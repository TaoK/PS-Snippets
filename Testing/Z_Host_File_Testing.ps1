
#consider looking into this script scope business! http://stackoverflow.com/questions/801967/how-can-i-find-the-source-path-of-an-executing-script/6985381#6985381
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory "AddTo-HostsFile.ps1")
. (Join-Path $ScriptDirectory "Check-ProcessIsElevated.ps1")
. (Join-Path $ScriptDirectory "Invoke-ElevatedCommand.ps1")


if (-not (Check-ProcessIsElevated)) {
	return Invoke-ElevatedCommand ($executioncontext.InvokeCommand.NewScriptBlock("(. $($MyInvocation.MyCommand.Path))"))
}

AddTo-HostsFile 10.10.10.10 a.b.c.d
