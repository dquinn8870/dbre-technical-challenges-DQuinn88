# DBRE Technical Challenge — Senior Database Administrator

## Welcome

Thank you for taking the time to complete this technical challenge. This exercise evaluates your ability to lead database modernization efforts, design migration strategies, optimize costs, and mentor teams — all within a regulated healthcare environment.

**Time expectation**: ~3 hours of focused effort. You have 5 days from receiving this repo to submit your answers.

**Important**: After submission, you will be invited to a 45–60 minute live call where we'll discuss your solutions, challenge your architecture decisions, and ask you to extend your designs live. Be prepared to defend trade-offs, explain failure modes, and demonstrate hands-on expertise.

---

## Environment Context

You are being evaluated for a Senior DBA role leading the database modernization effort for a healthcare platform. The environment:

- **Current State**: SQL Server 2016 on self-managed EC2 instances (Windows Server 2016)
- **Target State**: AWS RDS for SQL Server (Multi-AZ)
- **SSIS**: Currently runs ETL packages on the EC2 hosts (SQL Server Agent jobs)
- **SSRS**: Report server co-located on one of the EC2 instances
- **Compliance**: HITRUST E1, HIPAA — encryption at rest (KMS), in transit (TLS), audit logging mandatory
- **Monitoring**: Datadog + CloudWatch (transitioning from legacy SQL Agent alerts)
- **IaC**: Terraform for RDS infrastructure
- **Migrations**: Flyway via Octopus Deploy
- **Team**: You will mentor 2 junior SQL DBAs who have no cloud experience

### Current EC2 Database Landscape

| Instance | Role | Edition | Size | Storage | Avg CPU |
|----------|------|---------|------|---------|---------|
| `EC2-SQLPROD-01` | Primary (AG listener) | Enterprise | r5.4xlarge | 2TB GP3 | 45% |
| `EC2-SQLPROD-02` | Secondary (sync replica) | Enterprise | r5.4xlarge | 2TB GP3 | 12% |
| `EC2-SQLPROD-03` | SSIS/SSRS + Reporting replica | Standard | r5.2xlarge | 800GB GP2 | 60% |

Key standards (same as junior challenge):
- All DDL must be **idempotent** (safe to re-run)
- No exclusive table locks on production tables during deployments
- Error handling uses `BEGIN TRY / BEGIN CATCH` with `XACT_ABORT ON`
- No `SELECT *`, no cursors, no triggers
- SQL keywords in UPPERCASE, columns explicitly listed

---

## Tasks

### Task 1 — Migration Architecture (45 min)

You are tasked with planning the migration of `EC2-SQLPROD-01` and `EC2-SQLPROD-02` to AWS RDS for SQL Server.

**Your job**: Create `submissions/task1_migration_plan.md` containing:

1. **Edition Decision**: The EC2 instances run Enterprise Edition. RDS supports Enterprise and Standard. Make a recommendation with cost/feature justification. Consider: Always On AG, compression, online index operations, partitioning.
2. **Migration Strategy**: Choose between AWS DMS, native backup/restore to S3, or log shipping. Justify your choice with RPO/RTO targets for a healthcare system (propose appropriate values).
3. **Downtime Window**: Propose a cutover approach that minimizes downtime. Detail the sequence of steps, rollback plan, and validation checks.
4. **SSIS Migration**: `EC2-SQLPROD-03` runs 14 SSIS packages via SQL Agent. RDS does not support SQL Agent or SSIS. Propose an architecture for these ETL workloads post-migration (consider: AWS Glue, Step Functions + Fargate, standalone EC2 SSIS host, or other).
5. **SSRS Migration**: The SSRS instance serves 23 operational reports used by clinical staff daily. Propose the target architecture (consider: standalone EC2/Fargate SSRS, migration to QuickSight, Power BI Service, or hybrid).
6. **Risk Register**: List the top 5 risks for this migration and your proposed mitigation for each.

---

### Task 2 — Cost Optimization (30 min)

Leadership wants a 30% cost reduction on the database tier within 6 months of migration completion.

**Your job**: Create `submissions/task2_cost_optimization.md` containing:

