<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert notes from an API call to a CSV file.

This transformation extracts note data from OSM API XML responses and converts
them into a CSV format suitable for database import.

CSV Output Format:
- note_id: Unique identifier of the note
- latitude: Geographic latitude coordinate
- longitude: Geographic longitude coordinate  
- created_at: Timestamp when the note was created
- closed_at: Timestamp when the note was closed (empty if still open)
- status: Note status ("open" or "close")
- country_id: Default country ID (1 for unknown)
- user_id: Default user ID (1 for unknown)

Author: Andres Gomez (AngocA)
Version: 2025-07-25
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <!-- Main template to process all notes -->
 <xsl:template match="/">
  <xsl:for-each select="osm/note">
   <!-- Extract note ID - unique identifier for the note -->
   <xsl:value-of select="id"/>
   <xsl:text>,</xsl:text>
   
   <!-- Extract latitude coordinate from note attributes -->
   <xsl:value-of select="@lat"/>
   <xsl:text>,</xsl:text>
   
   <!-- Extract longitude coordinate from note attributes -->
   <xsl:value-of select="@lon"/>
   <xsl:text>,"</xsl:text>
   
   <!-- Extract creation timestamp - when the note was first created -->
   <xsl:value-of select="date_created"/>
   <xsl:text>",</xsl:text>
   
   <!-- Determine note status and closed timestamp -->
   <xsl:choose>
    <!-- If note has a closed date, mark as closed and include close timestamp -->
    <xsl:when test="date_closed != ''">
     <xsl:text>"</xsl:text>
     <xsl:value-of select="date_closed"/>
     <xsl:text>","close"</xsl:text>
    </xsl:when>
    <!-- If no closed date, mark as open with empty close timestamp -->
    <xsl:otherwise>
     <xsl:text>,"open"</xsl:text>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:text>,</xsl:text>
   
   <!-- Default country ID (1) - will be updated by spatial processing -->
   <xsl:text>1</xsl:text>
   
   <!-- End of line for CSV record -->
   <xsl:text>&#10;</xsl:text>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
