param(
    [string]$VerilatorPath = "",
    [string]$MakePath = "",
    [string]$PythonPath = "python3",
    [string[]]$Targets = @("static_check", "event_parser", "event_book", "event_risk", "event_engine", "event_latency")
)

$ErrorActionPreference = "Stop"

function Resolve-Tool {
    param(
        [string]$ExplicitPath,
        [string[]]$Names
    )

    if ($ExplicitPath -ne "") {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        return $resolved.Path
    }

    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            return $cmd.Source
        }
    }

    return ""
}

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$resolvedVerilator = Resolve-Tool -ExplicitPath $VerilatorPath -Names @("verilator", "verilator_bin")
$resolvedMake = Resolve-Tool -ExplicitPath $MakePath -Names @("make", "mingw32-make")
$resolvedPython = Resolve-Tool -ExplicitPath $PythonPath -Names @("python3", "python")

Write-Host "Repository: $repoRoot"
Write-Host "Verilator:  $resolvedVerilator"
Write-Host "Make:       $resolvedMake"
Write-Host "Python:     $resolvedPython"

if ($resolvedPython -eq "") {
    throw "Python was not found. Pass -PythonPath with an absolute path."
}

& $resolvedPython scripts/check_repo_static.py

if ($resolvedVerilator -eq "") {
    throw "Verilator was not found. Pass -VerilatorPath with an absolute path to verilator.exe or verilator_bin.exe."
}

if ($resolvedMake -eq "") {
    throw "Make was not found. Pass -MakePath with an absolute path to make.exe or mingw32-make.exe."
}

$env:PATH = (Split-Path -Parent $resolvedVerilator) + ";" + (Split-Path -Parent $resolvedMake) + ";" + $env:PATH

foreach ($target in $Targets) {
    Write-Host "Running make $target"
    & $resolvedMake $target "VERILATOR=$resolvedVerilator" "PYTHON=$resolvedPython"
    if ($LASTEXITCODE -ne 0) {
        throw "make $target failed with exit code $LASTEXITCODE"
    }
}

Write-Host "PASS: requested verification targets completed"
