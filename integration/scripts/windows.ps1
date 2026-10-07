# The Windows path end to end. Reaching this script at all is most of the
# assertion: it arrived over WinRM, as the account the guest agent created and
# whose password the driver decrypted off the serial port.
$ErrorActionPreference = "Stop"

function Get-GceMetadata($Path) {
  Invoke-RestMethod -Headers @{ "Metadata-Flavor" = "Google" } `
    -Uri "http://metadata.google.internal/computeMetadata/v1/$Path"
}

function Fail($Message) {
  Write-Error "FAIL: $Message"
  exit 1
}

$name = Get-GceMetadata "instance/name"
Write-Host "instance=$name user=$env:USERNAME"

if ((Get-GceMetadata "instance/attributes/created-by") -ne "test-kitchen") {
  Fail "created-by metadata is not test-kitchen"
}

# The driver adds this for WinRM transports only. It is what opens 5985 inside
# the guest -- the VPC firewall rule has to be created separately.
$startup = Get-GceMetadata "instance/attributes/windows-startup-script-ps1"
if ($startup -notmatch "localport=5985") {
  Fail "the WinRM startup script metadata was not set"
}

# Google's images ship the built-in Administrator disabled and the agent will
# not enable it, so the driver must be connecting as something else.
if ($env:USERNAME -ieq "administrator") {
  Fail "connected as the built-in Administrator, which should never work"
}

$admins = Get-LocalGroupMember -Group "Administrators" | ForEach-Object { $_.Name }
Write-Host "Administrators: $($admins -join ', ')"
if (-not ($admins -match [regex]::Escape($env:USERNAME))) {
  Fail "$env:USERNAME is not in the local Administrators group"
}

# The password the driver decrypted is what authenticated this session.
$listeners = winrm enumerate winrm/config/listener
if ($listeners -notmatch "5985") {
  Fail "no WinRM listener on 5985"
}

Write-Host "OK: windows"
