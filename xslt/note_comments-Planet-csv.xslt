<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comments from a Planet dump to a CSV file.

This transformation extracts comment data from OSM Planet XML files and converts
them into a CSV format suitable for database import. Planet files have a
different XML structure than API responses, with comment data as attributes.

CSV Output Format:
- note_id: ID of the note this comment belongs to
- sequence_action: Sequential number of the comment (1, 2, 3...)
- event: Type of action (opened, commented, closed, reopened)
- created_at: When the comment/action occurred
- id_user: ID of the user who made the comment (empty if anonymous)
- username: Name of the user who made the comment (escaped for CSV)

Author: Andres Gomez (AngocA)
Version: 2025-07-26
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <!-- Dynamic timestamp parameter with fallback for missing timestamps -->
 <xsl:param name="default-timestamp" select="'2025-01-27T00:00:00Z'"/>

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

 <!-- Main template to process all notes and their comments from Planet dump -->
 <xsl:template match="/">
  <xsl:for-each select="osm-notes/note">
   <!-- Store note ID for use in all comments of this note -->
   <xsl:variable name="note_id">
    <xsl:value-of select="@id"/>
   </xsl:variable>
   
   <!-- Process each comment for the current note -->
   <xsl:for-each select="comment">
    <xsl:variable name="sequence_number" select="position()"/>
    <xsl:choose>
     <!-- Handle comments with user information -->
     <xsl:when test="@uid != ''">
      <!-- Extract note ID - links comment to the parent note -->
      <xsl:copy-of select="$note_id" />
      <xsl:text>,</xsl:text>
      
      <!-- Extract sequence number - sequential order of the comment -->
      <xsl:value-of select="$sequence_number"/>
      <xsl:text>,"</xsl:text>
      
      <!-- Extract action type - what the user did (opened, commented, closed, reopened) -->
      <xsl:value-of select="@action" />
      <xsl:text>","</xsl:text>
      
      <!-- Extract timestamp with fallback for missing timestamps -->
      <xsl:choose>
       <!-- Use actual timestamp if available -->
       <xsl:when test="@timestamp != ''">
        <xsl:value-of select="@timestamp"/>
       </xsl:when>
       <!-- Use default timestamp if timestamp is missing -->
       <xsl:otherwise>
        <xsl:value-of select="$default-timestamp"/>
       </xsl:otherwise>
      </xsl:choose>
      <xsl:text>",</xsl:text>
      
      <!-- Extract user ID - unique identifier of the user -->
      <xsl:value-of select="@uid"/>
      <xsl:text>,"</xsl:text>
      
      <!-- Extract username with quote escaping for CSV compatibility -->
      <xsl:call-template name='escape-quotes'>
       <xsl:with-param name='text' select='@user'/>
      </xsl:call-template>
      <xsl:text>"</xsl:text>
     </xsl:when>
     
     <!-- Handle anonymous comments (no user information) -->
     <xsl:otherwise>
      <!-- Extract note ID - links comment to the parent note -->
      <xsl:copy-of select="$note_id" />
      <xsl:text>,</xsl:text>
      
      <!-- Extract sequence number - sequential order of the comment -->
      <xsl:value-of select="$sequence_number"/>
      <xsl:text>,"</xsl:text>
      
      <!-- Extract action type - what was done (opened, commented, closed, reopened) -->
      <xsl:value-of select="@action" />
      <xsl:text>","</xsl:text>
      
      <!-- Extract timestamp with fallback for missing timestamps -->
      <xsl:choose>
       <!-- Use actual timestamp if available -->
       <xsl:when test="@timestamp != ''">
        <xsl:value-of select="@timestamp"/>
       </xsl:when>
       <!-- Use default timestamp if timestamp is missing -->
       <xsl:otherwise>
        <xsl:value-of select="$default-timestamp"/>
       </xsl:otherwise>
      </xsl:choose>
      <xsl:text>",,</xsl:text>
     </xsl:otherwise>
    </xsl:choose>
    
    <!-- End of line for CSV record -->
    <xsl:text>&#10;</xsl:text>
   </xsl:for-each>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
