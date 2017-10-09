$CommandName = $MyInvocation.MyCommand.Name.Replace(".ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
	AfterEach {
		(Get-ChildItem "$env:temp\dbatoolsci") | Remove-Item
	}
	Context "Verifying output" {
		It "exports results to one file and creates directory if required" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Memory Clerk Usage' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci"
			(Get-ChildItem "$env:temp\dbatoolsci").Count | Should Be 1
		}
		It "exports results to Excel file" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Memory Clerk Usage' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci" -ConvertTo Excel
			(Get-ChildItem "$env:temp\dbatoolsci\*.xlsx").Count | Should Be 1
		}
		It "exports results to .sql files" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Top Logical Reads Queries' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci" -ConvertTo Excel
			(Get-ChildItem "$env:temp\dbatoolsci\*.sql").Count | Should BeGreaterThan 0
		}
		It "exports results to .plan files" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Top Logical Reads Queries' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci" -ConvertTo Excel
			(Get-ChildItem "$env:temp\dbatoolsci\*.sqlplan").Count | Should BeGreaterThan 0
		}
        It "does not export results to .sql files if -NoQueryExport switch is uses" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Top Logical Reads Queries' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci" -ConvertTo Excel -NoQueryExport
			(Get-ChildItem "$env:temp\dbatoolsci\*.sql").Count | Should Be 0
        }
        It "still exports results to .plan files if -NoQueryExport switch is used" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Top Logical Reads Queries' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci" -ConvertTo Excel -NoQueryExport
			(Get-ChildItem "$env:temp\dbatoolsci\*.sqlplan").Count | Should BeGreaterThan 0
        }
        It "does not export results to .plan files if -NoPlanExport switch is used" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Top Logical Reads Queries' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci" -ConvertTo Excel -NoPlanExport
			(Get-ChildItem "$env:temp\dbatoolsci\*.sqlplan").Count | Should Be 0
        }
        It "still exports results to .sql files if -NoPlanExport switch is used" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance2 -QueryName 'Top Logical Reads Queries' | Export-DbaDiagnosticQuery -Path "$env:temp\dbatoolsci" -ConvertTo Excel -NoPlanExport
			(Get-ChildItem "$env:temp\dbatoolsci\*.sql").Count | Should BeGreaterThan 0
         }
	}
}