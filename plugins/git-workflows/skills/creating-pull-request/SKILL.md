---
name: creating-pull-request
description: Create GitHub pull requests with auto-generated titles and descriptions. Use when creating PRs, opening pull requests, or when you say 'create a PR', 'make a pull request', 'open a PR', 'create PR', or 'submit for review'.
allowed-tools: [mcp__git__git_status, mcp__git__git_log, mcp__git__git_diff, mcp__git__git_branch, mcp__github__create_pull_request, mcp__sequential-thinking__sequentialthinking, Bash(git ls-remote:*), Bash(git remote get-url:*), Bash(git push:*), Read, Glob]
---

# Skill: Creating a Pull Request

## When to Use This Skill

**Use this skill when the user requests:**
- "create a PR"
- "create a pull request"
- "make a pull request"
- "open a PR"
- "submit for review"
- "create PR for this"
- Any variation requesting GitHub pull request creation

**Use other skills instead when:**
- Only committing changes → Use creating-commit skill
- Viewing existing PRs → Use GitHub MCP tools directly
- Updating existing PRs → Use GitHub MCP update tools

---

## Workflow Description

This skill creates GitHub pull requests with automatic commit handling, repository type detection, PR content generation, branch pushing, and GitHub PR creation via MCP.

**Information to gather from user request:**
- Draft status: Detect if user mentioned "draft" or "WIP" in their request (default: false)
- PR title: Extract title if user provided one (e.g., "create PR titled '...'"), otherwise auto-generate
- PR description: Extract description if user provided one, otherwise auto-generate
- Target branch: Extract target branch if specified (e.g., "create PR to develop" or "base on staging"), otherwise use mainline

---

## Phase 1: Verify Committed Changes

**Objective**: Ensure all changes are committed.

**Steps**:
1. Check: `mcp__git__git_status` with `repo_path` (cwd)
2. Parse: Identify modified, untracked, staged files

**Validation Gate**: IF uncommitted changes:
- Propose invoking creating-commit skill
- IF user approves: Invoke skill, verify success
- IF user declines or skill fails: STOP

Continue to Phase 2.

---

## Phase 2: Feature Branch Validation

**Objective**: Ensure we're on a feature branch, not mainline.

**Step 1: Get current branch**

Tool: `mcp__git__git_branch`
Parameters:
- `repo_path`: Current working directory absolute path
- `branch_type`: "local"
Permission: Auto-approved (read-only MCP tool)
Expected output: List of local branches with current branch indicated
Capture: Current branch name (the branch marked as current)

**Step 2: Detect mainline branch**

Command: `git ls-remote --exit-code --symref origin HEAD | sed -n 's/^ref: refs\/heads\/\(.*\)\tHEAD/\1/p'`
Permission: Matches `Bash(git ls-remote:*)` in allowed-tools
Purpose: Get remote repository's default branch name (main/master/develop/etc)
Expected output: Single line with mainline branch name (e.g., "main")
Capture: Mainline branch name

**Step 3: Compare current branch to mainline**

Compare captured branch names:
- IF current equals mainline: Set on_mainline = true
- IF current differs from mainline: Set on_mainline = false

**Validation Gate: Not on Mainline**

IF on_mainline = false (on feature branch):
  PROCEED to Phase 3

IF on_mainline = true AND user has not explicitly approved:
  WARN: "Currently on mainline branch [branch-name]"
  EXPLAIN: "Pull requests should be created from feature branches to keep mainline clean and enable proper review workflow"
  PROPOSE: "Create a feature branch for this PR"
  ASK: "Would you like me to create a feature branch now?"
  WAIT for user decision

  IF user approves branch creation:
    INVOKE: creating-branch skill
    WAIT for creating-branch skill to complete

    IF creating-branch succeeded:
      VERIFY: Now on feature branch (not mainline)
      Capture new current branch name
      PROCEED to Phase 3

    IF creating-branch failed:
      STOP immediately
      EXPLAIN: "Branch creation failed, cannot proceed with PR"
      EXIT workflow

  IF user declines branch creation:
    ASK: "Continue with PR from mainline branch anyway? (This is not recommended as it bypasses review workflow)"
    WAIT for explicit confirmation

    IF user confirms:
      INFORM: "Proceeding with PR from mainline (not recommended)"
      PROCEED to Phase 3

    IF user declines:
      STOP immediately
      EXPLAIN: "Cannot create PR without feature branch"
      EXIT workflow

