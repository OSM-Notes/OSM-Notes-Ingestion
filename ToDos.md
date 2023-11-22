ToDo list

# New features

* Procesar el texto de los comentarios.
  * Debe insertarlos en otra tabla.
  * Se debe crear otro XSLT.
* Hacer un analizador de hashtags.
  * Incluir los hashtags de una nota.
  * Mostrar los hashtags más usados en país y notas.
  * Filtrar notas por hashtags.
* Definir los tipos de contribuidores, insertarlos y asignarlos dinámicamente.
* Definir los badges y asignarlos.
* Generar un reporte de cambios identificados al cargar la ETL.
  * Los select cambiarlos a exports para mostrar otras cosas.
* Poder acceder al listado de todas, o las últimas 10 000 abiertas y 10 000 cerradas de una persona
* Usar una DB direferente para el DWH
* Procesar en paralelo los usuarios de datamart.
* Usar un mecanismo de logger para postgres
* Crear SPs para consultar el perfil. Y así poder guardar qué perfiles están siendo visitados
* Probar https://crates.io/crates/anglosaxon en vez de saxon

## Profile

* Mostrar aplicaciones usadas para notas, tanto para usuarios como para países.
  * Se identifican a partir del texto de los comentarios.
* Mostrar resultados con link a OSM y al API. El API ofrece detalles de horas, pero no mapa.
* Mostrar los tiles de actividad del último año.
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
* Por país, las notas que tomaron más tiempo en cerrarse

# Check

* Revisar cuando una nota se reabre, que se quite el closed en DWH (pero implica un update lo cual es malo).
  * O procesar estos de una manera diferente. Por ejemplo teniendo el max action.
* 3944119 ocultada y reactivada. Revisar que se procesa bien esta nota.
* Validar que esta nota se procesa bien https://api.openstreetmap.org/api/0.6/notes/3750896
* Tener rankings de los 100 histórico, último año, último mes, hoy
  * El que más ha abierto, más cerrado, más comentado, más reabierto
* Cuando se ejecuta el datamart de nuevo, vuelve a cargar las notas del mismo dia, ya que había cargado