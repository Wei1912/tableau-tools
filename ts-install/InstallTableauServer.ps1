<#
Auto script for installing Tableau Server

Auther: wcheng
Date: 2020-06-14
#>

#Requires -RunAsAdministrator

function Write-Log($log) {
  Write-Host (Get-Date).ToString('yyyy/MM/dd HH:mm:ss') $log
}

# how to use
$__usage="
Usage: sudo bash install.sh [Options]

Options:
  -h, --help                Print usage
  -v, --version <version>   Tableau Server version
  --resume <n>              Resume installation after interruption
        n:
          1. Install TSM
          2. Activate
          3. Register
          4. Configure and initialize initial node
          5. Add an administrator account
"

# read arguments
$tsVersion = ""
$runStep = 0

$i = 0
while ($i -lt $args.Length) {
  $arg = $args[$i]
  if ($arg -eq "-v" -or $arg -eq "--version" ) {
    $tsVersion = $args[++$i]
  } elseif ($arg -eq "-h" -or $arg -eq "--help") {
    Write-Host $__usage
    exit
  } elseif ($arg -eq "--resume") {
    $runStep = $args[++$i]
    if (-Not ($runStep -ge 1 -and $runStep -le 5)) {
      throw 'Error: Please specify a number of 1-5 for --resume.'
    }
  } else {
    throw "Error: Unrecognized argument: $arg"
  }
  $i++
}

# check Tableau Server version
if ([string]::IsNullOrEmpty($tsVersion)) {
  throw 'Error: No version of Tableau Server.'
}
$vs = $tsVersion.Split('.')
if ($vs.Length -ne 3) {
  throw 'Error: Invalid version.'
}
$versionArray = [int[]]::new($vs.Length)
for ($i = 0; $i -lt $vs.Length; $i++) {
  $versionArray[$i] = [int]$vs[$i]
}

$curPath = $PSScriptRoot
Set-Location -Path $curPath
Write-Log($PWD)

# check config
$appProps = ConvertFrom-StringData (get-content ./settings.properties -raw)
$productKey = $appProps."ts.product.key"
if ([string]::IsNullOrEmpty($productKey)) {
  throw 'Error: No product key.'
}

Write-Log("Will install Tableau Server $($tsVersion)")

# create download folder
$downloadPath = Join-Path -Path $curPath -ChildPath "download"
if (-Not (test-path $downloadPath))
{
  $null = New-Item -ItemType Directory -Force -Path $downloadPath
}

if ($runStep -le 1) {
  Write-Log("1. Installing TSM ...")
  # download installer
  $url = "https://downloads.tableau.com/esdalt/$($tsVersion)/TableauServer-64bit-$($tsVersion.Replace('.', '-')).exe"
  $installerFileName = $url.Substring($url.LastIndexOf("/") + 1)
  $installerFilePath = Join-Path -Path $downloadPath -ChildPath $installerFileName

  if (Test-Path $installerFilePath -PathType Leaf) {
    Write-Log("$($installerFilePath) exists, skip downloading")
  } else {
    Write-Log("Downloading installer from $($url)")
    (New-Object System.Net.WebClient).DownloadFile($url, $installerFilePath)
    Start-Sleep -s 5
    Write-Log("Downloading installer finished")
  }

  $arguments = [System.Collections.ArrayList]@("/silent")
  if (($versionArray[0] -gt 2019) -or (($versionArray[0] -eq 2019) -and ($versionArray[1] -ge 4))) {
    # 2019.4 or later
    $arguments.Add("ACCEPTEULA=1")
  } else {
    $arguments.Add("/accepteula")
  }
  Write-Log("Installing TSM...")
  $proc = Start-Process -NoNewWindow -Wait -FilePath $installerFilePath -ArgumentList $arguments
  Start-Sleep -s 5
  Write-Log("Installing TSM finished with exit code $($proc.ExitCode)")
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

Write-Log("Run tsm status -v")
Start-Process -NoNewWindow -Wait tsm "status -v"

if ($runStep -le 2) {
  Write-Log("2. Activating...")
  Start-Process -NoNewWindow -Wait tsm "licenses activate -k $($productKey)"
  Write-Log("Activating finished")
}

if ($runStep -le 3) {
  Write-Log("3. Registering...")
  Start-Process -NoNewWindow -Wait tsm "register --file ./ts_registration.json"
  Write-Log("Registering finished")
}

if ($runStep -le 4) {
  Write-Log("4. Configuring and initializing initial node ...")
  Start-Process -NoNewWindow -Wait tsm "settings import -f ./ts_settings.json"
  Start-Process -NoNewWindow -Wait tsm "pending-changes apply --ignore-prompt"
  Start-Process -NoNewWindow -Wait tsm "initialize --start-server --request-timeout 3600"

  # TODO: should check the return code of tsm initialize, should stop installtation if it fails.

  Write-Log("Configuring and initializing initial node finished")
}

if ($runStep -le 5) {
  Write-Log("5. Adding an Administrator Account ...")

  # get port from json file
  $portString = Select-String -Path ".\ts_settings.json" -Pattern '"port" *:' | select-object -ExpandProperty Line
  $port = [regex]::match($portString, '(\d+)').Groups[1].Value
  If([string]::IsNullOrEmpty($port)) {
    $port = 80
  }

  # Add an Administrator Account
  Start-Process -NoNewWindow -Wait tabcmd "initialuser --server http://localhost:$($port) `
                --username $($appProps."ts.admin.user") --password $($appProps."ts.admin.password")"
  Write-Log("Created admin account: $($appProps."admin.user")")
}

Write-Log("Finished.")
