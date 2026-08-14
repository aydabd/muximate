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

[`tags-semver.json`](tags-semver.json) applies to every tag. It prevents deletion and rewriting and
requires verified signatures. GitHub currently rejects the `tag_name_pattern` rule on this
repository-owned ruleset through the repository API (`422 Invalid rule 'tag_name_pattern'`), so this
portable repository payload intentionally omits that unsupported rule. The release workflows enforce
the tag contract before creating or promoting releases: stable `vMAJOR.MINOR.PATCH` and development
`vMAJOR.MINOR.PATCH-dev.N`.

If this project is moved under an organization or enterprise ruleset scope, add the official
organization-level `tag_name_pattern` rule there as a stricter server-side control. The template
deliberately has no bypass
actor because the built-in `github-actions[bot]` identity is not a valid portable ruleset bypass
actor. This portable template does not restrict tag creation or updates because the current release
workflows use `GITHUB_TOKEN`; those restrictions require a separate installed release identity.
Deletion and force-update protections remain enabled. Keep the production workflow limited to `main`
and protect its `production` environment with required reviewers.

## Environment settings

Configure these separately in **Settings → Environments** or with the payloads and API commands in
[`../environments/README.md`](../environments/README.md):

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

If stronger creation/update protection is needed later, add a real installed GitHub App or dedicated
release service account as a bypass actor and migrate the release workflows to that identity first.

The `release-please.yml` workflow automatically handles development prereleases. Only
`release.yml` can promote one to production, and it validates the source tag and commit ancestry.
