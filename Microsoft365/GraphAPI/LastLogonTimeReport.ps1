
Param
(
    [string]$MBNamesFile,
    [int]$InactiveDays,
    [switch]$UserMailboxOnly,
    [switch]$ReturnNeverLoggedInMB,
    [switch]$SigninAllowedUsersOnly,
    [switch]$LicensedUsersOnly,
    [switch]$AdminsOnly,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)
Function ConnectModules 
{
    $MsGraphBetaModule =  Get-Module Microsoft.Graph.Beta -ListAvailable
    if($null -eq $MsGraphBetaModule)
    { 
        Write-host "Important: Microsoft Graph Beta module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Microsoft Graph Beta module..."
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
            Install-PackageProvider -Name NuGet -Force
            Install-Module PowerShellGet -Force
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
            Write-host "Microsoft Graph Beta module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Microsoft Graph Beta module must be available in your system to run the script" -ForegroundColor Red
            Exit 
        } 
    }
    $ExchangeOnlineModule =  Get-Module ExchangeOnlineManagement -ListAvailable
    if($null -eq $ExchangeOnlineModule)
    { 
        Write-host "Important: Exchange Online module is unavailable. It is mandatory to have this module installed in the system to run the script successfully." 
        $confirm = Read-Host Are you sure you want to install Exchange Online module? [Y] Yes [N] No  
        if($confirm -match "[yY]") 
        { 
            Write-host "Installing Exchange Online module..."
            Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
            Write-host "Exchange Online Module is installed in the machine successfully" -ForegroundColor Magenta 
        } 
        else
        { 
            Write-host "Exiting. `nNote: Exchange Online module must be available in your system to run the script" 
            Exit 
        } 
    }
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
    Write-Progress -Activity "Connecting modules(Microsoft Graph and Exchange Online module)..."
    try{
        if($TenantId -ne "" -and $ClientId -ne "" -and $CertificateThumbprint -ne "")
        {
            Connect-MgGraph  -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -ErrorAction SilentlyContinue -ErrorVariable ConnectionError|Out-Null
            if($ConnectionError -ne $null)
            {    
                Write-Host $ConnectionError -Foregroundcolor Red
                Exit
            }
            $Scopes = (Get-MgContext).Scopes
            if($Scopes -notcontains "Directory.Read.All" -and $Scopes -notcontains "Directory.ReadWrite.All")
            {
                Write-Host "Note: Your application required the following graph application permissions: Directory.Read.All" -ForegroundColor Yellow
                Exit
            }
            Connect-ExchangeOnline -AppId $ClientId -CertificateThumbprint $CertificateThumbprint  -Organization (Get-MgDomain | Where-Object {$_.isInitial}).Id -ShowBanner:$false
        }
        else
        {
            Connect-MgGraph -Scopes "Directory.Read.All"  -ErrorAction SilentlyContinue -Errorvariable ConnectionError |Out-Null
            if($ConnectionError -ne $null)
            {
                Write-Host $ConnectionError -Foregroundcolor Red
                Exit
            }
            Connect-ExchangeOnline -UserPrincipalName (Get-MgContext).Account -ShowBanner:$false
        }
    }
    catch
    {
        Write-Host $_.Exception.message -ForegroundColor Red
        Exit
    }
    Write-Host "Microsoft Graph Beta Powershell module is connected successfully" -ForegroundColor Green
    Write-Host "Exchange Online module is connected successfully" -ForegroundColor Green
}
Function CloseConnection
{
    Disconnect-MgGraph|Out-Null
    Disconnect-ExchangeOnline -Confirm:$false
}
Function ProcessMailBox
{
    Write-Progress -Activity "`n     Processing mailbox: $Script:MailBoxUserCount - $DisplayName"
    $Script:MailBoxUserCount++
    if($AccountEnabled -eq $True)
    {
        $SigninStatus = "Allowed"
    }
    else
    {
        $SigninStatus = "Blocked"
    }

    #Retrieve lastlogon time and then calculate Inactive days
    if($LastLogonTime -eq $null)
    {
        $LastLogonTime = "Never Logged In"
        $InactiveDaysOfUser = "-"
    }
    else
    {
        $InactiveDaysOfUser = (New-TimeSpan -Start $LastLogonTime).Days
    }

    #Get licenses assigned to mailboxes
    $Licenses = (Get-MgBetaUserLicenseDetail -UserId $UPN).SkuPartNumber
    $AssignedLicense = @()
    #Convert license plan to friendly name
    if($Licenses.count -eq 0)
    {
        $AssignedLicense = "No License Assigned"
    }
    else
    {
        foreach($License in $Licenses)
        {
            $EasyName = $FriendlyNameHash[$License]
            if(!($EasyName))
            {$NamePrint = $License}
            else
            {$NamePrint = $EasyName}
            $AssignedLicense += $NamePrint
        }
    }
    #Inactive days based filter
    if($InactiveDaysOfUser -ne "-")
    {
        if(($InactiveDays -ne "") -and ($InactiveDays -gt $InactiveDaysOfUser))
        {
            return
        }
    }
    #UserMailboxOnly
    if(($UserMailboxOnly.IsPresent) -and ($MailBoxType -ne "UserMailbox"))
    {
        return
    }
    #Never Logged In user
    if(($ReturnNeverLoggedInMB.IsPresent) -and ($LastLogonTime -ne "Never Logged In"))
    {
        return
    }
    #Signin Allowed Users
    if($SigninAllowedUsersOnly.IsPresent -and $AccountEnabled -eq $False)
    {
        
        return
    }
    #Licensed Users ony
    if($LicensedUsersOnly -and $Licenses.Count -eq 0)
    {
        return
    }
    #Get roles assigned to user
    $Roles = @()
    $Roles = Get-MgBetaUserTransitiveMemberOf -UserId $UPN |Select-Object -ExpandProperty AdditionalProperties
    $Roles=$Roles|?{$_.'@odata.type' -eq '#microsoft.graph.directoryRole'} 
    if($Roles.count -eq 0) 
    { 
        $RolesAssigned = "No roles" 
    } 
    else 
    { 
        $RolesAssigned = @($Roles.displayName) -join ',' 
    } 
    #Admins only
    if($AdminsOnly.IsPresent -and $RolesAssigned -eq 'No roles')
    {
        return
    }
    #Export result to CSV file
    $Script:OutputCount++
    $Result = [PSCustomObject]@{'UserPrincipalName'=$UPN;'DisplayName'=$DisplayName;'SigninStatus' = $SigninStatus ;'LastLogonTime'=$LastLogonTime;'CreationTime'=$_.WhenCreated;'InactiveDays'=$InactiveDaysOfUser;'MailboxType'=$MailBoxType; 'AssignedLicenses'=(@($AssignedLicense)-join ',');'Roles'=$RolesAssigned}
    $Result | Export-Csv -Path $ExportCSV -Notype -Append
}

