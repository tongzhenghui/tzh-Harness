---
name: governance-workflow
description: "Governance workflow automation for huanlongAI: Ruling creation, spec sign-off, PROGRESS.json tracking, Obsidian session sync, cascade verification, and governance document lifecycle. Use this skill when the user mentions rulings, governance specs, MIRA, SAAC, charter amendments, progress tracking, session memory, Obsidian sync, cascade rules, governance sign-off, spec versioning, or any workflow related to the tzh-Harness governance framework. Also trigger for cross-repo governance coordination and CONSEN-SPEC references."
---

# Governance Workflow

Automates governance processes for the huanlongAI organization, centered on the **tzh-Harness** repository as the governance hub.

## Governance Document Hierarchy

The governance framework has a clear authority chain:

```
00-CHARTER.md          <- Constitutional document, highest authority
  +-- MIRA-001.md      <- Mission, Identity, Role Architecture
  +-- SAAC-001.md      <- Strategic Architecture & Alignment Charter
  +-- CONSEN-SPEC-001.md <- Consistency Sentinel specification
  +-- BOOTSTRAP.md     <- Bootstrap protocol
  +-- CONTEXT.md       <- Living context document, updated frequently
```

**Key rule**: Changes to higher-authority documents cascade downward. MIRA changes may require updates to SAAC, BOOTSTRAP, CONTEXT, and CONSEN-SPEC. This is enforced by D-3 (cascade precheck) in the Sentinel system.

## Core Workflows

### 1. Ruling Creation

A **Ruling** is a governance decision recorded in `RULINGS.md` in tzh-Harness. Rulings have binding force and serve as precedent.

**Process**:
1. Identify the decision point and affected specs
2. Draft the ruling with rationale
3. Append to RULINGS.md with sequential numbering
4. Update CHANGELOG.md (required by D-1 check)
5. If the ruling modifies a spec, update the spec document
6. Commit with message format: `gov(ruling): R-NNN <brief description>`

**Ruling format**:
```markdown
### R-NNN: <Title>
**Date**: YYYY-MM-DD
**Scope**: <affected specs/repos>
**Decision**: <the actual ruling>
**Rationale**: <why this decision was made>
**Impact**: <what changes as a result>
```

### 2. Spec Sign-Off

Specs (MIRA, SAAC, CONSEN-SPEC, etc.) follow a versioning lifecycle:

**Version format**: `vX.Y` where X = major (breaking/structural), Y = minor (clarification/addition)

**Sign-off process**:
1. Draft changes in a branch
2. Sentinel CI runs all checks (D-1~D-6 + LLM review)
3. Review cascade impacts -- which downstream docs need updates?
4. Update `version:` field in the spec frontmatter
5. Update CHANGELOG.md with version bump entry
6. Merge to main
7. Record in PROGRESS.json

### 3. Cascade Verification

The `cascade_map` in `.sentinel/config.yaml` defines dependency relationships:

```yaml
cascade_map:
  "MIRA-001.md":
    - "SAAC-001.md"
    - "BOOTSTRAP.md"
    - "CONTEXT.md"
    - "CONSEN-SPEC-001.md"
  "SAAC-001.md":
    - "CONTEXT.md"
    - "BOOTSTRAP.md"
  "00-CHARTER.md":
    - "CONTEXT.md"
    - "BOOTSTRAP.md"
```

