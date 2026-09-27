$script:KpaFotaApi = 'https://fota5p.adups.com/otainter-5.0/fota5'
$script:KpaFotaSign = '50f0c23cbdc67a512562752e48b33828'
$script:KpaPayloadDumperHash = '09EA2F5BCB4424BDEEDAB4FC7983116BDD30661E7D886B1C453FC08C64066848'
$script:KpaKnownStock = @(
    [pscustomobject]@{ Date='20260730'; Short='0730'; Server='BW03_20260730_20260730-1638'; Hash='735E1D3855DC0165762006CDCB1136D3047B8E999A559FBD259B2ADB58A32487' },
    [pscustomobject]@{ Date='20260813'; Short='0813'; Server='BW03_20260813_20260813-1107'; Hash='66919AA93F4D1CE9055F2F08B20034E031E63444C2B77E0D2FA3EB186817A71A' },
    [pscustomobject]@{ Date='20260828'; Short='0828'; Server='BW03_20260828_20260827-2100'; Hash='F25E0D5115E4E382983F9ACB47B3A2B8AEFB8C8C866D5A07BB888E48553D4039' }
)

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
    $Mid=(Get-Date -Format 'yyyyMMddHHmmss')+'Kp'+(Get-Random -Minimum 1000 -Maximum 9999)
    $P=[ordered]@{device_type='pad';connect_type='-2';platform='MTK_7400_12.0';project='ayaneo$7400$12.0_KONKR Pocket Advance_en-US_other';version=$SourceVersion;devicesinfoExt='GT78-VN_ARBOR_GT78-VN_GT78-VN_k85v1$64_ARBOR__';swFingerprint='ARBOR/GT78-VN/GT78-VN:11/RP1A.200720.011/mp1V95182:user/release-keys';sdk_level='31';sdk_release='12';resolution='960#640';mid=$Mid;isNewMid='1';appVersion='5.30.1.237083.006_2025-07-25 10:56';appCode='216';local='en-US';operator='';spn1='';spn2='';sendId='1075259712158';fotaSign=$script:KpaFotaSign;androidId='';fcmId='';agreeType='false';upgradeAgreement='false';isActive='false';imei1=$Serial;imei2='';mac='ff:ff:ff:ff:ff:ff';esn=$Serial}
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
    param([Parameter(Mandatory)][string]$RootDir,[Parameter(Mandatory)][string]$Build,[Parameter(Mandatory)][string]$Serial)
    if($Build -notmatch '^BW03_(\d{8})(?:_|$)'){throw "Unsupported firmware build: $Build"}
    $TargetDate=$Matches[1]; $TargetShort=$TargetDate.Substring(4); $TargetFile=Join-Path $RootDir "boot_${TargetShort}_stock.img"
    $Catalog=@($script:KpaKnownStock)
    $IndexFile=Join-Path $RootDir 'generated-stock-boots.json'
    if(Test-Path $IndexFile){$Generated=@(Get-Content $IndexFile -Raw|ConvertFrom-Json);$Catalog+=@($Generated)}else{$Generated=@()}
    $Known=$Catalog|Where-Object Date -eq $TargetDate|Select-Object -First 1
    if(Test-Path -LiteralPath $TargetFile -PathType Leaf){
        $Hash=(Get-FileHash $TargetFile -Algorithm SHA256).Hash
        if((Get-Item $TargetFile).Length -ne 33554432){throw "Existing stock boot has invalid size: $TargetFile"}
        if($Known -and $Hash -ine $Known.Hash){throw "Existing stock boot SHA256 mismatch: $TargetFile"}
        return [pscustomobject]@{Path=$TargetFile;Hash=$Hash;Version=$TargetShort;Generated=$false}
    }
    if($Serial -notmatch '^BW03[A-Z0-9]+$'){throw 'Connected device identity is invalid.'}
    $Dumper=Join-Path $RootDir 'tools\payload_dumper.exe'
    if(-not(Test-Path $Dumper)){throw 'payload_dumper.exe is missing.'}
    if((Get-FileHash $Dumper -Algorithm SHA256).Hash -ine $script:KpaPayloadDumperHash){throw 'payload_dumper.exe SHA256 mismatch.'}
    $Source=$Catalog|Where-Object{[string]$_.Date -lt $TargetDate -and (Test-Path (Join-Path $RootDir "boot_$($_.Short)_stock.img"))}|Sort-Object Date -Descending|Select-Object -First 1
    if(-not $Source){throw 'No earlier verified stock boot is available for OTA reconstruction.'}
    $CurrentDate=[string]$Source.Date; $CurrentShort=[string]$Source.Short; $CurrentServer=[string]$Source.Server; $CurrentBoot=Join-Path $RootDir "boot_${CurrentShort}_stock.img"
    if((Get-Item $CurrentBoot).Length -ne 33554432 -or (Get-FileHash $CurrentBoot -Algorithm SHA256).Hash -ine [string]$Source.Hash){throw "Source stock boot verification failed: $CurrentBoot"}
    $Cache=Join-Path $RootDir 'ota-cache'; New-Item -ItemType Directory -Force -Path $Cache|Out-Null
    Write-Host (Get-KpaText 'Missing stock boot; querying the official OTA chain.' '缺少原版 boot，正在查询官方 OTA 增量链。') -ForegroundColor Yellow
    for($Step=0;$Step -lt 12 -and $CurrentDate -lt $TargetDate;$Step++){
        $Offer=Get-KpaOtaOffer $CurrentServer $Serial
        if(-not $Offer){throw "No official incremental OTA was returned for $CurrentServer"}
        $NextServer=[string]$Offer.versionName
        if($NextServer -notmatch '^BW03_(\d{8})_'){throw "Unexpected OTA target version: $NextServer"}
        $NextDate=$Matches[1]; if($NextDate -gt $TargetDate){throw "OTA chain skipped beyond installed firmware: $NextServer"}
        $NextShort=$NextDate.Substring(4); $NextBoot=Join-Path $RootDir "boot_${NextShort}_stock.img"
        if(Test-Path $NextBoot){
            $NextHash=(Get-FileHash $NextBoot -Algorithm SHA256).Hash
            $NextRecord=$Catalog|Where-Object Date -eq $NextDate|Select-Object -First 1
            if((Get-Item $NextBoot).Length -ne 33554432 -or ($NextRecord -and $NextHash -ine [string]$NextRecord.Hash)){throw "Existing stock boot verification failed: $NextBoot"}
        }
        else {
            $Ota=Get-KpaOtaArchive $Cache $CurrentServer $Offer
            $Work=Join-Path $Cache ('work_'+$CurrentShort+'_'+$NextShort); $SourceDir=Join-Path $Work 'source'; $OutputDir=Join-Path $Work 'output'
            New-Item -ItemType Directory -Force -Path $SourceDir,$OutputDir|Out-Null
            Copy-Item $CurrentBoot (Join-Path $SourceDir 'boot.img') -Force
            $DumperOutput=& $Dumper $Ota --source-dir $SourceDir --out $OutputDir --images boot --no-parallel 2>&1
            $DumperExit=$LASTEXITCODE
            $DumperOutput|ForEach-Object{Write-Host $_}
            if($DumperExit -ne 0){throw "OTA boot reconstruction failed: $CurrentServer -> $NextServer"}
            $Built=Join-Path $OutputDir 'boot.img'
            if(-not(Test-Path $Built) -or (Get-Item $Built).Length -ne 33554432){throw 'Reconstructed boot image is invalid.'}
            $NextHash=(Get-FileHash $Built -Algorithm SHA256).Hash
            $KnownNext=$script:KpaKnownStock|Where-Object Date -eq $NextDate|Select-Object -First 1
            if($KnownNext -and $NextHash -ine [string]$KnownNext.Hash){throw "Reconstructed stock boot SHA256 mismatch: $NextServer"}
            Copy-Item $Built $NextBoot
            $Generated+= [pscustomobject]@{Date=$NextDate;Short=$NextShort;Server=$NextServer;Hash=$NextHash}
            Save-KpaGeneratedIndex $RootDir $Generated
        }
        $CurrentDate=$NextDate;$CurrentShort=$NextShort;$CurrentServer=$NextServer;$CurrentBoot=$NextBoot
    }
    if($CurrentDate -ne $TargetDate -or -not(Test-Path $TargetFile)){throw "Could not reconstruct stock boot for $Build"}
    return [pscustomobject]@{Path=$TargetFile;Hash=(Get-FileHash $TargetFile -Algorithm SHA256).Hash;Version=$TargetShort;Generated=$true}
}