#Get friendly name of license plan from external file
$FriendlyNameHash = Invoke-RestMethod -Method GET -Uri "https://raw.githubusercontent.com/bonguides25/PowerShell/main/Microsoft365/Files/LicenseFriendlyName.txt" | ConvertFrom-StringData

#Module functions
ConnectModules
Write-Host "`nNote: If you encounter module related conflicts, run the script in a fresh PowerShell window." -ForegroundColor Yellow
#Set output file
$ExportCSV = ".\LastLogonTimeReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$MailBoxUserCount = 1
$OutputCount = 0

#Check for input file
if([string]$MBNamesFile -ne "") 
{ 
    #We have an input file, read it into memory 
    $Mailboxes = @()
    try{
        $InputFile = Import-Csv -Path $MBNamesFile -Header "MBIdentity"
    }
    catch
    {
        Write-Host $_.Exception.Message -ForegroundColor Red
        CloseConnection
        Exit
    }
    Foreach($item in $InputFile.MBIdentity)
    {
        $Mailbox = Get-ExoMailBox -Identity $item -PropertySets All -ErrorAction SilentlyContinue
        if($Mailbox -ne $null)
        {
            $DisplayName = $Mailbox.DisplayName
            $UPN = $Mailbox.UserPrincipalName
            $LastLogonTime = (Get-ExoMailboxStatistics -Identity $UPN -Properties LastLogonTime).LastLogonTime
            $MailBoxType = $Mailbox.RecipientTypeDetails
            $CreatedDateTime = $Mailbox.WhenCreated
            $AccountEnabled = (Get-MgBetaUser -UserId $UPN).AccountEnabled
            ProcessMailBox
        } 
        else
        {
            Write-Host $item not found -ForegroundColor Red
        }   
    }
}

#Get all mailboxes from Office 365
else
{
    Get-ExoMailbox -ResultSize Unlimited -PropertySets All | Where{$_.DisplayName -notlike "Discovery Search Mailbox"} | ForEach-Object {
        $DisplayName = $_.DisplayName
        $UPN = $_.UserPrincipalName
        $LastLogonTime = (Get-ExoMailboxStatistics -Identity $UPN -Properties LastLogonTime).LastLogonTime
        $MailBoxType = $_.RecipientTypeDetails
        $CreatedDateTime = $_.WhenCreated
        $AccountEnabled = (Get-MgBetaUser -UserId $UPN).AccountEnabled
        ProcessMailBox
    }
}
#Open output file after execution
Write-Host `nScript executed successfully
if((Test-Path -Path $ExportCSV) -eq "True")
{
   
    Write-Host "Exported report has " -NoNewline
    Write-Host "$OutputCount mailboxe(s)" -ForegroundColor Green
    $Prompt = New-Object -ComObject wscript.shell
    $UserInput = $Prompt.popup("Do you want to open output file?",` 0,"Open Output File",4)
    if ($UserInput -eq 6)
    {
        Invoke-Item "$ExportCSV"
    }
    Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 
    
}
else
{
    Write-Host "No mailbox found" -ForegroundColor Red
}

CloseConnection