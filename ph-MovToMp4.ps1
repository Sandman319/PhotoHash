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

$FileList = get-childitem -Path $Molotilka -Recurse -Include $FilterMovFiles | where { ! $_.PSIsContainer }
$tenPersentPie = [math]::Round($($FileList.Count)/10)
$i = 0
$Percent = 0
Get-Date
$FileList | % {
 $i=$i+1
 if ($i%$tenPersentPie -eq 0) {$Percent = $Percent+10; Write-host "$Percent%"}
 (cmd /c "$PathToFFMPEG\ffmpeg.exe" -i "$($_.FullName)" "$($_.DirectoryName)\$($_.BaseName).mp4") 2>$null
 $NewFile = Get-item "$($_.DirectoryName)\$($_.BaseName).mp4"
 $NewFile.LastWriteTime = $_.LastWriteTime
 Rename-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$($_.Extension).$DoubleExtension"
} 
Get-Date