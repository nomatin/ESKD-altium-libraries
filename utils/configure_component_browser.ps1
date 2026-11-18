[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$NoPause,
    [switch]$RestoreLatest,
    [string]$Restore,
    [string]$AltiumProfile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$libraryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$backupRoot = Join-Path $libraryRoot 'Backup\ComponentBrowser'
$settingsSuffix = '\DesignExplorer\Preferences\ComponentSearch\SearchResult'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-AltiumClosed {
    if (Get-Process -Name X2 -ErrorAction SilentlyContinue) {
        throw 'Close Altium Designer, then run this file again. No settings were changed.'
    }
}

function Read-JsonFile([string]$Path) {
    return ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Open-UserRegistry {
    return [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::CurrentUser,
        [Microsoft.Win32.RegistryView]::Registry64)
}

function Find-SettingsKey($Base) {
    $parent = $Base.OpenSubKey('Software\Altium')
    if ($null -eq $parent) { throw 'Altium Designer settings were not found for this Windows user.' }
    try {
        $candidates = @()
        foreach ($name in $parent.GetSubKeyNames()) {
            if ($name -notlike 'Altium Designer {*}') { continue }
            if ($AltiumProfile -and $name -ne $AltiumProfile -and $name -notlike "*$AltiumProfile*") { continue }
            $path = 'Software\Altium\' + $name + $settingsSuffix
            $key = $Base.OpenSubKey($path)
            if ($null -eq $key) { continue }
            try {
                $score = @($key.GetValueNames() | Where-Object {
                    $_.IndexOf($libraryRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
                }).Count
                $candidates += [pscustomobject]@{ Path = $path; Score = $score }
            }
            finally { $key.Dispose() }
        }
        $ordered = @($candidates | Sort-Object Score -Descending)
        if ($ordered.Count -eq 0) { throw 'Open the installed library once in Altium, close Altium, then run this file again.' }
        if ($ordered.Count -gt 1 -and $ordered[0].Score -eq $ordered[1].Score) {
            throw 'Several Altium profiles match. Run with -AltiumProfile followed by the required installation name or GUID.'
        }
        return $ordered[0].Path
    }
    finally { $parent.Dispose() }
}

function Get-ValueSnapshot($Key, [string]$Name) {
    if ($Key.GetValueNames() -contains $Name) {
        $kind = $Key.GetValueKind($Name).ToString()
        if ($kind -ne 'String') { throw "Unexpected registry value type for: $Name. Nothing was changed." }
        return [pscustomobject]@{
            Name = $Name; Exists = $true; Kind = $kind
            Value = $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
    }
    return [pscustomobject]@{ Name = $Name; Exists = $false; Kind = 'String'; Value = $null }
}

function Assert-TargetName([string]$Name) {
    # A restore file may only address category values belonging to this library.
    $allowed = $false
    foreach ($stem in @('MY_LIB', 'MY_LIB_IEC')) {
        $prefix = Join-Path $libraryRoot ($stem + '.DbLib')
        if ($Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
            $Name.Substring($prefix.Length) -match '^.+\$(\|Dialog)?$') { $allowed = $true }
    }
    if (-not $allowed) { throw "Backup contains a value outside this library: $Name" }
}

function Save-Backup($Key, [string]$KeyPath, [array]$Names, [string]$Operation) {
    $values = @($Names | ForEach-Object { Get-ValueSnapshot $Key $_ })
    $folder = Join-Path $backupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    [void][IO.Directory]::CreateDirectory($folder)
    $path = Join-Path $folder 'settings.json'
    $snapshot = [ordered]@{
        Version = 1; CreatedUtc = [DateTime]::UtcNow.ToString('o'); Operation = $Operation
        LibraryRoot = $libraryRoot; RegistryKey = $KeyPath; Values = $values
    }
    [IO.File]::WriteAllText($path, ($snapshot | ConvertTo-Json -Depth 30), $utf8)
    # Verify the backup is readable and complete before touching the registry.
    $saved = Read-JsonFile $path
    if ($saved.Version -ne 1 -or @($saved.Values).Count -ne $values.Count) { throw 'Backup verification failed. No settings were changed.' }
    for ($i = 0; $i -lt $values.Count; $i++) {
        if ($saved.Values[$i].Name -cne $values[$i].Name -or
            $saved.Values[$i].Exists -ne $values[$i].Exists -or
            $saved.Values[$i].Value -cne $values[$i].Value) { throw 'Backup verification failed. No settings were changed.' }
    }
    [IO.File]::WriteAllText((Join-Path $folder 'README.txt'),
        "Altium component browser settings backup.`r`nOperation: $Operation`r`nRestore by dragging settings.json onto utils\restore_component_browser.cmd.`r`n", $utf8)
    Write-Host "Backup: $path"
    return [pscustomobject]@{ Path = $path; Snapshot = $saved }
}

function Set-Snapshot($Key, $Snapshot) {
    foreach ($row in @($Snapshot.Values)) {
        if ($row.Exists) { $Key.SetValue($row.Name, [string]$row.Value, [Microsoft.Win32.RegistryValueKind]::String) }
        else { $Key.DeleteValue($row.Name, $false) }
    }
    $Key.Flush()
    foreach ($row in @($Snapshot.Values)) {
        $actual = Get-ValueSnapshot $Key $row.Name
        if ($actual.Exists -ne $row.Exists -or ($row.Exists -and $actual.Value -cne $row.Value)) {
            throw "Registry verification failed for: $($row.Name)"
        }
    }
}

function Restore-Settings($Base, [string]$Path) {
    $snapshot = Read-JsonFile $Path
    if ($snapshot.Version -ne 1 -or @($snapshot.Values).Count -eq 0) { throw 'Unsupported or empty backup.' }
    if ($snapshot.RegistryKey -notmatch '^Software\\Altium\\Altium Designer \{[0-9A-Fa-f-]+\}\\DesignExplorer\\Preferences\\ComponentSearch\\SearchResult$') {
        throw 'The backup does not contain an Altium component browser settings key.'
    }
    if (-not [string]::Equals($snapshot.LibraryRoot, $libraryRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'This backup belongs to a different library location. Restore it from the original library folder.'
    }
    foreach ($row in @($snapshot.Values)) {
        Assert-TargetName $row.Name
        if ($row.Kind -ne 'String' -or $row.Exists -isnot [bool]) { throw 'Invalid backup value.' }
    }
    $key = $Base.OpenSubKey($snapshot.RegistryKey, $true)
    if ($null -eq $key) { throw 'The Altium profile from this backup was not found.' }
    try {
        if ($CheckOnly) { Write-Host "Restore check passed: $(@($snapshot.Values).Count) category profiles."; return }
        $safety = Save-Backup $key $snapshot.RegistryKey @($snapshot.Values | ForEach-Object { $_.Name }) 'before-restore'
        try { Set-Snapshot $key $snapshot }
        catch { Set-Snapshot $key $safety.Snapshot; throw }
        Write-Host 'Previous component browser settings restored.'
    }
    finally { $key.Dispose() }
}

function Apply-Settings($Base) {
    $config = Read-JsonFile (Join-Path $libraryRoot 'Settings\component_browser.json')
    if ($config.version -ne 1 -or @($config.categories).Count -eq 0) { throw 'Unsupported or empty component browser configuration.' }
    $keyPath = Find-SettingsKey $Base
    $key = $Base.OpenSubKey($keyPath, $true)
    try {
        $changes = @()
        foreach ($category in $config.categories) {
            if ($category.stem -notin @('MY_LIB', 'MY_LIB_IEC') -or [string]::IsNullOrWhiteSpace($category.sheet)) { throw 'Invalid library category.' }
            $dbPath = Join-Path $libraryRoot ($category.stem + '.DbLib')
            if (-not [IO.File]::Exists($dbPath)) { throw "Library file not found: $dbPath" }
            $columnNames = @($category.columns | ForEach-Object { $_.name })
            if ($columnNames.Count -eq 0 -or $columnNames[0] -ne 'ID' -or
                @($columnNames | Select-Object -Unique).Count -ne $columnNames.Count -or
                @($columnNames | Where-Object { $_ -in @('Library Ref', 'LibRef', 'LibReference') }).Count -gt 0) {
                throw "Invalid visible columns for: $($category.sheet)"
            }
            foreach ($suffix in @('', '|Dialog')) {
                $name = $dbPath + $category.sheet + '$' + $suffix
                Assert-TargetName $name
                $previous = Get-ValueSnapshot $key $name
                if ($previous.Exists) { $data = $previous.Value | ConvertFrom-Json }
                else { $data = [pscustomobject]@{ FilterString = $null; ComponentParametersViewExpanded = $true } }
                if ($null -eq $data) { throw "Empty saved profile: $name" }
                $columns = @()
                $index = 0
                foreach ($column in $category.columns) {
                    if ([string]::IsNullOrWhiteSpace($column.name) -or [double]$column.width -le 0) { throw 'Invalid column name or width.' }
                    $columns += [ordered]@{
                        Name = $column.name; ParamName = ''; VisibleIndex = $index; Width = [double]$column.width
                        GroupIndex = -1; SortIndex = $(if ($index -eq 0) { 0 } else { -1 })
                        IsSortedAscending = $(if ($index -eq 0) { $true } else { $null }); IsGroupSortedAscending = $false
                    }
                    $index++
                }
                $data | Add-Member -MemberType NoteProperty -Name VisibleColumns -Value $columns -Force
                $data | Add-Member -MemberType NoteProperty -Name IsGroupingEnabled -Value $false -Force
                $data | Add-Member -MemberType NoteProperty -Name IsManuallyCreatedSetting -Value $true -Force
                $changes += [pscustomobject]@{ Name = $name; Exists = $true; Kind = 'String'; Value = ($data | ConvertTo-Json -Depth 30 -Compress) }
            }
        }
        $uniqueNames = @($changes | ForEach-Object { $_.Name } | Select-Object -Unique)
        if ($uniqueNames.Count -ne $changes.Count) { throw 'Duplicate category profiles in configuration.' }
        if ($CheckOnly) { Write-Host "Check passed: $($config.categories.Count) categories, $($changes.Count) category profiles. No settings changed."; return }
        $backup = Save-Backup $key $keyPath $uniqueNames 'before-apply'
        try { Set-Snapshot $key ([pscustomobject]@{ Values = $changes }) }
        catch { Set-Snapshot $key $backup.Snapshot; throw }
        Write-Host "Configured $($changes.Count) category profiles. Start Altium Designer to load the new columns."
    }
    finally { $key.Dispose() }
}

$exitCode = 0
$base = $null
try {
    if ($Restore -and $RestoreLatest) { throw 'Use either -Restore or -RestoreLatest.' }
    Assert-AltiumClosed
    $base = Open-UserRegistry
    if ($RestoreLatest) {
        $latest = @(Get-ChildItem -LiteralPath $backupRoot -Filter settings.json -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { (Read-JsonFile $_.FullName).Operation -eq 'before-apply' } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
        if ($latest.Count -eq 0) { throw 'No settings backup was found.' }
        $Restore = $latest[0].FullName
    }
    if ($Restore) { Restore-Settings $base ([IO.Path]::GetFullPath($Restore)) }
    else { Apply-Settings $base }
}
catch {
    Write-Host ''
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
}
finally {
    if ($null -ne $base) { $base.Dispose() }
    if (-not $NoPause) {
        Write-Host ''
        [void](Read-Host 'Press Enter to close')
    }
}
exit $exitCode
