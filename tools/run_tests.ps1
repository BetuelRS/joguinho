# Roda todos os testes GUT headless. Exit code != 0 se houver falha.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

# Resolve o executavel do Godot. No Windows, o build "godot.exe" costuma ser
# um shim/symlink (ex.: WinGet Links) para o binario sem subsistema de console
# (Godot_v*_win64.exe), que nao propaga corretamente o exit code para o
# PowerShell ($LASTEXITCODE fica vazio mesmo com saida no console). Quando
# existe a variante "*_console.exe" ao lado do binario resolvido, ela e usada
# em vez disso, pois relata o exit code de forma confiavel.
function Resolve-GodotExe {
	$cmd = Get-Command godot -ErrorAction Stop
	$target = $cmd.Source
	$item = Get-Item -LiteralPath $target -ErrorAction SilentlyContinue
	if ($item -and $item.LinkType -and $item.Target) {
		$linkTarget = $item.Target
		if ($linkTarget -is [System.Array]) { $linkTarget = $linkTarget[0] }
		$target = $linkTarget
	}
	$dir = Split-Path -Parent $target
	$nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($target)
	$consoleVariant = Join-Path $dir "$nameNoExt`_console.exe"
	if (Test-Path $consoleVariant) {
		return $consoleVariant
	}
	return $target
}

$godotExe = Resolve-GodotExe

# Importa recursos e atualiza o cache de class_name (necessário para testes headless).
& $godotExe --headless --path $root --import | Out-Null
& $godotExe --headless --path $root -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit @args
exit $LASTEXITCODE
