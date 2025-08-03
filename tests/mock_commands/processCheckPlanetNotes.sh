#!/bin/bash

# Mock processCheckPlanetNotes.sh for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

# Mock function for downloading planet notes
__downloadPlanetNotes() {
 echo "Mock: Downloading planet notes..."
 # Create mock files if needed
 mkdir -p /tmp/mock_planet
 echo "Mock planet data" > /tmp/mock_planet/planet-notes.osm.bz2
 echo "Mock: Planet notes downloaded successfully"
 return 0
}

# Mock function for creating required files
__createMockFiles() {
 # Create mock files that notesCheckVerifier.sh expects
 mkdir -p /tmp
 echo "id,lat,lon,created_at,closed_at,status,id_country,part_id" > /tmp/lastNote.csv
 echo "1,40.7128,-74.0060,2023-01-01 00:00:00 UTC,2023-01-02 00:00:00 UTC,closed,1,1" >> /tmp/lastNote.csv
 echo "id,note_id,action,timestamp,uid,user" > /tmp/lastCommentNote.csv
 echo "1,1,opened,2023-01-01 00:00:00 UTC,12345,testuser" >> /tmp/lastCommentNote.csv
 echo "id" > /tmp/differentNoteIds.csv
 echo "id" > /tmp/differentNoteCommentIds.csv
 echo "id,lat,lon,created_at,closed_at,status,id_country,part_id" > /tmp/differentNotes.csv
 echo "id,note_id,action,timestamp,uid,user" > /tmp/differentNoteComments.csv
 echo "id,note_id,action,timestamp,uid,user,text" > /tmp/differentTextComments.csv
 echo "id,note_id,action,timestamp,uid,user,text" > /tmp/textComments.csv
}

# Mock function for processing planet notes
__processPlanetNotes() {
 echo "Mock: Processing planet notes..."
 echo "Mock: Planet notes processed successfully"
 return 0
}

# Mock function for database operations
__mockDatabaseOperations() {
 echo "Mock: Performing database operations..."
 # Create mock files that the script expects
 __createMockFiles
 echo "Mock: Database operations completed"
 return 0
}

# Main function
main() {
 echo "Mock: processCheckPlanetNotes.sh started"
 
 # Parse arguments
 while [[ $# -gt 0 ]]; do
   case $1 in
     --help|-h)
       echo "Mock processCheckPlanetNotes.sh - Help"
       echo "Usage: $0 [OPTIONS]"
       echo "Options:"
       echo "  --help, -h    Show this help message"
       echo "  --dry-run      Run in dry-run mode"
       exit 0
       ;;
     --dry-run)
       echo "Mock: Running in dry-run mode"
       ;;
     *)
       echo "Mock: Unknown option: $1"
       ;;
   esac
   shift
 done
 
 # Execute mock functions
 __downloadPlanetNotes
 __processPlanetNotes
 __mockDatabaseOperations
 
 echo "Mock: processCheckPlanetNotes.sh completed successfully"
 exit 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 main "$@"
fi 