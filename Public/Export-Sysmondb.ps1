
function Export-SysmonLogsDB {
<#
.Synopsis
    Exports sysmon logs to a SQLite databaase

.DESCRIPTION
    Exports sysmon logs to a SQLite database. 
    If no database is stated then sysmonlogs.sqlite is created in the current directory.
    The frequency of each event ID is written to screen at the end

.PARAMETER Database
    The location of the database file to be used

.PARAMETER File
    The location of a saved sysmon EVTX file

.PARAMETER ID
    The ID's that you want to export - can be an array of integers. These must be valid Sysmon event IDs

.PARAMETER StartTime
    The earliest time for logs to be exported

.PARAMETER EndTime
    The latest time for logs to be exported

.PARAMETER MaxEvents
 Specifies the maximum number of events that are returned. Enter an integer. The default is to return all the events in the logs or files.

.PARAMETER CopyEVT
 Creates a copy of the event file, either by exporting from "Microsoft-Windows-Sysmon/Operational" or copying from a local file specified with 
 the -File parameter. If a local file is not specified then the exported logs will be names "sysmon.evtx".

 This does NOT work for a remote computer at present #TODO


 .PARAMETER ComputerName
  Name of remote computer

 .PARAMETER Laps
 Indicates that a LAPS credential is needed. This requires that the Get-LapsCred function is available, from ADTools

.EXAMPLE
    Export-SysmonLogs
    All Sysmon events are dumped to a SQLite database. This could take a while.

.LINK
    https://technet.microsoft.com/en-us/sysinternals/sysmon

.NOTES
 Author: Dave Bremer
 TODO:
    Add validation on database path
    Add validation for ID numbers - could look at extracting ID from event_types in the database

#>

    [cmdletBinding()]
    Param (
            [Parameter(position = 0)]
            #TODO add validation 
            [String]$Database = ("{0}\sysmonlogs.sqlite" -f (get-location)),
            
            [Parameter()]
            [ValidateScript({If(Test-Connection $_ -quiet -count 1){$true}else{Throw "Cannot find or resolve `"$_`""} })]
            [string]$Computername,

            [Parameter()]
            [ValidateScript({If(get-LapsCred $computername){$true}else{Throw "Cannot find a LAPS credential for $computername"} })]
            [switch]$Laps,

            #TODO add validation
            [int[]]$ID,

            [Parameter()]
            [ValidateScript({If(Test-Path $_ -PathType Leaf){$true}else{Throw "Invalid EVTX file given: $_"} })]
            [string]$File,
            
            [Parameter()]
            [string]$StartTime,

            [Parameter()]
            [string]$EndTime,

            [Parameter()]
            [ValidateRange(1, [int]::MaxValue)]
            [int64]$MaxEvents,

            [Parameter()]
            [switch]$CopyEVT     
           )


 BEGIN {
    

    $Freq =  @{}
    $Dir = Split-Path -Path $Database
    If(-not(Test-Path $Database -PathType Leaf)) {
        New-Sysmondb -Database $Database
    }
    write-verbose "Export-sysmondb - Database: $database"
    
   }
 
 PROCESS {
    
 
    if ($file) {
        $HashTable = @{path=$File}
    } else {
        $HashTable = @{logname="Microsoft-Windows-Sysmon/Operational"}
    }

    # if we're grabbing a copy of the events then...
    if ($CopyEVT) {        
        if ($file) {
            copy $File $Dir #copy the file into where-ever the output is set. Could be issues if that's where it is #TO TEST
        } else {
            wevtutil.exe epl "Microsoft-Windows-Sysmon/Operational" $Dir\sysmon.evtx
        } #if file    
    } #if copyEVT

    if ($id) {
        $HashTable.Add("ID", $id)
    }

    if ($StartTime) {
        $HashTable.Add("StartTime", $StartTime)
    }

    if ($EndTime) {
        $HashTable.Add("EndTime", $EndTime)
    }

    write-verbose ("FilterHashtable:`n{0}`n`n" -f $($HashTable| Out-String))

    $getwineventParams = @{FilterHashtable = $HashTable}
 
   if ($ComputerName) {
        $getwineventParams.Add("ComputerName", $ComputerName)
    }

    if ($Laps) {
        $getwineventParams.Add("Credential", (get-lapscred $ComputerName))
    }
   

    if ($MaxEvents) {
        $getwineventParams.Add("MaxEvents", $MaxEvents)
    }

    write-verbose ("WinEvent Hashtable:`n{0}`n`n" -f $($getwineventParams| Out-String))
  
    Get-WinEvent @getwineventParams -ErrorAction SilentlyContinue| ForEach-Object  {
         $Event = $_
         Register-Sysmonlog $Event -database $Database
         $freq.($Event.id) +=1
    } # ForEach-Object in Get-WinEvent
            
}

END {
    #Write the frequency of each type to screen
    $freq.GetEnumerator() |
        select @{n="Type";e={$_.name}},@{n="Frequency";e={$_.value -as [int]}} | 
        sort -Property Type

    #Make a frequency file
    #$freq.GetEnumerator() |  
    #    select @{n="Type";e={$_.name}},@{n="Frequency";e={$_.value -as [int]}} | 
    #    sort -Property Type | 
    #    export-csv "$dir\sysmon-frequency.csv" -NoTypeInformation
    }
}

