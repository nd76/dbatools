$CommandName = $MyInvocation.MyCommand.Name.Replace(".ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$CommandName Integration Tests" -Tags "IntegrationTests" {
	Context "Verifying output" {
		It "runs a specific query" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -QueryName 'Memory Clerk Usage' *>&1
			$results.Name.Count | Should Be 1
		}
		It "works with DatabaseSpecific" {
			$results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -DatabaseSpecific *>&1
			$results.Name.Count -gt 10 | Should Be $true
		}
        It "Uncomments Complete Query Text columns" {
            $results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -QueryName "Top Logical Reads Queries" *>&1
            ($results.Result | Get-Member | Where-Object Name -eq "Complete Query Text").Count | Should Be 1
        }
        It "Uncomments Query Plan columns" {
            $results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -QueryName "Top Logical Reads Queries" *>&1
            ($results.Result | Get-Member | Where-Object Name -eq "Query Plan").Count | Should Be 1
        }
        It "Does not uncomment Complete Query Text columns when -NoQueryTextColumn is used" {
            $results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -QueryName "Top Logical Reads Queries" -NoQueryTextColumn *>&1
            ($results.Result | Get-Member | Where-Object Name -eq "Complete Query Text").Count | Should Be 0
        }
        It "Does not uncomment Query Plan columns when -NoPlanColumn is used" {
            $results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -QueryName "Top Logical Reads Queries" -NoPlanColumn *>&1
            ($results.Result | Get-Member | Where-Object Name -eq "Query Plan").Count | Should Be 0
        }
        It "Still uncomments Complete Query Text columns when -NoPlanColumn is used" {
            $results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -QueryName "Top Logical Reads Queries" -NoPlanColumn *>&1
            ($results.Result | Get-Member | Where-Object Name -eq "Complete Query Text").Count | Should Be 1
        }
        It "Still Uncomments Query Plan columns when -NoQueryTextColumn is used" {
            $results = Invoke-DbaDiagnosticQuery -SqlInstance $script:instance1 -QueryName "Top Logical Reads Queries" -NoQueryTextColumn *>&1
            ($results.Result | Get-Member | Where-Object Name -eq "Query Plan").Count | Should Be 1
        }
	}
}