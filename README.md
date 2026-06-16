# 🚀 Big Data Lab - AWS Data Platform

A complete, production-ready data platform on AWS built with Terraform, featuring S3 data lake, Glue ETL, Redshift Serverless, and Athena analytics.

---

## 📋 Overview

This project builds an end-to-end data platform on AWS using Infrastructure as Code (IaC). It's designed to demonstrate modern data engineering practices for banking and financial services, with a focus on:

- **Scalable Data Storage** - S3 data lake with raw/processed zones
- **Serverless ETL** - AWS Glue with PySpark for data transformation
- **Data Warehousing** - Redshift Serverless for analytics
- **Ad-hoc Querying** - Athena for serverless SQL on S3
- **Infrastructure as Code** - Terraform with GitHub Actions CI/CD
- **Security First** - IAM least privilege, encryption at rest

---

## 🏗️ Architecture
┌─────────────────────────────────────────────────────────────────────────────┐
│ AWS Data Platform │
├─────────────────────────────────────────────────────────────────────────────┤
│ │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │
│ │ Data Lake │ │ ETL │ │ Data │ │
│ │ (S3) │ -> │ (Glue) │ -> │ Warehouse │ │
│ │ raw/ │ │ PySpark │ │ (Redshift) │ │
│ │ processed/ │ │ Parquet │ │ Serverless │ │
│ └─────────────┘ └─────────────┘ └─────────────┘ │
│ │ │ │ │
│ v v v │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Analytics Layer │ │
│ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │ │
│ │ │ Athena │ │ BI │ │ API │ │ │
│ │ │ (SQL on │ │ (Redshift │ │ (Outputs) │ │ │
│ │ │ S3) │ │ Queries) │ │ │ │ │
│ │ └─────────────┘ └─────────────┘ └─────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Security & Governance │ │
│ │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │ │
│ │ │ IAM │ │ KMS │ │ S3 Public │ │ │
│ │ │ Least │ │ Encryption │ │ Block │ │ │
│ │ │ Privilege │ │ at Rest │ │ Access │ │ │
│ │ └─────────────┘ └─────────────┘ └─────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│ │
└─────────────────────────────────────────────────────────────────────────────┘