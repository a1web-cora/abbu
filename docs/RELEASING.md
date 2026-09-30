<!-- docs/RELEASING.md -->

# RubyGems Trusted Publishing

ABBU publishes RubyGems releases from GitHub Actions using RubyGems.org Trusted
Publishing. The release workflow intentionally contains no long-lived RubyGems
API key.

## One-time RubyGems.org setup

As a RubyGems owner for `abbu`, configure a Trusted Publisher with:

- GitHub repository owner: `scarver2`
- GitHub repository: `abbu`
- workflow filename: `release.yml`
- GitHub environment: `release`

Create the GitHub environment named `release` with `scarver2` as a required
reviewer and administrator bypass disabled. Only tags matching `v*` may deploy.
The Sheriff may approve a release they initiated; approval is still explicit.
Verify these settings before the first automated publication. Merely naming an
environment in YAML does not protect it.

Official RubyGems guidance:
https://guides.rubygems.org/trusted-publishing/

## Release flow

1. Prepare and review the release on `main`.
2. Run the canonical spec, lint, and package gates.
3. Obtain explicit Sheriff authorization for the specific version.
4. Push only the authorized `vMAJOR.MINOR.PATCH` tag.
5. GitHub Actions runs `.github/workflows/release.yml`.
6. The Sheriff reviews the exact tag target and approves the `release` environment.
   The workflow requires a stable version tag reachable from `origin/main`, checks
   that it matches `Abbu::VERSION`, and reruns the package gates before publishing
   with `rubygems/release-gem@v1` using OIDC.
7. Verify the RubyGems release and provenance against the accepted source.

The workflow does not bump versions, create tags, or grant release authority.

For repeatable candidate verification, run:

```bash
SOURCE_DATE_EPOCH=$(git show -s --format=%ct HEAD) bin/package
```

The workflow sets that same value for
both verification and the action's `bundle exec rake release` build. Compare the
published gem with the accepted source; never move a release tag or republish a
version to recover from a failed run. A failed run after upload requires checking
RubyGems before retrying. Do not replay the already published `v0.4.0` tag.

Normal PR CI remains the Ruby 3.3/3.4/4.0 review gate; the release job repeats
spec/lint/package checks on the Ruby 3.3 compatibility floor. Local/manual pushes
are not the default path. No API key secret is needed, and Trusted Publisher
registration is not itself permission to publish a new version.

## Repository standard

Use this pattern by default for our other GitHub-hosted RubyGems: OIDC Trusted
Publishing, a protected `release` environment, exact version-tag verification,
canonical repository checks, and no long-lived RubyGems publishing secret.

See [AGENTS.md](../AGENTS.md), [contribution workflows](CONTRIBUTING.md), and
[README](../README.md). This infrastructure PR does not authorize a release.

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
