$script:KpaFotaApi = 'https://fota5p.adups.com/otainter-5.0/fota5'
$script:KpaFotaSign = $null
$script:KpaPayloadDumperHash = '09EA2F5BCB4424BDEEDAB4FC7983116BDD30661E7D886B1C453FC08C64066848'

function Invoke-KpaNativeCapture([scriptblock]$Action) {
    # Windows PowerShell 5.1 promotes native stderr to error records even when
    # the process succeeds. Native tools are authoritative through exit codes.
    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $Output = @(& $Action 2>&1)
        $ExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousPreference
    }
    return [pscustomobject]@{ ExitCode=$ExitCode; Output=$Output }
}

function ConvertTo-KpaFotaKey([string]$Text) {
    $Rng=[Security.Cryptography.RandomNumberGenerator]::Create(); $Key=New-Object byte[] 8; $Rng.GetBytes($Key)
    try {
        $Plain=[Text.Encoding]::UTF8.GetBytes($Text); $Out=New-Object byte[] (9+$Plain.Length); $Out[0]=8
        for($i=0;$i -lt 8;$i++){ $v=[int]$Key[$i]; $Out[1+$i]=[byte]((($v -shl 3)-bor($v -shr 5))-band 255) }
        for($i=0;$i -lt $Plain.Length;$i++){ $Out[9+$i]=[byte](([int]$Plain[$i])-bxor([int]$Key[$i%8])) }
        return (($Out|ForEach-Object{$_.ToString('X2')})-join '')
    } finally { $Rng.Dispose() }
}

function Get-KpaSha256Text([string]$Text) {
    $Sha=[Security.Cryptography.SHA256]::Create()
    try { return (($Sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join '') }
    finally { $Sha.Dispose() }
}

function Get-KpaOtaOffer([string]$SourceVersion,[string]$Serial) {
    if ($script:KpaDeviceProfile) {
        $script:KpaFotaApi = $script:KpaDeviceProfile.Ota.Api
        $script:KpaFotaSign = $script:KpaDeviceProfile.Ota.Sign
    }
    $O=$script:KpaDeviceProfile.Ota
    $Mid=(Get-Date -Format 'yyyyMMddHHmmss')+'Kp'+(Get-Random -Minimum 1000 -Maximum 9999)
    $P=[ordered]@{device_type=$O.DeviceType;connect_type=$O.ConnectType;platform=$O.Platform;project=$O.Project;version=$SourceVersion;devicesinfoExt=$O.DevicesInfoExt;swFingerprint=$O.Fingerprint;sdk_level=$O.SdkLevel;sdk_release=$O.SdkRelease;resolution=$O.Resolution;mid=$Mid;isNewMid='1';appVersion=$O.AppVersion;appCode=$O.AppCode;local='en-US';operator='';spn1='';spn2='';sendId=$O.SendId;fotaSign=$O.Sign;androidId='';fcmId='';agreeType='false';upgradeAgreement='false';isActive='false';imei1=$Serial;imei2='';mac='ff:ff:ff:ff:ff:ff';esn=$Serial}
    $Plain=''; foreach($Item in $P.GetEnumerator()){ $Plain+='&'+$Item.Key+'='+$Item.Value }
    $Key=ConvertTo-KpaFotaKey $Plain
    $Response=Invoke-RestMethod -Uri "$script:KpaFotaApi/detectSchedule.do" -Method Post -Body @{key=$Key;shaKey=(Get-KpaSha256Text $Key)} -TimeoutSec 45
    if($Response.status -eq 1000 -and $Response.version){ return $Response.version }
    return $null
}

function Test-KpaOtaArchive([string]$Path,$Offer) {
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
    if($Offer.filesize -and (Get-Item $Path).Length -ne [long]$Offer.filesize){return $false}
    if($Offer.md5sum -and (Get-FileHash $Path -Algorithm MD5).Hash -ine [string]$Offer.md5sum){return $false}
    if($Offer.sha -and (Get-FileHash $Path -Algorithm SHA256).Hash -ine [string]$Offer.sha){return $false}
    return $true
}

function Get-KpaOtaArchive([string]$CacheRoot,[string]$SourceVersion,$Offer) {
    $Target=[string]$Offer.versionName
    $Route=(($SourceVersion+'__to__'+$Target)-replace '[^A-Za-z0-9._-]','_')
    $Folder=Join-Path $CacheRoot $Route; New-Item -ItemType Directory -Force -Path $Folder|Out-Null
    $Name=[Uri]::UnescapeDataString([IO.Path]::GetFileName(([Uri][string]$Offer.deltaurl).AbsolutePath))
    if([string]::IsNullOrWhiteSpace($Name)){throw 'OTA server returned no file name.'}
    $File=Join-Path $Folder $Name
    if(Test-KpaOtaArchive $File $Offer){return $File}
    $Temp=$File+'.download'; Invoke-WebRequest -Uri ([string]$Offer.deltaurl) -OutFile $Temp -UseBasicParsing -TimeoutSec 300
    if(-not(Test-KpaOtaArchive $Temp $Offer)){Remove-Item $Temp -Force;throw 'Downloaded OTA checksum mismatch.'}
    Move-Item $Temp $File -Force
    return $File
}

function Save-KpaGeneratedIndex([string]$RootDir,[object[]]$Rows) {
    $Rows|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $RootDir 'generated-stock-boots.json') -Encoding UTF8
}

