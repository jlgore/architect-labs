# Minecraft ECS Infrastructure & Data Pipeline Architecture

## 🎯 Simplified High-Level Architecture

```mermaid
graph TD
    %% Players and Game Server
    Players[🎮 Minecraft Players] --> ECS[⚙️ ECS Fargate<br/>Minecraft Server]
    
    %% Data Collection
    ECS --> Logs[📝 CloudWatch Logs]
    ECS --> VPCFlow[🔍 VPC Flow Logs]
    
    %% Data Pipeline
    Logs --> Firehose[🌊 Kinesis Firehose]
    VPCFlow --> Firehose
    Firehose --> S3Raw[🪣 S3 Raw Data]
    
    %% Processing
    S3Raw --> Glue[🔧 Glue Jobs<br/>Hourly Processing]
    Glue --> S3Lake[🏞️ S3 Data Lake<br/>Processed Analytics]
    
    %% Analytics
    S3Lake --> Athena[📊 Amazon Athena<br/>SQL Analytics]
    
    %% Styling
    classDef game fill:#e8f5e8,stroke:#4caf50,stroke-width:2px
    classDef pipeline fill:#e3f2fd,stroke:#2196f3,stroke-width:2px  
    classDef analytics fill:#fce4ec,stroke:#e91e63,stroke-width:2px
    
    class Players,ECS game
    class Logs,VPCFlow,Firehose,S3Raw,Glue,S3Lake pipeline
    class Athena analytics
```

## 📊 Data Flow Layers

```mermaid
graph TB
    subgraph "🎮 Game Layer"
        Players[Minecraft Players]
        Server[ECS Minecraft Server]
        Players --> Server
    end
    
    subgraph "📥 Collection Layer" 
        CloudWatch[CloudWatch Logs]
        VPCLogs[VPC Flow Logs]
        Server --> CloudWatch
        Server --> VPCLogs
    end
    
    subgraph "🚀 Streaming Layer"
        Firehose[Kinesis Firehose]
        CloudWatch --> Firehose
        VPCLogs --> Firehose
    end
    
    subgraph "💾 Storage Layer"
        RawData[S3 Raw Logs]
        ProcessedData[S3 Data Lake]
        Firehose --> RawData
        RawData --> ProcessedData
    end
    
    subgraph "⚡ Processing Layer"
        GlueJob[Glue Jobs]
        RawData --> GlueJob
        GlueJob --> ProcessedData
    end
    
    subgraph "📈 Analytics Layer"
        Athena[Amazon Athena]
        Tables[Data Tables:<br/>• Player Stats<br/>• Server Metrics<br/>• Network Data]
        ProcessedData --> Athena
        Athena --> Tables
    end
```

## 🔄 Simple Data Processing Flow

```mermaid
flowchart LR
    A[🎮 Players Join] --> B[📝 Logs Generated]
    B --> C[🌊 Streamed to S3]
    C --> D[⏰ Hourly Processing]
    D --> E[📊 Ready for Analysis]
    
    style A fill:#e8f5e8
    style B fill:#fff3e0  
    style C fill:#e3f2fd
    style D fill:#f3e5f5
    style E fill:#fce4ec
```

## 🏗️ AWS Infrastructure Layout

```mermaid
graph TB
    subgraph "🌐 AWS Cloud"
        subgraph "🔒 VPC (minecraft-vpc)"
            subgraph "📡 Public Subnets"
                ECS[⚙️ ECS Fargate<br/>Minecraft Server<br/>Port 25565]
            end
        end
        
        subgraph "📊 Data Services"
            CW[☁️ CloudWatch<br/>Logs]
            KF[🌊 Kinesis<br/>Firehose]
            S3[🪣 S3 Buckets<br/>Raw + Processed]
            Glue[🔧 AWS Glue<br/>Jobs + Catalog]
            Athena[📈 Amazon Athena<br/>Analytics]
        end
        
        subgraph "🤖 Automation"
            EB[⏰ EventBridge<br/>Hourly Trigger]
            Lambda[⚡ Lambda<br/>Job Triggers]
        end
    end
    
    Users[🎮 Players] --> ECS
    ECS --> CW
    CW --> KF
    KF --> S3
    S3 --> Glue
    Glue --> Athena
    EB --> Lambda
    Lambda --> Glue
    
    classDef aws fill:#ff9900,color:white
    classDef compute fill:#ec7211,color:white
    classDef data fill:#3f8fbf,color:white
    classDef auto fill:#7aa116,color:white
    
    class ECS compute
    class CW,KF,S3,Glue,Athena data
    class EB,Lambda auto
```

