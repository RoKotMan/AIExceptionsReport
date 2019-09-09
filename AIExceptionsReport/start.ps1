[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation
try {
    Import-Module $PSScriptRoot\ps_modules\VstsTaskSdk
    # Import the localized strings.
    Import-VstsLocStrings "$PSScriptRoot\task.json"

    $ApplicationInsightsId = Get-VstsInput -Name ApplicationInsightsId -Require
    $ApplicationInsightsAPIAccessKey = Get-VstsInput -Name ApplicationInsightsAPIAccessKey -Require
    $StartTime = Get-VstsInput -Name StartTime -Require
    $LastCustomEventName = Get-VstsInput -Name LastCustomEventName -Require
    $ApplicationInsightsDelay = Get-VstsInput -Name ApplicationInsightsDelay -Require
    $ApplicationInsightsReportFile = Get-VstsInput -Name ApplicationInsightsReportFile -Require

    . "$PSScriptRoot\main.ps1" -ApplicationInsightsId $ApplicationInsightsId -ApplicationInsightsAPIAccessKey $ApplicationInsightsAPIAccessKey `
        -StartTime $StartTime -LastCustomEventName $LastCustomEventName `
        -ApplicationInsightsDelay $ApplicationInsightsDelay -ApplicationInsightsReportFile $ApplicationInsightsReportFile

}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}