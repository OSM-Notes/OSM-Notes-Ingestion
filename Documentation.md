This explanation was written to start using AI and speed and improve the
development of this project.

En OpenStreetMap hay una funcionalidad que se llaman notas
(https://wiki.openstreetmap.org/wiki/Notes) y buscan hacer reportes,
principalmente en terreno donde se describe una incongruencia entre lo que
existe y lo que está mapeado en el mapa. De hecho hay una documentación de cómo
crear notas - https://learnosm.org/en/beginner/notes/.

Las notas puedes crearse de manera anónima, o autenticado en OSM. Y para
resolverlas, los mapeadores las leen, analizan el texto, y de acuerdo al
contenido de la nota, como a lo que está ya en el mapa, deciden o no si
se requiere realizar un cambio en el mapa.

Muchas notas puede que no requieran cambios en el mapa. Otras notas pueden
tener información falsa o incompleta. Por lo tanto, resolver una nota es una
tarea que puede ser fácil o complicado.

También, hay notas que han sido creadas desde el computador, por ejemplo para
reportar elementos faltantes en el mapa, como un río que no está mapeado. Este
tipo de notas puede tomar bastante en hacer el cambio en el mapa.

La funcionalidad de mapas se incorporó en OSM como una extensión de la API v0.6
en el 2013. Antes había un proyecto paralelo que se llamaba OpenStreetBugs que
ofrecía una funcionalidad similar, pero se integró en OSM.

La situación actual es que la actividad de resolver notas no es muy promovida
dentro de la comunidad OSM, y hay notas muy viejas. Para algunos mapeadores,
esas notas ya no ofrecen mucho valor, y deberían ser cerradas. Por otro lado,
algunos mapeadores consideran que para resolver las notas se debe verificar los
datos; sin embargo, esto puede ser una tarea imposible ya que no hay datos
alternos disponibles, y desplazarse a la ubicación de las notas no es práctico.

Debido a todo esto, las comunidades de los diferentes países, y los mapeadores
tienen diferentes puntos de vista y diferentes alcances con respecto a la
resolución de notas. Pero este trabajo es difícilmente identificable, ya que
hay pocas estadísticas.

El único lugar que indica el desempeño con respecto al procesamiento de notas
es la página ResultMaps de Neis Pascal:
https://resultmaps.neis-one.org/osm-notes donde se pueden ver las notas
abiertas de todos los países, el desempeño de notas en los últimos días.
Ya en la página de cada país se puede ver el listado de las últimas 1000
notas, además de un link hacia las 10 mil notas abiertas. Acceder a esta
página es una de las estrategias para resolver notas masivamente.

Por otro lado, en la sección de board del mismo sitio web:
https://osmstats.neis-one.org/?item=boards se puede ver el top 100 de
usuarios que más han abierto notas y que más han cerrado (en la sección Notes).

Además, este sitio web ofrece un perfil de contribución en OpenStreetMapp, que
se llama How Did You Contribute - HDYC, y dicho perfil permite obtener
información detallada del mapeador. Esta es una página del usuario AngocA:
https://hdyc.neis-one.org/?AngocA

Ahí se puede identificar desde cuándo creó la cuenta, cuántos días ha mapeado,
el desempeño por país, qué tipos de elementos ha creado/modificado/borrado,
las etiquetas utilizadas, entre otros elementos. También tiene un pequeño
apartado de cuántas notas ha abierto, y cuántas ha cerrado.

La página de HDYC puede considerarse como el único perfil de contribución por
usuario, y uno de los pocos por país, sin embargo la información de notas
es muy limitada.

Este proyecto busca ofrecer un perfil como el de HDYC, mostrando información
sobre las actividades alrededor de las notas: apertura, comentario, resolución,
reapertura. Esto por país (que viene a ser cada una de las comunidades de OSM)
y por usuario. Tener una especie de Tiles, como los GitHub Tiles verdes que
muestren su actividad en el último año, días importantes como el que más notas
cerró, cantidad de notas abiertas y cerradas por cada año, etc. Con esto, el
mapeador puede medir su trabajo.

También debe mostrarse el desempeño de las notas por hashtags, indicando la
fecha en que comenzó, cuántas notas se han creado, y cerrado, y otras
estadísticas. Actualmente, no hay herramientas que aprovechen los hashtags
de las notas, sin embargo, han comenzado a ser usados cada vez más.

Otra opción es ver el desempeño por aplicación, e identificar cómo están
siendo usadas con respecto a las notas.

----

Con respecto al código inicial, se ha escrito principalmente en Bash para las
interacciones con el API de OSM para traer las nuevas notas, y por medio del
Planet de OSM para descargar el archivo histórico de notas.

Por otro lado, se ha usado Overpass para descargar los países y otras regiones
en el mundo, y con esta información poder asociar una nota con un territorio.

Es necesario aclarar que el documento XML del Planet para notas no tiene la
misma estructura del XML recuperado a través del API. Ambas estructuras de XML
están en el directorio xsd para validarlos de manera independiente.

Con toda esta información, se ha diseñado un data warehouse, que está compuesto
por un conjunto de tablas en modelo estrella, una ETL que carga los datos
históricos en dichas tablas, usando unas tablas de staging.

Posteriormente, se crea unos datamart para usuarios y para países, para que los
cálculos de los datos ya estén precalculados al momento de consultar los
perfiles.