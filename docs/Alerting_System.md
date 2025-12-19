# Immediate Alerting System

> **Note:** For system architecture overview, see [Documentation.md](./Documentation.md).  
> For error handling details, see [Process_API.md](./Process_API.md) and [Process_Planet.md](./Process_Planet.md).  
> For troubleshooting, see [Documentation.md#troubleshooting-guide](./Documentation.md#troubleshooting-guide).

## Comparison: Previous System vs New System

### ❌ Previous System (with External Monitor)

```
Time    Event
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
01:00   processAPINotes.sh executes (cron)
        ├─ Error: Missing historical data
        └─ Creates file: processAPINotes_failed_execution
          (Location: /var/run/osm-notes-ingestion/ in installed mode,
           /tmp/osm-notes-ingestion/locks/ in fallback mode)
        
        ⏰ WAIT 10-15 MINUTES
        
01:15   checkFailedExecution.sh executes (cron)
        ├─ Detects failed file
        ├─ Reads content
        └─ 📧 Sends email to admin
        
        👤 Admin receives alert (15 minutes after error)
```

**Problems:**
- ⏰ 10-15 minute delay in notification
- 🔄 Requires additional script
- 📅 Requires additional cron configuration
- 💾 Uses more resources (script running every 15 min)
- 🔧 More complex to configure


### ✅ New System (Immediate Alerts)

```
Time    Event
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
01:00   processAPINotes.sh executes (cron)
        ├─ Error: Missing historical data
        ├─ Creates file: /tmp/processAPINotes_failed_execution
        └─ 📧 Sends email IMMEDIATELY
        
        👤 Admin receives alert (seconds after error)
```

**Advantages:**
- ⚡ Alert in seconds, not minutes
- 🎯 Simpler (no additional scripts)
- 💰 Less system resources
- 🔧 Easier to configure (just environment variables)
- 📱 Simple email-based alerting


## System Architecture

### Previous Architecture

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  CRON JOB #1: Processing                           │
│  */60 * * * * processAPINotes.sh                   │
│                                                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │ Does it fail?   │
         └────┬────────────┘
              │
              ▼ YES
    ┌──────────────────────┐
    │ Creates file:        │
    │ /tmp/...failed...    │
    └──────────┬───────────┘
               │
               │ ⏰ WAIT (10-15 min)
               │
┌──────────────┴──────────────────────────────────────┐
│                                                     │
│  CRON JOB #2: Monitoring                           │
│  */15 * * * * checkFailedExecution.sh              │
│                                                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │ Does file exist?│
         └────┬────────────┘
              │
              ▼ YES
    ┌──────────────────────┐
    │ Reads file           │
    │ Sends email 📧       │
    └──────────┬───────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Admin receives alert │
    │ (15 min later)       │
    └──────────────────────┘
```

**Required components:**
- 2 different scripts
- 2 cron configurations
- 1 state file (anti-spam)
- Separate logging system


### New Architecture (Improved)

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  CRON JOB: Processing                              │
│  */60 * * * * processAPINotes.sh                   │
│  Variables:                                         │
│    ADMIN_EMAIL=admin@example.com                   │
│    SEND_ALERT_EMAIL=true                           │
│                                                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │ Does it fail?   │
         └────┬────────────┘
              │
              ▼ YES
    ┌──────────────────────┐
    │ __create_failed_     │
    │     marker()         │
    │                      │
    │ 1. Creates file      │
    │ 2. __send_failure_   │
    │        email()       │
    └──────────┬───────────┘
               │
               ▼ ⚡ IMMEDIATE (seconds)
    ┌──────────────────────┐
    │ Admin receives:      │
    │ • Email 📧           │
    │ (seconds later)      │
    └──────────────────────┘
```

**Required components:**
- 1 script
- 1 cron configuration
- Simple environment variables
- Everything integrated


## Configuration

### Environment Variables

```bash
# Email (enabled by default)
ADMIN_EMAIL="admin@example.com"        # Destination email
SEND_ALERT_EMAIL="true"                # Enable/disable

# Failed file control
GENERATE_FAILED_FILE="true"            # Create failed file
ONLY_EXECUTION="yes"                   # (internal, set by script)
```

### Where to Configure

**Option 1: Directly in crontab**
```bash
crontab -e

ADMIN_EMAIL=admin@example.com
SEND_ALERT_EMAIL=true
0 * * * * /path/to/processAPINotes.sh
```

**Option 2: In a wrapper script**
```bash
#!/bin/bash
# /home/notes/bin/run-with-alerts.sh

export ADMIN_EMAIL="admin@example.com"
export SEND_ALERT_EMAIL="true"

exec /path/to/processAPINotes.sh "$@"
```

**Option 3: In configuration file**
```bash
# /etc/osm-notes/alerts.conf

ADMIN_EMAIL="admin@example.com"
SEND_ALERT_EMAIL="true"
```

Then in crontab:
```bash
0 * * * * source /etc/osm-notes/alerts.conf && /path/to/processAPINotes.sh
```


## Alert Examples

### Email Alert

```
Subject: ALERT: OSM Notes processAPINotes Failed - hostname

ALERT: OSM Notes Processing Failed
===================================

Script: processAPINotes.sh
Time: Wed Oct 22 01:00:07 UTC 2025
Server: osm-notes-server
Failed marker file: processAPINotes_failed_execution
(Location: /var/run/osm-notes-ingestion/ in installed mode,
 /tmp/osm-notes-ingestion/locks/ in fallback mode)

Error Details:
--------------
Error code: 248
Error: Historical data validation failed - base tables exist 
       but contain no historical data

Process Information:
--------------------
Process ID: 12345
Temporary directory: processAPINotes_20251022_010000
(Location: /var/tmp/osm-notes-ingestion/ in installed mode,
 /tmp/ in fallback mode)

Action Required:
----------------
Run processPlanetNotes.sh to load historical data: 
/home/notes/OSM-Notes-Ingestion/bin/process/processPlanetNotes.sh

Recovery Steps:
---------------
1. Read the error details above
2. Follow the required action instructions
3. After fixing, delete the marker file:
   # Remove failed execution marker (works in both modes)
   FAILED_FILE=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
     -name "processAPINotes_failed_execution" 2>/dev/null | head -1)
   if [[ -n "${FAILED_FILE}" ]]; then
     rm "${FAILED_FILE}"
   fi
4. Run the script again to verify the fix

Logs:
-----
Check logs at:
- Installed mode: /var/log/osm-notes-ingestion/processing/processAPINotes.log
- Fallback mode: /tmp/osm-notes-ingestion/logs/processing/processAPINotes.log

Or find automatically:
```bash
find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
  -name "processAPINotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
  sort -n | tail -1 | awk '{print $2}'
```

---
This is an automated alert from OSM Notes Ingestion system.
```


## Frequently Asked Questions

### Do I need to configure anything additional?

**No.** By default:
- Failed file is created automatically
- Email alerts are enabled
- You only need to configure `ADMIN_EMAIL`

### What email tools does the system use?

The system uses **`mutt`** as the email tool. `mutt` is a **required prerequisite** 
that is validated during the prerequisites check (`__checkPrereqsCommands`). 
If `mutt` is not available, the script will exit with an error before attempting 
to send any emails.

### Validating Email Sending Capability

The prerequisites check verifies that:
1. `mutt` is installed
2. `mutt` has SMTP support compiled in (for external email delivery)

However, actual email delivery cannot be validated without sending a real email. 
To manually test email sending, use:

```bash
echo "Test email" | mutt -s "Test" "${ADMIN_EMAIL}"
```

The failed file is created anyway to prevent subsequent executions, even if 
email sending fails.

### Are multiple alerts sent if it fails multiple times?

No. The failed file mechanism prevents subsequent executions:
1. First execution (01:00): Fails → Sends alert → Creates file
2. Second execution (02:00): Detects file → Exits without sending alert
3. Third execution (03:00): Detects file → Exits without sending alert

Only **ONE alert** is sent until you delete the failed file.


## Migration

If you already have the previous system configured:

1. **Update `processAPINotes.sh`** (already done)
2. **Configure environment variables:**
   ```bash
   export ADMIN_EMAIL="admin@example.com"
   ```
3. **Optional: Disable external monitor:**
   ```bash
   crontab -e
   # Comment or remove: */15 * * * * checkFailedExecution.sh
   ```
4. **Test the new system**
5. **Keep the external monitor as backup if you prefer**


## Benefits Summary

| Feature | Previous System | New System |
|---------|----------------|------------|
| **Alert time** | 10-15 minutes | Seconds |
| **Required scripts** | 2 | 1 |
| **Cron configuration** | 2 jobs | 1 job |
| **Complexity** | High | Low |
| **System resources** | Moderate | Low |
| **Configuration ease** | Medium | High |
| **Alert channels** | Email | Email |
| **Maintenance** | Complex | Simple |

## Conclusion

The new immediate alerting system is:
- ✅ **Faster**: Alerts in seconds instead of minutes
- ✅ **Simpler**: Single configuration
- ✅ **More efficient**: Less system resources
- ✅ **More reliable**: Simple email-based alerting
- ✅ **Easier**: Just configure environment variables

The previous system (`checkFailedExecution.sh`) is still valid as:
- Backup/redundancy
- Centralized monitoring of multiple scripts
- Cases where you prefer separation of responsibilities

**Recommendation**: Use the new system by default. Keep the old one only if you need centralized monitoring.

## Email Sending Locations

The system sends emails in **3 different scenarios**:

1. **Alert failures in `processAPINotes.sh` and `processPlanetNotes.sh`**
   - Function: `__common_send_failure_email()` in `lib/osm-common/alertFunctions.sh`
   - Triggered: When a critical error occurs and a failed execution marker is created
   - Uses: `mutt` (required prerequisite)

2. **Missing maritime boundaries alerts in `updateCountries.sh`**
   - Location: `bin/process/updateCountries.sh`
   - Triggered: When EEZ (maritime boundaries) exist in OSM but not in the database
   - Uses: `mutt` (required prerequisite)

3. **Database differences reports in `notesCheckVerifier.sh`**
   - Function: `__sendMail()` in `bin/monitor/notesCheckVerifier.sh`
   - Triggered: When differences are found between Planet file and API calls
   - Uses: `mutt` (always used for this script)

All three locations use the same email configuration (`ADMIN_EMAIL` or `EMAILS` 
environment variables) and require `mutt` as a prerequisite.

## Related Documentation

- **[Documentation.md](./Documentation.md)**: System architecture and error handling overview
- **[Process_API.md](./Process_API.md)**: API processing error handling implementation
- **[Process_Planet.md](./Process_Planet.md)**: Planet processing error handling implementation
- **[Documentation.md#troubleshooting-guide](./Documentation.md#troubleshooting-guide)**: Troubleshooting guide with error recovery procedures
- **[bin/ENVIRONMENT_VARIABLES.md](../bin/ENVIRONMENT_VARIABLES.md)**: Environment variable configuration (ADMIN_EMAIL, SEND_ALERT_EMAIL)

---