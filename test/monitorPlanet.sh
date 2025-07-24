#!/bin/bash

tail -40f $(ls -1rtd /tmp/processPlanetNotes_* | tail -1)/processPlanetNotes.log
