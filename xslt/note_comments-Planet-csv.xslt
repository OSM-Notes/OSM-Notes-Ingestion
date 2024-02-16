<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comment
s from a Planet dump to a CSV file.

Author: Andres Gomez (AngocA)
Version: 2023-11-13
-->
<xsl:stylesheet version="3.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*"/>
<xsl:output method="text" />
<xsl:param name="pPat">"</xsl:param>
<xsl:param name="pRep">""</xsl:param>
<xsl:template match="/">
 <xsl:for-each select="osm-notes/note">
 <xsl:variable name="note_id"><xsl:value-of select="@id"/></xsl:variable>
  <xsl:for-each select="comment">
<xsl:choose> <xsl:when test="@uid != ''"> <xsl:copy-of select="$note_id" />,"<xsl:value-of select="@action" />","<xsl:value-of select="@timestamp"/>",<xsl:value-of select="@uid"/>,"<xsl:value-of select="replace(@user, $pPat, $pRep)"/>"<xsl:text>
</xsl:text></xsl:when><xsl:otherwise>
<xsl:copy-of select="$note_id" />,"<xsl:value-of select="@action" />","<xsl:value-of select="@timestamp"/>",,<xsl:text>
</xsl:text></xsl:otherwise> </xsl:choose>
  </xsl:for-each>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
