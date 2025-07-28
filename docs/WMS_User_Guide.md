# WMS User Guide

## What is WMS?

WMS (Web Map Service) is a way to view OSM notes on a map. Think of it as a special layer that shows you where people have left notes about mapping issues, just like you might leave a sticky note on a map.

### Why Use WMS?

- **See the Big Picture**: View all notes in an area at once
- **Identify Patterns**: Notice where many notes are clustered
- **Prioritize Work**: Focus on areas that need attention
- **Track Progress**: See which areas have been recently worked on

### What You'll See

The WMS layer shows OSM notes as colored dots on the map:

- **Red Dots**: Open notes (issues that need attention)
- **Green Dots**: Closed notes (issues that have been resolved)

The color intensity tells you how old the note is:
- **Darker colors**: Older notes
- **Lighter colors**: Newer notes

## Getting Started

### Prerequisites

Before you can use the WMS layer, you need:

1. **JOSM** (Java OpenStreetMap Editor) or **Vespucci** (Android editor)
2. **Internet connection** to access the WMS service
3. **WMS service URL** (provided by your administrator)

### Basic Setup

#### For JOSM Users

1. **Open JOSM**
   - Launch JOSM on your computer

2. **Add WMS Layer**
   - Go to `Imagery` menu
   - Select `Add WMS Layer...`

3. **Enter WMS Details**
   - **WMS URL**: `http://localhost:8080/geoserver/wms`
   - **Layer Name**: `osm_notes:notes_wms_layer`
   - Click `OK`

4. **Configure Layer**
   - Right-click on the layer in the layers panel
   - Select `Properties`
   - Adjust transparency if needed (try 50-70%)

#### For Vespucci Users

1. **Open Vespucci**
   - Launch Vespucci on your Android device

2. **Add WMS Layer**
   - Go to `Layer` menu
   - Select `Add WMS Layer...`

3. **Enter WMS Details**
   - **WMS URL**: `http://localhost:8080/geoserver/wms`
   - **Layer Name**: `osm_notes:notes_wms_layer`
   - Tap `OK`

4. **Configure Layer**
   - Long-press on the layer
   - Select `Properties`
   - Adjust transparency as needed

## Understanding the Map

### Color Coding

#### Open Notes (Red Dots)

| Color | Meaning | Priority |
|-------|---------|----------|
| **Dark Red** | Recently opened (last few days) | High - Check soon |
| **Medium Red** | Open for a few weeks | Medium - Plan to address |
| **Light Red** | Open for months | Low - May need special attention |

#### Closed Notes (Green Dots)

| Color | Meaning | Information |
|-------|---------|-------------|
| **Dark Green** | Recently closed | Recently resolved |
| **Medium Green** | Closed some time ago | Previously resolved |
| **Light Green** | Closed long ago | Historical data |

### Spatial Patterns

#### What to Look For

1. **Clusters of Red Dots**
   - Indicates an area with many open issues
   - May need systematic mapping work
   - Could be a complex feature (shopping center, university, etc.)

2. **Sparse Areas**
   - Few notes might mean well-mapped area
   - Or could mean the area hasn't been surveyed

3. **Linear Patterns**
   - Notes along roads suggest road mapping issues
   - Notes along rivers suggest water feature issues
   - Notes along boundaries suggest administrative issues

4. **Recent Activity**
   - Dark red dots in an area suggest recent mapping activity
   - Could indicate ongoing mapping projects

### Interpreting Note Density

#### High Density Areas (>10 notes per km²)
- **Urban centers**: Complex areas with many features
- **Transportation hubs**: Stations, airports, major intersections
- **Tourist areas**: Hotels, restaurants, attractions
- **Construction zones**: Areas with ongoing development

#### Medium Density Areas (2-10 notes per km²)
- **Suburban areas**: Residential neighborhoods
- **Commercial districts**: Shopping areas
- **Industrial zones**: Factories, warehouses

#### Low Density Areas (<2 notes per km²)
- **Rural areas**: Farmland, forests
- **Parks and recreation**: Natural areas
- **Well-mapped areas**: Already completed mapping

## Best Practices

### When to Use WMS

#### Good Times to Check WMS
- **Before starting mapping work** in a new area
- **When planning mapping sessions** to prioritize areas
- **After completing work** to see if you missed anything
- **When coordinating with other mappers** to avoid duplication

#### How to Use WMS Effectively
1. **Start with a wide view** to see overall patterns
2. **Zoom in** to specific areas of interest
3. **Combine with other data sources** (satellite imagery, existing OSM data)
4. **Use transparency** to see underlying map features
5. **Check regularly** as notes are constantly being added

### Layer Management

#### Transparency Settings
- **0-30%**: Good for seeing underlying map features
- **30-50%**: Balanced view of notes and map
- **50-70%**: Emphasizes notes over map
- **70-100%**: Notes only (use with other imagery)

#### Zoom Levels
- **Zoom 0-8**: Overview of large areas
- **Zoom 9-12**: City/regional level
- **Zoom 13-15**: Neighborhood level
- **Zoom 16+**: Street level detail

### Combining with Other Data

#### Recommended Layer Combinations
1. **WMS + Satellite Imagery**: See notes against real-world features
2. **WMS + OSM Data**: Compare notes with existing mapping
3. **WMS + GPS Tracks**: Plan efficient mapping routes
4. **WMS + Administrative Boundaries**: Understand jurisdictional issues

## Common Scenarios

### Scenario 1: Planning a Mapping Session

