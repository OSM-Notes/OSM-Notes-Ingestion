<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert notes from a Planet dump to a CSV file.

Author: Andres Gomez (AngocA)
Version: 2025-07-26
-->
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:strip-space elements="*"/>
 <xsl:output method="text" />

 <!-- Dynamic timestamp parameter with fallback -->
 <xsl:param name="default-timestamp" select="'2025-01-27T00:00:00Z'"/>

 <xsl:template match="/">
  <xsl:for-each select="osm-notes/note">
   <xsl:value-of select="id"/>
   <xsl:text>,</xsl:text>
   <xsl:value-of select="@lat"/>
   <xsl:text>,</xsl:text>
   <xsl:value-of select="@lon"/>
   <xsl:text>,"</xsl:text>
   <xsl:choose>
    <xsl:when test="@created_at != ''">
     <xsl:value-of select="@created_at"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$default-timestamp"/>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:text>",</xsl:text>
   <xsl:choose>
    <xsl:when test="@closed_at != ''">
     <xsl:text>"close","</xsl:text>
     <xsl:value-of select="@closed_at"/>
     <xsl:text>",1</xsl:text>
    </xsl:when>
    <xsl:otherwise>
     <xsl:text>"open",,1</xsl:text>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:text>&#10;</xsl:text>
  </xsl:for-each>
 </xsl:template>
</xsl:stylesheet>
