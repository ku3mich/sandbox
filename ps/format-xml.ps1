function Get-BomMarker {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    $file
  )

  if ($file -is [System.IO.FileInfo]) {
    $fileName = $xmlFile.FullName
  }
  else {
    $fileName = $file
  }

  $contents = [System.IO.File]::ReadAllBytes($fileName)

  $contents.Length -gt 2 -and $contents[0] -eq 0xEF -and $contents[1] -eq 0xBB -and $contents[2] -eq 0xBF
}


function Using-Object {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    [Object]
    $InputObject,

    [Parameter(Mandatory = $true)]
    [scriptblock]
    $ScriptBlock
  )

  try {
    . $ScriptBlock
  }
  finally {
    if ($null -ne $InputObject -and $InputObject -is [System.IDisposable]) {
      $InputObject.Dispose()
    }
  }
}

function Format-XMLContent {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    [string]$xml,
    $indent = 2,
    $prefixes = @()
  )
  begin {
    $nt = [System.Xml.NameTable]::new()

    $xmlns = [System.Xml.XmlNamespaceManager]::new($nt);

    $prefixes | ForEach-Object {
      $xmlns.AddNamespace($_, "$_");
    }
  }
  process {

    Using-Object ($doc = [System.Xml.XmlDocument]::new($nt)) {
      $doc.PreserveWhitespace = $true

      $contentReader = New-Object System.IO.StringReader($xml)

      $rdrSettings = [System.Xml.XmlReaderSettings]::new()
      $rdrSettings.NameTable = $nt;

      $context = [System.Xml.XmlParserContext]::new($nt, $xmlns, "", [System.Xml.XmlSpace]::Default);
      $rdr = [System.Xml.XmlTextReader]::Create($contentReader, $rdrSettings, $context);

      #$rdr.Normalization = $false
      #$rdr.WhitespaceHandling = [System.Xml.WhitespaceHandling]::All;

      $doc.Load($rdr)

      $settings = New-Object System.Xml.XmlWriterSettings;
      $settings.Indent = $true;
      $settings.IndentChars = [string]::new(' ', $indent)
      $settings.OmitXmlDeclaration = $true;
      $settings.NewLineOnAttributes = $false;
      $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
      #$settings.NamespaceHandling = [System.Xml.NamespaceHandling]::

      $sw = New-Object System.Io.Stringwriter

      Using-Object ($writer = [System.Xml.XmlWriter]::Create($sw, $settings)) {
        $doc.WriteContentTo($writer)
        $writer.Flush()

        $formatted = $sw.ToString()
        $prefixes | ForEach-Object { $formatted = $formatted -replace " xmlns:$_=`"$_`"", "" }
        $formatted
      }
    }
  }
}

function Format-XML {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
    $xmlFile,
    [Switch]
    $Inplace,
    $prefixes = @()
  )
  process {
    if ($xmlFile -is [System.IO.FileInfo]) {
      $file = $xmlFile.FullName
    }
    else {
      $file = $xmlFile
    }

    Write-Debug "processing: $file"

    try {
      $formatted = Get-Content -Raw $file | Format-XMLContent -prefixes $prefixes
    }
    catch {
      Write-Error "xml error in $file"
      Write-Error $_.Exception
    }

    if ([string]::IsNullOrWhiteSpace($formatted)) {
      return;
    }

    if ($Inplace) {
      Write-Debug "writing fomatted content to: $file"
      $formatted | Set-Content $file
    }
    else {
      Write-Debug "returning fomatted content to: $file"
      Write-Output $formatted
    }
  }
}

