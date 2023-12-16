Clear-Host
Write-Host "`nDisconnecting from Microsoft Graph...." -ForegroundColor Yellow
Disconnect-Graph
Start-Sleep -Seconds 2
Disconnect-Graph
Clear-Host
$scopes = @(
    'Directory.ReadWrite.All',
    'User.ReadWrite.All',
    'Application.ReadWrite.All',
    'AppRoleAssignment.ReadWrite.All',
    'RoleManagement.ReadWrite.Directory',
    'DeviceManagementManagedDevices.PrivilegedOperations.All',
    'DeviceManagementManagedDevices.ReadWrite.All',
    'DeviceManagementConfiguration.ReadWrite.All',
    'CloudPC.ReadWrite.All'
)

Connect-MgGraph -Scopes $scopes

$tenantInfo = Get-MgOrganization
Write-Host "
Tenant Information:
Tenant: $($tenantInfo.DisplayName)
Id    : $($tenantInfo.Id)
Domain: $((Get-MgDomain).Id)
" -ForegroundColor Yellow

# Creating users in bulk
Write-Host "Creating user accounts..." -ForegroundColor Yellow 
$domain = Get-MgDomain | select -ExpandProperty Id
$items = @(1..6)
foreach ($item in $items) {
    $params = @{
        AccountEnabled = $true
        DisplayName = "Account$item"
        UserPrincipalName = "account$item@$domain"
        MailNickname = "account$item"
        UsageLocation = 'US'
        PasswordProfile = @{
            ForceChangePasswordNextSignIn = $false
            Password = 'Nttg$ti74fnff[gr4]'
        }
    }
    Write-Host "($item/$($items.Count)) Creating $($params.UserPrincipalName)"  -ForegroundColor Yellow 
    New-MgUser -BodyParameter $params | Out-Null
    Start-Sleep -Seconds 1
}

Start-Sleep 10

Write-Host "`nLicense Information:" -ForegroundColor Green
irm https://bonguides.com/pw/lictranslator | iex

$users = Get-MgUser -ConsistencyLevel eventual -Count userCount -Filter "startsWith(DisplayName, 'Account')" -OrderBy UserPrincipalName
while ($users.Count -lt 6){
Start-Sleep 1
$users = Get-MgUser -ConsistencyLevel eventual -Count userCount -Filter "startsWith(DisplayName, 'Account')" -OrderBy UserPrincipalName
}

Write-Host "`nAssign licenses and add members to group." -ForegroundColor Green
$users = Get-MgUser -ConsistencyLevel eventual -Count userCount -Filter "startsWith(DisplayName, 'Account')" -OrderBy UserPrincipalName
$groupId = (Get-MgGroup -ConsistencyLevel eventual -Count groupCount -Search '"DisplayName:sg-CloudPCUsers"').Id
$sku1 = (Get-MgSubscribedSku | Where-Object {$_.SkuPartNumber -match 'CPC_E_2C_8GB_256GB'}).SkuId
$sku2 = (Get-MgSubscribedSku | Where-Object {$_.SkuPartNumber -match 'CPC_E_2C_4GB_128GB​'}).SkuId

$i = 1
foreach ($user in $users) {
    Write-Host "($i/$($users.Count)) Assign licenses to account: $($user.UserPrincipalName)" -ForegroundColor Green
    Set-MgUserLicense -UserId $($user.Id) -Addlicenses @{SkuId = $sku1} -RemoveLicenses @() | Out-Null
    Set-MgUserLicense -UserId $($user.Id) -Addlicenses @{SkuId = $sku2} -RemoveLicenses @() | Out-Null
    $i++
    Start-Sleep 1
}
Write-Host
$i = 1
foreach ($user in $users) {
    Write-Host "($i/$($users.Count)) Adding account to group: $($user.UserPrincipalName)" -ForegroundColor Magenta
    New-MgGroupMember -GroupId $groupId -DirectoryObjectId $($user.Id) | Out-Null
    $i++
    Start-Sleep 1
}

Start-Sleep 5

