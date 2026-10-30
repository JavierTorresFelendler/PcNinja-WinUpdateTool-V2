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
