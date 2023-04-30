<#
.SYNOPSIS
	Import files (e.g.: photos and videos) from the source folder and organize them by date into subfolders of the
	destination folder.

.DESCRIPTION
	This script imports files, such as new photos and videos, from the source folder and organizes them by date into
	subfolders of the destination folder. Duplicates are moved to the duplicates folder for manual processing. It can
	read the source and destination folders and other settings from a configuration file, or they can be
	specified on the command line.

.PARAMETER ConfigFilePath
	The path to a JSON configuration file that contains the settings for the script. If not specified, the script
	will look for a file named 'Organize-FilesByDate_config.json' in the same directory as the script.

.PARAMETER SourceDir
	The path to the source folder that contains the files (e.g.: photos and videos) to import. This parameter is
	optional if a configuration file is used.

.PARAMETER DestDir
	The path to the destination folder where the imported files (e.g.: photos and videos) will be saved into
	subfolders by date. This parameter is optional if a configuration file is used.

.PARAMETER DupeDir
	The path to the duplicates folder where files with names that already exist in the destination folder are
	sorted into timestamped folders for manual processing.

.PARAMETER LogFile
	The full path and file name to a text file where the script's log output will be written. If not specified, the
	script will write to a file named 'Organize-FilesByDate_log.txt' in the same directory as the script.

.EXAMPLE
	.\Organize-FilesByDate.ps1 -ConfigFilePath "C:\MyScripts\OrganizeConfig.json"
	Organize files using the source folder, destination folder, duplicates folder and log file specified in the
	'OrganizeConfig.json' file.

.EXAMPLE
	.\Organize-FilesByDate.ps1 -SourceDir "C:\Users\Bob\Dropbox\Camera Uploads" -DestDir "D:\Pictures" -DupeDir "C:\Users\Bob\Desktop\Dupes"
	Imports new photos and videos from the 'Camera Uploads' folder in Bob's Dropbox directory to the 'D:\Pictures'
	directory and sends duplicates to 'C:\Users\Bob\Desktop\Dupes'.

#>

[CmdletBinding(DefaultParameterSetName='DefaultConfigFile')]
param (
    [Parameter(ParameterSetName='ConfigFile', Mandatory=$true, ValueFromPipeline=$false)]
    [Parameter(ParameterSetName='DefaultConfigFile', Mandatory=$false, ValueFromPipeline=$false)]
    [string]$ConfigFilePath,

    [Parameter(ParameterSetName='NoConfigFile', Mandatory=$true, ValueFromPipeline=$false)]
    [Parameter(ParameterSetName='DefaultConfigFile', Mandatory=$false, ValueFromPipeline=$false)]
    [string]$SourceDir,

    [Parameter(ParameterSetName='NoConfigFile', Mandatory=$true, ValueFromPipeline=$false)]
    [Parameter(ParameterSetName='DefaultConfigFile', Mandatory=$false, ValueFromPipeline=$false)]
    [string]$DestDir,

    [Parameter(ParameterSetName='NoConfigFile', Mandatory=$true, ValueFromPipeline=$false)]
    [Parameter(ParameterSetName='DefaultConfigFile', Mandatory=$false, ValueFromPipeline=$false)]
    [string]$DupeDir,

    [Parameter(ParameterSetName='NoConfigFile', Mandatory=$false, ValueFromPipeline=$false)]
    [Parameter(ParameterSetName='DefaultConfigFile', Mandatory=$false, ValueFromPipeline=$false)]
    [string]$LogFile
)

# Set default values for variables
$scriptName = "Organize-FilesByDate"
$scriptVer = "0.8"
$scriptPath = Join-Path $PSScriptRoot $scriptName
$defaultConfigFileName = $scriptName + "_config.json"
$defaultConfigFilePath = Join-Path $PSScriptRoot $defaultConfigFileName
$defaultLogFileName = $scriptName + "_log.txt"
$defaultLogFilePath = Join-Path $PSScriptRoot $defaultLogFileName
$srcDir = ""
$dstDir = ""
$dupeDir = ""
$logFile = ""

# Check if config file path was provided on the command line
if ($args -contains "-ConfigFilePath") {
	$configFilePathIndex = $args.IndexOf("-ConfigFilePath") + 1
	$configFilePath = $args[$configFilePathIndex]

	# Try to read config file
	try {
		$configFileContent = Get-Content $configFilePath | ConvertFrom-Json
		$srcDir = $configFileContent.srcDir
		$dstDir = $configFileContent.dstDir
		$dupeDir = $configFileContent.dupeDir
		$logFile = $configFileContent.logFile
	}
	catch {
		Write-Error "Error reading config file at $configFilePath"
		exit 1
	}
}
else {
	# Look for default config file in script directory
	if (Test-Path $defaultConfigFilePath) {
		# Try to read default config file
		try {
			$configFileContent = Get-Content $defaultConfigFilePath | ConvertFrom-Json
			$srcDir = $configFileContent.srcDir
			$dstDir = $configFileContent.dstDir
			$dupeDir = $configFileContent.dupeDir
			$logFile = $configFileContent.logFile
		}
		catch {
			Write-Error "Error reading default config file at $defaultConfigFilePath"
			exit 1
		}
	}
}