function Ensure-KpaPatchedBoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RootDir,[Parameter(Mandatory)]$Stock,[Parameter(Mandatory)][string]$Adb)
    $Output=Join-Path $RootDir "boot_$($Stock.Version)_magisk_30.7.img"
    if(Test-Path $Output){
        if((Get-Item $Output).Length -ne 33554432){throw "Existing patched boot has invalid size: $Output"}
        $RecordedHash=Get-KpaRecordedPatchedHash $RootDir $Stock.Version
        if($RecordedHash -and (Get-FileHash $Output -Algorithm SHA256).Hash -ine $RecordedHash){throw "Existing patched boot SHA256 mismatch: $Output"}
        return $Output
    }
    $Apk=Join-Path $RootDir 'Magisk-v30.7.apk'; $Work=Join-Path $RootDir ('ota-cache\magisk_'+$Stock.Version)
    if(Test-Path $Work){Remove-Item $Work -Recurse -Force};New-Item -ItemType Directory -Force -Path $Work|Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip=[IO.Compression.ZipFile]::OpenRead($Apk)
    try {
        $Map=@{'assets/boot_patch.sh'='boot_patch.sh';'assets/util_functions.sh'='util_functions.sh';'assets/stub.apk'='stub.apk';'lib/arm64-v8a/libbusybox.so'='busybox';'lib/arm64-v8a/libinit-ld.so'='init-ld';'lib/arm64-v8a/libmagisk.so'='magisk';'lib/arm64-v8a/libmagiskboot.so'='magiskboot';'lib/arm64-v8a/libmagiskinit.so'='magiskinit'}
        foreach($Pair in $Map.GetEnumerator()){ $Entry=$Zip.GetEntry($Pair.Key);if(-not $Entry){throw "Missing Magisk component: $($Pair.Key)"};[IO.Compression.ZipFileExtensions]::ExtractToFile($Entry,(Join-Path $Work $Pair.Value),$true) }
    } finally {$Zip.Dispose()}
    Copy-Item $Stock.Path (Join-Path $Work 'boot.img')
    & $Adb shell rm -rf /data/local/tmp/kpa-auto-patch|Out-Null
    & $Adb shell mkdir -p /data/local/tmp/kpa-auto-patch|Out-Null
    & $Adb push "$Work\." /data/local/tmp/kpa-auto-patch/|Out-Null
    $PatchOutput=& $Adb shell "cd /data/local/tmp/kpa-auto-patch && chmod 755 busybox magisk magiskboot magiskinit boot_patch.sh && BOOTMODE=true KEEPVERITY=true KEEPFORCEENCRYPT=true PATCHVBMETAFLAG=false RECOVERYMODE=false LEGACYSAR=false ASH_STANDALONE=1 ./busybox sh ./boot_patch.sh ./boot.img" 2>&1
    $PatchExit=$LASTEXITCODE
    $PatchOutput|ForEach-Object{Write-Host $_}
    if($PatchExit -ne 0){throw 'Magisk boot patch failed.'}
    & $Adb pull /data/local/tmp/kpa-auto-patch/new-boot.img $Output|Out-Null
    & $Adb shell rm -rf /data/local/tmp/kpa-auto-patch|Out-Null
    if(-not(Test-Path $Output) -or (Get-Item $Output).Length -ne 33554432){throw 'Patched boot output is invalid.'}
    $PatchedHash=(Get-FileHash $Output -Algorithm SHA256).Hash
    if($PatchedHash -ieq $Stock.Hash){throw 'Patched boot is unchanged.'}
    Save-KpaPatchedHash $RootDir $Stock.Version $PatchedHash $Stock.Hash
    return $Output
}
