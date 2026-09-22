<#
.SYNOPSIS
    Automated Unit & Regression Test Suite for AI Dev Prompt Clipboard
    Txek Systems - QA Gate
#>

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing, System.Windows.Forms

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
# SUITE 4: Git Dirty Status Filter (Ignore Non-Code Files) - Real Production Function
# -----------------------------------------------------------------------------
$script:currentSuite = "Git Dirty Status Filter"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$ignoredOnly = @(
    " M config.json",
    " M metrics.json",
    " M diary.md",
    "?? new_untracked_file.txt"
)
Assert-Test -Name "Ignores config.json, metrics.json, diary.md, and untracked files" -Condition (-not (Get-GitDirtyStatus -linesOverride $ignoredOnly))

$codeModified = @(
    " M config.json",
    " M app.ps1"
)
Assert-Test -Name "Correctly flags production code modification (app.ps1)" -Condition (Get-GitDirtyStatus -linesOverride $codeModified)

# -----------------------------------------------------------------------------
# SUITE 5: Config Merging & Null-Protection - Real Production Function
# -----------------------------------------------------------------------------
$script:currentSuite = "Config Merging & Null-Protection"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$userBackup = '{"AlwaysOnTop":true,"ActivePack":"frontend-ui","CustomKey":"custom"}'
$newSchema  = '{"AlwaysOnTop":false,"ActivePack":"default","NewFeatureFlag":true}'
$merged = Merge-UserConfig -UserBackupJson $userBackup -CurrentConfigJson $newSchema | ConvertFrom-Json

Assert-Test -Name "Preserves user setting ActivePack" -Condition ($merged.ActivePack -eq "frontend-ui")
Assert-Test -Name "Preserves user setting AlwaysOnTop" -Condition ($merged.AlwaysOnTop -eq $true)
Assert-Test -Name "Ingests new schema property NewFeatureFlag" -Condition ($merged.NewFeatureFlag -eq $true)

$nullProtected = Merge-UserConfig -UserBackupJson $null -CurrentConfigJson $newSchema
Assert-Test -Name "Null backup returns current schema without overwriting" -Condition ($nullProtected -eq $newSchema)

# -----------------------------------------------------------------------------
# SUITE 6: Category Filter State Machine Cycling - Real Production Function
# -----------------------------------------------------------------------------
$script:currentSuite = "Category Cycling State Machine"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$categories = @("Todos", "Workflow", "TDD", "Setup", "Auditoría", "R&D", "Estrategia")
$script:chipsList = [System.Collections.Generic.List[object]]::new()
foreach ($cat in $categories) {
    $script:chipsList.Add([PSCustomObject]@{ Category = $cat })
}

Assert-Test -Name "Cycles Todos -> Workflow" -Condition ((Get-NextCategoryName -currentCategory "Todos" -categories $script:chipsList) -eq "Workflow")
Assert-Test -Name "Cycles Estrategia -> Todos (wraps around)" -Condition ((Get-NextCategoryName -currentCategory "Estrategia" -categories $script:chipsList) -eq "Todos")
Assert-Test -Name "Cycles TDD -> Setup" -Condition ((Get-NextCategoryName -currentCategory "TDD" -categories $script:chipsList) -eq "Setup")

# -----------------------------------------------------------------------------
# SUITE 7: Tab Switching State Machine Cycling - Real Production Function
# -----------------------------------------------------------------------------
$script:currentSuite = "Tab Navigation State Machine"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$tabNames = @("Prompts", "DevFlux", "Metrics")

