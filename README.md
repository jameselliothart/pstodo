# PSTodo

PSTodo is a lightweight command-line todo list tracker implemented in PowerShell. It is primarily developed on PowerShell Core in an Ubuntu environment but is compatible at least down to PowerShell 5.1 on Windows (this is where I primarily use it).

## Purpose

The purpose of this module is to solve two problems:

1. Track a todo list and report on completed (done) items
2. Accomplish (1) without having to install any software, pull from external repositories, or track any information on the web

Thus, the todo module consists of only a single file, `todo.psm1`, so that its contents can be copy/pasted into a recognized PowerShell module directory and used immediately.

## Functionality

First running `todo` will create an empty todo list in the configured todo directory (see Configuration below).

```powershell
PS > todo
New todo file created in /home/james/todo.txt
No todos in /home/james/todo.txt!
```

Add todo items with `todo a 'some item'`:

```powershell
PS > todo a 'update readme'      
0. update readme
PS > todo a 'push changes to remote'
0. push changes to remote
1. update readme
```

Remove items with `todo r {index}`:

```powershell
PS > todo r 1
0. push changes to remote
```

Removed items are automatically timestamped and added to a todo.done.txt file in the same directory as todo.txt which can be queried with `done`:

```powershell
PS > done
[2019-12-23 20:41:16] update readme
```

To avoid adding to the done file, specify the `-Purge` option when removing, e.g. `todo r 1 -Purge`

`done` accepts a number of options to query by completed date, such as:

* `done today`
* `done yesterday`
* `done week this` 
* `done week 2` (done within the last two weeks)

## Installation

For PowerShell to load `todo` automatically, all that is required is to place the `todo.psm1` file in a folder named todo in one of the recognized PowerShell module paths (the entire repo can be clone there if desired). Use the command below to find the recognized PowerShell module paths across platforms:

```powershell
PS > $env:PSModulePath.Split(';').Split(':')
/home/james/.local/share/powershell/Modules
/usr/local/share/powershell/Modules
/opt/microsoft/powershell/6/Modules
```

For instance, for my output above, the required structure within `/home/james/.local/share/powershell/Modules` is:

```sh
.
└── todo
    ├── todo.psm1
```

This would also be fine (entire repo contents):

```sh
.
└── todo
    ├── README.md
    ├── todoConfig.template.json
    ├── todo.psm1
    └── todo.tests.ps1
```

## Implementation Details

The todo and done lists are persisted on disk in todo.txt and todo.done.txt files respectively. See the Configuration section for information on where these files live.

The test suite in `todo.tests.ps1` is implemented with Pester. For more information on Pester in general and on installation steps or running tests in particular, please see the [Pester GitHub page](https://github.com/pester/Pester).

## Configuration

By default, `todo` places the todo.txt and todo.done.txt files in the `$HOME` environment variable path (typically /home/username on Linux or C:\Users\username on Windows). 

The default behavior can be overridden by placing a todoConfig.json file in the module folder (an example todoConfig.template.json is provided). **Remember to escape backslashes** if specifying a Windows basePath (e.g. `"C:\\todo\\path"`). PowerShell will also accept forward slashes in a Windows environment, so `"C:/todo/path"` will also work and is recommended.


```sh
.
└── todo
    ├── todoConfig.json
    ├── todo.psm1
```

*# todoConfig.json:*
```json
{
    "todoConfig":
    {
        "basePath": "/some/directory/path"
    }
}
```