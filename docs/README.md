# Documentation Directory

## Overview

The `docs` directory contains comprehensive documentation for the OSM-Notes-Ingestion system, including user guides, technical specifications, and implementation details. This documentation helps users and contributors understand the system architecture and usage.

## Documentation Structure

### Core Documentation

- **`Documentation.md`**: Comprehensive system documentation and architecture overview
- **`Rationale.md`**: Project motivation, background, and design decisions

> **Note:** DWH (Data Warehouse), ETL, and Analytics documentation has been moved to
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### Technical Implementation

- **`processAPI.md`**: API processing documentation and incremental synchronization
- **`processPlanet.md`**: Planet file processing documentation and historical data handling

### Testing Documentation

- **`Testing_Guide.md`**: Complete testing guide with integration tests, troubleshooting, and best practices
- **`Testing_Workflows_Overview.md`**: Overview of GitHub Actions workflows and how to interpret results
- **`Input_Validation.md`**: Input validation and error handling documentation
- **`XML_Validation_Improvements.md`**: XML processing and validation improvements

### WMS (Web Map Service)

- **`WMS_Guide.md`**: Complete WMS guide with installation, configuration, and usage
- **`WMS_Technical.md`**: Technical specifications and architecture details
- **`WMS_User_Guide.md`**: User guide for mappers and end users
- **`WMS_Administration.md`**: Administration guide for system administrators
- **`WMS_API_Reference.md`**: Complete API reference and examples

## Quick Navigation

### For New Users

1. Start with **[Rationale.md](./Rationale.md)** to understand the project's purpose and motivation
2. Read **[Documentation.md](./Documentation.md)** for system architecture and overview
3. Review **[processAPI.md](./processAPI.md)** and **[processPlanet.md](./processPlanet.md)** for technical implementation details
4. Check **[WMS_User_Guide.md](./WMS_User_Guide.md)** for WMS usage instructions

### For Developers

1. Review **[Documentation.md](./Documentation.md)** for system architecture
2. Study **[processAPI.md](./processAPI.md)** for API integration details
3. Examine **[processPlanet.md](./processPlanet.md)** for data processing workflows
4. Consult **[WMS_Technical.md](./WMS_Technical.md)** and **[WMS_API_Reference.md](./WMS_API_Reference.md)** for WMS development
5. Read **[Testing_Guide.md](./Testing_Guide.md)** and **[Testing_Workflows_Overview.md](./Testing_Workflows_Overview.md)** for testing procedures

### For System Administrators

1. Read **[Documentation.md](./Documentation.md)** for deployment and maintenance guidelines
2. Review **[processAPI.md](./processAPI.md)** and **[processPlanet.md](./processPlanet.md)** for operational procedures
3. Follow **[WMS_Administration.md](./WMS_Administration.md)** for WMS system administration
4. Use **[WMS_Guide.md](./WMS_Guide.md)** for WMS installation and configuration
5. Check **[Testing_Workflows_Overview.md](./Testing_Workflows_Overview.md)** for CI/CD pipeline understanding

### For Testers and QA

1. Start with **[Testing_Guide.md](./Testing_Guide.md)** for comprehensive testing procedures
2. Read **[Testing_Workflows_Overview.md](./Testing_Workflows_Overview.md)** to understand GitHub Actions workflows
3. Review **[Input_Validation.md](./Input_Validation.md)** for validation testing guidelines
4. Study **[XML_Validation_Improvements.md](./XML_Validation_Improvements.md)** for XML testing procedures

## Documentation Cross-References

### Rationale.md

- **Purpose**: Project motivation and background
- **References**:
  - [Documentation.md](./Documentation.md) for technical details
  - [processAPI.md](./processAPI.md) and [processPlanet.md](./processPlanet.md) for implementation specifics

### Documentation.md

- **Purpose**: System architecture and technical overview
- **References**:
  - [Rationale.md](./Rationale.md) for project motivation
  - [processAPI.md](./processAPI.md) and [processPlanet.md](./processPlanet.md) for detailed implementation

### Testing Documentation

- **Testing_Guide.md**: Complete testing guide with integration tests and troubleshooting
- **Testing_Workflows_Overview.md**: GitHub Actions workflows explanation and interpretation
- **Input_Validation.md**: Input validation and error handling procedures
- **XML_Validation_Improvements.md**: XML processing and validation testing

### processAPI.md

- **Purpose**: API processing and incremental synchronization
- **References**:
  - [Documentation.md](./Documentation.md) for system architecture
  - [Rationale.md](./Rationale.md) for project background
  - [processPlanet.md](./processPlanet.md) for related processing workflows
  - [Testing_Guide.md](./Testing_Guide.md) for testing procedures

### processPlanet.md

- **Purpose**: Planet file processing and historical data handling
- **References**:
  - [Documentation.md](./Documentation.md) for system architecture
  - [Rationale.md](./Rationale.md) for project background
  - [processAPI.md](./processAPI.md) for related processing workflows
  - [Testing_Guide.md](./Testing_Guide.md) for testing procedures

### WMS Documentation

- **WMS_Guide.md**: Complete WMS guide with installation and configuration
- **WMS_Technical.md**: Technical specifications and architecture
- **WMS_User_Guide.md**: User guide for mappers and end users
- **WMS_Administration.md**: Administration guide for system administrators
- **WMS_API_Reference.md**: Complete API reference and examples

## Software Components

### System Documentation

- **Architecture Overview**: High-level system design and components
- **Data Flow**: How data moves through the system
- **Database Schema**: Table structures and relationships
- **API Integration**: OSM API usage and data processing

### Processing Documentation

- **API Processing**: Real-time data processing from OSM API
- **Planet Processing**: Large-scale data processing from Planet files

> **Note:** ETL Processes, Data Marts, and DWH features are maintained in
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### Technical Specifications

- **Performance Requirements**: System performance expectations
- **Security Considerations**: Data protection and access controls
- **Scalability**: System scaling and optimization strategies
- **Monitoring**: System monitoring and alerting procedures

## Usage Guidelines

### For System Administrators

- Monitor system health and performance
- Manage database maintenance and backups
- Configure processing schedules and timeouts
- Review [Documentation.md](./Documentation.md) for deployment guidelines

### For Developers

- Understand data flow and transformation processes
- Modify processing scripts and data ingestion procedures
- Study [processAPI.md](./processAPI.md) and [processPlanet.md](./processPlanet.md) for implementation details

> **Note:** For ETL procedures and analytics capabilities, see
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### For Data Analysts

- Query the notes database for custom analytics
- Review [Documentation.md](./Documentation.md) for data structure information

> **Note:** For data warehouse queries, data marts, and advanced analytics features
> (timezones, seasons, continents, application versions), see
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### For End Users

- View note activity and contribution metrics
- Read [Rationale.md](./Rationale.md) to understand the project's purpose

> **Note:** For interactive web visualization of user and country profiles, hashtag analysis, and campaign performance,
> see [OSM-Notes-Viewer](https://github.com/OSMLatam/OSM-Notes-Viewer).
> For data warehouse and analytics backend, see [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

## Dependencies

- Markdown rendering for proper display
- Diagrams and charts for visual documentation
- Code examples and configuration samples

## Contributing to Documentation

When updating documentation:

1. **Maintain Cross-References**: Update related document references
2. **Keep Language Consistent**: All documentation is now in English
3. **Test Links**: Verify all internal links work correctly
