import boto3
import os
from botocore.exceptions import ClientError
import uuid
from datetime import datetime, timezone
from decimal import Decimal

# Retrieve environment variables
DYNAMODB_LEDGER_TABLE_NAME = os.getenv('DYNAMODB_LEDGER_TABLE_NAME')
DYNAMODB_AUDIT_TABLE_NAME = os.getenv('DYNAMODB_AUDIT_TABLE_NAME')
KMS_KEY_ARN = os.getenv('KMS_KEY_ARN')

# Initialize AWS services
dynamodb = boto3.resource('dynamodb')
kms_client = boto3.client('kms')

# Connect to DynamoDB tables
payment_ledger_table = dynamodb.Table(DYNAMODB_LEDGER_TABLE_NAME)
audit_table = dynamodb.Table(DYNAMODB_AUDIT_TABLE_NAME)

# Helper Function: Encrypt SecureToken using KMS
def encrypt_token(token):
    try:
        response = kms_client.encrypt(
            KeyId=KMS_KEY_ARN,
            Plaintext=token.encode('utf-8')
        )
        return response['CiphertextBlob']
    except ClientError as e:
        raise Exception(f"Error encrypting token: {e.response['Error']['Message']}")

# Step 1: Persist Payment Ledger Entry (Payment Initiation)
def persist_payment_ledger(amount, processor_id):
    transaction_id = str(uuid.uuid4())  # Unique Transaction ID
    status = "PAYMENT-INITIATED"
    
    try:
        payment_ledger_table.put_item(
            Item={
                'TransactionID': transaction_id,
                'Amount': amount,
                'ProcessorID': processor_id,
                'Status': status,
                'Timestamp': str(datetime.utcnow())
            }
        )
        return transaction_id
    except ClientError as e:
        raise Exception(f"Error storing payment initiation: {e.response['Error']['Message']}")

# Step 2: Encrypt Token for Processor
def create_secure_token(amount, processor_id):
    token = f"TokenFor:{amount}:{processor_id}"
    encrypted_token = encrypt_token(token)
    return encrypted_token

# Step 3: Update Payment Status
def update_payment_status(transaction_id, status):
    try:
        payment_ledger_table.update_item(
            Key={'TransactionID': transaction_id},
            UpdateExpression="set #status = :status",
            ExpressionAttributeNames={'#status': 'Status'},
            ExpressionAttributeValues={':status': status},
            ReturnValues="UPDATED_NEW"
        )
    except ClientError as e:
        raise Exception(f"Error updating payment status: {e.response['Error']['Message']}")

# Step 4: Process Payment Response
def process_payment_response(transaction_id, amount, processor_id, processor_response):
    normalized_status = normalize_processor_response(processor_response)

    try:
        update_payment_status(transaction_id, normalized_status)

        if normalized_status == "PAYMENT-SUCCESS":
            persist_payment_success(transaction_id, amount, processor_id)
            query_details = f"Payment successful for amount: {amount} using processor: {processor_id}"
            response_data = f"Processor response: {processor_response}"
            persist_payment_audit_trail(transaction_id, query_details, response_data)
            return send_payment_success_response(transaction_id)

        elif normalized_status == "PAYMENT-FAILED":
            query_details = f"Failed payment for amount: {amount} using processor: {processor_id}"
            response_data = f"Processor response: {processor_response}"
            persist_payment_audit_trail(transaction_id, query_details, response_data)
            raise Exception(f"Payment failed for transaction {transaction_id}")

        elif normalized_status == "PAYMENT-PENDING":
            query_details = f"Payment pending for amount: {amount} using processor: {processor_id}"
            response_data = f"Processor response: {processor_response}"
            persist_payment_audit_trail(transaction_id, query_details, response_data)
            return {
                'statusCode': 202,
                'body': f"Payment is pending for transaction {transaction_id}"
            }

    except Exception as e:
        raise Exception(f"Error processing payment response: {str(e)}")

# Step 5: Normalize Processor Response
def normalize_processor_response(response):
    if response['status'] == 'success':
        return 'PAYMENT-SUCCESS'
    elif response['status'] == 'failure':
        return 'PAYMENT-FAILED'
    else:
        return 'PAYMENT-PENDING'

# Step 6: Persist Payment Success Ledger Entry
def persist_payment_success(transaction_id, amount, processor_id):
    status = "PAYMENT-SUCCESS"
    try:
        payment_ledger_table.put_item(
            Item={
                'TransactionID': transaction_id,
                'Amount': amount,
                'ProcessorID': processor_id,
                'Status': status,
                'Timestamp': str(datetime.utcnow())
            }
        )
    except ClientError as e:
        raise Exception(f"Error creating payment success entry: {e.response['Error']['Message']}")

# Step 7: Create Audit Trail
def persist_payment_audit_trail(transaction_id, query_details, response_data):
    try:
        audit_id = str(uuid.uuid4())
        audit_table.put_item(
            Item={
                'AuditID': audit_id,
                'TransactionID': transaction_id,
                'QueryDetails': query_details,
                'ResponseData': response_data,
                'Timestamp': str(datetime.now(timezone.utc))
            }
        )
    except ClientError as e:
        raise Exception(f"Error creating audit trail: {e.response['Error']['Message']}")

# Step 8: Send Success Response to API
def send_payment_success_response(transaction_id):
    return {
        'statusCode': 200,
        'body': f'Payment completed successfully for transaction {transaction_id}'
    }

# Main Lambda Handler
def lambda_handler(event, context):
    try:
        amount = Decimal(str(event['amount']))
        processor_id = event['processor_id']
        transaction_id = persist_payment_ledger(amount, processor_id)

        encrypted_token = create_secure_token(amount, processor_id)

        update_payment_status(transaction_id, "PAYMENT-PENDING")

        processor_response = {
            'status': event.get('simulate_status', 'success'),
            'transaction_id': transaction_id,
            'amount': amount,
            'processor_id': processor_id
        }

        return process_payment_response(transaction_id, amount, processor_id, processor_response)

    except Exception as e:
        return {
            'statusCode': 500,
            'body': f"Error in payment processing flow: {str(e)}"
        }
