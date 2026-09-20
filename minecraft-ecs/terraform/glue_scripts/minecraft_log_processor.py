import sys
import re
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

# Define schema for processed Minecraft events
minecraft_events_schema = StructType([
    StructField("timestamp", TimestampType(), True),
    StructField("event_type", StringType(), True),
    StructField("player_name", StringType(), True),
    StructField("message", StringType(), True),
    StructField("server_info", StringType(), True),
    StructField("coordinates", StringType(), True),
    StructField("dimension", StringType(), True),
    StructField("year", StringType(), True),
    StructField("month", StringType(), True),
    StructField("day", StringType(), True),
    StructField("hour", StringType(), True)
])

def parse_minecraft_log_line(log_line):
    """Parse a single Minecraft log line and extract relevant information"""
    try:
        # Updated patterns for the actual Minecraft log format
        patterns = {
            'player_join': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: (\w+) joined the game',
            'player_leave': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: (\w+) left the game',
            'player_death': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: (\w+) (.*died.*|.*killed.*|.*fell.*|.*drowned.*|.*burned.*|.*exploded.*)',
            'player_achievement': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: (\w+) has made the advancement \[(.*?)\]',
            'chat_message': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: \[Not Secure\] <(\w+)> (.*)',
            'server_start': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: Done \((.*?)\)! For help, type "help"',
            'server_stop': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: Stopping server',
            'world_save': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: Saved the game',
            'server_info': r'\[(\d{2}:\d{2}:\d{2}) INFO\]: (.*)'
        }
        
        for event_type, pattern in patterns.items():
            match = re.search(pattern, log_line)
            if match:
                time_str = match.group(1)
                
                # Extract player name and message based on event type
                player_name = None
                message = ""
                
                if event_type == 'chat_message':
                    # For chat messages: [time INFO]: [Not Secure] <player> message
                    player_name = match.group(2)
                    message = match.group(3)
                elif event_type in ['player_join', 'player_leave']:
                    # For join/leave: [time INFO]: player joined/left the game
                    player_name = match.group(2)
                    message = log_line
                elif event_type == 'player_death':
                    # For deaths: [time INFO]: player died/was killed/etc
                    player_name = match.group(2)
                    message = match.group(3)
                elif event_type == 'player_achievement':
                    # For achievements: [time INFO]: player has made the advancement [achievement]
                    player_name = match.group(2)
                    message = match.group(3)
                elif event_type in ['server_start', 'world_save', 'server_stop']:
                    # For server events
                    message = match.group(2) if len(match.groups()) > 1 else log_line
                elif event_type == 'server_info':
                    # For general server info
                    message = match.group(2)
                
                # Create timestamp from time string (assume current date)
                from datetime import datetime, time
                current_date = datetime.now().date()
                time_parts = time_str.split(':')
                log_time = time(int(time_parts[0]), int(time_parts[1]), int(time_parts[2]))
                full_timestamp = datetime.combine(current_date, log_time)
                
                return {
                    'timestamp': full_timestamp,
                    'event_type': event_type,
                    'player_name': player_name,
                    'message': message,
                    'server_info': log_line,
                    'coordinates': None,  # Could be extracted from specific messages
                    'dimension': None    # Could be extracted from specific messages
                }
        
        # If no pattern matches, return as generic log
        time_match = re.search(r'\[(\d{2}:\d{2}:\d{2}) INFO\]', log_line)
        if time_match:
            time_str = time_match.group(1)
            from datetime import datetime, time
            current_date = datetime.now().date()
            time_parts = time_str.split(':')
            log_time = time(int(time_parts[0]), int(time_parts[1]), int(time_parts[2]))
            full_timestamp = datetime.combine(current_date, log_time)
            
            return {
                'timestamp': full_timestamp,
                'event_type': 'other',
                'player_name': None,
                'message': log_line,
                'server_info': log_line,
                'coordinates': None,
                'dimension': None
            }
            
    except Exception as e:
        print(f"Error parsing log line: {e}")
        return None
    
    return None