function Get-KpaRecordedPatchedHash([string]$RootDir,[string]$Version) {
    $IndexFile=Join-Path $RootDir 'generated-patched-boots.json'
    if(-not(Test-Path -LiteralPath $IndexFile -PathType Leaf)){return $null}
    $Entry=@(Get-Content -LiteralPath $IndexFile -Raw|ConvertFrom-Json)|Where-Object Version -eq $Version|Select-Object -First 1
    if($Entry){return [string]$Entry.Hash}
    return $null
}

function Save-KpaPatchedHash([string]$RootDir,[string]$Version,[string]$Hash,[string]$StockHash) {
    $IndexFile=Join-Path $RootDir 'generated-patched-boots.json'
    $Rows=if(Test-Path -LiteralPath $IndexFile -PathType Leaf){@(Get-Content -LiteralPath $IndexFile -Raw|ConvertFrom-Json)}else{@()}
    $Rows=@($Rows|Where-Object Version -ne $Version)
    $Rows+=[pscustomobject]@{Version=$Version;Hash=$Hash;StockHash=$StockHash;Magisk='30.7'}
    $Rows|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $IndexFile -Encoding UTF8
}

function Ensure-KpaStockBoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RootDir,[Parameter(Mandatory)]$Profile,[Parameter(Mandatory)][string]$Build,[Parameter(Mandatory)][string]$Serial)
    if($Build -notmatch $Profile.BuildPattern){throw "Unsupported firmware build: $Build"}
    $TargetDate=$Matches[1]; $TargetShort=$TargetDate.Substring(4); $TargetFile=Get-KpaDeviceImagePath $Profile "boot_${TargetShort}_stock.img"
    $StateRoot=Join-Path $Profile.ProfileRoot 'ota'; New-Item -ItemType Directory -Force -Path $StateRoot|Out-Null
    $Catalog=@($Profile.Firmware | ForEach-Object {[pscustomobject]@{Date=$_.Date;Short=$_.Short;Server=$_.Server;Hash=$_.StockHash}})
    $IndexFile=Join-Path $StateRoot 'generated-stock-boots.json'
    if(Test-Path $IndexFile){$Generated=@(Get-Content $IndexFile -Raw|ConvertFrom-Json);$Catalog+=@($Generated)}else{$Generated=@()}
    $Known=$Catalog|Where-Object Date -eq $TargetDate|Select-Object -First 1
    if(Test-Path -LiteralPath $TargetFile -PathType Leaf){
        $Hash=(Get-FileHash $TargetFile -Algorithm SHA256).Hash
        if((Get-Item $TargetFile).Length -ne $Profile.BootSize){throw "Existing stock boot has invalid size: $TargetFile"}
        if($Known -and $Hash -ine $Known.Hash){throw "Existing stock boot SHA256 mismatch: $TargetFile"}
        return [pscustomobject]@{Path=$TargetFile;Hash=$Hash;Version=$TargetShort;Generated=$false}
    }
    if($Serial -notmatch $Profile.SerialPattern){throw 'Connected device identity is invalid.'}
    $Dumper=Join-Path $RootDir 'tools\ota\payload_dumper.exe'
    if(-not(Test-Path $Dumper)){throw 'payload_dumper.exe is missing.'}
    if((Get-FileHash $Dumper -Algorithm SHA256).Hash -ine $script:KpaPayloadDumperHash){throw 'payload_dumper.exe SHA256 mismatch.'}
    $Source=$Catalog|Where-Object{[string]$_.Date -lt $TargetDate -and (Test-Path (Get-KpaDeviceImagePath $Profile "boot_$($_.Short)_stock.img"))}|Sort-Object Date -Descending|Select-Object -First 1
    if(-not $Source){throw 'No earlier verified stock boot is available for OTA reconstruction.'}
    $CurrentDate=[string]$Source.Date; $CurrentShort=[string]$Source.Short; $CurrentServer=[string]$Source.Server; $CurrentBoot=Get-KpaDeviceImagePath $Profile "boot_${CurrentShort}_stock.img"
    if((Get-Item $CurrentBoot).Length -ne $Profile.BootSize -or (Get-FileHash $CurrentBoot -Algorithm SHA256).Hash -ine [string]$Source.Hash){throw "Source stock boot verification failed: $CurrentBoot"}
    $Cache=Join-Path $StateRoot 'cache'; New-Item -ItemType Directory -Force -Path $Cache|Out-Null
    Write-Host (Get-KpaText 'Missing stock boot; querying the official OTA chain.' '缺少原版 boot，正在查询官方 OTA 增量链。') -ForegroundColor Yellow
    for($Step=0;$Step -lt 12 -and $CurrentDate -lt $TargetDate;$Step++){
        $Offer=Get-KpaOtaOffer $CurrentServer $Serial
        if(-not $Offer){throw "No official incremental OTA was returned for $CurrentServer"}
        $NextServer=[string]$Offer.versionName
        if($NextServer -notmatch $Profile.Ota.TargetPattern){throw "Unexpected OTA target version: $NextServer"}
        $NextDate=$Matches[1]; if($NextDate -gt $TargetDate){throw "OTA chain skipped beyond installed firmware: $NextServer"}
        $NextShort=$NextDate.Substring(4); $NextBoot=Get-KpaDeviceImagePath $Profile "boot_${NextShort}_stock.img"
        if(Test-Path $NextBoot){
            $NextHash=(Get-FileHash $NextBoot -Algorithm SHA256).Hash
            $NextRecord=$Catalog|Where-Object Date -eq $NextDate|Select-Object -First 1
            if((Get-Item $NextBoot).Length -ne $Profile.BootSize -or ($NextRecord -and $NextHash -ine [string]$NextRecord.Hash)){throw "Existing stock boot verification failed: $NextBoot"}
        }
        else {
            $Ota=Get-KpaOtaArchive $Cache $CurrentServer $Offer
            $Work=Join-Path $Cache ('work_'+$CurrentShort+'_'+$NextShort); $SourceDir=Join-Path $Work 'source'; $OutputDir=Join-Path $Work 'output'
            New-Item -ItemType Directory -Force -Path $SourceDir,$OutputDir|Out-Null
            Copy-Item $CurrentBoot (Join-Path $SourceDir 'boot.img') -Force
            $DumperResult=Invoke-KpaNativeCapture { & $Dumper $Ota --source-dir $SourceDir --out $OutputDir --images boot --no-parallel }
            $DumperResult.Output|ForEach-Object{Write-Host $_}
            if($DumperResult.ExitCode -ne 0){throw "OTA boot reconstruction failed: $CurrentServer -> $NextServer"}
            $Built=Join-Path $OutputDir 'boot.img'
            if(-not(Test-Path $Built) -or (Get-Item $Built).Length -ne $Profile.BootSize){throw 'Reconstructed boot image is invalid.'}
            $NextHash=(Get-FileHash $Built -Algorithm SHA256).Hash
            $KnownNext=$Catalog|Where-Object Date -eq $NextDate|Select-Object -First 1
            if($KnownNext -and $NextHash -ine [string]$KnownNext.Hash){throw "Reconstructed stock boot SHA256 mismatch: $NextServer"}
            Copy-Item $Built $NextBoot
            $Generated+= [pscustomobject]@{Date=$NextDate;Short=$NextShort;Server=$NextServer;Hash=$NextHash}
            Save-KpaGeneratedIndex $StateRoot $Generated
        }
        $CurrentDate=$NextDate;$CurrentShort=$NextShort;$CurrentServer=$NextServer;$CurrentBoot=$NextBoot
    }
    if($CurrentDate -ne $TargetDate -or -not(Test-Path $TargetFile)){throw "Could not reconstruct stock boot for $Build"}
    return [pscustomobject]@{Path=$TargetFile;Hash=(Get-FileHash $TargetFile -Algorithm SHA256).Hash;Version=$TargetShort;Generated=$true}
}

