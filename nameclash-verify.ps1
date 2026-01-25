param (
    [Parameter(Mandatory=$true)]
    [string]$DirectoryPath
)

# 1. Path Validation
if (-not (Test-Path -Path $DirectoryPath)) {
    Write-Error "The directory path '$DirectoryPath' does not exist."
    return
}

# Initialize storage lists
$clashFiles = New-Object System.Collections.Generic.List[PSObject]
$standardFiles = New-Object System.Collections.Generic.List[PSObject]

Write-Host "Scanning directory: $DirectoryPath" -ForegroundColor Cyan
$allFiles = Get-ChildItem -Path $DirectoryPath -File -Recurse

# 2. Sort files into buckets
foreach ($file in $allFiles) {
    $fileInfo = [PSCustomObject]@{
        Name   = $file.Name
        Folder = $file.DirectoryName
        SizeKB = [math]::Round($file.Length / 1KB, 2)
    }

    if ($file.Name -like "*# Name clash*") {
        $clashFiles.Add($fileInfo)
    }
    else {
        $standardFiles.Add($fileInfo)
    }
}

# 3. Display Summary Table
Write-Host "`n--- SCAN SUMMARY ---" -ForegroundColor Cyan
[PSCustomObject]@{
    "Clash Files Found"    = $clashFiles.Count
    "Standard Files Found" = $standardFiles.Count
    "Total Files Scanned"  = $allFiles.Count
} | Format-Table -AutoSize

# 4. Interactive Menu
Write-Host "Which list would you like to view in GridView?" -ForegroundColor Yellow
Write-Host "1. List files WITH '# Name clash'"
Write-Host "2. List files WITHOUT '# Name clash'"
Write-Host "Press any other key to exit."

$choice = Read-Host "`nEnter selection (1 or 2)"

switch ($choice) {
    "1" {
        if ($clashFiles.Count -gt 0) {
            Write-Host "Opening GridView for Clash Files..." -ForegroundColor Magenta
            $clashFiles | Out-GridView -Title "Files WITH '# Name clash' - ($($clashFiles.Count) files)"
        } else {
            Write-Host "No clash files found to display." -ForegroundColor Yellow
        }
    }
    "2" {
        if ($standardFiles.Count -gt 0) {
            Write-Host "Opening GridView for Standard Files..." -ForegroundColor Green
            $standardFiles | Out-GridView -Title "Standard Files (NO CLASH) - ($($standardFiles.Count) files)"
        } else {
            Write-Host "No standard files found to display." -ForegroundColor Yellow
        }
    }
    Default {
        Write-Host "Exiting..." -ForegroundColor Gray
    }
}