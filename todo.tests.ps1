Import-Module $PSScriptRoot/todo.psm1 -Force

$testPath = "$PSScriptRoot/todo.txt"

$mockTodo = "first
second
another"

$mockDone = "[2019-01-09 12:00:00] second week of the year
[2019-10-01 20:37:55] october one
[2019-10-02 20:37:55] october two
[2019-11-11 20:37:55] eleven
[2019-11-12 20:37:55] twelve
[2019-11-13 20:37:55] thirteen
[$((Get-Date).AddDays(-1) | Get-Date -Format yyyy-MM-dd) 20:37:55] yesterday
[$((Get-Date).AddDays(-1) | Get-Date -Format yyyy-MM-dd) 20:37:55] yesterday as well
[$((Get-Date).AddDays(0) | Get-Date -Format yyyy-MM-dd) 20:37:55] today"
$DoneItems = ($mockDone -split '\r?\n')
$mockDoneDateVariant = "[$((Get-Date).AddMonths(-2) | Get-Date -Format yyyy-MM-dd) 20:37:55] two months ago
[$((Get-Date).AddMonths(-1) | Get-Date -Format yyyy-MM-dd) 20:37:55] last month
[$((Get-Date).AddDays(-14) | Get-Date -Format yyyy-MM-dd) 20:37:55] two weeks ago
[$((Get-Date).AddDays(-7) | Get-Date -Format yyyy-MM-dd) 20:37:55] last week one
[$((Get-Date).AddDays(-7) | Get-Date -Format yyyy-MM-dd) 20:37:55] last week two"
$DoneItemsDateVariant = ($mockDoneDateVariant -split '\r?\n')

function New-TempTodoConfig ([string] $BasePath = (Split-Path $testPath)) {
    Set-Content todoConfig.json -Value "{'todoConfig': {'basePath': '$BasePath'}}" -Force
}

Describe 'todo' {
    Context 'new todo file' {
        BeforeEach {New-TempTodoConfig -BasePath (Split-Path $testPath)}
        AfterEach {Get-ChildItem -Filter todoConfig.json | Remove-Item}
        It 'should create a todo file when one is not found' {
            todo | Should -Be @("New todo file created in $testPath", "No todos in $testPath!")
            Test-Path $testPath | Should -Be $true
        }
    }
    Context 'existing todo file commands' {
        BeforeEach {Set-Content $testPath -Value $mockTodo -Force}
        AfterEach {Get-ChildItem -Filter todo*.txt | Remove-Item}
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
            todo r 1 -Path $testPath | Out-Null
            Get-Content $donePath | Should -HaveCount 1
        }
        It 'should not write the removed item to the done file when -Purge specified' {
            $donePath = Get-DonePath $testPath
            todo r 1 -Path $testPath -Purge | Out-Null
            Test-Path $donePath | Should -Be $false
        }
    }
}

Describe 'done' {
    $donePath = (Get-DonePath -Path $testPath)
    Context 'no done file' {
        BeforeEach {New-TempTodoConfig -BasePath (Split-Path $testPath)}
        AfterEach {Get-ChildItem -Filter todoConfig.json | Remove-Item}
        It 'should note file not found if no done file' {
            done | Should -Be "done file not found in '$donePath'"
        }
    }
    Context 'date invariant' {
        BeforeEach {Set-Content $donePath -Value $mockDone -Force}
        AfterEach {if (Test-Path $donePath) {Remove-Item $donePath}}
        It 'should return all done items by default' {
            done -Path $donePath | Should -Be $DoneItems
        }
        It 'should return the specified Tail number of done items' {
            done -Tail 2 -Path $donePath | Should -Be $DoneItems.Where({$_})[-2..-1]
            done 2 -Path $donePath | Should -Be $DoneItems.Where({$_})[-2..-1]
        }
        It 'should return the items done today' {
            done today -Path $donePath | Should -Be $DoneItems.Where({$_ -like '*today*'})
        }
        It 'should return the items done yesterday' {
            done yesterday -Path $donePath | Should -Be $DoneItems.Where({$_ -like '*yesterday*'})
        }
    }
    Context 'date variant' {
        BeforeEach {Set-Content $donePath -Value $mockDoneDateVariant -Force}
        AfterEach {if (Test-Path $donePath) {Remove-Item $donePath}}
        It 'should return the items done last week' {
            done week last -Path $donePath | Should -Be $DoneItemsDateVariant.Where({$_ -like '*last week*'})
        }
        It 'should return the items done this week' {
            $weekNumToday = Get-Date | Get-Date -UFormat %V
            $weekNumTwoDaysAgo = (Get-Date).AddDays(-2) | Get-Date -UFormat %V
            if ($weekNumTwoDaysAgo -ne $weekNumToday) {
                Set-ItResult -Skipped -Because "this is only a valid test when at least two days into the current week"
            }
            else {
                $expected = {($_ -like '*today*') -or ($_ -like '*yesterday*') -or ($_ -like '*two days ago*')}
                done week this -Path $donePath | Should -Be $DoneItemsDateVariant.Where($expected)
            }
        }
        It 'should return done items done since two weeks ago' {
            done week 2 -Path $donePath | Should -Be $DoneItemsDateVariant.Where({($_ -like "*last week*") -or ($_ -like "*two weeks ago*")})
        }
        It 'should return the items done since last month' {
            $startOfLastMonth = [datetime]((Get-Date).AddMonths(-1) | Get-Date -Format yyyy-MM)
            done month 1 -Path $donePath | Should -Be $DoneItemsDateVariant.Where({[datetime](Get-DateFromDoneItem $_) -gt $startOfLastMonth})
        }
        It 'should return the items done since two months ago' {
            $startOfTwoMonthsAgo = [datetime]((Get-Date).AddMonths(-2) | Get-Date -Format yyyy-MM)
            done month 2 -Path $donePath | Should -Be $DoneItemsDateVariant.Where({[datetime](Get-DateFromDoneItem $_) -gt $startOfTwoMonthsAgo})
        }
    }
}