Phase 2 complete. Continue to Phase 3.

---

## Phase 3: Detect Repository Type (Fork vs Origin)

**Objective**: Determine if working in fork or origin repository.

**THINKING CHECKPOINT (RECOMMENDED)**

Tool: `mcp__sequential-thinking__sequentialthinking`
Purpose: Achieve 95%+ confidence in repository structure understanding
Permission: Auto-approved (sequential-thinking MCP tool)

Think through systematically:
1. Analyze remote configuration (origin vs upstream)
2. Understand fork vs origin implications for PR
3. Determine correct PR target repository (where PR should be created)
4. Identify correct head reference format (fork-owner:branch vs just branch)
5. Validate understanding of PR parameters

**Step 1: Get current branch**

Tool: `mcp__git__git_branch`
Parameters:
- `repo_path`: Current working directory absolute path
- `branch_type`: "local"
Permission: Auto-approved (read-only MCP tool)
Expected output: List of local branches with current branch indicated
Capture: Current branch name (the branch marked as current)

**Step 2: Check for upstream remote**

Command: `git remote get-url upstream`
Permission: Matches `Bash(git remote get-url:*)` in allowed-tools
Purpose: Detect fork scenario by checking for upstream remote
Expected output: URL of upstream remote (if exists)
Expected error: Exit code 128 or 2 if upstream doesn't exist

**Step 3: Check exit code**

IF exit code is 0:
  Upstream exists (FORK scenario)
  Set is_fork = true
  Capture upstream URL

IF exit code is non-zero:
  No upstream (ORIGIN scenario)
  Set is_fork = false

Phase 3 complete. Continue to Phase 4.

---

## Phase 4: Parse Remote URLs

**Objective**: Extract owner and repository names from remote URLs.

**Step 1: Get remote URLs based on repository type**

IF is_fork = true (upstream exists):
  Command: `git remote get-url upstream`
  Permission: Matches `Bash(git remote get-url:*)` in allowed-tools
  Expected output: Upstream URL
  Capture: Upstream URL

  Command: `git remote get-url origin`
  Permission: Matches `Bash(git remote get-url:*)` in allowed-tools
  Expected output: Origin URL
  Capture: Origin URL

IF is_fork = false (origin only):
  Command: `git remote get-url origin`
  Permission: Matches `Bash(git remote get-url:*)` in allowed-tools
  Expected output: Origin URL
  Capture: Origin URL

**Step 2: Parse URLs to extract owner and repository**

Handle both SSH and HTTPS URL formats:

**SSH format**: `git@github.com:owner/repo.git`
**HTTPS format**: `https://github.com/owner/repo.git`

**Parsing method using bash**:
```bash
echo "$URL" | sed 's/git@github.com://; s|https://github.com/||; s/.git$//'
```

This extracts `owner/repo` from either format.

Then split on `/` to get:
- owner (first part)
- repo (second part)

**Example parsing**:
- `git@github.com:kubernetes/kubernetes.git` → `kubernetes/kubernetes` → owner: `kubernetes`, repo: `kubernetes`
- `https://github.com/cblecker/claude-plugins.git` → `cblecker/claude-plugins` → owner: `cblecker`, repo: `claude-plugins`

**Step 3: Determine PR parameters**

