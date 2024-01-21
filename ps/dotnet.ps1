function New-Project {
    param([Parameter(Mandatory = $true)]$name, [Parameter(Mandatory = $true)]$type)

    New-Item -ItemType Directory $name
    Push-Location $name
    dotnet new $type
    Pop-Location
}

function Get-ProjectFile {
    param($project)
    $project + "/" + $project + ".csproj"
}

function Update-NugetPackages {
    dotnet list package --outdated |`
        Where-Object { $_ -match "> ([^ ]+)\s+([^ ]+)\s+([^ ]+)\s+([^ ]+)" } |`
        ForEach-Object {
        dotnet add package $($Matches[1])
    }
}

function New-Git {
    & git init
    $src = "$($PSScriptRoot)/dotnet"
    Write-Output "copying from $src"
    Copy-Item "$src/*"
    git add .
}

function New-Solution {
    param(
        [switch]$git
    )

    dotnet new sln

    $location = Get-Location | Select-Object -ExpandProperty Path
    $project = [System.IO.Path]::GetFileName($location)

    New-Project $project classlib
    $tests = "$($project).Tests"
    New-Project $tests xunit

    $projectFile = Get-ProjectFile $project
    $testProjectFile = Get-ProjectFile $tests
    dotnet sln add $projectFile
    dotnet sln add $testProjectFile

    Push-Location $tests
    dotnet add reference $("../" + $projectFile)
    dotnet add package coverlet.msbuild
    Update-NugetPackages
    Pop-Location
    dotnet restore

    if ($git) {
        New-Git
        git commit -am "initial"
    }
}

function Update-DotnetTools {
    dotnet tool list -g | tail -n+3 | awk '{print $1}' | ForEach-Object {
        Write-Output "* updating: $_"
        dotnet tool update -g $_
    }
}

function Find-Solution {
    [CmdletBinding()]
    param()

    $slns = $(Get-ChildItem *.sln)
    if ($slns.Count -ne 1) {
        Write-Error "there is no single sln"
        return
    }

    $slns[0]
}

function Open-Solution {
    $sln = Find-Solution
    if ($null -ne $sln) {
        Start-Process $sln.FullName
    }
}

function Build-Solution {
    $sln = Find-Solution
    if ($null -ne $sln) {
        & dotnet build $sln.FullName
    }
}

function Add-CommonProps {
    param(
        $csproj
    )

    [xml]$doc = Get-Content $csproj
    $import = [xml]'<Import Project="$([MSBuild]::GetPathOfFileAbove(common.props))" />'
    $node = $doc.ImportNode($import.DocumentElement, $true)

    $project = [System.Xml.XmlElement]$($doc.Project)
    $g = [System.Xml.XmlElement]$($project.SelectSingleNode('PropertyGroup'))
    $doc.DocumentElement.InsertAfter($node, $g)

    $doc.OuterXml | Format-XMLContent | Set-Content $csproj
}

function Set-NewPackageVersion {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        $csprojFile,
        [Parameter(Mandatory = $true)]
        $package,
        [Parameter(Mandatory = $true)]
        $version,
        [Parameter(Mandatory = $true)]
        $newVersion
    )
    begin {
        $package = $package -replace "\.", "\."
        $package = "`"$package[0-9a-zA-Z.]+`""
        $version = $version -replace "\.", "\." # magic )
        $version = $version -replace "\?", "\d+"
        $version = "`"$version`""
    }

    process {
        $fileName = $csprojFile -is [System.IO.FileInfo] ? $csprojFile.FullName : $csprojFile;
        $encoding = $(Get-BomMarker $fileName) ? "utf8BOM" : "utf8"
        $content = Get-Content $fileName
        $content = $content -replace "(Include=$package) (Version=)$version", "`$1 `$2`"$newVersion`""

        $content | Set-Content -Encoding $encoding $fileName
    }
}

Set-Alias -Name sln -Value Open-Solution

function Copy-Skel {
    [CmdletBinding()]
    param()

    Copy-Item -Recurse $PSScriptRoot/dotnet/* .
}

function Clear-SqBuild {
    Remove-Item -Recurse -Force "$($env:LOCALAPPDATA)\Microsoft\MSBuild\Current\Microsoft.Common.targets\ImportBefore\*.*"
}

# todo: combine with xml
function Format-CsPorjWhitespace {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        $file
    )
    process {
        $fileName = $file -is [System.IO.FileInfo] ? $file.FullName : $file
        $csproj = Get-Content -Raw $fileName

        Using-Object ($doc = New-Object System.Xml.XmlDocument) {
            $doc.PreserveWhitespace = $true

            $contentReader = New-Object System.IO.StringReader($csproj)
            $rdr = New-Object System.Xml.XmlTextReader($contentReader)
            $rdr.Normalization = $false
            $rdr.WhitespaceHandling = [System.Xml.WhitespaceHandling]::All;

            $doc.Load($rdr)

            $root = $doc.DocumentElement
            $w = $root.OwnerDocument.CreateWhitespace("`n")
            $root.InsertBefore($w, $root.FirstChild) | Out-Null

            $xmlDoc = $doc.DocumentElement.OwnerDocument
            $nodes = $xmlDoc.SelectNodes("//Project/child::node()")
            $nodes | Where-Object { $_.Name -ne '#whitespace' } | ForEach-Object {
                $n = $_
                $w = $xmlDoc.CreateWhitespace("`n")
                $doc.Project.InsertAfter($w, $n) | Out-Null
            }

            $settings = New-Object System.Xml.XmlWriterSettings;
            $settings.Indent = $true;
            $settings.OmitXmlDeclaration = $true;
            $settings.NewLineOnAttributes = $false;
            $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

            $sw = New-Object System.Io.Stringwriter
            Using-Object ($writer = [System.Xml.XmlWriter]::Create($sw, $settings)) {
                $doc.WriteContentTo($writer)
                $writer.Flush()

                $sw.ToString() | Set-Content -Path $fileName
            }
        }
    }
}