# Check if variables were set by config file
if ($srcDir -eq "" -or $dstDir -eq "" -or $dupeDir -eq "" -or $logFile -eq "") {
	# Variables not set by config file, check if they were provided on the command line
	if ($args -contains "-SourceDir" -and $args -contains "-DestDir" -and $args -contains "-DupeDir" -and $args -contains "-LogFile") {
		$srcDirIndex = $args.IndexOf("-SourceDir") + 1
		$dstDirIndex = $args.IndexOf("-DestDir") + 1
		$dupeDirIndex = $args.IndexOf("-DupeDir") + 1
		$logFileIndex = $args.IndexOf("-LogFile") + 1
		$srcDir = $args[$srcDirIndex]
		$dstDir = $args[$dstDirIndex]
		$dupeDir = $args[$dupeDirIndex]
		$logFile = $args[$logFileIndex]
	}
	elseif ($args -contains "-SourceDir" -and $args -contains "-DestDir" -and $args -contains "-DupeDir") {
		$srcDirIndex = $args.IndexOf("-SourceDir") + 1
		$dstDirIndex = $args.IndexOf("-DestDir") + 1
		$dupeDirIndex = $args.IndexOf("-DupeDir") + 1
		$srcDir = $args[$srcDirIndex]
		$dstDir = $args[$dstDirIndex]
		$dupeDir = $args[$dupeDirIndex]
		$logFile = $defaultLogFilePath
	}
	else {
		# Variables not set by config file or command line, write error message and exit
		Write-Error "Variables not set. Please specify them on the command line or in a config file. For syntax, use 'Get-Help $scriptPath'."
		exit 1
	}
}

# Use the variables as needed in the script
Write-Host "SourceDir: $srcDir"
Write-Host "DestDir: $dstDir"
Write-Host "DupeDir: $dupeDir"
Write-Host "LogFile: $logFile"

# Initialize the log file
$timeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logText = "Start of log for $timeStamp"
Add-Content $logFile $logText
Write-Host $logText

# Initialize variables
$duplicates = 0
$errorCode = 0

# Check if source directory (Camera Uploads) exists
if (Test-Path "$srcDir") {

	# Set the error code to 0 indicating that there was no error
	$errorCode = 0

	# Get all files in the source folder
	$files = Get-ChildItem $srcDir -File

	# Loop through each file
	foreach ($file in $files) {

		# Get the date the file was last modified
		$date = $file.LastWriteTime.ToString("yyyy-MM-dd")

		# If a subfolder with the date doesn't exist in the destination folder, create it
		if (!(Test-Path "$dstDir\$date")) {
			
			# Log that a subfolder will be created
			$logText = "Creating subfolder $date."
			Add-Content $logFile $logText
			Write-Host $logText
			
			# Create subfolder
			$null = New-Item -ItemType Directory -Path "$dstDir\$date"
		}

		# Check if a file with the same name exists in the destination folder
		if (Test-Path "$dstDir\$date\$($file.Name)") {

			# Set the duplicates variable to 1 indicating that there was at least one duplicate
			$duplicates = 1

			# File with same name exists in destination folder
			$logText = "Duplicate: $file already exists in $dstDir\$date. Moving to $dupeDir for manual processing."
			Add-Content $logFile $logText
			Write-Host $logText
			
			# Create duplicates folder if it doesn't exist
			if (!(Test-Path "$dupeDir\$timeStamp")) {
				
				# Log that a subfolder will be created
				$logText = "Creating duplicates folder $dupeDir\$timeStamp."
				Add-Content $logFile $logText
				Write-Host $logText
				
				# Create duplicates folder
				$null = New-Item -ItemType Directory -Path "$dupeDir\$timeStamp"
			}
			
			# Move the file to the duplicates folder
			Move-Item $file.FullName "$dupeDir\$timeStamp"
		}
		else {

			# Log the action to be taken
			$logText = "Moving $file to $dstDir\$date."
			Add-Content $logFile $logText
			Write-Host $logText

			# Move the file to the subfolder with the date
			Move-Item $file.FullName "$dstDir\$date"
		}
	}

	# There were no files in the source directory
	if ($files.count -eq 0) {
		
		# Log that there were no files in the source directory
		$logText = "$srcDir is empty. Nothing to do."
		Add-Content $logFile $logText
		Write-Host $logText
		
		# Set the error code to 2 indicating that there was nothing to do
		$errorCode = 2
	}
	
	# Check whether there were any duplicates
	if ($duplicates -eq 1) {
		
		# Set error code to 3 indicating that there was at least one duplicate
		$errorCode = 3
	}
}

# The source directory doesn't exist
else {

	# Log that the source directory doesn't exist
	$logText = "Error: Source directory $srcDir does not exist. Cannot continue."
	Add-Content $logFile $logText
	Write-Host $logText
	
	# Set the error code to 1 to indicate there was an error
	$errorCode = 1
}

# Mark the end of the log
$logText = "End of log for $timeStamp`n"
Add-Content $logFile $logText
Write-Host $logText

# Exit with error code
Write-Host "Exiting with error code $errorCode."
Exit $errorCode