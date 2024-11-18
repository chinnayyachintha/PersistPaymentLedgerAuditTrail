import boto3
import os
import json
from datetime import datetime

def lambda_handler(event, context):
    dynamodb = boto3.client('dynamodb')
    tables = os.getenv('TABLES_TO_BACKUP').split(',')
    s3_bucket = os.getenv('S3_BUCKET')
    timestamp = datetime.utcnow().strftime('%Y-%m-%d-%H-%M-%S')
    
    for table in tables:
        export_task = dynamodb.export_table_to_point_in_time(
            TableArn=f"arn:aws:dynamodb:{os.getenv('AWS_REGION')}:{os.getenv('AWS_ACCOUNT_ID')}:table/{table}",
            S3Bucket=s3_bucket,
            S3Prefix=f"backups/{table}/{timestamp}",
            ExportFormat="DYNAMODB_JSON"
        )
        print(f"Export started for table {table}: {export_task['ExportDescription']['ExportArn']}")
    return {"statusCode": 200, "body": json.dumps("Backup started")}
