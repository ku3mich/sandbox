Set-PSReadLineOption -EditMode Emacs -DingTone 9000 -DingDuration 15

Write-Host "* importing posh-git"
Import-Module posh-git
Write-Host "* importing AWS.Tools.Common"
Import-Module AWS.Tools.Common
Import-Module AWS.Tools.EC2
Import-Module AWS.Tools.ECS
Import-Module AWS.Tools.S3

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Write-Host "* importing Chocolatey"
    Import-Module "$ChocolateyProfile"
}

. $PSScriptRoot/dotnet.ps1

. $PSScriptRoot/sln.ps1
. $PSScriptRoot/format-xml.ps1

function Start-Pwsh {
    param(
        [parameter(mandatory=$true, position=0)]
        [string]$file,
        [parameter(mandatory=$false, position=1, ValueFromRemainingArguments=$true)]
        $remaining
    )

    Start-Process pwsh -ArgumentList $("-f", $file, $remaining | ForEach-Object { $_ })
}

Set-Alias -Name pws -Value Start-Pwsh

. $PSScriptRoot/render-api-setup.ps1
#. $PSScriptRoot/render-api.ps1