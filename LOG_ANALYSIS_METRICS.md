# Log Analysis Metrics - Daemon Performance Monitoring

**Created:** 2025-12-22  
**Purpose:** Reference document defining what metrics to collect from logs for daemon performance analysis  
**Current Baseline:** 2025-12-22 23:30 UTC

---

## Purpose

This document defines the key metrics and components that should be collected from logs for:
- Detecting performance improvements or degradations
- Identifying issues early
- Comparing performance between different versions/configurations
- Establishing alerts and thresholds
- Providing context for AI-assisted analysis

---

## Metric Categories

### 1. Complete Cycle Metrics
### 2. Data Processing Metrics
### 3. Insertion Stage Metrics
### 4. Optimization Metrics
### 5. System Health Metrics

---

## 1. Complete Cycle Metrics

### 1.1 Total Cycle Time

**Description:** Total time for a complete daemon cycle from start to completion.

**What to collect:**
- Cycle completion timestamp
- Cycle duration in seconds
- Cycle number (if available)

**SQL Query:**
```sql
SELECT 
  timestamp,
  CAST(SUBSTRING(message FROM 'Cycle ([0-9]+) completed successfully in ([0-9]+) seconds') AS INTEGER) as cycle_duration_seconds,
  CAST(SUBSTRING(message FROM 'Cycle ([0-9]+)') AS INTEGER) as cycle_number
FROM logs
WHERE message LIKE '%Cycle%completed successfully%'
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Calculations to perform:**
- Average (seconds)
- Minimum (seconds)
- Maximum (seconds)
- Median (seconds)
- 95th percentile (seconds)
- Standard deviation
- Total cycles

**Current Baseline (2025-12-22 23:47 UTC):**
- Average: 8.5 seconds
- Typical range: 8-10 seconds
- Median: 8 seconds
- Sample: 30 recent cycles

**Recommended thresholds:**
- ⚠️ Warning: > 15 seconds (95th percentile)
- 🚨 Critical: > 30 seconds or repeated failures

---

### 1.2 Cycle Frequency

**Description:** Number of cycles completed in a time period.

**What to collect:**
- Cycle completion timestamps
- Total cycles in period
- Time span of period

**SQL Query:**
```sql
SELECT 
  COUNT(*) as cycles_completed,
  MIN(timestamp) as first_cycle,
  MAX(timestamp) as last_cycle,
  ROUND(EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp))) / NULLIF(COUNT(*), 0), 2) as average_interval_seconds,
  ROUND(COUNT(*)::NUMERIC / NULLIF(EXTRACT(EPOCH FROM (MAX(timestamp) - MIN(timestamp))) / 3600.0, 0), 2) as cycles_per_hour
FROM logs
WHERE message LIKE '%Cycle%completed successfully%'
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Current Baseline (2025-12-22 23:30 UTC):**
- ~60 cycles per hour (1 cycle per minute)
- Average interval: ~60 seconds

---

### 1.3 Cycle Success Rate

**Description:** Percentage of cycles that complete successfully vs fail.

**What to collect:**
- Cycle completion messages (success)
- Cycle failure messages
- Total cycle attempts

**SQL Query:**
```sql
SELECT 
  COUNT(*) FILTER (WHERE message LIKE '%completed successfully%') as successful,
  COUNT(*) FILTER (WHERE message LIKE '%failed%' OR message LIKE '%ERROR%') as failed,
  COUNT(*) as total,
  ROUND(100.0 * COUNT(*) FILTER (WHERE message LIKE '%completed successfully%') / NULLIF(COUNT(*), 0), 2) as success_rate_pct
FROM logs
WHERE (message LIKE '%Cycle%' AND (message LIKE '%completed%' OR message LIKE '%failed%'))
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Current Baseline (2025-12-22 23:30 UTC):**
- Success rate: ~100% (0 errors detected)

**Recommended thresholds:**
- ⚠️ Warning: < 95%
- 🚨 Critical: < 90%

---

## 2. Data Processing Metrics

### 2.1 Notes Processed per Cycle

**Description:** Number of notes processed (new + updated) in each cycle.

**What to collect:**
- Timestamp of processing start
- Number of notes to be inserted
- Cycle identifier (if available)

**SQL Query:**
```sql
SELECT 
  timestamp,
  CAST(SUBSTRING(message FROM 'bulk insertion of ([0-9]+) notes') AS INTEGER) as notes_to_process
