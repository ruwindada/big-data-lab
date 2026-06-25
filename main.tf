# main.tf
# ============================================
# LOCAL VALUES
# ============================================
locals {
  prefix = "bigdata-${var.environment}-${random_id.suffix.hex}"
}

# ============================================
# DATA SOURCES
# ============================================
data "aws_caller_identity" "current" {}

# ============================================
# RANDOM SUFFIX (prevents name collisions)
# ============================================
resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================
# S3 DATA LAKE
# ============================================
resource "aws_s3_bucket" "data_lake" {
  bucket        = local.prefix
  force_destroy = var.force_destroy_bucket

  tags = {
    Name        = "Big Data Lab - ${var.environment}"
    Environment = var.environment
  }
}

# ============================================
# 🔒 SECURITY: S3 VERSIONING (Enabled)
# ============================================
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================
# 🔒 SECURITY: S3 ENCRYPTION (KMS)
# ============================================
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# ============================================
# 🔒 SECURITY: S3 BLOCK PUBLIC ACCESS
# ============================================
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================
# 🔒 SECURITY: S3 ACCESS LOGGING
# ============================================
# 🔒 SECURITY: S3 LOG BUCKET (Encrypted, Versioned, Blocked Public Access)
resource "aws_s3_bucket" "log_bucket" {
  bucket        = "${local.prefix}-logs"
  force_destroy = true

  tags = {
    Name = "Log Bucket for ${local.prefix}"
  }
}

# 🔒 SECURITY: Log Bucket Versioning
resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 🔒 SECURITY: Log Bucket KMS Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# 🔒 SECURITY: Log Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 🔒 SECURITY: Log Bucket Lifecycle (Clean up old logs)
resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_logging" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "s3-access-logs/"
}

# ============================================
# 🔒 SECURITY: S3 LIFECYCLE (Archive & Expire)
# ============================================
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "archive-old-data"
    status = "Enabled"

    # 🔒 SECURITY: Abort incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# ============================================
# 🔒 SECURITY: KMS KEYS (Encryption at Rest)
# ============================================

# KMS Key for S3
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket ${local.prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Glue Service to Use KMS"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Athena Service to Use KMS"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_key_alias" "s3_key" {
  name          = "alias/${local.prefix}-s3-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

# KMS Key for Glue
resource "aws_kms_key" "glue_key" {
  description             = "KMS key for Glue ${local.prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Glue Service to Use KMS"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_key_alias" "glue_key" {
  name          = "alias/${local.prefix}-glue-key"
  target_key_id = aws_kms_key.glue_key.key_id
}

# KMS Key for Athena
resource "aws_kms_key" "athena_key" {
  description             = "KMS key for Athena ${local.prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Athena Service to Use KMS"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_key_alias" "athena_key" {
  name          = "alias/${local.prefix}-athena-key"
  target_key_id = aws_kms_key.athena_key.key_id
}

# ============================================
# S3 FOLDERS
# ============================================
resource "aws_s3_object" "folders" {
  for_each = toset(["raw/", "processed/", "scripts/", "athena-results/", "temp/"])
  bucket   = aws_s3_bucket.data_lake.id
  key      = each.value

  depends_on = [aws_s3_bucket.data_lake]
}

# ============================================
# UPLOAD DATA FROM LOCAL CSV FILE
# ============================================
resource "aws_s3_object" "sample_data" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/transactions_${formatdate("YYYY-MM-DD", timestamp())}.csv"
  source = "${path.module}/data/transactions11.csv"
  etag   = filemd5("${path.module}/data/transactions11.csv")

  content_type = "text/csv"

  depends_on = [
    aws_s3_bucket.data_lake,
    aws_s3_object.folders["raw/"]
  ]
}

# ============================================
# UPLOAD GLUE SCRIPT FROM LOCAL FILE
# ============================================
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/transform.py"
  source = "${path.module}/scripts/transform.py"
  etag   = filemd5("${path.module}/scripts/transform.py")

  depends_on = [
    aws_s3_bucket.data_lake,
    aws_s3_object.folders["scripts/"]
  ]
}

# ============================================
# 🔒 SECURITY: GLUE SECURITY CONFIGURATION (Encryption)
# ============================================
resource "aws_glue_security_configuration" "glue_security" {
  name = "${local.prefix}-glue-security"

  encryption_configuration {
    cloudwatch_encryption {
      cloudwatch_encryption_mode = "SSE-KMS"
      kms_key_arn                = aws_kms_key.glue_key.arn
    }

    job_bookmarks_encryption {
      job_bookmarks_encryption_mode = "CSE-KMS"
      kms_key_arn                   = aws_kms_key.glue_key.arn
    }

    s3_encryption {
      s3_encryption_mode = "SSE-KMS"
      kms_key_arn        = aws_kms_key.s3_key.arn
    }
  }
}

# ============================================
# 🔒 SECURITY: IAM ROLES (Least Privilege)
# ============================================

# Glue Role
resource "aws_iam_role" "glue_role" {
  name = "${local.prefix}-glue-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.prefix}-glue-role"
  }
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "glue-s3-access"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.s3_key.arn,
          aws_kms_key.glue_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  depends_on = [
    aws_iam_role.glue_role,
    aws_s3_bucket.data_lake,
    aws_kms_key.s3_key,
    aws_kms_key.glue_key
  ]
}

# Athena Role
resource "aws_iam_role" "athena_role" {
  name = "${local.prefix}-athena-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "athena.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.prefix}-athena-role"
  }
}

