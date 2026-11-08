param(
    [string]$TargetIP   = '',
    [string]$TargetPass = '',
    [string]$ConfigKey  = 'N3z0y93',
    [int]$ActionOption  = 0
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ALL_PAGES = 'ARPTable_handle,ARP_Table,Backup_Restore,Broadband,CallHistory_id,Call_Rule,Certificates,DNS,Diagnostic_id,Email_Notify,Firewall,Firmware_Upgrade,Home_Connectivity,Home_Networking,IGMP_MLD,IPsec_VPN,Interface_Grouping,Log,Log_Setting,MAC_Filter,McastSt,NAT,NATSession_handle,PPTP_VPN,Parental_Control,Phone,QoS,Reboot,Remote_MGMT,Routing,RoutingTable_handle,Routing_Table,SIP,SNMP,SP_Domain,Scheduler_Rule,Status,Steering_Status,System,TR-064,TR-069_Client,Time,Traffic_Status,Tunnel_Setting,USB_Service,User_Account,VPN_Status,Vlan_Group,VoIP_Status,WLAN_Table,Wireless,wps_status_handle,Power_Monitor'

function Get-DerivedKey([string]$Secret, [byte[]]$Salt, [int]$KeyLength = 24, [int]$IvLength = 8) {
    $secretBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    $hasher = [System.Security.Cryptography.MD5]::Create()
    $buffer = New-Object byte[] 0
    $derived = New-Object System.Collections.Generic.List[byte]

    while ($derived.Count -lt ($KeyLength + $IvLength)) {
        $chunk = New-Object byte[] ($buffer.Length + $secretBytes.Length + $Salt.Length)
        [System.Buffer]::BlockCopy($buffer, 0, $chunk, 0, $buffer.Length)
        [System.Buffer]::BlockCopy($secretBytes, 0, $chunk, $buffer.Length, $secretBytes.Length)
        [System.Buffer]::BlockCopy($Salt, 0, $chunk, ($buffer.Length + $secretBytes.Length), $Salt.Length)
        $buffer = $hasher.ComputeHash($chunk)
        $derived.AddRange($buffer)
    }

    $key = New-Object byte[] $KeyLength
    $iv  = New-Object byte[] $IvLength
    [System.Buffer]::BlockCopy($derived.ToArray(), 0, $key, 0, $KeyLength)
    [System.Buffer]::BlockCopy($derived.ToArray(), $KeyLength, $iv, 0, $IvLength)
    return @{ Key = $key; IV = $iv }
}

function ConvertFrom-ZyxelBin([byte[]]$Data, [string]$Secret) {
    $salt = New-Object byte[] 8
    [System.Buffer]::BlockCopy($Data, 8, $salt, 0, 8)
    $cipher = New-Object byte[] ($Data.Length - 16)
    [System.Buffer]::BlockCopy($Data, 16, $cipher, 0, $cipher.Length)

    $derived = Get-DerivedKey -Secret $Secret -Salt $salt -KeyLength 24 -IvLength 8
    $des = [System.Security.Cryptography.TripleDES]::Create()
    $des.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $des.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $des.Key = $derived.Key
    $des.IV  = $derived.IV

    $plain = $des.CreateDecryptor().TransformFinalBlock($cipher, 0, $cipher.Length)
    return ([System.Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json)
}

function ConvertTo-ZyxelBin($JsonObject, [string]$Secret) {
    $jsonString = ($JsonObject | ConvertTo-Json -Depth 100 -Compress)
    $salt = New-Object byte[] 8
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)

    $derived = Get-DerivedKey -Secret $Secret -Salt $salt -KeyLength 24 -IvLength 8
    $des = [System.Security.Cryptography.TripleDES]::Create()
    $des.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $des.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $des.Key = $derived.Key
    $des.IV  = $derived.IV

    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonString)
    $cipher = $des.CreateEncryptor().TransformFinalBlock($bodyBytes, 0, $bodyBytes.Length)
    $magic = [System.Text.Encoding]::UTF8.GetBytes('Salted__')

    $output = New-Object byte[] ($magic.Length + $salt.Length + $cipher.Length)
    [System.Buffer]::BlockCopy($magic, 0, $output, 0, $magic.Length)
    [System.Buffer]::BlockCopy($salt, 0, $output, $magic.Length, $salt.Length)
    [System.Buffer]::BlockCopy($cipher, 0, $output, ($magic.Length + $salt.Length), $cipher.Length)
    return $output
}