def process_minecraft_logs():
    """Process Minecraft logs from S3 and create enriched datasets"""
    
    # Read raw logs from S3
    input_path = f"s3://{args['source_bucket']}/minecraft-container-logs/"
    
    try:
        # Read the raw log files
        raw_logs_df = spark.read.text(input_path)
        
        if raw_logs_df.count() == 0:
            print("No log files found to process")
            return
        
        print(f"Processing {raw_logs_df.count()} log entries")
        
        # Parse each log line
        def parse_log_udf(log_line):
            parsed = parse_minecraft_log_line(log_line)
            if parsed:
                # Add current date components for partitioning
                now = datetime.now()
                parsed.update({
                    'year': str(now.year),
                    'month': f"{now.month:02d}",
                    'day': f"{now.day:02d}",
                    'hour': f"{now.hour:02d}"
                })
                return parsed
            return None
        
        # Register UDF
        parse_udf = udf(parse_log_udf, minecraft_events_schema)
        
        # Apply parsing to each log line
        parsed_logs = raw_logs_df.select(
            parse_udf(col("value")).alias("parsed")
        ).select("parsed.*").filter(col("event_type").isNotNull())
        
        # Create player statistics
        player_stats = create_player_statistics(parsed_logs)
        
        # Create server statistics
        server_stats = create_server_statistics(parsed_logs)
        
        # Write processed data to S3
        output_base = f"s3://{args['output_bucket']}/processed-data"
        
        # Write parsed events (partitioned by date)
        parsed_logs.write \
            .mode("append") \
            .partitionBy("year", "month", "day", "hour") \
            .parquet(f"{output_base}/minecraft-events/")
        
        # Write player statistics
        player_stats.write \
            .mode("overwrite") \
            .parquet(f"{output_base}/player-statistics/")
        
        # Write server statistics
        server_stats.write \
            .mode("overwrite") \
            .parquet(f"{output_base}/server-statistics/")
        
        print("Successfully processed and saved Minecraft logs")
        
    except Exception as e:
        print(f"Error processing logs: {e}")
        raise

def create_player_statistics(events_df):
    """Create player-level statistics from events"""
    
    # Player activity summary
    player_stats = events_df.groupBy("player_name") \
        .agg(
            count("*").alias("total_events"),
            countDistinct("event_type").alias("unique_event_types"),
            sum(when(col("event_type") == "player_join", 1).otherwise(0)).alias("login_count"),
            sum(when(col("event_type") == "player_leave", 1).otherwise(0)).alias("logout_count"),
            sum(when(col("event_type") == "player_death", 1).otherwise(0)).alias("death_count"),
            sum(when(col("event_type") == "player_achievement", 1).otherwise(0)).alias("achievement_count"),
            sum(when(col("event_type") == "chat_message", 1).otherwise(0)).alias("chat_message_count"),
            min("timestamp").alias("first_seen"),
            max("timestamp").alias("last_seen")
        ) \
        .filter(col("player_name").isNotNull())
    
    # Add current timestamp for when stats were calculated
    player_stats = player_stats.withColumn("stats_calculated_at", current_timestamp())
    
    return player_stats

def create_server_statistics(events_df):
    """Create server-level statistics from events"""
    
    # Server activity summary
    server_stats = events_df.agg(
        count("*").alias("total_events"),
        countDistinct("player_name").alias("unique_players"),
        sum(when(col("event_type") == "player_join", 1).otherwise(0)).alias("total_logins"),
        sum(when(col("event_type") == "player_leave", 1).otherwise(0)).alias("total_logouts"),
        sum(when(col("event_type") == "player_death", 1).otherwise(0)).alias("total_deaths"),
        sum(when(col("event_type") == "player_achievement", 1).otherwise(0)).alias("total_achievements"),
        sum(when(col("event_type") == "chat_message", 1).otherwise(0)).alias("total_chat_messages"),
        sum(when(col("event_type") == "server_start", 1).otherwise(0)).alias("server_starts"),
        sum(when(col("event_type") == "server_stop", 1).otherwise(0)).alias("server_stops"),
        min("timestamp").alias("earliest_event"),
        max("timestamp").alias("latest_event")
    )
    
    # Add current timestamp for when stats were calculated
    server_stats = server_stats.withColumn("stats_calculated_at", current_timestamp())
    
    return server_stats

# Run the processing
process_minecraft_logs()

job.commit() 