function Copy-DbaTable {
	<#
		.SYNOPSIS
			Writes data to a SQL Server Table.

		.DESCRIPTION
			Writes a .NET DataTable to a SQL Server table using SQL Bulk Copy.

		.PARAMETER Source
			Source SQL Server.You must have sysadmin access and server version must be SQL Server version 2000 or greater.

		.PARAMETER SourceSqlCredential
			Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

			$scred = Get-Credential, then pass $scred object to the -SourceSqlCredential parameter.

			Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
			To connect as a different Windows user, run PowerShell as that user.

		.PARAMETER Destination
			Destination Sql Server. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

		.PARAMETER DestinationSqlCredential
			Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

			$dcred = Get-Credential, then pass this $dcred to the -DestinationSqlCredential parameter.

			Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.
			To connect as a different Windows user, run PowerShell as that user.

		.PARAMETER Database
			The database to import the table into.

		.PARAMETER InputObject
			This is the DataTable (or datarow) to import to SQL Server.

		.PARAMETER Table
			The table name to import data into. You can specify a one, two, or three part table name. If you specify a one or two part name, you must also use -Database.

			If the table does not exist, you can use -AutoCreateTable to automatically create the table with inefficient data types.

		.PARAMETER Schema
			Defaults to dbo if no schema is specified.

		.PARAMETER Query
			Used to copy just a portion of data, not all of it.
	
		.PARAMETER BatchSize
			The BatchSize for the import defaults to 5000.

		.PARAMETER NotifyAfter
			Sets the option to show the notification after so many rows of import

		.PARAMETER AutoCreateTable
			If this switch is enabled, the table will be created if it does not already exist. The table will be created with sub-optimal data types such as nvarchar(max)

		.PARAMETER NoTableLock
			If this switch is enabled, a table lock (TABLOCK) will not be placed on the destination table. By default, this operation will lock the destination table while running.

		.PARAMETER CheckConstraints
			If this switch is enabled, the SqlBulkCopy option to process check constraints will be enabled.
			
			Per Microsoft "Check constraints while data is being inserted. By default, constraints are not checked."

		.PARAMETER FireTriggers
			If this switch is enabled, the SqlBulkCopy option to fire insert triggers will be enabled.

			Per Microsoft "When specified, cause the server to fire the insert triggers for the rows being inserted into the Database."

		.PARAMETER KeepIdentity
			If this switch is enabled, the SqlBulkCopy option to preserve source identity values will be enabled.

			Per Microsoft "Preserve source identity values. When not specified, identity values are assigned by the destination."

		.PARAMETER KeepNulls
			If this switch is enabled, the SqlBulkCopy option to preserve NULL values will be enabled.

			Per Microsoft "Preserve null values in the destination table regardless of the settings for default values. When not specified, null values are replaced by default values where applicable."

		.PARAMETER Truncate
			If this switch is enabled, the destination table will be truncated after prompting for confirmation.
			
		.PARAMETER BulkCopyTimeOut
			Value in seconds for the BulkCopy operations timeout. The default is 30 seconds.

		.PARAMETER RegularUser
			If this switch is enabled, the user connecting will be assumed to be a non-administrative user. By default, the underlying connection assumes that the user has administrative privileges.

			This is particularly important when connecting to a SQL Azure Database.

		.PARAMETER WhatIf
			If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

		.PARAMETER Confirm
			If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
		
		.NOTES
			Tags: Migration
			Author: Chrissy LeMaire (@cl), netnerds.net
			Requires: sysadmin access on SQL Servers

			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Copy-DbaServerTrigger

		.EXAMPLE
			Copy-DbaServerTrigger -Source sqlserver2014a -Destination sqlcluster

			Copies all server triggers from sqlserver2014a to sqlcluster, using Windows credentials. If triggers with the same name exist on sqlcluster, they will be skipped.

		.EXAMPLE
			Copy-DbaServerTrigger -Source sqlserver2014a -Destination sqlcluster -ServerTrigger tg_noDbDrop -SourceSqlCredential $cred -Force

			Copies a single trigger, the tg_noDbDrop trigger from sqlserver2014a to sqlcluster, using SQL credentials for sqlserver2014a and Windows credentials for sqlcluster. If a trigger with the same name exists on sqlcluster, it will be dropped and recreated because -Force was used.

		.EXAMPLE
			Copy-DbaServerTrigger -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force

			Shows what would happen if the command were executed using force.
	#>
	[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
	param (
		[parameter(Mandatory = $true)]
		[DbaInstanceParameter]$Source,
		[PSCredential]$SourceSqlCredential,
		[parameter(Mandatory = $true)]
		[DbaInstanceParameter]$Destination,
		[PSCredential]$DestinationSqlCredential,
		[Parameter(Mandatory)]
		[string]$Database,
		[Parameter(Mandatory)]
		[string]$Table,
		[ValidateNotNullOrEmpty()]
		[string]$Schema = 'dbo',
		[string]$Query,
		[int]$BatchSize = 50000,
		[int]$NotifyAfter = 5000,
		[switch]$AutoCreateTable,
		[switch]$NoTableLock,
		[switch]$CheckConstraints,
		[switch]$FireTriggers,
		[switch]$KeepIdentity,
		[switch]$KeepNulls,
		[switch]$Truncate,
		[int]$bulkCopyTimeOut = 5000,
		[switch]$RegularUser,
		[switch]$EnableException
	)
	
	begin {
		# Getting the total rows copied is a challenge. Use SqlBulkCopyExtension.
		# http://stackoverflow.com/questions/1188384/sqlbulkcopy-row-count-when-complete
		
		$sourcecode = 'namespace System.Data.SqlClient {
			using Reflection;

			public static class SqlBulkCopyExtension
			{
				const String _rowsCopiedFieldName = "_rowsCopied";
				static FieldInfo _rowsCopiedField = null;

				public static int RowsCopiedCount(this SqlBulkCopy bulkCopy)
				{
					if (_rowsCopiedField == null) _rowsCopiedField = typeof(SqlBulkCopy).GetField(_rowsCopiedFieldName, BindingFlags.NonPublic | BindingFlags.GetField | BindingFlags.Instance);
					return (int)_rowsCopiedField.GetValue(bulkCopy);
				}
			}
		}'
		
		Add-Type -ReferencedAssemblies System.Data.dll -TypeDefinition $sourcecode -ErrorAction SilentlyContinue
		$bulkCopyOptions = 0
		$options = "TableLock", "CheckConstraints", "FireTriggers", "KeepIdentity", "KeepNulls", "Default", "Truncate"
		
		foreach ($option in $options) {
			$optionValue = Get-Variable $option -ValueOnly -ErrorAction SilentlyContinue
			if ($optionValue -eq $true) {
				$bulkCopyOptions += $([Data.SqlClient.SqlBulkCopyOptions]::$option).value__
			}
		}
		
		$fqtn = "$Database.$Schema.$Table"
		
		if (-not $query) {
			$Query = "select * from $fqtn"
		}
	}
	
	process {
		$sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential
		$destServer = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential
		$connstring = $destServer.ConnectionContext.ConnectionString
		
		if (-not $sourceServer.Databases[$Database]) {
			Stop-Function -Message "$database does not exist on source"
			return
		}
		
		if (-not $destServer.Databases[$Database]) {
			Stop-Function -Message "$database does not exist on destination"
			return
		}
		
		$sourcetable = $sourceServer.Databases[$Database].Tables | Where-Object { $_.Name -eq $Table -and $_.Schema -eq $Schema }
		$desttable = $destServer.Databases[$Database].Tables | Where-Object { $_.Name -eq $Table -and $_.Schema -eq $Schema }
		$sourceschema = $destServer.Databases[$Database].Schemas[$Schema]
		$destschema = $destServer.Databases[$Database].Schemas[$Schema]
		
		if (-not $sourcetable) {
			Stop-Function -Message "$fqtn does not exist on source"
			return 
		}
		
		if (-not $destschema) {
			try {
				$destServer.Databases[$Database].Query($sourceschema.Script())
			}
			catch {
				Stop-Function -Message "Could not create schema $schema on destination" -ErrorRecord $_ -Target $Destination
				return
			}
		}
		
		if (-not $desttable) {
			try {
				$destServer.Databases[$Database].Query($sourcetable.Script())
			}
			catch {
				Stop-Function -Message "Could not create $fqtn on destination" -ErrorRecord $_ -Target $Destination
				return
			}
		}
		
		$cmd = $sourceServer.ConnectionContext.SqlConnection.CreateCommand()
		$cmd.CommandText = $Query
		#$reader.Close()
		
		$bulkCopy = New-Object Data.SqlClient.SqlBulkCopy("$connstring;Database=$Database", $bulkCopyOptions)
		$bulkCopy.DestinationTableName = $fqtn
		$bulkCopy.BatchSize = $BatchSize
		$bulkCopy.NotifyAfter = $NotifyAfter
		$bulkCopy.BulkCopyTimeOut = $BulkCopyTimeOut
		
		$elapsed = [System.Diagnostics.Stopwatch]::StartNew()
		# Add RowCount output
		$bulkCopy.Add_SqlRowsCopied({
				$script:totalRows = $args[1].RowsCopied
				$percent = [int](($script:totalRows / $rowCount) * 100)
				$timeTaken = [math]::Round($elapsed.Elapsed.TotalSeconds, 1)
				Write-Progress -id 1 -activity "Inserting $rowCount rows." -PercentComplete $percent -Status ([System.String]::Format("Progress: {0} rows ({1}%) in {2} seconds", $script:totalRows, $percent, $timeTaken))
			})
		
		if ($Pscmdlet.ShouldProcess($SqlInstance, "Writing $rowCount rows to $fqtn")) {
			$bulkCopy.WriteToServer($cmd.ExecuteReader())
			if ($rowCount -is [int]) {
				Write-Progress -id 1 -activity "Inserting $rowCount rows" -status "Complete" -Completed
			}
		}
		
		$bulkCopy.Close()
		$bulkCopy.Dispose()
	}
}