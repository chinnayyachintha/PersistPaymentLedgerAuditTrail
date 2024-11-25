resource "aws_dynamodb_table" "payment_ledger" {
  name         = "${var.dynamodb_table_name}-Ledger"
  billing_mode = "PAY_PER_REQUEST" # On-demand mode
  hash_key     = "transaction_id"  # Partition Key
  range_key    = "timestamp"       # Sort Key

  # Define the attributes
  attribute {
    name = "transaction_id"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }
  attribute {
    name = "amount"
    type = "N"
  }
  attribute {
    name = "currency"
    type = "S"
  }
  attribute {
    name = "payment_method"
    type = "S"
  }
  attribute {
    name = "payment_status"
    type = "S"
  }
  attribute {
    name = "transaction_type"
    type = "S"
  }
  attribute {
    name = "customer_id"
    type = "S"
  }
  attribute {
    name = "merchant_id"
    type = "S"
  }
  attribute {
    name = "source"
    type = "S"
  }

  # Define the Global Secondary Indexes (GSIs)
  global_secondary_index {
    name            = "AmountIndex"
    hash_key        = "transaction_id"
    range_key       = "amount" # Use 'amount' in the range key for filtering
    projection_type = "ALL"    # All attributes available
  }

  global_secondary_index {
    name            = "CurrencyIndex"
    hash_key        = "transaction_id"
    range_key       = "currency" # Use 'currency' in the range key for filtering
    projection_type = "ALL"      # All attributes available
  }

  global_secondary_index {
    name            = "PaymentMethodIndex"
    hash_key        = "transaction_id"
    range_key       = "payment_method" # Use 'payment_method' in the range key
    projection_type = "ALL"            # All attributes available
  }

  global_secondary_index {
    name            = "PaymentStatusIndex"
    hash_key        = "transaction_id"
    range_key       = "payment_status" # Use 'payment_status' in the range key
    projection_type = "ALL"            # All attributes available
  }

  global_secondary_index {
    name            = "TransactionTypeIndex"
    hash_key        = "transaction_id"
    range_key       = "transaction_type" # Use 'transaction_type' in the range key
    projection_type = "ALL"              # All attributes available
  }

  global_secondary_index {
    name            = "SourceIndex"
    hash_key        = "transaction_id"
    range_key       = "source" # Use 'source' in the range key
    projection_type = "ALL"    # All attributes available
  }

  global_secondary_index {
    name            = "CustomerIdIndex"
    hash_key        = "transaction_id"
    range_key       = "customer_id" # Use 'customer_id' in the range key
    projection_type = "ALL"         # All attributes available
  }

  global_secondary_index {
    name            = "MerchantIdIndex"
    hash_key        = "transaction_id"
    range_key       = "merchant_id" # Use 'merchant_id' in the range key
    projection_type = "ALL"         # All attributes available
  }

  # Enable Point-in-Time Recovery (PITR)
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.dynamodb_table_name}-Ledger"
  }
}

resource "aws_dynamodb_table" "payment_audit_trail" {
  name         = "${var.dynamodb_table_name}-AuditTrail"
  billing_mode = "PAY_PER_REQUEST" # On-demand mode
  hash_key     = "audit_id"        # Partition Key
  range_key    = "timestamp"       # Sort Key

  # Define the attributes
  attribute {
    name = "audit_id"
    type = "S"
  }
  attribute {
    name = "transaction_id"
    type = "S"
  }
  attribute {
    name = "action"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }
  attribute {
    name = "source_ip"
    type = "S"
  }
  attribute {
    name = "action_details"
    type = "S"
  }
  attribute {
    name = "payment_result"
    type = "S"
  }
  attribute {
    name = "user_id"
    type = "S"
  }

  # Define the Global Secondary Indexes (GSIs)
  global_secondary_index {
    name            = "PaymentResultIndex"
    hash_key        = "transaction_id"
    range_key       = "payment_result" # Use 'payment_result' in the range key
    projection_type = "ALL"            # All attributes available
  }

  global_secondary_index {
    name            = "SourceIpIndex"
    hash_key        = "transaction_id"
    range_key       = "source_ip" # Use 'source_ip' in the range key
    projection_type = "ALL"       # All attributes available
  }

  global_secondary_index {
    name            = "ActionDetailsIndex"
    hash_key        = "action"
    range_key       = "timestamp" # Use 'timestamp' for sorting
    projection_type = "ALL"       # All attributes available
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "transaction_id"
    range_key       = "user_id" # Use 'user_id' in the range key
    projection_type = "ALL"     # All attributes available
  }

  global_secondary_index {
    name            = "ActionDetailsGSI" # New GSI for action_details
    hash_key        = "action_details"
    range_key       = "timestamp" # Sorting by timestamp
    projection_type = "ALL"       # All attributes available
  }

  # Enable Point-in-Time Recovery (PITR)
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.dynamodb_table_name}-AuditTrail"
  }
}
