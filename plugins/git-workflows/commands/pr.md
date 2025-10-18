---
description: Pull request creation workflow with commit check, push, and GitHub PR creation
---

# Pull Request Creation Workflow

[Extended thinking: This workflow creates GitHub pull requests. Uses MCP tools for git/GitHub operations, bash only for operations without MCP equivalents (git remote get-url, git push). Fork vs origin detection determines PR head format. May invoke /commit if uncommitted changes exist.]

You are executing the **pull request creation workflow**. Follow this deterministic, phase-based procedure exactly. Do not deviate from the specified steps or validation gates.

## Tool Requirements (Highly Relevant)

This workflow uses MCP tools for git/GitHub operations to enable user-controlled IAM permissions. Bash is used only when no MCP equivalent exists.

## Workflow Configuration

**Optional Input:**
- `--draft`: Create as draft pull request
- `--title <text>`: Override PR title
- `--body <text>`: Override PR description
- `--base <branch>`: Target branch (default: mainline)

## Phase 1: Verify Committed Changes

**Objective**: Ensure all changes are committed before creating PR.

**Steps:**
1. Check status using `mcp__git__git_status` (repo_path: current working directory)

2. **Analyze status output**:
   - Check for uncommitted changes (modified, untracked files)

**Validation Gate: All Changes Committed**
```
IF uncommitted changes exist:
  WARN: "Uncommitted changes detected"
  PROPOSE: "Commit changes first using /commit workflow"
  ASK: "Would you like to invoke /commit now?"
  WAIT for user decision

  IF user approves:
    INVOKE: SlashCommand tool with "/commit"
    WAIT for /commit workflow to complete
    PROCEED to Phase 2 after successful commit
  ELSE:
    STOP: "Cannot create PR with uncommitted changes"
    EXIT workflow
ELSE:
  PROCEED to Phase 2
```

**Required Output (JSON):**
```json
{
  "phase": "verify-committed-changes",
  "status": "success",
  "data": {
    "has_uncommitted_changes": false,
    "commit_invoked": false,
    "all_committed": true
  },
  "next_phase": "detect-repository-type"
}
```

## Phase 2: Detect Repository Type (Fork vs Origin)

**Objective**: Determine if working in fork or origin repository.

**Thinking Checkpoint (RECOMMENDED):**
THINKING CHECKPOINT: Use `mcp__sequential-thinking` to:
1. Analyze remote configuration
2. Understand fork vs origin implications
3. Determine correct PR target repository
4. Identify correct head reference format
5. Ensure 95%+ confidence in repository structure

**Steps:**
1. **Get current branch using bash**:
   - `git branch --show-current`

2. **Check for upstream remote using bash**:
   - `git remote get-url upstream`
   - **IMPORTANT**: Use this EXACT command - Bash tool captures exit codes automatically
   - Exit code 0: upstream exists (FORK scenario)
   - Exit code 1: no upstream (ORIGIN scenario)

3. **Determine repository type**:
   - IF upstream exists: is_fork = true
   - ELSE: is_fork = false

**Required Output (JSON):**
```json
{
  "phase": "detect-repository-type",
  "status": "success",
  "data": {
    "is_fork": false,
    "has_upstream": false,
    "current_branch": "feat/add-metrics"
  },
  "next_phase": "parse-remote-urls"
}
```

[Extended thinking: Fork vs origin detection determines PR creation pattern. A fork scenario means: user forked upstream repo to their namespace, works in their fork, creates PR back to upstream. This requires PR head format "fork-owner:branch" and PR target is upstream repo. An origin scenario means: user has direct access to repo, works on branch in that repo, creates PR within same repo. This requires PR head format "branch" and PR target is origin repo. The presence of 'upstream' remote is the definitive signal - it only exists in fork workflows. Getting this wrong causes PR creation to fail with confusing errors about invalid head references.]

## Phase 3: Parse Remote URLs

**Objective**: Extract owner and repository names from remote URLs.

**Steps:**
1. **Get remote URLs using bash**:
   - **IMPORTANT**: Use these EXACT commands - Bash tool captures exit codes automatically
   - IF is_fork (upstream exists):
     - `git remote get-url upstream` → UPSTREAM_URL
     - `git remote get-url origin` → ORIGIN_URL
   - ELSE (origin only):
     - `git remote get-url origin` → ORIGIN_URL

