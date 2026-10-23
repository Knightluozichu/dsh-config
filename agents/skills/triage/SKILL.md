---
name: triage
description: Move issues through a state machine of triage states on a tracker with no labels: categorise, verify, grill if needed, and write agent-ready briefs.
disable-model-invocation: true
---

# Triage

Move issues on the project issue tracker through a small state machine.

This repo reviews through Gerrit and has **no labels and no issue platform**. Issues are markdown files under `issues/open/` and `issues/closed/`, and every piece of state is a frontmatter field. Read `docs/agents/state.md` before doing anything: it is the source of truth for the field values, the transitions, and the closing rules. This skill only describes the triage *process*.

## Reference docs

- [AGENT-BRIEF.md](AGENT-BRIEF.md): how to write durable agent briefs
- [OUT-OF-SCOPE.md](OUT-OF-SCOPE.md): how the out-of-scope knowledge base works. In this repo that knowledge base is `issues/out-of-scope/`.

## Roles

One **category** (`frontmatter category`): `bug` or `enhancement`.

One **state**, expressed by the directory plus `frontmatter status`:

| State | How it looks on disk | Meaning |
| --- | --- | --- |
| untriaged | in `issues/open/`, no `status` field | never evaluated |
| `needs-info` | `status: needs-info` | waiting on the reporter |
| `ready` | `status: ready` | fully specified, an agent can start |
| `in-progress` | `status: in-progress` + `owner:` | claimed and being worked |
| closed | in `issues/closed/` + `resolution:` | `wontfix` / `duplicate` / `implemented` |

Every triaged issue carries exactly one category and one state. If the fields conflict, flag it and ask the maintainer before doing anything else.

Transitions: untriaged → `needs-info` / `ready` / closed. `needs-info` returns to untriaged once the reporter replies. Any state → `in-progress` when someone writes `owner:`. The maintainer can override at any time; flag transitions that look unusual and ask before proceeding.

## Invocation

The maintainer invokes `/triage` and describes what they want in natural language. Interpret the request and act. Examples:

- "Show me anything that needs my attention"
- "Let's look at <file name>"
- "Move this one to ready"

Identify an issue by its file name under `issues/open/`; there are no issue numbers.

## Show what needs attention

Query the tracker and present three buckets, oldest first:

1. **Untriaged**: in `issues/open/` with no `status` field.
2. **`needs-info` with reporter activity** since the last `## Triage` section: needs re-evaluation.
3. **`ready` but unclaimed**: no `owner:`, so nobody has picked it up.

```sh
rg -L '^status:' issues/open            # untriaged
rg -l '^status: needs-info' issues/open # waiting on the reporter
rg -l '^status: ready' issues/open      # ready, then drop the ones with ^owner:
```

Show counts and a one-line summary per item. Let the maintainer pick.

## Triage a specific issue

1. **Gather context.** Read the whole file: frontmatter, body, and every existing `## Triage` section. Parse any prior triage notes so you don't re-ask resolved questions. Explore the codebase using the project's domain vocabulary. Run two checks against the codebase: (a) **redundancy**: search for an existing implementation of the requested behavior by domain concept (not just the request's wording), and report where you looked. If found, it's an already-implemented close, not a fix. (b) **prior rejection**: read `issues/out-of-scope/*.md` and surface any that resembles this request.

2. **Recommend.** Tell the maintainer your category and state recommendation with reasoning, plus a brief codebase summary relevant to the request (including whether it's already implemented). Wait for direction.

3. **Verify the claim.** Before any grilling, check that the claim holds up. For a bug, reproduce it from the reporter's steps. Report what happened: confirmed (with code path), failed, or insufficient detail (a strong `needs-info` signal). A confirmed verification makes a much stronger agent brief.

4. **Grill (if needed).** If the request needs fleshing out, call the Skill tool twice, for "grilling" and "domain-modeling", and grill it into shape a round of questions at a time.

5. **Apply the outcome**, writing into the file rather than a comment stream:

   - **`ready`**: append an `## Agent Brief (<date>)` section following [AGENT-BRIEF.md](AGENT-BRIEF.md), then set `status: ready`.
   - **ready for a human**: same brief structure, but state why it can't be delegated (judgment calls, external access, design decisions, manual testing).
   - **`needs-info`**: append a `## Triage (<date>)` section using the template below, then set `status: needs-info`.
   - **Close without action**: set `status: done` and a `resolution:` value, then `git mv` the file to `issues/closed/`:
     - **Already implemented**: point to where it lives; do **not** write to `issues/out-of-scope/`.
     - **Rejected (bug)**: give a polite explanation in the file, then close.
     - **Rejected (enhancement)**: write `issues/out-of-scope/<slug>.md`, link it from the issue, then close.

Every section triage writes **must** start with this line:

```
> *This was generated by AI during triage.*
```

## Quick state override

If the maintainer says "move it to ready", trust them and apply the state directly. Confirm what you're about to do, then act. Skip grilling. If moving to `ready` without a grilling session, ask whether they want an agent brief.

## Triage notes template

```markdown
## Triage (<date>)

> *This was generated by AI during triage.*

**What we've established so far:**

- point 1
- point 2

**What we still need from you (@reporter):**

- question 1
- question 2
```

Capture everything resolved during grilling under "established so far" so the work isn't lost. Questions must be specific and actionable, not "please provide more info".

## Resuming a previous session

If prior `## Triage` sections exist in the file, read them, check whether the reporter has answered any outstanding questions, and present an updated picture before continuing. Don't re-ask resolved questions.

## Boundaries

- Never create labels, assignees, milestones, or priorities. State lives in the frontmatter and the directory.
- Never call `gh issue` / `glab issue`.
- Never `git add` or `git commit` on the maintainer's behalf.
