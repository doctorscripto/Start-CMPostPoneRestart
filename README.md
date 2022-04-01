# Start-CMPostPoneRestart
This file is based upon a script found here https://stackoverflow.com/questions/60294495/run-powershell-script-to-show-a-form-without-powershell-screen-at-the-back
I take no credit on any of the initial design.   If somebody can point me to the original Repository I will refer to it.

The concepts of this script are from the ShutdownNow.exe app from CoreTech (www.ctglobalservices.com).  This version is written in Pure PowerShell

The tasks of this script, when deployed in Configuration Manager; are as follows

Detect if a restart is needed

Disable Bitlocker temporarily to allow for restarts when PIN is enabled

Pop up a box to a user indicating a Countdown Before restart occurs

Presents users with 4 options to delay restart up to 24 hours

Allow them to minimize app while countdown continues

The app will schedule a task for a restart so that if the user logs off during this process, a restart can still occur

All buttons for Close, Minimize and Maximize have been removed from the form to prevent "user tampering" ;)

Enjoy!