FROM logs
WHERE message LIKE '%Lock validated. Starting bulk insertion of%'
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Calculations to perform:**
- Average notes per cycle
- Minimum
- Maximum
- Median
- Total notes processed in period

**Current Baseline (2025-12-22 23:47 UTC):**
- Average: 2.44 notes per cycle
- Typical range: 1-16 notes
- Total in 2 hours: 276 notes (113 cycles)

---

### 2.2 Breakdown: New vs Updated Notes

**Description:** Separation between new notes and updated notes.

**What to collect:**
- Number of new notes inserted
- Number of notes updated
- Timestamp

**SQL Query:**
```sql
SELECT 
  timestamp,
  CAST(SUBSTRING(message FROM 'New: ([0-9]+)') AS INTEGER) as new_notes,
  CAST(SUBSTRING(message FROM 'Updated: ([0-9]+)') AS INTEGER) as updated_notes,
  CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC) as duration_ms
FROM logs
WHERE message LIKE '%[TIMING]%Bulk INSERT notes%'
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Calculations to perform:**
- Average new notes per cycle
- Average updated notes per cycle
- Total new notes
- Total updated notes
- Ratio new/updated

**Current Baseline (2025-12-22 23:47 UTC):**
- Average new: 0.54 notes per cycle
- Average updated: 1.90 notes per cycle
- Total new: 61 notes (113 cycles)
- Total updated: 215 notes (113 cycles)
- Ratio new/updated: ~1:3.5

---

## 3. Insertion Stage Metrics

### 3.1 Time per Stage [TIMING]

**Description:** Execution time of each individual stage measured with [TIMING] logs.

**What to collect:**
- Stage name
- Execution duration (milliseconds)
- Timestamp
- Stage state (executed/skipped if applicable)

**SQL Query:**
```sql
SELECT 
  timestamp,
  SUBSTRING(message FROM 'Stage: ([^-]+)') as stage_name,
  CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC) as duration_ms,
  CASE 
    WHEN message LIKE '%SKIPPED%' THEN 'Skipped'
    ELSE 'Executed'
  END as state
FROM logs
WHERE message LIKE '%[TIMING]%'
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Key stages to monitor:**

1. **Bulk INSERT notes** (slowest stage)
   - Baseline: 6.15ms average
   - Range: 1.18ms - 17.85ms
   - Warning threshold: > 20ms average

2. **Bulk INSERT comments**
   - Baseline: 1.17ms average
   - Range: 0.23ms - 3.66ms
   - Warning threshold: > 10ms average

3. **Bulk INSERT users**
   - Baseline: 0.40ms average
   - Warning threshold: > 2ms average

4. **Count existing notes**
   - Baseline: 0.59ms average
   - Warning threshold: > 2ms average

5. **Count existing comments**
   - Baseline: 0.33ms average
   - Warning threshold: > 2ms average

6. **Integrity check**
   - Baseline: 0.35ms average (226 executions)
   - Warning threshold: > 1ms average

7. **Validate lock**
   - Baseline: 0.52ms average
   - Warning threshold: > 2ms average

**Current Baseline - All Stages (2025-12-22 23:30 UTC):**

| Stage | State | Frequency | Average (ms) | Min (ms) | Max (ms) |
|-------|-------|-----------|--------------|----------|----------|
| ANALYZE notes | Executed | 1 | 272.08 | 272.08 | 272.08 |
| Bulk INSERT notes | Executed | 113 | 6.15 | 1.18 | 17.85 |
| Synchronize sequences check | Skipped | 113 | 1.86 | 1.41 | 2.80 |
| Bulk INSERT comments | Executed | 113 | 1.17 | 0.23 | 3.66 |
| Count existing notes | Executed | 113 | 0.59 | 0.46 | 1.23 |
| Validate lock | Executed | 113 | 0.52 | 0.51 | 0.54 |
| ANALYZE notes check | Skipped | 112 | 0.49 | 0.46 | 0.58 |
| Bulk INSERT users | Executed | 113 | 0.40 | 0.24 | 1.21 |
| Integrity check | Executed | 226 | 0.35 | 0.14 | 0.76 |
| Count existing comments | Executed | 113 | 0.33 | 0.24 | 0.94 |
| Check notes_api count | Executed | 113 | 0.27 | 0.26 | 0.29 |
| ANALYZE note_comments check | Skipped | 113 | 0.25 | 0.24 | 0.29 |
| Check note_comments_api count | Executed | 113 | 0.14 | 0.11 | 0.41 |

