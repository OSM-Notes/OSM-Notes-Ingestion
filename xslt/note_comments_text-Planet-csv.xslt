<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comment's text from a Planet dump to a CSV file.

This transformation extracts the actual text content of comments from OSM Planet XML
files and converts them into a CSV format suitable for database import. Planet
files have a different XML structure than API responses, with comment text as
element content rather than attributes.

CSV Output Format:
- note_id: ID of the note this comment text belongs to
- comment_sequence: Sequential number of the comment (position in comment list)
- comment_text: The actual text content of the comment (escaped for CSV)

Author: Andres Gomez (AngocA)
Version: 2025-07-25
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <!-- Dynamic timestamp parameter with fallback for missing creation dates -->
 <!-- Using 2013-01-01 as OSM Notes started in 2013 (see README: "since 2013") -->
 <xsl:param name="default-timestamp" select="'2013-01-01T00:00:00Z'"/>

 <!-- Parameters for CSV quote escaping -->
 <xsl:param name="quote">"</xsl:param>
 <xsl:param name="escaped-quote">""</xsl:param>

 <!-- Template to escape double quotes in text fields for CSV compatibility -->
 <xsl:template name="escape-quotes">
  <xsl:param name="text"/>
  <xsl:variable name="rest" select="substring-after($text, $quote)"/>

  <xsl:choose>
   <!-- If text contains quotes, escape them by doubling -->
   <xsl:when test="contains($text, $quote)">
    <xsl:value-of select="substring-before($text, $quote)"/>
    <xsl:value-of select="$escaped-quote"/>
    <xsl:if test="string-length($rest) &gt; 0">
     <xsl:call-template name="escape-quotes">
      <xsl:with-param name="text" select="$rest"/>
      </xsl:call-template>
    </xsl:if>
   </xsl:when>
   <!-- If no quotes, output text as-is -->
   <xsl:otherwise>
    <xsl:value-of select="$text"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <!-- Main template to process all notes and their comment text from Planet dump -->
 <xsl:template match="/">
  <xsl:for-each select="osm-notes/note">
   <!-- Store note ID for use in all comments of this note -->
   <xsl:variable name="note_id">
    <xsl:value-of select="@id"/>
   </xsl:variable>
   
   <!-- Process each comment for the current note -->
   <xsl:for-each select="comment">
    <!-- Extract note ID - links comment text to the parent note -->
    <xsl:copy-of select="$note_id"/>
    <xsl:text>,</xsl:text>
    
    <!-- Extract comment sequence - position of this comment in the note's comment list -->
    <xsl:value-of select="position()"/>
    <xsl:text>,"</xsl:text>
    
    <!-- Extract comment text with quote escaping for CSV compatibility -->
    <!-- In Planet format, comment text is the element content (.) -->
    <xsl:call-template name='escape-quotes'>
     <xsl:with-param name='text' select='.'/>
    </xsl:call-template>
    <xsl:text>"</xsl:text>
    
    <!-- End of line for CSV record -->
    <xsl:text>&#10;</xsl:text>
   </xsl:for-each>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
