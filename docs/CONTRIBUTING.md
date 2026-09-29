<!-- CONTRIBUTING.md -->

# Contributing to abbu

Thank you for your interest in contributing!

## Setup

```bash
git clone https://github.com/scarver2/abbu
cd abbu
mise exec -- bundle install
```

## DX Loop

```bash
mise exec -- bundle exec guard
```

This runs RSpec and RuboCop automatically on file changes.

## Running Tests

```bash
bin/spec
```

## Linting

```bash
bin/lint
mise exec -- bundle exec rubocop -a   # autocorrect
```

## Packaging

```bash
bin/package
```

This builds the current gem, verifies its metadata, installs it into an isolated
gem home, and loads that installed copy. A successful package check is evidence
only; it does not authorize a release tag or RubyGems publication.

## Pull Request Guidelines

- Base branch: `main`
- Commit style: [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`)
- All specs must pass and coverage must remain at 100%
- RuboCop must pass with no offenses
- Add an entry to `docs/CHANGELOG.md` under `[Unreleased]`

## Reporting Issues

Open an issue on GitHub with a minimal reproduction case.

---
Stan Carver II
Made in Texas 🤠
https://stancarver.com
