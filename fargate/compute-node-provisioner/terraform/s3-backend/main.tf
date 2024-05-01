provider "aws" {}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "tfstate-${var.account_id}"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
    bucket = aws_s3_bucket.terraform_state.id

    versioning_configuration {
      status = "Enabled"
    }
}

