function downloadQuest{
    param(
        $token,
        $appID,
        $versionID
    )

    $downloadButton.text = "Fetching version info from OculusDB..."
    $db = Invoke-WebRequest "https://oculusdb.rui2015.me/api/v1/connected/$appID" -UseBasicParsing
    $json = $db.Content -replace 'platform', { "platform$(Get-Random -Minimum 1000 -Maximum 9999)" }
    $versionInfo = ConvertFrom-Json $json

    $versionInfo = ($versionInfo.versions | Where-Object { $_.id -eq $versionID })
    $OBBs = $versionInfo.obbList

    $questDownloadBar.Visible = $true
    $cookie = New-Object System.Net.Cookie
    $cookie.Name = "oc_www_at"
    $cookie.Value = $token
    $cookie.Domain = "oculus.com"
    $cookie.Path = "/"

    for ($i=0; $i -lt $OBBs.count; $i++) {
        $downloadButton.text = "Downloading game files ($($i + 1)/$(($OBBs.count) + 1))..."
        $downloadButton.Refresh()
        $job = start-job {
            param($cookie, $obb)
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add([System.Net.HttpRequestHeader]::Cookie, $cookie.ToString())
            $webClient.DownloadFile("https://securecdn.oculus.com/binaries/download/?id=$($obb.id)", "$env:temp/$($obb.file_name)")
        } -ArgumentList $cookie, $OBBs[$i]
        $questDownloadBar.Value = 0
        while ($job.state -ne "Completed") {
            $questDownloadBar.Value = (((Get-Item "$env:temp/$($OBBs[$i].file_name)").length / $OBBs[$i].sizeNumerical) * 100)
            start-sleep -Milliseconds 100
        }
        remove-job $job
    }
    $downloadButton.text = "Downloading game files ($($OBBs.count + 1)/$(($OBBs.count) + 1))..."
    $downloadButton.Refresh()
    $job = start-job {
        param($cookie, $versionID, $versionInfo)
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add([System.Net.HttpRequestHeader]::Cookie, $cookie.ToString())
        $webClient.DownloadFile("https://securecdn.oculus.com/binaries/download/?id=$versionID", "$env:temp\$($versionInfo.file_name)")
    } -ArgumentList $cookie, $versionID, $versionInfo
    $questDownloadBar.Value = 0
    while ($job.state -ne "Completed") {
        $questDownloadBar.Value = (((Get-Item "$env:temp\$($versionInfo.file_name)").length / 96177060) * 100)
        start-sleep -Milliseconds 100
    }
    remove-job $job
    $questDownloadBar.Value = 100
    $downloadButton.text = "Download Complete!"
    $downloadButton.Refresh()
    $questDownloadBar.Visible = $false

    $choice = [System.Windows.Forms.MessageBox]::Show("Download Complete! Would you like to install the game onto your headset?", "Bootleg Oculus Downgrader","YesNo", "Question")   
    if ($choice -eq "Yes") {
        installQuest $versionInfo $OBBs
    } else {
        $saveLocation = Read-FolderBrowserDialog -Message "Where would you like to save the game files?" -InitialDirectory "$env:USERPROFILE\Desktop"
        if ($saveLocation) {
            $saveLocation = $saveLocation + "\" + $versionInfo.name
            Move-Item "$env:temp\$($versionInfo.file_name)" "$saveLocation\$($versionInfo.file_name)"
            for ($i=0; $i -lt $OBBs.count; $i++) {
                Move-Item "$env:temp/$($OBBs[$i].file_name)" "$saveLocation/$($OBBs[$i].file_name)"
            }
        }
    }
}

