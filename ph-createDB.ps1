cls
$Time_stamp = $(Get-Date -UFormat '%Y-%m-%d %H:%M:%S')
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

if (test-connection $IPaddressOfMySQLserver -Quiet) 
{

 add-type -AssemblyName System.Drawing
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
 
 if ($FlagCheckUnicVault) 
 {
  Write-host "Начали проверку хранилища уникальных данных на задвоенность файлов"
  Write-host "Обработка фото"
  Get-Date
  File-Processing -SourcePath $PHUnicPhotoPath -FilterSet $FilterSetPhoto -PHUnicPath $PHUnicPhotoPath -DoubleExtension $DoubleExtension -VaultCheckFlag $True
  Write-host "Обработка видео"
  Get-Date
  File-Processing -SourcePath $PHUnicVideoPath -FilterSet $FilterSetVideo -PHUnicPath $PHUnicVideoPath -DoubleExtension $DoubleExtension -VaultCheckFlag $True
 }
 
 foreach ($M in $Molotilka)
 {
  if (Test-Path $M)
  {
   Write-Host "Обрабатывается исходная папка: $M`n" -ForegroundColor Green
   Get-Date
   Write-host "Обработка фото"
   File-Processing -SourcePath $M -FilterSet $FilterSetPhoto -PHUnicPath $PHUnicPhotoPath -DoubleExtension $DoubleExtension
   Get-Date
   #Write-host "Обработка видео"
   #File-Processing -SourcePath $M -FilterSet $FilterSetVideo -PHUnicPath $PHUnicVideoPath -DoubleExtension $DoubleExtension
   Get-Date
   Write-host "Обработка завершена"
  }
 }
}
else {Write-host "Сервер с БД не доступен" -ForegroundColor Red}