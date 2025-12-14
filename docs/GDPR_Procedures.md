# GDPR Compliance Procedures

**Version:** 2025-12-13

## Overview

This document provides detailed procedures for handling GDPR data subject
requests and maintaining compliance with GDPR regulations in the OSM Notes
Ingestion system.

## Data Subject Request Handling Process

### 1. Request Receipt and Acknowledgment

**Step 1.1: Receive Request**

- Requests should be received via email at: `angoca@osm.lat`
- Subject line should contain: "GDPR Data Subject Request"
- All requests must be logged for tracking and audit purposes
  - **Tracking System:** GitHub Issues in this repository
  - Create a private issue for each GDPR request (use [private] tag)
  - Reference format: `GDPR-REQ-YYYYMMDD-HHMMSS` or use GitHub issue number
  - Alternative: Maintain a simple spreadsheet if preferred

**Step 1.2: Acknowledge Receipt**

- Respond within 1 week acknowledging receipt
- Include:
  - Reference number for the request
  - Expected response timeline (within 1 month, extendable to 2 months)
  - Information about identity verification requirements

**Email Template:**

```text
Subject: GDPR Request Acknowledgment - Reference [REF-NUMBER] (Issue #[ISSUE_NUMBER])

Dear [Name],

We acknowledge receipt of your GDPR data subject request dated [DATE].

Request Reference: [REF-NUMBER]
Request Type: [Access/Rectification/Erasure/Portability/Objection]

We are reviewing your request and will respond within one month. In complex
cases, this may be extended to two months, in which case we will inform you
within one month of receiving your request.

To proceed with your request, we may need to verify your identity. Please
provide:
- Your OSM username or User ID
- Additional verification if required

If you have any questions, please contact us at angoca@osm.lat quoting reference
[REF-NUMBER].

Best regards,
[Name/Team]
```

### 2. Identity Verification

**Step 2.1: Verify Identity**

Before processing any request, verify the identity of the data subject.

**Important:** OpenStreetMap does not provide public access to user email
addresses for privacy reasons. Therefore, we use alternative verification
methods:

**Verification Methods (choose one or combine):**

1. **Email Confirmation (Preferred):**
   - Ask the requester to send the GDPR request from the email address
     registered in their OSM account
   - The requester knows which email they used for OSM registration
   - Verify that the email address matches what they claim (though we cannot
     directly verify it with OSM)
   - If uncertain, request additional verification

2. **OSM Profile Verification:**
   - Ask the requester to add a specific verification code to their OSM user
     profile description (temporarily)
   - Format: "GDPR-Verification: [UNIQUE_CODE]"
   - After verification, they can remove it
   - This proves they control the OSM account

3. **Account Activity Information:**
   - Ask the requester to provide information only the account owner would
     know:
     - Approximate date of account creation
     - Location of some notes they created (without revealing exact coordinates)
     - Number of notes/comments they remember creating
   - Compare with data in our database

4. **For User ID Requests:**
   - First, request the OSM username associated with the User ID
   - Then use one of the verification methods above
   - Verify that the user_id matches the username in our database

**Step 2.2: Verification Process**

1. Upon receiving a GDPR request:
   - Acknowledge receipt and request identity verification
   - Choose appropriate verification method(s) based on request type
   - Provide clear instructions on how to verify identity

2. **Email Template for Verification Request:**

```text
Subject: GDPR Request - Identity Verification Required - Reference [REF-NUMBER]

Dear [Name],

Thank you for your GDPR data subject request (Reference: [REF-NUMBER]).

To protect your personal data and ensure we only provide information to the
legitimate account owner, we need to verify your identity.

Please choose ONE of the following verification methods:

**Option 1 - Email Verification:**
Please confirm that you are sending this request from the email address
registered with your OSM account [username]. If this is the case, simply reply
to this email confirming your OSM username and User ID (if known).

**Option 2 - OSM Profile Verification:**
1. Log in to your OSM account
2. Edit your user profile description
3. Add this verification code: GDPR-VERIFY-[UNIQUE_CODE]
4. Reply to this email once added
5. After verification, you can remove the code from your profile

**Option 3 - Account Information:**
Provide the following information that only you would know:
- Approximate date you created your OSM account
- Approximate number of notes you have created
- Name of one or two locations where you created notes (country/region level)

Please respond within 7 days. If we don't receive verification, we cannot
process your request.

If you have questions, please contact us at `angoca@osm.lat` quoting reference
[REF-NUMBER].

Best regards,
[Name/Team]
```

**Step 2.3: Reject Invalid Requests**

If identity cannot be verified after reasonable attempts:

- Inform the requester that verification is required
- Explain what additional information is needed
- Provide a deadline for verification (typically 7-14 days)
- Do not process the request until identity is verified
- Document all verification attempts in the GitHub issue