2. **Parse URLs** (handle both SSH and HTTPS formats):
   - **SSH format**: `git@github.com:owner/repo.git`
   - **HTTPS format**: `https://github.com/owner/repo.git`

3. **Extract owner and repo**:
   - Remove `git@github.com:` or `https://github.com/`
   - Remove `.git` suffix
   - Split on `/` to get owner and repo

   **Example parsing logic**:
   ```bash
   # For SSH: git@github.com:kubernetes/kubernetes.git
   echo "$URL" | sed 's/git@github.com://; s/.git$//'  # Returns: kubernetes/kubernetes

   # For HTTPS: https://github.com/kubernetes/kubernetes.git
   echo "$URL" | sed 's|https://github.com/||; s/.git$//'  # Returns: kubernetes/kubernetes

   # Extract owner and repo
   OWNER_REPO=$(echo "$URL" | sed 's/git@github.com://; s|https://github.com/||; s/.git$//')
   OWNER=$(echo "$OWNER_REPO" | cut -d'/' -f1)
   REPO=$(echo "$OWNER_REPO" | cut -d'/' -f2)
   ```

4. **Determine PR parameters**:
   - **IF is_fork**:
     - PR target owner: Upstream owner
     - PR target repo: Upstream repo
     - PR head: `<origin-owner>:<branch>` (fork:branch format)
   - **ELSE** (origin only):
     - PR target owner: Origin owner
     - PR target repo: Origin repo
     - PR head: `<branch>` (just branch name)

**Validation Gate: URLs Parsed Successfully**
```
IF cannot parse owner/repo from URLs:
  STOP: "Cannot parse repository information from remote URLs"
  EXPLAIN: Show URLs that were attempted
  PROPOSE: Manual PR creation or check remote configuration
  WAIT for user decision
ELSE:
  PROCEED to Phase 4
```

**Required Output (JSON):**
```json
{
  "phase": "parse-remote-urls",
  "status": "success",
  "data": {
    "is_fork": false,
    "target_owner": "cblecker",
    "target_repo": "claude-plugins",
    "origin_owner": "cblecker",
    "pr_head": "feat/add-metrics",
    "upstream_url": null,
    "origin_url": "git@github.com:cblecker/claude-plugins.git"
  },
  "next_phase": "determine-pr-base"
}
```

