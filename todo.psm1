function Get-TodoPath {
    Param(
        $ConfigPath = "$PSScriptRoot/todoConfig.json"
    )
    if (Test-Path $ConfigPath) {
        $content = Get-Content $ConfigPath -Raw
        $todoConfig = ConvertFrom-Json $content
        return $todoConfig.todoConfig.basePath
    }
    else {
        Write-Verbose "Could not find $ConfigPath. Defaulting todo base path to $HOME"
        return $HOME
    }
}

function todo {
    Param(
        [ValidateSet('a','r')]
        [string] $AddRemove,
        [string] $Item,
        [switch] $Purge,
        [string] $Path = "$(Get-TodoPath)/todo.txt"
    )

    Initialize-TodoItems -Path $Path
    [string[]] $todoItems = Get-Content $Path | Where-Object {$_} # ignore blank lines

    switch ($AddRemove) {
        'a' {
            $updatedTodo = Add-TodoItem -TodoItems $todoItems -ItemToAdd $Item
            Set-TodoContent -TodoItems $updatedTodo -Path $Path
            todo -Path $Path
        }
        'r' {
            $updatedTodo = Remove-TodoItem -TodoItems $todoItems -ItemIndexToRemove $Item -Purge:$Purge
            Set-TodoContent -TodoItems $updatedTodo -Path $Path
            todo -Path $Path
        }
        default {
            if (!$todoItems) {"No todos in $Path!"}
            else {Write-TodoItems -Items $todoItems}
        }
    }
}

function Initialize-TodoItems {
    Param(
        [string] $Path
    )
    if (!(Test-Path $Path)) {
        New-Item $Path -ItemType File -Force | Out-Null
        return "New todo file created in $Path"
    }
}

function Set-TodoContent {
    Param(
        [string[]] $TodoItems,
        [string] $Path
    )
    if (!$TodoItems) {Set-Content $Path -Value ""}
    else {$TodoItems | Set-Content $Path}
}

function Remove-TodoItem {
    Param(
        [string[]] $TodoItems,
        [string] $ItemIndexToRemove,
        [switch] $Purge
    )
    $updatedTodo = @()
    for ($i = 0; $i -lt $TodoItems.Count; $i++) {
        if ($i -ne $ItemIndexToRemove) {$updatedTodo += $TodoItems[$i]}
        elseif (($i -eq $ItemIndexToRemove) -and (!$Purge.IsPresent)) {
            New-TodoCompleted -Item $TodoItems[$i] -Path (Get-DonePath $Path)
        }
    }
    return $updatedTodo
}

function Add-TodoItem {
    Param(
        [string[]] $TodoItems,
        [string] $ItemToAdd
    )
    $updatedTodo = @()
    $ItemToAdd, $TodoItems | ForEach-Object {$updatedTodo += $_}
    return $updatedTodo
}

function Get-DonePath {
    Param(
        [Parameter(Mandatory)]
        [string] $Path
    )
    $parent = $Path | Split-Path
    $parts = ($Path | Split-Path -Leaf).Split('.')
    $name = $parts[0..($parts.Count - 2)]
    $doneName = ($name, 'done', $parts[-1] | %{$_}) -join '.'
    Join-Path $parent $doneName
}

function Write-TodoItems {
    Param(
        [Parameter(Mandatory)]
        [string[]] $Items
    )
    for ($i = 0; $i -lt $Items.Count; $i++) {
        "$i. $($Items[$i])"
    }
}

