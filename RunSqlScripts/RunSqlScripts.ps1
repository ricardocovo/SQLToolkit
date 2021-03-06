﻿# this function runs all the SQL scripts in a supplied folder against the supplied server
[CmdletBinding()]
Param()

Trace-VstsEnteringInvocation $MyInvocation;

Try {
    Import-VstsLocStrings "$PSScriptRoot\Task.json";
    [string]$pathToScripts = Get-VstsInput -Name pathToScripts;
    [string]$serverName = Get-VstsInput -Name serverName;
    [string]$databaseName = Get-VstsInput -Name databaseName;
    [string]$userName = Get-VstsInput -Name userName;
    [string]$userPassword = Get-VstsInput -Name userPassword;
    [string]$queryTimeout = Get-VstsInput -Name queryTimeout;
    [string]$removeComments = Get-VstsInput -Name removeComments;

    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

    $serverName.Split(",") | ForEach-Object {       
        $serverToProcess = $_
        Write-Host "Processing Server " $serverToProcess
        
        $databaseName.Split(",") | ForEach-Object {            
            $databaseToProcess = $_
            Write-Host "Processing database " $databaseToProcess

            $SqlConnection = New-Object System.Data.SqlClient.SqlConnection

            $server = $serverToProcess.Split(":")[0]
            $port = $serverToProcess.Split(":")[1]
            if(![string]::IsNullOrEmpty($port)){
                $serverToProcess = $server + ',' + $port
            }
	
            if ([string]::IsNullOrEmpty($userName)) {
                $SqlConnection.ConnectionString = "Server=$serverToProcess;Initial Catalog=$databaseToProcess;Trusted_Connection=True;Connection Timeout=30;"		
            }
            else {
                $SqlConnection.ConnectionString = "Server=$serverToProcess;Initial Catalog=$databaseToProcess;User ID=$userName;Password=$userPassword;Connection Timeout=30;"
            }

            $handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message -ForegroundColor DarkBlue} 
            $SqlConnection.add_InfoMessage($handler) 
            $SqlConnection.Open()
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.Connection = $SqlConnection
            $SqlCmd.CommandTimeout = $queryTimeout

            Write-Host "Running all scripts in $pathToScripts";

            foreach ($sqlScript in Get-ChildItem -path "$pathToScripts" -Filter *.sql | sort-object) {	
                Write-Host "Running Script " $sqlScript.Name
		
                #Execute the query
                switch ($removeComments) {
                    $true {
                        (Get-Content $sqlScript.FullName | Out-String) -replace '(?s)/\*.*?\*/', " " -split '\r?\ngo\r?\n' -notmatch '^\s*$' |
                            ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
                    }
                    $false {
                        (Get-Content $sqlScript.FullName | Out-String) -split '\r?\ngo\r?\n' |
                            ForEach-Object { $SqlCmd.CommandText = $_.Trim(); $reader = $SqlCmd.ExecuteNonQuery() }
                    }
                }
            }

            $SqlConnection.Close()
            $SqlConnection.Dispose()
        }
    }

    Write-Host "Finished";
}

catch {
    Write-Host "Error running SQL script: $_" -ForegroundColor Red
    throw $_
}

