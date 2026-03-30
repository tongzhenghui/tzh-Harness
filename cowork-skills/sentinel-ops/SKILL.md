---
name: sentinel-ops
description: "Consistency Sentinel CI/CD operations: deploy, debug, configure, and manage the multi-repo Sentinel system across huanlongAI org. Use this skill whenever the user mentions sentinel, CI checks, precheck scripts, reusable workflows, multi-repo deployment, sentinel config profiles, LLM review layer, or any operational task related to the Consistency Sentinel system. Also trigger when discussing GitHub Actions failures in sentinel-related workflows, cross-repo workflow_call patterns, or batch deployment to multiple repos."
---

# Sentinel Ops

Operational knowledge base for the **Consistency Sentinel** system -- a multi-repo CI/CD governance framework deployed across the huanlongAI GitHub organization.

## Architecture Overview

The Sentinel system uses a **hub-and-spoke reusable workflow** pattern:

- **Hub**: `huanlongAI/sentinel-shared` (PUBLIC repo -- must stay public, see constraints below)
  - `.github/workflows/consistency-sentinel.yml` -- the reusable workflow (callee)
  - `scripts/` -- D-1~D-6 precheck scripts + LLM review + aggregation + escalation
  - `prompts/` -- system prompts for LLM review layer

- **Spokes**: Each repo in huanlongAI org has:
  - `.github/workflows/consistency-sentinel.yml` -- ~25-line caller workflow
  - `.sentinel/config.yaml` -- repo-level configuration

## Critical Constraints (Hard-Won Lessons)

### 1. Permissions MUST be in the caller, NEVER in the callee

GitHub Actions reusable workflows (`workflow_call`) that declare a `permissions` block at ANY level (top-level or job-level) cause a **startup_failure** -- the workflow fails in 0 seconds with 0 jobs run, and the error is invisible in the UI.

**Rule**: The caller workflow declares `permissions`. The reusable workflow in sentinel-shared declares NONE.

```yaml
# CALLER (in each repo) -- declares permissions
permissions:
  contents: read
  pull-requests: write
  issues: write
jobs:
  sentinel:
    uses: huanlongAI/sentinel-shared/.github/workflows/consistency-sentinel.yml@main
```

```yaml
# CALLEE (sentinel-shared) -- NO permissions block anywhere
on:
  workflow_call:
    inputs: ...
    secrets: ...
jobs:
  run-sentinel:
    runs-on: ubuntu-latest
    steps: ...
```

### 2. sentinel-shared MUST be public

`GITHUB_TOKEN` is scoped to the calling repository only. When a caller workflow references `uses: huanlongAI/sentinel-shared/...@main`, GitHub needs to fetch that workflow. If sentinel-shared is private, the checkout fails silently. This is acceptable because sentinel-shared contains only CI scripts, no secrets.

### 3. Repo name cannot start with a dot

GitHub cannot resolve workflow references like `huanlongAI/.sentinel-shared/.github/workflows/...`. The leading dot causes a parse failure in the `uses:` directive.

### 4. Org-level ANTHROPIC_API_KEY required

Each repo's caller workflow passes `secrets: ANTHROPIC_API_KEY`. This must be configured as an org-level secret in huanlongAI, or per-repo for selective enablement.

### 5. ALL workflow YAML must be pure ASCII (confirmed x3)

GitHub Actions trigger indexer SILENTLY FAILS on non-ASCII characters. Three confirmed instances:
- Session 18: dashboard.yml + matrix-updater.yml (em-dash in comments)
- Session 21: ruling-merge-hook.yml (em-dash in comments)

Symptoms: workflow name shows as raw filename, `workflow_dispatch` trigger never registered, only `push` events fire.

**Mandatory checks before committing any workflow file**:
```bash
file <workflow.yml>  # Must show "ASCII text", NOT "UTF-8 Unicode text"
```

Additionally: workflow IDs are cached per filename. Deleting and re-creating with the same name inherits stale trigger metadata. Only truly NEW filenames get fresh workflow IDs.

