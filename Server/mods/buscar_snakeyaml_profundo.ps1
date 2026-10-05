Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host ""
Write-Host "Buscando SnakeYAML dentro de JARs y JARs anidados..." -ForegroundColor Cyan
Write-Host ""

$target = "org/yaml/snakeyaml/LoaderOptions.class"
$found = $false

function Search-ZipStream {
    param(
        [System.IO.Stream]$Stream,
        [string]$SourceChain,
        [int]$Depth = 0
    )

    if ($Depth -gt 4) {
        return
    }

    try {
        $zip = New-Object System.IO.Compression.ZipArchive(
            $Stream,
            [System.IO.Compression.ZipArchiveMode]::Read,
            $true
        )

        try {
            foreach ($entry in $zip.Entries) {
                if ($entry.FullName -eq $target) {
                    Write-Host ""
                    Write-Host "ENCONTRADO:" -ForegroundColor Green
                    Write-Host "  $SourceChain" -ForegroundColor Yellow
                    $script:found = $true
                }

                if ($entry.FullName.ToLowerInvariant().EndsWith(".jar")) {
                    try {
                        $nestedMemory = New-Object System.IO.MemoryStream
                        $entryStream = $entry.Open()
                        try {
                            $entryStream.CopyTo($nestedMemory)
                        }
                        finally {
                            $entryStream.Dispose()
                        }

                        $nestedMemory.Position = 0
                        Search-ZipStream `
                            -Stream $nestedMemory `
                            -SourceChain ($SourceChain + " -> " + $entry.FullName) `
                            -Depth ($Depth + 1)

                        $nestedMemory.Dispose()
                    }
                    catch {
                        # Algunos .jar anidados pueden no ser ZIP validos; ignorar
                    }
                }
            }
        }
        finally {
            $zip.Dispose()
        }
    }
    catch {
        # No es un ZIP/JAR valido
    }
}

$jarFiles = Get-ChildItem -Path $PSScriptRoot -Filter *.jar -File

foreach ($file in $jarFiles) {
    try {
        $fs = [System.IO.File]::OpenRead($file.FullName)
        try {
            Search-ZipStream -Stream $fs -SourceChain $file.Name -Depth 0
        }
        finally {
            $fs.Dispose()
        }
    }
    catch {
        Write-Host "No pude revisar: $($file.Name)" -ForegroundColor DarkGray
    }
}

Write-Host ""

if (-not $found) {
    Write-Host "No encontre LoaderOptions.class ni siquiera dentro de JARs anidados." -ForegroundColor Red
    Write-Host ""
    Write-Host "Eso apunta a que SnakeYAML podria estar viniendo de:" -ForegroundColor Yellow
    Write-Host "  - una libreria externa cargada por el host"
    Write-Host "  - el mod/plugin mcserverhost"
    Write-Host "  - una carpeta libraries fuera de mods"
}
else {
    Write-Host "Esos son los JARs que incluyen SnakeYAML directa o indirectamente." -ForegroundColor Green
}

Write-Host ""
Read-Host "Presiona Enter para cerrar"
