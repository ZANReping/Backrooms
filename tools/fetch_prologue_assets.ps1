param(
    [string]$Destination = (Join-Path $PSScriptRoot "..\assets\third_party\polyhaven")
)

$ErrorActionPreference = "Stop"
$apiRoot = "https://api.polyhaven.com"
$licenseUrl = "https://polyhaven.com/license"

$models = @(
    "metal_office_desk",
    "plastic_monobloc_chair_01",
    "desk_lamp_arm_01"
)

$textures = @(
    @{ Id = "wood_floor"; ColorKey = "Diffuse"; ColorResolution = "2k" },
    @{ Id = "white_plaster_02"; ColorKey = "Diffuse"; ColorResolution = "2k" },
    # This asset has three color variants and no API key named Diffuse.
    @{ Id = "fabric_pattern_07"; ColorKey = "col_1"; ColorResolution = "1k" },
    @{ Id = "brown_leather"; ColorKey = "Diffuse"; ColorResolution = "1k" },
    @{ Id = "decrepit_wallpaper"; ColorKey = "Diffuse"; ColorResolution = "2k" },
    @{ Id = "dirty_carpet"; ColorKey = "Diffuse"; ColorResolution = "2k" },
    @{ Id = "terrazzo_tiles"; ColorKey = "Diffuse"; ColorResolution = "2k" }
)

function Get-PropertyValue {
    param([object]$Object, [string]$Name)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw "API response does not contain key '$Name'."
    }
    return $property.Value
}

function Save-VerifiedFile {
    param(
        [string]$Url,
        [string]$ExpectedMd5,
        [long]$ExpectedSize,
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temporary = "$Path.download"
    Invoke-WebRequest -Uri $Url -OutFile $temporary -UseBasicParsing

    $actualSize = (Get-Item -LiteralPath $temporary).Length
    if ($actualSize -ne $ExpectedSize) {
        Remove-Item -LiteralPath $temporary -Force
        throw "Size mismatch for $Url (expected $ExpectedSize, got $actualSize)."
    }

    $actualMd5 = (Get-FileHash -LiteralPath $temporary -Algorithm MD5).Hash.ToLowerInvariant()
    if ($actualMd5 -ne $ExpectedMd5.ToLowerInvariant()) {
        Remove-Item -LiteralPath $temporary -Force
        throw "MD5 mismatch for $Url (expected $ExpectedMd5, got $actualMd5)."
    }

    Move-Item -LiteralPath $temporary -Destination $Path -Force
    return [ordered]@{
        path = $Path.Replace((Resolve-Path (Join-Path $PSScriptRoot "..")).Path + "\", "").Replace("\", "/")
        url = $Url
        bytes = $actualSize
        api_md5 = $actualMd5
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Get-Attribution {
    param([object]$Info)
    $entries = @()
    foreach ($property in $Info.authors.PSObject.Properties) {
        $entries += [ordered]@{ name = $property.Name; role = [string]$property.Value }
    }
    return $entries
}

$destinationRoot = [System.IO.Path]::GetFullPath($Destination)
New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null

foreach ($id in $models) {
    $files = Invoke-RestMethod -Uri "$apiRoot/files/$id"
    $info = Invoke-RestMethod -Uri "$apiRoot/info/$id"
    $gltfEntry = (Get-PropertyValue (Get-PropertyValue $files "gltf") "1k").gltf
    $assetRoot = Join-Path $destinationRoot "models\$id"
    $downloads = @()

    $gltfName = [System.IO.Path]::GetFileName([uri]$gltfEntry.url)
    $downloads += Save-VerifiedFile -Url $gltfEntry.url -ExpectedMd5 $gltfEntry.md5 -ExpectedSize $gltfEntry.size -Path (Join-Path $assetRoot $gltfName)
    foreach ($dependency in $gltfEntry.include.PSObject.Properties) {
        $entry = $dependency.Value
        $downloads += Save-VerifiedFile -Url $entry.url -ExpectedMd5 $entry.md5 -ExpectedSize $entry.size -Path (Join-Path $assetRoot $dependency.Name)
    }

    $manifest = [ordered]@{
        schema = 1
        id = $id
        name = $info.name
        kind = "model"
        status = "DOWNLOADED_UNVERIFIED"
        source_page = "https://polyhaven.com/a/$id"
        api_files = "$apiRoot/files/$id"
        authors = Get-Attribution $info
        published_utc = if ($info.date_published) { [DateTimeOffset]::FromUnixTimeSeconds([long]$info.date_published).UtcDateTime.ToString("yyyy-MM-dd") } else { $null }
        retrieved_utc = "2026-09-07"
        license = "CC0 1.0 Universal"
        license_url = $licenseUrl
        attribution_required = $false
        resolution = "1k"
        root_origin_and_coordinates = "UNVERIFIED_IN_GODOT"
        files = $downloads
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $assetRoot "manifest.json") -Encoding utf8
}

foreach ($spec in $textures) {
    $id = $spec.Id
    $files = Invoke-RestMethod -Uri "$apiRoot/files/$id"
    $info = Invoke-RestMethod -Uri "$apiRoot/info/$id"
    $assetRoot = Join-Path $destinationRoot "textures\$id"
    $downloads = @()

    $selections = @(
        @{ Key = $spec.ColorKey; Resolution = $spec.ColorResolution },
        @{ Key = "nor_gl"; Resolution = "1k" },
        @{ Key = "arm"; Resolution = "1k" }
    )
    foreach ($selection in $selections) {
        $map = Get-PropertyValue $files $selection.Key
        $entry = (Get-PropertyValue $map $selection.Resolution).jpg
        if ($null -eq $entry) {
            throw "$id/$($selection.Key)/$($selection.Resolution) has no JPG entry."
        }
        $name = [System.IO.Path]::GetFileName([uri]$entry.url)
        $downloads += Save-VerifiedFile -Url $entry.url -ExpectedMd5 $entry.md5 -ExpectedSize $entry.size -Path (Join-Path $assetRoot $name)
    }

    $manifest = [ordered]@{
        schema = 1
        id = $id
        name = $info.name
        kind = "texture"
        status = "DOWNLOADED_UNVERIFIED"
        source_page = "https://polyhaven.com/a/$id"
        api_files = "$apiRoot/files/$id"
        authors = Get-Attribution $info
        published_utc = if ($info.date_published) { [DateTimeOffset]::FromUnixTimeSeconds([long]$info.date_published).UtcDateTime.ToString("yyyy-MM-dd") } else { $null }
        retrieved_utc = "2026-09-07"
        license = "CC0 1.0 Universal"
        license_url = $licenseUrl
        attribution_required = $false
        maps = [ordered]@{
            color = [ordered]@{ api_key = $spec.ColorKey; resolution = $spec.ColorResolution; format = "jpg" }
            normal = [ordered]@{ api_key = "nor_gl"; resolution = "1k"; format = "jpg" }
            packed_arm = [ordered]@{ api_key = "arm"; resolution = "1k"; format = "jpg" }
        }
        files = $downloads
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $assetRoot "manifest.json") -Encoding utf8
}

Write-Output "Downloaded and verified Poly Haven assets in $destinationRoot"
Write-Output "Powered by Poly Haven: https://polyhaven.com"
