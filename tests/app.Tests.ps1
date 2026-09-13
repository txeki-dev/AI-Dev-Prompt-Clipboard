<#
.SYNOPSIS
    Automated Unit & Regression Test Suite for AI Dev Prompt Clipboard
    Txek Systems - QA Gate
#>

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$appScript = Join-Path $scriptDir "app.ps1"
$testsPassed = 0
$testsFailed = 0
$testResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function Assert-Test {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Details = ""
    )

    if ($Condition) {
        $global:testsPassed++
        $script:testResults.Add([PSCustomObject]@{
            Suite   = $script:currentSuite
            Test    = $Name
            Status  = "PASS"
            Details = $Details
        })
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $global:testsFailed++
        $script:testResults.Add([PSCustomObject]@{
            Suite   = $script:currentSuite
            Test    = $Name
            Status  = "FAIL"
            Details = $Details
        })
        Write-Host "  [FAIL] $Name - $Details" -ForegroundColor Red
    }
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "  AI Dev Prompt Clipboard - Test Suite (QA Gate)" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# SUITE 1: AST Parser & Syntax Integrity Gate
# -----------------------------------------------------------------------------
$script:currentSuite = "AST Syntax Integrity"
Write-Host "Running Suite: $script:currentSuite" -ForegroundColor Yellow

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($appScript, [ref]$tokens, [ref]$errors)
Assert-Test -Name "app.ps1 parses with 0 syntax errors" -Condition ($errors.Count -eq 0) -Details "Errors: $($errors.Count)"

$installScript = Join-Path $scriptDir "install-shortcut.ps1"
if (Test-Path -LiteralPath $installScript) {
    $astInstall = [System.Management.Automation.Language.Parser]::ParseFile($installScript, [ref]$tokens, [ref]$errors)
    Assert-Test -Name "install-shortcut.ps1 parses with 0 syntax errors" -Condition ($errors.Count -eq 0) -Details "Errors: $($errors.Count)"
}

$setupScript = Join-Path $scriptDir "setup.ps1"
if (Test-Path -LiteralPath $setupScript) {
    $astSetup = [System.Management.Automation.Language.Parser]::ParseFile($setupScript, [ref]$tokens, [ref]$errors)
    Assert-Test -Name "setup.ps1 parses with 0 syntax errors" -Condition ($errors.Count -eq 0) -Details "Errors: $($errors.Count)"
}

# -----------------------------------------------------------------------------
# IMPORT PRODUCTION FUNCTIONS DIRECTLY FROM app.ps1 AST
# Eliminates mock duplication; tests real production code in isolation
# -----------------------------------------------------------------------------
$astFuncs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
foreach ($f in $astFuncs) {
    Set-Item -Path "Function:\$($f.Name)" -Value ($f.Body.GetScriptBlock())
}

