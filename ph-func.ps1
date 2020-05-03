function Warning-Send
(
 [string] $Message
)
{
 Write-host $Message
}

function Get-ScriptPath {
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
  Write-host $CommandSet -ForegroundColor Yellow
 }
 $error.clear()
 $errorMessage = $null
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
 [string] $DoubleExtension,
 [boolean] $VaultCheckFlag = $false
)
{
 if (Test-Path "$SourcePath") 
 {
  $FileList = get-childitem -Path $SourcePath -Recurse -Include $FilterSet | where { ! $_.PSIsContainer }
  $tenPersentPie = [math]::Round($($FileList.Count)/10)
  $i = 0
  $Percent = 0
  $FileList | % {
   $i=$i+1
   if ($i%$tenPersentPie -eq 0) {$Percent = $Percent+10; Write-host "$Percent%"}
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
    $UnicPath = $("$PHUnicPath\$Year\$Month").Replace("\","\\")
    $NameTail = "_$($sha256hash.Substring($sha256hash.Length-$sha256hashRenameLength,$sha256hashRenameLength))"
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
     $CommandAddFile += "INSERT INTO t_filename (filename_id,filename,time_stamp) SELECT * FROM (SELECT null,'$filename$NameTail','$Time_stamp') as tmp WHERE not EXISTS (SELECT filename FROM t_filename WHERE filename = '$filename$NameTail');"
     $CommandAddFile += "INSERT INTO t_filetype (filetype_id,filetype,time_stamp) SELECT * FROM (SELECT null,'$filetype','$Time_stamp') as tmp WHERE not EXISTS (SELECT filetype FROM t_filetype WHERE filetype = '$filetype');"
     $CommandAddFile += "INSERT INTO t_path (path_id,path,time_stamp) SELECT * FROM (SELECT null,'$UnicPath','$Time_stamp') as tmp WHERE not EXISTS (SELECT path FROM t_path WHERE path = '$UnicPath');"
     $CommandAddFile += "INSERT INTO t_hash (filename_id,filetype_id,path_id,Sha256hash,filesize,fileTS,Time_stamp) SELECT * FROM (SELECT (SELECT filename_id FROM t_filename WHERE filename = '$filename$NameTail'),(SELECT filetype_id FROM t_filetype WHERE filetype = '$filetype'),(SELECT path_id FROM t_path WHERE path = '$UnicPath'),'$Sha256hash',$filesize,'$fileTS','$Time_stamp') as tmp;"
     $CommandAddFile += "UPDATE t_hash SET Time_stamp='$Time_stamp' WHERE  Sha256hash = '$Sha256hash';"
     Write-ToSQLbasePacket -CommandSet $CommandAddFile
     
     if (!(Test-Path "$PHUnicPath")) {New-Item -ItemType Directory -Path "$PHUnicPath" | out-null}
     if (!(Test-Path "$PHUnicPath\$Year")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year" | out-null}
     if (!(Test-Path "$PHUnicPath\$Year\$Month")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year\$Month" | out-null}
     if (!(Test-Path "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)"))
     {
      Copy-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -Destination "$PHUnicPath\$Year\$Month"
      if (Test-Path "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)") 
      {
       Rename-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$($_.Extension).$DoubleExtension"
       Rename-Item -LiteralPath "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$NameTail$($_.Extension)"
      }
     }
    }
   }
   else
   {
    if ($VaultCheckFlag) 
    {
     $CommandFindByHash = "select concat(path,'\\',filename,filetype) as name from t_hash join t_filename using (filename_id) join t_filetype using (filetype_id) join t_path using (path_id) where sha256hash = '$sha256hash';"
     $First = $($(Get-DataFromSQL -Command $CommandFindByHash).name)
     $Second = "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)"
     if ($First -ne $Second) {Warning-Send "`n`nЗадвоение данных в хранилище. `nИсточник проблемы:`nПервое вхождение $First`nВторое вхождение $Second`n`n"}
    }
    else {Rename-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$($_.Extension).$DoubleExtension"}
   }
  }
 }
 else {if (!$VaultCheckFlag) {Warning-Send "Указанный в настройках источник данных не существует на диске"}}
}