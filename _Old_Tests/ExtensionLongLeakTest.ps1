. $PSScriptRoot\..\..\Common\Aliases.ps1

function Test-ExtensionLongLeak {
    Param ([Parameter(Mandatory = $true)] [PSSessionT] $Session,
           [Parameter(Mandatory = $true)] [int] $TestDurationHours,
           [Parameter(Mandatory = $true)] [TestConfiguration] $TestConfiguration)

    . $PSScriptRoot\..\Utils\CommonTestCode.ps1

    if ($TestDurationHours -eq 0) {
        Write-Host "===> Extension leak test skipped."
        return
    }

    $Job.StepQuiet($MyInvocation.MyCommand.Name, {
        Write-Host "===> Running Extension leak test. Duration: ${TestDurationHours}h..."

        Initialize-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration

        $TestStartTime = Get-Date
        $TestEndTime = ($TestStartTime).AddHours($TestDurationHours)

        Write-Host "It's $TestStartTime. Going to sleep until $TestEndTime."

        $CurrentTime = $TestStartTime
        while ($CurrentTime -lt $TestEndTime) {
            Start-Sleep -s (60 * 10) # 10 minutes
            $CurrentTime = Get-Date
            Write-Host "It's $CurrentTime. Sleeping..."
        }

        Write-Host "Waking up!"

        Clear-TestConfiguration -Session $Session -TestConfiguration $TestConfiguration
        Write-Host "===> Success!"
    })
}
