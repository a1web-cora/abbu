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

Also create/configure the GitHub environment named `release` with the desired
deployment protection/approval rules.

Official RubyGems guidance:
https://guides.rubygems.org/trusted-publishing/

## Release flow

1. Prepare and review the release on `main`.
2. Run the canonical spec, lint, and package gates.
3. Obtain explicit Sheriff authorization for the specific version.
4. Push only the authorized `vMAJOR.MINOR.PATCH` tag.
5. GitHub Actions runs `.github/workflows/release.yml`.
6. The workflow reruns the package gates, verifies the tag matches
   `Abbu::VERSION`, then publishes with `rubygems/release-gem@v1` using OIDC.
7. Verify the RubyGems release and provenance against the accepted source.

The workflow does not bump versions, create tags, or grant release authority.

## Repository standard

Use this pattern by default for our other GitHub-hosted RubyGems: OIDC Trusted
Publishing, a protected `release` environment, exact version-tag verification,
canonical repository checks, and no long-lived RubyGems publishing secret.