### 6. jq `//` alternative operator boolean trap (Session 22)

`jq '.passed // true'` returns `true` when `.passed` is `false` because `//` is the alternative operator which treats both `null` and `false` as falsy.

**WRONG**:
```bash
passed=$(jq -r '.passed // true' "$result_file")
```

**CORRECT**:
```bash
passed=$(jq -r 'if .passed == null then "true" else (.passed | tostring) end' "$result_file" 2>/dev/null || echo "true")
```

This bug caused governance repo D-1 failure to show P1 instead of P0.

## Caller Workflow Template

Standard ~25-line template deployed to all repos:

```yaml
name: Consistency Sentinel
on:
  pull_request:
    types: [opened, synchronize, reopened]
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      skip_llm:
        description: 'Skip LLM review layer'
        required: false
        default: 'false'
        type: boolean
permissions:
  contents: read
  pull-requests: write
  issues: write
jobs:
  sentinel:
    uses: huanlongAI/sentinel-shared/.github/workflows/consistency-sentinel.yml@main
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
    with:
      skip_llm: ${{ github.event.inputs.skip_llm || 'false' }}
```

## Config Profiles

Four profiles, mapped by repo type:

### governance
Repos: tzh-Harness, super-founder
```yaml
sentinel_version: "1.0"
repo_type: governance
enabled_dimensions: [software_engineering, governance_process, strategic_alignment]
governance_files: []  # populate per-repo
cascade_map: {}       # populate per-repo
llm:
  model: "claude-sonnet-4-6"
  max_output_tokens: 4096
  confidence_threshold: 0.7
  checks: ["GPC-003", "SAC-004"]
```

### infra
Repos: tzh-agent-configs, tzh-evals, tzh-dotfiles, tzh-marketing, tzh-legal, hl-dispatch
```yaml
sentinel_version: "1.0"
repo_type: infra
enabled_dimensions: [software_engineering]
llm:
  model: "claude-sonnet-4-6"
  checks: []
```

### app
Repos: tzhOS-App, hl-factory, hl-console-native, hl-platform
```yaml
sentinel_version: "1.0"
repo_type: app
enabled_dimensions: [software_engineering, governance_process, design_brand, strategic_alignment]
brand_token_file_patterns: ["*.swift", "*.css", "*.scss", "*.tsx", "*.jsx"]
llm:
  checks: ["GPC-003", "DBC-002", "SAC-004"]
```

### library
Repos: guanghe, hl-framework, hl-contracts
```yaml
sentinel_version: "1.0"
repo_type: library
enabled_dimensions: [software_engineering, governance_process]
llm:
  checks: ["GPC-003"]
```

## Precheck Scripts (D-1 ~ D-6)

All scripts live in `sentinel-shared/scripts/` and share common patterns.

### Common Script Patterns

**1. Pipefail-safe grep**: Every script uses `set -euo pipefail`. Any `grep` that might return 0 matches MUST be wrapped:
```bash
# WRONG -- kills script if no match
grep "^\s*-" "$file" | sed ...

# CORRECT
{ grep "^\s*-" "$file" || true; } | sed ...
```

**2. Git diff context detection**: GitHub Actions push events have no staged files. Scripts must detect context:
```bash
if [ -n "${BASE_REF:-}" ]; then
  CHANGED_FILES=$(git diff --name-only "origin/${BASE_REF}...HEAD" 2>/dev/null || echo "")
elif git rev-parse HEAD~1 >/dev/null 2>&1; then
  CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
else
  CHANGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")
fi
```

**3. Empty array guard with `set -u`**: Accessing `${ARRAY[@]}` on an empty array triggers unbound variable error:
```bash
# WRONG
printf '%s\n' "${ISSUES[@]}" | jq -R . | jq -s .

# CORRECT
if [ ${#ISSUES[@]} -gt 0 ]; then printf '%s\n' "${ISSUES[@]}"; fi | jq -R . | jq -s .
```

