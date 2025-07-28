# OSM Notes Profile - Project Rationale

## Why This Project Exists

Notes have been an internal part of OpenStreetMap since 2013. They have become more important because they are considered feedback from our users. Also, by solving notes, it expresses that the map is alive, where feedback is considered, and OSM mappers are listening to the users.

Many mappers are resolving notes, and new ones are starting to get involved in this process. For this reason, many questions are appearing, and new tools are being developed.

## The Problem with Current Note Management

### Limited Visibility and Analytics

The OpenStreetMap website does not offer a straightforward way to see notes created from a particular user (one should navigate the user and move forward through pages). This list does not provide information about where the note was created. Also, this website does not provide a list grouping notes by communities, like countries. Showing notes for a particular place helps engage mappers to close the notes in that area.

### Current Third-Party Alternatives

There are several third-party alternatives, but each has limitations:

* **ResultMaps from Pascal Neis** is a valuable tool to identify notes, open and close ones. It supplies a list of notes for a specific country, as well as some statistics per country. Finally, it has a board about the users that are opening and closing the most.

* **NotesReview** is just a viewer of 50 notes. This service is very restricted, and it does not work to help thousands of notes.

* **OSM Note Viewer** is an excellent note analyzer with many options for filtering and exporting. However, it does not provide any analytical tool to show the status of the notes per user or country.

* **Notes Map** is a good try to show a map of notes with a custom icon per type of note. The downside is that the site is only in German. There is not a legend for the icons and the project does not have an issue system.

* **Notes heatmap** is a tool to visualize the location of the notes. This helps to show areas that need a lot of work, but that is all.

## Understanding OSM Notes

### What Are Notes?

