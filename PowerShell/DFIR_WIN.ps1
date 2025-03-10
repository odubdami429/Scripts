#======================================================================================
#Author: Dami Odubanjo
#This script collects various DFIR artifact from a Windows Endpoint by saving the output of various commands to a txt file 
#Once the the script is done the output files will be placed in C:\Temp\DFIR_Output
#======================================================================================

#Creates a folder that will contain all the artifacts
New-Item -Path "C:\Temp" -Name "DFIR_Output" -ItemType "directory";
 

#==========================================
#Collecting System Information
#==========================================

#Collect User and System information
systeminfo | Out-File "C:\Temp\DFIR_Output\system_info.txt";
query user | Out-File -append "C:\Temp\DFIR_Output\system_info.txt";
whoami /all | Out-File -append "C:\Temp\DFIR_Output\system_info.txt";
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\system_info.txt";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\system_info.txt";

#Collect list of Running Processes
tasklist /v | Out-File "C:\Temp\DFIR_Output\running_processes.txt";
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\running_processes.txt";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\running_processes.txt"

#Collect list of scheduled task
Get-ChildItem C:\Windows\System32\Tasks | Out-File "C:\Temp\DFIR_Output\scheduled_task.txt";
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\scheduled_task.txt";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\scheduled_task.txt"

#Collect list of system-level installed apps 
Get-ItemProperty `
  HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, `
  HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*, `
  HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* `
| Select-Object DisplayName, DisplayVersion, Publisher, InstallDate `
| Export-Csv -Path "C:\Temp\DFIR_Output\system_installed_apps.csv" -NoTypeInformation
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\system_installed_apps.csv";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\system_installed_apps.csv"

#Collect list of user-level installed apps 
# Gather all user SIDs from HKEY_USERS except .DEFAULT and *_Classes
$allUserSIDs = Get-ChildItem 'Registry::HKEY_USERS' `
  | Where-Object { $_.Name -notmatch "(_Classes$|\.DEFAULT$)" }

# Initialize a list to hold all uninstall entries
$allUninstalls = @()

foreach ($sid in $allUserSIDs) {
    $uninstallPath = "$($sid.Name)\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    
    if (Test-Path "Registry::$uninstallPath") {
        Get-ChildItem "Registry::$uninstallPath" -ErrorAction SilentlyContinue |
        ForEach-Object {
            # Grab the uninstall properties for each subkey
            $props = Get-ItemProperty $_.PSPath
            
            # Create a new object including the SID as a field
            $allUninstalls += [PSCustomObject]@{
                UserSID       = $sid.Name
                PSChildName   = $props.PSChildName
                DisplayName   = $props.DisplayName
                DisplayVersion= $props.DisplayVersion
                Publisher     = $props.Publisher
                InstallDate   = $props.InstallDate
            }
        }
    }
}

# Now export all collected entries to CSV
$allUninstalls | Export-Csv -Path "C:\Temp\DFIR_Output\user_installed_apps.csv" -NoTypeInformation
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\user_installed_apps.csv";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\user_installed_apps.csv"


#==========================================
#Collecting Networking Information
#==========================================

#Collect list of UDP connections
Get-NetUDPEndpoint  | Select-Object LocalAddress,LocalPort,CreationTime,OwningProcess,@{Name="Process";Expression={(Get-Process -Id $_.OwningProcess).ProcessName}} | ft -auto | Out-File "C:\Temp\DFIR_Output\udp_connections.txt";
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\udp_connections.txt";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\udp_connections.txt"

#Collect list of TCP connections
Get-NetTCPConnection |  select-object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,CreationTime,OwningProcess, @{Name="Process";Expression={(Get-Process -Id $_.OwningProcess).ProcessName}} | ft -auto | Out-File "C:\Temp\DFIR_Output\tcp_connections.txt";
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\tcp_connections.txt";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\tcp_connections.txt"

#Collect list of Wifi Profiles
netsh wlan show profiles | Out-File "C:\Temp\DFIR_Output\wifi_profiles.txt";
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\wifi_profiles.txt";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\wifi_profiles.txt"

#Collect list of all firewall rules on the system
$fwRules = Get-NetFirewallRule | ForEach-Object {
    # Collect the port filter (protocol, local port, remote port)
    $portFilter = $_ | Get-NetFirewallPortFilter
    # Collect the address filter (remote address)
    $addrFilter = $_ | Get-NetFirewallAddressFilter

    # Return a custom object with all the relevant fields
    [PSCustomObject]@{
        Name           = $_.Name
        DisplayName    = $_.DisplayName
        DisplayGroup   = $_.DisplayGroup
        Protocol       = $portFilter.Protocol
        LocalPort      = $portFilter.LocalPort
        RemotePort     = $portFilter.RemotePort
        RemoteAddress  = $addrFilter.RemoteAddress
        Enabled        = $_.Enabled
        Profile        = $_.Profile
        Direction      = $_.Direction
        Action         = $_.Action
    }
}

