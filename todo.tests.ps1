Import-Module $PSScriptRoot\todo.psm1 -Force

$testPath = "$PSScriptRoot\todo.txt"

$mockTodo = "first
second
another"

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
    }
    AfterAll {Get-ChildItem -Path $PSScriptRoot -Filter *.txt | Remove-Item}
}