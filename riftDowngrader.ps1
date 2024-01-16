function pickGameFolder {
    param($folderName)

    $locations = Get-ChildItem "HKCU:\SOFTWARE\Oculus VR, LLC\Oculus\Libraries\*"
    $locationList = [System.Collections.ArrayList]@()
    foreach ($location in $locations) {
        $locationList.Add($(Get-ItemProperty "HKCU:\SOFTWARE\Oculus VR, LLC\Oculus\Libraries\$($location.PSChildName)" -Name OriginalPath | Select-Object -ExpandProperty OriginalPath)) | Out-Null
    }

    $pickMenu = new-object System.Windows.Forms.Form
    $pickMenu.text = "Bootleg Oculus Downgrader"
    $pickMenu.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($fileLocation1)
    $pickMenu.Size = New-Object Drawing.Size @(320, 270)
    $pickMenu.StartPosition = "CenterScreen"
    $pickMenu.FormBorderStyle = "FixedDialog"
    $pickMenu.MaximizeBox = $false
    $pickMenu.ShowInTaskbar = $false

    $pickLabel = New-Object System.Windows.Forms.Label
    $pickLabel.Location = New-Object System.Drawing.Size(10,10)
    $pickLabel.Size = New-Object System.Drawing.Size(280,20)
    $pickLabel.Text = "Select folder the game is located in"
    $pickLabel.TextAlign = "MiddleCenter"
    $pickLabel.Font = "Microsoft Sans Serif,10"
    $pickMenu.Controls.Add($pickLabel)

    $pickList = New-Object System.Windows.Forms.ListBox
    $pickList.Location = New-Object System.Drawing.Size(10,30)
    $pickList.Size = New-Object System.Drawing.Size(280,100)
    $pickList.Font = "Microsoft Sans Serif,10"
    $pickList.DataSource = $locationList
    $pickList.SelectedIndex = $i
    $pickMenu.Controls.Add($pickList)

    $customPath = New-Object System.Windows.Forms.Button
    $customPath.Location = New-Object System.Drawing.Size(10,140)
    $customPath.Size = New-Object System.Drawing.Size(280,30)
    $customPath.Text = "Custom Path"
    $customPath.Font = "Microsoft Sans Serif,10"
    $customPath.Add_Click({
        $choice = [System.Windows.Forms.MessageBox]::Show("It is recommended that you use the pre-selected folder so that the Oculus app launches the correct version of the game.`n`n`While you can use a custom path it is not recommended. Would you still like to use a custom path?", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::YesNo, [system.windows.forms.messageboxicon]::Warning)
        if ($choice -eq "No") {
            return
        }
        $pickedFolder = Read-FolderBrowserDialog -Message "Select the folder the game is installed in"
        if (!(test-path "$newFolder\Software\$folderName")) {
            $choice = [System.Windows.Forms.MessageBox]::show("The game was not found in this folder, would you like to continue anyways?", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::YesNo, [system.windows.forms.messageboxicon]::Warning)
            if ($choice -eq "No") {
                return
            }
        }
        $global:newFolder = $pickedFolder
        $pickMenu.Close()
    })
    $pickMenu.Controls.Add($customPath) | Out-Null

    $pickButton = New-Object System.Windows.Forms.Button
    $pickButton.Location = New-Object System.Drawing.Size(10,180)
    $pickButton.Size = New-Object System.Drawing.Size(280,30)
    $pickButton.Text = "Select"
    $pickButton.Font = "Microsoft Sans Serif,10"
    $pickButton.Add_Click({
        if (!(test-path "$($locationList[$pickList.SelectedIndex])\Software\$folderName")) {
            $choice = [System.Windows.Forms.MessageBox]::show("The game was not found in this folder, would you like to pick it anyways?", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::YesNo, [system.windows.forms.messageboxicon]::Warning)
            if ($choice -eq "No") {
                return
            }
        }
        $global:newFolder = $locationList[$pickList.SelectedIndex]
        $pickMenu.Close()
    })
    $pickMenu.Controls.Add($pickButton)

    $pickMenu.ShowDialog() | Out-Null
    return $newFolder
}

function findGameFolder {
    param($folderName)
    $locations = Get-ChildItem "HKCU:\SOFTWARE\Oculus VR, LLC\Oculus\Libraries\*"
    $locationList = [System.Collections.ArrayList]@()
    foreach ($location in $locations) {
        $locationList.Add($(Get-ItemProperty "HKCU:\SOFTWARE\Oculus VR, LLC\Oculus\Libraries\$($location.PSChildName)" -Name OriginalPath | Select-Object -ExpandProperty OriginalPath)) | Out-Null
    }
    $locations = [System.Collections.ArrayList]@()
    foreach ($location in $locationList) {
        if (test-path "$location\Software\$folderName") {
            $locations.Add($location) | Out-Null
        }
    }
    if ($locations.count -eq 1) {
        return "$($locations)\Software\$folderName"
    } else {
        return "$(pickGameFolder)\Software\$folderName"
    }
}