**4. YAML parsing without yq**: Custom bash functions for reading YAML config:
```bash
yaml_get() {
  local file="$1" key="$2" default="${3:-}"
  local val=$(grep -E "^\s*${key}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:\s*//' | sed 's/\s*#.*//' | tr -d '"' | tr -d "'")
  echo "${val:-$default}"
}

yaml_get_array() {
  local file="$1" key="$2"
  sed -n "/^\s*${key}:/,/^\s*[a-z]/p" "$file" 2>/dev/null | { grep "^\s*-" || true; } | sed 's/^\s*-\s*//' | tr -d '"' | tr -d "'"
}

yaml_get_nested() {
  local file="$1" parent="$2" child="$3" default="${4:-}"
  local val=$(sed -n "/^\s*${parent}:/,/^\s*[a-z_]*:/p" "$file" 2>/dev/null | grep -E "^\s+${child}:" | head -1 | sed 's/^[^:]*:\s*//' | sed 's/\s*#.*//' | tr -d '"' | tr -d "'")
  echo "${val:-$default}"
}

yaml_get_nested_array() {
  local file="$1" parent="$2" child="$3"
  sed -n "/^\s*${parent}:/,/^\s*[a-z_]*:/p" "$file" 2>/dev/null | sed -n "/^\s*${child}:/,/^\s*[a-z]/p" | { grep "^\s*-" || true; } | sed 's/^\s*-\s*//' | tr -d '"' | tr -d "'"
}

yaml_get_kv_pairs() {
  local file="$1" key="$2"
  sed -n "/^\s*${key}:/,/^\s*[a-z_]*:/p" "$file" 2>/dev/null | grep -E "^\s+[^ :]+:\s+" | sed 's/^\s*//' | tr -d '"' | tr -d "'"
}
```

### Script Inventory

| Script | Check ID | Function | Key Config |
|--------|----------|----------|------------|
| precheck-changelog.sh | D-1 | Governance file changes require CHANGELOG update | `governance_files`, `changelog_file` |
| precheck-terminology.sh | D-2 | Scan for forbidden terms (TODO, FIXME, HACK) | `forbidden_terms` |
| precheck-cascade.sh | D-3 | Source file change -> target file must exist | `cascade_map` |
| precheck-directory.sh | D-4 | Required directory structure compliance | `directory_spec` |
| precheck-capability-source.sh | D-5 | CAPABILITY-SOURCE annotations in arch docs | `capability_source_patterns` |
| precheck-brand-token.sh | D-6 | No hardcoded colors in UI files | `brand_token_file_patterns`, `brand_token_allowlist` |

### Reusable Workflow Step Pattern

Each check in the reusable workflow uses `if: always()` for independent execution:
```yaml
- name: "D-4: Directory compliance"
  if: always() && hashFiles('sentinel-shared/scripts/precheck-directory.sh') != ''
  run: bash sentinel-shared/scripts/precheck-directory.sh
```
The `hashFiles` guard allows graceful skip when a script doesn't exist yet.

## LLM Review Layer

### Configuration
```yaml
llm:
  model: "claude-sonnet-4-6"        # or claude-opus-4-6
  max_context_tokens: 30000
  max_output_tokens: 4096
  confidence_threshold: 0.7
  checks:
    - "GPC-003"   # Governance Process Compliance
    - "DBC-002"   # Design/Brand Compliance
    - "SAC-004"   # Strategic Alignment Compliance
```

### Key Design Decisions

- **Graceful degradation**: API failure, empty response, or JSON parse failure -> verdict `ESCALATE`, exit 0 (non-blocking). The LLM layer should never break the CI pipeline.
- **Diff truncation**: 80K chars default, 150K for opus models. Prevents API token overflow.
- **Anchor files**: Config key-value pairs under `anchor_files:` provide context documents to the LLM.
- **System prompt**: Loaded from `prompts/` directory (local repo first, then sentinel-shared fallback).

