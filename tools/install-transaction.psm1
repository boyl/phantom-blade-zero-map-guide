#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Resolve-ModFile([string]$Root,[string]$Relative) {
 if([IO.Path]::IsPathRooted($Relative) -or $Relative.Contains(':')){throw '安装文件必须使用相对路径。'}
 $base=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
 $file=[IO.Path]::GetFullPath((Join-Path $base $Relative))
 if(-not $file.StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw '安装路径越界。'}
 $cursor=$file
 while($cursor){
  if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw '安装路径不能包含链接。'}
  $cursor=Split-Path $cursor -Parent
 }
 return $file
}
function Get-ModHash([string]$File) {
 if(-not (Test-Path -LiteralPath $File)){return $null}
 if(-not (Test-Path -LiteralPath $File -PathType Leaf)){throw '目标文件被目录占用。'}
 return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
}
function New-ModFilePlan([string]$Source,[string]$Destination,$Files,$Previous) {
 $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 $plan=[Collections.Generic.List[object]]::new()
 foreach($entry in $Files){
  if($entry.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw '源清单缺少合法 SHA-256。'}
  $target=Resolve-ModFile $Destination $entry.target
  if(-not $seen.Add($target)){throw '重复安装目标。'}
  $sourceFile=Resolve-ModFile $Source $entry.target
  $sourceHash=Get-ModHash $sourceFile
  if($sourceHash -ne $entry.sha256){throw "源文件校验失败：$($entry.target)"}
  $oldHash=Get-ModHash $target
  $ownedHash=if($Previous.ContainsKey($entry.target)){$Previous[$entry.target]}else{$null}
  if($oldHash -and $oldHash -ne $ownedHash -and $oldHash -ne $sourceHash){throw "保留已修改或未知文件，未覆盖：$($entry.target)"}
  $plan.Add([pscustomobject]@{Relative=$entry.target;Source=$sourceFile;Target=$target;SourceHash=$sourceHash;PreviousHash=$oldHash})
 }
 return $plan.ToArray()
}
function New-ModRemovalPlan([string]$Destination,$Previous) {
 $plan=[Collections.Generic.List[object]]::new()
 foreach($relative in $Previous.Keys){
  if($Previous[$relative] -notmatch '^[a-fA-F0-9]{64}$'){throw '旧清单缺少合法 SHA-256。'}
  $target=Resolve-ModFile $Destination $relative;$current=Get-ModHash $target
  if(-not $current){continue}
  if($current -ne $Previous[$relative]){throw "保留已修改的文件，未卸载：$relative"}
  $plan.Add([pscustomobject]@{Relative=$relative;Source=$null;Target=$target;SourceHash=$null;PreviousHash=$current})
 }
 return $plan.ToArray()
}
function Update-ModEnabledText([AllowEmptyString()][string]$Text,[ValidateSet('Enable','Disable','Remove')][string]$Action) {
 if($Text.StartsWith([string][char]0xFEFF,[StringComparison]::Ordinal)){return [string][char]0xFEFF+(Update-ModEnabledText $Text.Substring(1) $Action)}
 $pattern='(?im)^[ \t]*PBZMapGuide[ \t]*:[^\r\n]*'
 $found=[regex]::Matches($Text,$pattern)
 if($found.Count -gt 1){throw 'PBZMapGuide 启用配置重复，未修改。'}
 if($found.Count -eq 1){
  $line=$found[0];$valid=[regex]::Match($line.Value,'^[ \t]*PBZMapGuide[ \t]*:[ \t]*(?<state>[01])[ \t]*$',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $valid.Success){throw 'PBZMapGuide 启用配置格式未知，未修改。'}
  if($Action -eq 'Remove'){
   $length=$line.Length;$suffix=$Text.Substring($line.Index+$length)
   if($suffix.StartsWith("`r`n")){$length+=2}elseif($suffix.StartsWith("`n")){$length++}
   return $Text.Remove($line.Index,$length)
  }
  $position=$line.Index+$valid.Groups['state'].Index
  return $Text.Remove($position,1).Insert($position,($Action -eq 'Enable' ? '1' : '0'))
 }
 if($Action -eq 'Remove'){return $Text}
 $newline=$Text.Contains("`r`n") ? "`r`n" : "`n"
 $separator=($Text.Length -gt 0 -and -not $Text.EndsWith("`n")) ? $newline : ''
 return $Text+$separator+'PBZMapGuide : '+($Action -eq 'Enable' ? '1' : '0')+$newline
}
function Test-ModTargetAccess($Plan,[string]$Destination) {
 try{
  foreach($file in $Plan){
   if($file.PreviousHash){
    if((Get-Item -LiteralPath $file.Target).IsReadOnly){throw '目标文件只读，未尝试提权。'}
    $stream=[IO.File]::Open($file.Target,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite);$stream.Dispose()
   }
  }
  $probe=Resolve-ModFile $Destination ('.pbz-access-'+[guid]::NewGuid().ToString('N'))
  $stream=$null
  try{$stream=[IO.File]::Open($probe,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)}
  finally{if($stream){$stream.Dispose();Remove-Item -LiteralPath $probe -Force}}
 }catch [UnauthorizedAccessException]{$_.Exception.Data['PBZTargetWrite']=$true;throw}
}
function Invoke-ModFileTransaction($Plan,[string]$Destination,[scriptblock]$BeforeWrite) {
 if(-not @($Plan).Count){throw '安装清单不能为空。'}
 $backup=Resolve-ModFile $Destination ('.install-backups/'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $backup -Force|Out-Null
 foreach($file in $Plan){
  if($file.PreviousHash){
   if((Get-ModHash $file.Target) -ne $file.PreviousHash){throw '备份前目标已变化。'}
   $copy=Resolve-ModFile $backup ('files/'+$file.Relative)
   New-Item -ItemType Directory -Path (Split-Path $copy -Parent) -Force|Out-Null
   Copy-Item -LiteralPath $file.Target -Destination $copy
   if((Get-ModHash $copy) -ne $file.PreviousHash){throw '备份校验失败。'}
  }
 }
 $Plan|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $backup 'plan.json') -Encoding utf8
 $written=[Collections.Generic.List[object]]::new()
 try{
  $index=0
  foreach($file in $Plan){
   if($BeforeWrite){& $BeforeWrite $index};$index++
   if($file.SourceHash -and (Get-ModHash $file.Source) -ne $file.SourceHash){throw '复制前源文件已变化。'}
   if((Get-ModHash $file.Target) -ne $file.PreviousHash){throw '复制前目标已变化。'}
   if(-not $file.SourceHash){
    $written.Add($file);Remove-Item -LiteralPath $file.Target -Force
    if(Get-ModHash $file.Target){throw '卸载文件仍然存在。'}
    continue
   }
   New-Item -ItemType Directory -Path (Split-Path $file.Target -Parent) -Force|Out-Null
   $staging=Resolve-ModFile $Destination ($file.Relative+'.pbz-stage-'+[guid]::NewGuid().ToString('N'))
   if(Test-Path -LiteralPath $staging){throw '临时安装路径已存在。'}
   try{
    Copy-Item -LiteralPath $file.Source -Destination $staging
    if((Get-ModHash $staging) -ne $file.SourceHash){throw '暂存文件校验失败。'}
    if((Get-ModHash $file.Target) -ne $file.PreviousHash){throw '替换前目标已变化。'}
    $written.Add($file);[IO.File]::Move($staging,$file.Target,$true)
   }finally{if(Test-Path -LiteralPath $staging){Remove-Item -LiteralPath $staging -Force}}
   if((Get-ModHash $file.Target) -ne $file.SourceHash){throw '复制后校验失败。'}
  }
  foreach($file in $Plan){if((Get-ModHash $file.Target) -ne $file.SourceHash){throw '最终校验失败。'}}
 }catch{
  $failure=$_.Exception.Message;$errors=[Collections.Generic.List[string]]::new()
  for($i=$written.Count-1;$i -ge 0;$i--){
   $file=$written[$i]
   try{
    $current=Get-ModHash $file.Target
    if($current -ne $file.SourceHash -and $current -ne $file.PreviousHash){throw '安装后文件被其他程序修改，保留现场。'}
    if($file.PreviousHash){
     $copy=Resolve-ModFile $backup ('files/'+$file.Relative)
     if((Get-ModHash $copy) -ne $file.PreviousHash){throw '回滚备份哈希不符。'}
     Copy-Item -LiteralPath $copy -Destination $file.Target -Force
     if((Get-ModHash $file.Target) -ne $file.PreviousHash){throw '回滚校验失败。'}
    }elseif($current){Remove-Item -LiteralPath $file.Target -Force}
   }catch{$errors.Add($_.Exception.Message)}
  }
  if($errors.Count){throw "安装失败：$failure；部分回滚未完成：$($errors -join '；')；备份：$backup"}
  throw "安装失败并已回滚已写文件：$failure；备份：$backup"
 }
 return [pscustomobject]@{Verified=$true;Backup=$backup;Files=@($Plan).Count}
}
Export-ModuleMember -Function Resolve-ModFile,Get-ModHash,New-ModFilePlan,New-ModRemovalPlan,Update-ModEnabledText,Test-ModTargetAccess,Invoke-ModFileTransaction
