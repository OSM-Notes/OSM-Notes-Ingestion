<?xml version="1.0" encoding="UTF-8"?>
<!--
SLD file to style disputed and unclaimed areas for WMS layer.
Red color for disputed areas (overlapping countries).
Yellow color for unclaimed areas (gaps between countries).

Author: Andres Gomez (AngocA)
Version: 2025-11-30
-->
<StyledLayerDescriptor xmlns="http://www.opengis.net/sld" version="1.1.0" xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.1.0/StyledLayerDescriptor.xsd" xmlns:ogc="http://www.opengis.net/ogc" xmlns:se="http://www.opengis.net/se" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xlink="http://www.w3.org/1999/xlink">
  <NamedLayer>
    <se:Name>disputed_and_unclaimed_areas</se:Name>
    <UserStyle>
      <se:Name>disputed_and_unclaimed_areas</se:Name>
      <se:FeatureTypeStyle>
        <!-- Disputed Areas: Red with 50% opacity -->
        <se:Rule>
          <se:Name>Disputed Areas</se:Name>
          <se:Description>
            <se:Title>Disputed Areas</se:Title>
            <se:Abstract>Areas where 2 or more countries overlap (territorial disputes)</se:Abstract>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>zone_type</ogc:PropertyName>
              <ogc:Literal>disputed</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <se:PolygonSymbolizer>
            <se:Fill>
              <se:SvgParameter name="fill">#ff0000</se:SvgParameter>
              <se:SvgParameter name="fill-opacity">0.5</se:SvgParameter>
            </se:Fill>
            <se:Stroke>
              <se:SvgParameter name="stroke">#cc0000</se:SvgParameter>
              <se:SvgParameter name="stroke-width">2</se:SvgParameter>
              <se:SvgParameter name="stroke-linejoin">bevel</se:SvgParameter>
              <se:SvgParameter name="stroke-opacity">0.8</se:SvgParameter>
            </se:Stroke>
          </se:PolygonSymbolizer>
        </se:Rule>
        <!-- Unclaimed Areas: Yellow with 30% opacity -->
        <se:Rule>
          <se:Name>Unclaimed Areas</se:Name>
          <se:Description>
            <se:Title>Unclaimed Areas</se:Title>
            <se:Abstract>Areas not covered by any country (gaps between countries)</se:Abstract>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:PropertyIsEqualTo>
              <ogc:PropertyName>zone_type</ogc:PropertyName>
              <ogc:Literal>unclaimed</ogc:Literal>
            </ogc:PropertyIsEqualTo>
          </ogc:Filter>
          <se:PolygonSymbolizer>
            <se:Fill>
              <se:SvgParameter name="fill">#ffff00</se:SvgParameter>
              <se:SvgParameter name="fill-opacity">0.3</se:SvgParameter>
            </se:Fill>
            <se:Stroke>
              <se:SvgParameter name="stroke">#cccc00</se:SvgParameter>
              <se:SvgParameter name="stroke-width">1</se:SvgParameter>
              <se:SvgParameter name="stroke-linejoin">bevel</se:SvgParameter>
              <se:SvgParameter name="stroke-opacity">0.6</se:SvgParameter>
            </se:Stroke>
          </se:PolygonSymbolizer>
        </se:Rule>
      </se:FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>