# Get user report with license assigments and account status
    $result = @()
    $uri = "https://bonguides.com/files/LicenseFriendlyName.txt"
    $friendlyNameHash = Invoke-RestMethod -Method GET -Uri $uri | ConvertFrom-StringData

    $users  = Get-MgUser -ConsistencyLevel eventual -Count userCount -Filter "startsWith(DisplayName, 'Account')" -OrderBy UserPrincipalName

    # Get licenses assigned to user accounts
    Write-Host
    $i = 1
    foreach ($user in $users) {
        Write-Host "($i/$($users.Count)) Processing: $($user.UserPrincipalName) - $($user.DisplayName)" -ForegroundColor Cyan
        $licenses = (Get-MgBetaUserLicenseDetail -UserId $user.id).SkuPartNumber
        $assignedLicense = @()
    # Convert license plan to friendly name
        if($licenses.count -eq 0){
            $assignedLicense = "Unlicensed"
        } else {
        
        foreach($License in $licenses){
            $EasyName = $friendlyNameHash[$License]
            if(!($EasyName)){
                $NamePrint = $License
            } else {
                $NamePrint = $EasyName
        }
        $assignedLicense += $NamePrint
    }
    }

    # Creating the custom report
        $result += [PSCustomObject]@{
            'DisplayName' = $user.DisplayName
            'UserPrincipalName' = $user.UserPrincipalName
            'Assignedlicenses'=(@($assignedLicense)-join ',')
        }
        $i++
        }
    
Write-Host "`nGenerating report..." -ForegroundColor Yellow
$result | Sort-Object assignedlicenses -Descending | Format-Table

# Retrieve the group based on the specified group ID or display name
$groupId = (Get-MgGroup -ConsistencyLevel eventual -Count groupCount -Search '"DisplayName:sg-CloudPCUsers"').Id

$members = Get-MgGroupMember -GroupId $groupId -All

# Initialize an array to store user information
$users = @()

# Iterate through each group member and retrieve user details
foreach ($member in $members) {
    $user = Get-MgUser -UserId $member.Id -ErrorAction SilentlyContinue

    # Add user information to the array
    $Objects = [PSCustomObject][ordered]@{
        Group             = "sg-CloudPCUsers"
        Name              = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
    }

    # Add the ordered custom object to the array
    $users += $Objects
}

# Export user information
$users

