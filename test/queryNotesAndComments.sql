-- Diferencias entre notas en check y notas ya cargadas.
-- Primeros ids.
SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status
  FROM notes_check
   where note_id < 500000 
  EXCEPT
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status
  FROM notes
  WHERE (closed_at IS NULL OR closed_at < NOW()::DATE) 
  and note_id < 500000 
  order by note_id
  ;
-- 153166
-- 153187
-- 153214

-- Info de una nota en check
select note_id, latitude, longitude, created_at, status, closed_at, id_country
from notes_check
where note_id = $note
;
-- Info de una nota cargada
select note_id, latitude, longitude, created_at, status, closed_at, id_country
from notes
where note_id = $note
;
-- Info de comentarios en check
select note_id, sequence_action, event, created_at, id_user
from note_comments_check
where note_id = $note
order by sequence_action 
;
-- Info de comentarios cargados
select note_id, sequence_action, event, created_at, id_user
from note_comments
where note_id = $note
order by sequence_action
;

