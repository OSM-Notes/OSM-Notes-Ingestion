<!--
SLD file to give colors and shapes to closed OSM notes. Uses dynamically calculated years_since_closed column.
The age is calculated automatically in the database view, so no hardcoded year is needed.

Enhanced styling with country identification and variable opacity:
- Each country gets a distinct base color and shape for easy identification
- Color intensity varies by closure age (lighter = older)
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
    <se:Name>notes closed</se:Name>
    <UserStyle>
      <se:Name>notes closed</se:Name>
      <se:FeatureTypeStyle>
        <!-- Notes without country (unclaimed/disputed areas) - Gray -->
        <se:Rule>
          <se:Name>No country - recently closed</se:Name>
          <se:Description>
            <se:Title>No country - recently closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
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
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>No country - old closed</se:Name>
          <se:Description>
            <se:Title>No country - old closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
              </ogc:PropertyIsGreaterThan>
            </ogc:And>
          </ogc:Filter>
          <se:PointSymbolizer>
            <se:Graphic>
              <se:Mark>
                <se:WellKnownName>circle</se:WellKnownName>
                <se:Fill>
                  <se:SvgParameter name="fill">#cccccc</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#999999</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Country-based rules: Shape 0 (Triangle) - Blue tones (closed) -->
        <se:Rule>
          <se:Name>Country - Triangle - recently closed</se:Name>
          <se:Description>
            <se:Title>Country - Triangle - recently closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
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
                  <se:SvgParameter name="fill">#2d3436</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#636e72</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Triangle - old closed</se:Name>
          <se:Description>
            <se:Title>Country - Triangle - old closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
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
                  <se:SvgParameter name="fill">#b2bec3</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#dfe6e9</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 1 (Circle) - Cyan tones (closed) -->
        <se:Rule>
          <se:Name>Country - Circle - recently closed</se:Name>
          <se:Description>
            <se:Title>Country - Circle - recently closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
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
                  <se:SvgParameter name="fill">#00b894</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#00cec9</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Circle - old closed</se:Name>
          <se:Description>
            <se:Title>Country - Circle - old closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
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
                  <se:SvgParameter name="fill">#81ecec</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#dfe6e9</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 2 (Square) - Teal tones (closed) -->
        <se:Rule>
          <se:Name>Country - Square - recently closed</se:Name>
          <se:Description>
            <se:Title>Country - Square - recently closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
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
                  <se:SvgParameter name="fill">#00b894</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#55efc4</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Square - old closed</se:Name>
          <se:Description>
            <se:Title>Country - Square - old closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
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
                  <se:SvgParameter name="fill">#a8e6cf</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#dfe6e9</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 3 (Star) - Green tones (closed) -->
        <se:Rule>
          <se:Name>Country - Star - recently closed</se:Name>
          <se:Description>
            <se:Title>Country - Star - recently closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
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
                  <se:SvgParameter name="fill">#00b894</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#55efc4</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Star - old closed</se:Name>
          <se:Description>
            <se:Title>Country - Star - old closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
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
                  <se:SvgParameter name="fill">#a8e6cf</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#dfe6e9</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 4 (Cross) - Yellow tones (closed) -->
        <se:Rule>
          <se:Name>Country - Cross - recently closed</se:Name>
          <se:Description>
            <se:Title>Country - Cross - recently closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
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
                  <se:SvgParameter name="stroke">#ffeaa7</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Cross - old closed</se:Name>
          <se:Description>
            <se:Title>Country - Cross - old closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
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
                  <se:SvgParameter name="fill">#ffeaa7</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#ffffff</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        
        <!-- Shape 5 (Arrow) - Light blue tones (closed) -->
        <se:Rule>
          <se:Name>Country - Arrow - recently closed</se:Name>
          <se:Description>
            <se:Title>Country - Arrow - recently closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsLessThanOrEqualTo>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
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
                  <se:SvgParameter name="fill">#74b9ff</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#a29bfe</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
        <se:Rule>
          <se:Name>Country - Arrow - old closed</se:Name>
          <se:Description>
            <se:Title>Country - Arrow - old closed</se:Title>
          </se:Description>
          <ogc:Filter>
            <ogc:And>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>id_country</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsNotNull>
                <ogc:PropertyName>year_closed_at</ogc:PropertyName>
              </ogc:PropertyIsNotNull>
              <ogc:PropertyIsGreaterThan>
                <ogc:PropertyName>years_since_closed</ogc:PropertyName>
                <ogc:Literal>1</ogc:Literal>
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
                  <se:SvgParameter name="fill">#dfe6e9</se:SvgParameter>
                </se:Fill>
                <se:Stroke>
                  <se:SvgParameter name="stroke">#ffffff</se:SvgParameter>
                  <se:SvgParameter name="stroke-width">0.5</se:SvgParameter>
                </se:Stroke>
              </se:Mark>
              <se:Size>9</se:Size>
            </se:Graphic>
          </se:PointSymbolizer>
        </se:Rule>
      </se:FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>

