This is a list of errors, faced during multiple execution. They could
eventually be converted into GitHub issues, specially those that are known
to be real errors, but almost impossible to identify.

====


DATE: 2024-01-15
DESC: Esta apareciendo este error, parece que ocurre cuando el bot de neis
escribe dos comentarios iguales.
Solo se ve el abrir, un comentario y el de cerrado. Pero no los dos comentarios.


NOTICE:  End loop
ERROR:  insert or update on table "note_comments_text" violates foreign key constraint "fk_note_comment_uniq"
DETAIL:  Key (note_id, sequence_action)=(3037001, 4) is not present in table "note_comments".
20240115_19:00:21 ERROR: The script processAPINotes did not finish correctly. Line number: 407.
notes@maptimebogota-lenovo:/tmp/processAPINotes_5Ts8YM$ grep 3037001 *
OSM-notes-API.xml:  <id>3037001</id>
OSM-notes-API.xml:  <url>https://api.openstreetmap.org/api/0.6/notes/3037001.xml</url>
OSM-notes-API.xml:  <reopen_url>https://api.openstreetmap.org/api/0.6/notes/3037001/reopen.xml</reopen_url>
output-note_comments.csv:3037001,'opened','2022-02-04 10:38:19 UTC',15013980,'dannyasl'
output-note_comments.csv:3037001,'commented','2024-01-13 21:45:55 UTC',5060057,'NeisBot'
output-note_comments.csv:3037001,'commented','2024-01-14 09:02:58 UTC',5060057,'NeisBot'
output-note_comments.csv:3037001,'closed','2024-01-15 18:52:21 UTC',13847282,'Rhodez'
output-notes.csv:3037001,77.7449024,-85.2519107,"2022-02-04 10:38:19 UTC","2024-01-15 18:52:21 UTC","close"
output-text_comments.csv:3037001,'Y''a un banc là, même que y''a 2 pingouins ghetto.'
output-text_comments.csv:3037001,'Hi dannyasl,
output-text_comments.csv:3037001,'Hi dannyasl,
output-text_comments.csv:3037001,'unhelpful note'
processAPINotes.log:DETAIL:  Key (note_id, sequence_action)=(3037001, 4) is not present in table "note_comments".


----


ERROR:  insert or update on table "note_comments_text" violates foreign key constraint "fk_note_comment_uniq"
DETAIL:  Key (note_id, sequence_action)=(4082535, 2) is not present in table "note_comments".

Revisar los mensajes que se pusieron, para identificar el orden de inserción de los objetos.


----


DATE: 2024-01-29
2024-01-29 13:53:08 - functionsProcess.sh:__processBoundary:562 - DEBUG - UPDATE countries AS c
     SET country_name = 'الأردن', country_name_es = 'Jordania',
     country_name_en = 'Jordan',
     geom = (
      SELECT geom FROM (
       SELECT 184818, ST_Union(ST_makeValid(wkb_geometry)) geom
       FROM import GROUP BY 1
      ) AS t
     ),
     updated = true
     WHERE country_id = 184818
ERROR:  null value in column "geom" of relation "countries" violates not-null constraint
DETAIL:  Failing row contains (184818, الأردن, Jordania, Jordan, null, null, null, 6, null, t).
20240129_13:53:08 ERROR: The script updateCountries did not finish correctly. Line number: 563


-----


DESC: Durante la actualizacion por medio del API.
Si hay un error de inserción de un comentario, y ya se insertaron todas las notas, habrá un hueco.
El max de notas (abierta o cerrada) va a tener el valor reciente, pero la parte de comentarios estará atrasada, y si se vuelve a ejecutar, habrá un problema

Solución: tener max de notas y otro max de comentarios para procesamiento.
Pero el max update que se tiene actualmente para descarga, sin importar que se hayan insertado las notas o comentarios de la anterior descarga

Revisar si con la sincronizacion se arregla lo faltante.


----


Error con aria2c

