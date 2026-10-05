[CmdletBinding()]
param(
    [ValidateSet('Completo', 'Copiar', 'SoloSubir')]
    [string]$Modo = 'Completo',
    [string]$Mensaje = '',
    [string]$ProyectoMod = 'E:\DESKTOP 2026\semencraft-mod-template-1.21.1'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = Split-Path -Parent $PSScriptRoot
$BuildLibs = Join-Path $ProyectoMod 'build\libs'
$RequiredMods = Join-Path $Repo 'Required\mods'
$ServerMods = Join-Path $Repo 'Server\mods'

function Write-Step {
    param([string]$Text)
    Write-Host "`n==> $Text" -ForegroundColor Cyan
}

function Find-Git {
    $command = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }

    $fallback = 'C:\Program Files\Git\cmd\git.exe'
    if (Test-Path -LiteralPath $fallback) { return $fallback }

    throw 'Git no esta instalado o no se encuentra en PATH.'
}

$Git = Find-Git

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$GitArgs)

    & $Git -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Git fallo: git $($GitArgs -join ' ')"
    }
}

function Copy-LatestSemencraftJar {
    if (-not (Test-Path -LiteralPath $BuildLibs)) {
        throw "No existe la carpeta de compilacion: $BuildLibs"
    }

    $jar = Get-ChildItem -LiteralPath $BuildLibs -File -Filter 'semencraft-mod-mc1.21.1-*.jar' |
        Where-Object {
            $_.Name -notmatch '-sources\.jar$' -and
            $_.Name -notmatch '-dev\.jar$' -and
            $_.Name -notmatch '-javadoc\.jar$'
        } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $jar) {
        throw "No encontre un JAR ejecutable de Semencraft en: $BuildLibs"
    }

    New-Item -ItemType Directory -Path $RequiredMods -Force | Out-Null
    New-Item -ItemType Directory -Path $ServerMods -Force | Out-Null

    foreach ($folder in @($RequiredMods, $ServerMods)) {
        Get-ChildItem -LiteralPath $folder -File -Filter 'semencraft-mod-mc*.jar' |
            Where-Object { $_.Name -ne $jar.Name } |
            Remove-Item -Force

        Copy-Item -LiteralPath $jar.FullName -Destination (Join-Path $folder $jar.Name) -Force
    }

    $sourceHash = (Get-FileHash -LiteralPath $jar.FullName -Algorithm SHA256).Hash
    $requiredHash = (Get-FileHash -LiteralPath (Join-Path $RequiredMods $jar.Name) -Algorithm SHA256).Hash
    $serverHash = (Get-FileHash -LiteralPath (Join-Path $ServerMods $jar.Name) -Algorithm SHA256).Hash

    if ($sourceHash -ne $requiredHash -or $sourceHash -ne $serverHash) {
        throw 'La verificacion del JAR fallo: las copias no son identicas.'
    }

    Write-Host "JAR: $($jar.Name)" -ForegroundColor Green
    Write-Host "SHA-256: $sourceHash"
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) {
        throw "La carpeta no es un repositorio Git: $Repo"
    }

    if ($Modo -eq 'Completo') {
        Write-Step 'Compilando Semencraft'
        $gradle = Join-Path $ProyectoMod 'gradlew.bat'
        if (-not (Test-Path -LiteralPath $gradle)) {
            throw "No encontre gradlew.bat en: $ProyectoMod"
        }

        Push-Location $ProyectoMod
        try {
            & $gradle clean build -x test
            if ($LASTEXITCODE -ne 0) {
                throw 'La compilacion fallo. No se copio ni subio ningun archivo.'
            }
        }
        finally {
            Pop-Location
        }
    }

    if ($Modo -in @('Completo', 'Copiar')) {
        Write-Step 'Actualizando el JAR en Required y Server'
        Copy-LatestSemencraftJar
    }

    Write-Step 'Preparando los cambios'
    Invoke-Git -GitArgs @('add', '-A')

    & $Git -C $Repo diff --cached --quiet
    $HasChanges = $LASTEXITCODE -ne 0

    if ($HasChanges) {
        if ([string]::IsNullOrWhiteSpace($Mensaje)) {
            $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $Mensaje = "Update Semencraft Modpacks - $stamp"
        }

        Write-Step "Creando commit: $Mensaje"
        Invoke-Git -GitArgs @('commit', '-m', $Mensaje)
    }
    else {
        Write-Host 'No hay cambios locales nuevos para crear un commit.' -ForegroundColor Yellow
    }

    $branch = (& $Git -C $Repo branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
        throw 'No pude detectar la rama actual.'
    }

    Write-Step "Sincronizando origin/$branch"
    Invoke-Git -GitArgs @('pull', '--rebase', 'origin', $branch)

    Write-Step "Subiendo origin/$branch"
    Invoke-Git -GitArgs @('push', 'origin', $branch)

    Write-Step 'Verificando el resultado'
    $local = (& $Git -C $Repo rev-parse HEAD).Trim()
    $remoteLine = (& $Git -C $Repo ls-remote origin "refs/heads/$branch" | Select-Object -First 1)
    $remote = ($remoteLine -split "`t")[0]

    if ($local -ne $remote) {
        throw 'El push termino, pero la rama remota no coincide con el commit local.'
    }

    Write-Host "Listo. GitHub esta actualizado en el commit $($local.Substring(0, 7))." -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'No se borraron tus cambios locales.' -ForegroundColor Yellow

    $rebaseMarker = Join-Path $Repo '.git\rebase-merge'
    $rebaseApplyMarker = Join-Path $Repo '.git\rebase-apply'
    if ((Test-Path -LiteralPath $rebaseMarker) -or (Test-Path -LiteralPath $rebaseApplyMarker)) {
        Write-Host 'Git dejo un rebase pausado por un conflicto. Resuelvelo antes de volver a ejecutar el script.' -ForegroundColor Yellow
    }

    exit 1
}