**Note:** ANALYZE notes shows 1 execution with 272ms (periodic execution when threshold is met). This is expected behavior.

---

### 3.2 Conditional Stage States

**Description:** For stages that can be skipped or executed, monitor the frequency of each state.

**Conditional stages:**

1. **ANALYZE notes check**
   - States: Skipped / Executed
   - Baseline: 99% skipped (112/113 cycles), 1% executed (1/113 cycles - periodic)
   - Time when skipped: 0.49ms average
   - Time when executed: 272.08ms (expected when threshold met)
   - Monitor: Execution frequency (should be low, periodic only)

2. **ANALYZE note_comments check**
   - States: Skipped / Executed
   - Baseline: 100% skipped (113/113 cycles)
   - Time when skipped: 0.25ms average
   - Monitor: Execution frequency (should be low)

3. **Synchronize sequences**
   - States: Skipped / Executed
   - Baseline: 100% skipped (113/113 cycles for check), executions are separate
   - Time when skipped (check): 1.86ms average
   - Time when executed: Not shown in current data (separate log entry)
   - Monitor: Skip/execute ratio (should increase % skipped over time)

**SQL Query:**
```sql
SELECT 
  SUBSTRING(message FROM 'Stage: ([^-]+)') as stage_name,
  CASE 
    WHEN message LIKE '%SKIPPED%' THEN 'Skipped'
    ELSE 'Executed'
  END as state,
  COUNT(*) as frequency,
  ROUND(AVG(CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC)), 2) as average_ms
FROM logs
WHERE message LIKE '%[TIMING]%'
  AND (message LIKE '%ANALYZE%check%' OR message LIKE '%Synchronize sequences%')
  AND timestamp > NOW() - INTERVAL '<period>'
GROUP BY stage_name, state;
```

---

## 4. Optimization Metrics

### 4.1 ANALYZE Checks - Properties Cache

**Description:** Verify that ANALYZE timestamp caching is working.

**What to collect:**
- ANALYZE check execution times
- Whether check was skipped or executed
- Properties table timestamp values

**SQL Query:**
```sql
-- Verify properties keys exist
SELECT key, value, updated_at
FROM properties
WHERE key IN ('last_analyze_notes_timestamp', 'last_analyze_comments_timestamp');

-- Verify check time (should be < 1ms)
SELECT 
  AVG(CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC)) as average_ms
FROM logs
WHERE message LIKE '%[TIMING]%ANALYZE%check%'
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Current Baseline (2025-12-22 23:47 UTC):**
- ANALYZE notes check: 0.49ms average when skipped, 272.08ms when executed (periodic, expected)
- ANALYZE note_comments check: 0.25ms average (vs 848ms before optimization)
- Improvement: 99.97% for check operation (when skipped)

**Recommended thresholds:**
- ⚠️ Warning: > 5ms (indicates caching issue)
- 🚨 Critical: > 50ms (caching not working)

---

### 4.2 Integrity Check - EXISTS Optimization

**Description:** Verify that integrity check uses optimized EXISTS.

**What to collect:**
- Integrity check execution times
- Execution frequency

**SQL Query:**
```sql
SELECT 
  COUNT(*) as frequency,
  ROUND(AVG(CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC)), 2) as average_ms,
  ROUND(MIN(CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC)), 2) as min_ms,
  ROUND(MAX(CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC)), 2) as max_ms
FROM logs
WHERE message LIKE '%[TIMING]%Integrity check%'
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Current Baseline (2025-12-22 23:47 UTC):**
- Integrity check: 0.35ms average (vs 434ms before optimization)
- Frequency: 226 executions (2 per cycle)
- Improvement: 99.92%

**Recommended thresholds:**
- ⚠️ Warning: > 2ms average
- 🚨 Critical: > 10ms average

---

### 4.3 Conditional Sequence Synchronization

**Description:** Monitor the effectiveness of conditional sequence synchronization.

**What to collect:**
- Synchronization execution times
- Whether synchronization was skipped or executed
- Frequency of each state

