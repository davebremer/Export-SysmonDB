function New-Sysmondb {

<#
.Synopsis
    Creates a new SQLite3 database with seperate tables for each event type.

.DESCRIPTION
    Creates a new SQLite3 database with seperate tables for each event type. The tables are built dynamically from the sysmon version installed on the system. 

    To get an idea of what they look like run the pwoershell command:
    (Get-WinEvent -ListProvider "Microsoft-Windows-Sysmon" ).Events | sort id  | select id, description | format-table -wrap
    
.EXAMPLE
    Export-SysmonDb
    

.LINK
    https://technet.microsoft.com/en-us/sysinternals/sysmon

.NOTES
 Author: Dave Bremer
 
 Changes:
    2018-11-03 Created

 TODO:
    Validation on parameters - sanity and also protect against overwrite

#>
[cmdletBinding()]
#Requires -modules PSSQLite
Param (
        #TODO Validate path is ok.
        #TODO protect against accidently overwriting an existing DB 
        [Parameter (
            position = 0,
            Mandatory=$True)
        ]
        [System.IO.FileInfo]$Database    
        )


 BEGIN {
    # pssqlite borks if trying to create tables that already exists 
    # AT THE MOMENT - just delete anything that exists
    if ( Test-Path $Database ) {
        Remove-Item $Database  
        Write-warning ("Deleting {0} - I hope you wanted to do that. Its gone now!" -f $Database)  
    }

    write-verbose "New-sysmondb - Database: $Database"
    
}
 
 PROCESS {
    $sysmon_events = (Get-WinEvent -ListProvider "Microsoft-Windows-Sysmon" ).Events | Sort-Object id 
    Write-Verbose ("{0} Event types`r`n`r`n" -f $sysmon_events.Count)

    $createquery = "CREATE TABLE Event_Types(ID INTEGER Primary Key, Name TEXT NOT NULL)"
    write-verbose $createquery
    Invoke-SqliteQuery -Query $createquery -DataSource $Database

    foreach ($event in $sysmon_events) {
        $eventarray = $event.description -split "`r`n"

        #Change spaces to underscore in event name
        $tablename = ($eventarray[0] -split ":")[0] -replace " ", "_" 
        
        $UpdateQuery = ("INSERT INTO Event_Types `(ID,Name`) VALUES `({0},`'{1}`'`)" -f $event.Id,$tablename)
        Write-Verbose $UpdateQuery
        Invoke-SqliteQuery -Query $UpdateQuery -DataSource $Database 

        $createquery = "CREATE TABLE $tablename("

        for ($i=1;$i -lt $eventarray.Count;$i++) {
            if ($i -gt 1) {
                $createquery = ("{0}," -f $createquery)
            }
            $fieldname = ($eventarray[$i] -split ":")[0]
            $datatype = "TEXT"
            $createquery = ("{0}{1} {2}" -f $createquery,$fieldname,$datatype)
        }
        $createquery = ("{0})" -f $createquery)
        Write-Verbose "$createquery `r`n`r`n"
        Invoke-SqliteQuery -Query $createquery -DataSource $Database 
    }
}
END {}
}
