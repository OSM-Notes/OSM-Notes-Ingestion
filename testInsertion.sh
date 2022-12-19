#!/bin/bash

# API notes tester. It creates mock notes:
# * Id bigger than 7 000 000.
# * Position 4/72
# * Created on 2000
# * Userid bigger than 20 000 000
# * User testUser
#
# SELECT * FROM dwh.dimension_users WHERE user_id >= 20000000;
# SELECT * FROM dwh.facts WHERE id_note >= 7000000;
# SELECT * FROM note_comments WHERE note_id >= 7000000;
# SELECT * FROM wms.notes_wms WHERE note_id >= 7000000;
# SELECT * FROM notes WHERE note_id >= 7000000;
#
# DELETE FROM dwh.dimension_users WHERE user_id >= 20000000;
# DELETE FROM dwh.facts WHERE id_note >= 7000000;
# DELETE FROM note_comments WHERE note_id >= 7000000;
# DELETE FROM wms.notes_wms WHERE note_id >= 7000000;
# DELETE FROM notes WHERE note_id >= 7000000;
#
# Author: Andres Gomez
# Version: 2022-12-22

NOTE_ID="7000000"
LATITUDE="4.000000"
LONGITUDE="-72.0000000"
CREATED_AT="2000-12-14 19:53:24 UTC"
CLOSED_AT=
STATUS_NOTE="open"

STATUS_COMMENT="opened"
USER_ID=20000000
USERNAME="testUser"

DBNAME=notes

echo "CALL insert_note (${NOTE_ID}, ${LATITUDE}, ${LONGITUDE}, '${CREATED_AT}',
  NULL, '${STATUS_NOTE}')" \
  | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

echo "CALL insert_note_comment(${NOTE_ID}, '${STATUS_COMMENT}', '${CREATED_AT}',
  ${USER_ID}, '${USERNAME}')" \
  | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

CREATED_AT="2000-12-14 19:53:25 UTC"
STATUS_COMMENT="commented"

echo "CALL insert_note_comment(${NOTE_ID}, '${STATUS_COMMENT}', '${CREATED_AT}',
  ${USER_ID}, '${USERNAME}')" \
  | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

CREATED_AT="2000-12-14 19:53:26 UTC"
STATUS_COMMENT="closed"

echo "CALL insert_note_comment(${NOTE_ID}, '${STATUS_COMMENT}', '${CREATED_AT}',
  ${USER_ID}, '${USERNAME}')" \
  | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

