powershell .\TunneledClientLauncher.ps1 ^
    -SSHServerLocalIP:'192.168.1.30' ^
    -SSHServerLocalMAC:'60-77-4b-05-d3-f9' ^
    -SSHServerRemoteName:'ra.klerks.biz' ^
    -SSHExpectedHostKeyFingerprint:'63:78:1e:40:88:6a:50:62:98:06:d4:02:ac:e6:b6:ff' ^
    -SSHPort:33322 ^
    -SSHUser:"Tao" ^
    -SSHPrivateKeyFile:"E:\OpenSSHCompatibleKey.pk" ^
    -TargetNetworkServer:"192.168.1.27" ^
    -TargetServerPort:3336 ^
    -ClientProgram:"'%PROGRAMFILES(X86)%\TightVNC\vncviewer.exe'" ^
    -ClientArgs:"'<SERVER>::<PORT>'" ^
    -AutoQuit

Pause