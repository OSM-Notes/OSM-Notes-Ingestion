<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comments from an API call to a CSV file.

Author: Andres Gomez (AngocA)
Version: 2025-07-07
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <xsl:param name="quote">'</xsl:param>
 <xsl:param name="escaped-quote">''</xsl:param>

 <!-- Template to duplicate single quotes -->
 <xsl:template name="escape-quotes">
  <xsl:param name="text"/>
  <xsl:variable name="rest" select="substring-after($text, $quote)"/>

  <xsl:choose>
   <xsl:when test="contains($text, $quote)">
    <xsl:value-of select="substring-before($text, $quote)"/>
    <xsl:value-of select="$escaped-quote"/>
    <xsl:if test="string-length($rest) &gt; 0">
     <xsl:call-template name="escape-quotes">
      <xsl:with-param name="text" select="$rest"/>
     </xsl:call-template>
    </xsl:if>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$text"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <!-- Main template -->
 <xsl:template match="/">
  <xsl:for-each select="osm/note">
   <xsl:variable name="note_id">
    <xsl:value-of select="id"/>
   </xsl:variable>
   <xsl:for-each select="comments/comment">
    <xsl:choose>
     <xsl:when test="uid != ''">
      <xsl:copy-of select="$note_id" />
      <xsl:text>,'</xsl:text>
      <xsl:value-of select="action" />
      <xsl:text>','</xsl:text>
      <xsl:value-of select="date"/>
      <xsl:text>',</xsl:text>
      <xsl:value-of select="uid"/>
      <xsl:text>,'</xsl:text>
      <xsl:call-template name='escape-quotes'>
       <xsl:with-param name='text' select='user'/>
      </xsl:call-template>
      <xsl:text>'</xsl:text>
     </xsl:when>
     <xsl:otherwise>
      <xsl:copy-of select="$note_id" />
      <xsl:text>,'</xsl:text>
      <xsl:value-of select="action" />
      <xsl:text>','</xsl:text>
      <xsl:value-of select="date"/>
      <xsl:text>',,</xsl:text>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:text>&#10;</xsl:text>
   </xsl:for-each>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
