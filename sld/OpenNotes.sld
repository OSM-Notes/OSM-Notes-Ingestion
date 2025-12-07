<!--
SLD file to give colors and shapes to open OSM notes. Uses dynamically calculated age_years column.
The age is calculated automatically in the database view, so no hardcoded year is needed.

Enhanced styling with country identification and variable opacity:
- Each country gets a distinct base color and shape for easy identification
- Color intensity varies by note age (darker = older)
- Different shapes per country (triangle, circle, square, star, cross, arrow)
- Shape is determined by country_shape_mod column (id_country % 6)
- Notes without country (NULL) are shown in gray
- Variable opacity: older notes are more transparent to reduce visual noise

Author: Andres Gomez (AngocA)
Version: 2025-12-07
-->
<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor xmlns="http://www.opengis.net/sld" 
  xmlns:se="http://www.opengis.net/se" 
  xmlns:ogc="http://www.opengis.net/ogc" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.1.0/StyledLayerDescriptor.xsd" 
  version="1.1.0" 
  xmlns:xlink="http://www.w3.org/1999/xlink">
  <NamedLayer>
    <se:Name>notes open</se:Name>
    <UserStyle>
      <se:Name>notes open</se:Name>
      <se:FeatureTypeStyle>
        <!-- Notes without country (unclaimed/disputed areas) - Gray -->
        <se:Rule>
          <se:Name>No country - 0-1 years</se:Name>
          <se:Description>
            <se:Title>No country - 0-1 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#888888</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#555555</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>12</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>No country - 1-2 years</se:Name>
          <se:Description>
            <se:Title>No country - 1-2 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#666666</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#333333</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>12</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>No country - 2+ years</se:Name>
          <se:Description>
            <se:Title>No country - 2+ years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#444444</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#222222</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>12</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Country-based rules: Shape 0 (Triangle) - Red/Purple tones -->
        <se:Rule>
          <se:Name>Country - Triangle - 0-1 years</se:Name>
          <se:Description>
            <se:Title>Country - Triangle - 0-1 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#ff6b6b</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#c92a2a</se:SvgParameter>
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
          <se:Name>Country - Triangle - 1-2 years</se:Name>
          <se:Description>
            <se:Title>Country - Triangle - 1-2 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#c92a2a</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#862e2e</se:SvgParameter>
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
          <se:Name>Country - Triangle - 2+ years</se:Name>
          <se:Description>
            <se:Title>Country - Triangle - 2+ years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>0</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>triangle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#862e2e</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#5c1f1f</se:SvgParameter>
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
        
        <!-- Shape 1 (Circle) - Orange tones -->
        <se:Rule>
          <se:Name>Country - Circle - 0-1 years</se:Name>
          <se:Description>
            <se:Title>Country - Circle - 0-1 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#ff8c42</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#d63031</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Circle - 1-2 years</se:Name>
          <se:Description>
            <se:Title>Country - Circle - 1-2 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#d63031</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#a02626</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Circle - 2+ years</se:Name>
          <se:Description>
            <se:Title>Country - Circle - 2+ years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#a02626</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#6b1a1a</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 2 (Square) - Purple tones -->
        <se:Rule>
          <se:Name>Country - Square - 0-1 years</se:Name>
          <se:Description>
            <se:Title>Country - Square - 0-1 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>square</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#a29bfe</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#6c5ce7</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Square - 1-2 years</se:Name>
          <se:Description>
            <se:Title>Country - Square - 1-2 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>square</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#6c5ce7</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#4834d4</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Square - 2+ years</se:Name>
          <se:Description>
            <se:Title>Country - Square - 2+ years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>square</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#4834d4</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#2f1b69</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 3 (Star) - Blue tones -->
        <se:Rule>
          <se:Name>Country - Star - 0-1 years</se:Name>
          <se:Description>
            <se:Title>Country - Star - 0-1 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>3</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>star</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#74b9ff</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#0984e3</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Star - 1-2 years</se:Name>
          <se:Description>
            <se:Title>Country - Star - 1-2 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>3</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>star</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#0984e3</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#0652dd</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Star - 2+ years</se:Name>
          <se:Description>
            <se:Title>Country - Star - 2+ years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>3</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>star</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#0652dd</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#03396c</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 4 (Cross) - Yellow/Green tones -->
        <se:Rule>
          <se:Name>Country - Cross - 0-1 years</se:Name>
          <se:Description>
            <se:Title>Country - Cross - 0-1 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>4</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>cross</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#fdcb6e</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#e17055</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Cross - 1-2 years</se:Name>
          <se:Description>
            <se:Title>Country - Cross - 1-2 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>4</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>cross</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#e17055</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#b84a2f</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Cross - 2+ years</se:Name>
          <se:Description>
            <se:Title>Country - Cross - 2+ years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>4</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>cross</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#b84a2f</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#8b3a24</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 5 (Arrow) - Pink/Magenta tones -->
        <se:Rule>
          <se:Name>Country - Arrow - 0-1 years</se:Name>
          <se:Description>
            <se:Title>Country - Arrow - 0-1 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsLessThanOrEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>5</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>arrow</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#fd79a8</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#e84393</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Arrow - 1-2 years</se:Name>
          <se:Description>
            <se:Title>Country - Arrow - 1-2 years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsEqualTo>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>5</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>arrow</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#e84393</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#d63384</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Arrow - 2+ years</se:Name>
          <se:Description>
            <se:Title>Country - Arrow - 2+ years</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>age_years</ogc:PropertyName>
                <ogc:Literal>2</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
              <ogc:PropertyIsEqualTo>
                <ogc:PropertyName>country_shape_mod</ogc:PropertyName>
                <ogc:Literal>5</ogc:Literal>
              </ogc:PropertyIsEqualTo>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>arrow</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#d63384</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#a0265c</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">1</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>14</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
      </se:FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>

