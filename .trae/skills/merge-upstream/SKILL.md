---
name: merge-upstream
description: "Merges upstream (original open-source project) changes into origin (fork project). Invoke when user wants to sync/merge upstream updates, pull latest from upstream, or resolve merge conflicts from upstream."
version: 1.0.0
author: "Xiaoruiguo"
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Git, gh-cli]
    related_skills: []
---

***

name: "merge-upstream"
description: "Merges upstream (original open-source project) changes into origin (fork project). Invoke when user wants to sync/merge upstream updates, pull latest from upstream, or resolve merge conflicts from upstream."
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Merge Upstream into Origin

This skill merges changes from the upstream (original open-source project) repository into the origin (fork/branch project) repository. It handles the full workflow: environment setup, cloning (if needed), fetching upstream changes, detecting conflicts, merging, and resolving issues.

## Configuration

This skill reads configuration from three sources in priority order:

1. **Skill invocation parameters** (highest priority) — user provides values directly
2. **Environment variables** — set in `.env` or system environment
3. **Default values** (lowest priority) — built-in defaults

### Parameters

| Parameter         | Env Variable            | Default                                     | Description                                           |
| ----------------- | ----------------------- | ------------------------------------------- | ----------------------------------------------------- |
| `WORK_DIR`        | `MERGE_WORK_DIR`        | Current directory                           | Working directory for the operation                   |
| `UPSTREAM_REPO`   | `MERGE_UPSTREAM_REPO`   | `https://github.com/casdoor/casdoor.git`    | Original open-source project repository URL           |
| `FORK_REPO`       | `MERGE_FORK_REPO`       | `https://github.com/xiaoruiguo/casdoor.git` | Fork/branch project repository URL                    |
| `FORK_BRANCH`     | `MERGE_FORK_BRANCH`     | `master`                                    | Branch in the fork project to merge into              |
| `UPSTREAM_BRANCH` | `MERGE_UPSTREAM_BRANCH` | `master`                                    | Branch in the upstream project to merge from          |
| `MERGE_STRATEGY`  | `MERGE_STRATEGY`        | `merge`                                     | Merge strategy: `merge`, `rebase`, or `squash`        |
| `GITHUB_TOKEN`    | `MERGE_GITHUB_TOKEN`    | *(empty)*                                   | GitHub Personal Access Token (PAT) for authentication |
| `GIT_AUTH_METHOD` | `MERGE_GIT_AUTH_METHOD` | `auto`                                      | Auth method: `auto`, `token`, `ssh`, `none`           |
| `RETRY_COUNT`     | `MERGE_RETRY_COUNT`     | `10`                                        | Max retry attempts for clone/fetch operations         |
| `VERBOSE`         | `MERGE_VERBOSE`         | `true`                                      | Verbose output: `true` or `false`                     |

### How to Collect Parameters

When the skill is invoked, follow this process:

1. Check if the user provided any parameters in their message (e.g., "merge upstream to my fork at /path/to/project")
2. If not fully specified, check environment variables
3. If still not fully specified, use defaults
4. If critical parameters are missing (WORK\_DIR, UPSTREAM\_REPO, FORK\_REPO), ask the user

**Example user inputs and parameter extraction:**

- "同步上游更新" → Use all defaults
- "merge upstream into /home/user/my-casdoor" → `WORK_DIR=/home/user/my-casdoor`
- "sync <https://github.com/org/repo> from <https://github.com/upstream/repo>" → `FORK_REPO=https://github.com/org/repo`, `UPSTREAM_REPO=https://github.com/upstream/repo`
- "在 D:\projects\casdoor 合并上游更新，上游是 <https://github.com/casdoor/casdoor.git>" → `WORK_DIR=D:\projects\casdoor`, `UPSTREAM_REPO=https://github.com/casdoor/casdoor.git`

## Verbose Output

When `VERBOSE=true`, the skill outputs detailed logs at every step. This is **enabled by default**.

### Output Format

Each log line follows this format:

```
[merge-upstream] [STEP-N] [LEVEL] message
```

