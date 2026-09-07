param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$Graphical,
    [switch]$UserStorage
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$resultDirectory = Join-Path $projectRoot 'artifacts/verification'
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$Arguments)
    $logPath = Join-Path $resultDirectory ($Name + '.log')
    $previousPreferencesPath = $env:BACKROOMS_PREFERENCES_PATH
    $env:BACKROOMS_PREFERENCES_PATH = Join-Path $resultDirectory ('preferences_' + [guid]::NewGuid().ToString('N') + '.cfg')
    try { & $enginePath --path $projectRoot --log-file $logPath @Arguments }
    finally { $env:BACKROOMS_PREFERENCES_PATH = $previousPreferencesPath }
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE. See $logPath" }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($log -match 'SCRIPT ERROR:|FAIL:|ERROR:') { throw "$Name reported an error. See $logPath" }
    Write-Output "VERIFIED: $Name"
}

Invoke-GodotCheck -Name 'import' -Arguments @('--headless', '--editor', '--import', '--quit')
foreach ($test in @('stats', 'inventory', 'phone', 'save', 'player_audio')) {
    Invoke-GodotCheck -Name $test -Arguments @('--headless', '--script', "res://tests/test_$test.gd")
}
Invoke-GodotCheck -Name 'inventory_ui' -Arguments @('--headless', '--fixed-fps', '60', 'res://tests/test_inventory_ui.tscn')
Invoke-GodotCheck -Name 'runtime_headless' -Arguments @('--headless', '--fixed-fps', '60', 'res://tests/test_runtime.tscn')
if ($Graphical) {
    $runtimeArguments = @('--fixed-fps', '60', 'res://tests/test_runtime.tscn')
    if ($UserStorage) { $runtimeArguments += @('--', '--user-storage') }
    Invoke-GodotCheck -Name 'runtime_graphical' -Arguments $runtimeArguments
    Invoke-GodotCheck -Name 'inventory_ui_minimum' -Arguments @('--resolution', '960x540', '--fixed-fps', '60', 'res://tests/test_inventory_ui.tscn')
    Invoke-GodotCheck -Name 'ui_layout' -Arguments @('--fixed-fps', '60', 'res://tests/test_ui_layout.tscn')
}
Write-Output 'MILESTONE_1_VERIFICATION_PASSED'