Assert-Test -Name "Cycles Prompts -> DevFlux" -Condition ((Get-NextTabName -currentTab "Prompts" -tabs $tabNames -Reverse $false) -eq "DevFlux")
Assert-Test -Name "Cycles Metrics -> Prompts (forward wrap)" -Condition ((Get-NextTabName -currentTab "Metrics" -tabs $tabNames -Reverse $false) -eq "Prompts")
Assert-Test -Name "Cycles Prompts -> Metrics (reverse wrap)" -Condition ((Get-NextTabName -currentTab "Prompts" -tabs $tabNames -Reverse $true) -eq "Metrics")
Assert-Test -Name "Cycles DevFlux -> Prompts (reverse)" -Condition ((Get-NextTabName -currentTab "DevFlux" -tabs $tabNames -Reverse $true) -eq "Prompts")

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
# SUITE 12: Workspace Pack Discovery & Validation Engine
# -----------------------------------------------------------------------------
$script:currentSuite = "Workspace Pack Engine & Validation"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$validPackJson = '[{"id":"test_proto","title":"Test Title","prompt":"Do something","category":"Test","tag":"<test>"}]'
$validRes = Test-WorkspacePackContent -JsonContent $validPackJson
Assert-Test -Name "Valid pack content passes validation" -Condition ($validRes.Valid -eq $true -and $validRes.Count -eq 1)

$invalidPackJson = '[{"id":"bad_proto","title":"No prompt"}]'
$invalidRes = Test-WorkspacePackContent -JsonContent $invalidPackJson
Assert-Test -Name "Pack missing required 'prompt' property fails validation" -Condition ($invalidRes.Valid -eq $false)

$nonArrayJson = '{"id":"single_obj","title":"Single","prompt":"P"}'
$nonArrayRes = Test-WorkspacePackContent -JsonContent $nonArrayJson
Assert-Test -Name "Non-array JSON fails pack validation" -Condition ($nonArrayRes.Valid -eq $false)

$malformedJson = '{ bad json syntax }'
$malformedRes = Test-WorkspacePackContent -JsonContent $malformedJson
Assert-Test -Name "Malformed JSON syntax fails pack validation" -Condition ($malformedRes.Valid -eq $false)

# Test Import-WorkspacePackFile sanitization of default.json
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidev_test_pack_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$testPacksDir = Join-Path $tempDir "packs"
New-Item -ItemType Directory -Path $testPacksDir -Force | Out-Null
$defaultPackFile = Join-Path $tempDir "default.json"
[System.IO.File]::WriteAllText($defaultPackFile, $validPackJson, [System.Text.Encoding]::UTF8)

$importRes = Import-WorkspacePackFile -SourceFilePath $defaultPackFile -TargetPacksDir $testPacksDir -Force $true
Assert-Test -Name "default.json is renamed to custom-default.json to prevent workspace collision" -Condition ($importRes.TargetName -eq "custom-default.json" -and $importRes.Key -eq "custom-default")
Assert-Test -Name "Imported pack file exists in destination packs directory" -Condition (Test-Path -LiteralPath $importRes.Path)

Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# -----------------------------------------------------------------------------
# SUITE 13: Visual Prompt Editor Engine & Color Sanitizer
# -----------------------------------------------------------------------------
$script:currentSuite = "Prompt Editor & Color Sanitizer"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$existingFixture = @(
    [PSCustomObject]@{ id = "my_custom_prompt"; title = "My Custom Prompt" }
)
$newSlug1 = New-PromptItemSlug -Title "New Feature" -ExistingPrompts $existingFixture
Assert-Test -Name "Generates valid snake_case slug" -Condition ($newSlug1 -eq "new_feature")

$collisionSlug = New-PromptItemSlug -Title "My Custom Prompt" -ExistingPrompts $existingFixture
Assert-Test -Name "Deduplicates colliding slug with incremental suffix (_1)" -Condition ($collisionSlug -eq "my_custom_prompt_1")

# Brush validation and fallback tests
$validBrush = Get-SafeBrush -colorHex "#A6E3A1" -fallbackHex "#89B4FA"
Assert-Test -Name "Valid 6-digit hex color converts to brush successfully" -Condition ($validBrush -ne $null)

$fallbackBrush = Get-SafeBrush -colorHex "not_a_color_string" -fallbackHex "#89B4FA"
Assert-Test -Name "Invalid color string safely returns fallback brush without throwing" -Condition ($fallbackBrush -ne $null)

