param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$Graphical
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$resultDirectory = Join-Path $projectRoot 'artifacts/verification_m2'
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
foreach ($test in @('prologue_data', 'prologue_save', 'character_generation', 'player_appearance', 'player_audio')) {
    Invoke-GodotCheck -Name $test -Arguments @('--headless', '--script', "res://tests/test_$test.gd")
}
Invoke-GodotCheck -Name 'field_inventory_ui' -Arguments @('--headless', '--fixed-fps', '60', 'res://tests/test_field_inventory_ui.tscn')
foreach ($test in @('inventory_icon_fit', 'ambient_walkers', 'hinged_door', 'creator_navigation', 'hair_alignment', 'hud_components', 'settings_view', 'preferences_runtime', 'prologue_refinements')) {
    Invoke-GodotCheck -Name $test -Arguments @('--headless', '--fixed-fps', '60', "res://tests/test_$test.tscn")
}
Invoke-GodotCheck -Name 'boundaries' -Arguments @('--headless', '--fixed-fps', '60', 'res://tests/test_prologue_boundaries.tscn')
Invoke-GodotCheck -Name 'walk_headless' -Arguments @('--headless', '--fixed-fps', '60', 'res://tests/test_prologue_walk.tscn')
Invoke-GodotCheck -Name 'runtime_headless' -Arguments @('--headless', 'res://tests/test_prologue_runtime.tscn')
if ($Graphical) {
	Invoke-GodotCheck -Name 'field_inventory_graphical' -Arguments @('--resolution', '1280x720', 'res://tests/test_field_inventory_ui.tscn')
	Invoke-GodotCheck -Name 'character_visual' -Arguments @('--resolution', '1280x720', 'res://tests/test_character_visual.tscn')
    Invoke-GodotCheck -Name 'character_pose' -Arguments @('--resolution', '1280x720', 'res://tests/test_character_pose.tscn')
    Invoke-GodotCheck -Name 'prologue_ui_review' -Arguments @('--resolution', '960x540', 'res://tests/test_prologue_ui_review.tscn')
    Invoke-GodotCheck -Name 'handheld_phone' -Arguments @('--resolution', '1280x720', 'res://tests/test_handheld_phone.tscn')
    Invoke-GodotCheck -Name 'hair_graphical' -Arguments @('--resolution', '1280x720', 'res://tests/test_hair_alignment.tscn')
    Invoke-GodotCheck -Name 'preferences_graphical' -Arguments @('--resolution', '1920x1080', 'res://tests/test_preferences_runtime.tscn')
    Invoke-GodotCheck -Name 'refinements_graphical' -Arguments @('--resolution', '1920x1080', 'res://tests/test_prologue_refinements.tscn')
    # Real frame samples without a fixed timestep, with the default 60 FPS/vsync preferences.
    Invoke-GodotCheck -Name 'runtime_graphical_1080p' -Arguments @('--resolution', '1920x1080', 'res://tests/test_prologue_runtime.tscn')
}
Write-Output 'MILESTONE_2_VERIFICATION_PASSED'
