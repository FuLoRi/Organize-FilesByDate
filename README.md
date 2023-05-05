# Organize-FilesByDate
Import files (e.g.: photos and videos) from the source folder and organize them by date into subfolders of the destination folder.

## Description
This script imports files, such as new photos and videos, from the source folder and organizes them by date into
subfolders of the destination folder. Duplicates are moved to the duplicates folder for manual processing. It can
read the source and destination folders and other settings from a configuration file, or they can be
specified on the command line.

You can use the command `Get-Help Organize-FilesByDate` to get the proper syntax.

## Features
- Designed to be automated (e.g.: via Task Scheduler)
- Folder/file paths can be provided on the command line or in a JSON-formatted config file
- Looks for config file in default location if no parameters are provided on the command line
- Duplicate filename handling - files with names that exist in the destination are moved to another folder for manual processing
- Keeps a log (appends to a file) every time it runs
- Returns error codes on exit to indicate the outcome (0=success, 1=error, 2=nothing to do, 3=duplicates need manual processing)

## Note
**If you save the associated config (JSON) file in the same directory as the script, make sure to edit it and specify the correct
paths before running the script without parameters.**

