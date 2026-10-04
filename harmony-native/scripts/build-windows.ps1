param(
  [string]$StudioRoot = 'D:\Dev\DevEcoStudio26',
  [ValidateSet('arm64', 'simulator')][string]$Flavor = 'arm64',
  [string]$SimulatorStage = '',
  [Parameter(Mandatory = $true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$env:NODE_HOME = Join-Path $StudioRoot 'tools\node'
$env:JAVA_HOME = Join-Path $StudioRoot 'jbr'
$env:DEVECO_SDK_HOME = Join-Path $StudioRoot 'sdk'
$env:Path = "$env:NODE_HOME;$env:JAVA_HOME\bin;$env:Path"
$node = Join-Path $env:NODE_HOME 'node.exe'
$ohpm = Join-Path $StudioRoot 'tools\ohpm\bin\ohpm.bat'
$hvigor = Join-Path $StudioRoot 'tools\hvigor\bin\hvigorw.bat'
foreach ($tool in @($node, $ohpm, $hvigor)) { if (!(Test-Path -LiteralPath $tool)) { throw "Missing official tool: $tool" } }
if ($Flavor -eq 'simulator') {
  if (!$SimulatorStage) { throw 'Provide a fresh D:\Dev\SaydianHarmonySimulator\... staging path' }
  & $node (Join-Path $PSScriptRoot 'stage-simulator.mjs') $SimulatorStage
  if ($LASTEXITCODE) { throw 'Simulator staging failed' }
  $projectRoot = $SimulatorStage
}
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
Push-Location -LiteralPath $projectRoot
try {
  & $ohpm install --all *> (Join-Path $outputRoot "$Flavor-ohpm.log")
  if ($LASTEXITCODE) { throw 'ohpm install failed' }
  foreach ($mode in @('debug', 'release')) {
    $label = if ($Flavor -eq 'simulator') { 'x86_64-ui' } else { 'arm64' }
    $target = Join-Path $outputRoot "SAYDIAN-Health-0.1.5-10-$label-$mode-unsigned.hap"
    if (Test-Path -LiteralPath $target) { throw "Existing artifact preserved: $target" }
    & $hvigor --mode module -p product=default -p module=entry@default -p "buildMode=$mode" assembleHap --no-daemon *> (Join-Path $outputRoot "$label-$mode.log")
    if ($LASTEXITCODE) { throw "Build failed: $label $mode" }
    Copy-Item -LiteralPath 'entry\build\default\outputs\default\entry-default-unsigned.hap' -Destination $target
    Get-FileHash -Algorithm SHA256 -LiteralPath $target
  }
} finally { Pop-Location }
