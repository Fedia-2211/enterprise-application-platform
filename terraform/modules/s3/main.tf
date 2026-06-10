resource "aws_s3_bucket" "main" {
  bucket        = "${var.project_name}-${var.environment}-storage-${random_id.suffix.hex}"
  force_destroy = false
  tags          = { Name = "${var.project_name}-${var.environment}-storage" }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "db-backups-lifecycle"
    status = "Enabled"
    filter { prefix = "db-backups/" }

    transition {
      days          = 30          # ← was 7, minimum is 30 for STANDARD_IA
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 60          # ← was 30, must be after the IA transition
      storage_class = "GLACIER"
    }
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }

  rule {
    id     = "jenkins-artifacts-lifecycle"
    status = "Enabled"
    filter { prefix = "jenkins-artifacts/" }
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }

  rule {
    id     = "alb-logs-lifecycle"
    status = "Enabled"
    filter { prefix = "alb-logs/" }
    expiration { days = 90 }
  }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNonSSL"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = ["${aws_s3_bucket.main.arn}", "${aws_s3_bucket.main.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid    = "AllowALBLogging"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::127311923021:root" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.main.arn}/alb-logs/*"
      }
    ]
  })
}
