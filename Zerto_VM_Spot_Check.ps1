#REQUIRES VMWARE PS MODULE
Add-PSSnapin VMware.VimAutomation.Core

# Clear Arrays
$VMListTable = $null
$vmwarelist = $null
$VMList = $null
$VMsInJeopardy = $null


# Zerto Variables
$ZertoServer = "##ZERTO_SERVER_HOSTNAME##"
$ZertoPort = "9669"
$ZertoUser = "##SERVICE_ACCOUNT_WITH_ZERTO_ACCESS##"
$ZertoPassword = "##SERVICE_ACCOUNT_PASSWORD##"

# VMware Variables
$VCServer = "##vCenter_Hostname##"


# Mail Variables
$to = "##ENTER-EMAIL-ADDRESS##"
$from = "##ENTER-EMAIL-ADDRESS##"
$subject = "FIX ZERTO!: VMs that are on MONITORED DataStores that are not in Zerto"
$smtpserver = "##ENTER-SMTP-SERVER##"

# Connect to vCenter
connect-viserver -server $VCServer


# Setting Cert Policy
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
# Building Zerto API string and invoking API
$baseURL = "https://" + $ZertoServer + ":"+$ZertoPort+"/v1/"
# Authenticating with Zerto APIs
$xZertoSessionURI = $baseURL + "session/add"
$authInfo = ("{0}:{1}" -f $ZertoUser,$ZertoPassword)
$authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
$authInfo = [System.Convert]::ToBase64String($authInfo)
$headers = @{Authorization=("Basic {0}" -f $authInfo)}
$sessionBody = '{"AuthenticationMethod": "1"}'
$contentType = "application/json"
$xZertoSessionResponse = Invoke-WebRequest -Uri $xZertoSessionURI -Headers $headers -Method POST -Body $sessionBody -ContentType $contentType
#Extracting x-zerto-session from the response, and adding it to the actual API
$xZertoSession = $xZertoSessionResponse.headers.get_item("x-zerto-session")
$zertSessionHeader = @{"x-zerto-session"=$xZertoSession}
 
# Querying API
$VMListURL = $BaseURL+"vms"
$VMList = Invoke-RestMethod -Uri $VMListURL -TimeoutSec 100 -Headers $zertSessionHeader -ContentType "application/JSON"
$VMListTable = $VMList | select -ExpandProperty VmName
$VMListTable = $VMListTable.ToLower()
$VMListTable = $VMListTable | sort

 
# Get List from vCenter on Datastores Where Datastore has _PRT in Name and Doesnt Have Zerto in name. Also Dont include VMs with rubrik-in the name (mounted vm snapshots)
$vmwarelist = Get-Datastore | Where-Object {$_.Name -like "*_PRT"} | Where-Object {$_.Name -notlike "Zerto*"} | get-vm | Where-Object {$_.Name -notlike "rubrik-*"}  | select -ExpandProperty name | sort
# Convert names to Lowercase
$vmwarelist = $vmwarelist.ToLower()
# Sort List of VMs
$vmwarelist = $vmwarelist | sort 

# Comapare Zerto List and VMware List of VMs
$VMsInJeopardy = Compare-Object $VMListTable $vmwarelist -PassThru

# List VMS in Console that Need to be fixed
$VMsInJeopardy
# Count of VMS in Console that Need to be fixed
$VMsInJeopardy.Count
# Convert Array to String
$VMsInJeopardyBody = $VMsInJeopardy | out-string

# If there are more than 0 VMs in list then send an email with the list
If ($VMsInJeopardy.Count -gt 0) {
  send-mailmessage -from $from -to $to -subject $subject -body $VMsInJeopardyBody -smtpServer $smtpserver

  }  Else {

  'Do Nothing'

}