<#
.SYNOPSIS
    Setup GitHub Actions Self-Hosted Runner di Windows
.DESCRIPTION
    Download, configure, dan install GitHub Actions runner sebagai Windows Service.
    Runner akan build Otomatis tiap push ke branch 'lite' di repo OmniRoute-Lite.
.PREREQUISITES
    - Windows 10/11 (PowerShell 5.1+)
    - Docker Desktop terinstall & jalan
    - Git terinstall
    - Internet ~2GB untuk download pertama
    - GitHub Personal Access Token (PAT) dengan scope: repo, admin:repo_hook, workflow
.NOTES
    Author: Hermes Agent
    Repo: dianrestu/OmniRoute-Lite
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [string]$RepoUrl = "https://github.com/dianrestu/OmniRoute-Lite",
    
    [string]$WorkFolder = "D:\actions-runner\_work",
    
    [string]$RunnerFolder = "D:\actions-runner",
    
    [string]$RunnerVersion = "2.321.0",
    
    [switch]$ForceReinstall
)

# ───────────────────────────────────────────────────────────────────────────
# Helper Functions
# ───────────────────────────────────────────────────────────────────────────

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "OK"    { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Check-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Script harus dijalankan sebagai Administrator!" "ERROR"
        exit 1
    }
}

function Check-Prerequisites {
    Write-Log "Cek prerequisites..." "INFO"
    
    # Check Docker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Log "Docker tidak ditemukan. Install Docker Desktop dulu." "ERROR"
        exit 1
    }
    $dockerVersion = docker --version
    Write-Log "Docker: $dockerVersion" "OK"
    
    # Check Git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Git tidak ditemukan. Install Git dulu." "ERROR"
        exit 1
    }
    $gitVersion = git --version
    Write-Log "Git: $gitVersion" "OK"
    
    # Check Docker daemon running
    try {
        docker info | Out-Null
        Write-Log "Docker daemon running" "OK"
    } catch {
        Write-Log "Docker daemon tidak jalan. Start Docker Desktop dulu." "ERROR"
        exit 1
    }
    
    # Check disk space
    $drive = $RunnerFolder.Substring(0,3)
    $freeSpace = (Get-PSDrive -Name $drive[0]).Free / 1GB
    if ($freeSpace -lt 10) {
        Write-Log "Disk space kurang dari 10GB di $drive ($freeSpace GB free)" "WARN"
    } else {
        Write-Log "Disk space OK: $freeSpace GB free di $drive" "OK"
    }
}

# ───────────────────────────────────────────────────────────────────────────
# Main Setup
# ───────────────────────────────────────────────────────────────────────────

Write-Log "=== GitHub Self-Hosted Runner Setup ===" "INFO"
Write-Log "Repo: $RepoUrl" "INFO"
Write-Log "Runner folder: $RunnerFolder" "INFO"
Write-Log "Work folder: $WorkFolder" "INFO"

Check-Admin
Check-Prerequisites

# 1. Create folders
Write-Log "Buat folder..." "INFO"
if ($ForceReinstall -and (Test-Path $RunnerFolder)) {
    Write-Log "Force reinstall: hapus folder lama..." "WARN"
    Remove-Item -Recurse -Force $RunnerFolder -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $RunnerFolder | Out-Null
New-Item -ItemType Directory -Force -Path $WorkFolder | Out-Null
Write-Log "Folder siap" "OK"

# 2. Download runner
$runnerZip = "actions-runner-win-x64-$RunnerVersion.zip"
$runnerUrl = "https://github.com/actions/runner/releases/download/v$RunnerVersion/$runnerZip"
$zipPath = Join-Path $RunnerFolder $runnerZip

Write-Log "Download runner v$RunnerVersion (~150MB)..." "INFO"
try {
    Invoke-WebRequest -Uri $runnerUrl -OutFile $zipPath -UseBasicParsing
    Write-Log "Download selesai" "OK"
} catch {
    Write-Log "Gagal download: $_" "ERROR"
    exit 1
}

# 3. Extract
Write-Log "Extract runner..." "INFO"
try {
    Expand-Archive -Path $zipPath -DestinationPath $RunnerFolder -Force
    Write-Log "Extract selesai" "OK"
} catch {
    Write-Log "Gagal extract: $_" "ERROR"
    exit 1
}

# Cleanup zip
Remove-Item $zipPath -Force

# 4. Configure runner
Write-Log "Konfigurasi runner..." "INFO"
$configScript = Join-Path $RunnerFolder "config.cmd"

$configArgs = @(
    "--url", $RepoUrl
    "--token", $GitHubToken
    "--work", $WorkFolder
    "--unattended"
    "--replace"
    "--name", "$env:COMPUTERNAME-OmniRoute-Lite"
    "--labels", "self-hosted,windows,x64,omniroute,docker"
)

Write-Log "Running config.cmd..." "INFO"
$configProcess = Start-Process -FilePath $configScript -ArgumentList $configArgs -Wait -PassThru -NoNewWindow
if ($configProcess.ExitCode -ne 0) {
    Write-Log "Konfigurasi gagal (exit code: $($configProcess.ExitCode))" "ERROR"
    exit 1
}
Write-Log "Konfigurasi selesai" "OK"

# 5. Install as Service
Write-Log "Install Windows Service..." "INFO"
$svcScript = Join-Path $RunnerFolder "svc.exe"

$installProcess = Start-Process -FilePath $svcScript -ArgumentList "install" -Wait -PassThru -NoNewWindow
if ($installProcess.ExitCode -ne 0) {
    Write-Log "Install service gagal" "ERROR"
    exit 1
}
Write-Log "Service terinstall" "OK"

# 6. Start Service
Write-Log "Start service..." "INFO"
$startProcess = Start-Process -FilePath $svcScript -ArgumentList "start" -Wait -PassThru -NoNewWindow
if ($startProcess.ExitCode -ne 0) {
    Write-Log "Start service gagal" "ERROR"
    exit 1
}
Write-Log "Service running" "OK"

# 7. Verify
Write-Log "Verifikasi runner..." "INFO"
Start-Sleep -Seconds 5
$status = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue
if ($status -and $status.Status -eq "Running") {
    Write-Log "Runner service: $($status.Name) - $($status.Status)" "OK"
} else {
    Write-Log "Runner service tidak ditemukan atau tidak running" "WARN"
}

# ───────────────────────────────────────────────────────────────────────────
# Summary
# ───────────────────────────────────────────────────────────────────────────

Write-Log "=== SETUP SELESAI ===" "OK"
Write-Log "" "INFO"
Write-Log "Runner name: $env:COMPUTERNAME-OmniRoute-Lite" "INFO"
Write-Log "Labels: self-hosted, windows, x64, omniroute, docker" "INFO"
Write-Log "Work folder: $WorkFolder" "INFO"
Write-Log "" "INFO"
Write-Log "Cek status di GitHub:" "INFO"
Write-Log "  https://github.com/dianrestu/OmniRoute-Lite/settings/actions/runners" "INFO"
Write-Log "" "INFO"
Write-Log "Workflow sudah pakai 'runs-on: self-hosted'?" "INFO"
Write-Log "  Kalau belum, update .github/workflows/docker-lite.yml:" "INFO"
Write-Log "    jobs:" "INFO"
Write-Log "      build:" "INFO"
Write-Log "        runs-on: self-hosted  # <-- ganti dari ubuntu-latest" "INFO"
Write-Log "" "INFO"
Write-Log "Test build:" "INFO"
Write-Log "  git commit --allow-empty -m 'test runner' && git push origin lite" "INFO"