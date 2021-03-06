. $PSScriptRoot\..\..\PesterLogger\PesterLogger.ps1

function Start-UDPEchoServerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [Int16] $ServerPort,
        [Parameter(Mandatory=$true)] [Int16] $ClientPort
    )
    $UDPEchoServerCommand = ( `
    '$SendPort = {0};' + `
    '$RcvPort = {1};' + `
    '$IPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, $RcvPort);' + `
    '$RemoteIPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, 0);' + `
    '$UDPSocket = New-Object System.Net.Sockets.UdpClient;' + `
    '$UDPSocket.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true);' + `
    '$UDPSocket.Client.Bind($IPEndpoint);' + `
    'while($true) {{' + `
    '    try {{' + `
    '        $Payload = $UDPSocket.Receive([ref]$RemoteIPEndpoint);' + `
    '        $RemoteIPEndpoint.Port = $SendPort;' + `
    '        $UDPSocket.Send($Payload, $Payload.Length, $RemoteIPEndpoint);' + `
    '        \"Received message and sent it to: $RemoteIPEndpoint.\" | Out-String;' + `
    '    }} catch {{ Write-Output $_.Exception; continue }}' + `
    '}}') -f $ClientPort, $ServerPort

    Invoke-Command -Session $Session -ScriptBlock {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "UDPEchoServerJob",
            Justification="It's actually used."
        )]
        $UDPEchoServerJob = Start-Job -ScriptBlock {
            param($ContainerName, $UDPEchoServerCommand)
            docker exec $ContainerName powershell "$UDPEchoServerCommand"
        } -ArgumentList $Using:ContainerName, $Using:UDPEchoServerCommand
    }
}

function Stop-EchoServerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $Output = Invoke-Command -Session $Session -ScriptBlock {
        $UDPEchoServerJob | Stop-Job | Out-Null
        $Output = Receive-Job -Job $UDPEchoServerJob
        return $Output
    }

    Write-Log "Output from UDP echo server running in remote session: $Output"
}

function Start-UDPListenerInContainer {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session,
        [Parameter(Mandatory=$true)] [String] $ContainerName,
        [Parameter(Mandatory=$true)] [Int16] $ListenerPort
    )
    $UDPListenerCommand = ( `
    '$RemoteIPEndpoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, 0);' + `
    '$UDPRcvSocket = New-Object System.Net.Sockets.UdpClient {0};' + `
    '$Payload = $UDPRcvSocket.Receive([ref]$RemoteIPEndpoint);' + `
    '[Text.Encoding]::UTF8.GetString($Payload)') -f $ListenerPort

    Invoke-Command -Session $Session -ScriptBlock {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            "PSUseDeclaredVarsMoreThanAssignments",
            "UDPListenerJob",
            Justification="It's actually used."
        )]
        $UDPListenerJob = Start-Job -ScriptBlock {
            param($ContainerName, $UDPListenerCommand)
            & docker exec $ContainerName powershell "$UDPListenerCommand"
        } -ArgumentList $Using:ContainerName, $Using:UDPListenerCommand
    }
}

function Stop-UDPListenerInContainerAndFetchResult {
    Param (
        [Parameter(Mandatory=$true)] [PSSessionT] $Session
    )

    $Message = Invoke-Command -Session $Session -ScriptBlock {
        $UDPListenerJob | Wait-Job -Timeout 30 | Out-Null
        $ReceivedMessage = Receive-Job -Job $UDPListenerJob
        return $ReceivedMessage
    }
    Write-Log "UDP listener output from remote session: $Message"
    return $Message
}
