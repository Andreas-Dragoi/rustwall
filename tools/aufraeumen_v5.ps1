# Entfernt die 29 alten WAV-Klänge, die in Version 5 zu OGG wurden (einmal ausführen, dann in GitHub Desktop committen).
# Ausführen: Rechtsklick → „Mit PowerShell ausführen“, oder in PowerShell im Ordner rustwall:  powershell -ExecutionPolicy Bypass -File tools\aufraeumen_v5.ps1
$root = Split-Path -Parent $PSScriptRoot
$files = @(
  "audio\sfx\amb_birds.wav",
  "audio\sfx\amb_coast.wav",
  "audio\sfx\amb_crater.wav",
  "audio\sfx\amb_crickets.wav",
  "audio\sfx\amb_desert.wav",
  "audio\sfx\amb_forest.wav",
  "audio\sfx\amb_meadow.wav",
  "audio\sfx\amb_rain.wav",
  "audio\sfx\amb_snow.wav",
  "audio\sfx\amb_swamp.wav",
  "audio\sfx\amb_waves.wav",
  "audio\sfx\amb_wind_trees.wav",
  "audio\sfx\boss_defeat.wav",
  "audio\sfx\dusk_bell.wav",
  "audio\sfx\extract_success.wav",
  "audio\sfx\flood_alarm.wav",
  "audio\sfx\flood_horn.wav",
  "audio\sfx\hero_unlock.wav",
  "audio\sfx\level_up.wav",
  "audio\sfx\lose.wav",
  "audio\sfx\raid_horn.wav",
  "audio\sfx\rescue_cheer.wav",
  "audio\sfx\shield_hum.wav",
  "audio\sfx\siege_horn.wav",
  "audio\sfx\sk_berta.wav",
  "audio\sfx\sk_festival.wav",
  "audio\sfx\tree_fall.wav",
  "audio\sfx\win.wav",
  "audio\sfx\zentrale_down.wav"
)
foreach ($f in $files) {
  foreach ($p in @("$root\$f", "$root\$f.import")) {
    if (Test-Path $p) { Remove-Item $p; Write-Host "entfernt: $p" }
  }
}
Write-Host "Fertig."
