Lista de ToDo's

* Procesar el texto de los comentarios. Debe insertarlos en otra tabla.
  * Se debe crear otro XSLT
  * Hacer un analizar de hashtags
* Definir los tipos de contribuidores, insertarlos y asignarlos dinámicamente.
* Definir los badges y asignarlos.
* Tener dimensión para mostrar el trabajo por semana.
  * Tener una variable de 24*7=168
  * Se podría quitar la dimensión día, ya que no se le ve mucho uso
* Revisar cuando una nota se reabre, que se quite el closed en DWH
  * O procesar estos de una manera diferente.
* Generar un reporte de cambios identificados al cargar la ETL.
* 3944119 ocultada y reactivada. Revisar que se procesa bien esta nota.
* Validar que esta nota se procesa bien https://api.openstreetmap.org/api/0.6/notes/3750896
* Mostrar resultados en OSM y en el API.
* Mostrar los tiles de actividad del último año.
  * Puede crearse un varchar de 365 o 7*52=364
* Día con más notas creadas
* Hora con más notas creadas
* Minuto con más notas creadas
* Tabla de notas aún en estado abierto de cada año
  * Las columnas son los años desde 2013.
  * Las filas son los países
  * Cada uno de los campos es las notas de cada año que aún están abiertas.
  * Colombia solo tiene notas de 2023
  * Chile tiene solo 1 de 2016 de bien abajo
* Mostrar el tiempo promedio de resolución de notas
  * Un valor histórico
  * Valor por año para mostrar el desempeño
* Poder acceder al listado de todas, o las últimas 10 000 abiertas y 10 000 cerradas de una persona
* Tener rankings de los 100 histórico, último año, último mes, hoy
  * El que más ha abierto, más cerrado, más comentado, más reabierto
* Por país, las notas que tomaron más tiempo en cerrarse
* Aplicaciones usadas para notas.
  * Mostrar en el perfil de país.
* Usar una DB direferente para el DWH