- **STEP-N**: Step number (e.g., `STEP-0`, `STEP-1`)
- **LEVEL**: Log level — `INFO`, `WARN`, `ERROR`, `CMD`, `RESULT`

| Level    | Meaning                                     |
| -------- | ------------------------------------------- |
| `INFO`   | General progress information                |
| `WARN`   | Warning that may need attention             |
| `ERROR`  | Error that blocks progress                  |
| `CMD`    | Command being executed (show exact command) |
| `RESULT` | Output/result of a command                  |

### Verbose vs Quiet Mode

| Aspect           | `VERBOSE=true`                         | `VERBOSE=false`                   |
| ---------------- | -------------------------------------- | --------------------------------- |
| Step headers     | ✅ Show step number, title, description | ✅ Show step number and title only |
| Commands         | ✅ Show exact command before execution  | ❌ Hide commands                   |
| Command output   | ✅ Show full output                     | ❌ Show summary only               |
| Remote detection | ✅ Show URL matching details            | ❌ Show result only                |
| Diff analysis    | ✅ Show file-level details              | ❌ Show count only                 |
| Conflict details | ✅ Show conflict markers                | ✅ Always show (critical info)     |
| Timing           | ✅ Show elapsed time per step           | ❌ No timing                       |
| Configuration    | ✅ Show resolved config with source     | ✅ Show resolved config only       |

### Verbose Output Per Step

Each step below includes a `📋 Verbose Output` section that defines exactly what to log when `VERBOSE=true`.

## Execution Steps

### Step 0: Resolve Configuration

Determine all parameters from the three sources. Display the resolved configuration to the user.

📋 **Verbose Output**:

```
[merge-upstream] [STEP-0] [INFO] ===== Resolving Configuration =====
[merge-upstream] [STEP-0] [INFO] Parameter: WORK_DIR = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: UPSTREAM_REPO = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: FORK_REPO = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: FORK_BRANCH = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: UPSTREAM_BRANCH = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: MERGE_STRATEGY = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: GITHUB_TOKEN = <set/unset> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: GIT_AUTH_METHOD = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: RETRY_COUNT = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [INFO] Parameter: VERBOSE = <value> (source: <user/env/default>)
[merge-upstream] [STEP-0] [RESULT] Configuration resolved successfully
```

### Step 1: Environment Setup — Clone or Open

#### Authentication Configuration

Before cloning or fetching, configure Git authentication based on `GIT_AUTH_METHOD`:

| `GIT_AUTH_METHOD` | Behavior                                                                                                          |
| ----------------- | ----------------------------------------------------------------------------------------------------------------- |
| `auto` (default)  | Auto-detect: try SSH first (if `~/.ssh/id_*` exists), then token (if `GITHUB_TOKEN` is set), then unauthenticated |
| `token`           | Use `GITHUB_TOKEN` for HTTPS authentication                                                                       |
| `ssh`             | Use SSH key authentication (requires SSH key configured in `~/.ssh/`)                                             |
| `none`            | No authentication (public repos only)                                                                             |

**Token-based authentication** — Rewrite remote URLs to embed the token:

```bash
# For HTTPS URLs, rewrite to include token
# Format: https://<token>@github.com/<owner>/<repo>.git
git remote set-url <remote-name> https://${GITHUB_TOKEN}@github.com/<owner>/<repo>.git
```

**SSH-based authentication** — Rewrite remote URLs to use SSH:

```bash
# Convert HTTPS URL to SSH URL
# From: https://github.com/<owner>/<repo>.git
# To:   git@github.com:<owner>/<repo>.git
git remote set-url <remote-name> git@github.com:<owner>/<repo>.git
```

**Security**: NEVER log or display the `GITHUB_TOKEN` value. Always show `<set>` or `<unset>` instead.

Check if `WORK_DIR` contains a git repository belonging to the fork project.

📋 **Verbose Output**:

