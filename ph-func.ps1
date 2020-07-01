function Warning-Send
(
 [string] $Message,
 [string] $ForegroundColor = "White"
)
{
 Write-host $Message -ForegroundColor $ForegroundColor
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

Function Write-FileToDatabase_old
(
 [object] $File,
 [string] $sha256hash,
 [string] $NameTail,
 [string] $PHUnicPath,
 [string] $Year,
 [string] $Month,
 [boolean] $FlagMovMod = $false
)
{
 $flagAcceptString = $true
 $filename = $($File.BaseName).Replace("'","''")
 $filetype = $File.Extension
 $path = $($File.DirectoryName).Replace("\","\\")
 $filesize = $File.Length
 $fileTStmp1 = "$($File.LastWriteTime)".split(" ")
 $fileTStmp2 = $fileTStmp1[0].split("/")
 $fileTS = "$Year-$Month-$($fileTStmp2[1]) $($fileTStmp1[1])"
 $UnicPath = $("$PHUnicPath\$Year\$Month").Replace("\","\\")
 $UnicPath = $($UnicPath -split ":\\\\")[1]
 if ($flagAcceptString) 
 {
  if ($filename -eq "") {$filename = "UNKNOWN"}
  if ($filetype -eq "") {$filetype = "UNKNOWN"}
  if ($path.Length -gt 254) {$flagAcceptString = $false; Write-host "Path too LONG!`t$_"}
  if ($path.Length -eq "") {$flagAcceptString = $false; Write-host "Path is UNKNOWN!`t$_"}
  if ($filesize -eq "") {$flagAcceptString = $false; Write-host "File size is UNKNOWN!`t$_"}
  if ($fileTS -eq "") {$flagAcceptString = $false; Write-host "File TimeStamp is UNKNOWN!`t$_"}
  if ($Sha256hash -eq "") {$flagAcceptString = $false; Write-host "File hash is UNKNOWN!`t$_"}
 }
 if (($filename -ne "UNKNOWN") -and $FlagMovMod) {$filename = ($filename -split "_hash")[0]}
 if ($flagAcceptString) 
 {
  $CommandAddFile = ""
  $CommandAddFile += "INSERT INTO t_filename (filename_id,filename,time_stamp) SELECT * FROM (SELECT null,'$filename$NameTail','$Time_stamp') as tmp WHERE not EXISTS (SELECT filename FROM t_filename WHERE filename = '$filename$NameTail');"
  $CommandAddFile += "INSERT INTO t_filetype (filetype_id,filetype,time_stamp) SELECT * FROM (SELECT null,'$filetype','$Time_stamp') as tmp WHERE not EXISTS (SELECT filetype FROM t_filetype WHERE filetype = '$filetype');"
  $CommandAddFile += "INSERT INTO t_path (path_id,path,time_stamp) SELECT * FROM (SELECT null,'$UnicPath','$Time_stamp') as tmp WHERE not EXISTS (SELECT path FROM t_path WHERE path = '$UnicPath');"
  $CommandAddFile += "INSERT INTO t_hash (filename_id,filetype_id,path_id,Sha256hash,filesize,fileTS,Time_stamp) SELECT * FROM (SELECT (SELECT filename_id FROM t_filename WHERE filename = '$filename$NameTail'),(SELECT filetype_id FROM t_filetype WHERE filetype = '$filetype'),(SELECT path_id FROM t_path WHERE path = '$UnicPath'),'$Sha256hash',$filesize,'$fileTS','$Time_stamp') as tmp;"
  $CommandAddFile += "UPDATE t_hash SET Time_stamp='$Time_stamp' WHERE  Sha256hash = '$Sha256hash';"
  Write-ToSQLbasePacket -CommandSet $CommandAddFile  
  Return $True
 }
 else {Return $False}
}

Function Write-FileToDatabase
(
 [object] $File
)
{
 $flagAcceptString = $true
 Write-host $File.FullName
 $sha256hash  = (Get-FileHash -LiteralPath $File.FullName).hash
 #Write-host "OK"
 $filename = $($File.BaseName).Replace("'","''")
 $filetype = $File.Extension
 $path = $($File.DirectoryName).Replace("\","\\")
 $filesize = $File.Length
 $fileTStmp1 = "$($File.LastWriteTime)".split(" ")
 $fileTStmp2 = $fileTStmp1[0].split("/")
 $Year = $fileTStmp2[2]
 $Month = $fileTStmp2[0] 
 $fileTS = "$Year-$Month-$($fileTStmp2[1]) $($fileTStmp1[1])"
 $UnicPath = $($path -split ":\\\\")[1]
 if ($filename -eq "") {$filename = "UNKNOWN"}
 if ($filetype -eq "") {$filetype = "UNKNOWN"}
 if ($path.Length -gt 254) {$flagAcceptString = $false; Warning-Send -message "Path too LONG!`t$($File.FullName)"}
 if ($path.Length -eq "") {$flagAcceptString = $false; Warning-Send -message "Path is UNKNOWN!`t$($File.FullName)"}
 if ($filesize -eq "") {$flagAcceptString = $false; Warning-Send -message "File size is UNKNOWN!`t$($File.FullName)"}
 if ($fileTS -eq "") {$flagAcceptString = $false; Warning-Send -message "File TimeStamp is UNKNOWN!`t$($File.FullName)"}
 if ($Sha256hash -eq "") {$flagAcceptString = $false; Warning-Send -message "File hash is UNKNOWN!`t$($File.FullName)"}

 if ($flagAcceptString) 
 {
  $CommandAddFile = ""
  $CommandAddFile += "INSERT INTO t_filename (filename_id,filename,time_stamp) SELECT * FROM (SELECT null,'$filename','$Time_stamp') as tmp WHERE not EXISTS (SELECT filename FROM t_filename WHERE filename = '$filename');"
  $CommandAddFile += "INSERT INTO t_filetype (filetype_id,filetype,time_stamp) SELECT * FROM (SELECT null,'$filetype','$Time_stamp') as tmp WHERE not EXISTS (SELECT filetype FROM t_filetype WHERE filetype = '$filetype');"
  $CommandAddFile += "INSERT INTO t_path (path_id,path,time_stamp) SELECT * FROM (SELECT null,'$UnicPath','$Time_stamp') as tmp WHERE not EXISTS (SELECT path FROM t_path WHERE path = '$UnicPath');"
  $CommandAddFile += "INSERT INTO t_hash (filename_id,filetype_id,path_id,Sha256hash,filesize,fileTS,Time_stamp) SELECT * FROM (SELECT (SELECT filename_id FROM t_filename WHERE filename = '$filename'),(SELECT filetype_id FROM t_filetype WHERE filetype = '$filetype'),(SELECT path_id FROM t_path WHERE path = '$UnicPath'),'$Sha256hash',$filesize,'$fileTS','$Time_stamp') as tmp;"
  $CommandAddFile += "UPDATE t_hash SET Time_stamp='$Time_stamp' WHERE  Sha256hash = '$Sha256hash';"
  Write-ToSQLbasePacket -CommandSet $CommandAddFile  
  Return $True
 }
 else {Return $False}
}


Function File-Processing_old
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
  $FileList = get-childitem -Path $SourcePath -Recurse -Include $FilterSet -Force | where { ! $_.PSIsContainer }
  $tenPersentPie = [math]::Round($($FileList.Count)/10)
  $i = 0
  $Percent = 0
  Write-host "Найдено файлов: $($FileList.Count)"
  $FileList | % {
   $FlagAcceptFile = $True
   if ($FilterSetPhoto -eq "*$($_.Extension)")
   {   
    $aa = $_.FullName
    try 
    {
     $fileMetadata = New-Object System.Drawing.Bitmap($aa)
     $fileMetadata.Dispose()
    }
    catch 
    {
     Write-host "Поврежденный файл: $aa" -ForegroundColor Red
     $FlagAcceptFile = $False
    }
   }
   if ($FlagAcceptFile)
   {
    $i=$i+1
    if ($i%$tenPersentPie -eq 0) {$Percent = $Percent+10; Write-host "$Percent%"}
    $sha256hash = (Get-FileHash -LiteralPath $_.FullName).hash
    $CheckFileExist = "select count(sha256hash) as num from t_hash where sha256hash = '$sha256hash'"
    if ($(Get-DataFromSQL -Command $CheckFileExist).Num -eq 0) 
    {
     $fileTStmp1 = "$($_.LastWriteTime)".split(" ")
     $fileTStmp2 = $fileTStmp1[0].split("/")
     $Year = $fileTStmp2[2]
     $Month = $fileTStmp2[0]
     $NameTail = "_hash$($sha256hash.Substring($sha256hash.Length-$sha256hashRenameLength,$sha256hashRenameLength))"
     
     if (!(Test-Path "$PHUnicPath")) {New-Item -ItemType Directory -Path "$PHUnicPath" | out-null}
     if (!(Test-Path "$PHUnicPath\$Year")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year" | out-null}
     if (!(Test-Path "$PHUnicPath\$Year\$Month")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year\$Month" | out-null}
     if (!(Test-Path "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)"))
     {
      Copy-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -Destination "$PHUnicPath\$Year\$Month"
      if (Test-Path "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)") 
      {
       $AltDate = ""
       if ($FilterSetPhoto -eq "*$($_.Extension)")
       {
        $FileFSTimeStamp = (($_.lastwritetime).GetDateTimeFormats('u') -split " ")[0]
        $pdate = ""
        $FileMetadataTimeStamp = "UNSET"
        $aa = $_.FullName
        $fileMetadata = New-Object System.Drawing.Bitmap($aa)
        try 
        {
         $pdate = [System.Text.Encoding]::ASCII.GetString($fileMetadata.GetPropertyItem(36867).Value)
         $FileMetadataTimeStamp = [datetime]::ParseExact($pdate,"yyyy:MM:dd HH:mm:ss`0",$null).ToString('yyyy-MM')
        }
        catch {}
        $fileMetadata.Dispose()
        if ((!($FileFSTimeStamp -match $FileMetadataTimeStamp)) -and ($FileMetadataTimeStamp -ne "UNSET")) 
        {
         $AltDate = "__[date$FileMetadataTimeStamp]"
         #Write-host "$($_.FullName) " -NoNewline; Write-host "$FileFSTimeStamp " -ForegroundColor Green -NoNewline; Write-Host $FileMetadataTimeStamp -ForegroundColor Yellow
        }
       }
       Rename-Item -LiteralPath "$PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$NameTail$AltDate$($_.Extension)"
       if ($FilterMovMod -eq $($_.Extension))
       {
        (cmd /c "$PathToFFMPEG\ffmpeg.exe" -i "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail$($_.Extension)" "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail.mp4") 2>$null
        if ((Test-Path "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail.mp4")) 
        {
         $NewMP4file = Get-item "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail.mp4"
         $NewMP4file.LastWriteTime = $_.LastWriteTime
         $sha256hashNewMP4file = (Get-FileHash -LiteralPath $NewMP4file.FullName).hash
         $CheckFileExistNewMP4file = "select count(sha256hash) as num from t_hash where sha256hash = '$sha256hashNewMP4file'"
         if ($(Get-DataFromSQL -Command $CheckFileExistNewMP4file).Num -eq 0) 
         {
          $fileTStmpNewMP4file1 = "$($NewMP4file.LastWriteTime)".split(" ")
          $fileTStmpNewMP4file2 = $fileTStmpNewMP4file1[0].split("/")
          $YearNewMP4file = $fileTStmpNewMP4file2[2]
          $MonthNewMP4file = $fileTStmpNewMP4file2[0]
          $NameTailNewMP4file = "_hash$($sha256hashNewMP4file.Substring($sha256hashNewMP4file.Length-$sha256hashRenameLength,$sha256hashRenameLength))"
          Rename-Item -LiteralPath $NewMP4file.FullName -NewName "$(($($NewMP4file.BaseName) -split ""_hash"")[0])$NameTailNewMP4file.mp4"
          if (!$(Write-FileToDatabase -File $NewMP4file -sha256hash $sha256hashNewMP4file -NameTail $NameTailNewMP4file -PHUnicPath $PHUnicPath -Year $YearNewMP4file -Month $MonthNewMP4file -FlagMovMod $true)) {Write-host "Информация о файле не была сохранена в БД: $($NewMP4file.FullName)"}
          Rename-Item -LiteralPath "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail$($_.Extension)" -NewName "$($_.BaseName)$NameTail$($_.Extension).$MovModExtension"
          if (!$(Write-FileToDatabase -File $_ -sha256hash $sha256hash -NameTail $NameTail -PHUnicPath $PHUnicPath -Year $Year -Month $Month)) {Write-host "Информация о файле не была сохранена в БД: $($_.FullName)"}
         }  
         else 
         {
          Remove-Item "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail.mp4" -Force
          Remove-Item "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail$($_.Extension)" -Force
     
          $CommandFindByHash = "select concat(path,'\\',filename,filetype) as name from t_hash join t_filename using (filename_id) join t_filetype using (filetype_id) join t_path using (path_id) where sha256hash = '$sha256hashNewMP4file';"
          $FileName = $($(Get-DataFromSQL -Command $CommandFindByHash).name)
          Write-host "Переконвертированный файл уже есть в БД. Подробности:`n    Хэш mp4-файла: $sha256hashNewMP4file`
     Исходный файл в источнике: $($_.DirectoryName)\$($_.BaseName)$($_.Extension)`n    Скопированный в уникальное хранилище: $PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail$($_.Extension)`
     Совпавший по хэшу файл в БД:    $FileName`n    Имя сконвертированного файла из-за котрого подняли тревогу: $($NewMP4file.FullName)"
         }
        }
        else
        {
         Remove-Item "$PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail$($_.Extension)" -Force
         Write-Host "Пропущен файл $($_.FullName)" -ForegroundColor Red
         Write-Host "Ошибка при конвертировании. Подробности:`n   Исходный: $PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail$($_.Extension)`
    Должен был стать: $PHUnicPath\$Year\$Month\$($_.BaseName)$NameTail.mp4"
        }
       }
       else 
       {
        if (!$(Write-FileToDatabase -File $_ -sha256hash $sha256hash -NameTail $NameTail -PHUnicPath $PHUnicPath -Year $Year -Month $Month)) {Write-host "Информация о файле не была сохранена в БД: $($_.FullName)"}
       } 
       Rename-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$($_.Extension).$DoubleExtension" 
      }
     }
     else {Write-host "Файл с таким именем уже был в месте расположения, до начала копирования: `n   Уже имеющийся: $PHUnicPath\$Year\$Month\$($_.BaseName)$($_.Extension)`n   Второй экземпляр, который пытаемся скопировать: $($_.FullName)"}
    }
    else
    {
     if ($VaultCheckFlag) 
     {
      $CommandFindByHash = "select concat(path,'\\',filename,filetype) as name from t_hash join t_filename using (filename_id) join t_filetype using (filetype_id) join t_path using (path_id) where sha256hash = '$sha256hash';"
      $First = $($(Get-DataFromSQL -Command $CommandFindByHash).name)
      $Second = "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)"
      if ($First -ne $Second) {Warning-Send -message "`n`nЗадвоение данных в хранилище. `nИсточник проблемы:`nПервое вхождение $First`nВторое вхождение $Second`n`n"}
     }
     else {Rename-Item -LiteralPath "$($_.DirectoryName)\$($_.BaseName)$($_.Extension)" -NewName "$($_.BaseName)$($_.Extension).$DoubleExtension"}
    }
   }
  }
 }
 else 
 {
  if (!$VaultCheckFlag) {Warning-Send -message "Указанный в настройках источник данных не существует на диске"}
 }
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
 ## путь к молотилке существует?
 if (Test-Path "$SourcePath") 
 {
  ## получаем список файлов по общей маске
  $FileList = get-childitem -Path $SourcePath -Recurse -Include $FilterSet -Force | where { ! $_.PSIsContainer }
  $FilesFound = $FileList.Count
  Write-host "Найдено файлов: $FilesFound"

  ## инициализация прогреса выполнения
  $tenPersentPie = [math]::Round($FilesFound/10)
  $i = 0
  $Percent = 0

  Foreach ($FileMolotilka in $FileList)
  {
   ## зануляем хвосты
   $HashTail = ""
   $AltDateTail = ""
   
   ## это фото?
   if ($FilterSetPhoto -eq "*$($FileMolotilka.Extension)")
   {   
    $aa = $FileMolotilka.FullName
    $pdate = ""
    $FileMetadataTimeStamp = "UNSET"
    try 
    {
     $fileMetadata = New-Object System.Drawing.Bitmap($aa)
     $fileMetadata.Dispose()
    }
    catch 
    {
     $fileMetadata.Dispose()
     Warning-Send -message "Поврежденный файл: $aa" -ForegroundColor Red
     Rename-Item -LiteralPath $FileMolotilka.Fullname -NewName "$($FileMolotilka.BaseName)$($FileMolotilka.Extension).$DoubleExtension" -Force
     continue
    }
    try 
    {
     $fileMetadata = New-Object System.Drawing.Bitmap($aa)
     $pdate = [System.Text.Encoding]::ASCII.GetString($fileMetadata.GetPropertyItem(36867).Value)
     $FileMetadataTimeStamp = [datetime]::ParseExact($pdate,"yyyy:MM:dd HH:mm:ss`0",$null).ToString('yyyy-MM')
     $fileMetadata.Dispose()
    }
    catch 
    {
     $fileMetadata.Dispose()
    }
    $FileMolotilkaTimeStamp = (($FileMolotilka.lastwritetime).GetDateTimeFormats('u') -split " ")[0]
    if ((!($FileMolotilkaTimeStamp -match $FileMetadataTimeStamp)) -and ($FileMetadataTimeStamp -ne "UNSET")) {$AltDateTail = "__[date$FileMetadataTimeStamp]"}
   }
   
   $i=$i+1
   if ($i%$tenPersentPie -eq 0) {$Percent = $Percent+10; Write-host "$Percent%"}
   
   ## считаем хэш
   $sha256hash = (Get-FileHash -LiteralPath $FileMolotilka.FullName).hash
   $HashTail = "_hash$($sha256hash.Substring($sha256hash.Length-$sha256hashRenameLength,$sha256hashRenameLength))"
   
   ## проверяем хэш в БД
   $CheckFileExist = "select count(sha256hash) as num from t_hash where sha256hash = '$sha256hash'"
   if ($(Get-DataFromSQL -Command $CheckFileExist).Num -eq 0) 
   {
    ## разбираем метку времени, строим путь куда ляжет
    $fileTStmp1 = "$($FileMolotilka.LastWriteTime)".split(" ")
    $fileTStmp2 = $fileTStmp1[0].split("/")
    $Year = $fileTStmp2[2]
    $Month = $fileTStmp2[0]   
    if (!(Test-Path "$PHUnicPath")) {New-Item -ItemType Directory -Path "$PHUnicPath" | out-null}
    if (!(Test-Path "$PHUnicPath\$Year")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year" | out-null}
    if (!(Test-Path "$PHUnicPath\$Year\$Month")) {New-Item -ItemType Directory -Path "$PHUnicPath\$Year\$Month" | out-null}
    
    ## формируем новое имя для файла
    $NewFileName = "$($FileMolotilka.BaseName)$HashTail$AltDateTail$($FileMolotilka.Extension)"

    ## в приемнике есть файл с таким именем?
    if (!(Test-Path "$PHUnicPath\$Year\$Month\$NewFileName"))
    {
     ## переносим файл из молотилки в хранилище с попутным переименованием
     Copy-Item -LiteralPath "$($FileMolotilka.FullName)" -Destination "$PHUnicPath\$Year\$Month\$NewFileName"
     ## скопированный файл берем как объект

     #Write-host "$($FileMolotilka.FullName)" -ForegroundColor DarkMagenta
     #Write-host "$PHUnicPath\$Year\$Month\$NewFileName" -ForegroundColor DarkMagenta

     $FileUnic = Get-Item -LiteralPath "$PHUnicPath\$Year\$Month\$NewFileName"

     #Write-host $FileUnic.FullName -ForegroundColor Magenta

     ## файл требует перекодировки?
     if ($FilterMovMod -eq "$($FileUnic.Extension)")
     {
      ## кодируем файл
      Get-Date
      Write-host "(cmd /c ""$PathToFFMPEG\ffmpeg.exe"" -i ""$PHUnicPath\$Year\$Month\$($FileUnic.Name)"" ""$PHUnicPath\$Year\$Month\$($FileUnic.BaseName).mp4"") 2>$null"
      Write-host "Файл $i из $FilesFound" -ForegroundColor Yellow
      (cmd /c "$PathToFFMPEG\ffmpeg.exe" -i "$PHUnicPath\$Year\$Month\$($FileUnic.Name)" "$PHUnicPath\$Year\$Month\$($FileUnic.BaseName).mp4") 2>c:\temp\log.txt
      ## кодировка успешна?
      if ((Test-Path "$PHUnicPath\$Year\$Month\$($FileUnic.BaseName).mp4"))
      {
       ## берем как объект переконвертированный файл
       $sha256hashRecodedVideoFile = (Get-FileHash -LiteralPath "$PHUnicPath\$Year\$Month\$($FileUnic.BaseName).mp4").hash
       $HashTailRecodedVideoFile = "_hash$($sha256hashRecodedVideoFile.Substring($sha256hashRecodedVideoFile.Length-$sha256hashRenameLength,$sha256hashRenameLength))"
       $NewFileNameRecodedVideo = "$($($FileUnic.BaseName -split '_hash')[0])$HashTailRecodedVideoFile.mp4"
       if (!(Test-Path "$PHUnicPath\$Year\$Month\$NewFileNameRecodedVideo")) 
       {
        Rename-Item -LiteralPath "$PHUnicPath\$Year\$Month\$($FileUnic.BaseName).mp4" -NewName $NewFileNameRecodedVideo
       }
       else 
       {
        Warning-Send -message "Перекодировали видео $PHUnicPath\$Year\$Month\$($FileUnic.Name)." -ForegroundColor Cyan
        Warning-Send -message "У результата посчитали хэш: $sha256hashRecodedVideoFile." -ForegroundColor Cyan
        Warning-Send -message "При переименовании - дубль в имени: $NewFileNameRecodedVideo" -ForegroundColor Cyan
        #Warning-Send -message "Дубликат переименован в $NewFileNameRecodedVideo.DoubleName" -ForegroundColor Cyan
        #Rename-Item -LiteralPath "$PHUnicPath\$Year\$Month\$($FileUnic.BaseName).mp4" -NewName "$NewFileNameRecodedVideo.DoubleName"
       }
       $FileRecodedVideo = Get-Item -LiteralPath "$PHUnicPath\$Year\$Month\$NewFileNameRecodedVideo"

       ## переименовываем в хранилище оригинальное видео в "сконвертированное"
       Rename-Item -LiteralPath "$PHUnicPath\$Year\$Month\$($FileUnic.Name)" -NewName "$($FileUnic.Name).$MovModExtension"
       ## берем как объект оригинальный и переименованный видеофайл
       $FileOriginalVideo = Get-Item -LiteralPath "$PHUnicPath\$Year\$Month\$($FileUnic.Name).$MovModExtension"
       ## пишем в БД инфу по обоим видеофайлам - оригинал и переконвертированное
       
       $CheckRecodedVideoFileExist = "select count(sha256hash) as num from t_hash where sha256hash = '$sha256hashRecodedVideoFile'"
       if ($(Get-DataFromSQL -Command $CheckRecodedVideoFileExist).Num -eq 0) 
       {
        if (!$(Write-FileToDatabase -File $FileRecodedVideo)) {Write-host "Информация о файле не была сохранена в БД: $($FileRecodedVideo.FullName)"}
       }
       else 
       {
        Remove-Item $FileRecodedVideo.FullName -Force
        Warning-Send -message "Дубликат найден. Удален дубликат $($FileRecodedVideo.FullName) так как такой же хэш найден в БД: $sha256hashRecodedVideoFile" -ForegroundColor Cyan
       }
       if (!$(Write-FileToDatabase -File $FileOriginalVideo)) {Write-host "Информация о файле не была сохранена в БД: $($FileOriginalVideo.FullName)"}
      }
      else 
      {
       ## кодировка не успешна, удаляем скопированный в хранилище файл
       Remove-Item $FileUnic.FullName -Force
       Warning-Send -message "Пропущен файл $($FileMolotilka.FullName)" -ForegroundColor Red
       Warning-Send -message "Ошибка при конвертировании. Подробности:`n   Исходный: $($FileUnic.FullName) `nДолжен был стать: $PHUnicPath\$Year\$Month\$($FileUnic.BaseName).mp4"
      }
     }
     else 
     {
      ## пишем в БД инфу о файле, который без приключений лег в хранилище
      #Write-host "471 FileUnic: $($FileUnic.FullName)" -ForegroundColor Yellow
      if (!$(Write-FileToDatabase -File $FileUnic)) {Write-host "Информация о файле не была сохранена в БД: $($FileUnic.FullName)"}
     }
    }
    else 
    {
     ## пропускаем файл с конфликтом 
     Warning-Send -message "В приемнике уже есть файл с таким именем: $PHUnicPath\$Year\$Month\$NewFileName `n Файл, который пытались поместить в приемник и хэш которого в имени файла совпал, а в БД не был найден: $($FileMolotilka.FullName)`n $sha256hash"
     Rename-Item -LiteralPath $FileMolotilka.FullName -NewName "$($FileMolotilka.BaseName)$($FileMolotilka.Extension).$DoubleExtension"
     continue
    }
   }
   ## переименовываем файл в молотилке, чтобы второй раз с ним не возиться
   Rename-Item -LiteralPath $FileMolotilka.FullName -NewName "$($FileMolotilka.BaseName)$($FileMolotilka.Extension).$DoubleExtension"
  }
 }
 else {Warning-Send -message "Указанный в настройках источник данных не существует на диске"}
}

function Check-UnicVault
(
 [string] $SourcePath
)
{
 get-childitem -Path $SourcePath -Recurse -Include $FilterCommonSet -Force | where { ! $_.PSIsContainer } | %{Write-FileToDatabase -File $_}
}