## 🔄 Data Processing Workflow

```mermaid
sequenceDiagram
    participant 🎮 as Players
    participant ⚙️ as ECS Server
    participant ☁️ as CloudWatch
    participant 🌊 as Kinesis
    participant 🪣 as S3 Storage
    participant 🔧 as Glue Jobs
    participant 📈 as Athena
    
    🎮->>⚙️: Connect & Play
    ⚙️->>☁️: Stream Game Logs
    ☁️->>🌊: Forward Logs
    🌊->>🪣: Store Raw Data
    
    Note over 🔧: Hourly Processing
    🔧->>🪣: Read Raw Logs
    🔧->>🔧: Parse & Transform
    🔧->>🪣: Save Analytics
    
    📈->>🪣: Query Data
    📈-->>🎮: Analytics Results
```

## 📋 Analytics Tables Structure

```mermaid
graph LR
    subgraph "📊 Athena Analytics"
        Events[🎯 minecraft_events<br/>• Player actions<br/>• Game events<br/>• Timestamps]
        
        Players[👤 player_statistics<br/>• Login counts<br/>• Death counts<br/>• Activity times]
        
        Server[🖥️ server_statistics<br/>• Total events<br/>• Player counts<br/>• Server health]
        
        Network[🌐 network_statistics<br/>• Traffic flows<br/>• Connection data<br/>• Security metrics]
    end
    
    Events --> Players
    Events --> Server
    Events --> Network
    
    classDef table fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    class Events,Players,Server,Network table
```

## 🛠️ Service Dependencies

```mermaid
flowchart TD
    Internet[🌍 Internet] --> ALB[🔗 Application Load Balancer]
    ALB --> ECS[⚙️ ECS Fargate]
    
    ECS --> CWLogs[☁️ CloudWatch Logs]
    ECS --> VPCFlow[🔍 VPC Flow Logs]
    
    CWLogs --> Firehose[🌊 Kinesis Firehose]
    VPCFlow --> Firehose
    
    Firehose --> S3Raw[🪣 S3 Raw Logs]
    S3Raw --> GlueJobs[🔧 Glue Processing]
    GlueJobs --> S3Lake[🏞️ S3 Data Lake]
    
    S3Lake --> GlueCatalog[📚 Glue Catalog]
    GlueCatalog --> Athena[📊 Amazon Athena]
    
    EventBridge[⏰ EventBridge] --> Lambda[⚡ Lambda]
    Lambda --> GlueJobs
    
    style Internet fill:#f9f9f9
    style ALB fill:#ff9900,color:white
    style ECS fill:#ec7211,color:white
    style S3Raw,S3Lake fill:#3f8fbf,color:white
    style GlueJobs,GlueCatalog fill:#7aa116,color:white
    style Athena fill:#8c4fff,color:white
```

## Key Components Overview

### 🎮 **Game Infrastructure**
- **ECS Fargate Service**: Runs Minecraft server container
- **ServerTap Plugin**: Provides REST API for server statistics
- **Public Subnets**: Allow players to connect directly

### 📊 **Data Pipeline**
1. **Log Collection**: CloudWatch captures container logs and VPC flow logs
2. **Stream Processing**: Kinesis Firehose buffers and delivers to S3
3. **Batch Processing**: Glue jobs process logs hourly
4. **Data Cataloging**: Crawlers discover and register tables
5. **Analytics**: Athena provides SQL interface for querying

### 🔧 **Automation**
- **EventBridge**: Triggers processing every hour
- **Lambda Functions**: Start Glue jobs on schedule
- **IAM Roles**: Secure service-to-service communication

### 📈 **Analytics Tables**
- **minecraft_events**: Raw parsed game events
- **player_statistics**: Player behavior metrics
- **server_statistics**: Overall server health
- **network_statistics**: Traffic analysis
- **vpc_flow_logs**: Network security insights

This architecture enables real-time game hosting with comprehensive analytics, providing insights into player behavior, server performance, and network security. 