```
[merge-upstream] [STEP-1] [INFO] ===== Environment Setup =====
[merge-upstream] [STEP-1] [INFO] Checking WORK_DIR: <path>
[merge-upstream] [STEP-1] [INFO] Directory exists: <true/false>
[merge-upstream] [STEP-1] [INFO] Is git repo: <true/false>
[merge-upstream] [STEP-1] [INFO] Auth method: <auto/token/ssh/none>
[merge-upstream] [STEP-1] [INFO] GITHUB_TOKEN: <set/unset>
[merge-upstream] [STEP-1] [INFO] SSH key: <found/not found>
[merge-upstream] [STEP-1] [CMD] git remote -v
[merge-upstream] [STEP-1] [RESULT] <remote list output>
[merge-upstream] [STEP-1] [INFO] Remote URL matching:
[merge-upstream] [STEP-1] [INFO]   remote '<name>' URL '<url>' → matches FORK_REPO: <true/false>
[merge-upstream] [STEP-1] [INFO]   remote '<name>' URL '<url>' → matches UPSTREAM_REPO: <true/false>
[merge-upstream] [STEP-1] [INFO] Resolved: UPSTREAM_REMOTE = <name>, FORK_REMOTE = <name>
[merge-upstream] [STEP-1] [INFO] Applying authentication to remotes...
[merge-upstream] [STEP-1] [INFO]   <remote-name>: <URL rewritten for token/ssh/unchanged>
[merge-upstream] [STEP-1] [RESULT] Environment ready: <cloned new / opened existing>
```

If cloning:

```
[merge-upstream] [STEP-1] [INFO] WORK_DIR does not contain fork repo, cloning...
[merge-upstream] [STEP-1] [CMD] git clone <FORK_REPO> <WORK_DIR>
[merge-upstream] [STEP-1] [RESULT] Clone completed
[merge-upstream] [STEP-1] [CMD] git checkout <FORK_BRANCH>
[merge-upstream] [STEP-1] [CMD] git remote add upstream <UPSTREAM_REPO>
[merge-upstream] [STEP-1] [INFO] Added upstream remote: upstream → <UPSTREAM_REPO>
```

If adding missing remote:

```
[merge-upstream] [STEP-1] [INFO] No remote matches UPSTREAM_REPO, adding...
[merge-upstream] [STEP-1] [CMD] git remote add upstream <UPSTREAM_REPO>
[merge-upstream] [STEP-1] [INFO] Added upstream remote: upstream → <UPSTREAM_REPO>
```

#### Scenario A: Fork repo not found — Clone it

If the working directory does not exist or does not contain the fork repository:

```bash
# Determine clone URL based on auth method
if ($GIT_AUTH_METHOD -eq "ssh") {
    # Convert FORK_REPO HTTPS URL to SSH URL
    $CLONE_URL = $FORK_REPO -replace 'https://github.com/', 'git@github.com:'
} elseif ($GIT_AUTH_METHOD -eq "token" -and $GITHUB_TOKEN) {
    # Embed token in HTTPS URL
    $CLONE_URL = $FORK_REPO -replace 'https://', "https://${GITHUB_TOKEN}@"
} else {
    $CLONE_URL = $FORK_REPO
}

git clone $CLONE_URL $WORK_DIR
cd $WORK_DIR
git checkout $FORK_BRANCH

# Add upstream remote with auth if needed
if ($GIT_AUTH_METHOD -eq "ssh") {
    $UPSTREAM_URL = $UPSTREAM_REPO -replace 'https://github.com/', 'git@github.com:'
} elseif ($GIT_AUTH_METHOD -eq "token" -and $GITHUB_TOKEN) {
    $UPSTREAM_URL = $UPSTREAM_REPO -replace 'https://', "https://${GITHUB_TOKEN}@"
} else {
    $UPSTREAM_URL = $UPSTREAM_REPO
}

git remote add upstream $UPSTREAM_URL
```

After cloning, the remote configuration will be:

- `origin` → FORK\_REPO (standard git convention after clone)
- `upstream` → UPSTREAM\_REPO (added manually)

#### Scenario B: Fork repo exists — Verify and configure remotes

If the working directory already contains the fork repository:

```bash
cd $WORK_DIR
git remote -v
```

Check the existing remotes and identify which one points to the fork and which to the upstream:

