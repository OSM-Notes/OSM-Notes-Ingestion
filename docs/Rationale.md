# Why this project

Notes have been an internal part of OpenStreetMap since 2013.
They have become more important because they are considered feedback from our
users.
Also, by solving notes, it expresses that the map is alive, where feedback is
considered, and OSM mappers are listing the users.

Many mappers are resolving notes, and new ones are starting to get involved into
this process.
For this reason, many questions are appearing, and new tools are being
developed.

On the other side, the OpenStreetMap website does not offer a straightforward
way to see notes created from a particular user (one should navigate the user
and move forward through pages).
This list does not provide information about where the note was created.
Also, this website does not provide a list grouping notes by communities,
like countries.
Showing notes for a particular place helps engage mappers close the notes in
that area.

Also, there are third-party alternatives:

* ResultMaps from Pascal Neis is a valuable tool to identify notes, open and
close ones.
Also, it supplies a list of notes for a specific country, as well as some
statistics per country.
Finally, it has a board about the users that are opening and closing the most.
* NotesReview is just a viewer of 50 notes.
This service is very restricted, and it does not work to help thousands of
notes.
* OSM Note Viewer is an excellent note analyzer with many options for
filtering and exporting.
However, it does not provide any analytical tool to show the status of the notes
per user or country.
* Notes Map is a good try to show a map of notes with a custom icon per type of
note.
The downside is that the site is only in German.
There is not a legend for the icons and the project does not have an issue
system.
* Notes heatmap is a tool to visualize the location of the notes.
This helps to show areas that need a lot of work, but that is all.

# How this project work

As previously said, the purpose of this site is to supply better information
about notes in near real-time.

The main challenge is to get the data, which is in separate places:

* Country and maritime boundaries are in OpenStreetMap, but the way to obtain
them is with Overpass to retrieve all relations that have some specific tags.
This involves several requests to Overpass, convert the results, to finally
insert them into a Postgres database.
Once we have this information in the database, we can query if a specific point
(note's location) is inside a country or not.
* Most recent note changes can be obtained from OpenStreetMap API calls.
However, this service is limited to 10 000 notes, and the current number of
notes is above 4 million.
Therefore, it is necessary to retrieve the whole note's history in another
fashion to start working faster and not stress the API.
* OSM provides a daily dump from parts of the database and publishes it in the
Planet website.
The most well-known dataset is the map data, but for this project, it is
necessary to obtain the note dump, which contains the whole history of notes
since 2013, only excluding the hidden ones.

In other words, this project uses these three sources of data to keep the
database almost in sync with OSM data.
This is the most challenging thing of this project, and therefore, this is
why it have many objects and prevents duplicates or data loss.

First, it queries overpass to get the IDs of the country and maritime's
boundaries, and then it downloads each of them individually.
After, it converts this data into a Postgres geometry and builds the country's
table.

Second, it takes the daily dump from the Planet and builds the base of the
note's database.
Then, based on the location of the notes, it calculates to which country each
note belong.

Third, the program downloads the recent notes from the whole world and populates
the tables with this information.
Then, it also calculates the country of these new notes.
This step is periodic, which means it should be triggered regularly, like each
15 minutes to have recent information.
The shorter the time, the more near real-time information this will provide;
however, it needs a faster server to process the information.

Once the base information is stored in the database, different services could be
provided:

* A WMS map with the location of the open and closed notes.
* A data warehouse to perform analytical queries and create user and country
profile about the status of the notes.

As part of the data warehouse, the ETL converts the note’s data into a star
schema, calculating several facts.
Then, the last part is to build a Datamart with all the necessary values for a
user or country profile, reducing the time and impact on the database while
executing.
