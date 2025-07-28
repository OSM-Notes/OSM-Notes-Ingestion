# Configure Notes WMS

Notes WMS is a layer service that locates the open and closed notes on a map.
This layer can be included in JOSM or Vespucci to easily locate notes, and
process them by location.
By having the location of notes from a wide perspective, one can zoom in on
the areas where the notes are still open.
This service does not provide a lot of zoom detail, because it is only
necessary to have a rough idea of where open notes are located.

As part of the service, it also locates closed notes.
This allows us to identify areas where many notes have been opened, and imagine
the reason why.

This service uses the OSM Notes profile mechanism, which has an updated set
of notes (open and close).
To make WMS work some changes on the database are necessary, to copy just
the necessary values into another table, with the geometry already created.
This speeds up the queries for the WMS, without impacting the notes base table.

Then, it is necessary to configure GeoServer (which only needs to be downloaded)
and the basic configuration is explained here.

The layer is configured with a style (SLD file) that changes the color of the
note according to its age.
When open notes, the older the darker the note, meaning it has less value than
recently open notes.
When closed notes, the lighter the older, meaning it was processed long before.

# Installation

## Automated Installation (Recommended)

Use the WMS manager script for easy installation and management:

```bash
# Install WMS components
~/OSM-Notes-profile/bin/wms/wmsManager.sh install

# Check installation status
~/OSM-Notes-profile/bin/wms/wmsManager.sh status

# Remove WMS components
~/OSM-Notes-profile/bin/wms/wmsManager.sh deinstall

# Show help
~/OSM-Notes-profile/bin/wms/wmsManager.sh help
```

The WMS manager script includes:
- ✅ Automatic validation of prerequisites (PostgreSQL, PostGIS)
- ✅ Database connection testing
- ✅ Installation status checking
- ✅ Safe installation with conflict detection
- ✅ Force reinstallation option
- ✅ Dry-run mode for testing
- ✅ Comprehensive error handling

## Manual Installation

For manual installation, follow these steps:

# Database configuration

* Provide a password to the database user.

```
ALTER USER myuser WITH PASSWORD 'mypassword';
```

* Change the database configuration to allow remote connections.
This link could be useful: 
https://www.bigbinary.com/blog/configure-postgresql-to-allow-remote-connection
Also, you can find the configuration file with this:

```
find / -name "postgresql.conf" 2> /dev/null
```

And modify the file to make Postgres listen from any address:

```
vi /etc/postgresql/14/main/postgresql.conf

listen_addresses = '*'
```

Restart the service:

```
sudo systemctl restart postgresql.service
```

Allow users to connect remotely:

```
find / -name "pg_hba.conf" 2> /dev/null
vi /etc/postgresql/14/main/pg_hba.conf
host    all             all              0.0.0.0/0                       md5
host    all             all              ::/0                            md5
```

* Execute the necessary SQLs to adapt the database to synchronize with this
service.
Let's suppose the Postgres database is called `notes`.

```
psql -d "notes" -v ON_ERROR_STOP=1 -f "prepareDatabase.sql"
```

# Geoserver configuration

Configure the GeoServer to publish the layer from the database, following
these instructions.

## Contact Information

### Organization

* Organization: OSM LatAm
* Online Resource: https://osmlatam.org
* Welcome: Set of layers provided by OpenStreetMap LatAm.

### Primary Contact

* Contact: Andres Gomez Casanova - AngocA
* Position: Volunteer
* Email: angoca @ osm.lat

### Address

* City: Bogota
* State: D.C.
* Country: Colombia

## Workspaces

* Name: OSM_Notes
* Namespace URI: OSM_Notes

## Stores

### Basic Store Info

PostGIS

* Workspace: OSM_Notes
* Data Source Name: OSM Notes DS
* Description: Data for OSM Notes

### Connection Parameters

* Host:
* Port:
* Database: notes
* User:
* Passwd:

## Styles

### Syle Data

SLD files are under the `sld` directory.

* Name: Open notes style
* Workspace: OSM_Notes
* Upload a style line
  * Choose File: OpenNotes.sld
  * Upload...
* Legend: Add legend

* Name: Closed notes style
* Workspace: OSM_Notes
* Upload a style line
  * Choose File: ClosedNotes.sld
  * Upload...
* Legend: Add legend

## Layers

__Open Notes__

**On Data tab:**

Add layer from OSM_Notes:OSM_Notes_DS.

Configure new SQL view...

* View Name: Open OSM Notes layer
* SQL Statement:

```
SELECT /* Notes-WMS */ year_created_at, year_closed_at, geometry
FROM wms.notes_wms
WHERE year_closed_at IS NULL
ORDER BY year_created_at DESC
```

## Styles

For each layer.

### Publishing

* Default

### Basic Resource Info

* Abstract: This layer shows the location of the currently open notes.
The color intensity shows the age of the creation time.

### Coordinate Reference Systems

* Declared SRS: EPSG:4326

### Bounding Boxes

* Compute from SRS bounds
* Compute from native bounds

**On the Publishing tab:**

### WMS Settings - Layers Settings

* Additional Styles: OSM_Notes:OpenNotes

### WMS Attribution

* Attribution Text: OpenStreetMap contributors
* Attribution Link: https://www.openstreetmap.org/copyright

**On the Tile Caching tab:**

### Tile cache configuration

* Uncheck image/jpeg
* (Optional) Put 3600 for Expire Server cache after n seconds.
* Styles: Default Style: OSM_Notes:ClosedNotes (and check it).
* Gridset:
  * Published zoom levels: 0 - 8

__Closed Notes__

**On the Data tab:**

Layer from OSM_Notes:OSM_Notes_DS.

* View Name: Closed OSM Notes layer
* SQL Statement:

```
SELECT /* Notes-WMS */ year_created_at, year_closed_at, geometry
FROM wms.notes_wms
WHERE year_closed_at IS NOT NULL
ORDER BY year_created_at DESC
```

### Basic Resource Info

* Abstract: This layer shows the location of the closed notes.
The color intensity shows the age of the creation time.

**On the Publishing tab:**

### WMS Settings - Layers Settings

* Additional Styles: OSM_Notes:CloseNotes

The other options the same as for open notes.

## Disk Quota

* Enable disk quota
* Maximum tile cache size: 5 GB

## BlobStores

* Add new:
* Type of BlobStore: File BlobStore
* Identifier: OSM Notes
* Enabled.
* Default.
* Base Directory: A location with more than 50 GB space.

## Tile Layers

* Choose each layer, and click on Seed/Truncate.

## Passwords

* Change active master provider.

## Users, Groups, Roles

* Change admin password.

## Additionally

* Activate BlobStores.

# Files

Under `sld`:

* `ClosedNotes.sld` QGIS generated file for WMS style on closed notes.
* `CountriesAndMaritimes.sld` QGIS generated file for WMS style on countries
  and maritimes areas.
* `OpenNotes.sld` QGIS generated file for WMS style on open notes.

Under `sql/wms`

* `prepareDatabase.sql` All the necessary scripts to synchronize the OSM
  Notes profile mechanism with this Notes WMS layer service.
* `removeFromDatabase.sql` Removes the Notes WMS part from the database.


