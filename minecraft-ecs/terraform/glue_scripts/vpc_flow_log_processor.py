import sys
from datetime import datetime
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import DataFrame
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'source_bucket',
    'output_bucket',
    'database_name'
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

def process_vpc_flow_logs():
    """Process VPC Flow Logs from S3 and create network analytics"""
    
    # Read raw VPC Flow Logs from S3
    input_path = f"s3://{args['source_bucket']}/vpc-flow-logs/"
    
    try:
        # Read the raw flow log files
        raw_flow_logs = spark.read.text(input_path)
        
        if raw_flow_logs.count() == 0:
            print("No VPC Flow Log files found to process")
            return
        
        print(f"Processing {raw_flow_logs.count()} flow log entries")
        
        # Parse VPC Flow Logs (standard format)
        # Format: version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes windowstart windowend action flowlogstatus
        flow_logs_df = raw_flow_logs.select(
            split(col("value"), " ").alias("fields")
        ).select(
            col("fields")[0].alias("version"),
            col("fields")[1].alias("account_id"),
            col("fields")[2].alias("interface_id"),
            col("fields")[3].alias("srcaddr"),
            col("fields")[4].alias("dstaddr"),
            col("fields")[5].cast("int").alias("srcport"),
            col("fields")[6].cast("int").alias("dstport"),
            col("fields")[7].cast("int").alias("protocol"),
            col("fields")[8].cast("long").alias("packets"),
            col("fields")[9].cast("long").alias("bytes"),
            col("fields")[10].cast("long").alias("windowstart"),
            col("fields")[11].cast("long").alias("windowend"),
            col("fields")[12].alias("action"),
            col("fields")[13].alias("flowlogstatus")
        ).filter(
            col("version").isNotNull() & 
            col("srcaddr").isNotNull() & 
            col("dstaddr").isNotNull()
        )
        
        # Convert timestamps
        flow_logs_df = flow_logs_df.withColumn(
            "start_time", from_unixtime(col("windowstart"))
        ).withColumn(
            "end_time", from_unixtime(col("windowend"))
        )
        
        # Add date partitioning columns
        flow_logs_df = flow_logs_df.withColumn(
            "year", year(col("start_time"))
        ).withColumn(
            "month", lpad(month(col("start_time")), 2, "0")
        ).withColumn(
            "day", lpad(dayofmonth(col("start_time")), 2, "0")
        ).withColumn(
            "hour", lpad(hour(col("start_time")), 2, "0")
        )
        
        # Identify Minecraft-related traffic (port 25565 and 4567 for ServerTap)
        minecraft_traffic = flow_logs_df.filter(
            (col("srcport") == 25565) | (col("dstport") == 25565) |
            (col("srcport") == 4567) | (col("dstport") == 4567)
        ).withColumn(
            "traffic_type", 
            when((col("srcport") == 25565) | (col("dstport") == 25565), "minecraft")
            .when((col("srcport") == 4567) | (col("dstport") == 4567), "servertap")
            .otherwise("other")
        )
        
        # Create network analytics
        network_stats = create_network_statistics(flow_logs_df, minecraft_traffic)
        
        # Create connection analytics
        connection_stats = create_connection_statistics(minecraft_traffic)
        
        # Create geographic analytics (basic IP analysis)
        geo_stats = create_geographic_statistics(minecraft_traffic)
        
        # Write processed data to S3
        output_base = f"s3://{args['output_bucket']}/processed-data"
        
        # Write all flow logs (partitioned by date)
        flow_logs_df.write \
            .mode("append") \
            .partitionBy("year", "month", "day", "hour") \
            .parquet(f"{output_base}/vpc-flow-logs/")
        
        # Write Minecraft-specific traffic
        minecraft_traffic.write \
            .mode("append") \
            .partitionBy("year", "month", "day", "hour") \
            .parquet(f"{output_base}/minecraft-network-traffic/")
        
        # Write network statistics
        network_stats.write \
            .mode("overwrite") \
            .parquet(f"{output_base}/network-statistics/")
        
        # Write connection statistics
        connection_stats.write \
            .mode("overwrite") \
            .parquet(f"{output_base}/connection-statistics/")
        
        # Write geographic statistics
        geo_stats.write \
            .mode("overwrite") \
            .parquet(f"{output_base}/geographic-statistics/")
        
        print("Successfully processed and saved VPC Flow Logs")
        
    except Exception as e:
        print(f"Error processing VPC Flow Logs: {e}")
        raise

