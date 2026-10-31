$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'WinUpdateCore.psm1'
Import-Module $modulePath -Force

Describe 'PcNinja scheduled task replacement' {
    InModuleScope WinUpdateCore {
        It 'removes matching tasks from canonical and legacy task paths' {
            Mock Test-PcnAdministrator { $true }
            Mock Write-PcnWinUpdateLog { }
            Mock Get-ScheduledTask {
                @(
                    [pscustomobject]@{ TaskName = 'PcNinja WinUpdate Tool'; TaskPath = '\PcNinja\' },
                    [pscustomobject]@{ TaskName = 'PcNinja WinUpdate Tool'; TaskPath = '\' },
                    [pscustomobject]@{ TaskName = 'PcNinja WinUpdate Tool V2'; TaskPath = '\Legacy\' },
                    [pscustomobject]@{ TaskName = 'Unrelated Task'; TaskPath = '\' }
                )
            }
            Mock Unregister-ScheduledTask { }

            $result = Unregister-PcnWinUpdateToolTasks

            $result.Warnings.Count | Should Be 0
            $result.Removed.Count | Should Be 3
            Assert-MockCalled Unregister-ScheduledTask -Times 1 -ParameterFilter {
                $TaskName -eq 'PcNinja WinUpdate Tool' -and $TaskPath -eq '\PcNinja\'
            }
            Assert-MockCalled Unregister-ScheduledTask -Times 1 -ParameterFilter {
                $TaskName -eq 'PcNinja WinUpdate Tool' -and $TaskPath -eq '\'
            }
            Assert-MockCalled Unregister-ScheduledTask -Times 1 -ParameterFilter {
                $TaskName -eq 'PcNinja WinUpdate Tool V2' -and $TaskPath -eq '\Legacy\'
            }
        }

        It 'cleans old tasks before registering the canonical task' {
            Mock Test-PcnAdministrator { $true }
            Mock Test-Path { $true }
            Mock New-PcnScheduledTaskXml { '<Task />' }
            Mock Unregister-PcnWinUpdateToolTasks { [pscustomobject]@{ Warnings = @() } }
            Mock Register-ScheduledTask { }
            Mock Write-PcnWinUpdateLog { }

            $config = [pscustomobject]@{
                Frequency = 'Monthly'
                Time = '03:00'
                RunAtStartup = $false
                StartupDelayMinutes = 5
            }

            Register-PcnWinUpdateScheduledTask -Config $config -ScriptPath 'C:\Program Files\PcNinja\WinUpdateTool\WinUpdateTool.ps1'

            Assert-MockCalled Unregister-PcnWinUpdateToolTasks -Times 1
            Assert-MockCalled Register-ScheduledTask -Times 1 -ParameterFilter {
                $TaskName -eq 'PcNinja WinUpdate Tool' -and $TaskPath -eq '\PcNinja\' -and $Force
            }
        }
    }
}

Describe 'PcNinja app update package metadata' {
    InModuleScope WinUpdateCore {
        It 'accepts package filenames and SHA256 hashes in the expected format' {
            $result = Test-PcnAppUpdatePackageMetadata `
                -FileName 'WinUpdate.Tool.by.PcNinja.msi' `
                -Sha256 ('A' * 64) `
                -PackageType Msi

            $result.IsValid | Should Be $true
            $result.Errors.Count | Should Be 0
        }

        It 'rejects path traversal and malformed hashes' {
            $result = Test-PcnAppUpdatePackageMetadata `
                -FileName '..\outside.msi' `
                -Sha256 'not-a-hash' `
                -PackageType Msi

            $result.IsValid | Should Be $false
            $result.Errors.Count | Should Be 2
        }

        It 'rejects a package with the wrong extension' {
            $result = Test-PcnAppUpdatePackageMetadata `
                -FileName 'unexpected.exe' `
                -Sha256 ('0' * 64) `
                -PackageType Msi

            $result.IsValid | Should Be $false
            $result.Errors.Count | Should Be 1
        }
    }
}

Describe 'PcNinja atomic JSON persistence' {
    InModuleScope WinUpdateCore {
        It 'replaces a JSON file without leaving a temporary file' {
            $path = Join-Path ([System.IO.Path]::GetTempPath()) ("pcninja-state-{0}.json" -f [guid]::NewGuid().ToString('N'))
            try {
                Write-PcnJsonFileAtomic -Path $path -InputObject ([pscustomobject]@{ Result = 'Old' })
                Write-PcnJsonFileAtomic -Path $path -InputObject ([pscustomobject]@{ Result = 'New' })

                $saved = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
                $saved.Result | Should Be 'New'
                @(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter ((Split-Path -Leaf $path) + '.*.tmp')).Count | Should Be 0
                @(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter ((Split-Path -Leaf $path) + '.*.bak')).Count | Should Be 0
            }
            finally {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'PcNinja UTF-8 text files' {
    InModuleScope WinUpdateCore {
        It 'sets PowerShell console and pipeline output encoding to UTF-8' {
            $originalConsoleEncoding = [Console]::OutputEncoding
            $originalOutputEncoding = $OutputEncoding
            try {
                Set-PcnUtf8ConsoleEncoding

                [Console]::OutputEncoding.WebName | Should Be 'utf-8'
                $OutputEncoding.WebName | Should Be 'utf-8'
            }
            finally {
                [Console]::OutputEncoding = $originalConsoleEncoding
                $global:OutputEncoding = $originalOutputEncoding
            }
        }

        It 'reads Unicode text from UTF-8 files without a byte order mark' {
            $path = Join-Path ([System.IO.Path]::GetTempPath()) ("pcninja-utf8-{0}.txt" -f [guid]::NewGuid().ToString('N'))
            $expected = [System.Text.RegularExpressions.Regex]::Unescape('\u05E2\u05D1\u05E8\u05D9\u05EA | \u0627\u0644\u0639\u0631\u0628\u064A\u0629 | \u65E5\u672C\u8A9E | Fran\u00E7ais')
            try {
                [System.IO.File]::WriteAllText($path, $expected, (New-Object System.Text.UTF8Encoding($false)))

                $actual = Read-PcnUtf8File -Path $path

                $actual | Should Be $expected
            }
            finally {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
