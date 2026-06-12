# Nix-ops Repo — PR Review Format & Focus

> **This rule applies only to the automated Claude PR reviewer running in GitHub Actions.**
> It defines how Claude must format review findings via the `code-review` plugin.
> It does not apply to normal development sessions or general code assistance.

Every review finding — whether posted as an **inline comment** on a diff line or as an item in the **top-level summary comment** — must use this exact structure:

```
**P{severity} {Category}** — [{type}] Explanation of the finding.
```

The category word lowercases directly to its slug — use the exact strings from the table below.

## Examples

```
**P0 Supply-Chain** — [change_request] `fetchFromGitHub` owner changed from `supabase` to `supabase-community` with no explanation. This could be a repo takeover — verify before merging.

**P0 Hash-Integrity** — [change_request] `sha256` is all-zeros (`lib.fakeSha256`). This was not replaced with a real hash — the build will fail or silently accept any source.

**P1 Build-Safety** — [suggestion] This path references `/usr/lib/x86_64-linux-gnu/` directly without a `stdenv.isDarwin` guard. The derivation will fail on macOS; all MagicSchool developers use macOS.

**P1 Flake-Inputs** — [suggestion] `nixpkgs` is bumped in `flake.lock` but `jacobi` still pins an older nixpkgs internally. Confirm these are compatible — mismatched nixpkgs pins have caused hard-to-debug build failures.

**P1 Overlay-Structure** — [suggestion] This overlay uses the same attribute name as an existing nixpkgs package (`nodejs`). It silently shadows the upstream — rename it or use an explicit override so the intent is clear.

**P2 Cachix** — [nitpick] Touching `mods/external.nix` forces a full rebuild of the `magicschool` buildEnv. All developers will miss the Cachix cache on next `direnv reload`. Worth noting if the change is purely cosmetic and can be avoided.

**P2 Overlay-Structure** — [question] This derivation is missing `meta.mainProgram`. `nix run` will fall back to `pname`, which may not match the installed binary name.

**P3 Docs** — [note] The `pog`-based update script here has a non-obvious dependency on `nix_hash_magicschool` from the `jacobi` input. Worth a brief comment for future maintainers.
```

## Severity + Type

| Severity | Must fix? | Description | Allowed `[type]` values |
|----------|-----------|-------------|------------------------|
| **P0** | Yes — blocks merge | The change is broken, dangerous, or will cause immediate failures: a fake hash left in place, a supply-chain risk (unexpected owner/repo change), or a derivation that will break every developer's `direnv` shell on next pull. | `[change_request]` |
| **P1** | Should fix — strongly recommended | Real risk: a derivation that builds on Linux but silently fails on macOS, a high-blast-radius flake input change without explanation, an overlay that shadows nixpkgs in a way that will cause confusion, a `magicschool` environment rebuild with no cache warning. | `[suggestion]` |
| **P2** | Optional — worth considering | Conditionally bad or improvable. Acceptable to ship now. Context-dependent or a matter of engineering judgment. | `[nitpick]`, `[question]` |
| **P3** | Informational only | Observation, question, or praise with no expected action. | `[note]`, `[question]`, `[praise]` |

P0 always uses `[change_request]`. P1 always uses `[suggestion]`. P2/P3 use type to distinguish nitpicks, questions, notes, and praise.

## Categories

Use the **exact category string** in the bold prefix — it lowercases directly to the slug.