### 3. Request Processing Procedures

#### 3.1 Right of Access (Article 15)

**Purpose:** Provide data subject with all personal data held about them.

**Procedure:**

1. **Query Database:**

   ```sql
   -- Execute SQL scripts from sql/gdpr/gdpr_access_request.sql
   -- See section "SQL Scripts" below
   ```

2. **Collect Data:**
   - User information (user_id, username)
   - All notes created by the user
   - All comments made by the user
   - Text content of all comments
   - Timestamps and locations

3. **Format Response:**
   - Export data in CSV or JSON format
   - Include metadata about data sources
   - Explain data structure and fields

4. **Provide Response:**
   - Send data via secure method (encrypted email or secure file transfer)
   - Include explanation of:
     - What data is included
     - Data sources (OSM Planet, OSM API)
     - Processing purposes
     - Retention periods

**Response Time:** 2 month (extendable to 6 months for complex requests)

#### 3.2 Right to Rectification (Article 16)

**Purpose:** Correct inaccurate personal data.

**Important Note:** Since data originates from OpenStreetMap, rectification
should primarily be done in OSM. This system reflects OSM data.

**Procedure:**

1. **Identify Inaccurate Data:**
   - Query database for user's data
   - Compare with OSM source data
   - Identify discrepancies

2. **Correct in OSM First:**
   - Inform data subject that corrections should be made in OSM
   - Provide instructions for correcting data in OSM
   - Explain that changes will be reflected in next data sync

3. **Manual Correction (if needed):**
   - Only if correction cannot be made in OSM
   - Document the correction
   - Note the reason for manual correction
   - Update will be overwritten by next OSM sync

4. **Response:**
   - Inform data subject about actions taken
   - Explain limitations (data comes from OSM)
   - Provide timeline for updates to reflect in system

#### 3.3 Right to Erasure / Right to be Forgotten (Article 17)

**Purpose:** Delete personal data under specific conditions.

**Important Considerations:**

- Complete deletion may not be possible due to:
  - Technical constraints (foreign key relationships)
  - License requirements (ODbL)
  - Research/statistical purposes
  - Historical record requirements

**Procedure:**

1. **Evaluate Request:**
   - Check if deletion is legally required
   - Assess impact on data integrity
   - Consider anonymization as alternative

2. **Decision Tree:**

   ```text
   Can data be deleted without affecting:
   - Historical records? YES → Proceed with deletion
   - Research purposes? NO → Consider anonymization
   - License requirements? NO → Consider anonymization
   - Technical constraints? NO → Partial deletion + anonymization
   ```

3. **Execute Deletion/Anonymization:**

   ```sql
   -- Execute SQL scripts from sql/gdpr/gdpr_erasure_request.sql
   -- See section "SQL Scripts" below
   ```

4. **Document Actions:**
   - Log what data was deleted
   - Log what data was anonymized
   - Document reasons for any partial deletions

5. **Response:**
   - Inform data subject about actions taken
   - Explain any limitations
   - Provide details about anonymization if applied

**Anonymization Standards:**

- Replace username with: `[ANONYMIZED_USER_<user_id>]`
- Replace user_id references with NULL or anonymized ID
- Keep geographic and temporal data for research purposes
- Keep note structure but remove user attribution

#### 3.4 Right to Data Portability (Article 20)

**Purpose:** Provide personal data in structured, machine-readable format.

**Procedure:**

1. **Export Data:**
   - Use same queries as Access Request
   - Export in JSON or CSV format
   - Include metadata and schema information

2. **Format Options:**
   - JSON (preferred for structured data)
   - CSV (for tabular data)
   - XML (if requested)

3. **Provide Response:**
   - Send data file via secure method
   - Include schema documentation
   - Explain data format and structure

#### 3.5 Right to Object (Article 21)

**Purpose:** Object to processing based on legitimate interests.

**Procedure:**

1. **Evaluate Objection:**
   - Assess if objection is valid
   - Balance data subject rights vs. legitimate interests
   - Consider:
     - Nature of personal data
     - Impact on data subject
     - Importance of processing purpose

2. **Decision:**
   - If objection is valid: Stop processing for that user
   - If objection is invalid: Explain reasons (can process)

3. **Actions:**
   - If processing stops: Anonymize existing data
   - Prevent future processing of user's data
   - Document decision and rationale

4. **Response:**
   - Inform data subject of decision
   - Explain reasoning
   - Provide information about right to complain

### 4. Documentation and Logging

**Required Documentation:**

