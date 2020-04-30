














$SourcePath = "c:\del me"
$FilterSetVideo = "*.avi","*.mp4","*.mpg","*.mpeg","*.wmv"
$FilterSetPicture = "*.bmp","*.jpg","*.jpeg","*.png","*.tif","*.tiff"


get-childitem -Path $SourcePath -Recurse -Include $FilterSetPicture | where { ! $_.PSIsContainer } | % {
 "$($_.BaseName)|$($_.Extension)|$($_.DirectoryName)|$($_.Length)|$($_.LastWriteTime)|$((Get-FileHash -LiteralPath $_.FullName).hash)"}