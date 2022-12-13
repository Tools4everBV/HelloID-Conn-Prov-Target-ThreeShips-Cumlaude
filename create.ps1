#####################################################
# HelloID-Conn-Prov-Target-ThreeShips-Cumlaude-Create
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
# This is a basic account mapping to create a user of any type in ThreeShips Cumlaude. There are far more properties that can be
# added. Also properties that differentiate between an employee or student. Like; studyProgress or the EckID.
$account = [PSCustomObject]@{
    user_id   = $p.ExternalId
    source    = $($config.Source)
    source_id = $p.ExternalId
    fn        = $p.DisplayName
    email     = $p.Contact.Business.Email

    # The password could be mandatory depending on the configuration of ThreeShips Cumlaude.
    password = ''
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Set to true if accounts in the target system must be updated
$updatePerson = $false

#region functions
function Initialize-CumlaudePowerShellSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $UserName,

        [Parameter(Mandatory)]
        [SecureString]
        $Password,

        [Parameter(Mandatory)]
        $BaseUrl
    )

    $script:CurrentDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    $script:CumlaudeUserService = New-WebServiceProxy "$BaseUrl/services/UserServices.asmx?wsdl"
    $script:CumlaudeIMSImportService = New-WebServiceProxy "$BaseUrl/services/IMSEnterpriseImport.asmx?wsdl"
    $script:CumlaudeSecurityService = New-WebServiceProxy "$BaseUrl/services/Security.asmx?wsdl"

    $script:CumlaudeSecurityService.CookieContainer = [System.Net.CookieContainer]::new()
    $script:CumlaudeSecurityService.Url = "$BaseUrl/services/Security.asmx"
    $script:CumlaudeSecurityService.proxy = $proxy

    $script:CumlaudeIMSImportService.CookieContainer = $script:CumlaudeSecurityService.CookieContainer
    $script:CumlaudeIMSImportService.Url = "$BaseUrl/services/IMSEnterpriseImport.asmx"
    $script:CumlaudeIMSImportService.Proxy = $proxy

    $script:CumlaudeUserService.CookieContainer = $script:CumlaudeSecurityService.CookieContainer
    $script:CumlaudeUserService.Url = "$BaseUrl/services/UserServices.asmx"
    $script:CumlaudeUserService.Proxy = $proxy

    Connect-CumlaudeWebService -UserName $UserName -Password $Password
}

function Connect-CumlaudeWebService {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $UserName,

        [Parameter(Mandatory)]
        [SecureString]
        $Password
    )

    $challengeResponse = ($script:CumlaudeSecurityService.InitializeLogin($UserName)) | ConvertFrom-Json
    $jsonSalt = $challengeResponse.salt
    $jsonChallenge = $challengeResponse.challenge
    $jsonIterations = $challengeResponse.Iterations

    $splatParameters = @{
        Password   = $Password
        Salt       = $jsonSalt
        Challenge  = $jsonChallenge
        Iterations = $jsonIterations
    }
    $finalHash = ConvertTo-CumlaudeSha1Hash @splatParameters

    $response = $script:CumlaudeSecurityService.Login($finalHash)
    if ($response){
        $script:Authenticated = $response
    } else {
        $script:Authenticated = $false
    }
}

function Disconnect-CumlaudeWebService {
    $script:Authenticated = $false
    $script:CumlaudeSecurityService.Logout()
}

function ConvertTo-CumlaudeSha1Hash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [SecureString]
        $Password,

        [Parameter(Mandatory)]
        [string]
        $Salt,

        [Parameter(Mandatory)]
        [string]
        $Challenge,

        [Parameter(Mandatory)]
        [int]
        $Iterations
    )

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $passWordString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

    $sha1 = [System.Security.Cryptography.SHA1CryptoServiceProvider]::new()
    $sha1.Initialize()

    $hash = $passWordString
    for ($i = 0; $i -lt $Iterations; $i++) {
        [byte[]] $bytes = $sha1.ComputeHash([System.Text.Encoding]::Default.GetBytes(($hash + $Salt + $passWordString)))
        $hashStringBuilder = [System.Text.StringBuilder]::new()
        foreach ($byte in $bytes){
            $null = $hashStringBuilder.Append($byte.ToString('x2'))
        }

        $hash = $hashStringBuilder.ToString()
    }

    $response = $hash + $Challenge
    $finalHashStringBuilder = [System.Text.StringBuilder]::new()
    [byte[]] $finalBytes = $sha1.ComputeHash([System.Text.Encoding]::Default.GetBytes($response))
    foreach ($finalByte in $finalBytes){
        $null = $finalHashStringBuilder.Append($finalByte.ToString('x2'))
    }

    $finalHashStringBuilder.ToString()
}

