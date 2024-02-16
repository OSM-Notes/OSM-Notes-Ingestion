<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert notes from an API call to a CSV file.

Author: Andres Gomez (AngocA)
Version: 2023-11-13
-->
<xsl:stylesheet version="3.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*"/>
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm/note"><xsl:value-of select="id"/>,<xsl:value-of select="@lat"/>,<xsl:value-of select="@lon"/>,"<xsl:value-of select="date_created"/>",<xsl:choose><xsl:when test="date_closed != ''">"<xsl:value-of select="date_closed"/>","close"
</xsl:when><xsl:otherwise>,"open"<xsl:text>
</xsl:text></xsl:otherwise></xsl:choose>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
