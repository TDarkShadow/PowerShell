<#=============================================================================================
Script by    : Leo Nguyen
Website      : www.bonguides.com
Telegram     : https://t.me/bonguides
Discord      : https://discord.gg/fUVjuqexJg
YouTube      : https://www.youtube.com/@BonGuides
Description  : Export Microsoft 365 users' last logon time report using PowerShell

Script Highlights:
~~~~~~~~~~~~~~~~~
#. Single script allows you to generate last login reports.
============================================================================================#>


if (-not([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You need to have Administrator rights to run this script!`nPlease re-run this script as an Administrator in an elevated powershell prompt!"
    # Start-Process -Verb runas -FilePath powershell.exe -ArgumentList "irm  | iex"
    break
}

Param
(
    [switch]$InstallMainBasic,
    [switch]$InstallMainAll,
    [switch]$InstallBetaBasic,
    [switch]$InstallBetaAll
)

# Required running with elevated right.
if (-not([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You need to have Administrator rights to run this script!`nPlease re-run this script as an Administrator in an elevated powershell prompt!"
    break
 }

Function InstallDeps {
# Configure Execution Policy
if ((Get-ExecutionPolicy) -notmatch "RemoteSigned") {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
}

# Update the PowerShellGet if needed.
$PSGetCurrentVersion = (Get-PackageProvider -Name 'PowerShellGet').Version
$PSGetLatestVersion = (Find-Module PowerShellGet).Version
if ($PSGetCurrentVersion -lt $PSGetLatestVersion) {
    Write-Host "Updating PowerShellGet Module from $PSGetCurrentVersion to $PSGetLatestVersion..."
    Install-Module -Name 'PowerShellGet' -Force
}

# We're installing from the PowerShell Gallery so make sure that it's trusted.
$InstallationPolicy = (Get-PSRepository -Name PSGallery).InstallationPolicy
if ($InstallationPolicy -match "Untrusted") {
   Write-host "Configuring the PowerShell Gallery Repository..."
   Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
}

# Update the NuGet Provider if needed.
$nuGetPath = "C:\Program Files\PackageManagement\ProviderAssemblies\nuget\*\Microsoft.PackageManagement.NuGetProvider.dll"
$testPath = Test-Path -Path $nuGetPath
if ($testPath -match 'false') {
    Write-Host "Installing NuGet Provider..."
    Install-PackageProvider -Name NuGet -Force | Out-Null
}
}

Function InstallMainAll {
$MsGraphModule =  Get-Module Microsoft.Graph -ListAvailable
if($null -eq $MsGraphModule)
{ 
    Write-host "Important: Microsoft Graph module is unavailable. `nIt is mandatory to have this module installed in the system to run the script successfully." 
    $confirm = Read-Host Are you sure you want to install Microsoft Graph module? [Y] Yes [N] No  
    if($confirm -match "[yY]") 
    { 
        Write-host "Installing Microsoft Graph module..."
        InstallDeps
        Install-Module Microsoft.Graph -Scope CurrentUser
        Write-host "Microsoft Graph module is installed in the machine successfully" -ForegroundColor Magenta 
    } 
    else
    { 
        Write-host "Exiting. `nNote: Microsoft Graph module must be available in your system to run the script" -ForegroundColor Red
        Exit 
    } 
}
}

Function InstallMainBasic {
$MsGraphBetaModule =  Get-Module Microsoft.Graph -ListAvailable
if($null -eq $MsGraphBetaModule)
{ 
    Write-host "Important: Microsoft Graph module is unavailable. `nIt is mandatory to have this module installed in the system to run the script successfully." 
    $confirm = Read-Host Are you sure you want to install Microsoft Graph module? [Y] Yes [N] No  
    if($confirm -match "[yY]") 
    { 
        Write-host "Installing Microsoft Graph module..."
        InstallDeps
        Install-Module Microsoft.Graph.Users -Scope CurrentUser -AllowClobber
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -AllowClobber
        Write-host "Microsoft Graph module is installed in the machine successfully" -ForegroundColor Magenta 
    } 
    else
    { 
        Write-host "Exiting. `nNote: Microsoft Graph module must be available in your system to run the script" -ForegroundColor Red
        Exit 
    } 
}
}


Function InstallBetaBasic {
$MsGraphBetaModule =  Get-Module Microsoft.Graph.Beta* -ListAvailable
if($null -eq $MsGraphBetaModule)
{ 
    Write-host "Important: Microsoft Graph Beta module is unavailable. `nIt is mandatory to have this module installed in the system to run the script successfully." 
    $confirm = Read-Host Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No  
    if($confirm -match "[yY]") 
    { 
        Write-host "Installing Microsoft Graph Beta module..."
        InstallDeps
        Install-Module Microsoft.Graph.Beta.Users -Scope CurrentUser -AllowClobber
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -AllowClobber
        Write-host "Microsoft Graph Beta module is installed in the machine successfully" -ForegroundColor Magenta 
    } 
    else
    { 
        Write-host "Exiting. `nNote: Microsoft Graph Beta module must be available in your system to run the script" -ForegroundColor Red
        Exit 
    } 
}
}

Function InstallBetaAll {
$MsGraphBetaModule =  Get-Module Microsoft.Graph.Beta* -ListAvailable
if($null -eq $MsGraphBetaModule)
{ 
    Write-host "Important: Microsoft Graph Beta module is unavailable. `nIt is mandatory to have this module installed in the system to run the script successfully." 
    $confirm = Read-Host Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No  
    if($confirm -match "[yY]") 
    { 
        Write-host "Installing Microsoft Graph Beta module..."
        InstallDeps
        Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
        Write-host "Microsoft Graph Beta module is installed in the machine successfully" -ForegroundColor Magenta 
    } 
    else
    { 
        Write-host "Exiting. `nNote: Microsoft Graph Beta module must be available in your system to run the script" -ForegroundColor Red
        Exit 
    } 
}
}

if($InstallMainBasic.IsPresent)
{
    InstallMainBasic
} elseif ($InstallBetaBasic.IsPresent) {
    InstallBetaBasic
} else {
    InstallMainAll
    InstallBetaAll
}