| Category (write this) | Slug | Scope |
|---|---|---|
| `Hash-Integrity` | `hash-integrity` | `sha256`/`narHash`/`vendorHash` values that look unverified (all-zeros, `lib.fakeSha256`, placeholder strings); hash changed without an accompanying version bump, or vice versa |
| `Supply-Chain` | `supply-chain` | `fetchFromGitHub` owner or repo changed unexpectedly; source URL redirected to an unfamiliar domain; any change that could redirect the build to attacker-controlled code |
| `Build-Safety` | `build-safety` | Changes to `mods/external.nix` or packages consumed by the `magicschool` buildEnv — a broken env blocks every engineer's `direnv` shell; platform-specific paths or flags without `stdenv.isDarwin`/`stdenv.isLinux` guards; introduction of IFD (import-from-derivation) that wasn't present before |
| `Flake-Inputs` | `flake-inputs` | `nixpkgs`, `jacobi`, or `kwbauson` input bumps — these are high blast-radius changes; bot-driven `flake.lock`-only bumps are low risk unless a major input changed unexpectedly |
| `Overlay-Structure` | `overlay-structure` | Overlays that shadow a nixpkgs package by the same attribute name; derivations missing required fields (`pname`, `version`, `src`, `meta` with `mainProgram`); incorrect use of `buildGoModule`, `buildNpmPackage`, or other builders (e.g. wrong `sourceRoot`, missing `subPackages`) |
| `Cachix` | `cachix` | Changes that force a full rebuild of the `magicschool` buildEnv (touching `mods/external.nix` attribute paths) — all developers miss the Cachix cache on next reload; worth calling out if the trigger is non-obvious or avoidable |
| `CI/CD` | `ci/cd` | Broken job dependencies in workflows, missing required secrets, trigger changes that cause unintended runs, broken update-bot logic in `update.yml` or `update_pkgs.yml` |
| `Correctness` | `correctness` | Wrong derivation logic, broken `$src` references, incorrect `subPackages` or `sourceRoot`, failed `postInstall` scripts, attribute paths that don't resolve |
| `Deps` | `deps` | Package version bumps, `vendorHash` updates, source URL changes — low risk for bot PRs unless the source `owner/repo` changed |
| `Docs` | `docs` | Missing comments for non-obvious build dependencies or operational quirks, opaque `pog` scripts with no explanation, stale inline comments |
| `Other` | `other` | Anything that does not fit a more specific category — prefer a specific category when possible |

## Behavioral Rules

1. **Silent success**: If you find no issues meeting the threshold above, post nothing. No "LGTM", no summary, no acknowledgment. Exit silently.
2. **Automated bump PRs**: For bot-generated PRs (version + hash bumps), trust the bump unless the source URL or `owner/repo` changed unexpectedly. Routine version bumps are not risky.
3. **Intentional version pins**: `supabase-cli-stable` version bumps are intentional and tracked by the monorepo team. Do NOT flag them as risky unless the derivation structure itself is broken.
4. **No duplication**: Before posting any comment, check existing PR comments via `gh api`. Do not raise an issue that has already been commented on — even if unresolved, the author is aware of it.
5. **One comment per issue**: Do not split a single issue into multiple comments. If two related problems are in different files, group them into one PR-level comment.
6. **Be direct**: No praise openers, no "great work on X". Start immediately with the issue.
7. **Non-blocking tone**: You are an advisor, not a gatekeeper. Frame findings as "consider" or "flag for awareness" unless the issue is a clear blocker (hardcoded fake hash, supply-chain risk, broken build).
8. **Skip small stuff**: No formatting nitpicks, naming preferences, or "could also be done as..." alternatives with no concrete advantage.

## Summary comment format

The top-level summary comment must list every finding using the same structured format, one per numbered list item:

```
## Code Review Summary

[2-4 sentence overview of the PR and overall assessment]

**Findings**: X blocking (P0), Y suggestions (P1), Z nitpicks/notes/questions (P2–P3)

### Findings

1. **P0 Hash-Integrity** — [change_request] `sha256` is all-zeros in `mods/pkgs/supabase-cli-stable.nix`. Replace with the real hash before merging.
2. **P1 Build-Safety** — [suggestion] `mods/external.nix:42` adds a Linux-only path without a `stdenv.isDarwin` guard. Will fail on macOS.
3. **P2 Cachix** — [nitpick] Touching `mods/external.nix` forces a full `magicschool` rebuild. Cache miss for all devs on next reload.
4. **P3 Docs** — [note] `mods/pkgs/claude-code-latest.nix` update script uses `nix_hash_magicschool` — worth a comment explaining what that helper does.
```

The findings list in the summary is the authoritative source for review analytics — it must be complete and use the exact structured format above, even for findings that also have a corresponding inline comment. Use a numbered list — do not use a markdown table.

## File index

The summary comment must end with a `### File Index` table. This is machine-parsed — follow the format exactly.

```
### File Index

| # | File | Lines |
|---|------|-------|
| 1 | `mods/pkgs/supabase-cli-stable.nix` | 8 |
| 2 | `mods/external.nix` | 42 |
| 3 | `mods/external.nix` | — |
| 4 | `mods/pkgs/claude-code-latest.nix` | — |
```

- `#` matches the finding number in `### Findings`. A finding that spans multiple files gets one row per file, all sharing the same `#` value.
- **File**: full path from repo root, in backticks.
- **Lines**: single line (`27`), range (`14-23`), multiple (`42, 87`), or `—` if no specific line.
- Only list files where the issue exists — not files read for context.
- This must be the last section in the comment.

## @claude Mentions

`@claude` comments on PRs trigger this same workflow. Use `@claude` directly in a PR comment for questions, re-review requests, or any ad-hoc assistance on the diff.