[#6ea47c 0B/0B CN:1 DL:0B]

02/26 06:05:29 [ERROR] CUID#7 - Download aborted. URI=https://planet.openstreetmap.org/notes/planet-notes-latest.osn.bz2
Exception: [AbstractCommand.cc:340] errorCode=2 Timeout.

Debe ser debido a que no habia internet.
No debe dejar archivo failed, porque no se debe bloquear la siguiente ejecucion


----


DATE: 2024-04-26
Error de conexion

CREATE PROCEDURE
COMMENT
CREATE PROCEDURE
COMMENT
--2024-04-26 01:15:01--  https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=10000&closed=-1&sort=updated_at&from=2024-04-26T00:59:55Z
Resolving api.openstreetmap.org (api.openstreetmap.org)... 184.104.179.139, 184.104.179.140, 184.104.179.141, ...
Connecting to api.openstreetmap.org (api.openstreetmap.org)|184.104.179.139|:443... failed: Connection timed out.
Connecting to api.openstreetmap.org (api.openstreetmap.org)|184.104.179.140|:443... failed: Connection timed out.
Connecting to api.openstreetmap.org (api.openstreetmap.org)|184.104.179.141|:443... failed: Connection timed out.
Connecting to api.openstreetmap.org (api.openstreetmap.org)|2001:470:1:fa1::b|:443... failed: Network is unreachable.
Connecting to api.openstreetmap.org (api.openstreetmap.org)|2001:470:1:fa1::c|:443... failed: Network is unreachable.
Connecting to api.openstreetmap.org (api.openstreetmap.org)|2001:470:1:fa1::d|:443... failed: Network is unreachable.
20240426_01:21:33 ERROR: The script processAPINotes did not finish correctly. Line number: 507.


----


DATE: 2024-02-02
psql:/home/notes/OSM-Notes-profile/sql/process/processAPINotes_32_insertNewNotesAndComments.sql:99: ERROR:  Trying to reopen an opened note: 3924749 - open reopened
CONTEXT:  PL/pgSQL function insert_note_comment(integer,note_event_enum,timestamp with time zone,integer,character varying) line 40 at RAISE
SQL statement "CALL insert_note_comment (3924749, 'reopened'::note_event_enum, TO_TIMESTAMP('2024-02-02 07:52:52', 'YYYY-MM-DD HH24:MI:SS'), 10493879, 'Oskarst_')"
PL/pgSQL function inline_code_block line 25 at EXECUTE
20240202_19:11:23 ERROR: The script processAPINotes did not finish correctly. Line number: 395
2024-02-02 19:11:23 - functionsProcess.sh:__onlyExecution:152 - #-- STARTED __ONLYEXECUTION --#
2024-02-02 19:11:23 - functionsProcess.sh:__onlyExecution:158 - |-- FINISHED __ONLYEXECUTION - Took: 0h:0m:0s --|.

Se pusieron mas banderas, se muestra el statment del call, se invirtieron los logs.
Toca ver si está insertando primero el cerrado y después el abierto.
Es debido a un problema con el API que permite estas transiciones inválidas


-----


DATE: 2024-04-05
psql:/home/notes/OSM-Notes-profile/sql/dwh/Staging_61_loadNotes.sql:15: NOTICE:  2024-04-05 18:30:10.112904+00 - Error when getting the open date - note_id 4172438, sequence 2
psql:/home/notes/OSM-Notes-profile/sql/dwh/Staging_61_loadNotes.sql:15: ERROR:  null value in column "recent_opened_dimension_id_date" of relation "facts" violates not-null constraint
DETAIL:  Failing row contains (8937022, 4172438, null, 47, 2024-04-05 18:30:09.03975, 2024-04-05 18:26:35, closed, 4000, 518, 234219, 3993, 503, null, 4000, 518, 234219, null, null, null, null, null, null, null, null, null, null, 0).
CONTEXT:  SQL statement "INSERT INTO dwh.facts (
     id_note, dimension_id_country,
     action_at, action_comment, action_dimension_id_date,
     action_dimension_id_hour_of_week, action_dimension_id_user,
     opened_dimension_id_date, opened_dimension_id_hour_of_week,
     opened_dimension_id_user,
     closed_dimension_id_date, closed_dimension_id_hour_of_week,
     closed_dimension_id_user, dimension_application_creation,
     recent_opened_dimension_id_date, hashtag_1, hashtag_2, hashtag_3,
     hashtag_4, hashtag_5, hashtag_number
   ) VALUES (
     rec_note_action.id_note, m_dimension_country_id,
     rec_note_action.action_at, rec_note_action.action_comment,
     m_action_id_date, m_action_id_hour_of_week, m_dimension_user_action,
     m_opened_id_date, m_opened_id_hour_of_week, m_dimension_user_open,
     m_closed_id_date, m_closed_id_hour_of_week, m_dimension_user_close,
     m_application, m_recent_opened_dimension_id_date, m_hashtag_id_1,
     m_hashtag_id_2, m_hashtag_id_3, m_hashtag_id_4, m_hashtag_id_5,
     m_hashtag_number
   )"
