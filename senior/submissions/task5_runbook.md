This following procedure outlines the steps for performing a Point in Time Restore on an RDS instance.

Audience: This run book was written to both educate and assist anyone with little or no AWS RDS exposure has a solid understanding of SQL Server.

Acronyms: 
 - PITR = Stands for Point in Time Recovery
 - AWS CLI = AWS Command Line Interface

Perquisites and Considerations in order to perform PITR on and RDS database:
	-The database is online.
	-Its recovery model is set to FULL.
	-It's writable.
	-It has its physical files on the D: drive.
	-It's not listed in the rds_pitr_blocked_databases table.
	-Restored databases have the same name as in the source DB instance. You can't specify a different name.


Restoring and RDS Database from the AWS Console:

Step 1. Sign in to the AWS Management Console and open the Amazon RDS console at https://console.aws.amazon.com/rds/.

Step 2. In the navigation pane, choose Automated backups.

Step 3. Choose the RDS Custom DB instance that you want to restore.

Step 4. For Actions, choose Restore to point in time.

Step 5. The Restore to point in time window appears.

Step 6. Choose Latest restorable time to restore to the latest possible time, or choose Custom to choose a time.

Step 7. Choose Restore to point in time.


Note:
 	If you chose Custom, enter the date and time to which you want to restore the instance.
Times are shown in your local time zone, which is indicated by an offset from Coordinated Universal Time (UTC). For example, UTC-5 is Eastern Standard Time/Central Daylight Time.
For DB instance identifier, enter the name of the target restored RDS Custom DB instance. The name must be unique.
Choose other options as needed, such as DB instance class.


Restoring and RDS Database from the AWS CLI:

Step 1. In the AWS Console whilwe in the RDS database instance look for the >_ symbol next to the global search bar and notification bell.
Step 2. Click it to launch a secure shell window right at the bottom of your browser.
Step 3. In the CLI window, run the following:
   (This is using a test-instance name as an example)
 
   aws rds restore-db-instance-to-point-in-time \
    --source-db-instance-identifier test-instance \
    --target-db-instance restored-test-instance \
    --restore-time 2018-07-30T23:45:00.000Z

Step 4. Output will look something like the following:

{
    "DBInstance": {
        "AllocatedStorage": 20,
        "DBInstanceArn": "arn:aws:rds:us-east-1:123456789012:db:restored-test-instance",
        "DBInstanceStatus": "creating",
        "DBInstanceIdentifier": "restored-test-instance",
        ...some output omitted...
    }
}

Step 5. This finalizes the restore steps using the AWS CLI


What could go Wrong: 

Scenario 1. When attempting point-in-time-recovery (PITR) in RDS for SQL Server, you might encounter failures due to gaps in log sequence numbers.

Common causes for this issue are:

Manual changes to the database recovery model.
Automatic recovery model changes by RDS due to insufficient resources for completing transaction log backups.

Resolution:

Step 1. Identify LSN gaps in your database, run this query: From the query window in the console

SELECT * FROM msdb.dbo.rds_fn_list_tlog_backup_metadata(database_name)
ORDER BY backup_file_time_utc desc;

Step 2. If you discover an LSN gap, you can:

        - Choose a restore point before the LSN gap.
	-Wait and restore to a point after the next instance backup completes.


When to Escalate:

Please escalate to any Senior DBA for assistance with restores for any errors or issues.





