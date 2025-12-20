# GDPR Privacy Policy

**Version:** 2025-12-13

## Introduction

This document outlines the privacy policy and GDPR compliance measures for the
OSM Notes Ingestion system. This system processes data from OpenStreetMap (OSM)
that may contain personal information of OSM contributors.

## Scope

This privacy policy applies to all personal data processed by the OSM Notes
Ingestion system, including:

- User identifiers and usernames from OSM
- Geographic location data (coordinates of notes)
- Timestamps of note creation and comments
- Text content of notes and comments
- Metadata associated with notes and comments

## Legal Basis for Processing

The legal basis for processing personal data under GDPR Article 6(1)(f) is
**legitimate interest**:

1. The system processes publicly available data from OpenStreetMap, which is
   already published under the Open Database License (ODbL).
2. The processing is necessary for research, analysis, and improvement of OSM
   data quality and mapping activities.
3. The system provides value to the OpenStreetMap community by enabling
   analysis and monitoring of notes.
4. Data processing is limited to what is strictly necessary for the stated
   purposes.

## Data Controller Information

**Data Controller:** Andrés Gómez

**Contact Information:** `angoca@osm.lat`

## Types of Personal Data Processed

### 1. User Identifiers

- **Data Type:** OSM User ID and Username
- **Source:** OpenStreetMap API and Planet dumps
- **Storage:** PostgreSQL database table `users`
- **Risk:** Usernames may contain real names or identifiable information

### 2. Geographic Location Data

- **Data Type:** Latitude and Longitude coordinates
- **Source:** OSM Notes API and Planet dumps
- **Storage:** PostgreSQL database table `notes`
- **Risk:** Precise location data can reveal where users live, work, or
  frequent, potentially identifying individuals

### 3. Temporal Data

- **Data Type:** Creation timestamps, closure timestamps
- **Source:** OSM Notes API and Planet dumps
- **Storage:** PostgreSQL database tables `notes` and `note_comments`
- **Risk:** Timestamps combined with locations can reveal behavioral patterns

### 4. Text Content

- **Data Type:** Note and comment text content
- **Source:** OSM Notes API and Planet dumps
- **Storage:** PostgreSQL database table `note_comments_text`
- **Risk:** Text content may contain personal information, opinions, or
  identifying details

## Purpose of Processing

The personal data is processed for the following purposes:

1. **Data Analysis:** Analyzing OSM notes patterns and trends
2. **Quality Monitoring:** Monitoring note quality and processing issues
3. **Research:** Supporting research on mapping activities and user behavior
4. **Service Provision:** Data may be published via WMS (Web Map Service) layers (see [OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS)) for
   visualization
5. **System Maintenance:** Ensuring data integrity and system functionality

## Data Retention

### Retention Period

Personal data is retained indefinitely, as it is derived from publicly
available OSM data that is subject to the Open Database License (ODbL).

However, data subjects have the right to request:

- **Access** to their personal data (GDPR Article 15)
- **Rectification** of inaccurate data (GDPR Article 16)
- **Erasure** (Right to be forgotten) under specific conditions (GDPR Article
  17)
- **Data portability** (GDPR Article 20)

### Data Deletion Policy

Requests for data deletion will be evaluated on a case-by-case basis:

1. If data can be deleted without affecting the integrity of historical
   records or research purposes
2. If deletion is required by law or regulation
3. If the data subject provides valid reasons that override legitimate
   interests

**Note:** Complete deletion may not always be possible due to:

- Legal obligations to maintain historical records
- Technical limitations in data relationships
- License requirements (ODbL) that may require attribution

In such cases, **anonymization** will be considered as an alternative to
deletion.

## Data Security Measures

### Technical Measures

1. **Database Security:**
   - Access control through PostgreSQL user permissions
   - Regular security updates

2. **System Security:**
   - Secure configuration management
   - Access logging and monitoring

3. **Network Security:**
   - Firewall rules to restrict database access
   - Secure communication protocols (HTTPS, SSH)

### Organizational Measures

1. **Access Control:**
   - Principle of least privilege for database access
   - Regular review of user permissions

2. **Training:**
   - GDPR awareness training for team members
   - Data handling procedures documentation

## Data Subject Rights

Under GDPR, data subjects have the following rights:

### 1. Right of Access (Article 15)

Data subjects can request:

- Confirmation of whether their personal data is being processed
- Access to their personal data
- Information about the processing purposes
- Information about data retention periods

**Response Time:** Within 2 months (can be extended to 6 months for complex
requests)

### 2. Right to Rectification (Article 16)

Data subjects can request correction of inaccurate personal data.

