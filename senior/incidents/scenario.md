# Incident Scenario — Migration Cutover Failure

## Alert Received

**Time**: 22:47 UTC, Saturday (during planned migration maintenance window)  
**Channel**: `#dbre-alerts-production` (auto-posted by Datadog → PagerDuty → Slack)

```
ALERT: DBA - lgc-apps-prod - RDS SQL Server Replication Lag for pro-scheduling-rds-01
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status:    ALERT (P1)
Metric:    aws.rds.replica_lag
Current:   247 seconds (and climbing)
Threshold: 30 seconds (critical)
Duration:  8 minutes
Instance:  pro-scheduling-rds-01 (SQL Server 2019, r5.4xlarge, Multi-AZ)
Region:    us-east-1
Account:   lgc-apps-prod
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Context

You are **mid-migration**. This is the planned cutover weekend from EC2 to RDS.

### What Has Happened So Far

1. **Friday 18:00 UTC**: Final full backup taken from EC2-SQLPROD-01, restored to pro-scheduling-rds-01 via native backup/restore to S3
2. **Friday 22:00 UTC**: Log shipping from EC2 to RDS started (transaction log backups every 5 minutes, restored to RDS with NORECOVERY)
3. **Saturday 20:00 UTC**: Application traffic redirected to maintenance page; log shipping gap closed to < 30 seconds
4. **Saturday 22:00 UTC**: Final log tail backup taken, restored to RDS with RECOVERY — database online
5. **Saturday 22:15 UTC**: DNS CNAME updated from EC2 endpoint to RDS endpoint
6. **Saturday 22:20 UTC**: Application servers restarted, traffic flowing to RDS
7. **Saturday 22:30 UTC**: Initial health checks pass — app is functional, queries executing
8. **Saturday 22:47 UTC**: THIS ALERT FIRES — replication lag on the Multi-AZ standby is climbing

### Additional Telemetry (from Datadog)

- **CPU**: 78% (elevated but not critical — was 35% on EC2 for same workload)
- **Write IOPS**: 12,400 (vs. provisioned 8,000 GP3 baseline + burst)
- **Read IOPS**: 3,200 (normal)
- **Free Storage**: 780 GB (healthy)
- **Network throughput**: 450 MB/s transmit (high — Multi-AZ sync replication)
- **Active connections**: 285 (normal for Saturday night)
- **Queue depth**: 14 (elevated)
- **Burst balance**: 22% (was 100% at 22:00 when cutover started)

### Team Situation

- You are the **migration lead** — you designed this cutover plan
- The VP of Engineering is on the bridge call monitoring the migration
- The app team lead is awake and available
- One junior DBA is shadowing you (learning opportunity)
- **Rollback window**: You have until 02:00 UTC Sunday (3 hours 13 minutes from now) to decide rollback. After 02:00, the old EC2 log chain is broken and rollback requires a full restore.

---

## Your Task

### Part 1: Immediate Diagnosis (10 min)

1. **Root Cause Analysis**: Based on the telemetry above, what is the most likely root cause of the replication lag? Explain the chain of events.
2. **First 3 Actions**: What do you do RIGHT NOW? Be specific — exact queries, AWS Console actions, or CLI commands.
3. **Rollback Decision Framework**: At what point do you recommend rolling back vs. fixing forward? Define specific metrics/thresholds that would trigger your rollback decision.

### Part 2: Resolution Path (15 min)

Assuming your diagnosis is correct:

4. **Immediate Fix**: What change do you make to resolve the lag without rolling back? Provide the exact AWS CLI command(s) or Console steps.
5. **Validation**: How do you confirm the fix worked? What metrics should stabilize, and in what order?
6. **SSIS Impact**: The nightly SSIS ETL job is scheduled to run at 01:00 UTC (1 hour 13 minutes away). Given the current state, what do you do about it? It currently runs on EC2-SQLPROD-03 connecting to the old EC2-SQLPROD-01 endpoint.

### Part 3: Communication (10 min)

7. **Bridge Call Update**: Write the 60-second verbal update you give to the VP of Engineering right now. Include: what's happening, impact assessment, your plan, and timeline.
8. **Slack Status Update**: Write the message for `#dbre-alerts-production`.
9. **Junior DBA Teaching Moment**: After the incident is resolved, write a 3-paragraph explanation for your junior DBA explaining what happened and what they should learn from it. Assume they've never seen a Multi-AZ replication lag event.

### Part 4: Post-Incident (10 min)

10. **Post-Incident Review**: Write the post-incident document (5–8 sentences) covering: timeline, root cause, resolution, what went wrong in planning, and what changes you'll make for the next migration (EC2-SQLPROD-02).
11. **Terraform Change**: What specific Terraform resource/attribute change would you make to prevent this in the future? (Just the relevant attribute, not a full .tf file)
