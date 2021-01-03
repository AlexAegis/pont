#!/usr/bin/env powershell

# Custom folder on path, left here for reference

# $appdata = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
# $userbin = "$appdata\Local\bin\"
# New-Item -ItemType Directory -Force -Path $userbin
# New-Item -ItemType HardLink -Force -Path "$PSScriptRoot\pont.sh" -Target "$userbin\pont"
#
# $currentUserPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
#
# if (-not $currentUserPath -like "*$userbin*") {
# 	[Environment]::SetEnvironmentVariable(
# 		"Path",
# 		"$currentUserPath;$userbin",
# 		[EnvironmentVariableTarget]::User)
# }

# The same PATH variable is available from WSL and MINGW64
New-Item -ItemType HardLink -Force -Path "$env:windir\pont" -Target "$PSScriptRoot\pont.sh"
