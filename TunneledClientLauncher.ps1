#requires -version 2.0
param([string]$SSHServerLocalIP = $($showUsage = 1),
	[string]$SSHServerRemoteName = $($showUsage = 1),
	[string]$SSHExpectedHostKeyFingerprint,
	[string]$SSHUser = $($showUsage = 1),
	[string]$SSHPrivateKeyFile,
	[string]$TargetNetworkServer = $($showUsage = 1),
	[int]$TargetServerPort = $($showUsage = 1),
	[string]$ClientProgram = $($showUsage = 1),
	[string]$ClientArgs = $($showUsage = 1),
	[string]$SSHServerLocalMAC,
	[int]$SSHPort = 22,
	[switch]$ManualTunnelClose,
	[switch]$AutoQuit,
	[switch]$KeyboardInteractive
	)

#Helper function, avoid some repetition on error conditions
function PromptForExit {
	Write-Host "Press any key to exit."
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}

if ($showUsage)
{
	'Some script to do something.'
	'USAGE:	'
	'	-someparem: somevalue'
	$showUsage = $false; #turns out this becomes a global var if run within a powershell session, so need to reset it for next run.
	if (-not $AutoQuit) {
		PromptForExit
	}
	Exit 1
}

# Add usage blurb, with explanation of optional params etc.
# Add support for passphrase-protected keyfiles (implement PS-method callback-based "UserInfo" stuff)
# Add support for host key checking with file (implement PS-method callback-based "UserInfo" stuff)
# Implement dynamic user input
# Add support for HOSTS-modifying approach for hostname-oriented protocols, such as HTTP
# Add support for starting remote process (eg VPN program) BEFORE launching client program here
# Add examples, explaining why you might use different features.

#Add validation of presence of dotincludes
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory "SharpSsh 5.ps1")
. (Join-Path $ScriptDirectory "NetUtils.ps1")


#Helper function, get correct 32-bit programs folder regardless of machine architecture and PS execution mode
Function Get-32BitProgramFilesDir {
	if ([IntPtr]::Size -eq 8) {
		${Env:ProgramFiles(x86)}
	}
	else {
		${Env:ProgramFiles}
	}
}

#provide x86 program files variable even on 32-bit systems (WOW64 env vars are a mess)
$ClientProgram = $ClientProgram -replace '%PROGRAMFILES(X86)%',(Get-32BitProgramFilesDir)
#also expand any remaining real env variables, in case we were called from PS directly.
$ClientProgram = [System.Environment]::ExpandEnvironmentVariables($ClientProgram)


try {
	#test available networks to see if local or remote server.
	if (Confirm-IPAddressIsLocal $SSHServerLocalIP $SSHServerLocalMAC) {
		Write-Host "Using local server address: $SSHServerLocalIP"
		$SSHServerApplicableName = $SSHServerLocalIP
	}
	else {
		Write-Host "Using external server address: $SSHServerRemoteName"
		$SSHServerApplicableName = $SSHServerRemoteName
	}

	try {
		if ($SSHPrivateKeyFile -or $KeyboardInteractive) {
			Write-Host "Connecting to SSH server at $SSHServerApplicableName, port $SSHPort, user $SSHUser, with provided key file or keyboard interaction."
			$TunnellingShell = New-SshSession -HostName $SSHServerApplicableName -UserName $SSHUser -KeyFile $SSHPrivateKeyFile -Port $SSHPort -Passthru -ExpectedHostKeyFingerprint $SSHExpectedHostKeyFingerprint -KeyboardInteractive:$KeyboardInteractive
		}
		else {
			Write-Host "Obtaining password from user."
			try {
				$LoginCredential = Get-Credential "$SSHUser@$SSHServerApplicableName"
			}
			catch {
				Write-Warning "Credential capture failed:"
				$Host.UI.WriteErrorLine($_.Exception)
				return PromptForExit
			}
			Write-Host "Connecting to SSH server at $SSHServerApplicableName, port $SSHPort, user $SSHUser, with entered password."
			$TunnellingShell = New-SshSession $LoginCredential -Port $SSHPort -Passthru -ExpectedHostKeyFingerprint $SSHExpectedHostKeyFingerprint
		}
	}
	catch {
		Write-Warning "Error connecting to SSH server:"
		$Host.UI.WriteErrorLine($_.Exception)
		return PromptForExit
	}
			
	try {
		$LocalTunnellingPort = New-SshLocalPortForward  -RemotePort $TargetServerPort -RemoteHostName $TargetNetworkServer
	}
	catch {
		Write-Warning "Error setting up Port Forwarding:"
		$Host.UI.WriteErrorLine($_.Exception)
		$TunnellingShell.Close()
		return PromptForExit
	}

	Write-Host "Launching client program, tunneling through local port $LocalTunnellingPort to target server $TargetNetworkServer on remote network, port $TargetServerPort."

	$si2 = new-object System.Diagnostics.ProcessStartInfo
	$si2.fileName = $ClientProgram
	$si2.Arguments = $ClientArgs.Replace("<SERVER>", "localhost").Replace("<PORT>", $LocalTunnellingPort)
	$si2.WorkingDirectory = $pwd
	try {
		$process2 = [System.Diagnostics.Process]::Start($si2)
	}
	catch {
		Write-Warning "Error launching client program:"
		$Host.UI.WriteErrorLine($_.Exception)
		$TunnellingShell.Close()
		return PromptForExit
	}

	if ($ManualTunnelClose) {
		Write-Host "Press any key to close SSH tunnel."
		$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
	}
	else {
		Write-Host "Waiting for client program to complete."
		$process2.WaitForExit()
	}

	try {
		$TunnellingShell.Close()
	}
	catch {
		Write-Warning "Error closing SSH session:"
		$Host.UI.WriteErrorLine($_.Exception)
		return PromptForExit
	}
}
catch {
	Write-Warning "Unknown error:"
	$Host.UI.WriteErrorLine($_.Exception)
	return PromptForExit
}

if (-not $AutoQuit) {
	PromptForExit
}