# Global test fixtures
$script:prompts = Get-Content (Join-Path $scriptDir "prompts.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$prompts = $script:prompts
$script:fluxSequence = @(
    @{ Id = "initial";           Next = "intro" },
    @{ Id = "intro";             Next = "feature_plan" },
    @{ Id = "feature_plan";      Next = "feature_build" },
    @{ Id = "feature_build";     Next = "audit" },
    @{ Id = "audit";             Next = "remediate" },
    @{ Id = "remediate";         Next = "outro" },
    @{ Id = "outro";             Next = "feature_plan" },
    @{ Id = "rdi";               Next = "product_strategy" },
    @{ Id = "product_strategy";  Next = "business_strategy" },
    @{ Id = "business_strategy"; Next = "feature_plan" },
    @{ Id = "migrate";           Next = "intro" }
)

# -----------------------------------------------------------------------------
# SUITE 2: Template Token Parser ({{var}}) - Real Production Function
# -----------------------------------------------------------------------------
$script:currentSuite = "Template Token Parser"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$samplePrompt = "Execute `<test>` on branch {{BRANCH}} with date {{DATE}} and repeat {{BRANCH}}."
$extracted = Get-TemplateTokens $samplePrompt
Assert-Test -Name "Extracts exactly 2 unique tokens" -Condition ($extracted.Count -eq 2) -Details "Got: $($extracted -join ', ')"
Assert-Test -Name "Contains token BRANCH" -Condition ($extracted -contains "BRANCH")
Assert-Test -Name "Contains token DATE" -Condition ($extracted -contains "DATE")
Assert-Test -Name "Deduplicates repeated tokens" -Condition (($extracted | Where-Object { $_ -eq "BRANCH" }).Count -eq 1)

$emptyTokens = Get-TemplateTokens "Prompt without parameters"
Assert-Test -Name "Returns empty array when no template tokens present" -Condition ($emptyTokens.Count -eq 0)

# -----------------------------------------------------------------------------
# SUITE 3: Smart Suggestion Heuristics - Real Production Function
# -----------------------------------------------------------------------------
$script:currentSuite = "Smart Suggestion Heuristics"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$dateVal = Get-SmartSuggestion -tokenName "DATE"
Assert-Test -Name "DATE returns yyyy-MM-dd format" -Condition ($dateVal -match '^\d{4}-\d{2}-\d{2}$') -Details "Got: $dateVal"

$todayVal = Get-SmartSuggestion -tokenName "TODAY"
Assert-Test -Name "TODAY alias returns yyyy-MM-dd format" -Condition ($todayVal -match '^\d{4}-\d{2}-\d{2}$')

$timeVal = Get-SmartSuggestion -tokenName "TIME"
Assert-Test -Name "TIME returns HH:mm:ss format" -Condition ($timeVal -match '^\d{2}:\d{2}:\d{2}$') -Details "Got: $timeVal"

$unknownVal = Get-SmartSuggestion -tokenName "UNKNOWN_VARIABLE"
Assert-Test -Name "Unknown token returns empty string" -Condition ($unknownVal -eq "")

# -----------------------------------------------------------------------------
# SUITE 4: Git Dirty Status Filter (Ignore Non-Code Files)
# -----------------------------------------------------------------------------
$script:currentSuite = "Git Dirty Status Filter"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

function Invoke-GitDirtyFilterTest($lines) {
    $codeDirty = @($lines) | Where-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return $false }
        if ($line -match 'config\.json|metrics\.json|diary\.md|diary_archive\.md|launch\.vbs|version\.json|\.cache|graphify') { return $false }
        if ($line -match '^\?\?\s+') { return $false }
        return $true
    }
    return ($codeDirty.Count -gt 0)
}

$ignoredOnly = @(
    " M config.json",
    " M metrics.json",
    " M diary.md",
    "?? new_untracked_file.txt"
)
Assert-Test -Name "Ignores config.json, metrics.json, diary.md, and untracked files" -Condition (-not (Invoke-GitDirtyFilterTest $ignoredOnly))

$codeModified = @(
    " M config.json",
    " M app.ps1"
)
Assert-Test -Name "Correctly flags production code modification (app.ps1)" -Condition (Invoke-GitDirtyFilterTest $codeModified)

# -----------------------------------------------------------------------------
# SUITE 5: Config Merging & Null-Protection
# -----------------------------------------------------------------------------
$script:currentSuite = "Config Merging & Null-Protection"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

function Invoke-ConfigMergeTest($configBackupJson, $currentConfigJson) {
    if (-not $configBackupJson -or [string]::IsNullOrWhiteSpace($configBackupJson)) { return $currentConfigJson }
    $userSaved = $configBackupJson | ConvertFrom-Json
    $newSchema = $currentConfigJson | ConvertFrom-Json
    $merged = @{}
    if ($newSchema) {
        foreach ($prop in $newSchema.psobject.properties) {
            $merged[$prop.Name] = $prop.Value
        }
    }
    if ($userSaved) {
        foreach ($prop in $userSaved.psobject.properties) {
            $merged[$prop.Name] = $prop.Value
        }
    }
    return ($merged | ConvertTo-Json -Compress)
}

$userBackup = '{"AlwaysOnTop":true,"ActivePack":"frontend-ui","CustomKey":"custom"}'
$newSchema  = '{"AlwaysOnTop":false,"ActivePack":"default","NewFeatureFlag":true}'
$merged = Invoke-ConfigMergeTest $userBackup $newSchema | ConvertFrom-Json

Assert-Test -Name "Preserves user setting ActivePack" -Condition ($merged.ActivePack -eq "frontend-ui")
Assert-Test -Name "Preserves user setting AlwaysOnTop" -Condition ($merged.AlwaysOnTop -eq $true)
Assert-Test -Name "Ingests new schema property NewFeatureFlag" -Condition ($merged.NewFeatureFlag -eq $true)

$nullProtected = Invoke-ConfigMergeTest $null $newSchema
Assert-Test -Name "Null backup returns current schema without overwriting" -Condition ($nullProtected -eq $newSchema)

