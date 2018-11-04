function Register-Sysmonlog {
<#
.Synopsis
ConvertFrom a sysmon event, enter into database

.DESCRIPTION



.EXAMPLE
$SysmonEvent = Get-WinEvent -FilterHashtable @{logname="Microsoft-Windows-Sysmon/Operational";Id=255;} | select -first 1
Register-Sysmonlog $SysmonEvent

.LINK
https://technet.microsoft.com/en-us/sysinternals/sysmon

.NOTES
 Author: Dave Bremer
 TODO:
    * Validate database - can it be opened?

#>

    [cmdletBinding(DefaultParametersetName="user")]
    Param ([Parameter (
            Mandatory=$True,
            ValueFromPipelineByPropertyName = $TRUE,
            ValueFromPipeLine = $TRUE,
            Position = 0
                )]
            [ValidateNotNullOrEmpty()]
            [System.Diagnostics.Eventing.Reader.EventLogRecord[]] $Events,

           [Parameter(
            Mandatory=$True,
            ValueFromPipelineByPropertyName = $TRUE,
            ValueFromPipeLine = $TRUE,
            Position = 1
            )]
            [ValidateNotNullOrEmpty()]
            [System.IO.FileInfo]$Database)

 BEGIN {
 write-verbose "register-sysmonlog - Database: $Database"
    
   }
 
 PROCESS {
     Foreach ($event in $events) { 
        $EventArray = $Event.message -split "`r`n"
        
        #The first line of the event message is the Event Type - which we're using as the tablename
        $TableName = ($EventArray[0] -split ":")[0] -replace " ", "_"
        Write-Verbose ("Event type {0}, {1}" -f $Event.Id, ($EventArray[0] -split ":")[0])

        $InsertQuery = ("INSERT INTO {0} `(" -f $TableName)

        $Values = ""
        for ($i=1;$i -lt $EventArray.Count;$i++) {
            if ($i -gt 1) { #add a comma
                $InsertQuery = ("{0}," -f $InsertQuery)
                $Values = ("{0}," -f $Values)  
            }

            #Split the line on ":", take the first one as the table name
            #then join the rest back together for the value
            $item = ($eventarray[$i] -split ":") 
            $fieldname = $item[0]
            $val = ("`'{0}`'" -f ($item[1..($item.length-1)] -join ":").trim())

            $InsertQuery = ("{0}{1}" -f $InsertQuery,$fieldname)
            Write-Verbose ("Item:{0}`r`nValue:{1}" -f $eventarray[$i],$val)
            $values = ("{0}{1}" -f $values,$val)         
        }
        
        $InsertQuery = ("{0}) VALUES `({1}`)" -f $InsertQuery,$values)

        Write-Verbose ("Database: {0}, Query: {1}" -f $Database,$insertquery)
        Invoke-SqliteQuery -Query $InsertQuery -DataSource $Database

    }
}

END {}

}

#$SysmonEvent = Get-WinEvent -FilterHashtable @{logname="Microsoft-Windows-Sysmon/Operational"} | select -first 3
#Register-Sysmonlog $SysmonEvent -database "d:\temp\sm3.sqlite" -Verbose