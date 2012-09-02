Function Find-MatchingSubnetIP {
	Param (
		[Parameter(Position=0, Mandatory=$true)]  
		[string]$TestAddress, 
		[Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]  
		[string[]]$TargetAddresses, 
		[Parameter(Position=2, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]  
		[string[]]$TargetSubnets
	)

	begin {
		$TestIP = [System.Net.IPAddress]::Parse($TestAddress)
		$TestIPBytes = $TestIP.GetAddressBytes()
	}

	process {
		if ($TargetAddresses.Length -ne $TargetSubnets.Length) {
			throw "target addresses and target subnets must match!"
		}

		for ($j = 0; $j -lt $TargetAddresses.Length; $j++) {

			$TargetIP = [System.Net.IPAddress]::Parse($TargetAddresses[$j])
			$TargetIPBytes = $TargetIP.GetAddressBytes()
	
			$TargetSubnetIP = [System.Net.IPAddress]::Parse($TargetSubnets[$j])
			$TargetSubnetIPBytes = $TargetSubnetIP.GetAddressBytes()
	
			if (($TestIPBytes.Length -eq $TargetIPBytes.Length) -and ($TargetIPBytes.Length -eq $TargetSubnetIPBytes.Length)) {
				$MaskedMatch = $True
				for ($i = 0; $i -lt $TargetSubnetIPBytes.Length; $i++) {
					if (($TestIPBytes[$i] -band $TargetSubnetIPBytes[$i]) -ne  ($TargetIPBytes[$i] -band $TargetSubnetIPBytes[$i])) {
						$MaskedMatch = $False
					}
				}
				if ($MaskedMatch) {
					#Output IP that is on matching subnet
					$TargetIP
				}
			}
		}
	}
}

Function Confirm-IPAddressIsLocal {
	Param (
		[Parameter(Position=0, Mandatory=$true)]  
		[string]$TestIPAddress,
		[Parameter(Position=1, Mandatory=$false)]  
		[string]$ExpectedMACAddress
	)

	$LocalSubNetIP = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName . | `
		Where-Object {$_.IPAddress -ne '0.0.0.0'} | `
		Select-Object @{Name='TargetAddresses'; Expression={$_.IPAddress}}, @{Name='TargetSubnets'; Expression={$_.IPSubnet}} -Unique | `
		Find-MatchingSubnetIP $TestIPAddress

	if ($LocalSubNetIP) {
		if ($ExpectedMACAddress) {
			#true only if local IP's MAC address is as requested
			($ExpectedMACAddress -eq (Get-MacAddressFromIP($TestIPAddress)))
		}
		else {
			#no MAC filter, matching subnet founf, all set!
			$True
		}
	}
	else {
		#no matching subnet found.
		$False
	}
}

Function Get-AvailableLocalListeningPort {
	$autoListener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
	$autoListener.Start(0)
	$autoListener.LocalEndpoint.Port #grab the auto-assigned port before we release it (will revert to 0 afterwards!).
	$autoListener.Stop()
}

# from http://scriptolog.blogspot.com/2007/08/how-to-retrieve-remote-mac-address.html
Function Get-MacAddressFromIP {
	Param (
		[Parameter(Position=0, Mandatory=$true)]  
		[string]$IPAddress
	)
	# does not require admin priviledges, but DOES require that the target host respond to Ping requests.
	# (otherwise, we couldn't be sure that the ping request wasn't stale. We could enhance this by making
	# the ip test configurable, eg TCP connection attempt to a given port...)

	# fill that IP in arp cache by requesting a ping (v low timeout as we are looking for subnet-local responses anyway)
    if((new-object System.Net.NetworkInformation.Ping).Send($IPAddress, 200).Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {

		# get full contents of arp cache, and get MAC-lookalike pattern match from any line that contains the requested IP address
        (arp -a | ? {$_ -match $IPAddress}) -match "([0-9A-F]{2}([:-][0-9A-F]{2}){5})" | out-null

		#return the first match
        $matches[0]
    }

}