function Ensure-KpaPatchedBoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RootDir,[Parameter(Mandatory)]$Stock,[Parameter(Mandatory)][string]$Adb)
    if ([string]$Stock.Version -notmatch '^(?:[0-9]{4}|[0-9]{8})$') { throw 'Invalid firmware version identifier.' }
    $Output=Get-KpaDeviceImagePath $script:KpaDeviceProfile "boot_$($Stock.Version)_magisk_30.7.img"
    $StateRoot=Join-Path $script:KpaDeviceProfile.ProfileRoot 'ota'; New-Item -ItemType Directory -Force -Path $StateRoot|Out-Null
    if(Test-Path $Output){
        if((Get-Item $Output).Length -ne 33554432){throw "Existing patched boot has invalid size: $Output"}
        # 优先校验随包镜像的固定哈希，未知版本再使用生成记录。
        # Prefer the bundled catalog hash; use runtime records for future builds.
        $CatalogEntry=$script:KpaDeviceProfile.Firmware|Where-Object Short -eq $Stock.Version|Select-Object -First 1
        $RecordedHash=Get-KpaRecordedPatchedHash $StateRoot $Stock.Version
        if($CatalogEntry -and $CatalogEntry.PatchedHash){$RecordedHash=[string]$CatalogEntry.PatchedHash}
        if($RecordedHash -and (Get-FileHash $Output -Algorithm SHA256).Hash -ine $RecordedHash){throw "Existing patched boot SHA256 mismatch: $Output"}
        return $Output
    }
    $Apk=Join-Path $RootDir 'packages\Magisk-v30.7.apk'; $Work=Join-Path $StateRoot ('cache\magisk_'+$Stock.Version)
    $CacheRoot=[IO.Path]::GetFullPath((Join-Path $StateRoot 'cache'))+[IO.Path]::DirectorySeparatorChar
    $Work=[IO.Path]::GetFullPath($Work)
    if(-not $Work.StartsWith($CacheRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe patch workspace.'}
    if(Test-Path -LiteralPath $Work){Remove-Item -LiteralPath $Work -Recurse -Force}
    New-Item -ItemType Directory -Force -Path $Work|Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip=[IO.Compression.ZipFile]::OpenRead($Apk)
    try {
        $Map=@{'assets/boot_patch.sh'='boot_patch.sh';'assets/util_functions.sh'='util_functions.sh';'assets/stub.apk'='stub.apk';'lib/arm64-v8a/libbusybox.so'='busybox';'lib/arm64-v8a/libinit-ld.so'='init-ld';'lib/arm64-v8a/libmagisk.so'='magisk';'lib/arm64-v8a/libmagiskboot.so'='magiskboot';'lib/arm64-v8a/libmagiskinit.so'='magiskinit'}
        foreach($Pair in $Map.GetEnumerator()){ $Entry=$Zip.GetEntry($Pair.Key);if(-not $Entry){throw "Missing Magisk component: $($Pair.Key)"};[IO.Compression.ZipFileExtensions]::ExtractToFile($Entry,(Join-Path $Work $Pair.Value),$true) }
    } finally {$Zip.Dispose()}
    Copy-Item $Stock.Path (Join-Path $Work 'boot.img')
    Copy-Item -LiteralPath (Join-Path $RootDir 'scripts\patch_boot.sh') -Destination (Join-Path $Work 'patch_boot.sh')
    & $Adb shell rm -rf /data/local/tmp/kpa-auto-patch|Out-Null
    if($LASTEXITCODE -ne 0){throw 'Failed to clean the device patch workspace.'}
    & $Adb shell mkdir -p /data/local/tmp/kpa-auto-patch|Out-Null
    if($LASTEXITCODE -ne 0){throw 'Failed to create the device patch workspace.'}
    & $Adb push "$Work\." /data/local/tmp/kpa-auto-patch/|Out-Null
    if($LASTEXITCODE -ne 0){throw 'Failed to transfer the boot patch files.'}
    $PatchResult=Invoke-KpaNativeCapture { & $Adb shell sh /data/local/tmp/kpa-auto-patch/patch_boot.sh }
    $PatchResult.Output|ForEach-Object{Write-Host $_}
    if($PatchResult.ExitCode -ne 0){throw 'Magisk boot patch failed.'}
    & $Adb pull /data/local/tmp/kpa-auto-patch/new-boot.img $Output|Out-Null
    if($LASTEXITCODE -ne 0){throw 'Failed to retrieve the patched boot image.'}
    & $Adb shell rm -rf /data/local/tmp/kpa-auto-patch|Out-Null
    if(-not(Test-Path $Output) -or (Get-Item $Output).Length -ne 33554432){throw 'Patched boot output is invalid.'}
    $PatchedHash=(Get-FileHash $Output -Algorithm SHA256).Hash
    if($PatchedHash -ieq $Stock.Hash){throw 'Patched boot is unchanged.'}
    Save-KpaPatchedHash $StateRoot $Stock.Version $PatchedHash $Stock.Hash
    return $Output
}
