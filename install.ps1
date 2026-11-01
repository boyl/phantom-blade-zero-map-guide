#Requires -Version 7.0
[CmdletBinding()]
param([string]$GameRoot,[string]$PackageRoot=$PSScriptRoot,[ValidateSet('Install','Uninstall','Verify')][string]$Action='Install',[switch]$NoPause,[switch]$Elevated)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'tools/install-transaction.psm1') -Force
$script:PBZInstallerWorkRoot=[IO.Path]::GetTempPath()

function Get-PBZUniqueLibraries([string[]]$Paths){
 $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach($directory in $Paths){$full=[IO.Path]::GetFullPath($directory).TrimEnd('\','/');if($seen.Add($full)){$full}}
}
function Find-PBZGameRoot {
 $steam=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -Name SteamPath).SteamPath
 $libraries=@($steam);$libraryFile=Join-Path $steam 'steamapps/libraryfolders.vdf'
 if(Test-Path -LiteralPath $libraryFile){$libraries+=@([regex]::Matches([IO.File]::ReadAllText($libraryFile),'"path"\s+"([^"]+)"')|ForEach-Object{$_.Groups[1].Value.Replace('\\','\')})}
 $roots=@(foreach($library in @(Get-PBZUniqueLibraries $libraries)){
  $manifest=Join-Path $library 'steamapps/appmanifest_4115450.acf'
  if(Test-Path -LiteralPath $manifest){$match=[regex]::Match([IO.File]::ReadAllText($manifest),'"installdir"\s+"([^"]+)"');if($match.Success){Join-Path $library ('steamapps/common/'+$match.Groups[1].Value)}}
 })
 if($roots.Count -ne 1){throw '无法唯一定位 Steam 游戏，请用 -GameRoot 指定游戏目录。'}
 return $roots[0]
}
function Get-PBZGameProcesses([string]$Root) {
 $executables=@((Join-Path $Root 'platform/steam/PBZ.exe'),(Join-Path $Root 'steam/PBZ.exe'))
 return @(Get-Process -Name PBZ -ErrorAction SilentlyContinue|Where-Object{$_.Path -in $executables})
}
function Read-PBZOwnership([string]$Mods) {
 $file=Resolve-ModFile $Mods 'PBZMapGuide/.pbz-map-guide-install.json'
 $previous=@{}
 if(Test-Path -LiteralPath $file){
  $record=[IO.File]::ReadAllText($file)|ConvertFrom-Json
  if($record.id -ne 'PBZMapGuide' -or $record.format -ne 1){throw '安装所有权清单无效，未修改文件。'}
  foreach($entry in $record.files){
   if($entry.target -notlike 'Scripts/*' -or $entry.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw '旧文件清单无效。'}
   $relative='PBZMapGuide/'+$entry.target
   [void](Resolve-ModFile $Mods $relative)
   if($previous.ContainsKey($relative)){throw '旧文件清单重复。'}
   $previous[$relative]=$entry.sha256
  }
  $previous['PBZMapGuide/.pbz-map-guide-install.json']=Get-ModHash $file
 }
 return $previous
}
function Invoke-PBZInstallation([string]$Root,[string]$Package,[string]$Mode) {
 $Root=(Resolve-Path -LiteralPath $Root).Path
 foreach($relative in @('platform/steam/PBZ.exe','ProjectPBZ/Content/Paks')){
  if(-not (Test-Path -LiteralPath (Resolve-ModFile $Root $relative))){throw '指定目录不是预期的 Steam 影之刃零安装目录。'}
 }
 if($Mode -ne 'Verify' -and @(Get-PBZGameProcesses $Root).Count){throw '请先退出游戏，再安装、升级或卸载。'}
 $mods=Resolve-ModFile $Root 'platform/steam/ue4ss/Mods'
 if(-not (Test-Path -LiteralPath $mods -PathType Container) -or -not (Test-Path -LiteralPath (Resolve-ModFile $Root 'platform/steam/ue4ss/UE4SS.dll')) -or -not (Test-Path -LiteralPath (Resolve-ModFile $Root 'platform/steam/dwmapi.dll'))){throw '未发现完整 UE4SS，请先安装适配本游戏的加载器。'}
 $previous=Read-PBZOwnership $mods
 $namespace=Resolve-ModFile $mods 'PBZMapGuide/Scripts'
 $modDirectory=Split-Path $namespace -Parent
 if($Mode -eq 'Install' -and (Test-Path -LiteralPath $modDirectory -PathType Container) -and @(Get-ChildItem -LiteralPath $modDirectory -Filter '*.dll' -File -Recurse).Count){throw '该 Mod 目录含有未归属的原生模块，未覆盖或启用。'}
 if($Mode -eq 'Verify'){
  if(-not $previous.Count){throw '没有可核验的安装清单。'}
  foreach($relative in $previous.Keys){if((Get-ModHash (Resolve-ModFile $mods $relative)) -ne $previous[$relative]){throw "已安装文件不一致：$relative"}}
  $config=Resolve-ModFile $mods 'mods.txt'
  $text=if(Test-Path -LiteralPath $config){[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($config))}else{''}
  return [pscustomobject]@{Verified=$true;Enabled=($text -ceq (Update-ModEnabledText $text Enable));Action=$Mode;Files=$previous.Count-1}
 }
 $staging=Join-Path $script:PBZInstallerWorkRoot ('PBZMapGuide-install-'+[guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $staging -Force|Out-Null
 $plan=[Collections.Generic.List[object]]::new()
 $config=Resolve-ModFile $mods 'mods.txt';$configHash=Get-ModHash $config
 $text=if($configHash){[Text.UTF8Encoding]::new($false,$true).GetString([IO.File]::ReadAllBytes($config))}else{''}
 if($Mode -eq 'Install'){
  $manifest=[IO.File]::ReadAllText((Join-Path $Package 'manifest.json'))|ConvertFrom-Json
  if($manifest.id -ne 'PBZMapGuide' -or $manifest.format -ne 1 -or $manifest.entry -ne 'Scripts/main.lua'){throw '安装包清单无效。'}
  $source=Join-Path $Package 'payload/PBZMapGuide';$files=[Collections.Generic.List[object]]::new();$newNames=@{}
  foreach($entry in $manifest.files){
   if($entry.target -notlike 'Scripts/*' -or $entry.target -notlike '*.lua'){throw '安装包包含未授权的文件类型。'}
   $original=Resolve-ModFile $source $entry.target
   if((Get-ModHash $original) -ne $entry.sha256){throw "安装包文件校验失败：$($entry.target)"}
   $relative='PBZMapGuide/'+$entry.target;$newNames[$relative]=$true
   $copy=Resolve-ModFile $staging $relative;New-Item -ItemType Directory -Path (Split-Path $copy -Parent) -Force|Out-Null;Copy-Item -LiteralPath $original -Destination $copy
   $files.Add([pscustomobject]@{target=$relative;sha256=$entry.sha256})
  }
  if(-not $newNames.ContainsKey('PBZMapGuide/Scripts/main.lua')){throw '安装包缺少正式入口。'}
  $owner=Resolve-ModFile $staging 'PBZMapGuide/.pbz-map-guide-install.json'
  [ordered]@{format=1;id='PBZMapGuide';version=$manifest.version;contentHash=$manifest.contentHash;files=$manifest.files}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $owner -Encoding utf8NoBOM
  $files.Add([pscustomobject]@{target='PBZMapGuide/.pbz-map-guide-install.json';sha256=Get-ModHash $owner})
  foreach($file in @(New-ModFilePlan $staging $mods $files.ToArray() $previous)){$plan.Add($file)}
  $obsolete=@{};foreach($relative in $previous.Keys){if($relative -ne 'PBZMapGuide/.pbz-map-guide-install.json' -and -not $newNames.ContainsKey($relative)){$obsolete[$relative]=$previous[$relative]}}
  foreach($file in @(New-ModRemovalPlan $mods $obsolete)){$plan.Add($file)}
  $updated=Update-ModEnabledText $text Enable
 }else{
  if(-not $previous.Count){throw '没有所有权清单，未删除未知文件。'}
  $updated=Update-ModEnabledText $text Remove
  foreach($file in @(New-ModRemovalPlan $mods $previous)){$plan.Add($file)}
 }
 if($updated -ne $text){
  [IO.File]::WriteAllText((Join-Path $staging 'mods.txt'),$updated,[Text.UTF8Encoding]::new($false))
  $configPlan=@(New-ModFilePlan $staging $mods @([pscustomobject]@{target='mods.txt';sha256=Get-ModHash (Join-Path $staging 'mods.txt')}) @{'mods.txt'=$configHash})
  if($Mode -eq 'Uninstall'){for($index=$configPlan.Count-1;$index -ge 0;$index--){$plan.Insert(0,$configPlan[$index])}}else{foreach($file in $configPlan){$plan.Add($file)}}
 }
 Test-ModTargetAccess $plan.ToArray() $mods
 $result=Invoke-ModFileTransaction $plan.ToArray() $mods
 return [pscustomobject]@{Verified=$result.Verified;Action=$Mode;Files=$result.Files;Backup=$result.Backup}
}

if($MyInvocation.InvocationName -ne '.'){
 $code=0
 try{
  if(-not $GameRoot){$GameRoot=Find-PBZGameRoot}
  try{$result=Invoke-PBZInstallation $GameRoot $PackageRoot $Action}
  catch [UnauthorizedAccessException]{
   if($Elevated -or -not $_.Exception.Data.Contains('PBZTargetWrite')){throw}
   $beforeUninstall=if($Action -eq 'Uninstall'){Read-PBZOwnership (Join-Path $GameRoot 'platform/steam/ue4ss/Mods')}else{@{}}
   $pwsh=(Get-Command pwsh.exe -CommandType Application|Select-Object -First 1).Source
   $arguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -GameRoot "{1}" -PackageRoot "{2}" -Action {3} -Elevated -NoPause' -f $PSCommandPath,$GameRoot,$PackageRoot,$Action
   $process=Start-Process -FilePath $pwsh -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
   if($process.ExitCode -ne 0){throw "提权安装未成功，退出码 $($process.ExitCode)。"}
   if($Action -ne 'Uninstall'){
    $result=Invoke-PBZInstallation $GameRoot $PackageRoot Verify
    if($Action -eq 'Install' -and -not $result.Enabled){throw '文件核验通过，但本 Mod 没有启用。'}
   }else{
    $mods=Join-Path $GameRoot 'platform/steam/ue4ss/Mods'
    foreach($relative in $beforeUninstall.Keys){if(Get-ModHash (Resolve-ModFile $mods $relative)){throw '子进程退出成功但卸载文件仍存在。'}}
    $config=Join-Path $mods 'mods.txt'
    if((Test-Path -LiteralPath $config) -and [IO.File]::ReadAllText($config) -match '(?im)^[ \t]*PBZMapGuide[ \t]*:'){throw '卸载后仍存在本 Mod 启用行。'}
    $result=[pscustomobject]@{Verified=$true;Action='Uninstall'}
   }
  }
  $result|ConvertTo-Json -Depth 5
 }catch{Write-Warning $_.Exception.Message;$code=1}
 if(-not $NoPause){[void](Read-Host '按 Enter 关闭')}
 exit $code
}