**SQL Query:**
```sql
SELECT 
  CASE 
    WHEN message LIKE '%SKIPPED%' THEN 'Skipped'
    ELSE 'Executed'
  END as state,
  COUNT(*) as frequency,
  ROUND(AVG(CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC)), 2) as average_ms
FROM logs
WHERE message LIKE '%[TIMING]%Synchronize sequences%'
  AND timestamp > NOW() - INTERVAL '<period>'
GROUP BY state;
```

**Current Baseline (2025-12-22 23:47 UTC):**
- Check skipped: 113 cycles (100%), 1.86ms average
- Note: Actual synchronization execution is logged separately when needed
- Expected trend: Check should continue to be skipped when sequences are synchronized

---

## 5. System Health Metrics

### 5.1 Errors and Failures

**Description:** Number and type of errors in the system.

**What to collect:**
- Error messages
- Error timestamps
- Error frequency
- Error types (if categorized)

**SQL Query:**
```sql
SELECT 
  timestamp,
  message,
  COUNT(*) OVER (PARTITION BY DATE_TRUNC('hour', timestamp)) as errors_per_hour
FROM logs
WHERE (message LIKE '%ERROR%' OR message LIKE '%error%' OR message LIKE '%Error%' 
       OR message LIKE '%FAILED%' OR message LIKE '%failed%')
  AND timestamp > NOW() - INTERVAL '<period>'
ORDER BY timestamp DESC;
```

**Summary Query:**
```sql
SELECT 
  COUNT(*) as total_errors,
  COUNT(DISTINCT DATE_TRUNC('hour', timestamp)) as hours_with_errors,
  MIN(timestamp) as first_error,
  MAX(timestamp) as last_error
FROM logs
WHERE (message LIKE '%ERROR%' OR message LIKE '%error%' OR message LIKE '%Error%' 
       OR message LIKE '%FAILED%' OR message LIKE '%failed%')
  AND timestamp > NOW() - INTERVAL '<period>';
```

**Current Baseline (2025-12-22 23:47 UTC):**
- Total errors in 24 hours: 0
- Error rate: 0%

**Recommended thresholds:**
- ⚠️ Warning: > 1 error per hour
- 🚨 Critical: > 5 errors per hour or consecutive errors

---

### 5.2 Daemon Status

**Description:** Verify that the daemon is running and active.

**What to collect (from system logs, not DB):**
- Service status (systemctl)
- Process status (ps)
- Lock file status (if applicable)
- Last cycle completion time

**Commands:**
```bash
systemctl status osm-notes-ingestion-daemon.service
ps aux | grep processAPINotesDaemon
```

**Checks:**
- Service status: should be "active (running)"
- Active process
- Lock file present (if applicable)
- Last cycle completed recently (< 5 minutes)

---

## Consolidated Queries for Log Collection

### Query 1: Complete Cycle Summary

**Purpose:** Collect all cycle completion data for a period.

```sql
SELECT 
  timestamp,
  CAST(SUBSTRING(message FROM 'Cycle ([0-9]+) completed successfully in ([0-9]+) seconds') AS INTEGER) as cycle_duration_seconds,
  CAST(SUBSTRING(message FROM 'Cycle ([0-9]+)') AS INTEGER) as cycle_number
FROM logs
WHERE message LIKE '%Cycle%completed successfully%'
  AND timestamp > NOW() - INTERVAL '<period>'
ORDER BY timestamp DESC;
```

### Query 2: All Stage Timing Metrics

**Purpose:** Collect all [TIMING] stage data for analysis.

```sql
SELECT 
  timestamp,
  SUBSTRING(message FROM 'Stage: ([^-]+)') as stage_name,
  CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC) as duration_ms,
  CASE 
    WHEN message LIKE '%SKIPPED%' THEN 'Skipped'
    ELSE 'Executed'
  END as state,
  message as full_message
FROM logs
WHERE message LIKE '%[TIMING]%'
  AND timestamp > NOW() - INTERVAL '<period>'
ORDER BY timestamp DESC, duration_ms DESC;
```

### Query 3: Notes Processing Data

**Purpose:** Collect notes processing information.

