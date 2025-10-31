# --- Config ---
$domains = @(
  "100ulife.com","coslogdydy.in","ipmoyu.com","pcxrlback.com","tuding.xyz","1ztop.work",
  "cxlcyy.com","jasmine.land","petrel-ip.com","tvsnapp.com","99soya.shop","cxzyr.com",
  "jolted.vip","pixelscast.com","veezy.site","ad3g.com","dazzl.vip","joyfulxx.com",
  "pixlo.cc","vividweb.work","admoyu.com","dc16888888.com","jutux.work","pm2za.cc",
  "wildpettykiwi.com","ads-goal.com","dcylog.com","logcer.com","qazwsxedc.xyz",
  "wildpettykiwi.info","ai-goal.com","dqmop.com","long.tv","qocoll.com",
  "wildpettykiwi.xyz","apotube.com","duoduodev.com","meiboot.com","qulogger.com",
  "wotads.com","app-goal.com","easyjoy.me","moonhub.work","randomhow.com","ycxad.com",
  "appclicking.com","echojoy.xyz","motiyu.net","retrofitxer.com","ycxrl.com",
  "astrolink.cn","finemob.com","moyix.com","rzless.work","ycxrldow.com","bitemores.com",
  "firehub.link","moyu88.xyz","shanhulan.cn","yeyeyeye.xyz","bltproxy.com","firehub.work",
  "msohu.online","simplekds.me","yxcrl.com","bluefish.work","flyermobi.com","msohu.shop",
  "soyatea.online","yydsma.com","bullet-proxy.com","fuhidd.com","mtcpmpm.com",
  "sparkjoy.cc","yydsmb.com","catmore88.com","g1ee.com","mtcprogram.com",
  "supportdatainput.top","yydsmd.com","catmos99.com","giddy.cc","mtcpuouo.com",
  "sustat.com","yydsmr.com","cbphe.com","goologer.com","mymoyu.shop","swiftcode.work",
  "ziyemy.shop","cbpheback.com","heygames.club","navnow.xyz","syloger.com","ztword.com",
  "clickby.net","huulog.com","net-goal.com","sysbinder.com","zxcvbnmasdfghjkl.xyz",
  "clocksyn.com","huuww.com","pccyy.com","sysbinder.xyz","vmud.net","ipforyou.top",
  "pcxrl.com","ttyunos.com","meisvip.com"
)

$csvPath = "/Volumes/T9/*.csv"
$headers = 'No','Time','Source','Destination','Protocol','Length','Info'

# Build a fast lookup (lowercase) for exact parent-domain checks
$domainSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$domains | ForEach-Object { [void]$domainSet.Add($_) }

# Collect unique IPs seen in DNS responses
$ipSet = [System.Collections.Generic.HashSet[string]]::new()

function Get-QueriedFqdn {
    param([string]$Info)
    if (-not $Info) { return $null }
    
        # Look for domain names in the Info field
        # Match 'A something.domain.com' pattern
        if ($Info -match '\sA\s+([a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+)') {
            return $matches[1].TrimEnd('.').ToLowerInvariant()
        }
    
        # If no A record found, fall back to the old behavior
        $fqdn = ($Info -split '\s+')[-1].TrimEnd('.')
        # Basic sanity: must contain at least one dot
        if ($fqdn -notmatch '\.') { return $null }
        $fqdn.ToLowerInvariant()
}

function Matches-Watchlist {
    param([string]$fqdn)

    if (-not $fqdn) { return $false, $null }

    # Exact match first
    if ($domainSet.Contains($fqdn)) { return $true, $fqdn }

    # Suffix (subdomain) match: fqdn ends with "." + domain
    foreach ($d in $domainSet) {
        if ($fqdn.EndsWith("." + $d, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true, $d
        }
    }
    return $false, $null
}

$csvData = Get-ChildItem $csvPath | ForEach-Object {
    $currentFile = $_
    Import-Csv -Path $_.FullName -Header $headers | ForEach-Object {
        $_ | Add-Member -NotePropertyName 'SourceFile' -NotePropertyValue $currentFile.Name
        $_
    }
}

$matches = $csvData |
    Where-Object { $_.Protocol -eq 'DNS' } |
    ForEach-Object {
        $fqdn = Get-QueriedFqdn -Info $_.Info
        $isMatch, $hit = Matches-Watchlist -fqdn $fqdn
        if ($isMatch) {
            # Output an object (easy to pipe/export) and also show a colored line
            Write-Host ("Matched domain: {0} (via {1})" -f $fqdn, $hit) -ForegroundColor Green
            # Extract any IPv4 addresses from the Info field and add to global set
            $ips = @()
            if ($_.Info) {
                $matchesIp = [regex]::Matches($_.Info, '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b')
                foreach ($m in $matchesIp) {
                    $ip = $m.Value
                    # Basic validation to skip octets >255
                    $parts = $ip -split '\.' | ForEach-Object {[int]$_}
                    if ($parts -and ($parts | Where-Object { $_ -gt 255 }).Count -eq 0) {
                        $ips += $ip
                        [void]$ipSet.Add($ip)
                    }
                }
            }

            [pscustomobject]@{
                No            = $_.No
                Time          = $_.Time
                Source        = $_.Source
                Destination   = $_.Destination
                Protocol      = $_.Protocol
                QueryFQDN     = $fqdn
                MatchedDomain = $hit
                SourceFile    = $_.SourceFile
                IPs           = ($ips -join ', ')
                Info          = $_.Info
            }
        }
    }

$matches | Format-Table -AutoSize

# Print collected unique IPs (numerically sorted) if any were found
if ($ipSet.Count -gt 0) {
    Write-Host "`nCollected unique IPs:" -ForegroundColor Cyan
    # Sort IPs numerically by converting to uint32
    $ipSet | Sort-Object -Property @{Expression = { 
        $b = [System.Net.IPAddress]::Parse($_).GetAddressBytes()
        [Array]::Reverse($b)
        [BitConverter]::ToUInt32($b, 0)
    }} | ForEach-Object { Write-Host $_ }
}

# Check whether any of those IPs appear in Source or Destination fields of the original CSV data
if ($ipSet.Count -gt 0 -and $csvData) {
    $ipMatches = @()
    foreach ($ip in $ipSet) {
        $rows = $csvData | Where-Object { $_.Source -eq $ip -or $_.Destination -eq $ip }
        foreach ($r in $rows) {
            $ipMatches += [pscustomobject]@{
                IP         = $ip
                No         = $r.No
                Time       = $r.Time
                Source     = $r.Source
                Destination= $r.Destination
                Protocol   = $r.Protocol
                SourceFile = $r.SourceFile
                Info       = $r.Info
            }
        }
    }

    if ($ipMatches.Count -gt 0) {
        Write-Host "`nIP addresses found in Source/Destination fields:" -ForegroundColor Yellow
        # Remove duplicates (in case same row matched multiple IPs) and sort by IP then Time
        $ipMatches | Sort-Object Time | Format-Table * -AutoSize
    }
    else {
        Write-Host "`nNo collected IPs were found in Source or Destination fields of the CSV data." -ForegroundColor DarkGray
    }
}
