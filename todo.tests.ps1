Import-Module $PSScriptRoot\todo.psm1 -Force

$testPath = "$PSScriptRoot\todo.txt"

$mockTodo = "first
second
another"

$mockDone = "[$((Get-Date).AddDays(-2) | Get-Date -Format yyyy-MM-dd) 20:37:55] two days ago
[$((Get-Date).AddDays(-1) | Get-Date -Format yyyy-MM-dd) 20:37:55] yesterday
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
            Get-DonePath -Path $path | Should -Be 'some/path/to/todo.done.txt'
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
    Context 'Get-DoneByDate' {
        $DoneItems = '[2019-11-19 20:37:55] nineteen', '[2019-11-20 20:37:55] twenty', '[2019-11-21 20:37:55] twenty-one'
        It 'should return done items from the specified year-month-day' {
            Get-DoneByDate -Date '2019-11-20' -DoneItems $DoneItems | Should -Be '[2019-11-20 20:37:55] twenty'
        }
        It 'should return done items from the specified month-day' {
            Get-DoneByDate -Date '11-20' -DoneItems $DoneItems | Should -Be '[2019-11-20 20:37:55] twenty'
        }
    }
    Context 'done' {
        $donePath = (Get-DonePath -Path $testPath)
        AfterEach {
            if (Test-Path $donePath) {Remove-Item $donePath}
        }
        It 'should note file not found if no done file' {
            done -Path $testPath | Should -Be "done file not found in '$testPath'"
        }
        It 'should return the specified Tail number of done items' {
            Set-Content $donePath -Value $mockDone -Force
            done -Tail 2 -Path $donePath | Should -Be ($mockDone -split '\r?\n').Where({$_})[-2..-1]
        }
        It 'should return the items done today' {
            Set-Content $donePath -Value $mockDone -Force
            done today -Path $donePath| Should -Be ($mockDone -split '\r?\n').Where({$_})[-1]
        }
        It 'should return the items done yesterday' {
            Set-Content $donePath -Value $mockDone -Force
            done yesterday -Path $donePath| Should -Be ($mockDone -split '\r?\n').Where({$_})[-2]
        }
    }
}