function installQuest {
    param(
        $versionInfo,
        $OBBs
    )


    $adb = "$env:temp\adb\platform-tools\adb.exe"
    if (!(Test-Path "$adb")) {
        $downloadButton.text = "Downloading ADB..."
        Invoke-WebRequest "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile "$env:temp\platform-tools.zip"
        Expand-Archive -Path "$env:temp\platform-tools.zip" -DestinationPath "$env:temp\adb\"
    }
    $downloadButton.text = "Searching for headset..."
    while (1) {
        $devices = & $adb devices
        $devices = $devices -split "`n"
        if ($devices.count -gt 3) {
            $noDevice = [System.Windows.Forms.MessageBox]::show("More than one device detected, make sure only your Quest is connected to your PC. If you have any other Android devices connected is it a possibility that the game will be installed onto the wrong device. Please unplug any devices that you do not need before pressing retry.", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::RetryCancel, [system.windows.forms.messageboxicon]::Error)
            if ($noDevice -eq "Cancel") {
                $patchEchoVR.text = "Try again"
                $installProgress.Visible = $false
                $patchEchoVR.enabled = $true
                $resetPatcher.visible = $true
                return
            }
        } else {
            break
        }
    }
    while (1) {
        $devices = & $adb devices
        $devices = $devices -split "`n"
        if ($devices.count -lt 3) {
            $noDevice = [System.Windows.Forms.MessageBox]::show("No device detected, make sure your Quest is connected to your PC and developer mode and debug mode are enabled (Google: How to enable developer mode on quest).`n`nIf these things have been done check your headset for a USB debugging message.`n`nIf it still is not working try restarting the headset.", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::RetryCancel, [system.windows.forms.messageboxicon]::Error)
            if ($noDevice -eq "Cancel") {
                $patchEchoVR.text = "Try again"
                $installProgress.Visible = $false
                $patchEchoVR.enabled = $true
                $resetPatcher.visible = $true
                return
            }
        } else {
            break
        }
    }
    while (1) {
        $devices = & $adb devices
        if ($devices[1] -like "*unauthorized") {
            $noDevice = [System.Windows.Forms.MessageBox]::show("This computer is unauthorized. Please accept the prompt in your headset then press retry.", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::RetryCancel, [system.windows.forms.messageboxicon]::Warning)
            if ($noDevice -eq "Cancel") {
                $patchEchoVR.text = "Try again"
                $installProgress.Visible = $false
                $patchEchoVR.enabled = $true
                $resetPatcher.visible = $true
                return
            }
        } else {
            break
        }
    }

    $downloadButton.text = "Installing game..."

    new-item -Path "$env:temp\apktools" -ItemType Directory -Force
    expand-archive -path ".\Apktool.zip" -destinationpath "$env:temp\apktool"

    & "$env:temp\apktool\jdk-11.0.21+9-jre\bin\java.exe" -jar "$env:temp\apktool\aapt2-8.2.1-10154469-windows.jar" d "$env:temp\$($versionInfo.file_name)" -o output
    [xml]$androidManifest = Get-Content -Path ".\output\AndroidManifest.xml"
    $packageName = $androidManifest.manifest.package

    remove-item -Path "$env:temp\apktools" -Recurse -Force

    if ($null -eq $packageName) {
        [System.Windows.Forms.MessageBox]::Show("Something went wrong, please try again. [Error: Package Name Missing]", "Bootleg Oculus Downgrader","OK", "Error")
        return
    }

    & $adb uninstall $packageName
    & $adb install "$env:temp\$($versionInfo.file_name)"
    foreach ($obb in $OBBs) {
        & $adb push "$env:temp\$($obb.file_name)" "/sdcard/Android/obb/$packageName/$($obb.file_name)"
    }
    [System.Windows.Forms.MessageBox]::Show("Game installed!", "Bootleg Oculus Downgrader","OK", "Info")
}

function Read-FolderBrowserDialog([string]$Message, [string]$InitialDirectory) {
    $app = New-Object -ComObject Shell.Application
    $folder = $app.BrowseForFolder(0, $Message, 0, $InitialDirectory)
    if ($folder) { return $folder.Self.Path } else { return "$env:USERPROFILE\Desktop" }
}