[Extended thinking: URL parsing extracts owner and repo names from git remote URLs, handling both SSH (git@github.com:owner/repo.git) and HTTPS (https://github.com/owner/repo.git) formats. This parsing is critical because mcp__github__create_pull_request requires owner and repo as separate parameters. For forks, we parse BOTH upstream and origin URLs because we need upstream owner/repo for PR target and origin owner for PR head format. The parsing logic must handle .git suffix removal and different URL prefixes correctly - parsing errors here cause workflow to fail at PR creation with no clear recovery path.]

## Phase 4: Determine PR Base Branch

**Objective**: Identify target branch for pull request.

**Steps:**
1. **Check if `--base <branch>` flag was provided**:
   - IF provided: Use specified branch
   - ELSE: Use mainline

2. **Get mainline branch** (if needed) (§ git-ops.md Mainline Detection)

3. **Store PR base**:
   - PR_BASE = specified branch or mainline

**Required Output (JSON):**
```json
{
  "phase": "determine-pr-base",
  "status": "success",
  "data": {
    "pr_base": "main",
    "user_specified": false,
    "is_mainline": true
  },
  "next_phase": "generate-pr-content"
}
```

## Phase 5: Generate PR Content

**Objective**: Create compelling PR title and description.

**Thinking Checkpoint (CRITICAL):**
THINKING CHECKPOINT: Use `mcp__sequential-thinking` to:
1. Review all commits that will be included in PR
2. Analyze overall purpose and scope of changes
3. Identify key features, fixes, or improvements
4. Draft concise, informative title (<50 chars)
5. Create structured description with context
6. Ensure 95%+ confidence in content quality

**Steps:**
1. **Get commit history using MCP**:
   - Use `mcp__git__git_log` to get commits on current branch
   - Use `mcp__git__git_diff` to see full changes vs base branch
   - Analyze: `git diff <base-branch>...HEAD`

2. **Analyze commits and changes**:
   - Identify primary purpose (feature, fix, refactor, etc.)
   - Extract key modifications
   - Understand overall impact

3. **Generate PR title**:
   - **IF `--title` flag provided**: Use provided title
   - **ELSE generate**:
     - Use imperative mood
     - Be specific and descriptive
     - Keep under 50 characters
     - Follow Conventional Commits format if applicable

4. **Generate PR description**:
   - **IF `--body` flag provided**: Use provided body
   - **ELSE generate structured description**:
     ```markdown
     ## Summary
     <1-3 bullet points describing the changes>

     ## Changes
     <Detailed list of modifications>

     ## Test Plan
     <How changes were tested or should be tested>

     ## Additional Notes
     <Any relevant context, breaking changes, etc.>
     ```

**Required Output (JSON):**
```json
{
  "phase": "generate-pr-content",
  "status": "success",
  "data": {
    "pr_title": "Add metrics export functionality",
    "pr_body": "## Summary\n- Implements metrics tracking...",
    "title_overridden": false,
    "body_overridden": false,
    "commit_count": 5
  },
  "next_phase": "push-to-remote"
}
```

[Extended thinking: PR content generation requires reviewing ALL commits that will be included, not just the latest commit. Use git log and git diff to see complete changes since base branch. The thinking checkpoint here is critical for quality - poorly generated PR titles/descriptions waste reviewer time and slow down merge velocity. Title should be concise (<50 chars) and follow project conventions (detect Conventional Commits if used). Description should provide context for reviewers: what changed, why it changed, how to test. Sequential-thinking helps achieve 95%+ confidence that generated content accurately represents the PR scope.]

## Phase 6: Push to Remote

**Objective**: Push current branch to remote repository.

**Validation Gate: Plan Mode Check**
```
IF in plan mode:
  STOP: "Cannot push to remote in plan mode"
  EXPLAIN: This workflow would push branch to remote:
    - Push branch [branch name] to origin
    - Create remote tracking relationship
  INFORM: "Exit plan mode to execute pull request workflow"
  EXIT workflow
ELSE:
  PROCEED to push
```

**Steps:**
1. **Determine push target**:
   - Always push to `origin` (your fork or your repository)
   - Branch: Current branch from Phase 2

2. **Push branch using bash** (no MCP equivalent):
   - `git push -u origin <branch-name>`
   - The `-u` flag sets up tracking relationship
   - First-time push will create remote branch

3. **Check push result**:
   - Exit code 0: Push successful
   - Exit code != 0: Push failed

**Validation Gate: Push Success**
```
IF push failed:
  STOP: "Failed to push branch to remote"
  THINK about root cause (consider using sequential-thinking)
  EXPLAIN error to user:
    - Common causes: Authentication, network, force push needed
  PROPOSE solution:
    - Check authentication (SSH key, token)
    - Verify network connectivity
    - Use --force-with-lease if branch was rebased
  ASK: "Would you like to retry with force push?"
  WAIT for user decision
ELSE:
  PROCEED to Phase 7
```

**Required Output (JSON):**
```json
{
  "phase": "push-to-remote",
  "status": "success",
  "data": {
    "pushed_to": "origin",
    "branch_name": "feat/add-metrics",
    "push_successful": true,
    "bash_command_used": true,
    "bash_reason": "git push has no MCP equivalent"
  },
  "next_phase": "create-pr"
}
```

## Phase 7: Create Pull Request

**Objective**: Create PR on GitHub using MCP tools.

**Validation Gate: Plan Mode Check**
```
IF in plan mode:
  STOP: "Cannot create pull request in plan mode"
  EXPLAIN: This workflow would create GitHub pull request:
    - Title: [pr_title from Phase 5]
    - Target: [target_owner]/[target_repo]
    - Head: [pr_head]
    - Base: [pr_base]
    - Draft: [is_draft]
  INFORM: "Exit plan mode to execute pull request creation"
  EXIT workflow
ELSE:
  PROCEED to PR creation
```

**Steps:**
1. **Prepare PR parameters** from previous phases:
   - owner: From Phase 3 (target_owner)
   - repo: From Phase 3 (target_repo)
   - head: From Phase 3 (pr_head)
   - base: From Phase 4 (pr_base)
   - title: From Phase 5 (pr_title)
   - body: From Phase 5 (pr_body)
   - draft: From configuration (--draft flag)

2. Create PR using `mcp__github__create_pull_request`:

   **MCP call structure**:
   ```
   mcp__github__create_pull_request:
     owner: <target-owner>
     repo: <target-repo>
     head: <pr-head>  # "owner:branch" for forks, "branch" for origin
     base: <pr-base>
     title: <pr-title>
     body: <pr-body>
     draft: <draft-flag>
   ```

**Error Handling:**
```
IF MCP tool fails:
  STOP immediately
  THINK about root cause (consider using sequential-thinking)
  EXPLAIN error clearly to user:
    - Authentication issues
    - Repository permissions
    - Invalid parameters
  PROPOSE solution with reasoning
  ASK for confirmation before retry
  EXPLAIN why any defaults were overridden

  **Fallback consideration**:
  IF error is unresolvable (not a usage error):
    WARN: "GitHub MCP tool failed, considering fallback"
    PROPOSE: "Use gh CLI as fallback?"
    WAIT for user approval
ELSE:
  PROCEED to Phase 8
```

**Required Output (JSON):**
```json
{
  "phase": "create-pr",
  "status": "success",
  "data": {
    "pr_created": true,
    "pr_number": 123,
    "pr_url": "https://github.com/owner/repo/pull/123",
    "is_draft": false,
    "mcp_tool_used": true,
    "gh_cli_fallback_used": false
  },
  "next_phase": "return-pr-url"
}
```

[Extended thinking: PR creation via mcp__github__create_pull_request is the culmination of all previous phases. All parameters (owner, repo, head, base, title, body) must be exactly correct or PR creation fails. The head parameter format differs between fork and origin: "owner:branch" for forks, "branch" for origin. Using bash gh CLI or attempting to construct GitHub API calls manually is a FAILURE - the workflow must use MCP tool. If MCP tool fails due to authentication or permissions, that's a legitimate error requiring user intervention, not a cue to fall back to bash. Only consider gh CLI fallback if MCP tool itself is broken, and only with explicit user approval.]

## Phase 8: Return PR URL

**Objective**: Provide PR URL to user and confirm success.

**Steps:**
1. **Extract PR URL** from Phase 7 response

2. **Report success to user**:
   ```
   Pull request created successfully

   PR #123: Add metrics export functionality
   URL: https://github.com/owner/repo/pull/123
   Status: Open (or Draft)

   Your pull request is ready for review!
   ```

**Required Output (JSON):**
```json
{
  "phase": "return-pr-url",
  "status": "complete",
  "data": {
    "pr_number": 123,
    "pr_url": "https://github.com/owner/repo/pull/123",
    "pr_state": "open",
    "workflow_complete": true
  },
  "workflow_complete": true
}
```

## Tool Reference

**MCP tools:** `mcp__git__git_status`, `mcp__git__git_log`, `mcp__git__git_diff`, `mcp__github__create_pull_request`

**Bash (no MCP equivalent):** `git branch --show-current`, `git ls-remote` (for mainline detection), `git remote get-url` (for upstream/origin detection), `git push`

## Success Criteria

- All phases completed successfully
- All validation gates passed
- All changes committed (invoke /commit if needed)
- Repository type detected correctly (fork vs origin)
- Remote URLs parsed successfully
- PR content generated with quality
Branch pushed to remote
- PR created using GitHub MCP tool
- PR URL returned to user
- Structured JSON state maintained throughout

## Failure Scenarios

- Uncommitted changes exist → Propose /commit invocation
- Cannot determine repository type → Analyze remotes, ask user
- Cannot parse remote URLs → Show URLs, propose manual PR
- Push fails → Check auth, network, propose force push if rebased
- GitHub MCP fails → Analyze error, propose solutions, consider fallback
- MCP tool unavailable for required operations → Stop and report error

## Special Notes

**Fork vs Origin PR Creation:**

**Fork Scenario** (upstream exists):
```
Target: upstream repository
Head: fork-owner:branch-name
Base: upstream mainline branch

Example:
owner: kubernetes
repo: kubernetes
head: cblecker:feat/add-metrics
base: master
```

**Origin Scenario** (no upstream):
```
Target: origin repository
Head: branch-name (no owner prefix)
Base: origin mainline branch

Example:
owner: cblecker
repo: claude-plugins
head: feat/add-metrics
base: main
```

**Draft Pull Requests:**
Use `--draft` flag to create draft PRs:
- Signals work in progress
- Prevents accidental merging
- Can convert to ready later

**PR Description Best Practices:**
- Clear summary of changes
- Context for reviewers
- Test instructions
- Breaking changes highlighted
- Links to related issues

**Integration with Other Workflows:**
- Can invoke `/commit` if uncommitted changes exist
- Should be preceded by `/rebase` if branch needs updating
- Can be invoked as final step in `/git-workflow`
