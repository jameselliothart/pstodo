function todo {
    Param(
        [ValidateSet('a','r')]
        [string] $AddRemove,
        [string] $Item,
        [string] $Path = "${HOME}/todo.txt"
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
            $updatedTodo = Remove-TodoItem -TodoItems $todoItems -ItemIndexToRemove $Item
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
        [string] $ItemIndexToRemove
    )
    $updatedTodo = @()
    for ($i = 0; $i -lt $TodoItems.Count; $i++) {
        if ($i -ne $ItemIndexToRemove) {$updatedTodo += $TodoItems[$i]}
        else {New-TodoCompleted -Item $TodoItems[$i] -Path (Get-DonePath $Path)}
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
        [string] $Path = "${HOME}/todo.done.txt"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Item"
    Add-Content -Value $entry -Path $Path
}

function done {
    Param(
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Tail = 10,
        [string] $Path = "${HOME}/todo.done.txt"
    )
    if (!(Test-Path $Path)) {return "done file not found in '$Path'"}
    $doneItems = Get-Content $Path
    $doneItems | select -Last $Tail
}

function Get-DoneByDate {
    Param(
        [string] $Date,
        [string[]] $DoneItems
    )
    $regexDate = $Date.Replace('-','\-')
    $matchString = "\[.*$regexDate.*\d{2}:\d{2}:\d{2}\].+"
    $DoneItems | Where-Object {$_ -match $matchString}
}

# Export-ModuleMember -Function todo, done