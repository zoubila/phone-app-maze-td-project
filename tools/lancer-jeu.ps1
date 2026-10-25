# Lanceur Windows : lit des valeurs, sans executer le contenu des fichiers .env.
# -Check verifie les chemins sans ouvrir de fenetre de jeu.
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$taskProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

# Charge seulement les deux variables du lanceur. Accepte les valeurs avec espaces
# et les guillemets facultatifs ; ne remplace ni $variables ni %VARIABLES% dans les valeurs.
function Read-GameEnvironment {
    param([string]$Path, [hashtable]$Values)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $taskLineNumber = 0
    foreach ($taskRawLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $taskLineNumber++
        $taskLine = $taskRawLine.Trim()
        if ($taskLine.Length -eq 0 -or $taskLine.StartsWith('#')) { continue }
        if ($taskLine -notmatch '^(GODOT_EXE|GAME_DIR)\s*=(.*)$') {
            throw "Configuration invalide dans ${Path}:${taskLineNumber}. Utilisez GODOT_EXE=... ou GAME_DIR=..."
        }
        $taskKey = $Matches[1]
        $taskValue = $Matches[2].Trim()
        if ($taskValue.Length -ge 2) {
            $taskFirst = $taskValue[0]
            $taskLast = $taskValue[$taskValue.Length - 1]
            if (($taskFirst -eq '"' -and $taskLast -eq '"') -or ($taskFirst -eq "'" -and $taskLast -eq "'")) {
                $taskValue = $taskValue.Substring(1, $taskValue.Length - 2)
            }
        }
        $Values[$taskKey] = $taskValue
    }
}

# Transforme un chemin relatif en chemin absolu, toujours depuis le dossier du lanceur.
function Resolve-GamePath {
    param([string]$Value)
    if ([IO.Path]::IsPathRooted($Value)) { return [IO.Path]::GetFullPath($Value) }
    return [IO.Path]::GetFullPath((Join-Path $taskProjectRoot $Value))
}

try {
    $taskValues = @{}
    Read-GameEnvironment (Join-Path $taskProjectRoot '.env') $taskValues
    Read-GameEnvironment (Join-Path $taskProjectRoot '.env.local') $taskValues
    # Une variable fournie directement par le terminal reste prioritaire sur les fichiers.
    foreach ($taskKey in @('GODOT_EXE', 'GAME_DIR')) {
        $taskInheritedValue = [Environment]::GetEnvironmentVariable($taskKey, 'Process')
        if (-not [string]::IsNullOrWhiteSpace($taskInheritedValue)) { $taskValues[$taskKey] = $taskInheritedValue }
        if ([string]::IsNullOrWhiteSpace($taskValues[$taskKey])) {
            throw "${taskKey} manque. Configurez .env ou .env.local dans $taskProjectRoot"
        }
    }

    $taskGameDirectory = Resolve-GamePath $taskValues['GAME_DIR']
    if (-not (Test-Path -LiteralPath (Join-Path $taskGameDirectory 'project.godot') -PathType Leaf)) {
        throw "project.godot introuvable dans GAME_DIR : $taskGameDirectory"
    }
    $taskGodotExecutable = Resolve-GamePath $taskValues['GODOT_EXE']
    if (-not (Test-Path -LiteralPath $taskGodotExecutable -PathType Leaf)) {
        # Un nom seul, comme godot.exe, peut aussi designer une application du PATH.
        if ($taskValues['GODOT_EXE'] -notmatch '[\\/]') {
            $taskCommand = Get-Command -Name $taskValues['GODOT_EXE'] -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $taskCommand) { $taskGodotExecutable = $taskCommand.Source }
        }
        if (-not (Test-Path -LiteralPath $taskGodotExecutable -PathType Leaf)) {
            throw "Godot introuvable. Corrigez GODOT_EXE dans .env.local : $($taskValues['GODOT_EXE'])"
        }
    }

    if ($Check) {
        Write-Output "GODOT_EXE=$taskGodotExecutable"
        Write-Output "GAME_DIR=$taskGameDirectory"
        exit 0
    }
    # Le processus Godot recoit aussi les variables resolues. La configuration reste locale
    # au processus du lanceur et n'ecrit pas dans les variables permanentes de Windows.
    $env:GODOT_EXE = $taskGodotExecutable
    $env:GAME_DIR = $taskGameDirectory
    Start-Process -FilePath $taskGodotExecutable -WorkingDirectory $taskGameDirectory -ArgumentList @('--path', ('"{0}"' -f $taskGameDirectory))
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
