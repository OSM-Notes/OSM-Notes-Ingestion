<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comments from an API call to a CSV file.

Author: Andres Gomez (AngocA)
Version: 2023-11-13
-->
<xsl:stylesheet version="3.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*"/>
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm/note">
 <xsl:variable name="note_id"><xsl:value-of select="id"/></xsl:variable>
  <xsl:for-each select="comments/comment">
<xsl:choose> <xsl:when test="uid != ''"> <xsl:copy-of select="$note_id" />,'<xsl:value-of select="action" />','<xsl:value-of select="date"/>',<xsl:value-of select="uid"/>,'<xsl:value-of select="replace(user,'''','''''')"/>'<xsl:text>
</xsl:text></xsl:when><xsl:otherwise>
<xsl:copy-of select="$note_id" />,'<xsl:value-of select="action" />','<xsl:value-of select="date"/>',,<xsl:text>
</xsl:text></xsl:otherwise> </xsl:choose>
  </xsl:for-each>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
