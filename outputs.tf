# outputs.tf
output "s3_bucket" {
  description = "Name of the S3 bucket (data lake)"
  value       = aws_s3_bucket.data_lake.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.data_lake.arn
}

output "glue_database" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.bank_db.name
}

output "glue_crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.raw_crawler.name
}

output "glue_job_name" {
  description = "Name of the Glue ETL job"
  value       = aws_glue_job.transform_job.name
}

# output "redshift_workgroup" {
#   description = "Name of the Redshift Serverless workgroup"
#   value       = aws_redshiftserverless_workgroup.analytics.workgroup_name
# }

# output "redshift_endpoint" {
#   description = "Redshift Serverless endpoint address"
#   value       = aws_redshiftserverless_workgroup.analytics.endpoint[0].address
# }

# output "redshift_port" {
#   description = "Redshift Serverless port"
#   value       = aws_redshiftserverless_workgroup.analytics.endpoint[0].port
# }

# output "redshift_role_arn" {
#   description = "ARN of the Redshift IAM role"
#   value       = aws_iam_role.redshift_role.arn
# }

output "athena_workgroup" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.primary.name
}

output "athena_named_queries" {
  description = "Names of Athena named queries"
  value = {
    count_transactions       = aws_athena_named_query.count_transactions.name
    suspicious_transactions  = aws_athena_named_query.suspicious_transactions.name
    customer_volume          = aws_athena_named_query.customer_volume.name
  }
}

output "prefix" {
  description = "Resource prefix used for naming"
  value       = local.prefix
}

output "commands" {
  description = "Useful commands for running the pipeline"
  value = <<-COMMANDS
    # ========================================
    # BIG DATA LAB — COMMANDS
    # ========================================

    # ---- START THE PIPELINE ----

    # 1. Start Glue Crawler
    aws glue start-crawler --name ${aws_glue_crawler.raw_crawler.name}

    # 2. Check Crawler Status
    aws glue get-crawler --name ${aws_glue_crawler.raw_crawler.name} --query 'Crawler.State'

    # 3. Start Glue ETL Job
    aws glue start-job-run --job-name ${aws_glue_job.transform_job.name}

    # 4. Check Glue Job Status (most recent)
    aws glue get-job-runs --job-name ${aws_glue_job.transform_job.name} --max-items 1

    # 5. List all files in S3
    aws s3 ls s3://${aws_s3_bucket.data_lake.id}/ --recursive --human-readable

    # ---- ATHENA QUERIES ----

    # Run named query: count_transactions
    aws athena start-query-execution \
      --query-string "SELECT merchant, COUNT(*) FROM ${aws_glue_catalog_database.bank_db.name}.raw GROUP BY merchant" \
      --work-group ${aws_athena_workgroup.primary.name} \
      --result-configuration "OutputLocation=s3://${aws_s3_bucket.data_lake.id}/athena-results/"

    # ---- REDSHIFT CONNECTION ----

    # Endpoint: ${aws_redshiftserverless_workgroup.analytics.endpoint[0].address}
    # Port: ${aws_redshiftserverless_workgroup.analytics.endpoint[0].port}
    # Database: dev
    # Username: admin
    # Password: (see terraform.tfvars)

    # ---- DESTROY EVERYTHING ----

    terraform destroy -auto-approve
  COMMANDS
}