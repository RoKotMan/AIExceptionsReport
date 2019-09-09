[CmdletBinding()]
param(
    [string]$ApplicationInsightsId,
    [string]$ApplicationInsightsAPIAccessKey,
    [string]$ApplicationInsightsReportFile,
    [string]$StartTime,
    [string]$LastCustomEventName,
    [int]$ApplicationInsightsDelay
)
. "$PSScriptRoot\extension.ps1"

# Get Timespan
$TimeNow = Get-Date
switch ( $StartTime ) {
    "PipelineStartTime" { 
        $StartDateTime = [DateTime]::Parse($Env:SYSTEM_PIPELINESTARTTIME)
        $Timespan = "$($StartDateTime.ToUniversalTime().toString('O'))/$($TimeNow.ToUniversalTime().toString('O'))" 
    }
    "LastHour" { 
        $StartDateTime = (Get-Date).AddHours(-1)
        $Timespan = "PT1H" 
     }
     "LastCustomEvent" {
     # Get CustomEvent timestamp
        $Query = "customEvents | where name == `"$LastCustomEventName`""
        $CustomEventsRows = Get-ApplicationInsightsQuery -ApplicationInsightsId $ApplicationInsightsId -ApplicationInsightsAPIAccessKey $ApplicationInsightsAPIAccessKey -Query $Query -Timespan "PT720H"
        $CustomEvents =@()
        foreach ( $RowAppIns in $CustomEventsRows.rows) {
            $CustomEvent = @{}
            $CustomEventsRows.columns | % {
                $CustomEvent."$($_.name)" = $RowAppIns[[array]::indexof($CustomEventsRows.columns.name,$_.name)]
            }
            $CustomEvents += [pscustomobject]$CustomEvent
        }
        if ( $CustomEvents.Count -eq 0 ) {
            Write-Warning "Application Insights custom event with name `"$LastCustomEventName`" not found."
            throw
        }
        $LastCustomEventtimestamp = ($CustomEvents | Sort-Object -Property "timestamp" -Descending | Select-Object -First 1).timestamp
        $StartDateTime = [DateTime]::Parse($LastCustomEventtimestamp)
        $Timespan = "$LastCustomEventtimestamp/$($TimeNow.ToUniversalTime().toString('O'))" 
     }
    Default { 
        $StartDateTime = (Get-Date).AddHours(-12)
        $Timespan = "PT12H" 
    }
}

Write-Host "Waiting for $ApplicationInsightsDelay s..."
Start-Sleep $ApplicationInsightsDelay
Write-Host "Query Application Insights exceptions"
$ApplicationInsightsReportPath = Join-Path $Env:System_DefaultWorkingDirectory $ApplicationInsightsReportFile

