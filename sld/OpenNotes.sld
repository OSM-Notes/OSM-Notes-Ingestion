<!--
SLD file to give colors to the notes. The lighter the note was recently opened.
The darker the note was opened several years ago. It is used in GeoServer.

Author: Andres Gomez (AngocA)
Version: 2023-11-13
-->
<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor xmlns="http://www.opengis.net/sld" xmlns:se="http://www.opengis.net/se" xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.1.0/StyledLayerDescriptor.xsd" version="1.1.0" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:ogc="http://www.opengis.net/ogc" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <NamedLayer>
    <se:Name>notes open</se:Name>
    <UserStyle>
      <se:Name>notes open</se:Name>
      <se:FeatureTypeStyle>
        <se:Rule>
          <se:Name>open</se:Name>
          <se:Description>
            <se:Title>open</se:Title>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:PropertyIsNull>
              <ogc:PropertyName>year_closed_at</ogc:PropertyName>
            </ogc:PropertyIsNull>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#ff0000</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#232323</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>1</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>0 - 1</se:Name>
          <se:Description>
            <se:Title>0 - 1</se:Title>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:Sub>
                  <ogc:Literal>2022</ogc:Literal>
                  <ogc:PropertyName>year_created_at</ogc:PropertyName>
                </ogc:Sub>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#e31a1c</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#e31a1c</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
              <se:Rotation>
                <ogc:Literal>180</ogc:Literal>
              </se:Rotation>
              <se:Displacement>
                <se:DisplacementX>0</se:DisplacementX>
                <se:DisplacementY>7</se:DisplacementY>
              </se:Displacement>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>1 - 2</se:Name>
          <se:Description>
            <se:Title>1 - 2</se:Title>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:Sub>
                  <ogc:Literal>2022</ogc:Literal>
                  <ogc:PropertyName>year_created_at</ogc:PropertyName>
                </ogc:Sub>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#aa1415</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#aa1415</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
              <se:Rotation>
                <ogc:Literal>180</ogc:Literal>
              </se:Rotation>
              <se:Displacement>
                <se:DisplacementX>0</se:DisplacementX>
                <se:DisplacementY>7</se:DisplacementY>
              </se:Displacement>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>2 - 4</se:Name>
          <se:Description>
            <se:Title>2 - 4</se:Title>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:And>
              <ogc:And>
                <ogc:PropertyIsNull>
                  <ogc:PropertyName>year_closed_at</ogc:PropertyName>
                </ogc:PropertyIsNull>
                <ogc:PropertyIsLessThanOrEqualTo>
                  <ogc:Literal>3</ogc:Literal>
                  <ogc:Sub>
                    <ogc:Literal>2022</ogc:Literal>
                    <ogc:PropertyName>year_created_at</ogc:PropertyName>
                  </ogc:Sub>
                </ogc:PropertyIsLessThanOrEqualTo>
              </ogc:And>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:Sub>
                  <ogc:Literal>2022</ogc:Literal>
                  <ogc:PropertyName>year_created_at</ogc:PropertyName>
                </ogc:Sub>
                <ogc:Literal>4</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#720d0e</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#720d0e</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
              <se:Rotation>
                <ogc:Literal>180</ogc:Literal>
              </se:Rotation>
              <se:Displacement>
                <se:DisplacementX>0</se:DisplacementX>
                <se:DisplacementY>7</se:DisplacementY>
              </se:Displacement>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>4 - 7</se:Name>
          <se:Description>
            <se:Title>4 - 7</se:Title>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:And>
              <ogc:And>
                <ogc:PropertyIsNull>
                  <ogc:PropertyName>year_closed_at</ogc:PropertyName>
                </ogc:PropertyIsNull>
                <ogc:PropertyIsLessThanOrEqualTo>
                  <ogc:Literal>5</ogc:Literal>
                  <ogc:Sub>
                    <ogc:Literal>2022</ogc:Literal>
                    <ogc:PropertyName>year_created_at</ogc:PropertyName>
                  </ogc:Sub>
                </ogc:PropertyIsLessThanOrEqualTo>
              </ogc:And>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:Sub>
                  <ogc:Literal>2022</ogc:Literal>
                  <ogc:PropertyName>year_created_at</ogc:PropertyName>
                </ogc:Sub>
                <ogc:Literal>7</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#390607</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#390607</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
              <se:Rotation>
                <ogc:Literal>180</ogc:Literal>
              </se:Rotation>
              <se:Displacement>
                <se:DisplacementX>0</se:DisplacementX>
                <se:DisplacementY>7</se:DisplacementY>
              </se:Displacement>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>7 -</se:Name>
          <se:Description>
            <se:Title>7 -</se:Title>
          </se:Description>
          <ogc:Filter xmlns:ogc="http://www.opengis.net/ogc">
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:Literal>8</ogc:Literal>
                <ogc:Sub>
                  <ogc:Literal>2022</ogc:Literal>
                  <ogc:PropertyName>year_created_at</ogc:PropertyName>
                </ogc:Sub>
              </ogc:PropertyIsLessThanOrEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#000000</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#000000</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
              <se:Rotation>
                <ogc:Literal>180</ogc:Literal>
              </se:Rotation>
              <se:Displacement>
                <se:DisplacementX>0</se:DisplacementX>
                <se:DisplacementY>7</se:DisplacementY>
              </se:Displacement>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
      </se:FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
