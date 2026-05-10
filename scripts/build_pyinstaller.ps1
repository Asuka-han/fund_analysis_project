<#
Build one-file executables for the fund analysis toolkit.

Usage examples (from repo root or this script's folder):
  pwsh scripts/build_pyinstaller.ps1
  pwsh scripts/build_pyinstaller.ps1 -NoConsole
  pwsh scripts/build_pyinstaller.ps1 -Clean -PyInstaller "python -m PyInstaller"
  
Alternative Python version (requires pyinstaller package installed):
  python scripts/build_pyinstaller.py
  python scripts/build_pyinstaller.py --clean
#>

param(
    [string]$PyInstaller = "pyinstaller",
    [switch]$Clean,
    [switch]$NoConsole
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Work around PyInstaller conda metadata bug (KeyError: 'depends')
$env:PYINSTALLER_IGNORE_CONDA = "1"

if ($Clean) {
    Write-Host "Cleaning dist/build/spec artifacts..."
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue dist, build, *.spec
}

$commonArgs = @(
    "--onefile",
    "--clean",
    "--noconfirm",
    "--workpath", "build/pyinstaller",
    "--distpath", "dist",
    "--collect-all", "matplotlib",
    "--collect-all", "plotly",
    "--collect-all", "pandas",
    "--collect-all", "numpy",
    "--collect-all", "scipy",
    "--collect-submodules", "akshare",
    "--hidden-import", "pytz",
    "--hidden-import", "dateutil.tz",
    "--copy-metadata", "pandas",
    "--copy-metadata", "numpy",
    "--copy-metadata", "scipy",
    "--copy-metadata", "plotly",
    "--copy-metadata", "matplotlib"
)

# 补齐 Windows + conda 下 oneMKL/OpenMP 运行时 DLL
$libBinCandidates = @()
if ($env:CONDA_PREFIX) {
    $libBinCandidates += (Join-Path $env:CONDA_PREFIX "Library\bin")
}
$libBinCandidates += (Join-Path $env:VIRTUAL_ENV "Library\bin")

$patterns = @(
    "mkl*.dll",           # 匹配所有 mkl 开头的 dll
    "libiomp5md.dll",     # Intel OpenMP 运行时
    "tbb*.dll",           # 可选，Intel TBB
    "svml_dispmd.dll"     # Intel SVML
)

$seen = @{}
foreach ($libBin in $libBinCandidates) {
    if (-not $libBin -or -not (Test-Path $libBin)) { continue }
    foreach ($pattern in $patterns) {
        Get-ChildItem $libBin -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $seen.ContainsKey($_.FullName)) {
                $seen[$_.FullName] = $true
                $commonArgs += "--add-binary"
                $commonArgs += ("{0};." -f $_.FullName)
            }
        }
    }
}

if ($NoConsole) {
    $commonArgs += "--noconsole"
}

$scripts = @(
    @{ Name = "fund_main"; Entry = "main.py" },
    @{ Name = "excel_analysis"; Entry = "scripts/analysis_from_excel.py" },
    @{ Name = "import_excel"; Entry = "scripts/import_excel_to_db.py" },
    @{ Name = "analysis_from_db"; Entry = "scripts/run_analysis_from_db.py" },
    @{ Name = "update_db"; Entry = "scripts/update_db.py" }
)

foreach ($s in $scripts) {
    Write-Host "Building $($s.Name) from $($s.Entry)..."
    & $PyInstaller @commonArgs "--name" $s.Name $s.Entry
}

Write-Host "Done. Binaries in dist/."