### Expected LLM Output Format
```json
{
  "verdict": "PASS|WARN|FAIL|ESCALATE",
  "checks": {
    "GPC-003": {"verdict": "PASS", "confidence": 0.85, "reason": "..."},
    "SAC-004": {"verdict": "WARN", "confidence": 0.6, "reason": "..."}
  },
  "summary": "Brief overall assessment"
}
```

## Batch Deployment

### MCP Push Limitation
GitHub MCP `push_files` returns 403 for `.github/workflows/` files due to GitHub App token restrictions. Workflow files require direct `git push` with appropriate auth.

### Batch Deploy Procedure

For deploying to all repos (used in WP-4):

1. Clone each repo shallow (`--depth 1`)
2. Create `.github/workflows/consistency-sentinel.yml` from caller template
3. Create `.sentinel/config.yaml` from profile template (skip if already exists for governance repos with custom config)
4. `git add` + `git commit` + `git push origin main`
5. Track success/failure counts

Write-Owner repos (can direct push): tzhOS, tzh-Harness, super-founder, tzh-agent-configs, tzh-evals, tzh-dotfiles, guanghe, tzhOS-App
Non-Owner repos: require cross-domain write protocol (MULTI-NODE-COWORK-SPEC 3.4)

## Debugging Playbook

### Workflow shows "startup_failure" (0s, 0 jobs)
1. Check for `permissions` block in the reusable workflow -> remove it
2. Check `uses:` path syntax -- no leading dots in repo names
3. Check sentinel-shared visibility -- must be public

### Script exits immediately with code 1
1. Check `grep` pipelines -- wrap with `{ grep ... || true; }`
2. Check empty array access -- add `${#ISSUES[@]} -gt 0` guard
3. Check `yaml_get_array` -- ensure `|| true` in grep within function

### D-1 false positive on non-governance commits
1. Verify `governance_files` list in `.sentinel/config.yaml`
2. Ensure git diff mode matches event context (PR vs push)

### LLM says "No checks enabled"
1. Check nested YAML parsing -- `llm.checks` requires `yaml_get_nested_array`, not `yaml_get_array`
2. Verify `llm:` section indentation in config

### Checkout of sentinel-shared fails
1. Verify `huanlongAI/sentinel-shared` is PUBLIC
2. Check `actions/checkout` step uses correct path and ref

### Severity shows P1 instead of P0 for governance D-1 failure (Session 22)
1. Check jq boolean extraction -- `//` operator treats `false` as falsy
2. Must use explicit null check: `if .passed == null then "true" else (.passed | tostring) end`
3. Never use `jq '.field // default'` for boolean fields

## Phase 2 Workflows

### Cross-Repo Cascade Verification (cascade-verify.yml)

Deployed in sentinel-shared. When hub scripts/workflow/matrix/profiles/prompts change, auto-dispatches sentinel-cascade events to all 16 downstream repos, waits 120s, then collects pass/fail results. Failures auto-create an issue with cascade-failure label.

- Trigger: push to scripts/**/workflow/matrix/profiles/prompts OR workflow_dispatch
- Fan-out: curl POST /repos/{repo}/dispatches with event_type=sentinel-cascade
- Collect: 120s wait, then query /actions/runs?event=repository_dispatch
- Token: CASCADE_TOKEN (fine-grained PAT, 17 repos)

### Matrix Auto-Update (matrix-updater.yml)

Triggered via workflow_dispatch from tzhOS ruling-hook.yml when a ruling PR merges:

```
ruling PR merge (tzhOS) -> ruling-hook extracts matrix_change
  -> workflow_dispatch to sentinel-shared/matrix-updater.yml
  -> Claude API drafts updated sentinel-matrix.yaml
  -> Creates PR (or fallback issue if LLM fails)
```

Inputs: ruling_id (string), matrix_change_b64 (base64-encoded), source_pr (URL)
Secrets: ANTHROPIC_API_KEY for LLM draft, CASCADE_TOKEN for PR/issue creation
Important: Uses CASCADE_TOKEN (not GITHUB_TOKEN) for PR and issue creation on public repos.

### Sentinel Dashboard v2 (dashboard.yml)

