1. Current Cost Estimate:
								
| Estimate summary  |                       |                                 |            |         |          |                       |          |
|-------------------|-----------------------|---------------------------------|------------|---------|----------|-----------------------|----------|
| Upfront cost      | Monthly cost          | Total 12 months cost            | Currency   |         |          |                       |          |
| 0                 | 14448.87              | 173386.44                       | USD        |         |          |                       |          |
|                   |                       | * Includes upfront cost         |            |         |          |                       |          |
|                   |                       |                                 |            |         |          |                       |          |
|                   |                       |                                 |            |         |          |                       |          |
| Detailed Estimate |                       |                                 |            |         |          |                       |          |
| Group hierarchy   | Region                | Description                     | Service    | Upfront | Monthly  | First 12 months total | Currency |
| My Estimate       | US East (N. Virginia) | DBRE_Initial_Cost_Estimate      | Amazon EC2 | 0       | 13108.98 | 157307.76             | USD      |
| My Estimate       | US East (N. Virginia) | SSIS_SSRS_Estimate_DBRE_Initial | Amazon EC2 | 0       | 1339.89  | 16078.68              | USD      |
|                   |                       |                                 |            |         |          |                       |          |
																																																					
Configuration summary																														
Tenancy (Dedicated Instances), Operating system (Windows Server with SQL Server Enterprise), Workload (Consistent, Number of instances: 2), Advance EC2 instance (r5.4xlarge), Pricing strategy ( 1yr  No Upfront), Enable monitoring (enabled), EBS Storage amount (4 TB), DT Inbound: Not selected (0 TB per month), DT Outbound: Not selected (0 TB per month), DT Intra-Region: (0 TB per month)
Tenancy (Dedicated Instances), Operating system (Windows Server with SQL Server Standard), Workload (Consistent, Number of instances: 1), Advance EC2 instance (r5.2xlarge), Pricing strategy ( 1yr  No Upfront), Enable monitoring (enabled), EBS Storage amount (800 GB), DT Inbound: Not selected (0 TB per month), DT Outbound: Not selected (0 TB per month), DT Intra-Region: (0 TB per month)
															


2.  Proposed RDS Architecture:

Estimate summary

| Upfront cost | Monthly cost | Total 12 months cost |
|--------------|--------------|----------------------|
| 0.00 USD     | 6,985.20 USD | 83,822.40 USD        |


Includes upfront cost

Detailed Estimate
Name
Amazon RDS for SQL server
Group
-
Region
US East (N. Virginia)
Upfront cost
0.00 USD
Monthly cost
6,985.20 USD
Status
-
Description:
Proposed RDS
Config summary
Storage amount (2 TB), Nodes (1), Instance type (db.r5d.2xlarge), Utilization (On-Demand only) (730 Hours/Month), Deployment option (Multi-AZ), License (License included), Database edition (Enterprise), Unbundled Licensing (FALSE), Pricing strategy (Reserved 1yr No Upfront), Storage for each RDS instance (General Purpose SSD (gp3)), General Purpose SSD (gp3) - IOPS (16000), General Purpose SSD (gp3) - Throughput (1000 MiBps)

SSIS & SSRS would remain on EC2:

Monthly cost:
1339.89 USD

Total 12 months cost:
16078.68 USD

Tenancy (Dedicated Instances), Operating system (Windows Server with SQL Server Standard), Workload (Consistent, Number of instances: 1), Advance EC2 instance (r5.2xlarge), Pricing strategy ( 1yr  No Upfront), Enable monitoring (enabled), EBS Storage amount (800 GB), DT Inbound: Not selected (0 TB per month), DT Outbound: Not selected (0 TB per month), DT Intra-Region: (0 TB per month)

Total Monthly cost for both = 8,325.09 USD


3. Edition Downgrade Analysis:

Features Lost or Degraded: 

Scaling:
	- Compute capacity- Limited to 4 Sockets or 24 Cores in contrast to O/S system maximum with Enterprise Edition
        - Memory Buffer Pool max is 128 GB
        - Max capacity for Buffer pool extension 4 times memory configured vs 32 times for Enterprise
        - Maximum Memory for columnstore is 32GB
