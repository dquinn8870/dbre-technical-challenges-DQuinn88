/*
    Schema: dbo
    Purpose: Nightly data export procedure — extracts appointment summaries
             and ships to downstream analytics system
    Environment: SQL Server 2019 Enterprise on EC2 (self-managed)
    Dependencies: xp_cmdshell, linked server [ANALYTICS-DW], SQL Agent Job "Nightly_Export"
    Last modified: 2025-01-20
    Octopus Step: N/A (manual deployment, pre-migration refactor target)
*/

-- =============================================================================
-- PROCEDURE: APPOINTMENT_Export_NightlyAnalytics
-- Called by SQL Agent job at 01:00 UTC daily
-- Exports previous day's appointment data to CSV, then pushes to analytics DW
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.APPOINTMENT_Export_NightlyAnalytics
    @ExportDate DATETIME = NULL,
    @ArnS3Bucket NVARCHAR(500) = 'arn:aws:s3:::my-Nightlyanalytics-exports'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Default to yesterday
    IF @ExportDate IS NULL
        SET @ExportDate = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));

    DECLARE @FileName       VARCHAR(200);
	DECLARE @LocalDir       NVARCHAR(300) = N'D:\S3\';
    DECLARE @LocalFullPath  NVARCHAR(500) = @LocalDir + @FileName;
    DECLARE @RowCount        INT          = 0;
    DECLARE @CancelledCount INT           = 0;
    DECLARE @AvgDuration    DECIMAL(9,2)  = 0;
    DECLARE @TaskId         INT;

    SET @FileName = 'appointments_' + CONVERT(VARCHAR(8), @ExportDate, 112) + '.csv';
    SET @FullPath = @ArnS3Bucket + @FileName;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Create staging table with export data
         IF OBJECT_ID('dbo.APPOINTMENT_Export_Staging') IS NULL
        BEGIN
            CREATE TABLE dbo.APPOINTMENT_Export_Staging
            (
                export_date       DATE          NOT NULL,
                appointment_id    BIGINT        NOT NULL,
                appointment_date  DATETIME2(0)  NOT NULL,
                duration_minutes  INT           NULL,
                status            VARCHAR(30)   NULL,
                provider_id       INT           NULL,
                provider_name     NVARCHAR(100) NULL,
                specialty         NVARCHAR(100) NULL,
                location_id       INT           NULL,
                created_at        DATETIME2(0)  NULL,
                cancelled_at      DATETIME2(0)  NULL,
                CONSTRAINT PK_APPOINTMENT_Export_Staging
                    PRIMARY KEY (export_date, appointment_id)
            );
        END;

        BEGIN TRANSACTION;

        DELETE FROM dbo.APPOINTMENT_Export_Staging
        WHERE export_date = @ExportDate;

        INSERT INTO dbo.APPOINTMENT_Export_Staging
        (export_date, appointment_id, appointment_date, duration_minutes, status,
         provider_id, provider_name, specialty, location_id, created_at, cancelled_at)
        SELECT
            @ExportDate,
            a.id,
            a.appointment_date,
            a.duration_minutes,
            a.status,
            a.provider_id,
            p.last_name,
            p.specialty,
            a.location_id,
            a.created_at,
            a.cancelled_at
        FROM dbo.APPOINTMENT a
        INNER JOIN dbo.PROVIDER  p ON p.provider_id = a.provider_id
        WHERE a.appointment_date >= @ExportDate
          AND a.appointment_date <  DATEADD(DAY, 1, @ExportDate);

        SET @RowCount = @@ROWCOUNT;

        SELECT
            @CancelledCount = SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END),
            @AvgDuration    = AVG(CASE WHEN status <> 'cancelled'
                                       THEN CAST(duration_minutes AS DECIMAL(9,2)) END)
        FROM dbo.APPOINTMENT_Export_Staging
        WHERE export_date = @ExportDate;

        INSERT INTO dbo.EXPORT_LOG (export_date, file_name, row_count, status, completed_at)
        VALUES (@ExportDate, @FileName, @RowCount, 'STAGED', SYSUTCDATETIME());

        COMMIT TRANSACTION;
		
        DECLARE @Sql NVARCHAR(MAX) = N'
            SELECT appointment_id, appointment_date, duration_minutes, status,
                   provider_id, provider_name, specialty, location_id,
                   created_at, cancelled_at
            FROM dbo.APPOINTMENT_Export_Staging
            WHERE export_date = @d
            ORDER BY appointment_id';

 ------------------------------------------------------------------
        -- Step 3: Upload the file from D:\S3\ to S3 (async task).
        ------------------------------------------------------------------
        EXEC msdb.dbo.rds_upload_to_s3
             @rds_file_path       = @LocalFullPath,
             @s3_arn_of_file      = @S3BucketArn,
             @overwrite_file      = 1,
             @task_id             = @TaskId OUTPUT;

        ------------------------------------------------------------------
        -- Step 4: Poll the task until it completes (bounded wait).
        ------------------------------------------------------------------
        DECLARE @Status NVARCHAR(50) = N'CREATED';
        DECLARE @Waits  INT = 0;

        WHILE @Status IN (N'CREATED', N'IN_PROGRESS') AND @Waits < 60
        BEGIN
            WAITFOR DELAY '00:00:05';
            SELECT @Status = lifecycle
            FROM msdb.dbo.rds_fn_task_status(NULL, @TaskId);
            SET @Waits += 1;
        END;

        IF @Status <> N'SUCCESS'
            RAISERROR('S3 upload task %d ended with status %s', 16, 1, @TaskId, @Status);

        ------------------------------------------------------------------
        -- Step 5: Push summary to the DW. Prefer a linked server created
        -- via sp_addlinkedserver with a SQL login. Parameterize the call
        -- with sp_executesql instead of string concatenation.
        ------------------------------------------------------------------
        DECLARE @DwSql NVARCHAR(MAX) = N'
            INSERT INTO [ANALYTICS-DW].AnalyticsDB.dbo.APPOINTMENT_DAILY_SUMMARY
                (export_date, total_appointments, cancelled_count,
                 avg_duration, export_file, exported_at)
            VALUES (@d, @tot, @can, @avg, @f, SYSUTCDATETIME());';

        EXEC sys.sp_executesql
             @DwSql,
             N'@d DATE, @tot INT, @can INT, @avg DECIMAL(9,2), @f NVARCHAR(200)',
             @d   = @ExportDate,
             @tot = @RowCount,
             @can = @CancelledCount,
             @avg = @AvgDuration,
             @f   = @FileName;

        ------------------------------------------------------------------
        -- Step 6: Mark log row successful. (File retention is handled by
        -- an S3 lifecycle rule on the bucket — no SQL cleanup needed.)
        ------------------------------------------------------------------
        UPDATE dbo.EXPORT_LOG
        SET status = 'SUCCESS', completed_at = SYSUTCDATETIME()
        WHERE export_date = @ExportDate
          AND file_name   = @FileName
          AND status      = 'STAGED';

        ------------------------------------------------------------------
        -- Step 7: Notify (Database Mail must be enabled in the RDS
        -- option group and a profile named 'DBA Notifications' created).
        ------------------------------------------------------------------
        DECLARE @Subject NVARCHAR(200) = N'Nightly Export Complete: ' + @FileName;
        DECLARE @Body    NVARCHAR(1000) = CONCAT(
            N'Exported ', @RowCount, N' rows for ',
            CONVERT(VARCHAR(10), @ExportDate, 120),
            N'. Cancelled: ', @CancelledCount,
            N'. Avg duration: ', @AvgDuration, N' min.');

        EXEC msdb.dbo.sp_send_dbmail
             @profile_name = 'DBA Notifications',
             @recipients   = 'dba-team@company.com',
             @subject      = @Subject,
             @body         = @Body;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        INSERT INTO dbo.EXPORT_LOG
            (export_date, file_name, row_count, status, error_message, completed_at)
        VALUES
            (@ExportDate, @FileName, ISNULL(@RowCount, 0),
             'FAILED', ERROR_MESSAGE(), SYSUTCDATETIME());

        DECLARE @ErrSubject NVARCHAR(200) = N'FAILED: Nightly Export ' + ISNULL(@FileName, N'unknown');
        DECLARE @ErrBody    NVARCHAR(2000) = N'Error: ' + ERROR_MESSAGE();

        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                 @profile_name = 'DBA Notifications',
                 @recipients   = 'dba-team@company.com',
                 @subject      = @ErrSubject,
                 @body         = @ErrBody,
                 @importance   = 'High';
        END TRY
        BEGIN CATCH
            -- swallow mail failures so THROW still surfaces the real error
        END CATCH;

        THROW;
    END CATCH;
