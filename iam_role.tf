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

resource "aws_iam_role_policy" "paymentaudittrail_policy" {
  name = "${var.dynamodb_table_name}-ledgeraudittrail-policy"
  role = aws_iam_role.paymentaudittrail_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permissions for KMS
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

      # Permissions for DynamoDB (Reading and Writing Data)
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

      # Permissions for Exporting DynamoDB to S3
      {
        Effect = "Allow"
        Action = [
          "dynamodb:ExportTableToPointInTime",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeExport",
          "dynamodb:ListExports",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.payment_ledger.name}",
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_dynamodb_table.payment_audit_trail.name}"
        ]
      },

      # S3 Permissions for Backup Storage
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_backup_bucket_name}",
          "arn:aws:s3:::${var.s3_backup_bucket_name}/*"
        ]
      },

      # CloudWatch Logs Permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"
      },

      # Lambda VPC permissions
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
      }
    ]
  })
}
