import os
import uuid
import boto3
import json
from datetime import datetime, timezone
from decimal import Decimal
import requests

# Initialize DynamoDB
dynamodb = boto3.resource("dynamodb")

# Retrieve table names from environment variables
PAYMENT_LEDGER_TABLE = os.getenv("PAYMENT_LEDGER_TABLE")
AUDIT_TRAIL_TABLE = os.getenv("AUDIT_TRAIL_TABLE")

# Initialize tables dynamically
payment_ledger_table = dynamodb.Table(PAYMENT_LEDGER_TABLE)
audit_table = dynamodb.Table(AUDIT_TRAIL_TABLE)

# Step 1: Create Ledger Entry
def create_ledger_entry(transaction_id, process_type, status, details=None):
    try:
        payment_ledger_table.put_item(
            Item={
                "transaction_id": transaction_id,
                "process_type": process_type,
                "status": status,
                "timestamp": str(datetime.now(timezone.utc)),
                "response_details": details or {},
            }
        )
    except Exception as e:
        raise Exception(f"Error creating ledger entry: {str(e)}")

# Step 2: Get Security Token from Payment Processor
def get_security_token():
    try:
        headers = {"Authorization": f"Bearer {os.getenv('API_KEY')}"}
        processor_url = os.getenv("PROCESSOR_URL")
        response = requests.post(f"{processor_url}/security-token", headers=headers)
        response.raise_for_status()
        return response.json()["token"]
    except Exception as e:
        raise Exception(f"Error generating security token: {str(e)}")

# Step 3: Update Ledger for Payment Pending
def update_ledger_status(transaction_id, status, details=None):
    try:
        payment_ledger_table.update_item(
            Key={"transaction_id": transaction_id},
            UpdateExpression="SET #st = :s, response_details = :rd",
            ExpressionAttributeNames={"#st": "status"},
            ExpressionAttributeValues={
                ":s": status,
                ":rd": details or {},
            },
        )
    except Exception as e:
        raise Exception(f"Error updating ledger entry: {str(e)}")

# Step 4: Process Payment Intent
def process_payment_intent(transaction_id, amount, token):
    try:
        processor_url = os.getenv("PROCESSOR_URL")
        payload = {"transaction_id": transaction_id, "amount": str(amount), "token": token}
        response = requests.post(f"{processor_url}/payment-intent", json=payload)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        raise Exception(f"Error processing payment intent: {str(e)}")

# Step 5: Log Payment Success in Ledger
def log_payment_success(transaction_id, details):
    update_ledger_status(transaction_id, "PAYMENT-SUCCESS", details)

# Step 6: Create Audit Entry for Successful Payment
def create_audit_entry(transaction_id, action_type, details):
    try:
        audit_table.put_item(
            Item={
                "audit_id": str(uuid.uuid4()),
                "transaction_id": transaction_id,
                "action_type": action_type,
                "timestamp": str(datetime.now(timezone.utc)),
                "action_details": details,
            }
        )
    except Exception as e:
        raise Exception(f"Error creating audit entry: {str(e)}")

# Step 7: Normalize Processor Response
def normalize_response(response):
    return {
        "status": response.get("status", "unknown"),
        "message": response.get("message", "No message provided"),
        "transaction_id": response.get("transaction_id"),
    }

# Step 8: Return Success Response to API Gateway
def lambda_handler(event, context):
    try:
        # Extract input data
        transaction_id = str(uuid.uuid4())
        process_type = event["process_type"]
        amount = Decimal(str(event["amount"]))

        # Step 1: Create Ledger Entry for Payment Initiation
        create_ledger_entry(transaction_id, process_type, "PAYMENT-INITIATED")

        # Step 2: Generate Security Token
        token = get_security_token()

        # Step 3: Create Ledger Entry for Payment Pending
        update_ledger_status(transaction_id, "PAYMENT-PENDING", {"token": token})

        # Step 4: Process Payment Intent
        processor_response = process_payment_intent(transaction_id, amount, token)

        # Step 5: Log Payment Success
        if processor_response["status"].lower() == "success":
            normalized_response = normalize_response(processor_response)
            log_payment_success(transaction_id, normalized_response)

            # Step 6: Create Audit Entry
            create_audit_entry(transaction_id, "PAYMENT-SUCCESS", normalized_response)

            # Step 8: Return Success Response
            return {
                "statusCode": 200,
                "body": json.dumps({"transaction_id": transaction_id, "status": "success"}),
            }

        else:
            raise Exception(f"Payment failed: {processor_response}")

    except Exception as e:
        # Log errors
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }
