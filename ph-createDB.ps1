cls
#$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ScriptDirectory = "C:\job\Project\PhotoHash"
try 
{
 . ("$ScriptDirectory\ph-variable.ps1")
 . ("$ScriptDirectory\ph-func.ps1")
 . ("$ScriptDirectory\ph-sqlCommand.ps1")
}
catch {Write-Host "Error while loading supporting PowerShell Scripts"}

#GetVariableFromIniFile -FileName "ph-variable.ini"

Add-Type –Path $PathToMySQLdll
$Connection = [MySql.Data.MySqlClient.MySqlConnection]@{ConnectionString="server=$IPaddressOfMySQLserver;uid=$rootDBuser;pwd=$rootDBpass;charset=utf8"}

Get-DataFromSQL -Command $CheckDatabases | foreach {if ($_.Database -eq $DBname) {$FlagDBfound = $true}}
if (!$FlagDBfound) 
{
 Write-ToSQLbasePacket -CommandSet $CreateDBCommandSet
 $Connection = [MySql.Data.MySqlClient.MySqlConnection]@{ConnectionString="server=$IPaddressOfMySQLserver;uid=$DBuser;pwd=$DBpass;database=$DBname;charset=utf8"}
 Write-ToSQLbasePacket -CommandSet $CreateDBTablesCommandSet
}
else {$Connection = [MySql.Data.MySqlClient.MySqlConnection]@{ConnectionString="server=$IPaddressOfMySQLserver;uid=$DBuser;pwd=$DBpass;database=$DBname;charset=utf8"}}