PL/pgSQL function staging.process_notes_at_date(timestamp without time zone,integer,boolean) line 206 at SQL statement
SQL statement "CALL staging.process_notes_at_date(max_note_on_dwh_timestamp,
     qty_dwh_notes, true)"
PL/pgSQL function staging.process_notes_actions_into_dwh() line 100 at CALL
20240405_18:30:10 ERROR: The script ETL did not finish correctly. Line number: 409.

El error se produce porque la fecha del max processed está mayor a algunas
notas que no se han insertado en la tabla facts.
En este caso, toca procesar los que están en la tabla notes, que no están en
la tabla facts, y son inferiores a max_processed_timestamp
Con esto se debería arreglar el problema, pero la ejecución se debería hacer
cuando se valide que hay algo mal:
select 
note_id, nc.sequence_action
from note_comments nc 
except
select 
f.id_note, f.sequence_action
from dwh.facts f
Si el query anterior arroja algún registro, el procesamiento de la ETL podría
irse por otro lado, para ajustar los errores pasados. Esto se debe a que el query
está devolviendo los que no están en facts, pero ya son viejos-antes del max
processed time.

De pronto pueda ser necesario meter processing_time a notes, para 

=========================
=========================


DATE:2024-02-07
DESC: Too many request

Connecting to overpass-api.de (overpass-api.de)|65.109.112.52|:443... connected.
HTTP request sent, awaiting response... 429 Too Many Requests
2024-02-08 03:22:12 ERROR 429: Too Many Requests.

Solucion: Leer la salida del programa, si dice este error, esperar 30 segundos en el hilo y reintentar
Al parecer ya que hizo, toca ver si no vuelve a fallar por esto

DONE: Esto ya no debe estar pasando, porque reintenta si hay error o devuelve json invalido


-----


DATE: 2024-02-07
DESC: JSON incorrecto

SyntaxError: Unexpected end of JSON input
    at JSON.parse (<anonymous>)
    at legacyParsers (/usr/local/lib/node_modules/osmtogeojson/osmtogeojson:120:21)
    at ConcatStream.<anonymous> (/usr/local/lib/node_modules/osmtogeojson/node_modules/concat-stream/index.js:37:43)
    at ConcatStream.emit (events.js:326:22)
    at finishMaybe (/usr/local/lib/node_modules/osmtogeojson/node_modules/readable-stream/lib/_stream_writable.js:624:14)
    at endWritable (/usr/local/lib/node_modules/osmtogeojson/node_modules/readable-stream/lib/_stream_writable.js:643:3)
    at ConcatStream.Writable.end (/usr/local/lib/node_modules/osmtogeojson/node_modules/readable-stream/lib/_stream_writable.js:571:22)
    at ReadStream.onend (_stream_readable.js:683:10)
    at Object.onceWrapper (events.js:420:28)
    at ReadStream.emit (events.js:326:22)

El JSON fue truncado. Puede ser por muchos intentos consecutivos.
Solucion: revisar la salida del parseo de JSON, y si hay error, reintentar

Puede ser con
json_pp / jsonlint
o
echo {} | python -c "import sys,json;json.loads(sys.stdin.read());print 'OK'"
https://stackoverflow.com/questions/42385036/validate-json-file-syntax-in-shell-script-without-installing-any-package

O inclusive, defiir un json.schema
json validate --schema-file=schema.json --document-file=data.json
https://linuxhint.com/validate-json-files-from-command-line-linux/

DONE: Esto ya se corrigio, porque se valida el json


-----


Resolving api.openstreetmap.org (api.openstreetmap.org)... failed: Temporary failure in name resolution.
wget: unable to resolve host address ‘api.openstreetmap.org’

Esta fallando si hay un problema de reoslucion.
Por ejemplo, si no hay internet.

DONE: Este error deberia fallar la ejecucion actual, pero no dejar archivo failed.
porque no es un error bloqueante.


----


DATE: 2024-02-02
2024-02-02 14:39:22 (180 KB/s) - ‘/tmp/processPlanetNotes_237Ms2/3245621.json’ saved [67974]

ERROR 1: ERROR:  column "coastline" of relation "import" does not exist

ERROR 1: ERROR:  column "coastline" of relation "import" does not exist

ERROR 1: ERROR:  column "coastline" of relation "import" does not exist
no COPY in progress

ERROR 1: Unable to write feature 0 from layer 3245621.
ERROR 1: Terminating translation prematurely after failed
translation of layer 3245621 (use -skipfailures to skip errors)
Solucion: hacer secuencial la inserción en import
DONE: Esto ya se debió haber corregido, con el candado en el directorio