def create_network_statistics(all_traffic_df, minecraft_traffic_df):
    """Create network-level statistics"""
    
    # Overall network statistics
    total_stats = all_traffic_df.agg(
        count("*").alias("total_flows"),
        sum("packets").alias("total_packets"),
        sum("bytes").alias("total_bytes"),
        countDistinct("srcaddr").alias("unique_source_ips"),
        countDistinct("dstaddr").alias("unique_dest_ips"),
        sum(when(col("action") == "ACCEPT", 1).otherwise(0)).alias("accepted_flows"),
        sum(when(col("action") == "REJECT", 1).otherwise(0)).alias("rejected_flows")
    )
    
    # Minecraft-specific statistics
    minecraft_stats = minecraft_traffic_df.agg(
        count("*").alias("minecraft_flows"),
        sum("packets").alias("minecraft_packets"),
        sum("bytes").alias("minecraft_bytes"),
        countDistinct("srcaddr").alias("minecraft_unique_source_ips"),
        countDistinct("dstaddr").alias("minecraft_unique_dest_ips"),
        sum(when(col("action") == "ACCEPT", 1).otherwise(0)).alias("minecraft_accepted_flows"),
        sum(when(col("action") == "REJECT", 1).otherwise(0)).alias("minecraft_rejected_flows")
    )
    
    # Combine statistics
    network_stats = total_stats.crossJoin(minecraft_stats).withColumn(
        "stats_calculated_at", current_timestamp()
    )
    
    return network_stats

def create_connection_statistics(minecraft_traffic_df):
    """Create connection-level statistics for Minecraft traffic"""
    
    # Connection patterns by source IP
    connection_stats = minecraft_traffic_df.groupBy("srcaddr", "traffic_type") \
        .agg(
            count("*").alias("connection_count"),
            sum("packets").alias("total_packets"),
            sum("bytes").alias("total_bytes"),
            avg("packets").alias("avg_packets_per_flow"),
            avg("bytes").alias("avg_bytes_per_flow"),
            min("start_time").alias("first_connection"),
            max("end_time").alias("last_connection"),
            sum(when(col("action") == "ACCEPT", 1).otherwise(0)).alias("successful_connections"),
            sum(when(col("action") == "REJECT", 1).otherwise(0)).alias("failed_connections")
        )
    
    # Add connection duration and success rate
    connection_stats = connection_stats.withColumn(
        "connection_duration_hours",
        (unix_timestamp(col("last_connection")) - unix_timestamp(col("first_connection"))) / 3600
    ).withColumn(
        "success_rate",
        col("successful_connections") / (col("successful_connections") + col("failed_connections"))
    ).withColumn(
        "stats_calculated_at", current_timestamp()
    )
    
    return connection_stats

def create_geographic_statistics(minecraft_traffic_df):
    """Create basic geographic statistics based on IP patterns"""
    
    # Analyze IP address patterns to identify potential geographic regions
    # This is a simplified analysis - in production, you'd use a GeoIP database
    geo_stats = minecraft_traffic_df.withColumn(
        "ip_class_a", 
        split(col("srcaddr"), "\\.")[0]
    ).withColumn(
        "ip_class_b",
        concat(split(col("srcaddr"), "\\.")[0], lit("."), split(col("srcaddr"), "\\.")[1])
    ).groupBy("ip_class_a", "ip_class_b", "traffic_type") \
    .agg(
        count("*").alias("connection_count"),
        countDistinct("srcaddr").alias("unique_ips"),
        sum("packets").alias("total_packets"),
        sum("bytes").alias("total_bytes"),
        avg("packets").alias("avg_packets"),
        avg("bytes").alias("avg_bytes")
    ).withColumn(
        "stats_calculated_at", current_timestamp()
    )
    
    return geo_stats

def create_security_analytics(minecraft_traffic_df):
    """Create security-focused analytics"""
    
    # Identify potential security concerns
    security_stats = minecraft_traffic_df.groupBy("srcaddr") \
        .agg(
            count("*").alias("total_attempts"),
            sum(when(col("action") == "REJECT", 1).otherwise(0)).alias("rejected_attempts"),
            sum(when(col("action") == "ACCEPT", 1).otherwise(0)).alias("successful_attempts"),
            countDistinct("dstport").alias("unique_ports_accessed"),
            min("start_time").alias("first_attempt"),
            max("end_time").alias("last_attempt")
        ) \
        .withColumn(
            "rejection_rate",
            col("rejected_attempts") / col("total_attempts")
        ) \
        .withColumn(
            "potential_threat_score",
            when(col("rejection_rate") > 0.5, 3)  # High rejection rate
            .when(col("total_attempts") > 100, 2)  # High volume
            .when(col("unique_ports_accessed") > 5, 1)  # Port scanning
            .otherwise(0)
        ) \
        .withColumn(
            "stats_calculated_at", current_timestamp()
        )
    
    return security_stats

# Run the processing
process_vpc_flow_logs()

job.commit() 