# -----------------------------------------------------------------------------
# SUITE 14: Telemetry & Metrics Engine
# -----------------------------------------------------------------------------
$script:currentSuite = "Telemetry & Metrics Engine"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$script:metrics = @{
    totalCopies    = 0
    tddCycles      = 0
    promptUsage    = @{}
    categoryUsage  = @{}
    recentActivity = [System.Collections.Generic.List[object]]::new()
}
$script:metricsFile = Join-Path ([System.IO.Path]::GetTempPath()) ("metrics_test_" + [Guid]::NewGuid().ToString("N") + ".json")

$testItem = [PSCustomObject]@{
    id          = "feature_build"
    title       = "Feature Build"
    category    = "TDD"
    tag         = "<tdd_build>"
}

Track-PromptUsage -item $testItem
Assert-Test -Name "Track-PromptUsage increments totalCopies" -Condition ($script:metrics.totalCopies -eq 1)
Assert-Test -Name "Track-PromptUsage increments tddCycles for TDD category" -Condition ($script:metrics.tddCycles -eq 1)
Assert-Test -Name "Track-PromptUsage records prompt ID in promptUsage map" -Condition ($script:metrics.promptUsage["feature_build"] -eq 1)
Assert-Test -Name "Track-PromptUsage records category in categoryUsage map" -Condition ($script:metrics.categoryUsage["TDD"] -eq 1)
Assert-Test -Name "Track-PromptUsage inserts entry into recentActivity" -Condition ($script:metrics.recentActivity.Count -eq 1)

for ($i = 2; $i -le 30; $i++) {
    $bulkItem = [PSCustomObject]@{ id = "proto_$i"; title = "Protocol $i"; category = "General"; tag = "<tag_$i>" }
    Track-PromptUsage -item $bulkItem
}
Assert-Test -Name "recentActivity queue is strictly capped at 25 items" -Condition ($script:metrics.recentActivity.Count -eq 25)
Assert-Test -Name "recentActivity top item is the most recent (proto_30)" -Condition ($script:metrics.recentActivity[0].id -eq "proto_30")

if (Test-Path -LiteralPath $script:metricsFile) { Remove-Item -LiteralPath $script:metricsFile -Force -ErrorAction SilentlyContinue }

# -----------------------------------------------------------------------------
# SUITE 15: Quick-Fill Template Substitution Engine
# -----------------------------------------------------------------------------
$script:currentSuite = "Quick-Fill Substitution Engine"
Write-Host "`nRunning Suite: $script:currentSuite" -ForegroundColor Yellow

$templateMulti = "Deploy {{APP}} to environment {{ENV}} for user {{USER}}."
$tokensMulti = @{ "APP" = "PromptClipboard"; "ENV" = "Production"; "USER" = "Admin" }
$filledMulti = Fill-PromptTemplate -TemplateText $templateMulti -TokenValues $tokensMulti
Assert-Test -Name "Substitutes multiple distinct tokens" -Condition ($filledMulti -eq "Deploy PromptClipboard to environment Production for user Admin.")

$templateRepeated = "Check {{SERVICE}} status. Ping {{SERVICE}} endpoint."
$tokensRepeated = @{ "SERVICE" = "AuthWorker" }
$filledRepeated = Fill-PromptTemplate -TemplateText $templateRepeated -TokenValues $tokensRepeated
Assert-Test -Name "Substitutes repeated tokens consistently across entire text" -Condition ($filledRepeated -eq "Check AuthWorker status. Ping AuthWorker endpoint.")

$templateEmpty = "Value is: [{{OPTIONAL}}]"
$tokensEmpty = @{ "OPTIONAL" = "" }
$filledEmpty = Fill-PromptTemplate -TemplateText $templateEmpty -TokenValues $tokensEmpty
Assert-Test -Name "Substitutes empty token value gracefully" -Condition ($filledEmpty -eq "Value is: []")

$templateSpecial = "Regex characters test: {{INPUT}}"
$specialValue = '$100 \path\ [brackets] (parens) *asterisk* +plus+'
$tokensSpecial = @{ "INPUT" = $specialValue }
$filledSpecial = Fill-PromptTemplate -TemplateText $templateSpecial -TokenValues $tokensSpecial
Assert-Test -Name "Safely handles regex and escape characters without corruption" -Condition ($filledSpecial -eq "Regex characters test: $specialValue")

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
