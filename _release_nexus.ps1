param(
[string]$Message = "Automated commit"
)

Write-Host "=== Nexus Release Script ==="

function Get-GitHubToken {
    foreach ($name in @("GITHUB_TOKEN", "GH_TOKEN")) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    try {
        $ghToken = (gh auth token 2>$null).Trim()
        if (-not [string]::IsNullOrWhiteSpace($ghToken)) {
            return $ghToken
        }
    } catch {
        # Ignore when gh is not installed or not authenticated.
    }

    return ""
}

function Get-GitHubApiHeaders([string]$Token) {
    $headers = @{ Accept = "application/vnd.github+json"; "User-Agent" = "Nexus Release Script" }
    if (-not [string]::IsNullOrWhiteSpace($Token)) {
        $headers["Authorization"] = "Bearer $Token"
    }
    return $headers
}

$token = Get-GitHubToken

# --- Get current branch ---
$currentBranch = git rev-parse --abbrev-ref HEAD
Write-Host ":: Current branch: $currentBranch"

# --- Ensure upstream exists ---
$upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
if (-not $upstream) {
    Write-Host ":: Branch $currentBranch has no upstream. Setting upstream to origin/$currentBranch..."
    git push --set-upstream origin $currentBranch
} else {
    Write-Host ":: Branch $currentBranch already has upstream: $upstream"
}

# --- Git LFS setup ---
git lfs install | Out-Null
$patterns = @("*.zip", "*.wav", "*.exe", "*.dll")
foreach ($p in $patterns) { git lfs track $p | Out-Null }
git add .gitattributes

# --- Commit any changes ---
$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -eq "main") {
    $Message = "Automated commit - main branch"
} elseif ($currentBranch -like "feature/*") {
    $Message = "Automated commit - feature branch: $currentBranch"
} elseif ($currentBranch -like "dev/*") {
    $Message = "Automated commit - dev branch: $currentBranch"
} else {
    $Message = "Automated commit - branch: $currentBranch"
}

# --- Commit any changes ---
if (-not (git status --porcelain)) {
    Write-Host ":: No changes to commit."
} else {
    git add .
    git commit -m "$Message"
    git push
}

# --- Decide tag prefix ---
if ($currentBranch -eq "main") { $tagPrefix = "v" } else { $tagPrefix = "test-v" }

# --- Get last tag for this branch type ---
$lastTag = git tag --list "$tagPrefix*" | Sort-Object { [version]($_ -replace "^$tagPrefix", "") } -Descending | Select-Object -First 1
if ($lastTag -match "^$tagPrefix(\d+)\.(\d+)\.(\d+)$") {
    $major = [int]$matches[1]; $minor = [int]$matches[2]; $patch = [int]$matches[3]
} else {
    $major = 0; $minor = 0; $patch = 0
    $lastTag = "$tagPrefix0.0.0"
}
Write-Host ":: Last tag: $lastTag"

# --- Ask user which part to increment ---
$choice = Read-Host "Which part would you like to increment? (1=major, 2=minor, 3=patch, default=patch):"
switch ($choice.ToLower()) {
    "major" { $major++; $minor=0; $patch=0 }
    "1"     { $major++; $minor=0; $patch=0 }
    "minor" { $minor++; $patch=0 }
    "2"     { $minor++; $patch=0 }
    "patch" { $patch++ }
    "3"     { $patch++ }
    default { $patch++ }
}

# --- Ensure tag is unique ---
do {
    $newTag = "$tagPrefix$major.$minor.$patch"
    $existingTag = git tag --list $newTag
    if ($existingTag) { Write-Host ":: Tag $newTag already exists, incrementing patch..."; $patch++ }
} while ($existingTag)

Write-Host ":: Creating tag: $newTag"

# --- Tag (signed) and push ---
git tag -s $newTag -m "Release $newTag"
git push origin $newTag
Write-Host ":: Committed and tagged (signed) as $newTag."

# --- Update changelog ---
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$changelogPath = "changelog.txt"

if ($lastTag -ne "$tagPrefix0.0.0") {
    $commits = git log $lastTag..HEAD --pretty=format:"- %s"
} else {
    $commits = git log --pretty=format:"- %s"
}

$changelogEntry = "[$timestamp] $newTag`n$commits`n"
Add-Content -Path $changelogPath -Value $changelogEntry
Write-Host ":: Updated changelog.txt:`n$changelogEntry"

git add $changelogPath
git commit -m "Update changelog for $newTag"
git push

# --- Update version.txt ---
$versionFile = "version.txt"
$versionInfo = "$newTag ($timestamp)"
Set-Content -Path $versionFile -Value $versionInfo
Write-Host ":: Updated version.txt: $versionInfo"

git add $versionFile
git commit -m "Update version file for $newTag"
git push

Write-Host ":: Release complete: $newTag"

# --- Remove old releases ---
$repo       = "RobertoTorino/Nexus"
$keepLatest = 2