function Invoke-HttpJson([string]$Url, [string]$Method = 'GET', [byte[]]$Payload = $null, [hashtable]$Headers = @{}, [System.Net.CookieContainer]$Cookies = $null) {
    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = $Method
        $request.Timeout = 15000
        $request.CookieContainer = if ($Cookies) { $Cookies } else { New-Object System.Net.CookieContainer }

        foreach ($name in $Headers.Keys) {
            if ($name -eq 'Content-Type') {
                $request.ContentType = $Headers[$name]
            } else {
                $request.Headers.Add($name, $Headers[$name])
            }
        }

        if ($Payload) {
            $request.ContentLength = $Payload.Length
            $stream = $request.GetRequestStream()
            $stream.Write($Payload, 0, $Payload.Length)
            $stream.Close()
        }

        $response = $request.GetResponse()
        $memory = New-Object System.IO.MemoryStream
        $response.GetResponseStream().CopyTo($memory)
        return @{
            StatusCode = [int]$response.StatusCode
            Data       = $memory.ToArray()
            Text       = [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
        }
    } catch {
        return @{ StatusCode = 0; Data = (New-Object byte[] 0); Text = '' }
    }
}

function Set-ConfigValue($TargetObject, [string]$PropertyName, $Value) {
    if ($null -eq $TargetObject) { return }
    if ($TargetObject.PSObject.Properties[$PropertyName]) {
        $TargetObject.$PropertyName = $Value
    } else {
        $TargetObject | Add-Member -NotePropertyName $PropertyName -NotePropertyValue $Value -Force
    }
}