|                              | Features                                                        | SQL Server Standard Edition (2022) |
|------------------------------|-----------------------------------------------------------------|------------------------------------|
| HA:                          |                                                                 |                                    |
|                              | Always on failover cluster instances: 2 nodes vs 16 *           |                                    |
|                              | Always On availability groups *                                 | Not Available                      |
|                              | Online page and file restore                                    | Not Available                      |
|                              | Online indexing *                                               | Not Available                      |
|                              | Online schema  change *                                         | Not Available                      |
|                              | Fast recovery                                                   | Not Available                      |
|                              | Mirrored backups                                                | Not Available                      |
|                              | Hot add memory and CPU                                          | Not Available                      |
|                              | Contained availability groups                                   | Not Available                      |
|                              | Distributed availability groups                                 | Not Available                      |
|                              | Automatic read write connection rerouting                       | Not Available                      |
|                              | Resumable online index rebuilds                                 | Not Available                      |
|                              | Resumable online ADD CONSTRAINT                                 | Not Available                      |
|                              |                                                                 |                                    |
| Scalability and Performance: |                                                                 |                                    |
|                              |                                                                 |                                    |
|                              | Online nonclustered columnstore index rebuild *                 | Not Available                      |
|                              | In-Memory Database: hybrid buffer pool support for direct write | Not Available                      |
|                              | In-Memory Database: Memory-optimized TempDB metadata            | Not Available                      |
|                              | NUMA aware large page memory and buffer array allocation        | Not Available                      |
|                              | I/O resource governance                                         | Not Available                      |
|                              | Read-ahead                                                      | Not Available                      |
|                              | Advanced scanning                                               | Not Available                      |
|                              | Support for Advanced Vector Extension (AVX) 512 5               | Not Available                      |
|                              | Integrated acceleration and offloading (hardware)               | Not Available                      |
|                              |                                                                 |                                    |
| Other Features:              |                                                                 |                                    |
|                              |                                                                 |                                    |
|                              | (Performance) Resource governor                                 | Not Available                      |
|                              | (Security)  Extensible key management (EKM)                     | Not Available                      |
|                              | (Replication)  Oracle publication                               | Not Available                      |
|                              | (Replication) Peer to peer transactional replication            | Not Available                      |
|                              | Automatic tuning *                                              | Not Available                      |
|                              | Batch mode adaptive joins                                       | Not Available                      |
|                              | Batch mode memory grant feedback                                | Not Available                      |
|                              | Batch mode on row store                                         | Not Available                      |
|                              | Cardinality estimate feedback *                                 | Not Available                      |
|                              | Degree of parallelism feedback *                                | Not Available                      |
|                              | Memory grant feedback persistence and percentile                | Not Available                      |
|                              | Row mode memory grant feedback                                  | Not Available                      |
|                              | Distributed partitioned views *                                 | Not Available                      |
|                              | Parallel index maintenance operations *                         | Not Available                      |
|                              | Automatic use of indexed view by query optimizer *              | Not Available                      |
|                              | Parallel consistency check                                      | Not Available                      |
|                              | SQL Server Utility Control Point                                | Not Available                      |
|                              | Advanced R integration 2                                        | Not Available                      |
|                              | Advanced Python integration                                     | Not Available                      |
|                              | Machine Learning Server (Standalone)                            | Not Available                      |
|                              | Query Store on secondary replicas                               | Not Available                      |
|                              | Star join Query optimizations                                   | Not Available                      |
|                              | Parallel query processing on partitioned tables and indexes     | Not Available                      |
|                              | Global Batch aggregation                                        | Not Available                      |


* Indicates features that may matter for the workload. 
The impact to Always on AG is the loss of Availability Groups as well as the restriction of two nodes. No impact to Partitioning or compression. 


4. Storage Optimization:

The proposed right-sizing of 4 TB (2 TB per EC2 Server Instance) and taking it down to 2.4 roughly 1.2TB per EC2 instance
As the table shows a total cost savings of $262.12


| Before                                                                             |                                       |
|------------------------------------------------------------------------------------|---------------------------------------|
| Pricing calculations                                                               | Price                                 |
| Storage amount: 4 TB x 1024 GB in a TB = 4096 GB                                   |                                       |
| 1,460 total EC2 hours / 730 hours in a month = 2.00 instance months                |                                       |
| 4,096 GB x 2.00 instance months x 0.08 USD                                         | 655.36 USD (EBS Storage Cost)         |
| 60,000 iops - 3000 GP3 iops free                                                   |                                       |
| Max (57000.00 iops, 0 minimum billable iops) = 57,000.00 total billable gp3 iops   |                                       |
| 57,000.00 iops x 2.00 instance months x 0.005 USD = 570.00 USD (EBS IOPS gp3 Cost) |                                       |
| 1,800 MBps - 125 GP3 MBps free = 1,675.00 billable MBps                            |                                       |
| Max (1675.00 MBps, 0 minimum mbps) = 1,675.00 billable throughput (MBps)           |                                       |
| 1,675.00 MBps / 1024 MB per GB = 1.6357 billable throughput (GBps)                 |                                       |
| 1.6357 GBps x 2.00 instance months x 40.96 USD                                     | 134.00 USD (EBS gp3 throughput Cost)  |
| 655.36 USD + 570.00 USD + 134.00 USD                                               | 1,359.36 USD (Total EBS storage cost) |
|                                                                                    |                                       |
| After                                                                              |                                       |
| Pricing calculations                                                               |                                       |
| Storage amount: 2.4 TB x 1024 GB in a TB = 2457.6 GB                               |                                       |
| 1,460 total EC2 hours / 730 hours in a month = 2.00 instance months                |                                       |
| 2,457.60 GB x 2.00 instance months x 0.08 USD                                      | 393.22 USD (EBS Storage Cost)         |
| EBS Storage Cost: 393.22 USD                                                       |                                       |
| 60,000 iops - 3000 GP3 iops free = 57,000.00 billable gp3 iops                     |                                       |
| Max (57000.00 iops, 0 minimum billable iops) = 57,000.00 total billable gp3 iops   |                                       |
| 57,000.00 iops x 2.00 instance months x 0.005 USD = 570.00 USD (EBS IOPS gp3 Cost) |                                       |
| 1,800 MBps - 125 GP3 MBps free = 1,675.00 billable MBps                            |                                       |
| Max (1675.00 MBps, 0 minimum mbps) = 1,675.00 billable throughput (MBps)           |                                       |
| 1,675.00 MBps / 1024 MB per GB = 1.6357 billable throughput (GBps)                 |                                       |
| 1.6357 GBps x 2.00 instance months x 40.96 USD                                     | 134.00 USD (EBS gp3 throughput Cost)  |
| 393.22 USD + 570.00 USD + 134.00 USD                                               | 1,097.22 USD (Total EBS storage cost) |













		
												
																								
															
																															