function Get-CumlaudeXmlNode {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [xml]$XmlDocument,

        [Parameter(Mandatory)]
        [string]$NodePath
    )

    $namespaceURI = $XmlDocument.DocumentElement.NamespaceURI
    $nodeSeparatorCharacter = '.'

    $xmlNsManager = [System.Xml.XmlNamespaceManager]::new($XmlDocument.NameTable)
    $xmlNsManager.AddNamespace("ns", $namespaceURI)
    $fullyQualifiedNodePath = "/ns:$($NodePath.Replace($($nodeSeparatorCharacter), '/ns:'))"

    $node = $XmlDocument.SelectSingleNode($fullyQualifiedNodePath, $xmlNsManager)
    Write-Output $node
}
#endregion

# Begin
try {
    Write-Verbose 'Connecting to ThreeShip-Cumlaude'
    $connectParams = @{
        UserName = $($config.UserName)
        Password = ConvertTo-SecureString $($config.Password) -AsPlainText -Force
        BaseUrl  = $($config.BaseUrl)
    }
    Initialize-CumlaudePowerShellSession @connectParams

    # Verify if a user must be either [created and correlated], [updated and correlated] or just [correlated]
    # 'UserStatus = 1' indicates the account must be created.
    # 'UserStatus = 2' indicates the account must be updated.
    $responseUser = $script:CumlaudeUserService.GetUserByLoginId2($account.source_id)
    if ($null -eq $responseUser.UserWithSource){
        $action = 'Create-Correlate'
        $userStatus = 1
    } elseif ($updatePerson -eq $true) {
        $action = 'Update-Correlate'
        $userStatus = 2
    } else {
        $action = 'Correlate'
    }

    # Add a warning message showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $action ThreeShips-Cumlaude account for: [$($p.DisplayName)], will be executed during enforcement"
    }

    $settingsXML =[System.Xml.Linq.XElement]::new("properties",
        [System.Xml.Linq.XElement]::new("datasource", "$($config.Source)"),

        # The value 'N@TSchool!' seems to be a fixed value.
        [System.Xml.Linq.XElement]::new("target", "N@Tschool!"),
        [System.Xml.Linq.XElement]::new("datetime", $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))
    )
    $settingXMLNode = Get-CumlaudeXmlNode -XmlDocument $settingsXML -NodePath 'properties'

    # The value 'N@TSchool!' seems to be a fixed value.
    $userXML = "
    <enterprise>
        <properties>
            <datasource>$($config.source)</datasource>
            <target>N@Tschool!</target>
            <datetime>$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))</datetime>
        </properties>
        <person recstatus=`"$userStatus`">
            <userid password=`"$($account.password)`">$($account.user_id)</userid>
        <sourcedid>
            <source>$($account.source))</source>
            <id>$($account.source_id)</id>
        </sourcedid>
            <name>
                <fn>$($account.fn)</fn>
            </name>
            <email>$($account.email)</email>
        </person>
    </enterprise>"

    $log = $null

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Create-Correlate' {
                Write-Verbose "Creating and correlating ThreeShips-Cumlaude account"
                $CumlaudeIMSImportService.ProcessWithXMLResults($settingXMLNode, $userXML, [ref]$log)
                break
            }

            'Update-Correlate'{
                Write-Verbose "Updating and correlating ThreeShips-Cumlaude account"
                $CumlaudeIMSImportService.ProcessWithXMLResults($settingXMLNode, $userXML, [ref]$log)
                break
            }

            'Correlate' {
                Write-Verbose "Correlating ThreeShips-Cumlaude account"
                $accountReference = $responseUser.UserWithSource.Loginid
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                        Message = "$action account was successful. AccountReference is: [$accountReference]"
                        IsError = $false
                    })
                break
            }
        }

        if ($null -ne $log){
            $xml = [System.Xml.XmlDocument]::new()
            $xml.LoadXml($log)
            if ($xml.entries.entry.ProceedResultCaption -eq 'SUCCESS'){
                $success = $true
                $accountReference = $xml.entries.entry.MainObjectRef.Split(' ')[0]
                $auditLogs.Add([PSCustomObject]@{
                        Message = "$action account was successful. AccountReference is: [$accountReference]"
                        IsError = $false
                    })
            } else {
                throw $xml.entries.entry.description
            }
        }
    }
} catch {
    $success = $false
    $ex = $PSItem
    $auditMessage = "Could not $action ThreeShips-Cumlaude account. Error: $($ex.Exception.Message)"
    Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
# End
} finally {
    $null = Disconnect-CumlaudeWebService
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        Account          = $account
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