When a source file is modified, D-3 checks that all target files in the cascade exist. This is a structural check -- it ensures awareness, not that targets were also modified (that's a future enhancement).

**Manual cascade workflow**: When modifying a high-authority document:
1. Run `git diff` to identify what changed
2. Review cascade_map for affected downstream documents
3. Assess each downstream doc -- does it reference the changed content?
4. Update downstream docs as needed
5. Document cascade rationale in commit message

### 4. PROGRESS.json Tracking

`PROGRESS.json` in tzh-Harness records session-level work history. It serves as an audit trail and coordination mechanism across nodes (NODE-M, NODE-C, etc.).

**Structure**:
```json
{
  "sessions": [
    {
      "id": 13,
      "date": "2026-03-29",
      "node": "NODE-M",
      "title": "Sentinel Phase 1 deployment",
      "work_packages": ["WP-1", "WP-2", "WP-3", "WP-4"],
      "summary": "...",
      "artifacts": ["sentinel-shared repo", "16-repo deployment"],
      "decisions": ["R-001"],
      "next_steps": ["WP-5", "WP-6"]
    }
  ]
}
```

**Update process**:
1. At session end or major milestone, add a new entry
2. Increment session ID
3. Include all work packages completed
4. Reference any rulings made
5. List artifacts created
6. Identify next steps for continuity

### 5. Obsidian Session Sync

Session memory is stored in Obsidian for long-term recall:

**Path pattern**: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/tzh-memory/sessions/YYYY/YYYY-MM-DD-NODE-<topic>.md`

**Content structure**:
```markdown
---
date: YYYY-MM-DD
node: NODE-M
session: <id>
title: <topic>
status: completed|in_progress
tags: [sentinel, governance, ...]
---

# Session <id>: <topic>

## Work Packages Completed
## Critical Discoveries (if any)
## Commits This Session (table format)
## E2E Results
## Architecture (code block with flow diagram)
## Status
```

**Sync triggers**: End of significant work session, major milestone, or context window approaching limit. Write the session note capturing the essential knowledge for future recall.

**Language rule**: Obsidian session notes MUST be written in Chinese with English technical term translations in parentheses.

## Governance Files Inventory (tzh-Harness)

| File | Authority | Purpose |
|------|-----------|--------|
| 00-CHARTER.md | Constitutional | Organization charter, highest authority |
| MIRA-001.md | Foundational | Mission, Identity, Role Architecture |
| SAAC-001.md | Foundational | Strategic Architecture & Alignment |
| CONSEN-SPEC-001.md | Operational | Sentinel system specification |
| BOOTSTRAP.md | Operational | Bootstrap protocol for new nodes |
| CONTEXT.md | Living | Current context, frequently updated |
| MASTER-OVERVIEW.md | Reference | High-level system overview |
| RULINGS.md | Precedent | Governance decisions log |
| CHANGELOG.md | Audit | Change history |
| PROGRESS.json | Audit | Session-level work tracking |

## Cross-Repo Governance Coordination

### Write-Owner Model

Each node (NODE-M, NODE-C, etc.) has Write-Owner privileges for specific repos. Governance changes that affect non-owned repos must follow the cross-domain write protocol.

**NODE-M Write-Owner repos**: tzhOS, tzh-Harness, super-founder, tzh-agent-configs, tzh-evals, tzh-dotfiles, guanghe, tzhOS-App

**Protocol for non-owned repos**:
1. Open an Issue describing the needed change
2. Tag the responsible node
3. Or: Submit a PR and request review from the owner node

### Sentinel Check IDs

Checks referenced in governance workflows:

| ID | Dimension | Description |
|----|-----------|------------|
| GPC-003 | Governance Process | Governance process compliance |
| SAC-004 | Strategic Alignment | Strategic alignment compliance |
| DBC-002 | Design/Brand | Design and brand compliance |
| SEC-* | Software Engineering | Standard engineering checks (deterministic) |

## Commit Message Conventions

Governance-related commits follow structured prefixes:

```
gov(ruling): R-NNN <description>          # New ruling
gov(spec): MIRA-001 v1.1 <description>   # Spec version bump
gov(cascade): update downstream from MIRA # Cascade propagation
ci(sentinel): deploy/update sentinel      # Sentinel CI changes
doc(governance): <description>            # Documentation updates
doc(progress): Session NN <description>   # PROGRESS.json update
doc(skill): <skill-name> <description>    # Skill knowledge update
```

## Common Governance Scenarios

### Adding a New Governance File
1. Create the file in tzh-Harness
2. Add to `governance_files` list in `.sentinel/config.yaml`
3. Add cascade relationships to `cascade_map` if applicable
4. Update CHANGELOG.md
5. Record in PROGRESS.json

### Onboarding a New Repo
1. Determine profile (governance/infra/app/library)
2. Deploy caller workflow from template (see sentinel-ops skill)
3. Create `.sentinel/config.yaml` with appropriate profile
4. Populate `governance_files` and `cascade_map` if governance profile
5. Add to REPO-MAP documentation
6. Ensure ANTHROPIC_API_KEY secret is available

### Amending a Foundational Spec
1. Create a branch
2. Make the changes
3. Run cascade analysis -- identify all downstream impacts
4. Update all affected downstream documents
5. Bump version in spec frontmatter
6. Update CHANGELOG.md
7. Push and let Sentinel CI validate
8. Review Sentinel results -- all D-checks should pass
9. If LLM layer flags concerns, address them
10. Merge and record ruling if needed

## Phase 2 Additions

### Crystallization Automation (tzhOS: crystallization.yml)

Automates CONSEN-SPEC S5.2 ruling crystallization:
- Trigger: workflow_dispatch with 6 inputs (ruling_id, ruling_title, ruling_scope, ruling_decision, ruling_rationale, ruling_impact)
- Process: Claude API drafts RULINGS.md entry + CHANGELOG.md update
- Fallback: Template-based entry if LLM fails
- Output: Commits to main with gov(ruling) prefix

### Matrix Auto-Update on Ruling Merge

When a ruling PR merges in tzhOS with gov(ruling) in the title:
1. ruling-hook.yml detects the merge event
2. Extracts matrix_change from PR body (after ## Matrix Change heading)
3. Base64-encodes and dispatches to sentinel-shared/matrix-updater.yml
4. LLM drafts updated sentinel-matrix.yaml using Claude API
5. Creates a PR on sentinel-shared for human review
6. If LLM fails, creates a manual-update issue instead

This closes the loop: governance ruling -> automated matrix configuration update.

### PROGRESS.json Session Schema (Updated)

Sessions now include additional fields:
```json
{
  "id": 22,
  "date": "2026-03-30",
  "node": "NODE-M",
  "title": "...",
  "work_packages": ["WP-4A-1: ..."],
  "summary": "...",
  "artifacts": ["repo/path (commit_sha)"],
  "architecture": { "trigger": "...", "flow": "..." },
  "key_decisions": ["..."],
  "blockers": [],
  "status": "completed",
  "next_steps": ["..."]
}
```

### Cross-Repo Governance Event Flow (Updated with Phase 4)

```
tzhOS ruling PR merge
  -> ruling-hook.yml (tzhOS)
  -> workflow_dispatch to matrix-updater.yml (sentinel-shared)
  -> Claude API drafts sentinel-matrix.yaml update
  -> PR created on sentinel-shared
  -> Human reviews and merges
  -> Push triggers cascade-verify.yml (sentinel-shared)
  -> Fan-out to all 16 downstream repos
  -> Each repo: escalate.sh v2 grades severity (P0-P3)
  -> STEP_SUMMARY JSON with SENTINEL_ESCALATION markers
  -> Dashboard aggregates health next morning (08:00 UTC)
  -> Trend detection: NEW/RECOVERED/PERSISTENT failures
  -> Smart alert: issue only on NEW failures
  -> Stale nudge: auto-dispatch repos silent >72h
  -> Caller-sync: weekly drift check + auto-PR
```

## Phase 4 Additions (Session 22)

### Severity-Aware Governance

Phase 4 introduced P0-P3 severity grading in escalate.sh v2. For governance repos, this has special implications:

- **D-1 (changelog) failure on governance repo = P0**: Blocks merge, triggers critical notification
- **LLM:GPC-003 or LLM:SAC-004 failure on governance repo = P0**: Same critical treatment
- **All other governance check failures = P1**: Blocks merge but lower severity

This means governance spec changes are held to the highest standard. A spec amendment that forgets CHANGELOG.md will be caught as P0 critical.

### Notification Pipeline for Governance Events

```
Sentinel CI on governance repo
  -> escalate.sh v2 (P0 for governance-critical checks)
  -> STEP_SUMMARY JSON (SENTINEL_ESCALATION markers)
  -> workflow_run event
  -> Super-Founder Hummingbird HTTP Server
  -> FeishuCardBuilder
  -> Feishu #eng-notify group
```

Sentinel does NOT directly integrate with Feishu. The Super-Founder app (already delivered in its Phase 5) handles the workflow_run -> Feishu interactive card conversion.

### Cross-Sandbox File Transfer (Cowork)

When governance workflow automation needs to transfer files between Cowork sandbox and Mac (e.g., for skill updates, workflow deployments):

**Preferred method** (Session 22): Write to Cowork Workspace mount `/sessions/.../mnt/Workspace/` which maps to `/Users/tzh/Workspace/` on Mac. Then use osascript `cp` to final destination.

This replaces the unreliable base64-over-osascript transfer which silently corrupts large files.

### Dashboard v2 Governance Integration (Phase 5)

Dashboard v2 (dashboard.yml) now produces structured escalation JSON for governance-aware downstream consumers:

```json
{
  "type": "dashboard",
  "severity": "P1",
  "health_pct": 93,
  "total": 16, "pass": 15, "fail": 1, "stale": 0,
  "new_failures": "tzh-Harness",
  "autofix_targets": "tzh-Harness:D-2"
}
```

This JSON is wrapped in `SENTINEL_ESCALATION_BEGIN/END` HTML comment markers in STEP_SUMMARY, parseable by Super-Founder FeishuCardBuilder for Feishu notifications.

Dashboard v2 auto-triggers sentinel-autofix.yml for D-2/D-6 violations (dry_run=true by default). This creates a closed-loop governance flow: detect → fix → review PR → merge.

### GitHub Workflow Input Type Restriction

CRITICAL: All `workflow_dispatch` inputs MUST use `type: string`. The `type: choice` and `type: boolean` types cause GitHub's trigger indexer to silently fail (HTTP 422). Validate input values in script body with `case` statements instead.