if (-not [string]::IsNullOrWhiteSpace($token)) {
    $headers = Get-GitHubApiHeaders $token

    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Headers $headers |
            Sort-Object { $_.created_at } -Descending
        $oldReleases = $releases | Select-Object -Skip $keepLatest

        foreach ($rel in $oldReleases) {
            Write-Host ":: Deleting release: $($rel.name) / tag: $($rel.tag_name)"
            Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/$($rel.id)" -Method Delete -Headers $headers
            if (git ls-remote --tags origin $rel.tag_name) { git push origin :refs/tags/$($rel.tag_name) }
            git tag -d $($rel.tag_name)
        }

        # --- Remove old tags, keep latest 2 per type ---
        if ($currentBranch -eq "main") { $allTags = git tag --list "v*" --sort=-creatordate }
        else { $allTags = git tag --list "test-v*" --sort=-creatordate }

        $tagsToDelete = $allTags | Select-Object -Skip 2
        foreach ($tag in $tagsToDelete) {
            if (git ls-remote --tags origin $tag) { git push origin :refs/tags/$tag }
            git tag -d $tag
            Write-Host ":: Deleted old tag: $tag"
        }

        # --- Workflow cleanup ---
        $repoOwner = "RobertoTorino"; $repoName="Nexus"; $keepRuns=2; $workflowId="release.yml"
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/actions/workflows/$workflowId/runs?per_page=100" -Headers $headers
        $allRuns = $response.workflow_runs | Sort-Object { $_.created_at } -Descending
        $oldRuns = $allRuns | Select-Object -Skip $keepRuns

        foreach ($run in $oldRuns) {
            Write-Host ":: Deleting workflow run $($run.id) (status: $($run.status), conclusion: $($run.conclusion))"
            try {
                Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/actions/runs/$($run.id)" -Method Delete -Headers $headers
                Write-Host ":: Deleted workflow run $($run.id)"
            } catch {
                Write-Warning ":: Failed to delete run $($run.id): $_"
            }
        }

        Write-Host ":: Old workflows, releases and tags cleaned up, keeping the latest $keepLatest release(s)."
    } catch {
        Write-Warning ":: GitHub API cleanup skipped: $($_.Exception.Message)"
    }
} else {
    Write-Warning ":: No GitHub token found. Skipping release/workflow cleanup and status checks. Set GITHUB_TOKEN, GH_TOKEN, or authenticate with gh."
}

Write-Host ":: Release finished for tag: $newTag"

# CHECK GITHUB WORKFLOW STATUS + SHOW RELEASE
if ($currentBranch -ne "main" -and $currentBranch -like "feature/*") {
    Write-Host ":: Skipping workflow status check for branch $currentBranch"
} else
{

    Write-Host ":: Now checking workflow status and release info... "
    $tagCommitSha = (git rev-list -n 1 $newTag).Trim()
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Warning ":: Skipping workflow status check because no GitHub token was found."
        return
    }

    $headers = Get-GitHubApiHeaders $token

    Write-Host "`n:: Checking latest GitHub Actions workflow run..."

    # === Wait for workflow completion (poll every 15s) ---
    $maxAttempts = 40
    $attempt = 0
    $runCompleted = $false

    do
    {
        $workflowFile = "release.yml"
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/actions/workflows/$workflowFile/runs?event=push&per_page=20" -Headers $headers
        $matchingRuns = @($response.workflow_runs | Where-Object { $_.head_sha -eq $tagCommitSha })

        if (-not $matchingRuns -or $matchingRuns.Count -eq 0)
        {
            Write-Host ":: No workflow run found yet for tag $newTag (commit $tagCommitSha). Waiting..."
            Start-Sleep -Seconds 15
            $attempt++
            continue
        }

        $latestRun = $matchingRuns | Sort-Object { $_.created_at } -Descending | Select-Object -First 1

        Write-Host (":: Current status: {0} (conclusion: {1})" -f $latestRun.status, $latestRun.conclusion)

        if ($latestRun.status -eq "completed")
        {
            $runCompleted = $true
            break
        }

        Start-Sleep -Seconds 15
        $attempt++
    } while ($attempt -lt $maxAttempts)

    if (-not $runCompleted)
    {
        Write-Warning ":: Timeout waiting for GitHub workflow to complete."
        Exit 1
    }

    if ($latestRun.conclusion -ne "success")
    {
        Write-Host ":: GitHub workflow failed. Conclusion: $( $latestRun.conclusion )"
        Exit 1
    }

    Write-Host ":: GitHub workflow succeeded!"
    Write-Host ":: Commit: $( $latestRun.head_commit.message )"
    Write-Host ":: Run URL: $( $latestRun.html_url )`n"


    # === Find latest release and show link ---
    try
    {
        $releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/releases/latest" -Headers $headers
    }
    catch
    {
        Write-Warning ":: No release found"
    }

    if ($releaseResponse)
    {
        Write-Host ":: Release finished for tag: $newTag"
        Write-Host "================ RELEASE INFO ================"
        Write-Host ":: Tag: $( $releaseResponse.tag_name )"
        Write-Host ":: Name: $( $releaseResponse.name )"
        Write-Host ":: URL: $( $releaseResponse.html_url )"
        Write-Host "=============================================="
    }
    else
    {
        Write-Warning ":: No more release found."
    }
}


Write-Host ":: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: "

