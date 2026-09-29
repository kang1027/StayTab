---
name: release-changelog
description: Changelog generation for StayTab from a version or tag through HEAD. Use when the user requests release notes with verified GitHub issue references.
---

# Release changelog

Create end-user release notes from a base version through the latest commit.
Return Markdown unless the user names an output file.

## 1. Fix the range and format

The "Changelog format" section of `CLAUDE.md` is canonical: its section
names, heading levels, order, audience, and compare footer.

Use the requested base ref. StayTab tags are `v`-prefixed (`v0.1.1`), so a bare
version means its `v` tag. The repository also carries upstream BetterCmdTab
tags; if no base was given, take the newest release from
`gh release list -R kang1027/StayTab` and state that choice.
The target is `HEAD` unless the user supplied another commit. Resolve both
endpoints with `git rev-parse` and verify the range with
`git merge-base --is-ancestor`.

**Complete when:** the exact `BASE..TARGET` range is valid and the canonical
output structure is known from the current repository files.

## 2. Build an evidence ledger

Inspect every commit with
`git log --reverse --format=fuller "$BASE..$TARGET"` and every net changed
file with `git diff --name-status "$BASE..$TARGET"`. Read patches whenever a subject
does not prove the user-visible outcome. Classify every commit as either:

- one observable user change, possibly grouped with related commits; or
- excluded because it is only `chore`, `refactor`, `build`, `test`, `ci`, or
  documentation.

Collect issue numbers from commit messages and associated pull requests. Query
pull requests with `gh pr view ... --json body,closingIssuesReferences` and
confirm candidates with `gh issue view`. A printed number must identify a
relevant issue, not merely the pull request containing the change. Append
verified issues to the matching bullet as `(#123, #456)`. Leave the suffix off
when no issue is verified.

**Complete when:** every commit and changed file is accounted for, every
included claim is supported by a diff, and every printed issue number is
verified and relevant.

## 3. Write outcome-first notes

Start directly with the canonical Highlights heading. Put its one- or
two-sentence summary on one physical line.

Emit only non-empty canonical sections, in the order and at the heading depth
`CLAUDE.md` gives. Each section item is one physical line in the form
`- User-visible outcome`.
Describe what users can now do, what changed for them, or what no longer
breaks. Use product language rather than commit subjects, implementation
symbols, or contributor workflow.

Add known issues only for confirmed unresolved behavior in the target. Keep
the GPL-3.0 / BetterCmdTab attribution that `RELEASING.md` requires (published
releases carry it in a `### License and attribution` section). Combine duplicate
outcomes and keep issue suffixes at the end of their bullets.

After a blank line, end with:

```text
**Full changelog:** https://github.com/kang1027/StayTab/compare/<BASE>...<TARGET-REF>
```

Use the intended `v` release tag as `TARGET-REF` when the user supplied it;
otherwise use the resolved target commit SHA.

**Complete when:** the first line is the canonical Highlights heading, all
headings exactly match `CLAUDE.md`, empty sections are absent, every
bullet is user-facing, and the footer represents the inspected range.