1. **Request Log (GitHub Issue):**
   - Create a **private** GitHub Issue for each GDPR request
   - Issue title format: `[GDPR] [REQUEST_TYPE] - OSM User: [username]`
   - Include in issue description:
     - Request reference number (e.g., `GDPR-REQ-20250123-143000` or GitHub issue #)
     - Date received
     - Data subject identifier (OSM username/ID)
     - Request type (Access/Rectification/Erasure/Portability/Objection)
     - Date processed
     - Actions taken
     - Response date
   - Use GitHub Issue labels: `gdpr`, `private-data`, `[request-type]`
   - Close issue when request is completed
   - Keep issues private (confidential) for data protection

2. **Processing Log:**
   - SQL queries executed
   - Data accessed
   - Data modified/deleted
   - Anonymization applied
   - Exceptions or issues

3. **Decision Records:**
   - Reasons for decisions (especially deletions/objections)
   - Legal basis assessments
   - Impact evaluations

**Storage:**

- **GitHub Issues:** Private issues remain accessible in the repository
  - Keep issues private and confidential
  - Do not include sensitive personal data in issue descriptions
  - Reference sensitive data by ID only (e.g., "User ID: 12345")
- **Retention:** Maintain logs securely for audit purposes. Retain for minimum
  of 2 years
- **Access Control:** Ensure only authorized personnel have access to private
  issues

### 5. Response Templates

#### 5.1 Access Request Response

```text
Subject: GDPR Access Request Response - Reference [REF-NUMBER]

Dear [Name],

In response to your data access request (Reference: [REF-NUMBER]), we are
providing you with the personal data we hold about you in our OSM Notes
Ingestion system.

Attached Files:
- personal_data_[REF-NUMBER].csv (or .json)
- data_schema_[REF-NUMBER].txt

Summary:
- User ID: [ID]
- Username: [USERNAME]
- Notes Created: [COUNT]
- Comments Made: [COUNT]
- Date Range: [FROM] to [TO]

Data Sources:
- OpenStreetMap Planet Dumps
- OpenStreetMap Notes API

Processing Purposes:
- Data analysis and research
- Quality monitoring
- Service provision (WMS layers)

Retention:
- Data is retained as part of historical records
- Derived from publicly available OSM data under ODbL license

If you have any questions or wish to exercise other GDPR rights, please
contact us quoting reference [REF-NUMBER].

Best regards,
[Name/Team]
```

#### 5.2 Erasure Request Response

```text
Subject: GDPR Erasure Request Response - Reference [REF-NUMBER]

Dear [Name],

In response to your erasure request (Reference: [REF-NUMBER]), we have
reviewed your request and taken the following actions:

[If deletion is possible:]
- Deleted username from users table
- Anonymized all user references in notes and comments
- Removed personal attribution from [X] notes and [Y] comments

[If deletion is not possible:]
- Anonymized username in users table
- Anonymized all user references in notes and comments
- Geographic and temporal data retained for research purposes (anonymized)

Limitations:
[Explain any limitations, e.g., license requirements, research needs]

Future Processing:
[Explain if data will be processed in future, or if processing has stopped]

If you have any questions, please contact us quoting reference [REF-NUMBER].

Best regards,
[Name/Team]
```

### 6. Escalation Procedures

**Complex Requests:**

- If request is complex or requires legal review
- Extend response time to 2 months (inform data subject within 1 month)
- Consult with legal advisor if needed

**Disputes:**

- If data subject disputes decision
- Provide detailed explanation of decision
- Inform about right to complain to supervisory authority

**Data Breaches:**

- Follow incident response procedures
- Notify supervisory authority within 72 hours if required
- Notify affected data subjects if high risk

### 7. Regular Compliance Reviews

**Annually:**

- Comprehensive GDPR compliance audit
- Review privacy policy and update as needed
- Review data retention policies
- Assess data processing activities
- Update security measures
- Review and update procedures as needed
- Check and close any pending GDPR requests (review open GitHub Issues with
  `gdpr` label)
- Training updates if applicable

### 8. Training Requirements

All team members handling GDPR requests must:

1. Complete GDPR awareness training
2. Understand data subject rights
3. Know request handling procedures
4. Be aware of data security requirements
5. Know when to escalate issues

### 9. Contact Information

**GDPR Contact:** Andrés Gómez - `angoca@osm.lat`

**Legal Advisor:** Not applicable

**Supervisory Authority:** Data subjects should contact their local data
protection authority in their EU/EEA country of residence. See
[GDPR_Privacy_Policy.md](./GDPR_Privacy_Policy.md) for details.

## Appendix

### SQL Scripts Location

SQL scripts for GDPR requests are located in:
`sql/gdpr/`

See `sql/gdpr/README.md` for detailed usage instructions.

### Annual Compliance Checklist

For a practical checklist to use during annual compliance reviews, see:
[GDPR_Annual_Checklist.md](./GDPR_Annual_Checklist.md)