```sql
SELECT 
  timestamp,
  CAST(SUBSTRING(message FROM 'bulk insertion of ([0-9]+) notes') AS INTEGER) as notes_to_process
FROM logs
WHERE message LIKE '%Lock validated. Starting bulk insertion of%'
  AND timestamp > NOW() - INTERVAL '<period>'
ORDER BY timestamp DESC;
```

### Query 4: Bulk INSERT Notes Breakdown

**Purpose:** Collect detailed breakdown of new vs updated notes.

```sql
SELECT 
  timestamp,
  CAST(SUBSTRING(message FROM 'New: ([0-9]+)') AS INTEGER) as new_notes,
  CAST(SUBSTRING(message FROM 'Updated: ([0-9]+)') AS INTEGER) as updated_notes,
  CAST(SUBSTRING(message FROM 'Duration: ([0-9.]+)') AS NUMERIC) as duration_ms
FROM logs
WHERE message LIKE '%[TIMING]%Bulk INSERT notes%'
  AND timestamp > NOW() - INTERVAL '<period>'
ORDER BY timestamp DESC;
```

---

## Recommended Collection Frequency

### Real-time Monitoring
- Daemon status: Every 5 minutes
- Errors: Immediate alert

### Periodic Collection
- Cycle metrics: Every hour (summary of last hour)
- Stage metrics: Every hour (summary of last hour)
- Optimization metrics: Every 4 hours
- System resources: Every hour

### Long-term Analysis
- Trend analysis: Daily (compare day to day)
- Complete analysis: Weekly (compare week to week)
- Baseline update: Monthly (update reference values)

---

## Suggested Analysis Workflow

### Step 1: Collect Raw Data
Use the consolidated queries above to extract raw log data for the desired time period.

### Step 2: Calculate Aggregates
Calculate:
- Averages
- Min/Max values
- Percentiles (50th, 95th, 99th)
- Frequency distributions
- Success rates

### Step 3: Compare to Baseline
Compare current values to baseline values documented in this document.

### Step 4: Identify Anomalies
Flag metrics that exceed thresholds or show significant deviations.

### Step 5: Generate Report
Create a summary report with:
- Current values
- Comparison to baseline
- Anomalies detected
- Recommendations

---

## Current Baseline Summary (2025-12-22 23:47 UTC)

**Analysis Period:** Last 2 hours (113 cycles)

### Complete Cycle Metrics
- **Average cycle time:** 8.5 seconds
- **Typical range:** 8-10 seconds
- **Median:** 8 seconds
- **Cycle frequency:** ~60 cycles per hour (1 cycle per minute)
- **Success rate:** 100% (0 errors)

### Data Processing
- **Total notes processed:** 276 notes
- **Average notes per cycle:** 2.44 notes
- **Average new notes:** 0.54 per cycle (61 total)
- **Average updated notes:** 1.90 per cycle (215 total)
- **New/Updated ratio:** ~1:3.5

### Stage Performance
- **Bulk INSERT notes:** 6.15ms average (slowest normal stage)
- **Bulk INSERT comments:** 1.17ms average
- **Synchronize sequences check:** 1.86ms average (when skipped)
- **All other stages:** < 0.6ms average
- **ANALYZE notes (periodic):** 272.08ms (1 execution, expected)

### Optimizations Status
- **ANALYZE checks:** 99-100% skipped, < 0.5ms when skipped (optimized)
- **Integrity check:** 0.35ms average, 226 executions (optimized)
- **Sequence sync check:** 100% skipped (113/113 cycles), optimized

### System Health
- **Errors in 24h:** 0
- **System status:** Healthy
- **All optimizations:** Working correctly

---

## Notes for Future Comparisons

### When Comparing Metrics

1. **Use the same time period** (e.g., last 2 hours, last 24 hours)
2. **Consider workload** (number of notes processed)
3. **Compare percentiles** in addition to averages (to detect outliers)
4. **Account for expected improvements** vs degradations

### Factors That May Affect Metrics

- **Workload:** More notes = more time (normal)
- **Database configuration:** Changes in indexes, PostgreSQL configuration
- **Server load:** Other processes consuming resources
- **Database state:** Table sizes, fragmentation
- **Code changes:** New optimizations or features

---

**Last Updated:** 2025-12-22 23:47 UTC  
**Next Review Recommended:** Monthly or after significant changes  
**Baseline Data Source:** Production server 192.168.0.7, last 2 hours of operations