END
GO

-- =============================================================================
-- SQL Agent Job (reference only — this is what currently schedules the above)
-- =============================================================================
/*
    Job Name: Nightly_Export_Analytics
    Schedule: Daily at 01:00 UTC
    Step 1: EXEC dbo.APPOINTMENT_Export_NightlyAnalytics
    On Failure: Notify operator "DBA-OnCall"
    Retry: 2 attempts, 5 min interval
*/


---==================================================================================
-- Rollback. Un comment the below code and run
--
--=====================================================================================

/************************************************************************************
/*
    Schema: dbo
    Purpose: Nightly data export procedure — extracts appointment summaries
             and ships to downstream analytics system
    Environment: SQL Server 2019 Enterprise on EC2 (self-managed)
    Dependencies: xp_cmdshell, linked server [ANALYTICS-DW], SQL Agent Job "Nightly_Export"
    Last modified: 2025-01-20
    Octopus Step: N/A (manual deployment, pre-migration refactor target)
*/

-- =============================================================================
-- PROCEDURE: APPOINTMENT_Export_NightlyAnalytics
-- Called by SQL Agent job at 01:00 UTC daily
-- Exports previous day's appointment data to CSV, then pushes to analytics DW
-- =============================================================================

CREATE PROCEDURE dbo.APPOINTMENT_Export_NightlyAnalytics
    @ExportDate DATETIME = NULL,
    @OutputPath VARCHAR(500) = 'D:\SQLExports\Analytics\'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Default to yesterday
    IF @ExportDate IS NULL
        SET @ExportDate = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));

    DECLARE @FileName VARCHAR(200);
    DECLARE @FullPath VARCHAR(700);
    DECLARE @CMD VARCHAR(2000);
    DECLARE @RowCount INT;
    DECLARE @LinkedServerQuery NVARCHAR(MAX);

    SET @FileName = 'appointments_' + CONVERT(VARCHAR(8), @ExportDate, 112) + '.csv';
    SET @FullPath = @OutputPath + @FileName;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: Create staging table with export data
        IF OBJECT_ID('tempdb..#ExportStaging') IS NOT NULL
            DROP TABLE #ExportStaging;

        SELECT
            a.id AS appointment_id,
            a.appointment_date,
            a.duration_minutes,
            a.status,
            a.provider_id,
            p.last_name AS provider_name,
            p.specialty,
            a.location_id,
            a.created_at,
            a.cancelled_at
        INTO #ExportStaging
        FROM dbo.APPOINTMENT a
        INNER JOIN dbo.PROVIDER p ON a.provider_id = p.provider_id
        WHERE a.appointment_date >= @ExportDate
          AND a.appointment_date < DATEADD(DAY, 1, @ExportDate);

        SET @RowCount = @@ROWCOUNT;

        -- Step 2: Export to CSV using xp_cmdshell + bcp
        SET @CMD = 'bcp "SELECT * FROM #ExportStaging" queryout "' + @FullPath + '" -c -t"," -T -S ' + @@SERVERNAME;

        EXEC master.dbo.xp_cmdshell @CMD, no_output = 1;

        -- Step 3: Verify file exists
        DECLARE @FileExists INT;
        EXEC master.dbo.xp_fileexist @FullPath, @FileExists OUTPUT;

        IF @FileExists = 0
        BEGIN
            RAISERROR('Export file was not created: %s', 16, 1, @FullPath);
        END

        -- Step 4: Push summary to analytics data warehouse via linked server
        SET @LinkedServerQuery = '
            INSERT INTO [ANALYTICS-DW].AnalyticsDB.dbo.APPOINTMENT_DAILY_SUMMARY
            (export_date, total_appointments, cancelled_count, avg_duration, export_file, exported_at)
            VALUES (
                ''' + CONVERT(VARCHAR(10), @ExportDate, 120) + ''',
                ' + CAST(@RowCount AS VARCHAR) + ',
                (SELECT COUNT(*) FROM #ExportStaging WHERE status = ''cancelled''),
                (SELECT AVG(duration_minutes) FROM #ExportStaging WHERE status != ''cancelled''),
                ''' + @FileName + ''',
                GETDATE()
            )';

        EXEC (@LinkedServerQuery);

        -- Step 5: Log success to SQL Agent job history (custom table)
        INSERT INTO dbo.EXPORT_LOG (export_date, file_name, row_count, status, completed_at)
        VALUES (@ExportDate, @FileName, @RowCount, 'SUCCESS', GETDATE());

        -- Step 6: Clean up old export files (keep 30 days)
        SET @CMD = 'forfiles /p "D:\SQLExports\Analytics" /m *.csv /d -30 /c "cmd /c del @file"';
        EXEC master.dbo.xp_cmdshell @CMD, no_output = 1;

        COMMIT TRANSACTION;

        -- Step 7: Notify via Database Mail
        DECLARE @Subject VARCHAR(200) = 'Nightly Export Complete: ' + @FileName;
        DECLARE @Body VARCHAR(500) = 'Exported ' + CAST(@RowCount AS VARCHAR) + ' rows for ' + CONVERT(VARCHAR(10), @ExportDate, 120);

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'DBA Notifications',
            @recipients = 'dba-team@company.com',
            @subject = @Subject,
            @body = @Body;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Log failure
        INSERT INTO dbo.EXPORT_LOG (export_date, file_name, row_count, status, error_message, completed_at)
        VALUES (@ExportDate, @FileName, 0, 'FAILED', ERROR_MESSAGE(), GETDATE());

        -- Notify failure
        DECLARE @ErrSubject VARCHAR(200) = 'FAILED: Nightly Export ' + ISNULL(@FileName, 'unknown');
        DECLARE @ErrBody VARCHAR(1000) = 'Error: ' + ERROR_MESSAGE();

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'DBA Notifications',
            @recipients = 'dba-team@company.com',
            @subject = @ErrSubject,
            @body = @ErrBody,
            @importance = 'High';

        THROW;
    END CATCH
END
GO

-- =============================================================================
-- SQL Agent Job (reference only — this is what currently schedules the above)
-- =============================================================================


*************************************************************************************/