# Proton Drive "Name Clash" Cleanup Tools

PowerShell scripts designed to identify and safely resolve the duplicate file issue caused by Proton Drive sync errors. These errors typically generate redundant files with the suffix `(# Name clash YYYY-MM-DD Hash #)`.

## ⚠️ Disclaimer & Safety

* **AI-Assisted:** These scripts were generated with the assistance of Gemini. The author has used them on his own data, but is not a PowerShell expert!
* **Test First:** **Always** test these scripts on a copy of your data before running them on your main directory.
* **Backups:** Ensure you have a full, separate backup of your Proton Drive contents before proceeding.
* **No Warranty:** Use these tools at your own risk.

---

## The Problem

Under certain conditions, Proton Drive duplicates files instead of merging/overwriting them during sync conflicts. This results in "Original" files sitting alongside "Name Clash" versions. There can be thousands of files spread across many directories, making manual clean up challenging. There is also the potential risk some "clash" files may actually contain newer data than the original versions and therefore be desireable to preserve.

## The Solution

This repository provides two tools to automate the cleanup and verification process.

### 1. The Cleanup Script (`nameclash-clean.ps1`)

This is the primary tool for identifying and moving confirmed duplicates out of your drive directory.

**How it works:**

* **Regex Identification:** It uses a regular expression to match the specific Proton Drive clash naming convention.
* **Strict Verification:** It only considers a file a duplicate if:
1. The **SHA256 Hash** matches the original exactly.
2. The **Last Modified Date** matches the original exactly.
* **Preserved Files & Structure:** Duplicate files are moved to an archive directory of your choice, maintaining their original subfolder hierarchy.
* **Detailed Reporting:** Generates a timestamped `.csv` report (e.g., `DuplicateReport_20260125_2115.csv`) detailing every file processed, its hash, its modification date, and its final status (MOVED, or KEPT-Modified).

**Usage:**

```powershell
.\nameclash-clean.ps1 -DirectoryPath "C:\Path\To\ProtonDrive" -ArchivePath "C:\Path\To\Archive"

```

### 2. The Verification Script (`nameclash-verify.ps1`)

Use this tool to validate your directory state before or after running the cleanup script.

**How it works:**

* Recursively scans the target directory.
* Provides a summary count of "Clash" files vs. "Standard" files.
* Offers an interactive prompt to view either list in a searchable, sortable **GridView** window.

**Usage:**

```powershell
.\nameclash-verify.ps1 -DirectoryPath "C:\Path\To\ProtonDrive"

```

---

## Installation & Requirements

1. **Download:** Clone this repository or download the `.ps1` files.
2. **PowerShell Execution Policy:** You may need to allow script execution in your terminal:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

```
3. **Safety Check:** Confirm you have backups, and verify the behaviour of the script on a **copy** of your Proton Drive directory before running it for real!
4. **De-duplicate:** Run the clean script, and then review the DuplicateReport.csv saved in the same directory as the script to confirm what has happened.
5. **Verify:** Use the verify script to confirm the files that have been removed, and those which remain match your expectations.
5. **Restore PowerShell Execution Policy:** Optionally, return to default settings:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser

```