Aggregates sentinel health across all 16 downstream repos:
- Schedule: daily 08:00 UTC cron + manual workflow_dispatch
- Output: STEP_SUMMARY with markdown health table
- Alerting: Smart alerting -- only creates `dashboard-alert` issue on NEW failures (not persistent)
- Trend detection: Compares current vs last `dashboard-report` issue to identify NEW/RECOVERED/PERSISTENT
- Stale nudge: Repos with no run >72h get auto-dispatched (skip_llm=true)
- Historical archival: Each run saved as auto-closed `dashboard-report` issue
- Token: CASCADE_TOKEN for cross-repo API queries

### Ruling Hook (tzhOS: ruling-hook.yml)

**NOTE**: Originally `ruling-merge-hook.yml`, renamed to `ruling-hook.yml` (commit ed2b302) due to Unicode trigger indexer bug (3rd confirmed instance). The old filename is permanently contaminated in GitHub's workflow ID cache.

Detects merged PRs with `gov(ruling)` in title. Extracts `matrix_change` from PR body, base64-encodes it, dispatches to sentinel-shared matrix-updater.yml.

- Trigger: `pull_request: types: [closed], branches: [main]`
- Job condition: `github.event.pull_request.merged == true && contains(github.event.pull_request.title, 'gov(ruling)')`
- Dispatch URL: `https://api.github.com/repos/huanlongAI/sentinel-shared/actions/workflows/matrix-updater.yml/dispatches`
- Token: CASCADE_TOKEN for cross-repo dispatch
- Dispatch validation: logs HTTP response code, expects 204

#### Matrix Change Extraction Pattern (v2 -- commit 91be5bf)

The extraction must handle Markdown code fences in PR body. The original `sed` range `/[Mm]atrix.[Cc]hange/,/^##\|^---\|^$/p` fails because it stops at empty lines between the `### Matrix Change` header and the code fence content.

**Correct pattern** (grep-chain filtering):
```bash
MATRIX_CHANGE=$(echo "$PR_BODY" \
  | sed -n '/[Mm]atrix.[Cc]hange/,/^### /p' \
  | grep -v '^### ' \
  | grep -v '^```' \
  | grep -v '^[[:space:]]*$' \
  | head -20)
```

Key points:
- `sed` range stops at next `### ` header (not at empty line or `---`)
- grep-chain removes: headers, code fence markers, blank lines
- `head -20` prevents oversized payloads
- Result is then base64-encoded for dispatch

## Phase 4: Monitoring Escalation + Auto-Remediation (Session 22)

### Escalation Handler v2 (escalate.sh)

Location: `sentinel-shared/scripts/escalate.sh` (commit a0ed69f)

Full severity grading + structured JSON output for downstream consumers (Super-Founder FeishuCardBuilder).

#### P0-P3 Severity Model

| Level | Name | Condition | Exit Code |
|-------|------|-----------|----------|
| P0 | Critical | All D-checks fail OR governance repo D-1/LLM:GPC-003/LLM:SAC-004 fail | 1 (block) |
| P1 | Warning | Multiple D-checks fail OR any repo LLM FAIL | 1 (block) |
| P2 | Info | Single non-critical check fail | 0 (pass) |
| P3 | Noise | All pass, LLM low-confidence PASS | 0 (pass) |

#### Structured JSON Output (STEP_SUMMARY)

Embedded in GITHUB_STEP_SUMMARY with HTML comment markers for Super-Founder parsing:

```
<!-- SENTINEL_ESCALATION_BEGIN -->
{
  "sentinel_severity": "P1",
  "repo": "huanlongAI/tzhOS",
  "repo_type": "governance",
  "total_checks": 6,
  "failed_checks": 2,
  "failed_dimensions": ["D-1", "LLM:GPC-003"],
  "llm_verdict": "FAIL",
  "run_url": "https://github.com/...",
  "timestamp": "2026-03-30T00:00:00Z"
}
<!-- SENTINEL_ESCALATION_END -->
```

#### Notification Flow

