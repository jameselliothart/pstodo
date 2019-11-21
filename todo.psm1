function todo {
    Param(
        [ValidateSet('a','r')]
        [string] $AddRemove,
        [string] $Item,
        [string] $Path = "${HOME}/todo.txt"
    )

    if (!(Test-Path $Path)) {
        New-Item $Path -ItemType File -Force | Out-Null
        return "New todo file created in $Path"
    }
    [string[]] $todoItems = Get-Content $Path | Where-Object {$_} # ignore blank lines
    $updatedTodo = @()

    switch ($AddRemove) {
        'a' {
            $Item, $todoItems | ForEach-Object {$updatedTodo += $_}
            $updatedTodo | Set-Content $Path
            todo -Path $Path
        }
        'r' {
            for ($i = 0; $i -lt $todoItems.Count; $i++) {
                if ($i -ne $Item) {$updatedTodo += $todoItems[$i]}
                else {New-TodoCompleted -Item $todoItems[$i] -Path (Get-DonePath $Path)}
            }
            if (!$updatedTodo) {Set-Content $Path -Value ""}
            else {$updatedTodo | Set-Content $Path}
            todo -Path $Path
        }
        default {
            if (!$todoItems) {"No todos in $Path!"}
            else {Write-TodoItems -Items $todoItems}
        }
    }
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
        [int] $Tail = 10,
        [string] $Path = "${HOME}/todo.done.txt"
    )
    if (!(Test-Path $Path)) {return "done file not found in '$Path'"}
    Get-Content $Path -Tail $Tail
}

# Export-ModuleMember -Function todo, done