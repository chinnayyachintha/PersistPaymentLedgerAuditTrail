# IAM Role for Payment Ledger and Audit Trail Processing
resource "aws_iam_role" "paymentaudittrail_role" {
  name = "${var.dynamodb_table_name}-ledgeraudittrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy for Payment Ledger and Audit Trail
resource "aws_iam_role_policy" "paymentaudittrail_policy" {
  name = "${var.dynamodb_table_name}-ledgeraudittrail-policy"
  role = aws_iam_role.paymentaudittrail_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permissions for KMS (for both Payment Ledger and Audit Trail)
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.ledger_audit_key.id}",
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_alias.ledger_audit_key_alias.name}"
        ]
      },

      # Permissions for DynamoDB (for both Payment Ledger and Audit Trail)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.payment_ledger.name}",
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.payment_audit_trail.name}"
        ]
      },

      # Permissions for CloudWatch Logs (for both Payment Ledger and Audit Trail)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      },

      # Permissions for EC2 network interfaces (needed for Lambda in VPC)
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },

      # Backup Permissions for DynamoDB (for Payment Ledger only)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:ListTables",
          "dynamodb:DescribeTable",
          "dynamodb:ListStreams",
          "dynamodb:DescribeStream"
        ]
        Resource = "*"
      },

      # Backup Permissions for DynamoDB (for Payment Ledger only)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:CreateBackup",
          "dynamodb:DeleteBackup",
          "dynamodb:DescribeBackup",
          "dynamodb:ListBackups"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.payment_ledger.name}",
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.payment_audit_trail.name}"
      }
    ]
  })
}