1. If a remote points to `UPSTREAM_REPO` → record its name as `UPSTREAM_REMOTE`
2. If a remote points to `FORK_REPO` → record its name as `FORK_REMOTE`
3. If no remote points to `UPSTREAM_REPO`:
   ```bash
   # Determine URL with auth
   if ($GIT_AUTH_METHOD -eq "ssh") {
       $UPSTREAM_URL = $UPSTREAM_REPO -replace 'https://github.com/', 'git@github.com:'
   } elseif ($GIT_AUTH_METHOD -eq "token" -and $GITHUB_TOKEN) {
       $UPSTREAM_URL = $UPSTREAM_REPO -replace 'https://', "https://${GITHUB_TOKEN}@"
   } else {
       $UPSTREAM_URL = $UPSTREAM_REPO
   }
   git remote add upstream $UPSTREAM_URL
   ```
   Set `UPSTREAM_REMOTE=upstream`
4. If no remote points to `FORK_REPO`:
   ```bash
   if ($GIT_AUTH_METHOD -eq "ssh") {
       $FORK_URL = $FORK_REPO -replace 'https://github.com/', 'git@github.com:'
   } elseif ($GIT_AUTH_METHOD -eq "token" -and $GITHUB_TOKEN) {
       $FORK_URL = $FORK_REPO -replace 'https://', "https://${GITHUB_TOKEN}@"
   } else {
       $FORK_URL = $FORK_REPO
   }
   git remote add origin $FORK_URL
   ```
   Set `FORK_REMOTE=origin`
5. If remotes exist but use wrong auth method, rewrite their URLs:
   ```bash
   # Rewrite existing remote URL for token auth
   git remote set-url <remote-name> https://${GITHUB_TOKEN}@github.com/<owner>/<repo>.git
   # Or rewrite for SSH auth
   git remote set-url <remote-name> git@github.com:<owner>/<repo>.git
   ```

**Important**: The remote names may not follow the standard convention. Always identify remotes by their URL, not by name. For example, in this project:

- `origin` points to `https://github.com/casdoor/casdoor.git` (the UPSTREAM repo)
- `upstream` points to `https://github.com/xiaoruiguo/casdoor.git` (the FORK repo)

In this inverted case:

- `UPSTREAM_REMOTE = origin` (because its URL matches UPSTREAM\_REPO)
- `FORK_REMOTE = upstream` (because its URL matches FORK\_REPO)

### Step 2: Pre-flight Checks

Before starting the merge, verify the working tree is clean.

📋 **Verbose Output**:

```
[merge-upstream] [STEP-2] [INFO] ===== Pre-flight Checks =====
[merge-upstream] [STEP-2] [CMD] git status
[merge-upstream] [STEP-2] [RESULT] <status output>
[merge-upstream] [STEP-2] [CMD] git branch --show-current
[merge-upstream] [STEP-2] [RESULT] Current branch: <branch>
[merge-upstream] [STEP-2] [CMD] git diff --stat
[merge-upstream] [STEP-2] [RESULT] <diff stat or "clean">
[merge-upstream] [STEP-2] [CMD] git diff --cached --stat
[merge-upstream] [STEP-2] [RESULT] <cached diff stat or "clean">
[merge-upstream] [STEP-2] [INFO] Working tree: <clean / has uncommitted changes>
[merge-upstream] [STEP-2] [RESULT] Pre-flight check: <PASSED / NEEDS ATTENTION>
```

If there are uncommitted changes:

- Ask the user whether to stash them (`git stash`) or commit them first
- Do NOT proceed with uncommitted changes

Stash verbose output:

```
[merge-upstream] [STEP-2] [INFO] Stashing uncommitted changes...
[merge-upstream] [STEP-2] [CMD] git stash push -m "pre-merge-stash: local changes before upstream sync"
[merge-upstream] [STEP-2] [RESULT] Stashed successfully: <stash ref>
```

### Step 3: Fetch Latest Changes

📋 **Verbose Output**:

```
[merge-upstream] [STEP-3] [INFO] ===== Fetching Latest Changes =====
[merge-upstream] [STEP-3] [CMD] git fetch --all --prune
[merge-upstream] [STEP-3] [RESULT] <fetch output or error>
[merge-upstream] [STEP-3] [INFO] Fetch status: <SUCCESS / FAILED>
```