Describe "Utility Functions" {
    Context 'New-TodoCompleted' {
        AfterEach {Get-ChildItem -Filter todoConfig.json | Remove-Item}
        It 'should return a timestamped todo item' {
            New-TempTodoConfig -BasePath (Split-Path $testPath)
            $item = 'a todo item'
            $match = "^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] $item"
            New-TodoCompleted -Item $item -WhatIf | Should -MatchExactly $match
        }
    }
    Context 'Get-DateFromDoneItem' {
        $doneItem = '[2019-11-19 20:37:55] nineteen'
        It 'should parse the date from a done item' {
            Get-DateFromDoneItem -DoneItem $doneItem | Should -Be '2019-11-19 20:37:55'
        }
    }
    Context 'Get-DoneByDate' {
        It 'should return items done in the specified year-month-day' {
            Get-DoneByDate -Date '2019-11-11' -DoneItems $DoneItems | Should -Be $DoneItems.Where({$_ -like '*eleven*'})
        }
        It 'should return items done in the specified month-day' {
            Get-DoneByDate -Date '11-11' -DoneItems $DoneItems | Should -Be $DoneItems.Where({$_ -like '*eleven*'})
        }
        It 'should return items done in the specified year-month' {
            Get-DoneByDate -Date '2019-10' -DoneItems $DoneItems | Should -Be $DoneItems.Where({$_ -like '*october*'})
        }
        It 'should return items done in the specified week number' {
            Get-DoneByDate -WeekNumber 2 -DoneItems $DoneItems | Should -Be '[2019-01-09 12:00:00] second week of the year'
        }
        It 'should return items done since the beginning of the specified week number' {
            $twoWeeksAgo = [int]((Get-Date).AddDays(-14) | Get-Date -UFormat %V)
            Get-DoneByDate -DoneSince -WeekNumber $twoWeeksAgo -DoneItems $DoneItemsDateVariant |
                Should -Be $DoneItemsDateVariant.Where({($_ -like "*last week*") -or ($_ -like "*two weeks ago*")})
        }
        It 'should return items done since the beginning of the specified year-month' {
            $date = '2019-10'
            Get-DoneByDate -DoneSince -Date $date -DoneItems $DoneItems |
                Should -Be $DoneItems.Where({[datetime](Get-DateFromDoneItem $_) -gt [datetime]$date})
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
    Context 'Initialize-TodoItems' {
        $testInitializePath = "$PSScriptRoot/deleteme.txt"
        AfterEach {Get-ChildItem -Filter deleteme.txt | Remove-Item}
        It 'should create a file in the specified path' {
            Initialize-TodoItems -Path $testInitializePath
            Test-Path $testInitializePath | Should -Be $true
        }
    }
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
}

Describe 'Get-DoneByDateParams' -Tag 'DoneByDateParams' {
    It "should return a Date of '.' when no Specifier is given" {
        $params = Get-DoneByDateParams $foo $bar
        $params.Date | Should -Be '.'
    }
    It "should return today's date in yyyy-MM-dd format when 'today' is specified" {
        $expected = (Get-Date).AddDays(0) | Get-Date -Format yyyy-MM-dd
        $params = Get-DoneByDateParams today
        $params.Date | Should -Be $expected
        $params = Get-DoneByDateParams today 'something else'
        $params.Date | Should -Be $expected
    }
    It "should return yesterday's date in yyyy-MM-dd format when 'yesterday' is specified" {
        $expected = (Get-Date).AddDays(-1) | Get-Date -Format yyyy-MM-dd
        $params = Get-DoneByDateParams yesterday
        $params.Date | Should -Be $expected
        $params = Get-DoneByDateParams yesterday 'something else'
        $params.Date | Should -Be $expected
    }
    It "should return this week's week number when 'week this' is specified" {
        $expected = (Get-Date).AddDays(0) | Get-Date -UFormat %V
        $params = Get-DoneByDateParams week this
        $params.WeekNumber | Should -Be $expected
    }
    It "should return last week's week number when 'week last' is specified" {
        $expected = (Get-Date).AddDays(-7) | Get-Date -UFormat %V
        $params = Get-DoneByDateParams week last
        $params.WeekNumber | Should -Be $expected
    }
    It "should return the week number from two weeks ago with DoneSince flag when 'week 2' is specified" {
        $expected = (Get-Date).AddDays(-14) | Get-Date -UFormat %V
        $params = Get-DoneByDateParams week 2
        $params.WeekNumber | Should -Be $expected
        $params.DoneSince | Should -Be $true
    }
    It "should return this month's date when 'month this' is specified" {
        $expected = (Get-Date).AddMonths(0) | Get-Date -Format yyyy-MM
        $params = Get-DoneByDateParams month this
        $params.Date | Should -Be $expected
    }
    It "should return last month's date when 'month last' is specified" {
        $expected = (Get-Date).AddMonths(-1) | Get-Date -Format yyyy-MM
        $params = Get-DoneByDateParams month last
        $params.Date | Should -Be $expected
    }
    It "should return the month from two months ago when 'month 2' is specified" {
        $expected = (Get-Date).AddMonths(-2) | Get-Date -Format yyyy-MM
        $params = Get-DoneByDateParams month 2
        $params.Date | Should -Be $expected
    }
}