resource "aws_kms_key" "puerco-test-1" {
  description = "This key is used to encrypt bucket objects"
}

resource "aws_s3_bucket" "puerco-test-1" {
  bucket = "puerco-test-1"
  acl    = "private"

  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.puerco-test-1.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
resource "aws_s3_bucket_ownership_controls" "puerco-test-1" {
  bucket = aws_s3_bucket.puerco-test-1.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "puerco-test-1" {
  bucket = aws_s3_bucket.puerco-test-1.id

  block_public_acls   = true
  block_public_policy = true
}

resource "aws_iam_user" "puerco-test-1" {
  name = "puerco-test-1"
  path = "/"
}

resource "aws_iam_access_key" "puerco-test-1" {
  user = aws_iam_user.puerco-test-1.name
}

resource "aws_iam_user_policy" "puerco-test-1-rw-bucket" {
  name = "puerco-test-1"
  user = aws_iam_user.puerco-test-1.name

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Effect" : "Allow",
        "Resource" : aws_s3_bucket.puerco-test-1.arn
      }
    ]
  })
}
