function Check-ProcessIsElevated {
	$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent();
	$currentPrincipal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity);
	$isAdminRole = $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator);

	return $isAdminRole;
}
