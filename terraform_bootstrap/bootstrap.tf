resource "aws_s3_bucket" "terraform_state" {
  bucket = "app-migration-tf-state"
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "app-migration-tf-locks"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}