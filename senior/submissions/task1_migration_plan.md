1. Edition Decision: 
My recommendations are as follows:
Upgrade EC2-SQLPROD-01 (PRIMARY) to SQL Server 2025 Enterprise Version, utilizing the BYOM pricing model. 

There is no need to migrate EC2-SQLPROD-02 as it's just the secondary replica and can be used for either side by side upgrade of EC2-SQLPROD-03 to SQL Server 2025 or decommissioned. Replicas for EC2-SQLPROD-01 can be setup when configuring the Multi-AZ zones and read replicas. 
-SQL Server 2025 support (extended), is slated to extend to 2036. This will further reduce the need to upgrade to the latest edition for at least a 2 to 5 year period.
-SQL Server 2016 extended support ended July 14th 2026.
-TLS 1.3 supported natively
-RDS Windows Versions 2022
-SQL Server 2016 is also limited on what Windows version it can run on.

2. Migration Strategy: 

My recommendation for the migration strategy will be as follows: Backup and Restore to an S3 bucket. With this method since this also involves and upgrade of the SQL Server version, which happens as part of the restore, I propose the following methodology: 
-Full backup to S3 restore with no recovery
-Application taken down for cutover(Possibly here preferably)
-Differential backup to S3 restore with no recovery. Multiple as needed based on cutover date. (Prefer full and Diff be as close or on cutover date)
-Application taken down for cutover(Possibly, not as preferred depends on elapsed time between diff and cutover)
-Log(s) backup to S3, as little as possible. with recovery finish upgrade process.

From an RPO perspective this accomplishes minimal to no data loss and more granular control of the migration. This also has a built in rollback safety net since the application will be down and the cutover time is minimal post any validation testing. RTO will be measured in the allotted cutover time which could be safely set to two to three hours or less depending on dry run testing timings.

3. Downtime Window: 
 Down time window will be set to 3 hours.

Pre-Deployment Tasks: (Any tasks that happen a week or two prior to cutover)
-Deploy Memory-Optimized R-Family RDS instance
-Configure Drive Specs EBS Logical Data. Log, TempDB
-Migrate any SQL Server Standard accounts (sp_helpRevlogin)
-Operators
-Alerts if any
-RDS Parameter Group settings(Such as Max-DOP, Cost threshold for Parallelism, Set min and Max Memory)
-Restore Full backup with No recovery(At the longest 1 week with Daily Differentials)
-Could potentially configure EFS drive for faster backups and restores for this temporary purpose.(Performed in a past life)

Migration Day (Cutover):

-Differential backup and restored no-recovery 5 to 10 min
- DBA's disable jobs on source server
-Open Bridge
-Application Team takes down app servers    30 to 60 min 
-DBA's ensure no connections to database(s) 10 min
-Final Log backup          5 min 
-Restore final log backup  5 min 
-Complete upgrade process 20 to 30 min
-DBA validations 5 to 10 min
-Application Team brings app servers up pointing to new RDS instance 30 to 60 min
-Validation testing        30 min
-Pass, End of Cut- over
-Close Bridge

Post Migration:
-DBA's enable AWS automated backups
-Configure multi-AZ
-Configure Read Replica-Establish any monitoring outside of Cloudwatch


-----Rollback Plan if applicable--------------------------------
-DBA's re-enable application login if applicable      1 to 2 min
-Application team point application back to source server  30 min


4. SSIS Migration:

Basing my plan off of the following:

chrome-extension://efaidnbmnnnibpcajpcglclefindmkaj/https://docs.aws.amazon.com/pdfs/prescriptive-guidance/latest/migration-ssis-etl/migration-ssis-etl.pdf
https://aws.amazon.com/blogs/database/migrate-microsoft-sql-server-ssis-packages-to-amazon-rds-custom-for-sql-server/

My recommendations for SSIS would be as indicated in task 1. use EC2-SQLPROD-02 as the new server to conduct a side by side upgrade to SQL Server 2025 and migrate all 14 packages to the new server build.

Using the larger size server will also help reduce the 60% CPU usage due to the 2 extra cores


5. SSRS Migration:

Same as with task 4. 
My recommendations for SSRS would be as indicated in task 1. use EC2-SQLPROD-02 as the new server to conduct a side by side upgrade to SQL Server 2025 and migrate the 23 reports to the new server build.

Using the larger size server will also help reduce the 60% CPU usage due to the 2 extra cores.


6. Risk Register:

1. Risk- Application issues when migrating from SQL Server 2016 to SQL Server 2025.
         -Mitigation: Upgrade lower environments first with the same side by side migration steps. Allow time for testing phases unit, smoke and sign off for each environment.

2. Risk - Migration time exceeds estimated time and SLA is breached.
          -Mitigation: Conduct dry run migrations tracking times for each task in the migration plan ensuring the migration can complete without breaching the SLA. 

3. Risk - Not migrating SSIS packages to AWS Glue could leave us vulnerable to SSIS packages no longer being supported by Microsoft.
          -Start parallel testing and building out and migrating to AWS glue using the following method : https://docs.aws.amazon.com/SchemaConversionTool/latest/userguide/CHAP-converting-ssis-glue-studio.html

4. Risk - Database restore times could be slow from the S3 bucket
         -Mitigation: Deploy a temporary EFS volume to use for backup file staging and restores due to it's fast I/O throughput reducing restore times.

5. Risk - SQL Server 2025 upgrade introduces compatibility issues
        - Mitigation: Set the DB compatibility level to 2016.
    

















 