Write-Host "Creating an app registration in Entra ID..." -ForegroundColor Yellow
$appName =  "testapp"
    $app = New-MgApplication -DisplayName $appName
    $appObjectId = $app.Id

    $passwordCred = @{
        "displayName" = "DemoClientSecret"
        "endDateTime" = (Get-Date).AddMonths(+12)
    }
    $clientSecret = Add-MgApplicationPassword -ApplicationId $appObjectId -PasswordCredential $passwordCred

    $permissionParams = @{
        RequiredResourceAccess = @(
            @{
                ResourceAppId = "00000003-0000-0000-c000-000000000000"
                ResourceAccess = @(
                    @{
                        Id = '19dbc75e-c2e2-444c-a770-ec69d8559fc7'
                        Type = "Role"
                    },
                    @{
                        Id = "741f803b-c850-494e-b5df-cde7c675a1ca"
                        Type = "Role"
                    },
                    @{
                        Id = "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9"
                        Type = "Role"
                    },
                    @{
                        Id = "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8"
                        Type = "Role"
                    },
                    @{
                        Id = "5b07b0dd-2377-4e44-a38d-703f09a0dc3c"
                        Type = "Role"
                    },
                    @{
                        Id = "243333ab-4d21-40cb-a475-36241daa0842"
                        Type = "Role"
                    },
                    @{
                        Id = "9241abd9-d0e6-425a-bd4f-47ba86e767a4"
                        Type = "Role"
                    },
                    @{
                        Id = "06b708a9-e830-4db3-a914-8e69da51d44f"
                        Type = "Role"
                    }
                    
                )
            }
        )
    }
    Update-MgApplication -ApplicationId $appObjectId -BodyParameter $permissionParams

    Write-Host "Granting admin consent..." -ForegroundColor Yellow
    # Grant admin consent
    $graphSpId = $(Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'").Id
    $sp = New-MgServicePrincipal -AppId $app.appId
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "19dbc75e-c2e2-444c-a770-ec69d8559fc7" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "741f803b-c850-494e-b5df-cde7c675a1ca" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "5b07b0dd-2377-4e44-a38d-703f09a0dc3c" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "243333ab-4d21-40cb-a475-36241daa0842" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "9241abd9-d0e6-425a-bd4f-47ba86e767a4" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "06b708a9-e830-4db3-a914-8e69da51d44f" -ResourceId $graphSpId | Out-Null
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -AppRoleId "3b4349e1-8cf5-45a3-95b7-69d1751d3e6a" -ResourceId $graphSpId | Out-Null
    
    $folder = (Get-MgOrganization).VerifiedDomains.Name | Out-Null
    New-Item -ItemType Directory "P:\05.Databases\Cdx\$folder" -Force

    Write-Host "Generating app-only authentication information..." -ForegroundColor Yellow
    $($app.AppID) >> "P:\05.Databases\Cdx\$folder\appid.txt"
    $((Get-MgOrganization).Id) >> "P:\05.Databases\Cdx\$folder\tenantid.txt"
    $($clientSecret.SecretText) >> "P:\05.Databases\Cdx\$folder\clientSecret.txt"

    # Get-ChildItem "P:\05.Databases\Cdx\$folder"

# Create a script

Get-MgBetaDeviceManagementScript | foreach {
    Remove-MgBetaDeviceManagementScript -DeviceManagementScriptId $_.Id
}

    Write-Host "Adding a PowerShell script into Intune..." -ForegroundColor Yellow
    $scriptContent = Get-Content "P:\05.Databases\Cdx\all.ps1" -Raw
    # $encodedScriptContent = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$scriptContent"))
    $params = @{
        "@odata.type" = "#microsoft.graph.deviceManagementScript"
        displayName = "all"
        description = "all"
        # scriptContent = [System.Text.Encoding]::ASCII.GetBytes("c2NyaXB0Q29udGVudA==")
        scriptContent = [System.Text.Encoding]::ASCII.GetBytes("$scriptContent")
        runAsAccount = "system"
        enforceSignatureCheck = $false
        fileName = "all.ps1"
        roleScopeTagIds = @(
        )
        runAs32Bit = $true
    }

    New-MgBetaDeviceManagementScript -BodyParameter $params

Write-Host "Creating a device group..." -ForegroundColor Yellow
$GroupParam = @{
    DisplayName = "All-Cloud-PCs"
    GroupTypes = @(
        'DynamicMembership'
    )
    SecurityEnabled     = $true
    IsAssignableToRole  = $false
    MailEnabled         = $false
    membershipRuleProcessingState = 'On'
    MembershipRule = 'device.deviceModel -startsWith "Cloud PC"'
    MailNickname        = "test17"
    "Owners@odata.bind" = @(
        "https://graph.microsoft.com/v1.0/me"
    )
}

New-MgGroup -BodyParameter $GroupParam
Write-Host "`nAssigning a device group..." -ForegroundColor Yellow
# Assign the script to a group
    $devicesGroup = (Get-MgGroup | Where-Object {$_.DisplayName -eq 'All-Cloud-PCs'}).Id
    $scriptIds = (Get-MgBetaDeviceManagementScript).id

    foreach ($scriptId in $scriptIds){
        $params = @{
            deviceManagementScriptGroupAssignments = @(
                @{
                    "@odata.type" = "#microsoft.graph.deviceManagementScriptGroupAssignment"
                    id = $scriptId
                    targetGroupId = $devicesGroup
                }
            )
        }
        
        Set-MgBetaDeviceManagementScript -DeviceManagementScriptId $scriptId -BodyParameter $params
    }


Write-Host "`nDone." -ForegroundColor Green
Write-Host "Disconnecting from Microsoft Graph.`n" -ForegroundColor Green

Disconnect-Graph





