terraform {
  backend "s3" {
    bucket         = "app-migration-tf-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}