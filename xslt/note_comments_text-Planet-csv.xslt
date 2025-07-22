<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comment's text from a Planet dump to a CSV
file.

Author: Andres Gomez (AngocA)
Version: 2025-07-07
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <xsl:param name="quote">"</xsl:param>
 <xsl:param name="escaped-quote">""</xsl:param>

 <!-- Template to duplicate double quotes -->
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
  <xsl:for-each select="osm-notes/note">
   <xsl:variable name="note_id">
    <xsl:value-of select="@id"/>
   </xsl:variable>
   <xsl:for-each select="comment">
    <xsl:copy-of select="$note_id"/>
    <xsl:text>,</xsl:text>
    <xsl:value-of select="position()"/>
    <xsl:text>,"</xsl:text>
    <xsl:call-template name='escape-quotes'>
     <xsl:with-param name='text' select='.'/>
    </xsl:call-template>
    <xsl:text>"&#10;</xsl:text>
   </xsl:for-each>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
