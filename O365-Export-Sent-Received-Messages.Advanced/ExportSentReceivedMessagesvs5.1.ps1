Clear-Host
$desc = @"

  DEVELOPED BY : Guilherme Lima
  PLATFORM     : O365
  WEBSITE      : http://solucoesms.com.br
  WEBSITE2     : http://github.com/guilhermelimait
  LINKEDIN     : https://www.linkedin.com/in/guilhermelimait/
  DESCRIPTION  : Export sent and received messages from the valid users informed during specifig ranges like from 0h to 06h, 06h to 08h, 08h to 18h, 18h to 20h, 20h to 22h and 22h to 23h59

"@
Write-host $desc


<#===========================================

  VARIABLES
  
===========================================#>

# Log and Input file names
$LogExportedUsersData = ".\LOG-ExportData.csv"
$validatedusers = ".\LOG-ValidUsers.csv"
$notvalidatedusers = ".\LOG-InvalidUsers.csv"

# Export data from how many last days?
$Monitoringdays = 7
# User who will be connected to the O365
$adminuser = "admin@domain.com"

<#===========================================

  FUNCTIONS
  
===========================================#>

Function ConnectToO365 {
	$credential = Get-Credential -UserName $adminuser -Message "Please insert user and password to connect to O365"
	import-module msonline
	Connect-MsolService -Credential $credential
	Connect-EXOPSSession -Credential $credential 
}

function MessageInfo1 ($text1, $color) {
	write-host "$text1" -foreground $color
}

function MessageInfo3 ($text1, $text2, $text3, $color) {
	write-host "$text1"-foreground white -nonewline
	write-host "$text2"-foreground $color -nonewline
	write-host "$text3"-foreground white
}

function MessageInfo5 ($text1, $text2, $text3, $text4, $text5, $color) {
	write-host "$text1"-foreground white -nonewline
	write-host "$text2"-foreground darkcyan -nonewline	
	write-host "$text3"-foreground white -nonewline
	write-host "$text4"-foreground darkcyan -nonewline
	write-host "$text5"-foreground white
}

function FileExistence ($typefile, $file, $header){
	MessageInfo1 " + Locating $typefile file..." Darkcyan
	do{
		if (Test-Path -path $file) {
			MessageInfo3 "  - File " "$file" " found." "cyan"
			$fileexist = $true
			break
		} else {
			MessageInfo1 "  - File $file not found ..." "Red"
			MessageInfo3 "  - File " "$file" " created succesfully." "cyan"
			new-item -type file -name $file |out-null
			add-content $file -value $header
			$fileexist = $false
		}
	}until ($fileexist = $true)
}
$StartDateLOG = (get-date -format "HH:mm:ss")
ConnectToO365

Write-Host
MessageInfo1 " + Starting to Export Sent / Received Messages:" "Cyan"

#checking file existence
#$output = "MonitoringReport-$(get-date -f yyyy.MM.ddTHH.mm.ss).csv"
$output = ".\MonitoringReport-$(get-date -f yyyy.MM.dd).csv"
FileExistence "output" $output "id; Date; Mail; Country; City; Department; sent00h06h; received00h06h; Sent06h08h; Received06h08h; Sent08h18h; Received08h18h; Sent18h20h; Received18h20h; Sent20h22h; Received20h22h; Sent22h24h; Received22h24h" 
$fileexist = $false  #if fileexist is equal false, the file will be recreated everytime

FileExistence "input" $validatedusers ""
$TotalValidatedUsers = (get-content $validatedusers).count -1
write-host
FileExistence "log" $LogExportedUsersData "Id; USERNAME"
[int] $LastIdFromExportedData = import-csv $LogExportedUsersData -delimiter ";" | select-object -expandproperty id -last 1 
[Int] $CountSentMessages = $CountReceivedMessages = 0
$x = $LastIdFromExportedData

write-host
MessageInfo1 " + Information matrix ..." DarkCyan
MessageInfo1 "  - Previously exported data:   $LastIdFromExportedData " white
MessageInfo1 "  - Total users found       :   $TotalValidatedUsers " white
write-host
MessageInfo1 " + Exporting data from the last exported line ..." DarkCyan