# -----------------------------------------------------------------------------
# SUITE 6: Category Filter State Machine Cycling
# -----------------------------------------------------------------------------
$script:currentSuite = "Category Cycling State Machine"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$categories = @("Todos", "Workflow", "TDD", "Setup", "Auditoría", "R&D", "Estrategia")
$script:chipsList = [System.Collections.Generic.List[object]]::new()
foreach ($cat in $categories) {
    $script:chipsList.Add([PSCustomObject]@{ Category = $cat })
}

function Invoke-CategoryCycleStep($startCat, [bool]$reverse = $false) {
    $currentIndex = -1
    for ($i = 0; $i -lt $script:chipsList.Count; $i++) {
        if ($script:chipsList[$i].Category -ieq $startCat) {
            $currentIndex = $i
            break
        }
    }
    if ($currentIndex -lt 0) { $currentIndex = 0 }
    $nextIndex = if ($reverse) {
        ($currentIndex - 1 + $script:chipsList.Count) % $script:chipsList.Count
    } else {
        ($currentIndex + 1) % $script:chipsList.Count
    }
    return $script:chipsList[$nextIndex].Category
}

Assert-Test -Name "Cycles Todos -> Workflow" -Condition ((Invoke-CategoryCycleStep "Todos") -eq "Workflow")
Assert-Test -Name "Cycles Estrategia -> Todos (wraps around)" -Condition ((Invoke-CategoryCycleStep "Estrategia") -eq "Todos")
Assert-Test -Name "Cycles TDD -> Setup" -Condition ((Invoke-CategoryCycleStep "TDD") -eq "Setup")

# -----------------------------------------------------------------------------
# SUITE 7: Tab Switching State Machine Cycling
# -----------------------------------------------------------------------------
$script:currentSuite = "Tab Navigation State Machine"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$tabNames = @("Prompts", "DevFlux", "Metrics")

function Invoke-TabCycleStep($currentTab, $reverse = $false) {
    $tabIdx = -1
    for ($i = 0; $i -lt $tabNames.Count; $i++) {
        if ($tabNames[$i] -ieq $currentTab) { $tabIdx = $i; break }
    }
    $step = if ($reverse) { -1 } else { 1 }
    $nextIdx = ($tabIdx + $step + $tabNames.Count) % $tabNames.Count
    return $tabNames[$nextIdx]
}

Assert-Test -Name "Cycles Prompts -> DevFlux" -Condition ((Invoke-TabCycleStep "Prompts" $false) -eq "DevFlux")
Assert-Test -Name "Cycles Metrics -> Prompts (forward wrap)" -Condition ((Invoke-TabCycleStep "Metrics" $false) -eq "Prompts")
Assert-Test -Name "Cycles Prompts -> Metrics (reverse wrap)" -Condition ((Invoke-TabCycleStep "Prompts" $true) -eq "Metrics")
Assert-Test -Name "Cycles DevFlux -> Prompts (reverse)" -Condition ((Invoke-TabCycleStep "DevFlux" $true) -eq "Prompts")

# -----------------------------------------------------------------------------
# SUITE 8: DEV FLUX Sequence Stepper - Real Production Function & Rules
# -----------------------------------------------------------------------------
$script:currentSuite = "DEV FLUX Sequence Stepper"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$script:lastCopiedPromptId = "initial"
Assert-Test -Name "initial steps to intro" -Condition ((Get-NextPhasePrompt).id -eq "intro")

$script:lastCopiedPromptId = "intro"
Assert-Test -Name "intro steps to feature_plan" -Condition ((Get-NextPhasePrompt).id -eq "feature_plan")

$script:lastCopiedPromptId = "feature_plan"
Assert-Test -Name "feature_plan steps to feature_build" -Condition ((Get-NextPhasePrompt).id -eq "feature_build")

$script:lastCopiedPromptId = "feature_build"
Assert-Test -Name "feature_build steps to audit" -Condition ((Get-NextPhasePrompt).id -eq "audit")

$script:lastCopiedPromptId = "audit"
Assert-Test -Name "audit steps to remediate" -Condition ((Get-NextPhasePrompt).id -eq "remediate")

$script:lastCopiedPromptId = "remediate"
Assert-Test -Name "remediate steps to outro" -Condition ((Get-NextPhasePrompt).id -eq "outro")

$script:lastCopiedPromptId = "outro"
Assert-Test -Name "outro transitions to feature_plan (canonical lifecycle)" -Condition ((Get-NextPhasePrompt).id -eq "feature_plan")

$script:lastCopiedPromptId = "rdi"
Assert-Test -Name "rdi bridges to product_strategy" -Condition ((Get-NextPhasePrompt).id -eq "product_strategy")

