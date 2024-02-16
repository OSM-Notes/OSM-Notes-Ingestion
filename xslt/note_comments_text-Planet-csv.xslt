<?xml version="1.0" encoding="UTF-8"?>
<!--
XML transformation to convert note comment's text from a Planet dump to a CSV file.

Author: Andres Gomez (AngocA)
Version: 2023-12-04
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
 <xsl:copy-of select="$note_id" />,"<xsl:value-of select="replace(., $pPat, $pRep)"/>"<xsl:text>
</xsl:text>
  </xsl:for-each>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
