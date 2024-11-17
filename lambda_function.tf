resource "aws_lambda_function" "paymentledgeraudittrail" {
  function_name = "${var.dynamodb_table_name}-ledgeraudittrail"

  role    = aws_iam_role.paymentaudittrail_role.arn
  handler = "paymentledgeraudittrail.lambda_handler"
  runtime = "python3.8"

  filename         = "lambda_function/paymentledgeraudittrail.zip"
  source_code_hash = filebase64sha256("lambda_function/paymentledgeraudittrail.zip")

  environment {
    variables = {
      DYNAMODB_LEDGER_TABLE_NAME       = aws_dynamodb_table.payment_ledger.name
      DYNAMODB_AUDIT_TABLE_NAME = aws_dynamodb_table.payment_audit_trail.name
      KMS_KEY_ARN               = aws_kms_key.ledger_audit_key.arn
    }
  }

  vpc_config {
    subnet_ids         = [data.aws_subnet.private_subnet.id]     # Reference the private subnet
    security_group_ids = [data.aws_security_group.private_sg.id] # Reference the security group
  }

  timeout = 60
}
