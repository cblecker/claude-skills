---
name: repository-type
description: Automates fork vs origin detection by analyzing git remote configuration, eliminating manual inspection. Parses remote URLs to extract owner/repo metadata for GitHub operations. Essential for PR creation, branch syncing protocols. Invoked by sync, PR, and rebase skills to determine correct remote strategy. Use when detecting repository structure.
allowed-tools: Bash, Read
---

# Skill: Detecting Repository Type

## When to Use This Skill

**Use this skill when:**
- Determining if repository is a fork or origin
- Extracting owner and repository names from remotes
- Identifying correct sync/push/PR strategy
- Another skill needs repository structure information

**This skill is invoked by:**
- creating-pull-request: To determine PR target (upstream vs origin) and head format
- syncing-branch: To determine sync strategy (fork vs origin)
- rebasing-branch: To understand remote configuration

## Workflow Description

This skill analyzes git remote configuration to determine if the repository is a fork (has upstream remote) or origin-only repository. It extracts owner and repository names from remote URLs for GitHub API operations.

**Information to gather from invoking context:**
- None required - skill analyzes current repository state

## Phase 1: Check for Upstream Remote

**Objective**: Detect fork scenario by checking for upstream remote.

**Steps**:
1. Check for upstream remote:
   ```bash
   git remote get-url upstream
   ```

2. Check exit code:
   - Exit 0: Upstream exists (FORK scenario)
   - Exit 128/2: No upstream (ORIGIN scenario)

**Validation Gate: Remote Detection**

IF exit code is 0:
  Set is_fork = true
  Capture upstream_url
  Continue to Phase 2 (Fork Path)

IF exit code is non-zero:
  Set is_fork = false
  Continue to Phase 2 (Origin Path)

Phase 1 complete. Continue to Phase 2.

## Phase 2: Get Remote URLs

**Objective**: Retrieve all relevant remote URLs based on repository type.

**Fork Scenario** (is_fork = true):

Steps:
1. Get upstream URL:
   ```bash
   git remote get-url upstream
   ```

2. Get origin URL:
   ```bash
   git remote get-url origin
   ```

Capture: upstream_url, origin_url

**Origin Scenario** (is_fork = false):

Steps:
1. Get origin URL:
   ```bash
   git remote get-url origin
   ```

Capture: origin_url

**Validation Gate: URLs Retrieved**

IF all required URLs successfully retrieved:
  Continue to Phase 3

IF URL retrieval fails:
  STOP immediately
  EXPLAIN: "Cannot retrieve remote URLs"
  PROPOSE: "Verify remote configuration with `git remote -v`"
  RETURN: Error state to invoking skill

Phase 2 complete. Continue to Phase 3.

## Phase 3: Parse Remote URLs

**Objective**: Extract owner and repository names from URLs.

**Steps**:
1. Parse URLs using bash to handle both SSH and HTTPS formats:

   **SSH format**: `git@github.com:owner/repo.git`
   **HTTPS format**: `https://github.com/owner/repo.git`

   **Parsing command**:
   ```bash
   echo "$URL" | sed 's|git@github.com:||; s|https://github.com/||; s|\.git$||'
   ```

   This produces: `owner/repo`

2. Split on `/` to extract:
   - owner (first part before /)
   - repo (second part after /)

3. Apply to each URL based on repository type

**Fork Scenario** (is_fork = true):

Parse both upstream and origin URLs:
- upstream_owner, upstream_repo
- origin_owner, origin_repo

**Origin Scenario** (is_fork = false):

Parse origin URL only:
- origin_owner, origin_repo

**Validation Gate: Parsing Success**

IF all owner/repo pairs successfully extracted:
  Continue to Phase 4

IF parsing fails:
  STOP immediately
  EXPLAIN: "Cannot parse owner/repo from remote URLs"
  SHOW: URLs that failed to parse
  RETURN: Error state to invoking skill

Phase 3 complete. Continue to Phase 4.

## Phase 4: Build Result Structure

**Objective**: Return structured repository information to invoking skill.

**Fork Scenario Output**:

```json
{
  "is_fork": true,
  "upstream": {
    "url": "git@github.com:kubernetes/kubernetes.git",
    "owner": "kubernetes",
    "repo": "kubernetes"
  },
  "origin": {
    "url": "git@github.com:myuser/kubernetes.git",
    "owner": "myuser",
    "repo": "kubernetes"
  }
}
```

**Origin Scenario Output**:

```json
{
  "is_fork": false,
  "origin": {
    "url": "git@github.com:cblecker/claude-skills.git",
    "owner": "cblecker",
    "repo": "claude-skills"
  }
}
```

Phase 4 complete. Workflow complete.

## Success Criteria

This skill succeeds when:
- Repository type (fork vs origin) is correctly identified
- All remote URLs are successfully retrieved
- Owner and repository names are accurately extracted
- Structured result is returned to invoking skill