If fetch fails:

```
[merge-upstream] [STEP-3] [WARN] Fetch failed: <error message>
[merge-upstream] [STEP-3] [INFO] Diagnosing: checking authentication...
[merge-upstream] [STEP-3] [INFO] Current auth method: <auto/token/ssh/none>
[merge-upstream] [STEP-3] [INFO] GITHUB_TOKEN: <set/unset>
[merge-upstream] [STEP-3] [INFO] SSH key: <found/not found>
[merge-upstream] [STEP-3] [WARN] Authentication may be required. Options:
[merge-upstream] [STEP-3] [WARN]   1. Set GITHUB_TOKEN (env: MERGE_GITHUB_TOKEN)
[merge-upstream] [STEP-3] [WARN]   2. Set GIT_AUTH_METHOD=ssh and configure SSH key
[merge-upstream] [STEP-3] [WARN]   3. Configure network proxy
[merge-upstream] [STEP-3] [INFO] Attempting proxy: socks5://127.0.0.1:10808
[merge-upstream] [STEP-3] [CMD] git config http.proxy socks5://127.0.0.1:10808
[merge-upstream] [STEP-3] [CMD] git fetch --all --prune
[merge-upstream] [STEP-3] [RESULT] <fetch output or error>
```

If using local cache:

```
[merge-upstream] [STEP-3] [WARN] Using locally cached remote references (data may be stale)
[merge-upstream] [STEP-3] [INFO] Last known upstream ref: <ref>
[merge-upstream] [STEP-3] [INFO] Last known fork ref: <ref>
```

```bash
cd $WORK_DIR
git fetch --all --prune
```

If network is unavailable and user chooses to use local cache:

- Proceed with the locally cached remote references
- Warn the user that the analysis may be based on stale data

### Step 4: Analyze Differences

📋 **Verbose Output**:

```
[merge-upstream] [STEP-4] [INFO] ===== Analyzing Differences =====
[merge-upstream] [STEP-4] [CMD] git log --oneline <FORK_REMOTE>/<FORK_BRANCH>..<UPSTREAM_REMOTE>/<UPSTREAM_BRANCH>
[merge-upstream] [STEP-4] [RESULT] <commit list or "no new commits">
[merge-upstream] [STEP-4] [INFO] New commits from upstream: <count>
[merge-upstream] [STEP-4] [CMD] git diff --stat <FORK_REMOTE>/<FORK_BRANCH> <UPSTREAM_REMOTE>/<UPSTREAM_BRANCH>
[merge-upstream] [STEP-4] [RESULT] <diff stat summary>
[merge-upstream] [STEP-4] [CMD] git diff --name-status <FORK_REMOTE>/<FORK_BRANCH> <UPSTREAM_REMOTE>/<UPSTREAM_BRANCH>
[merge-upstream] [STEP-4] [RESULT] Modified: <count> | Added: <count> | Deleted: <count>
[merge-upstream] [STEP-4] [INFO] Modified files:
[merge-upstream] [STEP-4] [INFO]   M <file1>
[merge-upstream] [STEP-4] [INFO]   M <file2>
[merge-upstream] [STEP-4] [INFO] Added files:
[merge-upstream] [STEP-4] [INFO]   A <file3>
[merge-upstream] [STEP-4] [INFO] Deleted files:
[merge-upstream] [STEP-4] [INFO]   D <file4>
[merge-upstream] [STEP-4] [RESULT] Analysis complete: <N> new commits, <M> files changed
```

Show the user what changes will be merged:

```bash
cd $WORK_DIR
git log --oneline $FORK_REMOTE/$FORK_BRANCH..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH
git diff --stat $FORK_REMOTE/$FORK_BRANCH $UPSTREAM_REMOTE/$UPSTREAM_BRANCH
git diff --name-status $FORK_REMOTE/$FORK_BRANCH $UPSTREAM_REMOTE/$UPSTREAM_BRANCH
```

Present a summary to the user:

- Number of new commits from upstream
- Which files are affected (categorized: Modified / Added / Deleted)
- Any potential conflict areas (files modified in both repos)

