function AddTo-HostsFile{
	<#
		.DESCRIPTION
			This function checks to see if an entry exists in the hosts file.
			If it does not, it attempts to add it and verifies the entry.

		.EXAMPLE
			AddTo-Hosts -IPAddress 192.168.0.1 -HostName MyMachine

		.PARAMETER IPAddress
			A string representing an IP address.

		.PARAMETER HostName
			A string representing a host name.

		.SYNOPSIS
			Add entries to the hosts file.
	#>

	param(
		[parameter(Mandatory=$true,position=0)]
		[string]$IPAddress,
		[parameter(Mandatory=$true,position=1)]
		[string]$HostName
	)

	#turns out that this works even in SYSWOW64 mode, because file system redirection is disabled for the "etc" folder:
	# (ref: http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx)
	$HostsFileLocation = "$env:windir\System32\drivers\etc\hosts";
	$NewHostEntry = "$HostName";
	$NewHostEntry = "$HostName";
	$HostsContent = (Get-Content $HostsFileLocation)

	$ActiveEntriesFound = 0
	$HostsContent | Foreach-Object { if ($_ -match $pattern) { $ActiveEntriesFound = $ActiveEntriesFound + 1 } }


	if($HostsContent -contains $NewHostEntry) {
		Write-Output ([System.DateTime]::Now.ToString("yyyy.MM.dd hh:mm:ss") + ": The hosts file already contains the entry: $NewHostEntry.  File not updated.");
	}
	else {
		Write-Output ([System.DateTime]::Now.ToString("yyyy.MM.dd hh:mm:ss") + ": The hosts file does not contain the entry: $NewHostEntry.  Attempting to update.");
		try {
			Add-Content -Path $HostsFileLocation -Value $NewHostEntry;
			Write-Output ([System.DateTime]::Now.ToString("yyyy.MM.dd hh:mm:ss") + ": New entry, $NewHostEntry, added to $HostsFileLocation.");
		}
		catch {
			Write-Output ([System.DateTime]::Now.ToString("yyyy.MM.dd hh:mm:ss") + ": The new entry, $NewHostEntry, was not added to $HostsFileLocation.");
		}
	}
}
