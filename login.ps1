function getLoginUrl {
    $payload = @{
        "access_token" = "FRL|512466987071624|01d4a1f7fd0682aea7ee8ae987704d63"
    }
    $loginResponse = Invoke-RestMethod -Method Post -Uri "https://meta.graph.meta.com/webview_tokens_query" -Body (ConvertTo-Json $payload) -ContentType "application/json"
    $etoken = $loginResponse.native_sso_etoken
    $global:token = $loginResponse.native_sso_token
    return "https://auth.meta.com/native_sso/confirm?native_app_id=512466987071624&native_sso_etoken=$etoken&utm_source=skyline_splash"
}

function GetToken {
    $payload = @{
        "access_token" = "FRL|512466987071624|01d4a1f7fd0682aea7ee8ae987704d63"
        "blob" = $global:blob
        "request_token" = $global:token
    }
    $response = Invoke-RestMethod -Method Post -Uri "https://meta.graph.meta.com/webview_blobs_decrypt" -Body (ConvertTo-Json $payload) -ContentType "application/json"
    $firstToken = $response.access_token
    $c = @{
        "uri" = $oculusUri
        "options" = @{
            "access_token" = if ($firstToken -ne "") { $firstToken } else { "OC|752908224809889|" }
            "doc_id" = "5787825127910775"
            "variables" = "{`"app_id`":`"1582076955407037`"}"
        }
    }
    $response = Invoke-RestMethod -Method Post -Uri "https://meta.graph.meta.com/graphql" -Body (ConvertTo-Json $c.options) -ContentType "application/json"
    return $response.data.xfr_create_profile_token.profile_tokens[0].access_token
}

function parseOculusProtocol {
    param (
        $response
    )

    $parameters = $response.Replace("oculus://", "").Split('?')[1].Split('&')
    $global:blob = $parameters[1].Split('=')[1]
    return GetToken
}

function login {
    $registryPath = "HKCU\SOFTWARE\Classes\oculus"
    $backupPath = "$env:temp\oculus.reg"

    if (Test-Path $backupPath) {
        reg import $backupPath
        Remove-Item $backupPath
    }

    reg export $registryPath $backupPath | out-null


    New-Item -Path "HKCU:\Software\Classes\Oculus"
    Set-ItemProperty -Path "HKCU:\Software\Classes\Oculus" -Name "URL Protocol" -Value ""
    Set-ItemProperty -Path "HKCU:\Software\Classes\Oculus" -Name "(Default)" -Value "URL:Oculus Protocol"
    New-Item -Path "HKCU:\Software\Classes\Oculus\shell"
    New-Item -Path "HKCU:\Software\Classes\Oculus\shell\open"
    New-Item -Path "HKCU:\Software\Classes\Oculus\shell\open\command"
    Set-ItemProperty -Path "HKCU:\Software\Classes\Oculus\shell\open\command" -Name "(Default)" -Value "`"powershell.exe`" -executionPolicy bypass -windowStyle hidden -file $("$env:temp\setToken.ps1") `%1"

    'param($keys)' | Out-File -FilePath "$env:temp\setToken.ps1"
    '$keys | Out-File -FilePath "$env:temp\token"' | Out-File -FilePath "$env:temp\setToken.ps1" -Append
    '[reflection.assembly]::LoadWithPartialName( "System.Windows.Forms")' | Out-File -FilePath "$env:temp\setToken.ps1" -Append
    '[System.Windows.Forms.Application]::EnableVisualStyles()' | Out-File -FilePath "$env:temp\setToken.ps1" -Append
    '[System.Windows.Forms.MessageBox]::show("You have successfully logged in. You can close your browser and return to Echo Navigator", "Bootleg Oculus Downgrader","OK", "Information")' | Out-File -FilePath "$env:temp\setToken.ps1" -Append
    
    
    $downloadButton.Text = "Waiting for login..."

    Start-Process "$(getLoginUrl)"

    while (1) {
        $startTime = Get-Date
        while (!(test-path "$env:temp\token") -and ((Get-Date) -lt ($startTime.AddMinutes(1)))) {
            start-sleep -Milliseconds 100
            $timeRemainingLabel.Visible = $true
            $timeRemainingLabel.Text = "Time Till Cancel Option: $((($startTime.AddMinutes(1)) - (Get-Date)).Minutes):$((($startTime.AddMinutes(1)) - (Get-Date)).Seconds)"
        }

        if (!(test-path "$env:temp\token")) {
            $choice = [System.Windows.Forms.MessageBox]::show("Looks like you have been logging in for a while, would you like to cancel the login?", "Bootleg Oculus Downgrader","YesNo", "Question")
            if ($choice -eq "Yes") {
                if (Test-Path $backupPath) {
                    reg import $backupPath
                    Remove-Item $backupPath
                }
                $downloadButton.text = "Try again"
                $downloadButton.enabled = $true
                $timeRemainingLabel.Visible = $false
                return
            }
        } else {
            break
        }
    }

    if (Test-Path $backupPath) {
        reg import $backupPath
        Remove-Item $backupPath
    }

    $timeRemainingLabel.Visible = $false
    $downloadButton.text = "Logging in..."

    $tokenFile = get-content "$env:temp\token"
    remove-item "$env:temp\token"
    remove-item "$env:temp\setToken.ps1"
    return parseOculusProtocol $tokenFile
}