<#
Auto script for installing Tableau Server

Auther: wcheng
Date: 2020-06-14
#>

#Requires -RunAsAdministrator

function Write-Log($log) {
  Write-Host (Get-Date).ToString('yyyy/MM/dd HH:mm:ss') $log
}

# check Tableau Server version
$version = $args[0].ToString()
If([string]::IsNullOrEmpty($version)) {
  throw 'Error: No version of Tableau Server.'
}
$vs = $version.Split('.')
If($vs.Length -ne 3) {
  throw 'Error: Invalid version.'
}

$versionArray = [int[]]::new($vs.Length)
for ($i = 0; $i -lt $vs.Length; $i++) {
  $versionArray[$i] = [int]$vs[$i]
}

# check config
$appProps = ConvertFrom-StringData (get-content ./settings.properties -raw)
$productKey = $appProps."ts.product.key"
If([string]::IsNullOrEmpty($productKey)) {
  throw 'Error: No product key.'
}

Write-Log("Will install Tableau Server $($version)")

$curPath = $PSScriptRoot
Set-Location -Path $curPath
Write-Log($PWD)

# create download folder
$downloadPath = Join-Path -Path $curPath -ChildPath "download"
If(!(test-path $downloadPath))
{
  $null = New-Item -ItemType Directory -Force -Path $downloadPath
}

# download installer
$url = "https://downloads.tableau.com/esdalt/$($version)/TableauServer-64bit-$($version.Replace('.', '-')).exe"
$installerFileName = $url.Substring($url.LastIndexOf("/") + 1)
$installerFilePath = Join-Path -Path $downloadPath -ChildPath $installerFileName

If(Test-Path $installerFilePath -PathType Leaf) {
  Write-Log("$($installerFilePath) exists, skip downloading")
} else {
  Write-Log("Downloading installer from $($url)")
  (New-Object System.Net.WebClient).DownloadFile($url, $installerFilePath)
}

# sleep for 5 seconds
Start-Sleep -s 5

# install
# 1. Install TSM
$arguments = [System.Collections.ArrayList]@("/silent")
If(($versionArray[0] -gt 2019) -or (($versionArray[0] -eq 2019) -and ($versionArray[1] -ge 4))) {
  # 2019.4 or later
  $arguments.Add("ACCEPTEULA=1")
} else {
  $arguments.Add("/accepteula")
}
Write-Log("Installing TSM...")
$proc = Start-Process -NoNewWindow -Wait -FilePath $installerFilePath -ArgumentList $arguments
Write-Log($proc.ExitCode)

# sleep for 5 seconds
Start-Sleep -s 5

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

Write-Log("Run tsm status -v")
Start-Process -NoNewWindow -Wait tsm "status -v"

# 2. Activate and Register Tableau Server
Write-Log("Activating...")
Start-Process -NoNewWindow -Wait tsm "licenses activate -k $($productKey)"
Write-Log("Registering...")
Start-Process -NoNewWindow -Wait tsm "register --file ./ts_registration.json"

# 3. Configure Initial Node Settings
Write-Log("Initializing...")
Start-Process -NoNewWindow -Wait tsm "settings import -f ./ts_settings.json"
Start-Process -NoNewWindow -Wait tsm "pending-changes apply --ignore-prompt"
Start-Process -NoNewWindow -Wait tsm "initialize --start-server --request-timeout 1800"

# 4. Install tabcmd
# download tabcmd installer
$url = "https://downloads.tableau.com/esdalt/$($version)/TableauServerTabcmd-64bit-$($version.Replace('.', '-')).exe"
$installerFileName = $url.Substring($url.LastIndexOf("/") + 1)
$installerFilePath = Join-Path -Path $downloadPath -ChildPath $installerFileName

If(Test-Path $installerFilePath -PathType Leaf) {
  Write-Log("$($installerFilePath) exists, skip downloading")
} else {
  Write-Log("Downloading installer from $($url)")
  (New-Object System.Net.WebClient).DownloadFile($url, $installerFilePath)
}

# sleep for 5 seconds
Start-Sleep -s 5

# install tabcmd
$proc = Start-Process -NoNewWindow -Wait $installerFilePath "/install /silent /norestart ACCEPTEULA=1"
Write-Log($proc.ExitCode)
Write-Log("Installed Tabcmd.")

# sleep for 5 seconds
Start-Sleep -s 5

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

# get port from json file
$portString = Select-String -Path ".\ts_settings.json" -Pattern '"port" *:' | select-object -ExpandProperty Line
$port = [regex]::match($portString, '(\d+)').Groups[1].Value

# 5. Add an Administrator Account
Start-Process -NoNewWindow -Wait tabcmd "initialuser --server http://localhost:$($port) --username $($appProps."ts.admin.user") --password $($appProps."ts.admin.password")"
Write-Log("Created admin account: $($appProps."admin.user")")

Write-Log("Finished.")