# Export firewall rules to a CSV file
$fwRules | Export-Csv -Path "C:\Temp\DFIR_Output\firewall_settings.csv" -NoTypeInformation
"`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\firewall_settings.csv";
Get-Date | Out-File -append "C:\Temp\DFIR_Output\firewall_settings.csv"


#==========================================
#Windows and Browser History log files
#==========================================

#Creates a folder that will contain all copied windows event logs
New-Item -Path "C:\Temp\DFIR_Output\" -Name "windows_logs" -ItemType "directory";

#Copy over the Security, Systems and Application windows event logs 
Copy-Item "C:\Windows\System32\winevt\Logs\Security.evtx" -Destination "C:\Temp\DFIR_Output\windows_logs"
Copy-Item "C:\Windows\System32\winevt\Logs\System.evtx" -Destination "C:\Temp\DFIR_Output\windows_logs"
Copy-Item "C:\Windows\System32\winevt\Logs\Application.evtx" -Destination "C:\Temp\DFIR_Output\windows_logs"



#Creates a folder that will contain all copied browser history files
New-Item -Path "C:\Temp\DFIR_Output\" -Name "browser_history" -ItemType "directory";

$Manufacturer = (Get-CimInstance win32_computersystem -Property Manufacturer).Manufacturer #Addding the manufacturer of a device to a variable
Write-Host $Manufacturer

#Check if the device in question is a VM because the user app data and files are stored in the D-Drive for VM users
if ($Manufacturer -like "*Amazon EC2*") {


    Write-Host "Windows VDI Detected"

    #Collect list of all files and folders in the user's D drive
    Get-ChildItem D:\Users -Recurse | Out-File "C:\Temp\DFIR_Output\user_D_drive_files.txt";
    "`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\user_D_drive_files.txt";
    Get-Date | Out-File -append "C:\Temp\DFIR_Output\user_D_drive_files.txt"

    $d_drive_users = (Get-ChildItem D:\Users).Name

    foreach ($d_drive_users in $d_drive_users) {
        #Grab the Chrome history files for D drive users
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Google\Chrome\User Data\Default\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Chrome_Default_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 1\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Chrome_Profile_1_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 2\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Chrome_Profile_2_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 3\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Chrome_Profile_3_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 4\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Chrome_Profile_4_History"

        #Grab the Edge history files for D drive users
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Microsoft\Edge\User Data\Default\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Edge_Default_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 1\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Edge_Profile_1_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 2\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Edge_Profile_2_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 3\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Edge_Profile_3_History"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 4\History" "C:\Temp\DFIR_Output\browser_history\${d_drive_users}_Edge_Profile 4 History"

        #Creates a folder that will contain all copied windows logs and powershell history files
        New-Item -Path "C:\Temp\DFIR_Output\" -Name "${d_drive_users} powershell_logs" -ItemType "directory";
        Copy-Item "D:\Users\${d_drive_users}\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" "C:\Temp\DFIR_Output\${d_drive_users} powershell_logs"
        Copy-Item "D:\Users\${d_drive_users}\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\Visual Studio Code Host_history.txt" "C:\Temp\DFIR_Output\${d_drive_users} powershell_logs"
    }

}
else {

    Write-Host "Windows Laptop Detected"
    
    #Collect list of all files and folders in the user's C drive
    Get-ChildItem C:\Users -Recurse | Out-File "C:\Temp\DFIR_Output\user_C_drive_files.txt";
    "`n`nDate of Artifact Collection:" | Out-File -append "C:\Temp\DFIR_Output\user_C_drive_files.txt";
    Get-Date | Out-File -append "C:\Temp\DFIR_Output\user_C_drive_files.txt"
    
    #Copy over the Powershell history log file and chrome history file for all user profiles on the endpoint
    $c_drive_users = (Get-ChildItem C:\Users).Name
    foreach ($c_drive_users in $c_drive_users) {
        #Grab the Chrome history files for C drive users
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Google\Chrome\User Data\Default\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Chrome_Default_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 1\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Chrome_Profile_1_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 2\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Chrome_Profile_2_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 3\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Chrome_Profile_3_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Google\Chrome\User Data\Profile 4\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Chrome_Profile 4 History"

        #Grab the Edge history files for C drive users
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Microsoft\Edge\User Data\Default\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Edge_Default_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 1\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Edge_Profile_1_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 2\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Edge_Profile_2_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 3\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Edge_Profile_3_History"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Local\Microsoft\Edge\User Data\Profile 4\History" "C:\Temp\DFIR_Output\browser_history\${c_drive_users}_Edge_Profile 4 History"

        #Creates a folder that will contain all copied powershell history files
        New-Item -Path "C:\Temp\DFIR_Output\" -Name "${c_drive_users} powershell_logs" -ItemType "directory";
        #Copy over the powerhell command history file
        Copy-Item "C:\Users\${c_drive_users}\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" "C:\Temp\DFIR_Output\${c_drive_users} powershell_logs"
        Copy-Item "C:\Users\${c_drive_users}\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\Visual Studio Code Host_history.txt" "C:\Temp\DFIR_Output\windows_logs\${c_drive_users} powershell_logs"
    }

  }
