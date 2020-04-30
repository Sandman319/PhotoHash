﻿function Get-ScriptPath {
	$scritDir = Get-Variable PSScriptRoot -ErrorAction SilentlyContinue | ForEach-Object { $_.Value }
	if (!$scriptDir) {
		if ($MyInvocation.MyCommand.Path) {
			$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
		}
	}
	if (!$scriptDir) {
		if ($ExecutionContext.SessionState.Module.Path) {
			$scriptDir = Split-Path (Split-Path $ExecutionContext.SessionState.Module.Path)
		}
	}
	if (!$scriptDir) {
		$scriptDir = $PWD
	}
	return $scriptDir
}

function GetVariableFromIniFile 
{
 param ([string[]] $FileName)
 
 $ScriptRoot = Get-ScriptPath
 $iniFileContent = Get-Content -Path "$ScriptRoot\$FileName"
 #$iniFileContent = Get-Content -Path "C:\job\Project\NetworkRevision\script\$FileName"
 $iniFileContent | %{
  $parts = $_.split("=")
  Set-Variable -Name $parts[0].Trim() -Value $(Invoke-Expression $parts[1].Trim()) -Scope Global
 }
}

Function Get-DataFromSQL
(
 [string] $Command
)
{
 $MYSQLCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
 $MYSQLDataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter
 $MYSQLDataSet = New-Object System.Data.DataSet
 $MYSQLCommand.Connection=$Connection
 $MYSQLCommand.CommandText=$Command
 $Connection.Open()
 $MYSQLDataAdapter.SelectCommand=$MYSQLCommand
 $NumberOfDataSets=$MYSQLDataAdapter.Fill($MYSQLDataSet, "data")
 $Connection.Close()
 $Result = $MYSQLDataSet.tables[0] 
 Return $Result
}

function Write-ToSQLbasePacket
{
 param ($CommandSet)

 $MYSQLCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
 $Connection.Open()
 $MYSQLCommand.Connection = $Connection
 $MYSQLCommand.CommandText = $CommandSet
 $MYSQLCommand.ExecuteNonQuery()
 $Connection.Close()
}

function Write-ToSQLbasePacketPerLine
{
 param ($CommandSet)

 $MYSQLCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
 $Connection.Open()
 $MYSQLCommand.Connection = $Connection
 
 foreach ($c in $CommandSet)
 {
  $MYSQLCommand.CommandText = $c
  Try 
  {
   $ErrorActionPreference = "Stop"
   $MYSQLCommand.ExecuteNonQuery() | Out-Null
  }
  Catch 
  {$errorMessage = $Error[0].Exception}
  Finally {$ErrorActionPreference = "Continue"}
  if ($errorMessage -ne $null) 
  {
   Write-host $errorMessage -ForegroundColor Red 
   #"$Date_stamp $errorMessage" >> $LogProcessingErrors
   Write-host $c -ForegroundColor Yellow
   #"$Date_stamp $c" >> $LogProcessingErrors
  }
  $error.clear()
  $errorMessage = $null
 }
 $Connection.Close()
}

Function File-Processing
(
 [string] $SourcePath,
 [array] $FilterSet,
 [string] $PHUnicPath,
 [string] $DoubleExtension
)
{
 get-childitem -Path $SourcePath -Recurse -Include $FilterSet | where { ! $_.PSIsContainer } | % {
  $sha256hash = (Get-FileHash -LiteralPath $_.FullName).hash
  $CheckFileExist = "select count(sha256hash) as num from t_hash where sha256hash = '$sha256hash'"
  if ($(Get-DataFromSQL -Command $CheckFileExist).Num -eq 0) 
  {
   $flagAcceptString = $true
   $filename = $($_.BaseName).Replace("'","''")
   $filetype = $_.Extension
   $path = $($_.DirectoryName).Replace("\","\\")
   $filesize = $_.Length
   $fileTStmp1 = "$($_.LastWriteTime)".split(" ")
   $fileTStmp2 = $fileTStmp1[0].split("/")
   $Year = $fileTStmp2[2]
   $Month = $fileTStmp2[0]
   $fileTS = "$Year-$Month-$($fileTStmp2[1]) $($fileTStmp1[1])"
   if ($flagAcceptString) {
    if ($filename -eq "") {$filename = "UNKNOWN"}
    if ($filetype -eq "") {$filetype = "UNKNOWN"}
    if ($path.Length -gt 254) {$flagAcceptString = $false; Write-host "Path too LONG!`t$_"}
    if ($path.Length -eq "") {$flagAcceptString = $false; Write-host "Path is UNKNOWN!`t$_"}
    if ($filesize -eq "") {$flagAcceptString = $false; Write-host "File size is UNKNOWN!`t$_"}
    if ($fileTS -eq "") {$flagAcceptString = $false; Write-host "File TimeStamp is UNKNOWN!`t$_"}
    if ($Sha256hash -eq "") {$flagAcceptString = $false; Write-host "File hash is UNKNOWN!`t$_"}
   }
   if ($flagAcceptString) {
    $CommandAddFile = ""
    $CommandAddFile += "INSERT INTO t_filename (filename_id,filename,time_stamp) SELECT * FROM (SELECT null,'$filename','$Time_stamp') as tmp WHERE not EXISTS (SELECT filename FROM t_filename WHERE filename = '$filename');"
    $CommandAddFile += "INSERT INTO t_filetype (filetype_id,filetype,time_stamp) SELECT * FROM (SELECT null,'$filetype','$Time_stamp') as tmp WHERE not EXISTS (SELECT filetype FROM t_filetype WHERE filetype = '$filetype');"
    $CommandAddFile += "INSERT INTO t_path (path_id,path,etalon,time_stamp) SELECT * FROM (SELECT null,'$path',0,'$Time_stamp') as tmp WHERE not EXISTS (SELECT path FROM t_path WHERE path = '$path');"
    $CommandAddFile += "INSERT INTO t_hash (filename_id,filetype_id,path_id,Sha256hash,filesize,fileTS,Time_stamp) SELECT * FROM (SELECT (SELECT filename_id FROM t_filename WHERE filename = '$filename'),(SELECT filetype_id FROM t_filetype WHERE filetype = '$filetype'),(SELECT path_id FROM t_path WHERE path = '$path'),'$Sha256hash',$filesize,'$fileTS','$Time_stamp') as tmp;"
    $CommandAddFile += "UPDATE t_hash SET Time_stamp='$Time_stamp' WHERE  Sha256hash = '$Sha256hash';"
    Write-ToSQLbasePacket -CommandSet $CommandAddFile
    
    if (!(Test-Path "$PHUnicPath")) {New-Item -ItemType Directory -Path "$PHUnicPath"}
    if (!(Test-Path "$PHUnicPath\$Year")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year"}
    if (!(Test-Path "$PHUnicPath\$Year\$Month")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year\$Month"}
    if (!(Test-Path "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)"))
    {
     Copy-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -Destination "$PHUnicPath\$Year\$Month"
     if (Test-Path "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)") {Rename-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$($_.Extension).$DoubleExtension"}
    }
   }
  }
  else
  {
   Rename-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$($_.Extension).$DoubleExtension"
  }
 }
}