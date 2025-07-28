ToDo list

# New features

## Base

* Corregir las diferencias que se identifican con el monitor script.
* Si falla processPlanet base, enviar mail, ya que hay algo mal.

## Check monitor

All good.

## ETL

* Generar un reporte de cambios identificados al cargar la ETL.
  * Los select cambiarlos a exports para mostrar otras cosas.
* Contar los hashtags de las notas en la ETL.
* Calcular la cantidad de hashtags y ponerla en FACTS
* En el ETL calcular la cantidad de notas abiertas actualmente.
  * por usuario? total?
* En el ETL mantener la cantidad de notas abiertas en el país.
* Usar la secuencia de comentarios en los facts
* Factorizar CREATE and INITIAL en Staging, ya que tiene partes comunes
* Usar una DB direferente para el DWH
* Cuando se actualizan los países, puede que algunas notas cambien de pais
 por lo que hay que actualizar la dimension, y todo usuario y pais de datamarts
 afectados
  * La mejor estrategia es actualizar los valores del modelo estrella.
  * Pero se debe asegurar que los valores de los datamarts los toman en
    cuenta. Podría ser que se tengan que calcular todo de nuevo.

## Monitor ETL

* Revisar cuando una nota se reabre, que se quite el closed en DWH (pero implica
  un update lo cual es malo).
  * O procesar estos de una manera diferente. Por ejemplo teniendo el max
    action.
* Monitor debe revisar que la cantidad de comentarios es la misma de actions en
  facts.
  * Algo similar para los datamarts.
* Cuando se ejecuta el datamart de nuevo, vuelve a cargar las notas del mismo
  dia, ya que había cargado.
  * Parece que ya se arregló, ya que estaba cargando todo el día de nuevo

## Datamarts

* Mostrar aplicaciones usadas para notas, tanto para usuarios como para países.
  * Se identifican a partir del texto de los comentarios.
* Hacer un analizador de hashtags.
  * Incluir los hashtags de una nota. HECHO
  * Mostrar los hashtags más usados en país y notas.
  * Filtrar notas por hashtags.
* Ajustar los queries de los hashtags para relacionar con la secuencia de
  comentario
* Definir los badges y asignarlos.
* Procesar en paralelo los usuarios de datamart, ya que actualmente dura muchas
  horas.
* Calidad de la nota. Menos de 5 caracteres es mala. Menos de 10 regular. Mas de
  200 compleja, Mas de 500 un tratado.
* Usar "tiempo para resolver notas" en los datamart
* Día con más notas creadas
* Hora con más notas creadas
* Tabla de notas aún en estado abierto de cada año
  * Las columnas son los años desde 2013.
  * Las filas son los países
  * Cada uno de los campos es las notas de cada año que aún están abiertas.
  * Colombia solo tiene notas de 2023
  * Chile tiene solo 1 de 2016 de bien abajo
  * Mostrar un gráfico de notas abiertas en un año, con eje por mes, donde
    se muestre la evolución, donde se vea que las notas viejas aún están
    abiertas.
* Por país, las notas que tomaron más tiempo en cerrarse
* Mostrar el tiempo promedio de resolución de notas
  * Un valor histórico
  * Valor por año para mostrar el desempeño
* Mostrar el timestamp del comentario más reciente en la DB - Última
  actualización de la db
* Cantidad de notas aun en estado abierto
* Tener rankings de los 100 histórico, último año, último mes, hoy
  * El que más ha abierto, más cerrado, más comentado, más reabierto
* Mostrar el ranking de países como Neis. Abiertas, cerradas, actualmente
  abiertas, y la tasa.
* Ranking de los usuarios que más han abierto y cerrado notas mundo.
* Promedio de comentarios por notas
* Promerio de comentarios por notas por país

## Visualizer

* herramienta para visualizar datos: puede ser metabase desde caprover, o redash
* Crear SPs para consultar el perfil. Y así poder guardar qué perfiles están
  siendo visitados
  * Podría generar un archivo JSON, y que el archivo sea usado para por el
    generador de código HTML estático.
* Mostrar de manera diferente la cuenta
  <https://www.openstreetmap.org/user/ContributionReviewer>
* Mostrar resultados con link a OSM y al API. El API ofrece detalles de horas,
  pero no mapa.
* Mostrar la hora actual del servidor de DB.
* Mostrar la hora del procesamiento.
* Github tiles de <https://github.com/sallar/github-contributions-canvas>

## Other

* Poder acceder al listado de todas, o las últimas 10 000 abiertas y 10 000
  cerradas de una persona
* Exportar la db en formato CSV para que pueda ser publicada.
  * Tener un mecanismo que la exporte periódicamente y la publique.
* Mostrar un gráfico animado de cómo se mueve el top 10 del Open/closed a lo
  largo del tiempo. Como esas gráficas animadas que muestran países más
  productores.

## Documentation

* Hacer un diagrama de la curva de puntos de las actividades del último año
  (GitHib tiles).
* Hacer un diagrama de componenetes, enfocado en el flujo de la información,
  dónde la volva y dónde la obtiene cada elemento.

-- ANDRES, EJECUTA ESTO. MUESTRA CUÁNTOS USUARIOS SOLO HAN HECHO UNA CONTRIBUCIÓN
-- INCLUSIVE SE PODRIA CONVERTIR PARA MOSTRAR LA TASA DE USUARIOS QUE POCO HACEN
select count(1)
from (
 select f.action_dimension_id_user user
 from dwh.facts f
 group by f.action_dimension_id_user
 having count(1) = 1
) as t

* revisar que BACKUP solo es para la descarga de paises. Ya que la ubicacion
de notas es por defecto