resource "aws_iam_role_policy" "athena_s3_access" {
  name = "athena-s3-access"
  role = aws_iam_role.athena_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/raw/*",
          "${aws_s3_bucket.data_lake.arn}/athena-results/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.data_lake.arn}/athena-results/*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.s3_key.arn,
          aws_kms_key.athena_key.arn
        ]
      }
    ]
  })

  depends_on = [
    aws_iam_role.athena_role,
    aws_s3_bucket.data_lake,
    aws_s3_object.folders["athena-results/"],
    aws_kms_key.s3_key,
    aws_kms_key.athena_key
  ]
}

# ============================================
# GLUE DATA CATALOG + CRAWLER + JOB
# ============================================
resource "aws_glue_catalog_database" "bank_db" {
  name = "${local.prefix}_bank_db"

  depends_on = [
    aws_s3_bucket.data_lake,
    aws_s3_object.sample_data
  ]
}

# ============================================
# 🔒 SECURITY: GLUE CRAWLER (with Security Configuration)
# ============================================
resource "aws_glue_crawler" "raw_crawler" {
  name          = "${local.prefix}-raw-crawler"
  database_name = aws_glue_catalog_database.bank_db.name
  role          = aws_iam_role.glue_role.arn
  security_configuration = aws_glue_security_configuration.glue_security.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.id}/raw/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }

  schedule = null

  depends_on = [
    aws_s3_bucket.data_lake,
    aws_s3_object.sample_data,
    aws_glue_catalog_database.bank_db,
    aws_iam_role.glue_role,
    aws_iam_role_policy.glue_s3_access,
    aws_glue_security_configuration.glue_security
  ]

  tags = {
    Name = "${local.prefix}-raw-crawler"
  }
}

# ============================================
# 🔒 SECURITY: GLUE JOB (with Security Configuration)
# ============================================
resource "aws_glue_job" "transform_job" {
  name              = "${local.prefix}-transform-job"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "4.0"
  number_of_workers = var.glue_number_of_workers
  worker_type       = var.glue_worker_type
  security_configuration = aws_glue_security_configuration.glue_security.name

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.data_lake.id}/scripts/transform.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"       = "python"
    "--enable-spark-ui"    = "true"
    "--enable-auto-scaling" = "true"
    "--S3_BUCKET"          = aws_s3_bucket.data_lake.id
    "--TempDir"            = "s3://${aws_s3_bucket.data_lake.id}/temp/"
  }

  max_retries = 0
  timeout     = var.glue_timeout_minutes

  depends_on = [
    aws_s3_bucket.data_lake,
    aws_s3_object.glue_script,
    aws_glue_catalog_database.bank_db,
    aws_iam_role.glue_role,
    aws_iam_role_policy.glue_s3_access,
    aws_glue_security_configuration.glue_security
  ]

  tags = {
    Name = "${local.prefix}-transform-job"
  }
}

# ============================================
# 🔒 SECURITY: ATHENA WORKGROUP (with KMS Encryption)
# ============================================
resource "aws_athena_workgroup" "primary" {
  name = "${local.prefix}-workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.id}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.athena_key.arn
      }
    }
  }

  state = "ENABLED"

  depends_on = [
    aws_s3_bucket.data_lake,
    aws_s3_object.folders["athena-results/"],
    aws_iam_role.athena_role,
    aws_iam_role_policy.athena_s3_access,
    aws_kms_key.athena_key
  ]
}

# ============================================
# ATHENA NAMED QUERIES
# ============================================
resource "aws_athena_named_query" "count_transactions" {
  name      = "${local.prefix}-count-transactions"
  database  = aws_glue_catalog_database.bank_db.name
  query     = <<-SQL
    SELECT 
      vehicle_brand,
      COUNT(*) as transaction_count,
      ROUND(SUM(loan_amount_eur), 2) as total_volume
    FROM raw 
    GROUP BY vehicle_brand
    ORDER BY total_volume DESC
  SQL
  workgroup = aws_athena_workgroup.primary.name

  depends_on = [
    aws_glue_catalog_database.bank_db,
    aws_athena_workgroup.primary
  ]
}

resource "aws_athena_named_query" "suspicious_transactions" {
  name      = "${local.prefix}-suspicious-transactions"
  database  = aws_glue_catalog_database.bank_db.name
  query     = <<-SQL
    SELECT 
      vehicle_brand,
      vehicle_model,
      loan_amount_eur,
      credit_score,
      debt_to_income_ratio
    FROM raw 
    WHERE credit_score < 650 OR debt_to_income_ratio > 40
    ORDER BY loan_amount_eur DESC
    LIMIT 20
  SQL
  workgroup = aws_athena_workgroup.primary.name

  depends_on = [
    aws_glue_catalog_database.bank_db,
    aws_athena_workgroup.primary
  ]
}

resource "aws_athena_named_query" "customer_volume" {
  name      = "${local.prefix}-customer-volume"
  database  = aws_glue_catalog_database.bank_db.name
  query     = <<-SQL
    SELECT 
      customer_id,
      COUNT(*) as tx_count,
      ROUND(SUM(loan_amount_eur), 2) as total_spent,
      ROUND(AVG(loan_amount_eur), 2) as avg_loan
    FROM raw 
    GROUP BY customer_id
    ORDER BY total_spent DESC
    LIMIT 10
  SQL
  workgroup = aws_athena_workgroup.primary.name

  depends_on = [
    aws_glue_catalog_database.bank_db,
    aws_athena_workgroup.primary
  ]
}