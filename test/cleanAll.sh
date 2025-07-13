#!/bin/bash

# ETL part.
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/datamartCountries/datamartCountries-dropDatamartObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/datamartUsers/datamartUsers-dropDatamartObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/Staging_removeStagingObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/dwh/ETL_13_removeDWHObjects.sql ;

# WMS part.
psql -d notes -f ~/OSM-Notes-profile/sql/wms/removeFromDatabase.sql ;

# Base part.
psql -d notes -f ~/OSM-Notes-profile/sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processAPINotes_11_dropApiTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/functionsProcess_12_dropGenericObjects.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes_11_dropSyncTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes_13_dropBaseTables.sql ;
psql -d notes -f ~/OSM-Notes-profile/sql/process/processPlanetNotes_14_dropCountryTables.sql ;

rm -rf /tmp/process*