IF is_fork = true:
  PR target owner: Upstream owner (from parsed upstream URL)
  PR target repo: Upstream repo (from parsed upstream URL)
  PR head: `<origin-owner>:<current-branch>` (fork:branch format required by GitHub API)
  Base: Upstream mainline branch (from Phase 2)

IF is_fork = false:
  PR target owner: Origin owner (from parsed origin URL)
  PR target repo: Origin repo (from parsed origin URL)
  PR head: `<current-branch>` (just branch name, no owner prefix)
  Base: Origin mainline branch (from Phase 2)

**Validation Gate: URLs Parsed Successfully**

IF owner and repo successfully extracted from URLs:
  PROCEED to Phase 5

IF cannot parse owner/repo from URLs:
  STOP immediately
  EXPLAIN: "Cannot parse repository information from remote URLs"
  SHOW: URLs that were attempted to parse
  SHOW: Parsing results or errors encountered
  PROPOSE: "Verify remote configuration with `git remote -v` or create PR manually via GitHub web interface"
  WAIT for user decision

Phase 4 complete. Continue to Phase 5.

---

## Phase 5: Determine PR Base Branch

**Objective**: Identify target branch for pull request.

**Step 1: Determine target branch from user request**

Analyze user's request for target branch specification:
- Look for phrases like: "create PR to <branch>", "base on <branch>", "merge into <branch>", "target <branch>"
- Common branch names: develop, staging, main, master, release, etc.

IF target branch mentioned in user request:
  Use specified branch as PR base
  Set user_specified = true

IF no target branch mentioned:
  Use mainline branch from Phase 2 as PR base
  Set user_specified = false

**Step 2: Store PR base**

PR_BASE = specified branch or mainline

Phase 5 complete. Continue to Phase 6.

---

## Phase 6: Generate PR Content

**Objective**: Create compelling PR title and description.

**THINKING CHECKPOINT**: Use `mcp__sequential-thinking__sequentialthinking` to:
- Review commits (`mcp__git__git_log`, max 50) and diff (`mcp__git__git_diff` vs `<base>...HEAD`)
- Analyze purpose, scope, key changes, breaking changes
- Draft title (<72 chars, imperative) and description
- Validate quality and completeness

**Steps**:
1. Check user request for explicit title/description; use if provided
2. If not provided:
   - Title: Use Conventional Commits format if `Glob` finds `.commitlintrc*` or `commitlint.config.*`
   - Description: Generate with sections (Summary, Changes, Motivation, Testing, Additional Notes)
3. Populate from commit/diff analysis

Continue to Phase 7.

---

## Phase 7: Push to Remote

**Objective**: Push current branch to remote.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Get branch: `mcp__git__git_branch` with `repo_path` (cwd), `branch_type: "local"`
2. Push: `git push -u origin <branch-name>` (sets upstream tracking)

**Validation Gate**: IF push fails:
- Explain: Auth, network, force needed, protected, or permission
- Propose solution and wait for retry approval

Continue to Phase 8.

---

## Phase 8: Create Pull Request

**Objective**: Create PR on GitHub using MCP.

**Plan Mode**: Auto-enforced read-only if active

**Steps**:
1. Prepare: owner, repo, head (from Phase 4), base (Phase 5), title/body (Phase 6)
2. Determine draft: Check user request for "draft", "WIP", "work in progress"
3. Create: `mcp__github__create_pull_request` with all parameters

**Error Handling**: IF failure:
- Use `mcp__sequential-thinking__sequentialthinking` to analyze
- Explain: Auth, permissions, invalid params, duplicate PR, rate limit, or network
- Propose solution and wait for retry approval

Continue to Phase 9.

---

## Phase 9: Return PR URL

**Objective**: Provide PR URL and confirm success.

**Steps**:
1. Extract from Phase 8: PR number, URL, state
2. Report: PR #, title, URL, status (Open/Draft), base, head
3. If draft: Note conversion to "Ready for review" available

Workflow complete.