If there are **zero new commits** from upstream:

- Inform the user that the fork is already up-to-date
- Ask whether to proceed or stop

### Step 5: Detect Potential Conflicts

📋 **Verbose Output**:

```
[merge-upstream] [STEP-5] [INFO] ===== Detecting Potential Conflicts =====
[merge-upstream] [STEP-5] [CMD] git merge-base <FORK_REMOTE>/<FORK_BRANCH> <UPSTREAM_REMOTE>/<UPSTREAM_BRANCH>
[merge-upstream] [STEP-5] [RESULT] Merge base: <commit hash>
[merge-upstream] [STEP-5] [CMD] git diff --name-only <merge-base> <FORK_REMOTE>/<FORK_BRANCH>
[merge-upstream] [STEP-5] [RESULT] Files modified in fork: <count>
[merge-upstream] [STEP-5] [CMD] git diff --name-only <merge-base> <UPSTREAM_REMOTE>/<UPSTREAM_BRANCH>
[merge-upstream] [STEP-5] [RESULT] Files modified in upstream: <count>
[merge-upstream] [STEP-5] [INFO] Files modified in BOTH branches (potential conflicts):
[merge-upstream] [STEP-5] [WARN]   ⚠️ <file1>
[merge-upstream] [STEP-5] [WARN]   ⚠️ <file2>
[merge-upstream] [STEP-5] [RESULT] Conflict risk: <NONE / LOW / MEDIUM / HIGH>
```

Before merging, identify files that may conflict:

```bash
cd $WORK_DIR
git merge-base $FORK_REMOTE/$FORK_BRANCH $UPSTREAM_REMOTE/$UPSTREAM_BRANCH
```

For each file modified in both branches, flag it as a potential conflict.

### Step 6: Perform the Merge

📋 **Verbose Output**:

```
[merge-upstream] [STEP-6] [INFO] ===== Performing Merge =====
[merge-upstream] [STEP-6] [INFO] Strategy: <merge/rebase/squash>
[merge-upstream] [STEP-6] [CMD] git checkout <FORK_BRANCH>
[merge-upstream] [STEP-6] [RESULT] Switched to branch '<FORK_BRANCH>'
[merge-upstream] [STEP-6] [CMD] git merge <UPSTREAM_REMOTE>/<UPSTREAM_BRANCH> --no-edit
[merge-upstream] [STEP-6] [RESULT] <merge output>
[merge-upstream] [STEP-6] [RESULT] Merge status: <SUCCESS / CONFLICTS>
```

Switch to the fork's target branch and merge:

```bash
cd $WORK_DIR
git checkout $FORK_BRANCH
```

Choose the merge strategy based on `MERGE_STRATEGY`:

#### Option: merge (default)

```bash
git merge $UPSTREAM_REMOTE/$UPSTREAM_BRANCH --no-edit
```

#### Option: rebase

```bash
git rebase $UPSTREAM_REMOTE/$UPSTREAM_BRANCH
```

#### Option: squash

```bash
git merge --squash $UPSTREAM_REMOTE/$UPSTREAM_BRANCH
git commit -m "Merge upstream changes from $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
```

### Step 7: Handle Merge Conflicts

If conflicts occur, this step always shows full details regardless of VERBOSE setting.

📋 **Verbose Output** (always shown — conflicts are critical):

