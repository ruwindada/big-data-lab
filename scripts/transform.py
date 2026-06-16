# scripts/transform.py
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import col, to_date, when, lit, sum as _sum, count as _count
from pyspark.sql.types import DateType

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_BUCKET'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

bucket = args['S3_BUCKET']

print(f"🚀 Starting ETL job on bucket: {bucket}")

# Read CSV from raw folder
raw_df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv(f"s3://{bucket}/raw/")

print(f"📊 Read {raw_df.count()} raw transactions")

# Data cleaning & transformation
cleaned_df = raw_df \
    .filter(col("amount").isNotNull()) \
    .filter(col("amount") > 0) \
    .withColumn("processing_date", to_date(col("timestamp"))) \
    .withColumn("is_high_value", when(col("amount") > 10000, lit(True)).otherwise(lit(False))) \
    .withColumn("is_suspicious", when(col("merchant") == "Unknown", lit(True)).otherwise(lit(False))) \
    .withColumn("amount_eur",
        when(col("currency") == "EUR", col("amount"))
        .when(col("currency") == "USD", col("amount") * 0.92)
        .when(col("currency") == "CHF", col("amount") * 1.04)
        .otherwise(col("amount"))
    ) \
    .dropDuplicates(["transaction_id"])

print(f"✅ Cleaned {cleaned_df.count()} transactions")

# Write as Parquet (partitioned by processing_date)
cleaned_df.write \
    .mode("overwrite") \
    .partitionBy("processing_date") \
    .parquet(f"s3://{bucket}/processed/transactions/")

print("✅ Parquet write complete")

# Generate summary statistics
summary_df = cleaned_df.groupBy("merchant").agg(
    _count("transaction_id").alias("transaction_count"),
    _sum("amount_eur").alias("total_volume_eur")
).orderBy(col("total_volume_eur").desc())

summary_df.write \
    .mode("overwrite") \
    .parquet(f"s3://{bucket}/processed/summary/")

print("✅ Summary write complete")
print("🎉 ETL job finished successfully")