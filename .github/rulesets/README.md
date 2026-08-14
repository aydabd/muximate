# Ruleset templates

These files are repository ruleset API payload templates. Apply them with the repository rulesets
REST endpoint (for example, `gh api --method POST /repos/OWNER/REPO/rulesets --input FILE`) or
recreate them under
**Settings → Rules → Rulesets**, then verify the resulting API object. GitHub status-check names
must match the check-run names shown by this repository; adjust those entries if a different
repository uses different workflow or job names.

## Branch template

[`branch-main.json`](branch-main.json) applies only to `refs/heads/main`. It requires pull requests,
one approval, resolved review threads, signed commits, linear history, squash merges, the listed
CI checks, and CodeQL results. It intentionally has no required deployment rule: requiring the `development`
deployment before updating `main` would be circular because the automatic development release is
created after `main` changes.

## Tag template

[`tags-semver.json`](tags-semver.json) applies to `v*` tags, including development prereleases. It
prevents deletion and rewriting and disallows user bypass. The GitHub Actions integration is the
only bypass actor so Release Please and the protected production promotion workflow can create the
immutable tags. Keep the production workflow limited to `main` and protect its `production`
environment with required reviewers.

## Environment settings

Configure these separately in **Settings → Environments**:

- `development`: deployment branch `main`, no manual dispatch workflow, no production credentials.
- `production`: deployment branch `main`, required reviewer, prevent self-review, and administrator
  bypass disabled.

## Optional controls

Enable these only after the corresponding workflow is present and producing results on every pull
request:

- **Code quality results**: not enabled here because this repository has no GitHub Code Quality
  producer.
- **Code coverage**: not enabled here because no coverage upload and threshold policy exists.
- **Copilot code review**: enabled for non-draft pull requests on push when the author has Copilot
  access and available quota; it is review assistance, not a replacement for human approval.
- **Required deployments**: do not require `development` before merging to `main`; the development
  release is created automatically after `main` changes. Protect `production` with its environment
  reviewer and branch policy instead.

The tag template restricts both creation and updates to the GitHub Actions integration. Users cannot
manually create or rewrite release tags, while the release workflows can create them.

The `release-please.yml` workflow automatically handles development prereleases. Only
`release.yml` can promote one to production, and it validates the source tag and commit ancestry.