function New-TodoCompleted {
    Param(
        [string] $Item,
        [string] $Path = "$(Get-TodoPath)/todo.done.txt",
        [switch] $WhatIf
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Item"
    if ($WhatIf.IsPresent) {
        return $entry
    }
    else {
        Add-Content -Value $entry -Path $Path
    }
}

function done {
    [CmdletBinding(DefaultParameterSetName = 'TailNumber')]
    Param(
        [Parameter(Position = 0, ParameterSetName = 'TailNumber')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Tail = [int]::MaxValue,

        [Parameter(Position = 0, ParameterSetName = 'NaturalLanguage')]
        [ValidateSet('', 'yesterday', 'today', 'week', 'month')]
        [string] $Specifier1,

        [Parameter(Position = 1, ParameterSetName = 'NaturalLanguage')]
        [string] $Specifier2,

        [string] $Path = "$(Get-TodoPath)/todo.done.txt"
    )
    if (!(Test-Path $Path)) {return "done file not found in '$Path'"}
    $doneItems = Get-Content $Path
    $params = Get-DoneByDateParams $Specifier1 $Specifier2
    Get-DoneByDate @params -DoneItems $doneItems | Select-Object -Last $Tail
}

function Get-DoneByDateParams {
    Param(
        [ValidateSet('', 'yesterday', 'today', 'week', 'month')]
        [string] $Specifier1,
        [string] $Specifier2
    )
    $params = @{}
    switch ($Specifier1) {
        "yesterday" { $params.Date = (Get-Date).AddDays(-1) | Get-Date -Format yyyy-MM-dd }
        "today" { $params.Date = Get-Date -Format yyyy-MM-dd }
        "week" {
            if ($Specifier2 -eq 'this') {$params.WeekNumber = Get-Date -UFormat %V}
            elseif ($Specifier2 -eq 'last') {$params.WeekNumber = (Get-Date).AddDays(-7) | Get-Date -UFormat %V}
            else {
                [ref] $numIntervals = 0
                if ([int]::TryParse($Specifier2, $numIntervals)) {
                    $params.WeekNumber = (Get-Date).AddDays(-7 * $numIntervals.Value) | Get-Date -UFormat %V
                    $params.DoneSince = $true
                }
                else {throw "Unable to parse '$Specifier2' into 'this','last', or an integer"}
            }
        }
        "month" {
            if ($Specifier2 -eq 'this') {$params.Date = Get-Date -Format yyyy-MM}
            elseif ($Specifier2 -eq 'last') {$params.Date = (Get-Date).AddMonths(-1) | Get-Date -Format yyyy-MM}
            else {
                [ref] $numIntervals = 0
                if ([int]::TryParse($Specifier2, $numIntervals)) {
                    $params.Date = (Get-Date).AddMonths(-1 * $numIntervals.Value) | Get-Date -Format yyyy-MM
                    $params.DoneSince = $true
                }
                else {throw "Unable to parse '$Specifier2' into 'this','last', or an integer"}
            }
        }
        default { $params.Date = '.' }
    }
    return $params
}

function Get-DoneByDate {
    Param(
        [Parameter(Position = 0, ParameterSetName = 'Date')]
        [string] $Date,
        [Parameter(Position = 0, ParameterSetName = 'WeekNumber')]
        [ValidateRange(1, 53)]
        [int] $WeekNumber,
        [switch] $DoneSince,
        [string[]] $DoneItems
    )
    $parameterSet = $PSCmdlet.ParameterSetName
    switch ($parameterSet) {
        'Date' {
            $regexDate = $Date.Replace('-','\-')
            $matchString = "^\[.*$regexDate.*\d{2}:\d{2}:\d{2}\].+"
            $DoneItems | Where-Object {$_ -match $matchString}
        }
        'WeekNumber' {
            $where = (
                {[int](Get-DateFromDoneItem $_ | Get-Date -UFormat %V) -eq $WeekNumber},
                {[int](Get-DateFromDoneItem $_ | Get-Date -UFormat %V) -ge $WeekNumber}
            )
            $DoneItems | Where-Object $where[$DoneSince.IsPresent]
        }
        Default { throw "Parameter set not recognized: $parameterSet" }
    }
}

function Get-DateFromDoneItem {
    Param([string] $DoneItem)
    [regex]::Match($DoneItem,'^\[(?<datetime>.+)\]').Groups['datetime'].Value
}

# Export-ModuleMember -Function todo, done