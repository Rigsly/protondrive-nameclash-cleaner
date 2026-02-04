param (
    [Parameter(Mandatory=$true)]
    [string]$DirectoryPath,

    [Parameter(Mandatory=$true)]
    [string]$ArchivePath
)

function NormalizeString { 
    param([string]$Text) return $Text.Normalize([Text.NormalizationForm]::FormC) 
}

# 1. Setup paths and Timestamped CSV
if (-not (Test-Path -Path $DirectoryPath)) {
    Write-Error "The directory path '$DirectoryPath' does not exist."
    return
}

# Ensure Archive path exists
if (-not (Test-Path -Path $ArchivePath)) {
    New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
}

$sourceBase = (Get-Item $DirectoryPath).FullName
$archiveBase = (Get-Item $ArchivePath).FullName
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "DuplicateReport_$timestamp.csv"

# 2. Regex and result initialization
$pattern = '^(?<BaseName>.+?)\s+\(# Name clash \d{4}-\d{2}-\d{2} [a-zA-Z0-9]{7} #\)(?<Extension>\.[^.]+)?$'
$results = New-Object System.Collections.Generic.List[PSObject]

# Counters
$countExactMatch = 0
$countModified = 0



Write-Host "Gathering file list..." -ForegroundColor Cyan
$allFiles = Get-ChildItem -Path $sourceBase -File -Recurse
$totalFiles = $allFiles.Count
$processed = 0

# Ask user if they want to rename instead of move 
$renameChoice = Read-Host "Do you want to rename files matching the clash pattern instead of moving them? (Y/N)" 
$renameMode = $renameChoice.Trim().ToUpper() -eq "Y"

Write-Host "Analyzing files..." -ForegroundColor Cyan

foreach ($clashFile in $allFiles) {
    $processed++
    
    if ($processed % 100 -eq 0 -or $processed -eq $totalFiles) {
        Write-Progress -Activity "Processing Duplicates" -Status "Processed $processed of $totalFiles" -PercentComplete (($processed / $totalFiles) * 100)
    }

    if ($clashFile.Name -match $pattern) {
        $baseName = $Matches['BaseName'].Trim()
        $extension = $Matches['Extension']
        $cleanName = NormalizeString ($baseName + $extension)

        # --- RENAME MODE ---
        if ($renameMode) {
            $oldPath = NormalizeString $clashFile.FullName
            $newPath = NormalizeString (Join-Path -Path $clashFile.DirectoryName -ChildPath $cleanName)

            # Normalize path
            $cleanName = NormalizeString $cleanName 
            $oldPath = NormalizeString $clashFile.FullName 
            $newPath = Join-Path -Path $clashFile.DirectoryName -ChildPath $cleanName 
            $newPath = NormalizeString $newPath

            # Avoid overwriting existing files
            if (Test-Path $newPath) {
                $cleanName = NormalizeString "$baseName (renamed)$extension"
                $newPath = Join-Path -Path $clashFile.DirectoryName -ChildPath $cleanName
            }

            Rename-Item -LiteralPath $oldPath -NewName $cleanName -Force
            $countRenamed++

            $results.Add([PSCustomObject]@{
                "Status"          = "RENAMED"
                "Old Name"        = $clashFile.Name
                "New Name"        = $cleanName
                "Original Folder" = $clashFile.DirectoryName
            })

            continue
        }

        # --- ORIGINAL MOVE LOGIC ---
        $originalName = $baseName + $extension
        $originalPath = Join-Path -Path $clashFile.DirectoryName -ChildPath $originalName

        if (Test-Path -Path $originalPath) {
            $originalFile = Get-Item -Path $originalPath
            
            try {
                # Get Hash and Metadata
                $clashHash = (Get-FileHash -Path $clashFile.FullName -Algorithm SHA256).Hash
                $originalHash = (Get-FileHash -Path $originalPath -Algorithm SHA256).Hash
                $clashDate = $clashFile.LastWriteTime
                $originalDate = $originalFile.LastWriteTime
                
                $hashMatch = $clashHash -eq $originalHash
                $dateMatch = $clashDate -eq $originalDate
                
                $status = "KEPT (Modified)"

                # 3. Move Logic: Only if both Hash and Date match
                if ($hashMatch -and $dateMatch) {
                    $countExactMatch++
                    $status = "MOVED"

                    # Determine relative directory to preserve structure
                    $relativeDir = $clashFile.DirectoryName.Replace($sourceBase, "").TrimStart("\")
                    $targetFolder = Join-Path -Path $archiveBase -ChildPath $relativeDir
                    
                    if (-not (Test-Path $targetFolder)) {
                        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
                    }

                    Move-Item -Path $clashFile.FullName -Destination $targetFolder -Force
                } else {
                    $countModified++
                }

                # 4. Record Metadata for CSV
                $results.Add([PSCustomObject]@{
                    "Status"          = $status
                    "Duplicate Name"  = $clashFile.Name
                    "Original Name"   = $originalName
                    "Hash Match"      = if ($hashMatch) { "YES" } else { "NO" }
                    "Date Match"      = if ($dateMatch) { "YES" } else { "NO" }
                    "Clash Hash"      = $clashHash
                    "Original Hash"   = $originalHash
                    "Clash Modified"  = $clashDate.ToString("yyyy-MM-dd HH:mm:ss")
                    "Original Mod"    = $originalDate.ToString("yyyy-MM-dd HH:mm:ss")
                    "Original Folder" = $clashFile.DirectoryName
                })
            } catch {
                # Skip locked files
            }
        }
    }
}

Write-Progress -Activity "Processing Duplicates" -Completed

# --- OUTPUT & EXPORT SECTION ---

Write-Host "`n--- ANALYSIS SUMMARY ---" -ForegroundColor Cyan

if ($renameMode) {
    [PSCustomObject]@{
        "Total Renamed" = $countRenamed
    } | Format-Table -AutoSize
} else {
    [PSCustomObject]@{
        "Total Clashed Pairs"        = $results.Count
        "Exact Matches (Moved)"      = $countExactMatch
        "Modified Duplicates (Kept)" = $countModified
    } | Format-Table -AutoSize
}

if ($results.Count -gt 0) {
    $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8
    Write-Host "Success: Detailed CSV saved to: $csvPath" -ForegroundColor Green
    $results | Out-GridView -Title "Duplicate Name Clash Analysis"
} else {
    Write-Host "No matching files found." -ForegroundColor Yellow
}