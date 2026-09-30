# 从 GitHub release 安装 aliyun-cli（Windows）
# 用法:  powershell -ExecutionPolicy Bypass -File install.ps1  [版本号]
param([string]$Version = "")

$Repo = "aliyun/aliyun-cli"
# 安装到用户级全局路径，并持久化到用户 PATH
$InstallDir = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".aliyun\bin"
# Windows 官方仅发布 amd64 包
$ARCH = "amd64"

# 获取最新版本号
if (-not $Version) {
  Write-Host ">> 获取最新版本号..."
  $resp = Invoke-WebRequest -Uri "https://github.com/$Repo/releases/latest" -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
  $loc = $resp.Headers.Location
  $Version = [regex]::Match($loc, 'v[0-9.]+').Value
}
if (-not $Version) { Write-Host "!! 无法获取版本号" -ForegroundColor Red; exit 1 }
Write-Host ">> 目标版本: $Version"

# 去掉 tag 前缀 v（标签 v3.5.1，文件名 3.5.1）
$VerNoV = $Version -replace '^v',''
$File = "aliyun-cli-windows-$VerNoV-$ARCH.zip"
$Url = "https://github.com/$Repo/releases/download/$Version/$File"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Write-Host ">> 下载 $Url"
$Zip = Join-Path $env:TEMP $File
Invoke-WebRequest -Uri $Url -OutFile $Zip

Write-Host ">> 校验 SHA256..."
$Expected = (Invoke-WebRequest -Uri "https://github.com/$Repo/releases/download/$Version/SHASUMS256.txt" -UseBasicParsing).Content
$Expected = ($Expected -split "`n" | Where-Object { $_ -match " $File$" }) -split " " | Select-Object -First 1
$Actual = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower()
if ($Actual -ne $Expected) { Write-Host "!! SHA256 校验失败: $Actual != $Expected" -ForegroundColor Red; exit 1 }
Write-Host ">> SHA256 OK"

Expand-Archive -Path $Zip -DestinationPath $InstallDir -Force
Remove-Item $Zip -Force

$Exe = Join-Path $InstallDir "aliyun.exe"
Write-Host ">> 已安装到 $Exe"
& $Exe version
