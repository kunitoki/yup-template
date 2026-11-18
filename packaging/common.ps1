# =============================================================================
#  Shared configuration for the Windows packaging scripts (PowerShell mirror of
#  packaging/common.sh).
#
#  The product naming is read straight from the project configuration block in
#  CMakeLists.txt, so CMake stays the single source of truth: renaming a plugin
#  there automatically updates every package.
#  Every value can still be overridden from the environment.
# =============================================================================

$PackagingDir = Split-Path -Parent $PSCommandPath
$ProjectRoot  = (Resolve-Path (Join-Path $PackagingDir "..")).Path
$CMakeLists   = Join-Path $ProjectRoot "CMakeLists.txt"
$CMakeText    = Get-Content $CMakeLists -Raw

# Read a `set (<NAME> "<value>")` entry from the project CMakeLists.txt, letting
# an environment variable of the same name win.
function Get-ProjectValue([string]$Name) {
    $override = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrEmpty($override)) { return $override }

    $match = [regex]::Match($CMakeText, "(?m)^\s*set\s*\(\s*$([regex]::Escape($Name))\s+""([^""]*)""")
    if (-not $match.Success) {
        throw "Could not read '$Name' from $CMakeLists"
    }
    return $match.Groups[1].Value
}

# The internal target name (see PROJECT_NAME in CMakeLists.txt).
$ProjectName = Get-ProjectValue "PROJECT_NAME"

# The user-facing product name (see PRODUCT_NAME in CMakeLists.txt).
$ProductName = Get-ProjectValue "PRODUCT_NAME"

# The vendor / author (see COMPANY_NAME in CMakeLists.txt).
$CompanyName = Get-ProjectValue "COMPANY_NAME"

# The reverse-domain bundle identifier prefix (see BUNDLE_ID in CMakeLists.txt).
$BundleId = Get-ProjectValue "BUNDLE_ID"

# Short descriptive text (see PLUGIN_DESCRIPTION in CMakeLists.txt).
$PluginDescription = Get-ProjectValue "PLUGIN_DESCRIPTION"

# Website / support URL (see PLUGIN_URL in CMakeLists.txt).
$PluginUrl = Get-ProjectValue "PLUGIN_URL"

# Contact e-mail (see PLUGIN_EMAIL in CMakeLists.txt).
$PluginEmail = Get-ProjectValue "PLUGIN_EMAIL"

# Unique Inno Setup AppId (see INSTALLER_GUID in CMakeLists.txt).
$InstallerGuid = Get-ProjectValue "INSTALLER_GUID"

# Version string read from the VERSION file.
$Version = (Get-Content (Join-Path $ProjectRoot "VERSION") -Raw).Trim()

# Output directory for the finished installers.
$DistDir = if ($env:DIST_DIR) { $env:DIST_DIR } else { Join-Path $ProjectRoot "dist" }
