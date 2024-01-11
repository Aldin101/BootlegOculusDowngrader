. .\login.ps1
. .\questDowngrader.ps1
. .\riftDowngrader.ps1

function downloadPrep {
    param(
        [string]$appid,
        [string]$versionID,
        [string]$headset
    )
    $token = login

    if ($null -eq $token) {
        return
    }

    if ($headset -eq "rift") {
        downloadRift $token $appid $versionID
    } else {
        downloadQuest $token $appid $versionID
    }
}

function parseDownloadCode {
    $downloadButton.enabled = $false
    # downgrade code format "d --appid 3228453177179864 --versionid 7227527287272413 --headset rift"
    $code = $codeEntry.Text
    if ($code -match "d --appid (\d+) --versionid (\d+) --headset (rift|hollywood)") {
        $appid = $matches[1]
        $versionID = $matches[2]
        $headset = $matches[3]
        downloadPrep $appid $versionID $headset
    } else {
        [System.Windows.Forms.MessageBox]::Show("Invalid download code", "Bootleg Oculus Downgrader","OK", "Error")
        return
    }
}


$ProgressPreference = 'SilentlyContinue'

[reflection.assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
[system.windows.forms.application]::enablevisualstyles()

$menu = new-object System.Windows.Forms.Form
$menu.text = "Bootleg Oculus Downgrader"
$menu.Size = New-Object Drawing.Size @(600, 400)
$menu.StartPosition = "CenterScreen"
$menu.FormBorderStyle = "FixedDialog"
$menu.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Size(10, 10)
$label.Size = New-Object System.Drawing.Size(560, 20)
$label.Text = "Bootleg Oculus Downgrader"
$label.Font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$menu.Controls.Add($label)

$helpLabel = New-Object System.Windows.Forms.Label
$helpLabel.Location = New-Object System.Drawing.Size(10, 50)
$helpLabel.Size = New-Object System.Drawing.Size(560, 100)
$helpLabel.Text = "Welcome to the Bootleg Oculus Downgrader. This tool will allow you to download older version of oculus quest/rift games.`n`nTo download a game enter a download code into the box below and click download. You can get download codes from OculusDB, just search for a game, press details, then right click the download button and press show Oculus Downgrader code."
$menu.Controls.Add($helpLabel)

$codeEntry = New-Object System.Windows.Forms.TextBox
$codeEntry.Location = New-Object System.Drawing.Size(10, 150)
$codeEntry.Size = New-Object System.Drawing.Size(560, 20)
$codeEntry.Text = "Enter your downgrade code here"
$menu.Controls.Add($codeEntry)

$downloadButton = New-Object System.Windows.Forms.Button
$downloadButton.Location = New-Object System.Drawing.Size(10, 180)
$downloadButton.Size = New-Object System.Drawing.Size(560, 30)
$downloadButton.Text = "Download"
$downloadButton.Add_Click({
    parseDownloadCode
    $downloadButton.enabled = $true
    $downloadButton.Text = "Download"
})
$menu.Controls.Add($downloadButton)

$timeRemainingLabel = New-Object System.Windows.Forms.Label
$timeRemainingLabel.Location = New-Object System.Drawing.Size(10, 220)
$timeRemainingLabel.Size = New-Object System.Drawing.Size(560,10)
$timeRemainingLabel.Text = "Time Till Cancel Option: 1:00"
$timeRemainingLabel.Font = "Microsoft Sans Serif,10"
$timeRemainingLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$timeRemainingLabel.Visible = $false
$menu.Controls.Add($timeRemainingLabel)

$segmentLabel = New-Object System.Windows.Forms.Label
$segmentLabel.Location = New-Object System.Drawing.Size(10,220)
$segmentLabel.Size = New-Object System.Drawing.Size(200,20)
$segmentLabel.Text = "Downloaded Segments"
$segmentLabel.Font = "Microsoft Sans Serif,10"
$segmentLabel.Visible = $false
$menu.Controls.Add($segmentLabel)

$segmentProgress = New-Object System.Windows.Forms.ProgressBar
$segmentProgress.Location = New-Object System.Drawing.Size(10,240)
$segmentProgress.Size = New-Object System.Drawing.Size(200,15)
$segmentProgress.Style = "Continuous"
$segmentProgress.Maximum = 100
$segmentProgress.Value = 0
$segmentProgress.Visible = $false
$menu.Controls.Add($segmentProgress)

$sizeLabel = New-Object System.Windows.Forms.Label
$sizeLabel.Location = New-Object System.Drawing.Size(10,260)
$sizeLabel.Size = New-Object System.Drawing.Size(200,20)
$sizeLabel.Text = "Downloaded Size"
$sizeLabel.Font = "Microsoft Sans Serif,10"
$sizeLabel.Visible = $false
$menu.Controls.Add($sizeLabel)

$sizeProgress = New-Object System.Windows.Forms.ProgressBar
$sizeProgress.Location = New-Object System.Drawing.Size(10,280)
$sizeProgress.Size = New-Object System.Drawing.Size(200,15)
$sizeProgress.Style = "Continuous"
$sizeProgress.Maximum = 100
$sizeProgress.Value = 0
$sizeProgress.Visible = $false
$menu.Controls.Add($sizeProgress)

$questDownloadBar = New-Object System.Windows.Forms.ProgressBar
$questDownloadBar.Location = New-Object System.Drawing.Size(10,220)
$questDownloadBar.Size = New-Object System.Drawing.Size(560,15)
$questDownloadBar.Style = "Continuous"
$questDownloadBar.Maximum = 100
$questDownloadBar.Value = 0
$questDownloadBar.Visible = $false
$menu.Controls.Add($questDownloadBar)

$menu.ShowDialog()