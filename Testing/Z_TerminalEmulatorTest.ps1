#requires -version 2.0

$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory "SharpSsh 5.ps1")

New-SshSession -HostName "192.168.2.30" -UserName "Tao" -KeyFile "E:\DragonflyToTaonOnMinimac-TestOnly2.ppk" -Port 12322 -KeyboardInteractive

$CommandGiven = Read-Host "Whaddayawannado?" 

Invoke-Ssh $CommandGiven

$CommandGiven = Read-Host "Again?" 

Invoke-Ssh $CommandGiven

Write-Host "Disconnecting"

Remove-SshSession

Read-Host "All done"
