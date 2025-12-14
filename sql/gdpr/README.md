# GDPR SQL Scripts

This directory contains SQL scripts to handle GDPR data subject requests.

## Scripts Overview

### `gdpr_access_request.sql`

Retrieves all personal data for a specific user (access request).

**Usage:**

```bash
psql -d notes -v user_id=12345 -v username='john_doe' \
  -f sql/gdpr/gdpr_access_request.sql > user_data_12345.csv
```

**Parameters:**

- `user_id`: OSM User ID (optional if username is provided)
- `username`: OSM Username (optional if user_id is provided)

**Output:** CSV format with all user-related data.

### `gdpr_erasure_request.sql`

Anonymizes or deletes personal data for a specific user (erasure request).

**Warning:** This script anonymizes data. Complete deletion may not be
possible due to foreign key constraints and license requirements.

**Usage:**

```bash
psql -d notes -v user_id=12345 -v username='john_doe' \
  -f sql/gdpr/gdpr_erasure_request.sql
```

**Parameters:**

- `user_id`: OSM User ID (required)
- `username`: OSM Username (required for verification)

**Actions:**

1. Anonymizes username in `users` table
2. Sets `id_user` to NULL in `note_comments` table
3. Creates audit log of changes

### `gdpr_anonymize_user.sql`

Helper function to anonymize a user's data while preserving data structure.

**Usage:**

```sql
SELECT gdpr_anonymize_user(12345, 'john_doe');
```

### `gdpr_list_user_data.sql`

Lists summary of all data associated with a user (for verification before
processing requests).

**Usage:**

```bash
psql -d notes -v user_id=12345 -f sql/gdpr/gdpr_list_user_data.sql
```

## Important Notes

1. **Backup Before Execution:** Always backup the database before executing
   erasure requests.

2. **Review Results:** Review anonymization results to ensure data integrity
   is maintained.

3. **Audit Log:** All GDPR operations should be logged for compliance
   purposes.

4. **Foreign Key Constraints:** Some operations may fail if foreign key
   constraints prevent deletion. In such cases, anonymization is applied
   instead.

5. **License Requirements:** Data derived from OSM must comply with ODbL
   license requirements. Complete deletion may conflict with attribution
   requirements.

## Security

- These scripts should only be executed by authorized personnel
- Access should be logged and audited
- Results should be handled securely (encrypted transfer, secure storage)

## Support

For questions about GDPR procedures, see:
- `docs/GDPR_Procedures.md` - Detailed procedures
- `docs/GDPR_Privacy_Policy.md` - Privacy policy