For ($x -eq $LastIdFromExportedData; $x -lt $TotalValidatedUsers; $x++){ # start from the last exported line until end of input file
	[string] $mail = import-csv $validatedusers -delimiter ";"| Select-Object -Index $x | Select-Object -ExpandProperty mail
	$UPN = get-mailbox $mail | select-object -expandproperty UserPrincipalName
	$country = get-msoluser -UserPrincipalName $UPN | select-object -expandproperty country
	$city = get-msoluser -UserPrincipalName $UPN | select-object -expandproperty city
	$department = get-msoluser -UserPrincipalName $UPN | select-object -expandproperty department
	$index = $x+1
	Write-Host
	MessageInfo1 "  > [$index] of [$TotalValidatedUsers] Gathering data from user: $mail" White
	For (($day = $Monitoringdays); ($day -gt 0); ($day--)){
		write-host
			Function GetMessageCount ($StartHour, $StartMinute, $EndHour, $EndMinute, $DifferenceBetweenTimeZones){
			#start of message count timezone function
			[Int] $CountSentMessages = $CountReceivedMessages = 0
			$script:timezonedatestart = ([DateTime]::Today.AddDays(-$day).AddHours($StartHour + $DifferenceBetweenTimeZones).addminutes($StartMinute)).tostring("yyyy-MM-dd HH:mm") #timezone informed in parameter of the function
			$script:timezonedateend = ([DateTime]::Today.AddDays(-$day).AddHours($EndHour + $DifferenceBetweenTimeZones).addminutes($EndMinute)).tostring("yyyy-MM-dd HH:mm")
			$script:datestart = ([DateTime]::Today.AddDays(-$day).AddHours($StartHour).addminutes($StartMinute)).tostring("yyyy-MM-dd HH:mm") #no timezone applied, just a visual information
			$script:dateend = ([DateTime]::Today.AddDays(-$day).AddHours($EndHour).addminutes($EndMinute)).tostring("yyyy-MM-dd HH:mm")
			#end of message count timezone function
			Get-MessageTrace -senderaddress $mail -startdate $timezonedatestart -enddate $timezonedateend | ForEach-Object {$CountSentMessages++}
			Get-MessageTrace -recipientaddress $mail -startdate $timezonedatestart -enddate $timezonedateend | ForEach-Object {$CountReceivedMessages++}
			MessageInfo5 "  - Data from " "$datestart" " to " "$dateend" " [ $CountSentMessages | $CountReceivedMessages ]"
			
			return "$CountSentMessages; $CountReceivedMessages"
		}
		$value1 = GetMessageCount 00 00 06 00 -6 #inform the time slot based in Hour Minute Hour Minute Timezone difference
		$value2 = GetMessageCount 06 00 08 00 -6 #inform the time slot based in Hour Minute Hour Minute Timezone difference
		$value3 = GetMessageCount 08 00 18 00 -6 #inform the time slot based in Hour Minute Hour Minute Timezone difference
		$value4 = GetMessageCount 18 00 20 00 -6 #inform the time slot based in Hour Minute Hour Minute Timezone difference
		$value5 = GetMessageCount 20 00 22 00 -6 #inform the time slot based in Hour Minute Hour Minute Timezone difference
		$value6 = GetMessageCount 22 00 23 59 -6 #inform the time slot based in Hour Minute Hour Minute Timezone difference
		$reportdate = ([DateTime]::Today.AddDays(-$day).tostring("yyyy-MM-dd"))
		add-content $output -value "$Index; $reportdate; $mail; $country; $city; $department; $value1; $value2; $value3; $value4; $value5; $value6"
		MessageInfo1 "  > Exporting to file..." "Cyan"
	}
	$logDate = Get-date -Format "yyyy-MM-dd HH:mm"
	add-content $LogExportedUsersData -value "$index; $mail; $logDate"
	if ($count -gt 40){
		ConnectToO365 # After 40 users exported the script will ask for reauthenticate
		$count = 0
	}
	$count +=1
}
write-host

<#===========================================

  SEND REPORTS VIA EMAIL
  
===========================================#>

$EndDateLOG = (get-date -format "HH:mm:ss")
$TimeDiffLOG = New-Timespan -Start $StartDateLOG -End $EndDateLOG

$files = Get-ChildItem -Recurse -File | Where-Object { $_.fullname -match "2019"} |
Group-Object -Property Directory |
ForEach-Object {
    @(
        $_.Group |
        Resolve-Path -Relative |   # make relative path
        ForEach-Object Substring 2 # cut '.\ part
    )-join "`n	"
}

$TotalUsersNotFound = ($notvalidatedusers).count -1
$Messagebody = @"

	+ Report Information

	Number of users exported succesfully : $TotalValidatedUsers
	Number of users not found            : $TotalUsersNotFound
	Time Execution                       : $TimeDiffLOG

	+ Files generated

	$files
"@

MessageInfo1 " + Sending Mail results..." Darkcyan

$param = @{
	SmtpServer = 'smtpserver.domain.com'
	From = 'noreply@domain.com'
	To = 'admin1@domain.com', 'admin2@domain.com'
	Subject = "Monitoring Report from " + $datestart + " to " + $dateend
	Body = $Messagebody
	#Body = "Hi,<br /> Please check the report from <b> " + $datestart + "</b> to <b>" + $dateend + "</b> in attachment <br /> Report generated automatically in " + $total + " users." 
	Attachments = $output
}

#Send-MailMessage @param #-bodyashtml
Write-host "  - Mail sent successfully!"
Write-host "  - Time Execution : $TimeDiff"
Write-host 