function downloadRift {
    param(
        [string]$token,
        [string]$appID,
        [string]$versionID
    )


    $downloadButton.text = "Downloading Manifest..."
    $downloadButton.Refresh()
    $folderPicker.Visible = $false
    $segmentProgress.Value = 0
    $segmentProgress.Refresh()
    try {
        Invoke-WebRequest -uri "https://securecdn.oculus.com/binaries/download/?id=$versionID&access_token=$token&get_manifest=1" -OutFile "$env:temp\manifest.zip"
    } catch {
        [System.Windows.Forms.MessageBox]::show("Failed to start download. This is usually caused by you not owning the game on the account you logged in with, or are disconnected from the internet.", "Bootleg Oculus Downgrader","OK", "Error")
        $downloadButton.text = "Try again"
        $downloadButton.enabled = $true
        return
    }
    Expand-Archive -Path "$env:temp\manifest.zip" -DestinationPath "$env:temp\manifest" -force
    $manifest = get-content "$env:temp\manifest\manifest.json" | convertfrom-json
    remove-item "$env:temp\manifest.zip"
    remove-item "$env:temp\manifest" -recurse -force

    $gameFolderName = $manifest.canonicalName
    $gamePath = findGameFolder $gameFolderName

    mkdir "$gamePath\..\$gameFolderName.downloading\" -ErrorAction SilentlyContinue

    $segmentCount = 0
    $totalSize = 0
    $downloadButton.text = "Calculating Size..."
    $downloadButton.Refresh()
    $fileNames = $manifest.files | Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name }
    foreach ($fileName in $fileNames) {
        $file = $manifest.files.$fileName
        $segmentCount += $file.segments.count
        $totalSize += $file.size
    }

    if ($totalSize -gt (Get-PSDrive $gamePath[0]).Free) {
        [System.Windows.Forms.MessageBox]::show("You do not have enough free space to download the game. Please free up some space on your $($gamePath[0]) drive and try again.", "Bootleg Oculus Downgrader","OK", "Error")
        $downloadButton.text = "Try again"
        $downloadButton.enabled = $true
        return
    }

    if ($totalSize -gt ((Get-PSDrive $gamePath[0]).Free + 5GB)) {
        $choice = [System.Windows.Forms.MessageBox]::show("While you appear to have sufficient free space to download the game, Windows storage reservations may reduce the actual available space. It's recommended to free up additional space before proceeding with the download. Would you like to attempt the download regardless?", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::YesNo, [system.windows.forms.messageboxicon]::Warning)
        if ($choice -eq "No") {
            $downloadButton.text = "Try again"
            $downloadButton.enabled = $true
            return
        }
    }

    $segmentsDownloaded = 0
    $segmentLabel.Visible = $true
    $segmentProgress.Visible = $true
    $sizeLabel.Visible = $true
    $sizeProgress.Visible = $true
    $downloadButton.text = "Downloading..."
    $downgradeMenu.Refresh()
    Add-Type -AssemblyName System.Net.Http
    $client = [System.Net.Http.HttpClient]::new()
    for ($i=0; $i -lt $($manifest.files | get-member).name.count; $i++) {
        $folderName = $($($manifest.files | get-member).name[$i])
        $folderName = $folderName -split "\\"
        $folderName = $folderName[0..($folderName.Length - 2)]
        $folderName = $folderName -join "\"
        mkdir "$gamePath\..\$gameFolderName.downloading\$folderName\" -ErrorAction SilentlyContinue
        $fileStream = New-Object System.IO.FileStream("$gamePath\..\$gameFolderName.downloading\$($($manifest.files | get-member).name[$i])", [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $bufferSize = 10KB
        foreach ($segment in $manifest.files.$($($manifest.files | get-member).name[$i]).segments) {
            $targetStream = New-Object -TypeName System.IO.MemoryStream
            $uri = New-Object "System.Uri" "https://securecdn.oculus.com/binaries/segment/?access_token=$token&binary_id=$versionID&segment_sha256=$($segment[1])"
            $client = New-Object System.Net.Http.HttpClient
            $response = $client.GetAsync($uri).Result
            $responseStream = $response.Content.ReadAsStreamAsync().Result
            $responseStream.CopyTo($targetStream, $bufferSize)
            $targetStream.Position = 0
            $targetStream.SetLength($targetStream.Length - 4)
            $targetStream.Position = 2
            $deflateStream = New-Object System.IO.Compression.DeflateStream($targetStream, [System.IO.Compression.CompressionMode]::Decompress)
            $deflateStream.CopyTo($fileStream, $bufferSize)
            $deflateStream.Close()
            $targetStream.Close()
            $responseStream.Close()
            $segmentsDownloaded++
            $segmentProgress.value = ($segmentsDownloaded / $segmentCount) * 100
            $segmentProgress.Refresh()
            $sizeProgress.value = (((Get-ChildItem "$gamePath\..\$gameFolderName.downloading" -Recurse | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum + $fileStream.Length)/ $totalSize) * 100
            $sizeProgress.Refresh()
        }
        $fileStream.Close()
    }
    $segmentLabel.Visible = $false
    $sizeLabel.Visible = $false
    $sizeProgress.Visible = $false
    $downloadButton.text = "Verifying..."
    $downloadButton.Refresh()

    for ($i=0; $i -lt $($manifest.files | get-member).name.count; $i++) {
        $hash = (Get-FileHash -Path "$gamePath\..\$gameFolderName.downloading\$($($manifest.files | get-member).name[$i])" -Algorithm SHA256).hash
        if ($hash -ne $manifest.files.$($($manifest.files | get-member).name[$i]).sha256) {
            $downloadButton.text = "Downloading..."
            $fileStream = New-Object System.IO.FileStream("$gamePath\..\$gameFolderName.downloading\$($($manifest.files | get-member).name[$i])", [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
            $bufferSize = 10KB
            $segmentsDownloaded = 0
            foreach ($segment in $manifest.files.$($($manifest.files | get-member).name[$i]).segments) {
                $targetStream = New-Object -TypeName System.IO.MemoryStream
                $uri = New-Object "System.Uri" "https://securecdn.oculus.com/binaries/segment/?access_token=$token&binary_id=$versionID&segment_sha256=$($segment[1])"
                $client = New-Object System.Net.Http.HttpClient
                $response = $client.GetAsync($uri).Result
                $responseStream = $response.Content.ReadAsStreamAsync().Result
                $responseStream.CopyTo($targetStream, $bufferSize)
                $targetStream.Position = 0
                $targetStream.SetLength($targetStream.Length - 4)
                $targetStream.Position = 2
                $deflateStream = New-Object System.IO.Compression.DeflateStream($targetStream, [System.IO.Compression.CompressionMode]::Decompress)
                $deflateStream.CopyTo($fileStream, $bufferSize)
                $deflateStream.Close()
                $targetStream.Close()
                $responseStream.Close()
                $segmentsDownloaded++
                $segmentProgress.value = ($segmentsDownloaded / $manifest.files.$($($manifest.files | get-member).name[$i]).segments.count) * 100
                $segmentProgress.Refresh()
            }
            $fileStream.Close()
            $hash = (Get-FileHash -Path "$gamePath\..\$gameFolderName.downloading\$($($manifest.files | get-member).name[$i])" -Algorithm SHA256).hash
            if ($hash -ne $manifest.files.$($($manifest.files | get-member).name[$i]).sha256) {
                [System.Windows.Forms.MessageBox]::show("The download was corrupt even after a second download attempt. Please try again.", "Bootleg Oculus Downgrader","OK", "Error")
                $downloadButton.text = "Try again"
                $downloadButton.enabled = $true
                return
            } else {
                $downloadButton.text = "Verifying..."
                $downloadButton.Refresh()
            }
        }
        $segmentProgress.value = ($i / $($manifest.files | get-member).name.count) * 100
        $segmentProgress.Refresh()
    }
    $segmentProgress.Visible = $false

    Remove-Item "$gamePath\..\$gameFolderName.downloading\Equals" -recurse -force
    Remove-Item "$gamePath\..\$gameFolderName.downloading\GetHashCode" -recurse -force
    Remove-Item "$gamePath\..\$gameFolderName.downloading\GetType" -recurse -force
    Remove-Item "$gamePath\..\$gameFolderName.downloading\ToString" -recurse -force
    $choice = [System.Windows.Forms.MessageBox]::show("Would you like to delete your old install?", "Bootleg Oculus Downgrader", [system.windows.forms.messageboxbuttons]::YesNo, [system.windows.forms.messageboxicon]::Question)
    if ($choice -eq "Yes") {
        remove-item $gamePath -recurse -force
    } else {
        rename-item $gamePath "$gamePath.old"
    }
    rename-item "$gamepath\..\$gameFolderName.downloading\" "$gameFolderName" -force
    $downloadButton.text = "Finished!"
}