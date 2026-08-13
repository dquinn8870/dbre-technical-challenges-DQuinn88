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
/*
    Job Name: Nightly_Export_Analytics
    Schedule: Daily at 01:00 UTC
    Step 1: EXEC dbo.APPOINTMENT_Export_NightlyAnalytics
    On Failure: Notify operator "DBA-OnCall"
    Retry: 2 attempts, 5 min interval
*/
