<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comments from an API call to a CSV file.

This transformation extracts comment data from OSM API XML responses and converts
them into a CSV format suitable for database import. Each comment represents
an action (opened, commented, closed, reopened) on a note.

CSV Output Format:
- note_id: ID of the note this comment belongs to
- comment_sequence: Sequential number of the comment (1 for first comment)
- action: Type of action (opened, commented, closed, reopened)
- timestamp: When the comment/action occurred
- user_id: ID of the user who made the comment (empty if anonymous)
- username: Name of the user who made the comment (escaped for CSV)

Author: Andres Gomez (AngocA)
Version: 2025-08-07
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

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

 <!-- Main template to process all notes and their comments -->
 <xsl:template match="/">
  <xsl:for-each select="osm/note">
   <!-- Store note ID for use in all comments of this note -->
   <xsl:variable name="note_id">
    <xsl:value-of select="id"/>
   </xsl:variable>
   
   <!-- Process each comment for the current note -->
   <xsl:for-each select="comments/comment">
    <xsl:choose>
     <!-- Handle comments with user information -->
     <xsl:when test="uid != ''">
      <!-- Extract note ID - links comment to the parent note -->
      <xsl:copy-of select="$note_id" />
      <xsl:text>,1,</xsl:text>
      
      <!-- Extract action type - what the user did (opened, commented, closed, reopened) -->
      <!-- Note: No quotes around enum values for PostgreSQL enum types -->
      <xsl:choose>
       <xsl:when test="action != ''">
        <xsl:value-of select="action" />
       </xsl:when>
       <xsl:otherwise>
        <xsl:text>opened</xsl:text>
       </xsl:otherwise>
      </xsl:choose>
      <xsl:text>,"</xsl:text>
      
      <!-- Extract timestamp - when the action occurred -->
      <xsl:value-of select="date"/>
      <xsl:text>",</xsl:text>
      
      <!-- Extract user ID - unique identifier of the user -->
      <xsl:value-of select="uid"/>
      <xsl:text>,"</xsl:text>
      
      <!-- Extract username with quote escaping for CSV compatibility -->
      <xsl:call-template name='escape-quotes'>
       <xsl:with-param name='text' select='user'/>
      </xsl:call-template>
      <xsl:text>"</xsl:text>
     </xsl:when>
     
     <!-- Handle anonymous comments (no user information) -->
     <xsl:otherwise>
      <!-- Extract note ID - links comment to the parent note -->
      <xsl:copy-of select="$note_id" />
      <xsl:text>,1,</xsl:text>
      
      <!-- Extract action type - what was done (opened, commented, closed, reopened) -->
      <!-- Note: No quotes around enum values for PostgreSQL enum types -->
      <xsl:choose>
       <xsl:when test="action != ''">
        <xsl:value-of select="action" />
       </xsl:when>
       <xsl:otherwise>
        <xsl:text>opened</xsl:text>
       </xsl:otherwise>
      </xsl:choose>
      <xsl:text>,"</xsl:text>
      
      <!-- Extract timestamp - when the action occurred -->
      <xsl:value-of select="date"/>
      <xsl:text>",</xsl:text>
     </xsl:otherwise>
    </xsl:choose>
    
    <!-- End of line for CSV record -->
    <xsl:text>&#10;</xsl:text>
   </xsl:for-each>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