**Note:** Since data originates from OpenStreetMap, rectification requests
should first be directed to OSM. Changes in OSM will be reflected in
subsequent data updates.

### 3. Right to Erasure / Right to be Forgotten (Article 17)

Data subjects can request deletion of their personal data under specific
conditions:

- Data is no longer necessary for the original purpose
- Data subject withdraws consent (if consent was the legal basis)
- Data subject objects to processing (if legitimate interest was the basis)
- Data has been unlawfully processed

**Limitations:** Deletion may be refused if:

- Processing is necessary for compliance with legal obligations
- Processing is necessary for research or statistical purposes
- Data is required for historical records

### 4. Right to Restriction of Processing (Article 18)

Data subjects can request restriction of processing in certain circumstances.

### 5. Right to Data Portability (Article 20)

Data subjects can request their personal data in a structured, commonly used,
and machine-readable format.

### 6. Right to Object (Article 21)

Data subjects can object to processing based on legitimate interests.

### 7. Right to Withdraw Consent

If consent was the legal basis (not applicable in this case, as we use
legitimate interest).

## How to Exercise Your Rights

To exercise any of your GDPR rights, please contact:

**Email:** `angoca@osm.lat`

**Subject Line:** GDPR Data Subject Request

Please include:

1. Your OSM username or User ID
2. The specific right you wish to exercise
3. A clear description of your request
4. Any relevant documentation

**Verification:** We may need to verify your identity before processing your
request.

## Data Processing Activities

### Data Sources

1. **OSM Planet Dumps:** Daily dumps of all OSM notes
2. **OSM Notes API:** Real-time synchronization of recent notes

### Processing Steps

1. **Download:** Data is downloaded from OSM sources
2. **Extraction:** XML data is converted to CSV format using AWK scripts
3. **Validation:** Data is validated against XML schemas
4. **Storage:** Data is stored in PostgreSQL database
5. **Processing:** Geographic assignment, country identification, analysis
6. **Publication:** Data may be published via WMS layers (see [OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS) repository) (see [OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS))
7. **Analytics and Visualization:** Data may be processed by related projects:
   - **OSM-Notes-Analytics:** Data warehouse, ETL processes, and analytics
     capabilities for generating user and country profiles
   - **OSM-Notes-Viewer:** Web visualization and interactive exploration of
     user profiles, country profiles, and note data

### Data Sharing

- **WMS Layers:** Simplified, aggregated data may be published via WMS (see [OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS))
  services
- **Related Projects:** Data may be processed by related projects within the
  same organization:
  - **OSM-Notes-Analytics:** For data warehouse, ETL processes, analytics, and
    profile generation
  - **OSM-Notes-Viewer:** For web-based visualization and interactive
    exploration of user and country profiles
- **Research:** Anonymized or aggregated data may be shared for research
  purposes
- **No Third-Party Sharing:** Personal data is not sold or shared with third
  parties for commercial purposes

## International Data Transfers

Data is processed and stored within Colombia.

If data is transferred outside the EU/EEA, appropriate safeguards will be
implemented in accordance with GDPR Chapter V.

## Data Protection Officer (DPO)

A Data Protection Officer (DPO) is not required for this data processing activity.

## Complaints

If you are not satisfied with how your personal data is being handled, you
have the right to lodge a complaint with your local data protection
authority in the European Union or European Economic Area.

Since this is a personal data processing activity operated by an individual
(natural person) from Colombia, and not by a commercial entity or organization,
there is no single designated supervisory authority. If you are a resident of
an EU/EEA member state, you should contact the data protection authority in
your country of residence.

**List of EU/EEA Data Protection Authorities:**

You can find the contact information for your local data protection authority
at: [https://edpb.europa.eu/about-edpb/about-edpb/members_en](https://edpb.europa.eu/about-edpb/about-edpb/members_en)

Common examples include:

- **Spain:** Agencia Española de Protección de Datos (AEPD)
- **Germany:** Depends on your state (Länder) - e.g., Berliner Beauftragte für Datenschutz und Informationsfreiheit
- **France:** Commission Nationale de l'Informatique et des Libertés (CNIL)
- **United Kingdom:** Information Commissioner's Office (ICO)
- **Italy:** Garante per la protezione dei dati personali

For residents of other EU/EEA countries, please refer to the EDPB members list
linked above.

## Updates to This Policy

This privacy policy will be reviewed and updated regularly to ensure
compliance with GDPR and other applicable regulations.

**Last Updated:** 2025-12-13

## Contact Information

For questions, concerns, or requests regarding this privacy policy or GDPR
compliance, please contact:

Andrés Gómez - `angoca@osm.lat`