# Getting ApplicationInsights exceptions
$Query = "exceptions"
$ExceptionRows = Get-ApplicationInsightsQuery -ApplicationInsightsId $ApplicationInsightsId -ApplicationInsightsAPIAccessKey $ApplicationInsightsAPIAccessKey -Query $Query -Timespan $Timespan
# parce row data and create array
$Exceptions = @()
foreach ( $RowAppIns in $ExceptionRows.rows) {
    $Exception = @{}
    $ExceptionRows.columns | % {
        $Exception."$($_.name)" = $RowAppIns[[array]::indexof($ExceptionRows.columns.name,$_.name)]
    }
    $Exceptions += [pscustomobject]$Exception
}
# get unique Exceptions
Write-Host "Exceptions count: `"$($Exceptions.Count)`""
Write-Host "Will be collect unique types of exceptions only."

$Exceptions = $Exceptions | Sort-Object -Property "type" -Unique

# create blank report file
@"
<?xml version="1.0" encoding="utf-8"?>
<assemblies >
  <assembly >
    <collection >
    </collection>
  </assembly>
</assemblies>
"@ | Out-File $ApplicationInsightsReportPath -Force -Encoding utf8

$XmlDocument = [xml] (Get-Content $ApplicationInsightsReportPath)
# set assembly attributes
$AssemblyNode = Get-XmlNode -XmlDocument $XmlDocument -NodePath "assemblies.assembly"
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "name" -AttributeValue "Application Insights Exception"
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "run-date" -AttributeValue $StartDateTime.ToString("yyyy-MM-dd")
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "run-time" -AttributeValue $StartDateTime.ToString("HH:mm:ss")
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "total" -AttributeValue $Exceptions.Count
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "passed" -AttributeValue 0
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "failed" -AttributeValue $Exceptions.Count
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "skipped" -AttributeValue 0
Add-XmlAttribute -XmlDocument $XmlDocument -Node $AssemblyNode -AttributeName "time" -AttributeValue ($TimeNow - $StartDateTime).TotalSeconds
# set collection attributes
$CollectionNode = Get-XmlNode -XmlDocument $XmlDocument -NodePath "assemblies.assembly.collection"
Add-XmlAttribute -XmlDocument $XmlDocument -Node $CollectionNode -AttributeName "name" -AttributeValue "Application Insights Exception"
Add-XmlAttribute -XmlDocument $XmlDocument -Node $CollectionNode -AttributeName "total" -AttributeValue $Exceptions.Count
Add-XmlAttribute -XmlDocument $XmlDocument -Node $CollectionNode -AttributeName "passed" -AttributeValue 0
Add-XmlAttribute -XmlDocument $XmlDocument -Node $CollectionNode -AttributeName "failed" -AttributeValue $Exceptions.Count
Add-XmlAttribute -XmlDocument $XmlDocument -Node $CollectionNode -AttributeName "skipped" -AttributeValue 0
Add-XmlAttribute -XmlDocument $XmlDocument -Node $CollectionNode -AttributeName "time" -AttributeValue ($TimeNow - $StartDateTime).TotalSeconds
foreach ($Exception in $Exceptions) {
    $TestNode = New-XmlNode -XmlDocument $XmlDocument -Node $CollectionNode -NodePath "test" -DuplicatesAllowed
    Add-XmlAttribute -XmlDocument $XmlDocument -Node $TestNode -AttributeName "name" -AttributeValue $Exception.type
    Add-XmlAttribute -XmlDocument $XmlDocument -Node $TestNode -AttributeName "type" -AttributeValue "Application Insights Exception"
    Add-XmlAttribute -XmlDocument $XmlDocument -Node $TestNode -AttributeName "method" -AttributeValue $Exception.method
    Add-XmlAttribute -XmlDocument $XmlDocument -Node $TestNode -AttributeName "time" -AttributeValue ([DateTime]::Parse($Exception.timestamp) - $StartDateTime).TotalSeconds
    Add-XmlAttribute -XmlDocument $XmlDocument -Node $TestNode -AttributeName "result" -AttributeValue "Fail"
    $FailureNode = New-XmlNode -XmlDocument $XmlDocument -Node $TestNode -NodePath "failure"
    $Message = "Event time: $($Exception.timestamp)`nMessage: $($Exception.outerMessage)`nException type: $($Exception.type)`nFailed method: $($Exception.problemId)`ncustomDimensions: $($Exception.customDimensions.ToString())"
    $MessageNode = New-XmlNode -XmlDocument $XmlDocument -Node $FailureNode -NodePath "message"
    Add-XmlCDataSection -XmlDocument $XmlDocument -Node $MessageNode -CDataSectionValue $Message
    $StackTraceNode = New-XmlNode -XmlDocument $XmlDocument -Node $FailureNode -NodePath "stack-trace"
    Add-XmlCDataSection -XmlDocument $XmlDocument -Node $StackTraceNode -CDataSectionValue $Exception.details.ToString()
}
Write-Host "Save results to `"$ApplicationInsightsReportPath`""
$XmlDocument.Save($ApplicationInsightsReportPath)