1. **Current Cost Estimate**: Based on the instance table above, estimate the monthly EC2+licensing cost (use public AWS pricing for us-east-1, SQL Server license-included pricing for EC2).
2. **Proposed RDS Architecture**: Recommend instance types, Multi-AZ configuration, storage type, and Reserved Instance strategy.
3. **Edition Downgrade Analysis**: If you downgrade from Enterprise to Standard on RDS, list every feature you lose and which ones actually matter for this workload. Include impact on existing Always On AG, compression, and partitioning.
4. **Storage Optimization**: The 2TB GP3 volumes are only 58% utilized. Propose a storage right-sizing plan including IOPS/throughput calculations.
5. **Total Projected Savings**: Show a before/after cost comparison table with line items.

---

### Task 3 — Monitoring & Observability Design (25 min)

Open `monitoring/multi_instance_monitors.yml`. This file contains a set of Datadog monitor definitions for the new RDS fleet. Several have issues.

**Your job**: Create `submissions/task3_fixed_monitors.yml` that:

1. Fixes all issues in the provided monitors (thresholds, routing, tags, naming)
2. Adds a **composite monitor** that only pages when 2+ instances are simultaneously critical
3. Adds a **forecast monitor** for storage utilization that alerts 14 days before projected exhaustion
4. Implements proper **scheduled muting** configuration for the Sunday night ETL batch window (23:00–00:30 UTC)
5. Includes a **replication lag** monitor appropriate for Multi-AZ RDS SQL Server

---

### Task 4 — Migration Script & Rollback (30 min)

You need to modify a critical stored procedure as part of the migration preparation. The procedure currently uses features not supported on RDS (xp_cmdshell, linked servers, SQL Agent).

Open `schema/pre_migration_refactor.sql`. This contains the current procedure.

**Your job**: Create `submissions/task4_refactored_procedure.sql` that:

1. Refactors the procedure to remove all RDS-incompatible features
2. Replaces file system operations with S3 integration (using `msdb.dbo.rds_backup_database` patterns or SQS)
3. Replaces linked server calls with an alternative approach (document what the application team needs to change)
4. Maintains identical business logic and output
5. Includes a rollback script that restores the original procedure
6. Is fully idempotent with proper error handling

---

### Task 5 — Team Mentoring & Documentation (20 min)

You are responsible for upskilling 2 junior DBAs who have only worked with on-premises SQL Server.

**Your job**: Create `submissions/task5_runbook.md` — a runbook for one of these common RDS operations:

**Choose one**:
- (A) "How to perform a point-in-time restore on RDS SQL Server"
- (B) "How to investigate and resolve high CPU on RDS SQL Server (no OS access)"
- (C) "How to apply a parameter group change that requires reboot"

The runbook must:
1. Be written for someone with zero AWS experience but solid SQL Server skills
2. Include exact AWS Console steps AND equivalent CLI commands
3. Include a "What can go wrong" section with failure modes and recovery steps
4. Include validation checks to confirm the operation succeeded
5. Include a "When to escalate" decision tree

---

## Submission

1. Place all answers in the `submissions/` folder
2. Do NOT modify files in `schema/`, `monitoring/`, or `incidents/`
3. Commit your work and push to this branch
4. Reply to the Greenhouse email confirming your submission

---

## Evaluation Criteria

| Criteria | Weight |
|----------|--------|
| Architecture & systems thinking | 25% |
| Migration expertise (EC2 → RDS, SSIS, SSRS) | 25% |
| Cost awareness & business justification | 15% |
| Production safety & failure mode analysis | 15% |
| Mentoring clarity (can a junior follow your docs?) | 10% |
| Communication & trade-off articulation | 10% |

**Note**: There are intentional constraints and trade-offs baked into these tasks. We want to see how you navigate ambiguity, where you push back, and how you communicate risk. Perfect answers don't exist — thoughtful, justified decisions do.

---

## Rules

- You may use documentation and references (AWS Docs, Microsoft Docs, Datadog Docs, Terraform Registry)
- You may NOT use AI assistants to generate your answers, but you can use them to reason through problems — you will need to defend every decision live
- You will be asked to extend your architecture and modify your code live during the follow-up call
- If anything is unclear, email your recruiter — asking good questions is a positive signal

Good luck!
