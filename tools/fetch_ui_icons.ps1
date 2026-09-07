param(
    [string]$OutputDirectory = "assets/ui/icons/lucide"
)

$ErrorActionPreference = "Stop"
$Package = "lucide-static@1.41.0"
$ExpectedTarballSha256 = "d10f583e2076986ddcf79def168e6ce1e64f742fa06b6014347c59fa581aa6cb"
$Icons = @(
    "message-circle", "map", "globe", "phone", "camera", "clock",
    "briefcase-business", "house", "search", "arrow-left", "x", "check",
    "chevron-right", "settings", "heart", "zap", "droplets", "utensils",
    "brain", "moon", "weight", "battery", "wifi", "wifi-off", "shirt",
    "user", "footprints", "backpack", "hand", "gem", "scan-face",
    "sliders-horizontal", "rotate-cw", "image", "plus", "send", "trash-2",
    "download", "smartphone"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Destination = Join-Path $ProjectRoot $OutputDirectory
$Work = Join-Path $ProjectRoot ".tmp_ui_icons"
$Cache = Join-Path $Work "npm-cache"
New-Item -ItemType Directory -Force -Path $Work, $Cache, $Destination | Out-Null

Push-Location $Work
try {
    $Tarball = (& npm pack $Package --ignore-scripts --cache $Cache --silent | Select-Object -Last 1).Trim()
    if (-not $Tarball) { throw "npm pack did not return a tarball name" }
    $ActualTarballSha256 = (Get-FileHash $Tarball -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($ActualTarballSha256 -ne $ExpectedTarballSha256) {
        throw "Tarball SHA-256 mismatch: expected $ExpectedTarballSha256, got $ActualTarballSha256"
    }
    tar -xf $Tarball

    foreach ($Icon in $Icons) {
        $Source = Join-Path $Work "package/icons/$Icon.svg"
        if (-not (Test-Path $Source)) { throw "Pinned package is missing $Icon.svg" }
        # Godot tints white textures predictably with TextureRect.self_modulate.
        $Svg = (Get-Content -Raw $Source).Replace('stroke="currentColor"', 'stroke="#ffffff"')
        [IO.File]::WriteAllText((Join-Path $Destination "$Icon.svg"), $Svg, [Text.UTF8Encoding]::new($false))
    }
    Copy-Item (Join-Path $Work "package/LICENSE") (Join-Path $Destination "LICENSE") -Force
    Get-ChildItem "$Destination/*.svg" | Sort-Object Name | ForEach-Object {
        "{0}  {1}" -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
    } | Set-Content -Encoding utf8NoBOM (Join-Path $Destination "SHA256SUMS")
}
finally {
    Pop-Location
    if (Test-Path $Work) {
        $ResolvedWork = (Resolve-Path -LiteralPath $Work).Path
        $ResolvedProject = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $ResolvedWork.StartsWith($ResolvedProject, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove an icon cache outside the project: $ResolvedWork"
        }
        Remove-Item -LiteralPath $ResolvedWork -Recurse -Force
    }
}

Write-Host "Fetched $($Icons.Count) Lucide icons into $Destination"