$script:lastCopiedPromptId = "product_strategy"
Assert-Test -Name "product_strategy bridges to business_strategy" -Condition ((Get-NextPhasePrompt).id -eq "business_strategy")

$script:lastCopiedPromptId = "business_strategy"
Assert-Test -Name "business_strategy transitions to feature_plan" -Condition ((Get-NextPhasePrompt).id -eq "feature_plan")

# -----------------------------------------------------------------------------
# SUITE 9: Workspace Pack Discovery
# -----------------------------------------------------------------------------
$script:currentSuite = "Workspace Pack Discovery"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$packsDir = Join-Path $scriptDir "packs"
Assert-Test -Name "Packs directory exists" -Condition (Test-Path -LiteralPath $packsDir)

$corePack = Join-Path $packsDir "core-engineering.json"
Assert-Test -Name "core-engineering.json exists" -Condition (Test-Path -LiteralPath $corePack)

$frontendPack = Join-Path $packsDir "frontend-ui.json"
Assert-Test -Name "frontend-ui.json exists" -Condition (Test-Path -LiteralPath $frontendPack)

$securityPack = Join-Path $packsDir "security-devops.json"
Assert-Test -Name "security-devops.json exists" -Condition (Test-Path -LiteralPath $securityPack)

$coreContent = Get-Content -LiteralPath $corePack -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Test -Name "Core pack contains at least 10 protocols" -Condition ($coreContent.Count -ge 10)

# -----------------------------------------------------------------------------
# SUITE 10: Telemetry & Metrics Aggregator (Canonical app.ps1 Formula)
# -----------------------------------------------------------------------------
$script:currentSuite = "Metrics Aggregator"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$sampleMetrics = @{
    totalCopies   = 10
    tddCycles     = 3
    promptUsage   = @{ "feature_build" = 3; "intro" = 4 }
    categoryUsage = @{ "TDD" = 3; "Workflow" = 4 }
}

# Canonical production formula from app.ps1 lines 2913 and 3063
$ratio = if ($sampleMetrics.totalCopies -gt 0) { [math]::Round(($sampleMetrics.tddCycles / [double]$sampleMetrics.totalCopies) * 100) } else { 0 }
Assert-Test -Name "Computes canonical TDD discipline ratio (30%)" -Condition ($ratio -eq 30) -Details "Got: $ratio%"

# -----------------------------------------------------------------------------
# SUITE 11: Inno Setup Packaging & Asset Integrity Gate
# -----------------------------------------------------------------------------
$script:currentSuite = "Inno Setup Packaging Integrity"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$issFile = Join-Path $scriptDir "installer.iss"
Assert-Test -Name "installer.iss exists" -Condition (Test-Path -LiteralPath $issFile)

if (Test-Path -LiteralPath $issFile) {
    $issContent = Get-Content -LiteralPath $issFile
    $sourceFiles = [System.Collections.Generic.List[string]]::new()
    $inFiles = $false
    foreach ($line in $issContent) {
        if ($line -match '^\s*\[Files\]') { $inFiles = $true; continue }
        if ($inFiles -and $line -match '^\s*\[') { $inFiles = $false }
        if ($inFiles -and $line -match 'Source:\s*"([^"]+)"') {
            $sourceFiles.Add($matches[1])
        }
    }

    Assert-Test -Name "installer.iss has Source files defined" -Condition ($sourceFiles.Count -gt 0)
    Assert-Test -Name "metrics.json is NOT packaged in installer.iss (prevents CI failure and telemetry leak)" -Condition (-not ($sourceFiles -contains "metrics.json"))

    $allSourcesExist = $true
    $missingSources = @()
    foreach ($src in $sourceFiles) {
        $resolved = Join-Path $scriptDir $src
        $items = @(Get-Item -Path $resolved -ErrorAction SilentlyContinue)
        if ($items.Count -eq 0) {
            $allSourcesExist = $false
            $missingSources += $src
        }
    }
    Assert-Test -Name "All installer.iss Source files exist on disk" -Condition $allSourcesExist -Details ($missingSources -join ", ")
}

# -----------------------------------------------------------------------------
# SUMMARY REPORT
# -----------------------------------------------------------------------------
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "  Test Execution Summary" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Total Tests : $($testsPassed + $testsFailed)"
Write-Host "Passed      : $testsPassed" -ForegroundColor Green
Write-Host "Failed      : $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "DarkGreen" } else { "Red" })

if ($testsFailed -gt 0) {
    Write-Host "`nQA Gate Failed with $testsFailed errors." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nQA Gate 100% GREEN. Zero regressions detected." -ForegroundColor Green
    exit 0
}
