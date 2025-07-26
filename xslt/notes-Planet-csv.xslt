<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert notes from a Planet dump to a CSV file.

This transformation extracts note data from OSM Planet XML files and converts
them into a CSV format suitable for database import. Planet files have a
different XML structure than API responses.

CSV Output Format:
- note_id: Unique identifier of the note
- latitude: Geographic latitude coordinate
- longitude: Geographic longitude coordinate
- created_at: Timestamp when the note was created
- status: Note status ("open" or "close")
- closed_at: Timestamp when the note was closed (empty if still open)
- country_id: Default country ID (1 for unknown)

Author: Andres Gomez (AngocA)
Version: 2025-07-26
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <!-- Dynamic timestamp parameter with fallback for missing creation dates -->
 <xsl:param name="default-timestamp" select="'2025-01-27T00:00:00Z'"/>

 <!-- Main template to process all notes from Planet dump -->
 <xsl:template match="/">
  <xsl:for-each select="osm-notes/note">
   <!-- Extract note ID - unique identifier for the note -->
   <xsl:value-of select="id"/>
   <xsl:text>,</xsl:text>
   
   <!-- Extract latitude coordinate from note attributes -->
   <xsl:value-of select="@lat"/>
   <xsl:text>,</xsl:text>
   
   <!-- Extract longitude coordinate from note attributes -->
   <xsl:value-of select="@lon"/>
   <xsl:text>,"</xsl:text>
   
   <!-- Extract creation timestamp with fallback for missing dates -->
   <xsl:choose>
    <!-- Use actual creation timestamp if available -->
    <xsl:when test="@created_at != ''">
     <xsl:value-of select="@created_at"/>
    </xsl:when>
    <!-- Use default timestamp if creation date is missing -->
    <xsl:otherwise>
     <xsl:value-of select="$default-timestamp"/>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:text>",</xsl:text>
   
   <!-- Determine note status and closed timestamp -->
   <xsl:choose>
    <!-- If note has a closed date, mark as closed and include close timestamp -->
    <xsl:when test="@closed_at != ''">
     <xsl:text>"close","</xsl:text>
     <xsl:value-of select="@closed_at"/>
     <xsl:text>",1</xsl:text>
    </xsl:when>
    <!-- If no closed date, mark as open with empty close timestamp -->
    <xsl:otherwise>
     <xsl:text>"open",,1</xsl:text>
    </xsl:otherwise>
   </xsl:choose>
   
   <!-- End of line for CSV record -->
   <xsl:text>&#10;</xsl:text>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
