import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from pyspark.sql.functions import col, to_date, when

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_BUCKET'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

bucket = args['S3_BUCKET']
print(f"🚀 Processing bucket: {bucket}")

# Read CSV from S3
raw_df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv(f"s3://{bucket}/raw/")

print(f"📊 Total rows: {raw_df.count()}")

# Clean and transform
cleaned_df = raw_df \
    .filter(col("loan_amount_eur").isNotNull()) \
    .withColumn("is_high_risk", (col("credit_score") < 650) & (col("debt_to_income_ratio") > 40)) \
    .withColumn("loan_to_value_ratio", col("loan_amount_eur") / col("vehicle_price_eur"))

print(f"✅ Cleaned rows: {cleaned_df.count()}")

# Write as Parquet
cleaned_df.write \
    .mode("overwrite") \
    .partitionBy("loan_purpose") \
    .parquet(f"s3://{bucket}/processed/transactions/")
print("✅ Parquet write complete")

# Summary
cleaned_df.groupBy("vehicle_brand").count() \
    .write \
    .mode("overwrite") \
    .parquet(f"s3://{bucket}/processed/summary/")
print("✅ Summary write complete")
print("🎉 ETL job finished successfully!")
