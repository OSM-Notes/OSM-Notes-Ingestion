#!/bin/bash

# ETL part.
psql -d notes -f ./sql/dwh/datamartCountries/datamartCountries_dropDatamartObjects.sql
psql -d notes -f ./sql/dwh/datamartUsers/datamartUsers_dropDatamartObjects.sql
psql -d notes -f ./sql/dwh/Staging_removeStagingObjects.sql
psql -d notes -f ./sql/dwh/ETL_12_removeDatamartObjects.sql
psql -d notes -f ./sql/dwh/ETL_13_removeDWHObjects.sql

# WMS part.
psql -d notes -f ./sql/wms/removeFromDatabase.sql

# Base part.
psql -d notes -f ./sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql
psql -d notes -f ./sql/process/processAPINotes_11_dropApiTables.sql
psql -d notes -f ./sql/functionsProcess_12_dropGenericObjects.sql
psql -d notes -f ./sql/process/processPlanetNotes_11_dropSyncTables.sql
psql -d notes -f ./sql/process/processPlanetNotes_13_dropBaseTables.sql
psql -d notes -f ./sql/process/processPlanetNotes_14_dropCountryTables.sql

rm -rf /tmp/process*
