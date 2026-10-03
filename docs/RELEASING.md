<!-- docs/RELEASING.md -->

# GitHub-Hosted Releases

[Back to README](../README.md) · [Contributing](CONTRIBUTING.md)

Release automation executes Sheriff authorization; green checks do not grant it.
Never dispatch a publication run or approve its environment without approval for
the exact version and commit. No local personal access token or RubyGems API key
is required for the browser-driven path.

## One-Time Configuration

- RubyGems Trusted Publisher: owner `scarver2`, repository `abbu`, workflow
  `release.yml`, environment `release`.
- GitHub `release` environment: required reviewer `scarver2`, administrator
  bypass disabled, exact branch `main` and tags `v*` allowed. If the Sheriff
  starts and approves the run, self-review prevention must remain unchecked.
- Permit the workflow's job-scoped permissions. Do not broaden the repository's
  default token permissions or add a long-lived publishing secret.
- Any tag ruleset must permit the authorized Actions tag-creation job. If it
  blocks creation, stop for owner review; do not bypass protection or add a PAT.

## Release From The Browser

1. Merge reviewed release changes and a dated changelog. Verify accepted CI.
2. Open **Actions → Release gem → Run workflow**, selecting branch **main**.
3. Enter the approved numeric version (without `v`) and its complete lowercase
   40-character commit SHA. An earlier accepted commit is allowed; a branch name
   or abbreviated SHA is not. The workflow itself must be run from `main`.
4. The run displays the version/SHA and verifies ancestry, version, dated
   changelog, and any existing tag. Specs, lint and package checks run on the
   exact candidate across Ruby 3.3, 3.4 and 4.0 before a tag can be created.
5. Approve **Authorize and tag exact candidate** in the protected environment.
   It creates only `vVERSION`, never moves a tag, and accepts a matching existing
   tag for recovery. Check the run's version and SHA before approving.
6. Approve **Publish approved gem** if GitHub requests a second environment
   review. Separate jobs intentionally isolate Contents-write from OIDC rights.
   Publishing checks the tag again, reruns specs/lint/package, and uses RubyGems
   Trusted Publishing. The publishing job has only Contents-read and OIDC-write.
7. Verify the published version on RubyGems and inspect its provenance and run
   result. The action waits for registry propagation; the run summary records
   the version and source commit. This workflow does not create a GitHub Release.

The retained external `v*` tag-push path runs the same gates when the tagged
commit contains this workflow. Older tagged commits use their historical
workflow; manual dispatch from current `main` can release an older accepted
candidate without changing that candidate. Newly created Actions tags do **not**
trigger another push workflow: this run proceeds directly to publishing.

## Safe Checks And Recovery

`bin/release-check VERSION FULL_COMMIT_SHA` is read-only. Run in a clean checkout
after fetching `origin/main` and tags; it checks those local references and does
not fetch, create tags, or publish. The workflow fetches immediately before it.
This command checks source invariants, not tests or publication authority.

For a reproducible local package comparison, use
`SOURCE_DATE_EPOCH=$(git show -s --format=%ct HEAD) bin/package` in the accepted
checkout. The workflow uses the candidate commit timestamp for verification and
the publishing action's build. Do not replay previously published tags, including
`v0.4.0`.

If a job fails, inspect its logs. An existing matching tag permits retry after
fixing infrastructure, but a conflicting tag is a hard stop. Never delete or
move a release tag. If RubyGems already has that version, verify its provenance
before doing anything else: rerunning publication is not an idempotent no-op.
There is no automatic yank, overwrite, version increment, or rollback.

The first workflow PR must be merged before the Run workflow button appears.
That merge does not authorize releasing its commit. Reconfirm the exact candidate
if it differs from the Sheriff's previously approved SHA. Workflow-only tooling
does not change the gem's public version.

## References

- [GitHub token event behavior](https://docs.github.com/en/actions/concepts/security/github_token)
- [RubyGems Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
