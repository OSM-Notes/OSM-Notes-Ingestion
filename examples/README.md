# Examples Directory

This directory contains practical examples and configuration templates for the OSM Notes Ingestion project.

## Available Examples

### Configuration Examples

- **[alert-configuration.example](./alert-configuration.example)** - Alert system configuration
  - Email alerts setup
  - Troubleshooting guide
  - Migration from external monitoring

- **[crontab-setup.example](./crontab-setup.example)** - Crontab configuration
  - Basic setup (recommended)
  - Alternative frequencies
  - With alerts enabled
  - Monitoring instructions

- **[database-setup.example](./database-setup.example)** - Database configuration
  - PostgreSQL setup
  - Required extensions
  - Testing and troubleshooting

- **[properties-configuration.example](./properties-configuration.example)** - Properties file configuration
  - Basic configuration
  - Customizations
  - Validation steps

## How to Use These Examples

1. **Choose the appropriate example** for your setup
2. **Copy the relevant configuration** to your actual configuration files
3. **Modify the values** to match your environment
4. **Test the configuration** before applying

## Quick Start

1. **Database Setup**: Use `database-setup.example` to configure PostgreSQL
2. **Properties Configuration**: Use `properties-configuration.example` to configure the application
3. **Crontab Setup**: Use `crontab-setup.example` to schedule the processing
4. **Alert Configuration**: Use `alert-configuration.example` to set up monitoring

## Configuration Files Location

- **Properties**: `etc/properties.sh`
- **Database**: PostgreSQL configuration files
- **Crontab**: User's crontab (`crontab -e`)
- **Alerts**: Environment variables or properties file

## Testing Your Configuration

After applying any configuration:

1. **Test database connection**:
   ```bash
   psql -U $DB_USER -d $DBNAME -c "SELECT 1;"
   ```

2. **Test email configuration**:
   ```bash
   echo "Test email" | mail -s "Test" $ADMIN_EMAIL
   ```

3. **Test script execution**:
   ```bash
   ./bin/process/processAPINotes.sh
   ```

4. **Check logs**:
   ```bash
   tail -f /tmp/processAPINotes_*/processAPINotes.log
   ```

## Troubleshooting

If you encounter issues:

1. **Check the logs** for error messages
2. **Verify configuration** using the validation commands in the examples
3. **Test individual components** (database, email, API access)
4. **Review the documentation** in the `docs/` directory

## Support

For additional help:

- **Documentation**: Check the `docs/` directory
- **Issues**: Report issues on the project repository
- **Community**: Join the OSM community discussions

---

**Note**: These examples are provided as templates. Always customize them for your specific environment and requirements.