```
[merge-upstream] [STEP-7] [WARN] ===== Merge Conflicts Detected =====
[merge-upstream] [STEP-7] [CMD] git diff --name-only --diff-filter=U
[merge-upstream] [STEP-7] [RESULT] Conflicted files: <count>
[merge-upstream] [STEP-7] [WARN]   ⚠️ <conflicted-file-1>
[merge-upstream] [STEP-7] [WARN]   ⚠️ <conflicted-file-2>
[merge-upstream] [STEP-7] [INFO] Showing conflict details for: <file>
[merge-upstream] [STEP-7] [CMD] git diff <conflicted-file>
[merge-upstream] [STEP-7] [RESULT] <conflict markers>
[merge-upstream] [STEP-7] [INFO] Resolution options:
[merge-upstream] [STEP-7] [INFO]   1. Accept upstream change (--theirs)
[merge-upstream] [STEP-7] [INFO]   2. Keep local change (--ours)
[merge-upstream] [STEP-7] [INFO]   3. Manual resolution
[merge-upstream] [STEP-7] [INFO] User chose: <option> for <file>
[merge-upstream] [STEP-7] [CMD] git checkout --<ours/theirs> <file>
[merge-upstream] [STEP-7] [RESULT] Resolved: <file>
[merge-upstream] [STEP-7] [CMD] git add .
[merge-upstream] [STEP-7] [CMD] git merge --continue
[merge-upstream] [STEP-7] [RESULT] All conflicts resolved, merge continued
```

1. List all conflicted files:
   ```bash
   git diff --name-only --diff-filter=U
   ```
2. For each conflicted file, show the conflict markers:
   ```bash
   git diff <conflicted-file>
   ```
