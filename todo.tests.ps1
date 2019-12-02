Import-Module $PSScriptRoot\todo.psm1 -Force

$testPath = "$PSScriptRoot\todo.txt"

$mockTodo = "first
second
another"

$mockDone = "[2019-01-09 12:00:00] second week of the year
[2019-11-11 20:37:55] eleven
[2019-11-12 20:37:55] twelve
[2019-11-13 20:37:55] thirteen
[$((Get-Date).AddDays(-7) | Get-Date -Format yyyy-MM-dd) 20:37:55] last week one
[$((Get-Date).AddDays(-7) | Get-Date -Format yyyy-MM-dd) 20:37:55] last week two
[$((Get-Date).AddDays(-2) | Get-Date -Format yyyy-MM-dd) 20:37:55] two days ago
[$((Get-Date).AddDays(-1) | Get-Date -Format yyyy-MM-dd) 20:37:55] yesterday
[$((Get-Date).AddDays(-1) | Get-Date -Format yyyy-MM-dd) 20:37:55] yesterday as well
[$(Get-Date -Format yyyy-MM-dd) 20:37:55] today"

Describe 'todo' {
    Context 'Write-TodoItems' {
        It 'should display indexed todo items' {
            $items = $mockTodo.Split().Where({$_})
            Write-TodoItems $items | Should -Be "0. first", "1. second", "2. another"
        }
    }
    Context 'Get-DonePath' {
        It 'should return a path to a *.done.txt file' {
            $path = 'some/path/to/todo.txt'
            (Get-DonePath -Path $path).Replace('\','/') | Should -Be 'some/path/to/todo.done.txt'
        }
    }
    Context 'todo' {
        BeforeEach {
            Set-Content $testPath -Value $mockTodo -Force
        }
        It 'should display todo items when a/r not specified' {
            $expected = "0. first", "1. second", "2. another"
            todo -Path $testPath | Should -Be $expected
        }
        It 'should add an item when "a" specified with an item' {
            $expected = "0. my item", "1. first", "2. second", "3. another"
            todo a 'my item' -Path $testPath | Should -Be $expected
        }
        It 'should remove an item when "r" specified with an index' {
            $expected = "0. first", "1. another"
            todo r 1 -Path $testPath | Should -Be $expected
        }
        It 'should remove the final item when only one item exists' {
            $expected = "No todos in $testPath!"
            todo r 0 -Path $testPath | Out-Null
            todo r 0 -Path $testPath | Out-Null
            todo r 0 -Path $testPath | Should -Be $expected
        }
        It 'should write a removed item to the done file' {
            $donePath = Get-DonePath $testPath
            New-Item $donePath -Force
            todo r 1 -Path $testPath | Out-Null
            Get-Content $donePath | Should -HaveCount 1
        }
        AfterAll {Get-ChildItem -Path $PSScriptRoot -Filter *.txt | Remove-Item}
    }
    Context 'Get-DateFromDoneItem' {
        $doneItem = '[2019-11-19 20:37:55] nineteen'
        Get-DateFromDoneItem -DoneItem $doneItem | Should -Be '2019-11-19 20:37:55'
    }
    Context 'Get-DoneByDate' {
        $DoneItems = ($mockDone -split '\r?\n')
        It 'should return done items from the specified year-month-day' {
            Get-DoneByDate -Date '2019-11-11' -DoneItems $DoneItems | Should -Be $DoneItems.Where({$_ -like '*eleven*'})
        }
        It 'should return done items from the specified month-day' {
            Get-DoneByDate -Date '11-11' -DoneItems $DoneItems | Should -Be $DoneItems.Where({$_ -like '*eleven*'})
        }
        It 'should return done items from the specified week number' {
            Get-DoneByDate -WeekNumber 2 -DoneItems $DoneItems | Should -Be '[2019-01-09 12:00:00] second week of the year'
        }
    }
    Context 'Get-TodoPath' {
        It 'should default to $HOME when todoConfig.json is not found' {
            Get-TodoPath | Should -Be $HOME
        }
        It 'should return the path specified in todoConfig.json' {
            Set-Content todoConfig.temp.json -Value '{"todoConfig": {"basePath": "path/to/todo"}}' -Force
            Get-TodoPath -ConfigPath todoConfig.temp.json | Should -Be "path/to/todo"
        }
        AfterAll {Get-ChildItem -Path $PSScriptRoot -Filter *.temp.json | Remove-Item}
    }
    Context 'done' {
        $donePath = (Get-DonePath -Path $testPath)
        AfterEach {
            if (Test-Path $donePath) {Remove-Item $donePath}
        }
        It 'should note file not found if no done file' {
            done -Path $testPath | Should -Be "done file not found in '$testPath'"
        }
        It 'should return all done items by default' {
            Set-Content $donePath -Value $mockDone -Force
            done -Path $donePath | Should -Be ($mockDone -split '\r?\n')
        }
        It 'should return the specified Tail number of done items' {
            Set-Content $donePath -Value $mockDone -Force
            done -Tail 2 -Path $donePath | Should -Be ($mockDone -split '\r?\n').Where({$_})[-2..-1]
            done 2 -Path $donePath | Should -Be ($mockDone -split '\r?\n').Where({$_})[-2..-1]
        }
        It 'should return the items done today' {
            Set-Content $donePath -Value $mockDone -Force
            done today -Path $donePath | Should -Be ($mockDone -split '\r?\n').Where({$_ -like '*today*'})
        }
        It 'should return the items done yesterday' {
            Set-Content $donePath -Value $mockDone -Force
            done yesterday -Path $donePath | Should -Be ($mockDone -split '\r?\n').Where({$_ -like '*yesterday*'})
        }
        It 'should return the items done last week' {
            Set-Content $donePath -Value $mockDone -Force
            done last week -Path $donePath | Should -Be ($mockDone -split '\r?\n').Where({$_ -like '*last week*'})
        }
        It 'should return the items done this week' {
            $weekNumToday = Get-Date | Get-Date -UFormat %V
            $weekNumTwoDaysAgo = (Get-Date).AddDays(-2) | Get-Date -UFormat %V
            if ($weekNumTwoDaysAgo -ne $weekNumToday) {
                Set-ItResult -Skipped -Because "this is only a valid test when at least two days into the current week"
            }
            else {
                Set-Content $donePath -Value $mockDone -Force
                $expected = {($_ -like '*today*') -or ($_ -like '*yesterday*') -or ($_ -like '*two days ago*')}
                done this week -Path $donePath | Should -Be ($mockDone -split '\r?\n').Where($expected)
            }
        }
    }
    Context 'New-TodoCompleted' {
        AfterEach {Get-ChildItem -Filter todoConfig.json | Remove-Item}
        It 'should return a timestamped todo item' {
            New-TempTodoConfig -BasePath (Split-Path $testPath)
            $item = 'a todo item'
            $match = "^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] $item"
            New-TodoCompleted -Item $item -WhatIf | Should -MatchExactly $match
        }
    }
}