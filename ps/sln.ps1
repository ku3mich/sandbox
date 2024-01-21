# dependencies

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

function Get-ResolvedPath {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $p
    )
    process {
        $p | Resolve-Path | Select-Object -ExpandProperty Path
    }
}

function Get-ProjectReferences {
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string]$projFile
    )
    [xml]$proj = Get-Content $projFile

    $proj.Project.ItemGroup.ProjectReference.Include
}

function Get-SlnProjects {
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string]$slnFile
    )

    $projects = & dotnet sln $slnFile list
    $projects | `
        Select-Object -Skip 2 | ` # first 2 lines is 'Projects', '------------'

    ForEach-Object { $_ -replace '\\', '/' }
}

function Start-SlnAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]$slnFile
    )

    $slnFile = $([string]::IsNullOrWhiteSpace($slnFile)) `
        ? $(Find-Solution) `
        : $slnFile

    if (-not $slnFile) {
        Write-Error "no solution found"
        return
    }

    $slnFile = Get-ResolvedPath $slnFile

    $sln = New-Object PSObject @{
        SlnFile               = $slnFile
        Folder                = [System.IO.Path]::GetDirectoryName($slnFile);
        IncludedProjects      = [System.Collections.ArrayList]@();
        Dependencies          = [System.Collections.ArrayList]@();
        DependenciesByProject = @{};
        AllProjects           = [System.Collections.ArrayList]@();
        MissedProjects        = [System.Collections.ArrayList]@();
    }

    $projectList = Get-SlnProjects $slnFile | ForEach-Object {
        [System.IO.Path]::Combine($sln.Folder, $_) | Get-ResolvedPath
    }

    function Get-Dependencies {
        param(
            [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
            $proj,
            $deps
        )
        process {
            if (-not $sln.DependenciesByProject.ContainsKey($proj)) {
                $sln.DependenciesByProject.Add($proj, [System.Collections.ArrayList]@())
            }

            $depByPrj = $sln.DependenciesByProject[$proj]

            $projPath = [System.IO.Path]::GetDirectoryName($proj)
            $projRefs = Get-ProjectReferences $proj

            if ($deps -notcontains $proj) {
                $deps.Add($proj) | Out-Null
            }

            $projRefs | ForEach-Object {

                if ($null -eq $_) {
                    return
                }

                $ref = [System.IO.Path]::Combine($projPath, $_) | Get-ResolvedPath

                if ($depByPrj -notcontains $ref) {
                    $depByPrj.Add($ref) | Out-Null
                }

                if ($sln.AllProjects -notcontains $ref) {
                    $sln.AllProjects.Add($ref) | Out-Null
                }
                Get-Dependencies $ref $sln.Dependencies
            }
        }
    }

    $projectList | ForEach-Object {
        $proj = $_
        Write-Debug "processing $proj"
        if ($sln.AllProjects -notcontains $proj) {
            $sln.AllProjects.Add($proj) | Out-Null
        }

        Get-Dependencies $proj $sln.IncludedProjects
    }

    $missed = $sln.AllProjects | `
        Where-Object {
        $sln.IncludedProjects -notcontains $_
    }

    $missed | ForEach-Object {
        $relative = [System.IO.Path]::GetRelativePath($sln.Folder, $_)
        $sln.MissedProjects.Add($relative) | Out-Null
    }

    $sln
}

function Add-MissedProjects {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $analysis
    )
    process {
        "Processing $($analysis.SlnFile) ..."
        Push-Location $analysis.SlnFolder
        $analysis.MissedProjects | ForEach-Object {
            "  * adding: $_"
            dotnet sln add $_ -s "dependencies"
        }
        Pop-Location
    }
}