**Situation**: You want to map a new neighborhood

**Steps**:
1. **Check WMS layer** for the area
2. **Look for red dots** (open notes)
3. **Prioritize areas** with many recent notes
4. **Plan your route** to hit high-priority areas first
5. **Check again** after mapping to see if you missed anything

### Scenario 2: Quality Control

**Situation**: You've completed mapping an area

**Steps**:
1. **Enable WMS layer** to see notes
2. **Look for any red dots** in your mapped area
3. **Investigate notes** that seem relevant to your work
4. **Address issues** or mark notes as resolved
5. **Update your mapping** if needed

### Scenario 3: Coordinating with Others

**Situation**: Working with a mapping team

**Steps**:
1. **Share WMS layer** with team members
2. **Identify areas** with many notes
3. **Divide work** based on note density
4. **Communicate** about areas you're working on
5. **Update team** when notes are resolved

## Troubleshooting

### Common Issues

#### WMS Layer Not Loading

**Symptoms**:
- Layer appears but shows no data
- Error messages about connection
- Blank or gray tiles

**Solutions**:
1. **Check internet connection**
2. **Verify WMS URL** is correct
3. **Try refreshing** the layer
4. **Check with administrator** if service is running

#### Performance Issues

**Symptoms**:
- Slow loading of tiles
- Application becomes unresponsive
- High memory usage

**Solutions**:
1. **Reduce zoom level** (don't zoom in too far)
2. **Adjust transparency** to reduce rendering load
3. **Close other applications** to free memory
4. **Use smaller bounding boxes** if possible

#### Color Confusion

**Symptoms**:
- Can't distinguish between note types
- Colors seem wrong
- Hard to see against background

**Solutions**:
1. **Adjust transparency** for better contrast
2. **Use different background** (satellite vs. map)
3. **Zoom in/out** to see different detail levels
4. **Check layer properties** for style settings

### Getting Help

#### When to Ask for Help
- **WMS service unavailable** for extended periods
- **Incorrect data** showing in your area
- **Performance problems** that don't resolve
- **Questions about interpretation** of patterns

#### How to Get Help
1. **Check documentation** first
2. **Ask your mapping community** (local groups, forums)
3. **Contact your administrator** for technical issues
4. **Report bugs** through proper channels

## Advanced Features

### Custom Filters

#### By Note Age
- **Recent notes**: Focus on last 30 days
- **Older notes**: Look for long-standing issues
- **Historical patterns**: See trends over time

#### By Geographic Area
- **City limits**: Focus on urban areas
- **Administrative boundaries**: Work within jurisdictions
- **Custom polygons**: Define your own areas of interest

### Integration with Other Tools

#### JOSM Plugins
- **WMS Layer Manager**: Enhanced WMS control
- **Note Tool**: Direct note editing
- **Measurement Tool**: Distance calculations

#### Vespucci Features
- **Layer management**: Multiple WMS layers
- **Offline support**: Cache WMS data
- **GPS integration**: Navigate to notes

## Tips and Tricks

### Efficiency Tips

1. **Use bookmarks** for frequently accessed areas
2. **Set up layer presets** for different mapping scenarios
3. **Combine with other data sources** for comprehensive view
4. **Regular updates** keep your view current

### Quality Tips

1. **Verify notes** before acting on them
2. **Check note details** for specific information
3. **Update notes** when you resolve issues
4. **Add your own notes** for issues you find

### Communication Tips

1. **Share WMS layer** with mapping partners
2. **Discuss patterns** with local community
3. **Report systematic issues** to administrators
4. **Document your findings** for others

## Glossary

### WMS Terms

- **WMS**: Web Map Service - standard for serving map images
- **Layer**: A collection of geographic data (in this case, notes)
- **Tile**: Small image pieces that make up the map
- **Bounding Box**: Geographic area covered by the map
- **Transparency**: How see-through the layer is

### Note Terms

- **Open Note**: Issue that hasn't been resolved yet
- **Closed Note**: Issue that has been addressed
- **Note Age**: How long a note has been open/closed
- **Note Density**: Number of notes per area
- **Note Cluster**: Group of notes in a small area

### Color Terms

- **Dark Red**: Recently opened notes (high priority)
- **Medium Red**: Notes open for moderate time
- **Light Red**: Notes open for extended time
- **Dark Green**: Recently closed notes
- **Medium Green**: Notes closed some time ago
- **Light Green**: Notes closed long ago

## Support and Resources

### Documentation
- **Technical Guide**: See `docs/WMS_Guide.md`
- **API Reference**: See `docs/WMS_API_Reference.md`
- **Administration Guide**: See `docs/WMS_Administration.md`

### Community Support
- **OSM Forums**: Ask questions about mapping
- **Local Mapping Groups**: Connect with nearby mappers
- **Social Media**: Follow OSM communities

### Training Resources
- **OSM Wiki**: Comprehensive mapping guides
- **Video Tutorials**: Visual learning resources
- **Workshops**: Hands-on training sessions

## Version Information

- **WMS Version**: 1.3.0
- **Last Updated**: 2025-07-27
- **Compatible with**: JOSM 0.9+, Vespucci 0.9+

## Feedback

We welcome your feedback to improve this guide:

- **Report issues** with the WMS service
- **Suggest improvements** to the documentation
- **Share success stories** of using WMS effectively
- **Contribute tips** for other users

---

*This guide is designed to help you make the most of the WMS layer for OSM notes. Remember, the goal is to make mapping more efficient and collaborative by visualizing where attention is needed.* 