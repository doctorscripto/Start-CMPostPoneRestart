<#
Disclaimer:
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.

THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  

We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code,
provided that you agree: 
       (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; 
       (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
       (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.

Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained within the Premier Customer Services Description.
#>
# Original Source reference script from https://stackoverflow.com/questions/60294495/run-powershell-script-to-show-a-form-without-powershell-screen-at-the-back
# Modifications provided by Sean Kearney, Microsoft, Customer Engineer

# Default values to modify
# Customer Company Name
$CompanyName = 'Contoso Inc' 

# Function takes a single parameter "StopTime" which is a [datetime] object to indicate when the task should run
# it is a one time task to try and restart the computer if a pending reboot is detected under and environment
# managed by Configuration Manager
Function New-RestartTask {
    param($StopTime)
    #remove old task
    Unregister-ScheduledTask -TaskName "$Script:CompanyName Weekly Reboot" -Confirm:$false -ErrorAction SilentlyContinue
    # Create task action
    $TaskArgument = '-command "$RebootNeeded=(Invoke-CimMethod -Namespace root/ccm/ClientSDK -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending).rebootpending;if($RebootNeeded -eq $True) {Restart-Computer -force}"'
    $taskAction = New-ScheduledTaskAction -Execute 'POWERSHELL.EXE' -Argument $TaskArgument
    # Create a trigger (Mondays at 4 AM)
    $taskTrigger = New-ScheduledTaskTrigger -Once -at $StopTime
    # Task Settings
    $TaskSettings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable
    # The user to run the task
    $taskUser = New-ScheduledTaskPrincipal -UserId "SYSTEM"
    # The name of the scheduled task.
    $taskName = "$Script:CompanyName Weekly Reboot"
    # Describe the scheduled task.
    $description = "Forcibly reboot the computer"
    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskUser -Description $description -Settings $TaskSettings | Out-NULL

}

# This function simply accepts a value in seconds to modify the local variable RebootDelay
# which traps how long the user would like to delay the Restart
Function Add-RestartTime {
    param($UpdateInSeconds)

    if (($Script:RebootDelay + $UpdateInSeconds) -ge 86400 -and $Script:MaxHit -eq $false) {
        $Script:RebootDelay = 86400
        $Script:MaxHit = $True
    }
    elseif (($Script:RebootDelay + $UpdateInSeconds) -le 86400 -and $Script:MaxHit -eq $false) {
        $Script:RebootDelay = $Script:RebootDelay + $UpdateInSeconds
    }
}

# Detect if Configuration Manager thinks a reboot is needed
$RebootNeeded = ((Invoke-CimMethod -Namespace root/ccm/ClientSDK -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending).rebootpending)
If ($RebootNeeded) {
    # Suspend Bitlocker for Reboot to avoid PIN issues
    Suspend-BitLocker -MountPoint "C:" -RebootCount 0

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName( "Microsoft.VisualBasic") | Out-Null
    $ScreenData = [System.Windows.Forms.Screen]::PrimaryScreen
    $Workingsize = $ScreenData.WorkingArea
    $Terminate = $False
    $Title = "$Script:CompanyName Computer Restart Notification"
    $Message = "Computer will restart Automatically in:"
    $timerUpdate = New-Object 'System.Windows.Forms.Timer'
    $TotalTime = 7200 #in seconds
    $RebootDelay = $TotalTime
    $StartTime = Get-Date
    $Maxhit = $False
    $StopTime = $StartTime.AddSeconds($RebootDelay)
    New-RestartTask -stoptime $StopTime

    $timerUpdate_Tick = {
        # Define countdown timer
        [TimeSpan]$span = $Script:StopTime - (Get-Date)
        # Update the display
        $hours = "{0:00}" -f $span.Hours
        $mins = "{0:00}" -f $span.Minutes
        $secs = "{0:00}" -f $span.Seconds
        $labelTime.Text = "{0}:{1}:{2}" -f $hours, $mins, $secs
        $timerUpdate.Start()
        if ($span.TotalSeconds -le 0) {
            $timerUpdate.Stop()
            Unregister-TaskName "$Script:CompanyName Weekly Reboot" -Confirm:$false -ErrorAction SilentlyContinue
            $Script:Terminate = $TRUE
            New-RestartTask -StopTime (Get-Date).AddSeconds(60)
            $Form.close()
        }
    }

    $Form_StoreValues_Closing =
    {
        #Store the control values
    }
      
    $Form_Cleanup_FormClosed =
    {
        #Remove all event handlers from the controls
        try {
            $Form.remove_Load($Form_Load)
            $timerUpdate.remove_Tick($timerUpdate_Tick)
            #$Form.remove_Load($Form_StateCorrection_Load)
            $Form.remove_Closing($Form_StoreValues_Closing)
            $Form.remove_FormClosed($Form_Cleanup_FormClosed)
        }
        catch [Exception]
        { }
    }
      
    # Form
    $Form = New-Object -TypeName System.Windows.Forms.Form
    $Form.Text = $Title
    $Form.Size = New-Object -TypeName System.Drawing.Size(412, 285)
    $Form.StartPosition = "CenterScreen"
    $Form.Topmost = $true
    $Form.KeyPreview = $true
    $Form.ShowInTaskbar = $False
    $Form.FormBorderStyle = "FixedDialog"
    $form.ControlBox = $False
    $Form.FormBorderStyle = 'FixedDialog'
    $Icon = [system.drawing.icon]::ExtractAssociatedIcon("c:\Windows\System32\UserAccountControlSettings.exe")
    $Button1Text = 'Restart Now'
    $Button2Text = '+2 Hrs'
    $Button3Text = '+4 Hrs'
    $Button4Text = '+12 Hrs'
    $Button5Text = '+24 Hrs'
    $Button10Text = 'Minimize'

    $Form.Icon = $Icon

    # Button One (Reboot/Shutdown Now)
    $Button1 = New-Object -TypeName System.Windows.Forms.Button
    $Button1.Size = New-Object -TypeName System.Drawing.Size(90, 25)
    $Button1.Location = New-Object -TypeName System.Drawing.Size(158, 35)
    $Button1.Text = $Button1Text
    $Button1.Font = 'Tahoma, 10pt'
    $Button1.Add_Click({
            $timerUpdate.Stop()
            Unregister-ScheduledTask -TaskName "$Script:CompanyName Weekly Reboot" -Confirm:$false -ErrorAction SilentlyContinue
            $Script:Terminate = $TRUE        
            New-RestartTask -StopTime (Get-Date).AddSeconds(60)
            $Form.Close()
        })
    $Form.Controls.Add($Button1)

    # Button Two (Postpone for 2 Hours)
    $Button2 = New-Object -TypeName System.Windows.Forms.Button
    $Button2.Size = New-Object -TypeName System.Drawing.Size(90, 25)
    $Button2.Location = New-Object -TypeName System.Drawing.Size(10, 135)
    $Button2.Text = $Button2Text
    $Button2.Font = 'Tahoma, 10pt'
    $Button2.Add_Click({
      
            $timerUpdate.Stop()
            $TotalTime = 7200
            Add-RestartTime -UpdateInSeconds $TotalTime
            $Script:StopTime = $StartTime.AddSeconds($RebootDelay)
            New-RestartTask -stoptime $Script:StopTime
            $timerUpdate.add_Tick($timerUpdate_Tick)
            $timerUpdate.Start()
        })
    $Form.Controls.Add($Button2)

    # Button Three (Postpone for 4 Hours)
    $Button3 = New-Object -TypeName System.Windows.Forms.Button
    $Button3.Size = New-Object -TypeName System.Drawing.Size(90, 25)
    $Button3.Location = New-Object -TypeName System.Drawing.Size(105, 135)
    $Button3.Text = $Button3Text
    $Button3.Font = 'Tahoma, 10pt'
    $Button3.Add_Click({
      
            $timerUpdate.Stop()
            $TotalTime = 14400
            Add-RestartTime -UpdateInSeconds $TotalTime
            $Script:StopTime = $StartTime.AddSeconds($RebootDelay)
            New-RestartTask -stoptime $Script:StopTime
            $timerUpdate.add_Tick($timerUpdate_Tick)
            $timerUpdate.Start()
        })
    $Form.Controls.Add($Button3)

    # Button Three (Postpone for 12 Hours)
    $Button4 = New-Object -TypeName System.Windows.Forms.Button
    $Button4.Size = New-Object -TypeName System.Drawing.Size(90, 25)
    $Button4.Location = New-Object -TypeName System.Drawing.Size(200, 135)
    $Button4.Text = $Button4Text
    $Button4.Font = 'Tahoma, 10pt'
    $Button4.Add_Click({
      
            $timerUpdate.Stop()
            $TotalTime = 43200
            Add-RestartTime -UpdateInSeconds $TotalTime
            $Script:StopTime = $StartTime.AddSeconds($RebootDelay)
            New-RestartTask -stoptime $Script:StopTime
            $timerUpdate.add_Tick($timerUpdate_Tick)
            $timerUpdate.Start()
        })
    $Form.Controls.Add($Button4)

    # Button Five (Postpone for 24 Hours)
    $Button5 = New-Object -TypeName System.Windows.Forms.Button
    $Button5.Size = New-Object -TypeName System.Drawing.Size(90, 25)
    $Button5.Location = New-Object -TypeName System.Drawing.Size(295, 135)
    $Button5.Text = $Button5Text
    $Button5.Font = 'Tahoma, 10pt'
    $Button5.Add_Click({
      
            $timerUpdate.Stop()
            $TotalTime = 86400
            Add-RestartTime -UpdateInSeconds $TotalTime
            $Script:StopTime = $StartTime.AddSeconds($RebootDelay)
            New-RestartTask -stoptime $Script:StopTime
            $timerUpdate.add_Tick($timerUpdate_Tick)
            $timerUpdate.Start()
        })
    $Form.Controls.Add($Button5)


    # Button Ten (Hide me)
    $Button10 = New-Object -TypeName System.Windows.Forms.Button
    $Button10.Size = New-Object -TypeName System.Drawing.Size(90, 25)
    $Button10.Location = New-Object -TypeName System.Drawing.Size(150, 215)
    $Button10.Text = $Button10Text
    $Button10.Name = 'MinimizeWindow'
    $Button10.Font = 'Tahoma, 10pt'
    $Button10.Add_Click({
        
            $Form.close()
        })
    #>
    $Form.Controls.Add($Button10)

    # Label
    $Label = New-Object -TypeName System.Windows.Forms.Label
    $Label.Size = New-Object -TypeName System.Drawing.Size(400, 50)
    $Label.Location = New-Object -TypeName System.Drawing.Size(10, 5)
    $Label.Text = $Message
    $label.Font = 'Tahoma, 10pt'
    $Form.Controls.Add($Label)

    # Label2
    $Label2 = New-Object -TypeName System.Windows.Forms.Label
    $Label2.Size = New-Object -TypeName System.Drawing.Size(355, 30)
    $Label2.Location = New-Object -TypeName System.Drawing.Size(10, 100)
    $Label2.Text = $Message2
    $label2.Font = 'Tahoma, 10pt'
    $Form.Controls.Add($Label2) 

    # labelTime
    $labelTime = New-Object 'System.Windows.Forms.Label'
    $labelTime.AutoSize = $True
    $labelTime.Font = 'Arial, 26pt, style=Bold'
    $labelTime.Location = '120, 60'
    $labelTime.Name = 'labelTime'
    $labelTime.Size = '43, 15'
    $labelTime.TextAlign = 'MiddleCenter'

    $Form.Controls.Add($labeltime)

    # labelTime
    $postponelabel = New-Object 'System.Windows.Forms.Label'
    $postponelabel.AutoSize = $True
    $postponelabel.Font = 'Arial, 10pt'
    $postponelabel.Location = '50, 180'
    $postponelabel.Name = 'postponelabel'
    $postponelabel.Size = '355, 30'
    $postponelabel.TextAlign = 'MiddleCenter'
    $postponelabel.Text = 'Click Button(s) to Extend time. (24 hrs Maximum)'

    $Form.Controls.Add($postponelabel)
    $Form.AcceptButton = $Button10

    #Start the timer
    $timerUpdate.add_Tick($timerUpdate_Tick)
    $timerUpdate.Start()
    # Show
    $Form.Add_Shown({ $Form.Activate() })
    #Clean up the control events
    #endregion

    $timerUpdatesmall = New-Object 'System.Windows.Forms.Timer'
    $timerUpdateSmall_Tick = {
        # Define countdown timer
        [TimeSpan]$span = $Script:StopTime - (Get-Date)
        # Update the display
        $hours = "{0:00}" -f $span.Hours
        $mins = "{0:00}" -f $span.Minutes
        $secs = "{0:00}" -f $span.Seconds
        $labelTimeSmall.Text = "{0}:{1}:{2}" -f $hours, $mins, $secs
        $timerUpdate.Start()
        if ($span.TotalSeconds -le 0) {
            $timerUpdate.Stop()
            Unregister-ScheduledTask -TaskName "$Script:CompanyName Weekly Reboot" -Confirm:$false -ErrorAction SilentlyContinue
            $Script:Terminate = $TRUE
            New-RestartTask -StopTime (Get-Date).AddSeconds(60)
            $FormSmall.close()
        }
    }

    # Form
    $FormSmall = New-Object -TypeName System.Windows.Forms.Form
    $FormSmall.Text = 'RebootTimer'
    $FormSmall.Size = New-Object -TypeName System.Drawing.Size(70, 60)
    $FormSmall.StartPosition = "Manual"
    $LocationY = $Workingsize.Height - $FormSmall.Height
    $LocationX = $Workingsize.Width - $FormSmall.Width
    $FormSmall.Location = New-Object -TypeName System.Drawing.Size($LocationX, $LocationY)
    $FormSmall.Topmost = $true
    $FormSmall.KeyPreview = $true
    $FormSmall.ShowInTaskbar = $false
    $FormSmall.ControlBox = $true
    $FormSmall.FormBorderStyle = 'None'
    $FormSmall.Icon = $Icon

    # Button - Restore Large Form
    $ButtonSmall = New-Object -TypeName System.Windows.Forms.Button
    $ButtonSmall.Size = New-Object -TypeName System.Drawing.Size(125, 20)
    $ButtonSmall.Location = New-Object -TypeName System.Drawing.Size(5, 5)
    $ButtonSmall.Text = 'Restore'
    $ButtonSmall.Font = 'Tahoma, 10pt'
    $ButtonSmall.Add_Click({
            $FormSmall.close() 
        })
    $FormSmall.Controls.Add($ButtonSmall)


    # labelTime
    $labelTimeSmall = New-Object 'System.Windows.Forms.Label'
    $labelTimeSmall.AutoSize = $False
    $labelTimeSmall.Font = 'Tahoma, 10pt'
    $labelTimeSmall.Location = New-Object -TypeName System.Drawing.Size(5, 35)
    $labelTimeSmall.Name = 'labelTime'
    $labelTimeSmall.Size = New-Object -TypeName System.Drawing.Size(125, 30)
    $labelTimeSmall.TextAlign = 'MiddleCenter'

    $FormSmall.Controls.Add($labeltimesmall)

    #Start the timer
    $timerUpdatesmall.add_Tick($timerUpdatesmall_Tick)
    $timerUpdatesmall.Start()
    # Show
    $FormSmall.Add_Shown({ $FormSmall.Activate() })
    #Clean up the control events
    #endregion
    do {
        If (!$Terminate) { $form.ShowDialog() }
        If (!$Terminate) { $FormSmall.ShowDialog() }
    }Until($Terminate)
}