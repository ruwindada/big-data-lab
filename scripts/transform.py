import sys
import boto3
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, when

# Create Spark session
spark = SparkSession.builder \
    .appName("CSV-to-Parquet") \
    .config("spark.sql.catalogImplementation", "in-memory") \
    .getOrCreate()

bucket = sys.argv[1] if len(sys.argv) > 1 else "bigdata-dev-b1980612"
print(f"🚀 Processing bucket: {bucket}")

# Read CSV directly from S3
raw_df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv(f"s3://{bucket}/raw/")

print(f"📊 Total rows: {raw_df.count()}")
print("📊 Schema:")
raw_df.printSchema()
print("📊 Sample data:")
raw_df.show(5)

# Clean and transform
cleaned_df = raw_df \
    .filter(col("amount").isNotNull()) \
    .withColumn("processing_date", to_date(col("timestamp"))) \
    .withColumn("is_high_value", col("amount") > 10000) \
    .withColumn("amount_eur",
        when(col("currency") == "EUR", col("amount"))
        .when(col("currency") == "USD", col("amount") * 0.92)
        .when(col("currency") == "CHF", col("amount") * 1.04)
        .otherwise(col("amount"))
    )

print(f"✅ Cleaned rows: {cleaned_df.count()}")

# Write as Parquet
cleaned_df.write \
    .mode("overwrite") \
    .partitionBy("processing_date") \
    .parquet(f"s3://{bucket}/processed/transactions/")
print("✅ Parquet write complete")

# Summary
cleaned_df.groupBy("merchant").count() \
    .write \
    .mode("overwrite") \
    .parquet(f"s3://{bucket}/processed/summary/")
print("✅ Summary write complete")
print("🎉 ETL job finished successfully!")

spark.stop()
