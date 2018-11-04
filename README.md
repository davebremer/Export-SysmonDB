# Export-SysmonLogsDB

This module provides a way to export Sysmon Logs into a SQLite database with a seperate table for 
each type ID

##Functions

For exporting there is:

1. Export-SysmonDB
  * Reads either the live sysmon logs, or an offline saved evtx file
  * Each event is loaded into a table for that particular event-id
  * There are a bunch of flags which manipulate `get-WinEvent` used inside the script to select specific types, date range, etc. For eg - if you only want events since a particular date, or a maximum number of events
  
2. Register-SysmonLogsDB 
  * Loads the event as a record in the approapriate table
  
3. New-SysmonDB
  * Creates a new SQLite database with seperate tables for each event type
  * You can get a list of these events with
     Get-WinEvent -ListProvider "Microsoft-Windows-Sysmon" ).Events | sort id | Select id,description |format-table -wrap
 
 ##Built With
 
 I use [PSSQLite](https://github.com/RamblingCookieMonster/PSSQLite) by @RamblingCookieMonster 
