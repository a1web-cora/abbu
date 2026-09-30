---
name: releasing
description: Use for abbu version preparation, package verification, release tags, RubyGems MFA publication, yanks, or release recovery.
---

# Releasing

Read `AGENTS.md`, the current changelog, gemspec, version constant, and package
workflow before release work.

## Authority Boundary

Green automation is evidence, not authorization to publish. Never create or
push a release tag, publish or yank a gem, approve a protected release
environment, or otherwise authorize publication without explicit Sheriff
approval for the specific version.

If approval is absent or ambiguous, stop after non-mutating preparation and
report exactly what remains gated. Approval for code, a PR, or package
verification does not imply release approval.

## Canonical Package Check

- `bin/package` builds the current gem, validates version metadata, installs it
  into an isolated `GEM_HOME`, and loads that isolated installation.
- Use `bin/spec` and `bin/lint` before presenting a release candidate.
- A future `bin/release-check` may combine non-publishing invariants, but it must
  remain a dry run and cannot grant publication authority.
- When package or release behavior changes, update the command, CI or workflow,
  and documentation together rather than adding an ad hoc release path.

## Trusted Publishing Standard

For GitHub-hosted RubyGems, publish through GitHub Actions Trusted Publishing by
default rather than from a maintainer workstation or a long-lived API key.

- Use `.github/workflows/release.yml` with a `v*` tag trigger.
- Use the protected GitHub environment `release`.
- Grant `id-token: write` only to the release job so RubyGems can exchange
  GitHub's OIDC identity for a short-lived publishing token.
- Use `rubygems/release-gem@v1`; do not add `RUBYGEMS_API_KEY` when Trusted
  Publishing is available.
- Configure RubyGems.org once to trust the repository, `release.yml` workflow,
  and `release` environment. That external trust registration is an owner
  action and must not be simulated with repository credentials.
- Verify the pushed tag exactly equals `v#{VERSION}` before publication.
- The workflow is an execution mechanism only. Tag creation/push and protected
  environment approval remain subject to the Sheriff authority boundary above.

## Release Invariants

- Release only reviewed commits reachable from current `origin/main`.
- Require a clean checkout, matching stable `MAJOR.MINOR.PATCH` version and
  `vMAJOR.MINOR.PATCH` tag, dated changelog entry, green supported-Ruby CI, and a
  verified package.
- Require RubyGems MFA or an equivalently protected trusted-publishing flow.
- Push only the explicitly approved release tag; never push broad `--tags`.
- Never move, reuse, or overwrite a published tag or gem version. Correct a
  defect with a new patch release; yank only with explicit Sheriff approval and
  a documented reason.
- After authorized publication, verify the GitHub tag/release and RubyGems
  version independently.

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
