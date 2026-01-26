---
title: "GDPR Annual Compliance Checklist"
description: "This checklist should be completed annually to ensure GDPR compliance. Ideally, perform this review"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "documentation"
audience:
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# GDPR Annual Compliance Checklist

**Version:** 2025-12-13

This checklist should be completed annually to ensure GDPR compliance. Ideally, perform this review
in January to assess the previous year's compliance.

## Annual Review Checklist

### Request Review

- [ ] Review all GDPR requests received during the previous year
- [ ] Verify that all requests were processed within the required timeframe (2 months standard, 6
      months for complex requests)
- [ ] Check open GitHub Issues with `gdpr` label
- [ ] Close any completed GDPR requests/issues
- [ ] Document any delays or issues encountered

### Documentation Review

- [ ] Review and update `GDPR_Privacy_Policy.md` if necessary:
  - Changes in data processing activities
  - New features that process personal data
  - Updates to legal requirements
- [ ] Review and update `GDPR_Procedures.md` if necessary:
  - Improvements based on experience
  - Updates to verification methods
  - New best practices
- [ ] Update "Last Updated" date in privacy policy
- [ ] Document any changes made to policies or procedures

### Security Review

- [ ] Review database access controls and permissions
- [ ] Verify that only authorized personnel have access to personal data
- [ ] Review and update database credentials if necessary
- [ ] Check database access logs for anomalies
- [ ] Verify that backups are working correctly
- [ ] Review system security updates and patches applied

### Data Retention Review

- [ ] Confirm data retention policies are being followed
- [ ] Review any pending deletion requests
- [ ] Verify that anonymization procedures are effective
- [ ] Check that audit logs (`gdpr_audit_log` table) are being maintained

### Processing Activities Review

- [ ] Assess current data processing activities
- [ ] Verify that all processing activities are documented in privacy policy
- [ ] Check if any new data processing has been introduced
- [ ] Review data sharing with related projects (Analytics, Viewer)

### System Review

- [ ] Verify SQL scripts in `sql/gdpr/` are still functional
- [ ] Test GDPR request scripts with sample data (if possible)
- [ ] Review GitHub Issues system for tracking requests
- [ ] Verify email contact `notes@osm.lat` is still active and monitored

### Compliance Audit

- [ ] Review overall GDPR compliance status
- [ ] Identify any gaps or areas for improvement
- [ ] Document any compliance issues discovered
- [ ] Create action plan for any identified issues
- [ ] Review training needs (if applicable)

### Next Steps

After completing the checklist:

- [ ] Document completion date
- [ ] Create summary of findings (optional, in GitHub Issue or notes)
- [ ] Schedule next year's review
- [ ] Update any necessary documentation based on findings

## Completion Record

| Year | Review Date | Completed By | Notes |
| ---- | ----------- | ------------ | ----- |
| 2025 |             |              |       |
| 2026 |             |              |       |
| 2027 |             |              |       |

## Notes

- Keep this checklist file updated
- Add any specific issues or findings in the "Notes" column
- Reference related GitHub Issues if applicable

## Related Documentation

- [GDPR Privacy Policy](./GDPR_Privacy_Policy.md)
- [GDPR Procedures](./GDPR_Procedures.md)
- [GDPR SQL Scripts](../sql/gdpr/README.md)
