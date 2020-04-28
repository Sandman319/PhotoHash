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