OpenStreetMap has a feature called notes (https://wiki.openstreetmap.org/wiki/Notes), which are used to report, mainly in the field, any discrepancies between what exists in reality and what is mapped. There is also documentation on how to create notes: https://learnosm.org/en/beginner/notes/.

Notes can be created anonymously or authenticated in OSM. To resolve them, mappers read them, analyze the text, and according to the note content and what is already on the map, they decide whether or not a change in the map is required.

Many notes may not require changes in the map. Other notes may have false or incomplete information. Therefore, resolving a note is a task that can be easy or complicated.

Also, there are notes that have been created from the computer, for example to report missing elements on the map, such as a river that is not mapped. This type of note can take quite a while to make the change in the map.

### Historical Context

The notes functionality was incorporated into OSM as an extension of the API v0.6 in 2013. Before that, there was a parallel project called OpenStreetBugs that offered similar functionality, but it was integrated into OSM.

### Current Challenges

The current situation is that the activity of resolving notes is not very promoted within the OSM community, and there are very old notes. For some mappers, these notes no longer offer much value and should be closed. On the other hand, some mappers consider that to resolve the notes, the data must be verified; however, this can be an impossible task since there are no alternative data available, and traveling to the location of the notes is not practical.

Due to all this, the communities of different countries and mappers have different points of view and different scopes regarding note resolution. But this work is hardly identifiable since there are few statistics.

## The Need for Better Analytics

### Current Statistics Limitations

The only place that indicates performance regarding note processing is the ResultMaps page by Pascal Neis: https://resultmaps.neis-one.org/osm-notes where you can see open notes from all countries and note performance in recent days. On each country's page, you can see the list of the latest 1000 notes, plus a link to the 10,000 open notes. Accessing this page is one of the strategies to resolve notes massively.

On the other hand, in the board section of the same website: https://osmstats.neis-one.org/?item=boards you can see the top 100 users who have opened the most notes and who have closed the most (in the Notes section).

Additionally, this website offers a contribution profile in OpenStreetMap, called How Did You Contribute - HDYC, and this profile allows obtaining detailed information about the mapper. This is a page for user AngocA: https://hdyc.neis-one.org/?AngocA

There you can identify since when the account was created, how many days they have mapped, performance by country, what types of elements they have created/modified/deleted, the tags used, among other elements. It also has a small section on how many notes they have opened and how many they have closed.

The HDYC page can be considered as the only contribution profile per user, and one of the few per country; however, the note information is very limited.

## Project Goals

This project seeks to offer a profile like HDYC, showing information about activities around notes: opening, commenting, resolution, reopening. This by country (which comes to be each of the OSM communities) and by user. Having a kind of Tiles, like the green GitHub Tiles that show their activity in the last year, important days like the one that closed the most notes, number of notes opened and closed for each year, etc. With this, the mapper can measure their work.

It should also show note performance by hashtags, indicating the date it started, how many notes have been created and closed, and other statistics. Currently, there are no tools that take advantage of note hashtags; however, they have begun to be used more and more.

Another option is to see performance by application and identify how they are being used with respect to notes.

## How This Project Works

As previously said, the purpose of this site is to supply better information about notes in near real-time.

The main challenge is to get the data, which is in separate places:

* **Country and maritime boundaries** are in OpenStreetMap, but the way to obtain them is with Overpass to retrieve all relations that have some specific tags. This involves several requests to Overpass, convert the results, to finally insert them into a Postgres database. Once we have this information in the database, we can query if a specific point (note's location) is inside a country or not.

* **Most recent note changes** can be obtained from OpenStreetMap API calls. However, this service is limited to 10,000 notes, and the current number of notes is above 4 million. Therefore, it is necessary to retrieve the whole note's history in another fashion to start working faster and not stress the API.

* **OSM provides a daily dump** from parts of the database and publishes it in the Planet website. The most well-known dataset is the map data, but for this project, it is necessary to obtain the note dump, which contains the whole history of notes since 2013, only excluding the hidden ones.

In other words, this project uses these three sources of data to keep the database almost in sync with OSM data. This is the most challenging thing about this project, and therefore, this is why it has many objects and prevents duplicates or data loss.

## Data Processing Strategy

### 1. Geographic Data Collection
First, it queries Overpass to get the IDs of the country and maritime boundaries, and then it downloads each of them individually. After, it converts this data into a Postgres geometry and builds the country's table.

### 2. Historical Data Processing
Second, it takes the daily dump from the Planet and builds the base of the note's database. Then, based on the location of the notes, it calculates to which country each note belongs.

### 3. Incremental Synchronization
Third, the program downloads the recent notes from the whole world and populates the tables with this information. Then, it also calculates the country of these new notes. This step is periodic, which means it should be triggered regularly, like every 15 minutes to have recent information. The shorter the time, the more near real-time information this will provide; however, it needs a faster server to process the information.

## Technical Implementation

### Initial Code Structure
With respect to the initial code, it has been written mainly in Bash for interactions with the OSM API to bring new notes, and through the OSM Planet to download the historical notes file.

On the other hand, Overpass has been used to download countries and other regions in the world, and with this information, we can associate a note with a territory.

It is necessary to clarify that the XML document of the Planet for notes does not have the same structure as the XML retrieved through the API. Both XML structures are in the xsd directory to validate them independently.

### Data Warehouse Design
With all this information, a data warehouse has been designed, which is composed of a set of tables in star schema, an ETL that loads the historical data into these tables, using staging tables.

Subsequently, data marts are created for users and for countries, so that the data calculations are already pre-calculated at the time of querying the profiles.

## Services Provided

Once the base information is stored in the database, different services could be provided:

* **WMS Map**: With the location of open and closed notes
* **Data Warehouse**: To perform analytical queries and create user and country profiles about the status of the notes

As part of the data warehouse, the ETL converts the note's data into a star schema, calculating several facts. Then, the last part is to build a Data Mart with all the necessary values for a user or country profile, reducing the time and impact on the database while executing.

## Related Documentation

- **System Architecture**: See [Documentation.md](./Documentation.md) for technical implementation details
- **Processing Details**: See [processAPI.md](./processAPI.md) and [processPlanet.md](./processPlanet.md) for specific implementation details

