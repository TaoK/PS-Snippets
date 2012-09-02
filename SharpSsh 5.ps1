#requires -version 2.0
## A simple SSH Scripting module for PowerShell
## Retrieved from 
## History:
## v1 - Initial Script
## v2 - Capture default prompt in New-SshSession
## v3 - Update to advanced functions, require 2.0, and add basic help
## v4(modification by Tao Klerks) - Update to reference modified SharpSSH library, configurable connection port, Port Forwarding feature, relative path to binaries
## v5(modification by Tao Klerks) - Update to validate known fingerprint for host, fix to key-based auth support, and allow user-interactive decisions around host key handling/key passphrase entry using another modified SharpSSH library

## USING the SharpSSH.dll binary from:
## https://bitbucket.org/TaoK/sharpssh/downloads / https://bitbucket.org/mattgwagner/sharpssh/downloads
## in the same folder as this script

$ScriptFullPath = $MyInvocation.MyCommand.Path
$ScriptFolder = (New-Object System.IO.FileInfo($ScriptFullPath)).Directory.FullName;
[void][reflection.assembly]::LoadFrom("$ScriptFolder\SharpSSH.dll")

Function ConvertTo-SecureString {
#.Synopsis
#   Helper function which converts a string to a SecureString
Param([string]$input)
   $result = new-object System.Security.SecureString
 
   foreach($c in $input.ToCharArray()) {
      $result.AppendChar($c)
   }
   $result.MakeReadOnly()
   return $result
}

Function ConvertFrom-SecureString {
#.Synopsis
#   Helper function which converts a SecureString to a string
Param([security.securestring]$secure)
   $marshal = [Runtime.InteropServices.Marshal]
   return $marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($secure) )
}

Function ConvertTo-PSCredential {
#.Synopsis
#   Helper function which converts a NetworkCredential to a PSCredential
Param([System.Net.NetworkCredential]$Credential)
   $result = new-object System.Security.SecureString
 
   foreach($c in $input.ToCharArray()) {
      $result.AppendChar($c)
   }
   $result.MakeReadOnly()
   New-Object System.Management.Automation.PSCredential "$($Credential.UserName)@$($Credential.Domain)", (ConvertTo-SecureString $Credential.Password)
}

Function BooleanRead-Host {
#.Synopsis
#   Uses built-in "PromptForChoice" mechanism to ask the user for a yes/no answer
Param([string]$caption, [string]$message)
   $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","help";
   $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","help";
   $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
   $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)
   switch ($answer){
      0 {$true}
      1 {$false}
   }
}

## NOTE: These are still bare minimum functions, and only cover ssh, not sftp or scp (see here: http://poshcode.org/1034) 
##       IMPORTANT: if you "expect" something that does NOT get output, you'll be completely stuck and unable to 'break'
##
## As a suggestion, the best way to handle the output is to "expect" your prompt, and then do 
## select-string matching on the output that was captured before the prompt.

