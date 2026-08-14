# Environment configuration

GitHub does not provide one portable environment-import JSON format equivalent to repository
ruleset import. The environment endpoint configures the environment protection settings, while
custom deployment branch patterns use a separate endpoint. Environment secrets are separate again
and are intentionally not represented here.

These payloads are suitable for `gh api` or the GitHub REST API. They use `main` as the only
deployment branch. The production reviewer ID is the current `aydabd` user ID; replace it when
reusing the template in another repository.

## Apply the settings

From the repository root:

```sh
repo=aydabd/muximate
api_version=2026-03-10

gh api --method PUT \
  -H "X-GitHub-Api-Version: $api_version" \
  "/repos/$repo/environments/development" \
  --input .github/environments/development.json

gh api --method POST \
  -H "X-GitHub-Api-Version: $api_version" \
  "/repos/$repo/environments/development/deployment-branch-policies" \
  -f name=main -f type=branch

gh api --method PUT \
  -H "X-GitHub-Api-Version: $api_version" \
  "/repos/$repo/environments/production" \
  --input .github/environments/production.json

gh api --method POST \
  -H "X-GitHub-Api-Version: $api_version" \
  "/repos/$repo/environments/production/deployment-branch-policies" \
  -f name=main -f type=branch
```

The branch-policy POST returns `303` when the same policy already exists. Treat that as already
configured and verify it with:

```sh
gh api "/repos/$repo/environments/development/deployment-branch-policies"
gh api "/repos/$repo/environments/production/deployment-branch-policies"
```

For this solo-maintainer repository, `prevent_self_review: false` keeps the production approval
operable by `aydabd`. The production workflow remains manual and the environment reviewer is still
required. When a second independent reviewer is available, set `prevent_self_review` to `true` and
use that reviewer or team instead.

The environment API does not expose every UI control as a portable JSON field. In particular,
verify the administrator-bypass setting in **Settings → Environments → Protection rules** after
applying the payload. Keep administrator bypass disabled for production unless it is an explicitly
documented emergency procedure.

See [GitHub environment API documentation](https://docs.github.com/en/rest/deployments/environments)
and [deployment branch policy API documentation](https://docs.github.com/en/rest/deployments/branch-policies).
