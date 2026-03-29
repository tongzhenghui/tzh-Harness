---
name: sentinel-ops
description: "Consistency Sentinel CI/CD operations: deploy, debug, configure, and manage the multi-repo Sentinel system across huanlongAI org. Use this skill whenever the user mentions sentinel, CI checks, precheck scripts, reusable workflows, multi-repo deployment, sentinel config profiles, LLM review layer, or any operational task related to the Consistency Sentinel system. Also trigger when discussing GitHub Actions failures in sentinel-related workflows, cross-repo workflow_call patterns, or batch deployment to multiple repos."
---

# Sentinel Ops

Operational knowledge base for the **Consistency Sentinel** system — a multi-repo CI/CD governance framework deployed across the huanlongAI GitHub organization.

## Architecture Overview

The Sentinel system uses a **hub-and-spoke reusable workflow** pattern:

- **Hub**: `huanlongAI/sentinel-shared` (PUBLIC repo — must stay public, see constraints below)
  - `.github/workflows/consistency-sentinel.yml` — the reusable workflow (callee)
  - `scripts/` — D-1~D-6 precheck scripts + LLM review + aggregation + escalation
  - `prompts/` — system prompts for LLM review layer

- **Spokes**: Each repo in huanlongAI org has:
  - `.github/workflows/consistency-sentinel.yml` — ~25-line caller workflow
  - `.sentinel/config.yaml` — repo-level configuration

## Critical Constraints (Hard-Won Lessons)

### 1. Permissions MUST be in the caller, NEVER in the callee

GitHub Actions reusable workflows (`workflow_call`) that declare a `permissions` block at ANY level (top-level or job-level) cause a **startup_failure** — the workflow fails in 0 seconds with 0 jobs run, and the error is invisible in the UI.

**Rule**: The caller workflow declares `permissions`. The reusable workflow in sentinel-shared declares NONE.

```yaml
# CALLER (in each repo) — declares permissions
permissions:
  contents: read
  pull-requests: write
  issues: write
jobs:
  sentinel:
    uses: huanlongAI/sentinel-shared/.github/workflows/consistency-sentinel.yml@main
```

```yaml
# CALLEE (sentinel-shared) — NO permissions block anywhere
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
# WRONG — kills script if no match
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
# Simple key-value
yaml_get() {
  local file="$1" key="$2" default="${3:-}"
  local val=$(grep -E "^\s*${key}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:\s*//' | sed 's/\s*#.*//' | tr -d '"' | tr -d "'")
  echo "${val:-$default}"
}

# Array values (top-level key)
yaml_get_array() {
  local file="$1" key="$2"
  sed -n "/^\s*${key}:/,/^\s*[a-z]/p" "$file" 2>/dev/null | { grep "^\s*-" || true; } | sed 's/^\s*-\s*//' | tr -d '"' | tr -d "'"
}

# Nested key (e.g., llm.model)
yaml_get_nested() {
  local file="$1" parent="$2" child="$3" default="${4:-}"
  local val=$(sed -n "/^\s*${parent}:/,/^\s*[a-z_]*:/p" "$file" 2>/dev/null | grep -E "^\s+${child}:" | head -1 | sed 's/^[^:]*:\s*//' | sed 's/\s*#.*//' | tr -d '"' | tr -d "'")
  echo "${val:-$default}"
}

# Nested array (e.g., llm.checks)
yaml_get_nested_array() {
  local file="$1" parent="$2" child="$3"
  sed -n "/^\s*${parent}:/,/^\s*[a-z_]*:/p" "$file" 2>/dev/null | sed -n "/^\s*${child}:/,/^\s*[a-z]/p" | { grep "^\s*-" || true; } | sed 's/^\s*-\s*//' | tr -d '"' | tr -d "'"
}

# Key-value pairs under a parent (e.g., anchor_files)
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
| precheck-cascade.sh | D-3 | Source file change → target file must exist | `cascade_map` |
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

- **Graceful degradation**: API failure, empty response, or JSON parse failure → verdict `ESCALATE`, exit 0 (non-blocking). The LLM layer should never break the CI pipeline.
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
Non-Owner repos: require cross-domain write protocol (MULTI-NODE-COWORK-SPEC §3.4)

## Debugging Playbook

### Workflow shows "startup_failure" (0s, 0 jobs)
1. Check for `permissions` block in the reusable workflow → remove it
2. Check `uses:` path syntax — no leading dots in repo names
3. Check sentinel-shared visibility — must be public

### Script exits immediately with code 1
1. Check `grep` pipelines — wrap with `{ grep ... || true; }`
2. Check empty array access — add `${#ARRAY[@]} -gt 0` guard
3. Check `yaml_get_array` — ensure `|| true` in grep within function

### D-1 false positive on non-governance commits
1. Verify `governance_files` list in `.sentinel/config.yaml`
2. Ensure git diff mode matches event context (PR vs push)

### LLM says "No checks enabled"
1. Check nested YAML parsing — `llm.checks` requires `yaml_get_nested_array`, not `yaml_get_array`
2. Verify `llm:` section indentation in config

### Checkout of sentinel-shared fails
1. Verify `huanlongAI/sentinel-shared` is PUBLIC
2. Check `actions/checkout` step uses correct path and ref