```
escalate.sh -> STEP_SUMMARY JSON (markers) -> workflow_run event
  -> Super-Founder Hummingbird HTTP Server -> FeishuCardBuilder -> Feishu #eng-notify
```

Sentinel does NOT directly integrate with any notification system. It provides structured JSON only. Super-Founder app handles workflow_run -> Feishu card conversion.

### Caller Workflow Sync (caller-sync.yml)

Location: `sentinel-shared/.github/workflows/caller-sync.yml` (commit c8eed83)

- Schedule: Sunday 00:00 UTC cron + workflow_dispatch (dry_run option)
- Canonical template embedded as `CANONICAL_BODY` env var
- Structural comparison: strip comments, normalize whitespace, sort, then compare
- Auto-PR (dry_run=false): sentinel-caller-sync branch -> update -> PR
- Dedup: checks for existing open sync PR
- Alert: caller-drift issue on sentinel-shared

### Phase 4 Architecture Summary

```
Sentinel CI Run (any repo)
  -> escalate.sh v2 (P0-P3 grading)
  -> STEP_SUMMARY JSON (SENTINEL_ESCALATION markers)
  -> workflow_run -> Super-Founder -> Feishu

Dashboard (daily 08:00 UTC)
  -> 16-repo health scan
  -> trend detection (NEW/RECOVERED/PERSISTENT)
  -> smart alert (NEW only)
  -> stale nudge (>72h -> auto dispatch)

Caller-Sync (weekly Sunday 00:00 UTC)
  -> structural compare 16 repos
  -> drift -> auto-PR
  -> caller-drift issue
```

## Secrets and Tokens

| Secret | Where | Scope | Used By |
|--------|-------|-------|--------|
| CASCADE_TOKEN | sentinel-shared + tzhOS | Fine-grained PAT: 17 repos, Actions RW + Contents R + Issues RW + PRs RW | cascade-verify, dashboard, matrix-updater, ruling-hook, caller-sync |
| ANTHROPIC_API_KEY | org-level (all repos) | Anthropic API key | LLM review, matrix-updater LLM draft |
| GITHUB_TOKEN | auto-provided | repo-scoped | Standard CI (NOT cross-repo) |

Note: CASCADE_TOKEN migrated from classic PAT to fine-grained PAT (Session 20). Only deployed on hub repos (sentinel-shared, tzhOS), not downstream. Classic PAT should be revoked.

## Additional Debugging (Phase 2+4)

### workflow_dispatch returns 422 "Workflow does not have workflow_dispatch trigger"
CRITICAL - Unicode Trigger Indexer Bug (confirmed 3 separate times):
1. Check workflow file for ANY non-ASCII characters (emoji, em-dash, section sign, CJK)
2. GitHub Actions trigger indexer SILENTLY FAILS on non-ASCII content
3. The workflow appears active, push triggers work, but workflow_dispatch is NEVER registered
4. `file <workflow.yml>` must report "ASCII text", NOT "UTF-8 Unicode text"
5. Fix: Delete the workflow file, re-create with PURE ASCII content AND A NEW FILENAME
6. Workflow IDs are cached per filename - delete/recreate same name inherits stale metadata
7. Only truly new filenames get fresh workflow IDs with clean trigger registration
8. Confirmed instances: dashboard.yml, matrix-updater.yml (Session 18), ruling-hook.yml (Session 21)

### Ruling Hook dispatches but matrix_change is empty
1. Check PR body Markdown structure -- `### Matrix Change` followed by code fence
2. Original sed pattern stops at empty lines (`^$`) which appear between header and fence
3. Fix: Use `sed -n '/[Mm]atrix.[Cc]hange/,/^### /p'` + grep-chain (see Ruling Hook section)
4. Verify: echo "$PR_BODY" | sed ... should output the actual YAML content

### repository_dispatch returns 204 but no workflow run created
1. Known limitation for PUBLIC repos - repository_dispatch events are silently dropped
2. Fix: Pivot to workflow_dispatch with explicit inputs instead

