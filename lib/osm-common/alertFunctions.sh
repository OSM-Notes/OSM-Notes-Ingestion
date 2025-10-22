#!/bin/bash

# Common functions for failed execution alerts and notifications.
# These functions are used by processAPINotes.sh, processPlanetNotes.sh
# and other scripts to send immediate alerts when critical errors occur.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-22

# Creates a failed execution marker file with details and sends immediate
# alerts.
# This prevents subsequent executions from running until the issue is resolved.
#
# Parameters:
#   $1 - script_name: Name of the script that failed (e.g., "processAPINotes")
#   $2 - error_code: The error code that triggered the failure
#   $3 - error_message: Description of what failed
#   $4 - required_action: What action is needed to fix it
#   $5 - failed_execution_file: Path to the failed execution marker file
#
# Environment variables:
#   GENERATE_FAILED_FILE: Set to "true" to enable (default)
#   SEND_ALERT_EMAIL: Set to "true" to send email alerts (default: true)
#   ADMIN_EMAIL: Email address for alerts (default: root@localhost)
#   SEND_ALERT_SLACK: Set to "true" to send Slack alerts (default: false)
#   SLACK_WEBHOOK_URL: Slack webhook URL for alerts
#   ONLY_EXECUTION: Must be "yes" for alerts to be sent
#   TMP_DIR: Temporary directory for this execution
#   VERSION: Script version
#
# Returns:
#   None (always creates file if conditions are met)
function __common_create_failed_marker() {
 local SCRIPT_NAME="${1}"
 local ERROR_CODE="${2}"
 local ERROR_MESSAGE="${3}"
 local REQUIRED_ACTION="${4}"
 local FAILED_EXECUTION_FILE="${5}"
 local TIMESTAMP
 TIMESTAMP=$(date)
 local HOSTNAME_VAR
 HOSTNAME_VAR=$(hostname)

 __loge "Creating failed execution marker due to: ${ERROR_MESSAGE}"

 if [[ "${GENERATE_FAILED_FILE:-true}" == "true" ]] \
  && [[ "${ONLY_EXECUTION:-no}" == "yes" ]]; then

  # Create the failed execution marker file
  {
   echo "Execution failed at ${TIMESTAMP}"
   echo "Script: ${SCRIPT_NAME}"
   echo "Error code: ${ERROR_CODE}"
   echo "Error: ${ERROR_MESSAGE}"
   echo "Process ID: $$"
   echo "Temporary directory: ${TMP_DIR:-unknown}"
   echo "Server: ${HOSTNAME_VAR}"
   echo ""
   echo "Required action: ${REQUIRED_ACTION}"
  } > "${FAILED_EXECUTION_FILE}"
  __loge "Failed execution file created: ${FAILED_EXECUTION_FILE}"
  __loge "Remove this file after fixing the issue to allow new executions"

  # Send immediate email alert if enabled
  if [[ "${SEND_ALERT_EMAIL:-true}" == "true" ]]; then
   __common_send_failure_email "${SCRIPT_NAME}" "${ERROR_CODE}" \
    "${ERROR_MESSAGE}" "${REQUIRED_ACTION}" "${FAILED_EXECUTION_FILE}" \
    "${TIMESTAMP}" "${HOSTNAME_VAR}"
  fi


 else
  __logd "Failed file not created (GENERATE_FAILED_FILE=${GENERATE_FAILED_FILE:-true}, ONLY_EXECUTION=${ONLY_EXECUTION:-no})"
 fi
}

# Sends an email alert about the failed execution.
# This is called automatically by __common_create_failed_marker.
#
# Parameters:
#   $1 - script_name
#   $2 - error_code
#   $3 - error_message
#   $4 - required_action
#   $5 - failed_execution_file
#   $6 - timestamp
#   $7 - hostname
function __common_send_failure_email() {
 local SCRIPT_NAME="${1}"
 local ERROR_CODE="${2}"
 local ERROR_MESSAGE="${3}"
 local REQUIRED_ACTION="${4}"
 local FAILED_EXECUTION_FILE="${5}"
 local TIMESTAMP="${6}"
 local HOSTNAME_VAR="${7}"
 local EMAIL_TO="${ADMIN_EMAIL:-root@localhost}"

 # Check if mail command is available
 if ! command -v mail > /dev/null 2>&1; then
  __logw "Mail command not available, skipping email alert"
  return 0
 fi

 local SUBJECT="ALERT: OSM Notes ${SCRIPT_NAME} Failed - ${HOSTNAME_VAR}"
 local BODY
 BODY=$(cat << EOF
ALERT: OSM Notes Processing Failed
===================================

Script: ${SCRIPT_NAME}.sh
Time: ${TIMESTAMP}
Server: ${HOSTNAME_VAR}
Failed marker file: ${FAILED_EXECUTION_FILE}

Error Details:
--------------
Error code: ${ERROR_CODE}
Error: ${ERROR_MESSAGE}

Process Information:
--------------------
Process ID: $$
Temporary directory: ${TMP_DIR:-unknown}
Script version: ${VERSION:-unknown}

Action Required:
----------------
${REQUIRED_ACTION}

Recovery Steps:
---------------
1. Read the error details above
2. Follow the required action instructions
3. After fixing, delete the marker file:
   rm ${FAILED_EXECUTION_FILE}
4. Run the script again to verify the fix

Logs:
-----
Check logs at: ${TMP_DIR}/${SCRIPT_NAME}.log

---
This is an automated alert from OSM Notes Ingestion system.
EOF
)

 # Send email
 if echo "${BODY}" | mail -s "${SUBJECT}" "${EMAIL_TO}" 2>/dev/null; then
  __logi "Email alert sent successfully to ${EMAIL_TO}"
 else
  __logw "Failed to send email alert to ${EMAIL_TO}"
 fi
}


