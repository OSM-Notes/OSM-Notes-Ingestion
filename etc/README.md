# Configuration Files

This directory contains configuration files for the OSM-Notes-Ingestion project.

## Initial Setup

**IMPORTANT**: The actual configuration file (`properties.sh`) is not tracked in Git
for security reasons. You must create it from the example file:

```bash
# Copy example file to create your local configuration
cp etc/properties.sh.example etc/properties.sh

# Edit the file with your database credentials and settings
vi etc/properties.sh
```

The example files contain default values and detailed comments. Replace the
example values (like `myuser`, `changeme`, `your-email@domain.com`) with your
actual configuration.

## Files

### 1. properties.sh.example → properties.sh

Main configuration file with general project settings.

- **Example file**: `properties.sh.example` (tracked in Git)
- **Your local file**: `properties.sh` (not tracked in Git, contains your
  credentials)

## WMS Configuration

For **WMS (Web Map Service) layer publication** configuration, see the
[OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS) repository.

## Usage

### Loading Properties

```bash
# Load properties in a script
source etc/properties.sh

# Or set custom values before loading
export DBNAME="my_database"
source etc/properties.sh
```

## Best Practices

1. **Use Example Files**: Always copy from `.example` files to create your local
   configuration
2. **Never Commit Secrets**: The actual `properties.sh` file is in `.gitignore`
   and should never be committed
3. **Environment-Specific Files**: Create custom property files for different
   environments using the `_local` suffix (e.g., `properties.sh_local`)
4. **Secure Credentials**: Use environment variables for sensitive data when
   possible
5. **Validation**: Always validate properties before use
6. **Documentation**: Document custom configurations in your local files
7. **Version Control**: Only the `.example` files are tracked in Git (excluding
   secrets)