### MCP push_files returns 403 on .github/workflows/
1. GitHub App tokens CANNOT write workflow files
2. Fix: Use git clone/commit/push via terminal (osascript or direct)
3. From Cowork sandbox: write to Workspace mount -> osascript cp -> git push

### LLM draft completes in <1s (transient API failure)
1. matrix-updater curl call may fail silently due to `2>/dev/null`
2. Fallback path (auto Issue creation) should activate correctly
3. Not an architecture issue -- transient API connectivity
4. Verify: check Actions run logs for LLM step timing

### Severity shows P1 instead of P0 for governance D-1 failure
1. Root cause: jq `//` alternative operator treats `false` as falsy (same as `null`)
2. `jq '.passed // true'` returns `true` when `.passed` is `false`
3. Fix: explicit null check: `if .passed == null then "true" else (.passed | tostring) end`
4. General rule: NEVER use `jq '.field // default'` for boolean fields

## Workflow File Deployment Pattern

For deploying workflow files from Cowork sandbox to GitHub:
1. Generate file in Bash sandbox (ensures code quality)
2. Verify: `file <file.yml>` must show "ASCII text"
3. Write to Workspace mount (`/sessions/.../mnt/Workspace/`)
4. Use osascript `cp` from `/Users/tzh/Workspace/` to target location
5. git clone -> cp -> git add -> git commit -> git push

**Preferred transfer method** (Session 22): Workspace mount avoids base64 corruption issues with large files. The old base64-over-osascript pattern silently corrupts large payloads (gzip CRC errors). Always use Workspace mount for cross-sandbox transfer.

### GitHub Trigger Indexer: type:choice / type:boolean Causes 422

1. workflow_dispatch inputs with `type: choice` or `type: boolean` can cause GitHub's trigger indexer to silently fail
2. Symptom: file deploys correctly, `gh api` confirms content, but `gh workflow run` returns 422 "Workflow does not have 'workflow_dispatch' trigger"
3. Renaming the file does NOT fix this -- the indexer still fails on the new file
4. Fix: Use `type: string` for ALL workflow_dispatch inputs
5. For choice-like inputs, validate in the script body with `case` statements instead
6. Confirmed in Session 22 after 4 indexer failures (3× non-ASCII, 1× type:choice/boolean)

## Phase 4B+: LLM Auto-Remediation (sentinel-autofix.yml)

### Architecture

```
workflow_dispatch (target_repo, check_id, dry_run)
  -> checkout sentinel-shared
  -> clone target repo (CASCADE_TOKEN)
  -> run precheck script (D-2 or D-6)
  -> if violations: auto-fix.sh (Claude API)
  -> extract sed commands (security filter: grep '^sed -i ')
  -> if dry_run=false: apply patch, create branch, push, create PR
  -> step summary (always)
```

### auto-fix.sh Script (scripts/auto-fix.sh)

- Input: check_id (D-2|D-6), result_json, repo_root
- D-2 mode: Extracts forbidden terms + line context, asks Claude for sed replacements
- D-6 mode: Extracts hardcoded colors, asks Claude to map to guanghe design tokens
- Security: Only `grep -E '^sed -i '` lines extracted from LLM output (no arbitrary code execution)
- Fallback: If no API key or LLM fails, generates violation report only (no patch)
- Output: auto-fix-patch.sh (executable sed), auto-fix-summary.md (review report)

### Workflow File: .github/workflows/sentinel-autofix.yml

- ALL inputs are `type: string` (due to trigger indexer bug)
- Uses CASCADE_TOKEN for cross-repo operations
- Uses ANTHROPIC_API_KEY for Claude API calls
- Dedup: Checks for existing open auto-fix PR before creating new one
- Commit message: `fix(sentinel): auto-fix $CHECK violations ($N files)`

### Design Tokens (D-6 guanghe mapping)

```
Swift:   Color.ghPrimary, Color.ghBackground, ...
CSS:     var(--gh-primary), var(--gh-background), ...
React:   tokens.primary, tokens.background, ...
Native:  GHColor.primary, GHColor.background, ...
```
