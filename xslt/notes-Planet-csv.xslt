<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert notes from a Planet dump to a CSV file.

Author: Andres Gomez (AngocA)
Version: 2025-07-07
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <xsl:template match="/">
  <xsl:for-each select="osm-notes/note">
   <xsl:value-of select="@id"/>
   <xsl:text>,</xsl:text>
   <xsl:value-of select="@lat"/>
   <xsl:text>,</xsl:text>
   <xsl:value-of select="@lon"/>
   <xsl:text>,"</xsl:text>
   <xsl:value-of select="@created_at"/>
   <xsl:text>",</xsl:text>
   <xsl:choose>
    <xsl:when test="@closed_at != ''">
     <xsl:text>"</xsl:text>
     <xsl:value-of select="@closed_at"/>
     <xsl:text>","close"</xsl:text>
    </xsl:when>
    <xsl:otherwise>
     <xsl:text>,"open"</xsl:text>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:text>&#10;</xsl:text>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
