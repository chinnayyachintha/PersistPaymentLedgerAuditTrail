resource "aws_lambda_function" "paymentledgeraudittrail" {
  function_name = "${var.dynamodb_table_name}-ledgeraudittrail"

  role    = aws_iam_role.paymentaudittrail_role.arn
  handler = "paymentledgeraudittrail.lambda_handler"
  runtime = "python3.8"

  filename         = "lambda_function/paymentledgeraudittrail.zip"
  source_code_hash = filebase64sha256("lambda_function/paymentledgeraudittrail.zip")

  environment {
    variables = {
      DYNAMODB_LEDGER_TABLE_NAME = aws_dynamodb_table.payment_ledger.name
      DYNAMODB_AUDIT_TABLE_NAME  = aws_dynamodb_table.payment_audit_trail.name
      KMS_KEY_ARN                = aws_kms_alias.ledger_audit_key_alias.arn
    }
  }

  vpc_config {
    subnet_ids         = [data.aws_subnet.private_subnet.id]     # Reference the private subnet
    security_group_ids = [data.aws_security_group.private_sg.id] # Reference the security group
  }

  timeout = 60
}

# Lambda Function for DynamoDB Backup
resource "aws_lambda_function" "dynamodb_backup" {
  filename         = "lambda_function/dynamodb_backup.zip" # Replace with your Lambda zip file
  function_name    = "LedgerAuditTrail-dynamodb_backup"
  role             = aws_iam_role.paymentaudittrail_role.arn
  handler          = "dynamodb_backup.lambda_handler"
  runtime          = "python3.9"

  environment {
    variables = {
      # Comma-separated list of DynamoDB table ARNs to backup
      DYNAMODB_LEDGER_TABLE_NAME = aws_dynamodb_table.payment_ledger.name
      DYNAMODB_AUDIT_TABLE_NAME  = aws_dynamodb_table.payment_audit_trail.name
      S3_BUCKET        = aws_s3_bucket.dynamodb_backup.id
    }
  }

  timeout = 300  # Adjust timeout based on expected backup duration

  vpc_config {
    subnet_ids         = [data.aws_subnet.private_subnet.id]     # Reference the private subnet
    security_group_ids = [data.aws_security_group.private_sg.id] # Reference the security group
  }
}