function New-SshSession {
<#
.Synopsis
   Create an SSH session to a remote server
.Description
   Connect to a specific SSH server with the specified credentials.  Supports RSA KeyFile connections.
.Parameter HostName
   The server to SSH into
.Parameter UserName
   The user name to use for login
.Parameter Password
   The Password for login (Note: you really should pass this as a System.Security.SecureString, but it will accept a string instead)
.Parameter KeyFile
   An RSA keyfile for ssh secret key authentication (INSTEAD of username/password authentication).
.Parameter Credentials
   A PSCredential object containing all the information needed to log in. The login name should be in the form user@host
.Parameter Passthru
   If passthru is specified, the new SshShell is returned.
.Parameter Port
   The TCP port to connect to the SSH server on (default is 22)
.Parameter ExpectedHostKeyFingerprint
   Have the host key be checked to match the provided fingerprint
.Parameter AllowSecurityPrompts
   Allow for interactive user prompts for password, passphrase, host key checking decisions, etc
.Example 
   New-SshSession Microsoft.com BillG Micr050ft
   
   Description
   -----------
   Creates a new ssh session with the ssh server at Microsoft.com using the 'BillG' as the login name and 'Micr050ft' as the password (please don't bother trying that).
.Example 
   New-SshSession Microsoft.com -Keyfile BillGates.ppk
   
   Description
   -----------
   Creates a new ssh session with the ssh server at Microsoft.com using the credentials supplied in the BillGates.ppk private key file.
.Example
   $MSCred = Get-Credential BillG@Microsoft.com  # prompts for password
   New-SshSession $MSCred
  
   Description
   -----------
   Creates a new ssh session based on the supplied credentials. Uses the output of $MsCred.GetNetworkCredential() for the server to log into (domain) and the username and password.
#>
[CmdletBinding(DefaultParameterSetName='NamePass')]
Param(
   [Parameter(Position=0,Mandatory=$true,ParameterSetName="NamePass",ValueFromPipelineByPropertyName=$true)]
   [Parameter(Position=0,Mandatory=$true,ParameterSetName="RSAKeyFileOrInteractive",ValueFromPipelineByPropertyName=$true)]
   [string]$HostName
,
   [Parameter(Position=1,Mandatory=$false,ParameterSetName="NamePass",ValueFromPipelineByPropertyName=$true)]
   [Parameter(Position=1,Mandatory=$true,ParameterSetName="RSAKeyFileOrInteractive",ValueFromPipelineByPropertyName=$true)]
   [string]$UserName
,
   [Parameter(Position=2,Mandatory=$false,ParameterSetName="NamePass",ValueFromPipelineByPropertyName=$true)]
   $Password
,  
   [Parameter(Position=2,Mandatory=$false,ParameterSetName="RSAKeyFileOrInteractive",ValueFromPipelineByPropertyName=$true)]
   [string]$KeyFile
,
   [Parameter(Position=3,Mandatory=$false,ParameterSetName="RSAKeyFileOrInteractive",ValueFromPipelineByPropertyName=$true)]
   [switch]$KeyboardInteractive
,
   [Parameter(Position=0,Mandatory=$true,ParameterSetName="PSCredential",ValueFromPipeline=$true)]
   [System.Management.Automation.PSCredential]$Credentials
,
   [switch]$Passthru,
   [int]$Port,
   [string]$ExpectedHostKeyFingerprint = ""
)
   process {
      switch($PSCmdlet.ParameterSetName) {
         'RSAKeyFileOrInteractive'   {
            $global:LastSshSession = new-object Tamir.SharpSsh.SshShell $HostName, $UserName
			if ($KeyFile) { $global:LastSshSession.AddIdentityFile( (Convert-Path (Resolve-Path $KeyFile)) ) }
         }
         'NamePass' {
            if(!$UserName -or !$Password) {
               $Credentials = $Host.UI.PromptForCredential("SSH Login Credentials",
                                                "Please specify credentials in user@host format",
                                                "$UserName@$HostName","")
            } else {
               if($Password -isnot [System.Security.SecureString]) {
                  $Password = ConvertTo-SecureString $Password
               }
               $Credentials = New-Object System.Management.Automation.PSCredential "$UserName@$HostName", $Password
            }
         }
      }

      if($Credentials) {
         $HostName = $Credentials.GetNetworkCredential().Domain
         $global:LastSshSession = new-object Tamir.SharpSsh.SshShell `
                                          $HostName, 
                                          $Credentials.GetNetworkCredential().UserName,
                                          $Credentials.GetNetworkCredential().Password
      }
      else {
         #Keyboard-interactive auth
         $userInfo = new-object Tamir.SharpSsh.DelegatingKeyboardInteractiveUserInfo `
                { param($m); $s = Read-Host -AsSecureString $m; ConvertFrom-SecureString $s; }, `
                { param($m); $s = Read-Host -AsSecureString $m; ConvertFrom-SecureString $s; }, `
                { param($m); BooleanRead-Host -caption $m; }, `
                { param($m); Write-Host $m; }, `
                { param($d, $n, $i, $p, $e); 
                  Write-Host "Keyboard-Interactive Authentication:"; 
                  Write-Host "Destination: $d, Name: $n, Instruction: $i";
                  if ($p -and $p.Length > 0) {
                     Write-Host "Prompt: ";
                     Write-Host $p
                  }
                  $s = Read-Host -AsSecureString;
                  $is = ConvertFrom-SecureString $s;
                  return @($is);
                }

         $global:LastSshSession.SetUserInfo($userInfo);
         if (-not $ExpectedHostKeyFingerprint) {
            $global:LastSshSession.SetHostKeyCheckingRule([Tamir.SharpSsh.HostKeyCheckType]::"AskUser");
            $global:LastSshSession.SetHostKeyFileName("known_hosts");
         }
      }

      if ($ExpectedHostKeyFingerprint) {
         $global:LastSshSession.SetKnownHostFingerprint($ExpectedHostKeyFingerprint)
      }

      if ($Port) {
         $global:LastSshSession.Connect($Port)
      }
      else {
         $global:LastSshSession.Connect()
      }

      $global:LastSshSession.RemoveTerminalEmulationCharacters = $true
      
      if($Passthru) { return $global:LastSshSession }
      
      $global:LastSshSession.WriteLine("")
      sleep -milli 500
      $global:defaultSshPrompt = [regex]::Escape( $global:LastSshSession.Expect().Split("`n")[-1] )
   }
}

function New-SshLocalPortForward {
<#
.Synopsis
   Add remote port forwarding to an existing open SSH session.
.Description
   Add tunnel to a remote port (on a specified remote host) from a port on localhost, through an existing open SSH Shell session. Local listening port will be auto-assigned if not specified. Ports forwards will be cleaned up when shell is closed.
.Parameter SshShell
   The existing open SSH shell session to add the port forwarding to (defaults to the last one opened).
.Parameter RemotePort
   The TCP port to forward to on the remote host.
.Parameter RemoteHostName
   The hostname to tunnel to on the SSH host - often/usually "localhost" (if the resource you want to tunnel to is on the SSH server itself)
.Parameter LocalPort
   The local TCP port that SSH should listen on. Will be auto-assigned if not specified.
.Parameter Passthru
   Have the shell session be output instead of outputting the local port number the forward is configured to. This can be used for piping the shell through multiple port forwards.
.Example
   $listeningPortNumber = New-SshSession (Get-Credential BillG@Microsoft.com) -Passthru | New-SshLocalPortForward -RemoteHostName localhost -RemotePort 5900
  
#>
Param(
   [Parameter(Position=0,Mandatory=$true)]
   [int]$RemotePort,
   [Parameter(Position=1,Mandatory=$false)]
   [string]$RemoteHostName="localhost",
   [Parameter(Position=2,Mandatory=$false,ValueFromPipeline=$true)]
   [Tamir.SharpSsh.SshShell]$SshShell=$global:LastSshSession,
   [Parameter(Position=3,Mandatory=$false)]
   [int]$LocalPort,
   [Parameter(Position=4,Mandatory=$false)]
   [switch]$Passthru
)
   process {
      if ($LocalPort) {
         $SshShell.ForwardLocalPortToRemote($LocalPort, $RemoteHostName, $RemotePort)
      }
      else {
         $LocalPort = $SshShell.ForwardLocalPortToRemote($RemoteHostName, $RemotePort)
      }

      if ($Passthru) {
         return $SshShell
      }
      else {
         return $LocalPort
      }
   }
}

function Remove-SshSession {
<#
   .Synopsis
      Exits an open SshSession (the last open opened, by default)
#>
Param([Tamir.SharpSsh.SshShell]$SshShell=$global:LastSshSession)
   $SshShell.WriteLine( "exit" )
   sleep -milli 500
   if($SshShell.ShellOpened) { Write-Warning "Shell didn't exit cleanly, closing anyway." }
   $SshShell.Close()
   $SshShell = $null
}

function Invoke-Ssh {
<#
   .Synopsis
      Executes an SSH command and Receives output
   .Description
      Invoke-Ssh is basically the same as a Send-Ssh followed by a Receive-Ssh, except that Expect defaults to $defaultSshPrompt (which is read in New-SshSession)
   .Parameter Command
      The command to send
   .Parameter Expect
      A regular expression for expect. The ssh session will wait for a line that matches this regular expression to be output before returning, and will return all the text up to AND INCLUDING the line that matches.
      Defaults
   .Parameter SshShell
      The shell to invoke against. Defaults to the LastSshSession
#>
Param(
   [string]$Command
,  [regex]$Expect = $global:defaultSshPrompt ## there ought to be a non-regex parameter set...
,  [Tamir.SharpSsh.SshShell]$SshShell=$global:LastSshSession
)
   if($SshShell.ShellOpened) {
      $SshShell.WriteLine( $command )
      if($expect) {
         $SshShell.Expect( $expect ).Split("`n")
      }
      else {
         sleep -milli 500
         $SshShell.Expect().Split("`n")
      }
   }
   else { throw "The ssh shell isn't open!" } 
}

function Send-Ssh {
<#
   .Synopsis
      Executes an SSH command without receiving input
   .Description
      Sends a command to an ssh session
   .Parameter Command
      The command to send
   .Parameter SshShell
      The shell to send to. Defaults to the LastSshSession
#>
Param(
   [string]$command
,  [Tamir.SharpSsh.SshShell]$SshShell=$global:LastSshSession
)

   if($SshShell.ShellOpened) {
      $SshShell.WriteLine( $command )
   }
   else { throw "The ssh shell isn't open!" } 
}

function Receive-Ssh {
<#
   .Synopsis
      Receives output from an SSH session
   .Description
      Retrieves output from an SSH session until the text matches the Expect pattern
   .Parameter Expect
      A regular expression for expect. The ssh session will wait for a line that matches this regular expression to be output before returning, and will return all the text up to AND INCLUDING the line that matches.
   .Parameter SshShell
      The shell to wait for. Defaults to the LastSshSession
#>
Param(
   [RegEx]$expect ## there ought to be a non-regex parameter set...
,  [Tamir.SharpSsh.SshShell]$SshShell=$global:LastSshSession
)
   if($SshShell.ShellOpened) {
      if($expect) {
         $SshShell.Expect( $expect ).Split("`n")
      }
      else {
         sleep -milli 500
         $SshShell.Expect().Split("`n")
      }
   }
   else { throw "The ssh shell isn't open!" } 
}