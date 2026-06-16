# main.tf
# ============================================
# LOCAL VALUES
# ============================================
locals {
  prefix = "bigdata-${var.environment}-${random_id.suffix.hex}"
}

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

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Folder structure
resource "aws_s3_object" "folders" {
  for_each = toset(["raw/", "processed/", "scripts/", "athena-results/", "temp/"])
  bucket   = aws_s3_bucket.data_lake.id
  key      = each.value
}

# ============================================
# UPLOAD DATA FROM LOCAL CSV FILE
# ============================================
resource "aws_s3_object" "sample_data" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "raw/transactions_${formatdate("YYYY-MM-DD", timestamp())}.csv"
  source = "${path.module}/data/transactions.csv"
  etag   = filemd5("${path.module}/data/transactions.csv")

  content_type = "text/csv"
}

# ============================================
# UPLOAD GLUE SCRIPT FROM LOCAL FILE
# ============================================
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.data_lake.id
  key    = "scripts/transform.py"
  source = "${path.module}/scripts/transform.py"
  etag   = filemd5("${path.module}/scripts/transform.py")
}

# ============================================
# IAM ROLES
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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Redshift Role
resource "aws_iam_role" "redshift_role" {
  name = "${local.prefix}-redshift-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "redshift-serverless.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${local.prefix}-redshift-role"
  }
}

resource "aws_iam_role_policy" "redshift_s3_access" {
  name = "redshift-s3-access"
  role = aws_iam_role.redshift_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.data_lake.arn,
        "${aws_s3_bucket.data_lake.arn}/processed/*"
      ]
    }]
  })
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
      }
    ]
  })
}

# ============================================
# GLUE DATA CATALOG + CRAWLER + JOB
# ============================================
resource "aws_glue_catalog_database" "bank_db" {
  name = "${local.prefix}_bank_db"
}

resource "aws_glue_crawler" "raw_crawler" {
  name          = "${local.prefix}-raw-crawler"
  database_name = aws_glue_catalog_database.bank_db.name
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.id}/raw/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DEPRECATE_IN_DATABASE"
  }

  schedule = null

  tags = {
    Name = "${local.prefix}-raw-crawler"
  }
}

resource "aws_glue_job" "transform_job" {
  name              = "${local.prefix}-transform-job"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "4.0"
  number_of_workers = var.glue_number_of_workers
  worker_type       = var.glue_worker_type

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

  tags = {
    Name = "${local.prefix}-transform-job"
  }
}

# ============================================
# REDSHIFT SERVERLESS
# ============================================
resource "aws_redshiftserverless_namespace" "analytics" {
  namespace_name      = "${local.prefix}-namespace"
  admin_username      = "admin"
  admin_user_password = var.redshift_admin_password
  db_name             = "dev"
  iam_roles           = [aws_iam_role.redshift_role.arn]

  tags = {
    Name = "${local.prefix}-namespace"
  }
}

resource "aws_redshiftserverless_workgroup" "analytics" {
  workgroup_name = "${local.prefix}-workgroup"
  namespace_name = aws_redshiftserverless_namespace.analytics.namespace_name
  base_capacity  = var.redshift_base_capacity

  publicly_accessible = true

  tags = {
    Name = "${local.prefix}-workgroup"
  }

  depends_on = [aws_redshiftserverless_namespace.analytics]
}

# ============================================
# ATHENA WORKGROUP + NAMED QUERIES
# ============================================
resource "aws_athena_workgroup" "primary" {
  name = "primary"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.id}/athena-results/"
    }
  }

  state = "ENABLED"
}

resource "aws_athena_named_query" "count_transactions" {
  name      = "${local.prefix}-count-transactions"
  database  = aws_glue_catalog_database.bank_db.name
  query     = <<-SQL
    SELECT 
      merchant, 
      COUNT(*) as transaction_count,
      ROUND(SUM(amount), 2) as total_volume
    FROM raw 
    GROUP BY merchant
    ORDER BY total_volume DESC
  SQL
  workgroup = aws_athena_workgroup.primary.name
}

resource "aws_athena_named_query" "suspicious_transactions" {
  name      = "${local.prefix}-suspicious-transactions"
  database  = aws_glue_catalog_database.bank_db.name
  query     = <<-SQL
    SELECT 
      transaction_id,
      customer_id,
      amount,
      merchant,
      status,
      timestamp
    FROM raw 
    WHERE status = 'flagged' OR merchant = 'Unknown'
    ORDER BY amount DESC
    LIMIT 20
  SQL
  workgroup = aws_athena_workgroup.primary.name
}

resource "aws_athena_named_query" "customer_volume" {
  name      = "${local.prefix}-customer-volume"
  database  = aws_glue_catalog_database.bank_db.name
  query     = <<-SQL
    SELECT 
      customer_id,
      COUNT(*) as tx_count,
      ROUND(SUM(amount), 2) as total_spent,
      ROUND(AVG(amount), 2) as avg_tx_value
    FROM raw 
    GROUP BY customer_id
    ORDER BY total_spent DESC
    LIMIT 10
  SQL
  workgroup = aws_athena_workgroup.primary.name
}