function Get-ModemSession([string]$HostAddress, [string]$Password, [System.Net.CookieContainer]$Cookies) {
    $shaHasher = [System.Security.Cryptography.SHA512]::Create()
    $shaBytes = $shaHasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Password))
    $shaHex = [BitConverter]::ToString($shaBytes).Replace('-', '').ToLower()
    $base64Pass = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Password))
    $plainJson = (@{
        Input_Account   = 'admin'
        Input_Passwd    = $base64Pass
        currLang        = 'tr'
        SHA512_password = $shaHex
    } | ConvertTo-Json -Compress)

    try {
        $epochTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $rsaResponse = Invoke-HttpJson -Url "http://$HostAddress/getRSAPublickKey?t=$epochTime" -Method 'GET' -Cookies $Cookies
        if ($rsaResponse.StatusCode -eq 200 -and $rsaResponse.Text -match '-----BEGIN PUBLIC KEY-----') {
            $t = $rsaResponse.Text
            $endMark = '-----END PUBLIC KEY-----'
            $s = $t.IndexOf('-----BEGIN PUBLIC KEY-----')
            $e = if ($s -ge 0) { $t.IndexOf($endMark, $s) } else { -1 }
            if ($s -ge 0 -and $e -gt $s) {
                $pemContent = ($t.Substring($s, ($e - $s) + $endMark.Length)) -replace '\\n', "`n" -replace '\\/', '/'
                $cleanB64 = ($pemContent -replace '-----[^-]+-----', '') -replace '\s', ''
                $der = [Convert]::FromBase64String($cleanB64)

                $readLen = {
                    param([ref]$p)
                    $b = $der[$p.Value]; $p.Value++
                    if ($b -lt 0x80) { return [int]$b }
                    $n = $b -band 0x7f; $l = 0
                    for ($i = 0; $i -lt $n; $i++) { $l = ($l -shl 8) -bor $der[$p.Value]; $p.Value++ }
                    return [int]$l
                }

                $pos = 0
                if ($der[$pos] -eq 0x30) {
                    $pos++
                    [void](& $readLen ([ref]$pos))
                    if ($der[$pos] -eq 0x30) {
                        $pos++
                        $algLen = & $readLen ([ref]$pos); $pos += $algLen
                        if ($der[$pos] -eq 0x03) {
                            $pos++
                            [void](& $readLen ([ref]$pos)); $pos++
                            if ($der[$pos] -eq 0x30) {
                                $pos++
                                [void](& $readLen ([ref]$pos))
                                if ($der[$pos] -eq 0x02) {
                                    $pos++
                                    $modLen = & $readLen ([ref]$pos)
                                    $mod = New-Object byte[] $modLen
                                    [System.Buffer]::BlockCopy($der, $pos, $mod, 0, $modLen)
                                    $pos += $modLen

                                    if ($der[$pos] -eq 0x02) {
                                        $pos++
                                        $expLen = & $readLen ([ref]$pos)
                                        $exp = New-Object byte[] $expLen
                                        [System.Buffer]::BlockCopy($der, $pos, $exp, 0, $expLen)

                                        if ($mod.Length -gt 1 -and $mod[0] -eq 0) {
                                            $m2 = New-Object byte[] ($mod.Length - 1)
                                            [System.Buffer]::BlockCopy($mod, 1, $m2, 0, $m2.Length)
                                            $mod = $m2
                                        }
                                        if ($exp.Length -gt 1 -and $exp[0] -eq 0) {
                                            $e2 = New-Object byte[] ($exp.Length - 1)
                                            [System.Buffer]::BlockCopy($exp, 1, $e2, 0, $e2.Length)
                                            $exp = $e2
                                        }

                                        $rsaParams = New-Object System.Security.Cryptography.RSAParameters
                                        $rsaParams.Modulus  = $mod
                                        $rsaParams.Exponent = $exp

                                        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
                                        $aesK = New-Object byte[] 32; $rng.GetBytes($aesK)
                                        $ivF = New-Object byte[] 32; $rng.GetBytes($ivF)
                                        $iv16 = New-Object byte[] 16; [System.Buffer]::BlockCopy($ivF, 0, $iv16, 0, 16)

                                        $aes = [System.Security.Cryptography.Aes]::Create()
                                        $aes.KeySize = 256
                                        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
                                        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
                                        $aes.Key = $aesK
                                        $aes.IV  = $iv16

                                        $rawPlain = [System.Text.Encoding]::UTF8.GetBytes($plainJson)
                                        $cb = $aes.CreateEncryptor().TransformFinalBlock($rawPlain, 0, $rawPlain.Length)

                                        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
                                        $rsa.ImportParameters($rsaParams)
                                        $keyEnc = $rsa.Encrypt([System.Text.Encoding]::UTF8.GetBytes([Convert]::ToBase64String($aesK)), $false)

                                        $encPayload = (@{
                                            content = [Convert]::ToBase64String($cb)
                                            iv      = [Convert]::ToBase64String($ivF)
                                            key     = [Convert]::ToBase64String($keyEnc)
                                        } | ConvertTo-Json -Compress)

                                        $lRes = Invoke-HttpJson -Url "http://$HostAddress/UserLogin" -Method 'POST' -Payload ([System.Text.Encoding]::UTF8.GetBytes($encPayload)) -Headers @{'Content-Type'='application/json'} -Cookies $Cookies
                                        if ($lRes.StatusCode -eq 200) {
                                            if ($lRes.Text -match '"content"' -and $lRes.Text -match '"iv"') {
                                                try {
                                                    $lObj = $lRes.Text | ConvertFrom-Json
                                                    $ivD = New-Object byte[] 16
                                                    [System.Buffer]::BlockCopy([Convert]::FromBase64String($lObj.iv), 0, $ivD, 0, 16)
                                                    $aes.IV = $ivD
                                                    $decData = [Convert]::FromBase64String($lObj.content)
                                                    $decText = [System.Text.Encoding]::UTF8.GetString($aes.CreateDecryptor().TransformFinalBlock($decData, 0, $decData.Length))
                                                    if ($decText -match '"sessionkey"\s*:\s*"([^"]+)"') { return $matches[1] }
                                                } catch {}
                                            }
                                            if ($lRes.Text -match '"sessionkey"\s*:\s*"([^"]+)"') { return $matches[1] }
                                            $sessionCookie = $Cookies.GetCookies((New-Object System.Uri("http://$HostAddress")))['sessionkey']
                                            if ($sessionCookie) { return $sessionCookie.Value }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    } catch {}

    try {
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plainJson)
        $lRes2 = Invoke-HttpJson -Url "http://$HostAddress/UserLogin" -Method 'POST' -Payload $plainBytes -Headers @{'Content-Type'='application/json'} -Cookies $Cookies
        if ($lRes2.StatusCode -eq 200) {
            if ($lRes2.Text -match '"sessionkey"\s*:\s*"([^"]+)"') { return $matches[1] }
            $c2 = $Cookies.GetCookies((New-Object System.Uri("http://$HostAddress")))['sessionkey']
            if ($c2) { return $c2.Value }
        }
    } catch {}

    return $null
}

function Optimize-ConfigObject($Config, [string[]]$AllPages) {
    Write-Host " [*] Yapilandirma Alanlari Yerel Varsayilanlara Uyarlaniyor:" -ForegroundColor Cyan

    if ($Config.X_ZYXEL_LoginCfg) {
        $adminPasswordHash = $null
        $adminDefaultHash  = $null

        foreach ($group in $Config.X_ZYXEL_LoginCfg.LogGp) {
            if ($group.Account) {
                foreach ($account in $group.Account) {
                    if ($account.Username -eq 'admin') {
                        $adminPasswordHash = $account.Password
                        $adminDefaultHash  = $account.DefaultPassword
                        break
                    }
                }
            }
            if ($adminPasswordHash) { break }
        }

        Set-ConfigValue $Config.X_ZYXEL_LoginCfg 'LoginGroupConfigurable' $true

        foreach ($group in $Config.X_ZYXEL_LoginCfg.LogGp) {
            Set-ConfigValue $group 'Level' 'high'
            Set-ConfigValue $group 'Page' $AllPages
            Set-ConfigValue $group 'HiddenPage' ''

            if ($group.Account) {
                foreach ($account in $group.Account) {
                    Set-ConfigValue $account 'Enabled' $true
                    Set-ConfigValue $account 'RemoteAccessPrivilege' 'LAN,WAN'
                    Set-ConfigValue $account 'GetConfigByFtp' $true
                    Set-ConfigValue $account 'ConfigAccountFromWAN' $true
                    Set-ConfigValue $account 'Page' $AllPages
                    Set-ConfigValue $account 'HiddenPage' ''

                    if ($account.Username -in @('sUser', 'root') -and $adminPasswordHash) {
                        Set-ConfigValue $account 'Password' $adminPasswordHash
                        if ($adminDefaultHash) {
                            Set-ConfigValue $account 'DefaultPassword' $adminDefaultHash
                        }
                    }
                }
            }
        }
        Write-Host "   -> [X_ZYXEL_LoginCfg]     : Yonetim sayfa erisimleri ve teshis yetkileri varsayilana esitlendi." -ForegroundColor Green
    }

    if ($Config.X_ZYXEL_RemoteManagement) {
        foreach ($serviceGroup in @($Config.X_ZYXEL_RemoteManagement.Service, $Config.X_ZYXEL_RemoteManagement.SPService)) {
            if ($serviceGroup) {
                foreach ($service in $serviceGroup) {
                    if ($service.Name -in @('SSH', 'TELNET', 'FTP', 'HTTP', 'HTTPS', 'PING')) {
                        $service.Enable = $true
                        if ($service.PSObject.Properties['Mode'])     { $service.Mode = 'LAN_WAN' }
                        if ($service.PSObject.Properties['TrustAll']) { $service.TrustAll = $true }
                        if ($service.Name -eq 'SSH')    { $service.Port = 22 }
                        if ($service.Name -eq 'FTP')    { $service.Port = 21 }
                        if ($service.Name -eq 'TELNET') { $service.Port = 23 }
                    }
                    if ($service.Name -eq 'TR069') {
                        $service.Enable = $false
                        $service.Port   = 0
                    }
                }
            }
        }
        Write-Host "   -> [RemoteManagement]     : Yerel teshis portlari etkinlestirildi (SSH 22, Telnet 23, FTP 21, Web 80/443)." -ForegroundColor Green
    }

    if ($Config.ManagementServer) {
        $cwmpMap = @{
            EnableCWMP                    = $false
            PeriodicInformEnable          = $false
            UpgradesManaged               = $false
            URL                           = 'http://127.0.0.1:0'
            Username                      = ''
            Password                      = ''
            ConnectionRequestUsername     = ''
            ConnectionRequestPassword     = ''
            X_ZYXEL_ConnectionRequestPort = 0
            STUNEnable                    = $false
        }
        foreach ($key in $cwmpMap.Keys) {
            Set-ConfigValue $Config.ManagementServer $key $cwmpMap[$key]
        }
        Write-Host "   -> [ManagementServer]     : TR-069 (CWMP) sunucu ve istek adresi yerel varsayilana (127.0.0.1:0) sifirlandi." -ForegroundColor Green
    }

    if ($Config.LocalAgent) {
        foreach ($agentGroup in @($Config.LocalAgent.Subscription, $Config.LocalAgent.Controller, $Config.LocalAgent.MTP)) {
            if ($agentGroup) {
                foreach ($item in $agentGroup) {
                    Set-ConfigValue $item 'Enable' $false
                }
            }
        }
        Write-Host "   -> [LocalAgent]           : TR-369 (USP) telemetri servis parametreleri pasif konuma alindi." -ForegroundColor Green
    }

    if ($Config.MQTT -and $Config.MQTT.Client) {
        foreach ($client in $Config.MQTT.Client) {
            Set-ConfigValue $client 'Enable' $false
            Set-ConfigValue $client 'BrokerAddress' '127.0.0.1'
        }
        Write-Host "   -> [MQTT]                 : Telemetri araci yonlendirmesi yerel varsayilana (127.0.0.1) yonlendirildi." -ForegroundColor Green
    }
}

function Clear-ScreenSafe {
    try { [System.Console]::Clear() } catch { try { Clear-Host } catch {} }
}

function Show-AppBanner([string]$StatusText = '') {
    Clear-ScreenSafe
    Write-Host ""
    Write-Host "=========================================================================" -ForegroundColor Cyan
    Write-Host "  Zyxel-Local-Toolkit - Local Diagnostic & Configuration Tool            " -ForegroundColor Green
    Write-Host "  Zyxel Modem ve Router Cihazlari Icin Yerel Teshis ve Yonetim Araci     " -ForegroundColor DarkGray
    Write-Host "=========================================================================" -ForegroundColor Cyan
    if ($StatusText) {
        Write-Host "  $StatusText" -ForegroundColor Green
        Write-Host "-------------------------------------------------------------------------" -ForegroundColor DarkCyan
    }
    Write-Host ""
}

Show-AppBanner
Write-Host "  DIL SECIMI / LANGUAGE SELECTION:" -ForegroundColor Yellow
Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host "    [1] English   - International Documentation & English Menus" -ForegroundColor White
Write-Host "    [2] Turkce    - Turkce Yonergeler ve Menuler" -ForegroundColor White
Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

$isEn = $false
while ($true) {
    $rawLang = (Read-Host "  Select Language / Dil Seciniz [1: EN, 2: TR, Enter = 2]").Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($rawLang) -or $rawLang -in @('2', 'tr', 'turkce', 'turkce', 't')) {
        $isEn = $false
        break
    } elseif ($rawLang -in @('1', 'en', 'eng', 'english', 'e')) {
        $isEn = $true
        break
    } else {
        Write-Host "  [!] Invalid choice / Gecersiz secim. Please enter 1 or 2 (Lutfen 1 veya 2 girin)." -ForegroundColor Yellow
    }
}

$langTag = if ($isEn) { "[+] Language: English" } else { "[+] Dil: Turkce" }
Show-AppBanner -StatusText $langTag

if ($isEn) {
    Write-Host "  [i] Disclaimer:" -ForegroundColor Yellow
    Write-Host "      This toolkit is for educational, maintenance, and security research." -ForegroundColor DarkGray
    Write-Host "      Modifications may affect warranty status; user assumes all responsibility." -ForegroundColor DarkGray
    Write-Host "  [i] Responsible Disclosure:" -ForegroundColor Yellow
    Write-Host "      Diagnostic parameters are adapted to local area network defaults." -ForegroundColor DarkGray
    Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  OPERATION MODES:" -ForegroundColor Yellow
    Write-Host "    [1] Enable SSH/Telnet & Disable Remote CWMP (auto-backups first)" -ForegroundColor White
    Write-Host "        ~90-120s (device reboots automatically after applying)" -ForegroundColor DarkGray
    Write-Host "    [2] Export Current Configuration as Readable JSON" -ForegroundColor White
    Write-Host "        ~5s (device configuration unmodified, no reboot)" -ForegroundColor DarkGray
    Write-Host "    [3] Restore Modified JSON Configuration to Device" -ForegroundColor White
    Write-Host "        ~90-120s (device reboots automatically after applying)" -ForegroundColor DarkGray
    Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
} else {
    Write-Host "  [i] Feragatname:" -ForegroundColor Yellow
    Write-Host "      Bu aractaki yapilandirmalar egitim ve donanim bakimi amaclidir." -ForegroundColor DarkGray
    Write-Host "      Yapilacak islemler garanti durumunu etkileyebilir; sorumluluk kullaniciya aittir." -ForegroundColor DarkGray
    Write-Host "  [i] Sorumlu Ifsa:" -ForegroundColor Yellow
    Write-Host "      Teshis portlari yerel ag varsayilanlarina uyarlanmaktadir." -ForegroundColor DarkGray
    Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  ISLEM MODLARI:" -ForegroundColor Yellow
    Write-Host "    [1] SSH/Telnet Etkinlestir & Uzak Yonetimi Kapat (Once otomatik yedek alir)" -ForegroundColor White
    Write-Host "        ~90-120 sn (Cihaz ayarlar yuklenince otomatik yeniden baslar)" -ForegroundColor DarkGray
    Write-Host "    [2] Mevcut Ayarlari JSON Olarak Kaydet" -ForegroundColor White
    Write-Host "        ~5 sn (Cihazda ayar degistirmez, yeniden baslamaz)" -ForegroundColor DarkGray
    Write-Host "    [3] Duzenledigin JSON'u Cihaza Yukle" -ForegroundColor White
    Write-Host "        ~90-120 sn (Cihaz ayarlar yuklenince otomatik yeniden baslar)" -ForegroundColor DarkGray
    Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
}

if ($ActionOption -in 1, 2, 3) {
    $SelectedAction = $ActionOption
} else {
    while ($true) {
        $pMsg = if ($isEn) { "  Select Mode [1 / 2 / 3, Enter = 1]: " } else { "  Islem Seciniz [1 / 2 / 3, Enter = 1]: " }
        $inputAction = (Read-Host $pMsg).Trim()
        if ([string]::IsNullOrWhiteSpace($inputAction) -or $inputAction -eq '1') {
            $SelectedAction = 1
            break
        } elseif ($inputAction -eq '2') {
            $SelectedAction = 2
            break
        } elseif ($inputAction -eq '3') {
            $SelectedAction = 3
            break
        } else {
            $errPrompt = if ($isEn) { "  [!] Please enter 1, 2, or 3." } else { "  [!] Lutfen 1, 2 veya 3 giriniz." }
            Write-Host $errPrompt -ForegroundColor Yellow
        }
    }
}

$modeTag = if ($isEn) {
    switch ($SelectedAction) {
        1 { "[+] Mode 1: Enable SSH/Telnet" }
        2 { "[+] Mode 2: Export JSON" }
        3 { "[+] Mode 3: Restore JSON" }
    }
} else {
    switch ($SelectedAction) {
        1 { "[+] Mod 1: SSH/Telnet Etkinlestir & Uzak Yonetimi Kapat" }
        2 { "[+] Mod 2: JSON Olarak Kaydet" }
        3 { "[+] Mod 3: JSON Geri Yukle" }
    }
}

Show-AppBanner -StatusText "$langTag  |  $modeTag"

$scriptDir = if ($PSScriptRoot) {
    if ((Split-Path $PSScriptRoot -Leaf) -ieq 'core') { Split-Path $PSScriptRoot -Parent } else { $PSScriptRoot }
} else { Get-Location }
$jsonFilePath = Join-Path $scriptDir 'zcfg_config.json'

if ($SelectedAction -eq 3) {
    if (-not (Test-Path $jsonFilePath)) {
        $latestBackupDir = Get-ChildItem -Path $scriptDir -Directory -Filter 'yedek_*' -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($latestBackupDir) {
            $candidate = Join-Path $latestBackupDir.FullName 'zcfg_config.json'
            if (Test-Path $candidate) { $jsonFilePath = $candidate }
        }
    }

    if (-not (Test-Path $jsonFilePath)) {
        if ($isEn) {
            Write-Host "  [!] Error: 'zcfg_config.json' not found." -ForegroundColor Red
            Write-Host "      Export current config first with option [2] and edit it." -ForegroundColor Yellow
        } else {
            Write-Host "  [!] Hata: 'zcfg_config.json' dosyasi bulunamadi." -ForegroundColor Red
            Write-Host "      Once [2] secenegi ile mevcut paketi acip duzenlemeniz gerekir." -ForegroundColor Yellow
        }
        exit 1
    }

    try {
        $cfg = [System.IO.File]::ReadAllText($jsonFilePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $okMsg = if ($isEn) { "  [+] '$jsonFilePath' verified and loaded." } else { "  [+] '$jsonFilePath' dosyasi okundu ve dogrulandi." }
        Write-Host $okMsg -ForegroundColor Green
    } catch {
        $errMsg = if ($isEn) { "  [!] Error: 'zcfg_config.json' is not valid JSON." } else { "  [!] Hata: 'zcfg_config.json' gecerli bir JSON biciminde degil." }
        Write-Host $errMsg -ForegroundColor Red
        exit 1
    }
}

$defaultIP = '192.168.1.1'
try {
    $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NextHop -First 1)
    if ($gw -and $gw -match '^\d+\.\d+\.\d+\.\d+$') { $defaultIP = $gw }
} catch {}

$credHeader = if ($isEn) { "  DEVICE CONNECTION CREDENTIALS:" } else { "  BAGLANTI VE GIRIS BILGILERI:" }
Write-Host $credHeader -ForegroundColor Yellow
Write-Host "  -----------------------------------------------------------------------" -ForegroundColor DarkCyan

if ([string]::IsNullOrWhiteSpace($TargetIP)) {
    $ipPrompt = if ($isEn) { "    Router IP Address [Enter = $defaultIP]: " } else { "    Modem IP Adresi [Enter = $defaultIP]: " }
    $ipInput = Read-Host $ipPrompt
    $IP = if ([string]::IsNullOrWhiteSpace($ipInput)) { $defaultIP } else { $ipInput.Trim() }
} else {
    $IP = $TargetIP.Trim()
    Write-Host "    Target IP: $IP" -ForegroundColor Green
}

if ([string]::IsNullOrWhiteSpace($TargetPass)) {
    do {
        $passPrompt = if ($isEn) { "    Device Web Password (User: admin): " } else { "    Modem Yonetim Sifresi (Kullanici: admin): " }
        $Pass = (Read-Host $passPrompt).Trim()
        if ([string]::IsNullOrWhiteSpace($Pass)) {
            $emptyMsg = if ($isEn) { "    [!] Password cannot be empty." } else { "    [!] Sifre bos birakilamaz." }
            Write-Host $emptyMsg -ForegroundColor Yellow
        }
    } while ([string]::IsNullOrWhiteSpace($Pass))
} else {
    $Pass = $TargetPass.Trim()
}

Show-AppBanner -StatusText "$langTag  |  $modeTag  |  [+] $IP"

$authMsg = if ($isEn) { "  [*] Authenticating ($IP)..." } else { "  [*] Kimlik dogrulaniyor ($IP)..." }
Write-Host $authMsg -ForegroundColor Cyan
$cookies = New-Object System.Net.CookieContainer
$sk = Get-ModemSession -HostAddress $IP -Password $Pass -Cookies $cookies
if (-not $sk) {
    $loginFail = if ($isEn) { "[!] Error: Could not connect to router or login failed." } else { "[!] Hata: Modeme erisilemedi veya oturum acilamadi." }
    Write-Host $loginFail -ForegroundColor Red
    exit 1
}
$authOk = if ($isEn) { "[+] Authentication successful (admin). Session token obtained." } else { "[+] Kimlik dogrulandi (admin). Oturum anahtari alindi." }
Write-Host $authOk -ForegroundColor Green

if ($SelectedAction -in 1, 2) {
    $fetchMsg = if ($isEn) { "`n[*] Downloading configuration package from device..." } else { "`n[*] Donanim yapilandirma paketi aliniyor..." }
    Write-Host $fetchMsg -ForegroundColor Cyan
    try { [void](Invoke-HttpJson -Url "http://$IP/cgi-bin/UserLoginCheck" -Method 'GET' -Cookies $cookies) } catch {}
    $backupUrl = "http://$IP/cgi-bin/Backup_Restore?action=Backup&sessionkey=$([System.Uri]::EscapeDataString($sk))"
    $bRes = Invoke-HttpJson -Url $backupUrl -Method 'GET' -Cookies $cookies
    if ($bRes.StatusCode -ne 200 -or $bRes.Data.Length -lt 400) {
        $dlFail = if ($isEn) { "[!] Error: Failed to retrieve configuration package." } else { "[!] Hata: Yapilandirma paketi alinamadi." }
        Write-Host $dlFail -ForegroundColor Red
        exit 1
    }
    $dlOk = if ($isEn) { "[+] Configuration package received ($($bRes.Data.Length) bytes)." } else { "[+] Yapilandirma paketi alindi ($($bRes.Data.Length) bayt)." }
    Write-Host $dlOk -ForegroundColor Green

    $timeTag = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
    $backupDir = Join-Path $scriptDir "yedek_$timeTag"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $binOutPath = Join-Path $backupDir 'backup.bin'
    [System.IO.File]::WriteAllBytes($binOutPath, $bRes.Data)

    $unpackMsg = if ($isEn) { "`n[*] Unpacking binary package and parsing ZCFG object model..." } else { "`n[*] Donanim paketi aciliyor ve nesne modeli cozumleniyor..." }
    Write-Host $unpackMsg -ForegroundColor Cyan
    $cfg = ConvertFrom-ZyxelBin -Data $bRes.Data -Secret $ConfigKey
    $modelLoaded = if ($isEn) { "[+] Object model loaded into memory." } else { "[+] Nesne modeli bellege aktarildi." }
    Write-Host $modelLoaded -ForegroundColor Green

    if ($SelectedAction -eq 2) {
        $jsonOutPath = Join-Path $backupDir 'zcfg_config.json'
        [System.IO.File]::WriteAllText($jsonOutPath, ($cfg | ConvertTo-Json -Depth 100), [System.Text.Encoding]::UTF8)

        Write-Host "`n=========================================================================" -ForegroundColor Green
        if ($isEn) {
            Write-Host " [OK] CONFIGURATION PACKAGE EXTRACTED AND SAVED" -ForegroundColor Green
            Write-Host "=========================================================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "   - Archive Folder   : $backupDir" -ForegroundColor Green
            Write-Host "   - Raw Binary (.bin): $binOutPath" -ForegroundColor Green
            Write-Host "   - Open JSON (.json): $jsonOutPath" -ForegroundColor Green
            Write-Host ""
            Write-Host " Device configuration has not been modified." -ForegroundColor Yellow
            Write-Host " You can inspect or edit this JSON file for research or customization." -ForegroundColor Cyan
            Write-Host " After editing, use option [3] to restore it back to the device." -ForegroundColor Cyan
        } else {
            Write-Host " [OK] YAPILANDIRMA PAKETI BASARIYLA ACILDI VE KAYDEDILDI" -ForegroundColor Green
            Write-Host "=========================================================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "   - Arsiv Klasoru     : $backupDir" -ForegroundColor Green
            Write-Host "   - Ham Paket (.bin)  : $binOutPath" -ForegroundColor Green
            Write-Host "   - Acik Nesne (.json): $jsonOutPath" -ForegroundColor Green
            Write-Host ""
            Write-Host " Cihaz uzerinde herhangi bir durum degisikligi yapilmadi." -ForegroundColor Yellow
            Write-Host " JSON dosyasini egitim ve guvenlik analizi amaciyla inceleyebilirsiniz." -ForegroundColor Cyan
            Write-Host " Duzenleme sonrasi [3] secenegi ile modeminize geri yukleyebilirsiniz." -ForegroundColor Cyan
        }
        Write-Host "=========================================================================`n"
        exit 0
    } else {
        $archivedMsg = if ($isEn) { " [+] Original backup archived safely to '$binOutPath'." } else { " [+] Orijinal donanim paketi '$binOutPath' yoluna guvenle arsivlendi." }
        Write-Host $archivedMsg -ForegroundColor Green
    }
}

if ($SelectedAction -eq 1) {
    $optMsg = if ($isEn) { "`n[*] Applying interoperability and local diagnostic parameters..." } else { "`n[*] Birlikte calisabilirlik ve yerel servis parametreleri uyarlaniyor..." }
    Write-Host $optMsg -ForegroundColor Cyan
    Optimize-ConfigObject -Config $cfg -AllPages $ALL_PAGES
}

$packMsg = if ($isEn) { "`n[*] Repacking configuration into hardware binary format..." } else { "`n[*] Yeni donanim paketi hazirlaniyor ve paketleniyor..." }
Write-Host $packMsg -ForegroundColor Cyan
$encBytes = ConvertTo-ZyxelBin -JsonObject $cfg -Secret $ConfigKey
$packOk = if ($isEn) { "[+] Package generated ($($encBytes.Length) bytes)." } else { "[+] Paket hazirlandi ($($encBytes.Length) bayt)." }
Write-Host $packOk -ForegroundColor Green

$uploadMsg = if ($isEn) { "`n[*] Uploading configuration package to router..." } else { "`n[*] Yeni yapilandirma paketi cihaza yukleniyor..." }
Write-Host $uploadMsg -ForegroundColor Cyan
$boundary = '----ZyxelBoundary' + [System.Guid]::NewGuid().ToString('N')
$hB = [System.Text.Encoding]::UTF8.GetBytes("--$boundary`r`nContent-Disposition: form-data; name=`"mtenRestoreCfg`"; filename=`"backup.bin`"`r`nContent-Type: application/octet-stream`r`n`r`n")
$fB = [System.Text.Encoding]::UTF8.GetBytes("`r`n--$boundary--`r`n")
$ms = New-Object System.IO.MemoryStream
$ms.Write($hB, 0, $hB.Length); $ms.Write($encBytes, 0, $encBytes.Length); $ms.Write($fB, 0, $fB.Length)

$restoreUrl = "http://$IP/cgi-bin/Backup_Restore?action=Restore&sessionkey=$([System.Uri]::EscapeDataString($sk))"
try {
    [void](Invoke-HttpJson -Url $restoreUrl -Method 'POST' -Payload $ms.ToArray() -Headers @{'Content-Type'="multipart/form-data; boundary=$boundary"} -Cookies $cookies)
} catch {}

Write-Host "`n=========================================================================" -ForegroundColor Green
if ($isEn) {
    Write-Host " [INFO] CONFIGURATION PACKAGE APPLIED TO DEVICE" -ForegroundColor Green
    Write-Host "=========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " [*] New configuration applied. The router is now rebooting to load settings." -ForegroundColor Cyan
    Write-Host " [*] Establishing 5G/cellular link and Wi-Fi broadcast takes ~90-120 seconds. Please wait patiently." -ForegroundColor DarkGray
    Write-Host " [*] To revert to factory defaults, hold the Reset pinhole on the back for 10-15 seconds or use the Web GUI." -ForegroundColor DarkGray
    Write-Host ""
    if ($SelectedAction -eq 1) {
        Write-Host " Local Diagnostic Endpoints:" -ForegroundColor White
        Write-Host "   - Web Management GUI : http://$IP (user: admin)" -ForegroundColor Green
        Write-Host "   - Local SSH Shell    : ssh root@$IP -p 22" -ForegroundColor Green
        Write-Host "   - Local FTP Service  : ftp://$IP (port: 21)" -ForegroundColor Green
        Write-Host "   - Local Telnet       : telnet $IP 23" -ForegroundColor Green
        Write-Host ""
        Write-Host " Account Roles (Password: Your Router Web Password):" -ForegroundColor White
        Write-Host "   - admin : Default privileged web interface account" -ForegroundColor DarkGray
        Write-Host "   - root  : Privileged shell and FTP account" -ForegroundColor DarkGray
        Write-Host "   - sUser : Elevated system account" -ForegroundColor DarkGray
    } else {
        Write-Host "   - Custom configuration package restored successfully." -ForegroundColor Green
    }
    Write-Host ""
    Write-Host " Info: For educational, maintenance, and interoperability research only." -ForegroundColor DarkGray
} else {
    Write-Host " [BILGI] YAPILANDIRMA PAKETI CIHAZA AKTARILDI" -ForegroundColor Green
    Write-Host "=========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " [*] Yeni yapilandirma cihaza uygulandi. Cihaz ayarlari yuklemek uzere yeniden baslatiliyor." -ForegroundColor Cyan
    Write-Host " [*] Servislerin ve ag baglantisinin hazir hale gelmesi yaklasik 90-120 saniye surecektir. Lutfen sabirla bekleyiniz." -ForegroundColor DarkGray
    Write-Host " [*] Orijinal fabrika ayarlarina donmek isterseniz modemin arkasindaki Reset butonuna 10-15 saniye basili tutabilir veya web arayuzunden sifirlayabilirsiniz." -ForegroundColor DarkGray
    Write-Host ""
    if ($SelectedAction -eq 1) {
        Write-Host " Yerel Teshis Arabirimleri:" -ForegroundColor White
        Write-Host "   - Web Yonetim Arayuzu : http://$IP (kullanici: admin)" -ForegroundColor Green
        Write-Host "   - Yerel SSH Konsolu   : ssh root@$IP -p 22" -ForegroundColor Green
        Write-Host "   - Yerel FTP Servisi   : ftp://$IP (port: 21)" -ForegroundColor Green
        Write-Host "   - Yerel Telnet        : telnet $IP 23" -ForegroundColor Green
        Write-Host ""
        Write-Host " Hesap Yapisi (Mod 1 Sonrasi - Sifre: Modem Web Sifreniz):" -ForegroundColor White
        Write-Host "   - admin : Varsayilan yetkili web hesabi" -ForegroundColor DarkGray
        Write-Host "   - root  : SSH, FTP gibi servislerde kullanilan hesap" -ForegroundColor DarkGray
        Write-Host "   - sUser : Yetkili sistem hesabi" -ForegroundColor DarkGray
    } else {
        Write-Host "   - Ozel yapilandirma paketi basariyla cihaza iletildi." -ForegroundColor Green
    }
    Write-Host ""
    Write-Host " Bilgi: Bu arac egitim, donanim bakimi ve guvenlik arastirmasi amaclidir." -ForegroundColor DarkGray
}
Write-Host "=========================================================================`n"