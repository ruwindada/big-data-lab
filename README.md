# big-data-lab

A complete, production-ready data platform on AWS built with Terraform, featuring S3 data lake, Glue ETL, Redshift Serverless, and Athena analytics.

## Overview

This repository contains Infrastructure as Code (IaC) for a scalable, enterprise-grade data platform on Amazon Web Services (AWS). The platform integrates multiple AWS services to create a complete data lake and analytics solution.

## Architecture

The data platform includes:

- **S3 Data Lake** - Centralized storage for raw and processed data
- **AWS Glue ETL** - Serverless extract, transform, and load operations
- **Redshift Serverless** - Managed data warehouse for analytics
- **Athena** - SQL query engine for data lake analytics

## Technology Stack

- **Infrastructure as Code**: Terraform (HCL) - 87%
- **Scripting & Automation**: Python - 13%

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured
- Python 3.8+

## Getting Started

1. Clone the repository
2. Configure your AWS credentials
3. Review and customize `terraform.tfvars`
4. Run Terraform commands:
   ```bash
   terraform init
   terraform plan
   terraform apply