3. For each conflict, present the options to the user:
   - **Accept upstream change** (take the original project's version): `git checkout --theirs <file>`
   - **Keep local change** (keep the fork's version): `git checkout --ours <file>`
   - **Manual resolution**: Open the file for the user to edit
4. After resolving all conflicts:
   ```bash
   git add .
   git merge --continue
   ```

### Step 8: Verify the Merge

📋 **Verbose Output**:

```
[merge-upstream] [STEP-8] [INFO] ===== Verifying Merge =====
[merge-upstream] [STEP-8] [CMD] git log --oneline -5
[merge-upstream] [STEP-8] [RESULT] <recent commits>
[merge-upstream] [STEP-8] [INFO] Checking for Makefile...
[merge-upstream] [STEP-8] [CMD] make backend
[merge-upstream] [STEP-8] [RESULT] <build output summary>
[merge-upstream] [STEP-8] [CMD] make ut
[merge-upstream] [STEP-8] [RESULT] <test output summary>
[merge-upstream] [STEP-8] [CMD] git status
[merge-upstream] [STEP-8] [RESULT] <status output>
[merge-upstream] [STEP-8] [RESULT] Verification: <PASSED / FAILED>
```

After successful merge:

```bash
cd $WORK_DIR
git log --oneline -5

if (Test-Path "$WORK_DIR/Makefile") {
    make backend
    make ut
}

git status
```

### Step 9: Push Changes

📋 **Verbose Output**:

```
[merge-upstream] [STEP-9] [INFO] ===== Push Changes =====
[merge-upstream] [STEP-9] [INFO] Awaiting user confirmation to push...
[merge-upstream] [STEP-9] [INFO] User confirmed: <yes/no>
[merge-upstream] [STEP-9] [CMD] git push <FORK_REMOTE> <FORK_BRANCH>
[merge-upstream] [STEP-9] [RESULT] <push output>
[merge-upstream] [STEP-9] [RESULT] Push: <SUCCESS / SKIPPED / FAILED>
```

```bash
cd $WORK_DIR
git push $FORK_REMOTE $FORK_BRANCH
```

**Important**: Only push after the user explicitly confirms. Never push automatically.

### Step 10: Restore Stashed Changes (if applicable)

📋 **Verbose Output**:

```
[merge-upstream] [STEP-10] [INFO] ===== Restoring Stashed Changes =====
[merge-upstream] [STEP-10] [INFO] Stash exists: <true/false>
[merge-upstream] [STEP-10] [CMD] git stash pop
[merge-upstream] [STEP-10] [RESULT] <stash pop output>
[merge-upstream] [STEP-10] [RESULT] Stash restored: <SUCCESS / NO STASH>
```

If changes were stashed in Step 2:

```bash
cd $WORK_DIR
git stash pop
```

### Final Summary

📋 **Verbose Output** (always shown):

```
[merge-upstream] [DONE] ===== Merge Complete =====
[merge-upstream] [DONE] Work Dir:       <WORK_DIR>
[merge-upstream] [DONE] Upstream:       <UPSTREAM_REPO> (<UPSTREAM_BRANCH>)
[merge-upstream] [DONE] Fork:           <FORK_REPO> (<FORK_BRANCH>)
[merge-upstream] [DONE] Strategy:       <MERGE_STRATEGY>
[merge-upstream] [DONE] Auth Method:    <auto/token/ssh/none>
[merge-upstream] [DONE] New Commits:    <count>
[merge-upstream] [DONE] Conflicts:      <count> (all resolved)
[merge-upstream] [DONE] Build:          <PASSED / SKIPPED / FAILED>
[merge-upstream] [DONE] Tests:          <PASSED / SKIPPED / FAILED>
[merge-upstream] [DONE] Pushed:         <YES / NO>
[merge-upstream] [DONE] Stash Restored: <YES / NO>
[merge-upstream] [DONE] Total Time:     <duration>
```

## Conflict Resolution Guidelines

When resolving conflicts, follow these priorities:

1. **Configuration files** (e.g., `conf/app.conf`, `.env`, `docker-compose.yml`): Prefer the fork's version (keep local customizations), but review upstream changes for important updates
2. **Business logic code** (e.g., `controllers/`, `object/`): Prefer upstream changes (get latest bug fixes and features), then re-apply fork-specific modifications
3. **Frontend code** (e.g., `web/src/`): Prefer upstream changes, then re-apply custom themes/configurations
4. **Dependencies** (e.g., `go.mod`, `package.json`): Prefer upstream changes (get latest security patches)
5. **Documentation** (e.g., `README.md`, `*.md`): Merge both, keeping fork-specific additions

## Special Handling for This Project (Casdoor)

### Files That May Have Fork-Specific Customizations

The following files are likely customized in the fork and require careful conflict resolution:

- `conf/app.conf` — Backend configuration (database, ports, origins)
- `docker-compose.yml` — Docker deployment configuration
- `web/src/Setting.js` — Frontend API URL configuration
- `web/.env` — Frontend environment variables
- `traefik_casdoor_config.yaml` — Traefik gateway configuration
- `.env` — Root environment variables
- `Dockerfile` — May have custom build steps

### Files That Should Always Accept Upstream Changes

- `go.mod` / `go.sum` — Dependency updates
- `controllers/*.go` — API logic updates
- `object/*.go` — Business logic updates
- `routers/router.go` — Route definitions
- `authz/authz.go` — Authorization policy updates
- `web/src/backend/*.js` — Frontend API calls
- `web/src/locales/*/data.json` — Translation updates
- `i18n/locales/*/data.json` — Backend translation updates

## Error Recovery

If something goes wrong during the merge:

```bash
git merge --abort
git rebase --abort
git reset --hard <fork-branch-before-merge>
git checkout $FORK_BRANCH
git stash pop
```

📋 **Verbose Output** for error recovery:

```
[merge-upstream] [ERROR] Merge failed: <error message>
[merge-upstream] [ERROR] Initiating recovery...
[merge-upstream] [ERROR] [CMD] git merge --abort
[merge-upstream] [ERROR] [RESULT] Merge aborted, working tree restored
[merge-upstream] [ERROR] Recovery complete. You can retry or investigate manually.
```

## Quick Reference

| Action              | Command                                                                          |
| ------------------- | -------------------------------------------------------------------------------- |
| Clone fork          | `git clone $FORK_REPO $WORK_DIR`                                                 |
| Add upstream remote | `git remote add upstream $UPSTREAM_REPO`                                         |
| Check remotes       | `git remote -v`                                                                  |
| Fetch all           | `git fetch --all`                                                                |
| View diff           | `git diff $FORK_REMOTE/$FORK_BRANCH $UPSTREAM_REMOTE/$UPSTREAM_BRANCH`           |
| View commits        | `git log --oneline $FORK_REMOTE/$FORK_BRANCH..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH` |
| Merge               | `git merge $UPSTREAM_REMOTE/$UPSTREAM_BRANCH`                                    |
| Abort merge         | `git merge --abort`                                                              |
| Push to fork        | `git push $FORK_REMOTE $FORK_BRANCH`                                             |
| Stash changes       | `git stash`                                                                      |
| Pop stash           | `git stash pop`                                                                  |

