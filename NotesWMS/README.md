# Configure Notes WMS

Notes WMS is a layer service that locates the open and closed notes in a map.
This layer can be included in JOSM or Vespucci to easily locate notes, and
process them.
By having the location of notes from a wide perspective, one can zoom in on
the areas where the notes are still open.
This service does not provide a lot of zoom detail, because it is only
necessary to have a rough idea where open notes are located.

As part of the service, it also locates closed notes.
This allows to identify areas where many notes have being opened, and imagine
the reason why.

This service uses the OSM Notes profile mechanism, which has an updated set
of notes (open and close).
To make WMS working, some changes on the database are necessary, to copy just
the necessary values into another table, with the geometry already created.
This speeds up the queries for the WMS, without impacting the notes table.

Then, it is necessary to configure GeoServer (which only needs to be downloaded)
and the basic configuration is explained here.

# Database configuration

* Provide a password to the database user.

```
ALTER USER myuser WITH PASSWORD 'mypassword';
```
* Change the database configuration to allow remote connections.
This link could be useful: https://www.bigbinary.com/blog/configure-postgresql-to-allow-remote-connection
Also, you can find the configuration file with this:

```
find / -name "postgresql.conf" 2> /dev/null
```

And modify the file like to listen any address:

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

```
psql -d "notes" -v ON_ERROR_STOP=1 -f "prepareDatabase.sql"
```

# Geoserver configuration

## Contact Information

### Organization

* Organization: OSM LatAm
* Online Resource: https://osmlatam.org
* Welcome: Set of layers provided by OpenStreetMap LatAm.

### Primary Contact

* Contact: Andres Gomez Casanova - AngocA
* Position: Volunteer
* Email: angoca@yahoo.com

### Address

* City: Bogota
* State: D.C.
* Country: Colombia

## Workspaces

* Name: OSM_Notes
* Namespace URI: OSM_Notes

## Stores

### Basic Store Info

* Workspace: OSM_Notes
* Data Source Name: 
* Description: Data for OSM Notes Profile

### Connection Parameters

* Host:
* Port:
* Database: notes
* User:
* Passwd:

## Layers

Layer from OSM_Notes:OSM_Notes_DS.

* View Name: Open OSM Notes
* SQL Statement:

```
select geometry
from notes
where closed_at is null
```

### Basic Resource Info

* Abstract: This layer shows the location of the currently open notes.
The color intensity shows the age of the creation time.

### Coordinate Reference Systems

* Declared SRS: EPSG:4326

### Bounding Boxes

* Compute from SRS bounds
* Compute from native bounds

## Styles

### Syle Data

* Name: Open notes
* Workspace: OSM_Notes
* Upload a style line: OpenNotes.sld

# Files

* ClosedNotes.sld - QGIS generated file for WMS style on closed notes.
* CountriesAndMaritimes.sld - QGIS generated file for WMS style on countries and
maritimes areas.
* README.md - This file.
* NotesStyles.qgz - QGIS file with the configuration to generate the SLD files.
* OpenNotes.sld - QGIS generated file for WMS style on open notes.
* prepareDatabase.sql - All the necessary scripts to synchronize the OSM Notes
profile mechanism with this WMS layer service.
