# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.3.2] - 2026-10-08

### Fixed
- `deploy`, `cleanup` and `scheduled-cleanup`: pin uv to 0.12.17 in the `setup-uv` step. Without a version, setup-uv resolves "latest" through the GitHub API whenever the caller's workspace root has no `uv.toml` or `pyproject.toml`; on a Forgejo runner `github.token` is not valid there, so the lookup ran anonymously and failed intermittently on the rate limit
- `deploy`, `cleanup` and `scheduled-cleanup`: turn off the setup-uv cache. uv only installs zad-cli here, so the cache had nothing to hold and every run warned that its dependency glob matched no files

### Internal
- Dependabot also scans `deploy/`, `cleanup/` and `scheduled-cleanup/`. With only `/` it read `.github/workflows` and a root `action.yml`, so the actions the composite actions pull in (such as `astral-sh/setup-uv`) never got an update
- yamllint runs with `--strict` from a shared `.yamllint.yaml`, in pre-commit and CI alike; CI now lints every YAML file instead of a hand-picked list that missed `scheduled-cleanup`. `.editorconfig` sets the same 150-column limit for YAML
- The pre-commit.ci settings moved into `.pre-commit-config.yaml`: pre-commit.ci only reads the `ci:` key there, so `.pre-commit-ci.yaml` was ignored
- The smoke tests pass `skip-bot-prs: 'false'` to every action call. On its default the actions skip themselves when the PR author is a bot, so every assertion read an empty output and the suite went red on a Dependabot PR while testing nothing. Now that Dependabot scans the composite actions, that is every bump it opens. A `bot-check` job holds the skip logic itself, against the step's own script: a PR author cannot be faked in a workflow event, so it is extracted the way `deploy-log` extracts the deploy step

## [4.3.1] - 2026-10-07

### Changed
- The plugin and the actions share one version line. `.plugin/plugin.json` had stood at 1.2.0 since February while the actions moved through four minors to 4.3.0, so the marketplace installed a plugin that claimed a version from before seven commits and 597 lines of skill changes. The plugin version is now the tag version, which makes the marketplace follow a release of either without anyone remembering a second number
- The five skills no longer pin `model: sonnet`. A pinned model overrides the choice of whoever runs the skill, which is wrong for reference content: these skills describe ZAD deployment, linting and releases, they are not an agent loop with a cost or latency profile worth constraining. Nothing measured that sonnet was sufficient here, and a hardcoded model name is five places to edit when the naming changes, with nothing to signal that it went stale. The six plugins in the developer.overheid.nl marketplace dropped theirs for the same reason

### Internal
- `scripts/bump_version.py` sets the version in `.plugin/plugin.json` and regenerates the two platform manifests, so the three cannot drift apart by hand
- The release workflow refuses a tag whose version does not match `.plugin/plugin.json`, and names the helper in the error. A forgotten bump now fails the release before it publishes, instead of shipping a plugin that claims an older version — which is how the 1.2.0 gap went unnoticed for six months. The check runs before the release is created, so the existing rollback step takes the tag back down

## [4.3.0] - 2026-10-07

### Upgrading
A `deploy` step can now fail where it used to pass, in two cases, both of which were a green step over a rollout that had not happened:

- The deployment task was handed over to a newer task covering its deployment scope, and *that* task ended `failed` or `cancelled`. Previously the hand-over was invisible and the step reported success over addresses that nothing answered on; it now fails and names the task.
- The hand-over ended with changes saved but not rolled out. The step fails with the count and `zad project refresh`, rather than publishing addresses the project file asks for.

Nothing is renamed or removed, and a deploy that is not superseded takes exactly the path it did before.

### Fixed
- `deploy`: a superseded deployment task is treated as the hand-over it is. A newer task whose deployment scope covers this one's, a second deploy of the same deployment or a project-wide change, takes the remaining ArgoCD wait over; the waiting task ends as *completed* with `result.status: superseded`, and zad-cli exits 0 on that. Deploys of different deployments have disjoint scopes and never supersede each other. The action now follows `superseded_by.task_id` with `zad task wait` until a task finishes the work, and names the hand-over in the log as a notice. A taking-over task that ends `failed` or `cancelled` fails the step and names the task; a chain that never ends stops on a cap of 10 hand-overs
- `deploy`: a deploy whose hand-over ends with changes that are saved but not rolled out fails the step with the count and `zad project refresh`, instead of reporting success over addresses that the project file asks for and nothing answers on yet
- `deploy`: `Deployment successful` is printed once the URLs are in hand instead of on the create's exit code, so it can no longer precede an error in the log. The line that follows the create now says `Deployment task accepted`, which is what is true at that point

### Internal
- The reading of a task result's `status` lives in one place, `task_status` in `scripts/zad-common.sh`, instead of once there and once verbatim in `deploy/action.yml`. Two definitions of "what counts as superseded" could drift apart, and the way they would is silent: the deploy step's own copy stops recognising a hand-over that the helper still follows, which turns "saved but not rolled out" back into a green deploy
- `deploy`: both readings of the waiting count guard the nested index and not only the document around it. `type == "object"` answers for the task result, not for its `pending_rollout`, and `jq empty` accepts an array or a bare string as a `project pending` answer, so a count of another shape made `.count` a jq error — which, in a bare assignment under `set -eo pipefail`, failed the step with no annotation at all: on the fallback over the one count that branch exists to treat as best effort, and on the task result immediately after the hand-over had been reported as finished. The same suppression is on the two readings of `superseded_by` in `resolve_task_handover`, where a result of the wrong shape already ended in the message it should but leaked jq's own error lines into the log first
- The `deploy` smoke job covers the hand-over branches that had no case of their own: the waiting count read off the final task result rather than asked for again, the scoping of that check to a hand-over so somebody else's saved change cannot fail a plain deploy, a `cancelled` successor, a superseded result that names no successor, a task id that could forge an annotation, a count that cannot be read at all, and a count that comes back as something other than an object — on the `project pending` answer and on the final task result alike. `tests/stubs/zad` gained `ZAD_STUB_PENDING_EXIT`, which makes a failing `project pending` testable
- A `zad-common` smoke job calls `resolve_task_handover` directly, with its stderr captured. The promises the hand-over makes are about what it *says* — that it reads as a notice and not a warning, that a failure names the task that took over, that the cap ends with a message — and none of that is readable from the `deploy` job, because a step cannot read the job log it is running inside. The job also covers the branches the deploy path cannot reach: a result that is not JSON passing through untouched, both spellings of `cancelled`, a hostile `task_type`, a wait that exits 0 with a half-written document, a `superseded_by` that is not an object at all — which must end in the message that names nobody, without jq's own error line beside it — and the readings `task_status` gives for a bare string, an array and no input at all. `tests/stubs/zad` gained `ZAD_STUB_TASK_WAIT_RAW` for the half-written document, which `pretty` refuses to produce on purpose
- The `deploy` smoke job also pins a `pending_rollout.count` of `0` on the final task as an answer rather than a missing one: it is read off the result, and the project is not asked a second time
- A `deploy-log` smoke job runs the deploy step's own script with its output captured, because the lines it is judged on are annotations in the job log and no later step can read the log it is running inside. It pins what the waiting count makes the step *say* and not only what it makes the step do: the count itself and `zad project refresh` in the failure, the cause of a count that could not be read in the warning, and a count that is not a number failing nothing rather than being reported as that many changes waiting. The step's script is extracted from `deploy/action.yml` by name, and the extraction is checked against anchors from its head, middle and tail so it cannot silently come back empty or half
- `deploy`: when the waiting count cannot be read at all, the warning names the cause. The CLI's diagnosis is the document on stdout and its stderr is dropped on that call, so the bare warning left a reader unable to tell a one-off incident from an API key that structurally lacks the right to list pending changes — and in that second case this check is dead in that project, which makes "saved but not rolled out" a green deploy again
- The `debug-deploy` skill answers the hand-over failures: a successor that ended `failed` or `cancelled`, changes saved but not rolled out, the hop cap, a hand-over that names no successor, and the warning over a waiting count that could not be read. The skill is where a reader takes an `::error::` line from a deploy log, and these lines had no entry. `deploy/README.md` also says that each wait is bounded by `task-timeout` on its own, so a chain of hand-overs can outlast a single task's timeout
- The five skill descriptions are one quoted line each instead of a YAML block scalar. The text is unchanged, but `grep ^description:` and any tool that reads the first line saw `>-` and an empty value, which is how a review of the descriptions across the marketplace plugins concluded these skills had none. `generate-workflow` also lost the trigger `'hoe gebruik ik zad-actions'`, which `'setup zad'` and `'integratie'` already cover, bringing every description under 200 characters

## [4.2.0] - 2026-09-11

### Upgrading
Two outputs change meaning in this release. Nothing is renamed or removed, so nothing fails to parse, but a workflow that branches on either one will take a different path than it did on 4.1.x — and because the `v4` tag moves to this release, that happens without any change on your side.

- `zad-deleted` is `false` for a deployment that was already gone, where 4.1.x reported `true`. Earlier versions of this README suggested `if: steps.cleanup.outputs.zad-deleted != 'true'` to flag an incomplete cleanup; that condition now also fires for the already-gone case, where there is nothing to clean up by hand. Branch on `failure()` instead — the action already fails the step on a real delete error.
- `deploy`'s `url` output is the first declared component that *has* a public address, rather than the first declared component. On 4.1.x a first component without an ingress produced the literal string `null`; the step now picks the next component that does have an address, and fails outright when no component has one. A deploy of components that are all ingress-less used to pass with `url=null` and now stops.

### Changed
- Bump zad-cli from v0.8.0 to v0.12.0. Verified against the v0.12.0 binary itself: `deployment create` still takes `--component`, `--image`, `--file`, `--clone-from`, `--force-clone`, `--domain-format`, `--subdomain`, `--base-domain` and `--yes`; `deployment delete` still takes `--yes` and `--ignore-not-found` and still answers an absent deployment with `{"deleted": false, "reason": "not_found"}` as a single JSON document; and `Diagnosis` still carries the `fault`, `headline`, `summary`, `next_steps` and `status_code` fields `report_zad_error` reads
- `cleanup` and `scheduled-cleanup`: `zad-deleted` now reports `false` for a deployment that was already gone. The API answers a delete for an absent deployment by completing the task with `deleted: false` rather than with a 404; v0.8.0 read that as a successful deletion and set `zad-deleted=true`. Workflows that branch on `zad-deleted == 'true'` will see the corrected value
- `deploy`: multi-component deploys pass the component list as a manifest on stdin (`--file -`) instead of `--components`. This is required, not cosmetic — zad-cli removed `--components` in v0.10.0
- `deploy`: component URLs come from `zad deployment url` instead of being dug out of `.urls.<deployment>.urls.<component>` in the deploy's raw task result, a nesting the CLI never promised
- `deploy`: the `url` output is the first declared component that *has* a public address, rather than simply the first component. A component without an ingress has no address, and publishing `null` would send the next step to somewhere that never existed

### Internal
- `install_zad_cli` prefers the release binary for the platform (one verified download) and falls back to the source install when there is no asset or the download fails. Linux arm64 is included, which zad-cli started publishing in v0.11.0
- `install_zad_cli` exports `~/.local/bin` directly when the binary branch ran, instead of asking `uv tool bin`: on a self-hosted runner `UV_TOOL_BIN_DIR` or `XDG_BIN_HOME` can point that elsewhere, leaving the binary off PATH
- Checksum verification works on macOS too: it uses `shasum -a 256` where `sha256sum` is absent, and passes `--ignore-missing` in both cases because `SHA256SUMS` covers every platform's asset while only one is downloaded

## [4.1.1] - 2026-09-09

### Fixed
- `cleanup`, `scheduled-cleanup`: environment names were URL-encoded with a trailing newline (`pr123%0A`), so the GitHub-environment delete always returned 404 regardless of token permissions; every closed PR left its environment behind (with only a per-run warning) while the job stayed green
- `cleanup`: the delete-result check parses the status line `gh api --include` actually emits (`HTTP/2.0 204`); previously every outcome, including a successful delete, fell into the generic failure branch with `deleted=false`
- `cleanup`: a 404 on delete is verified with the regular `github-token` before being treated as "already deleted" — GitHub answers 404 instead of 403 for an admin token that lacks access, which previously read as success
- `cleanup`: the GitHub environment is kept when the ZAD deployment could not be deleted, so `scheduled-cleanup` can still discover and retry it; reported as new reason `zad_delete_failed`
- `scheduled-cleanup`: a failed GitHub-environment delete now marks the environment as not cleaned, instead of still counting it in "Successfully cleaned N environment(s)" / `cleaned-count`
- `scheduled-cleanup`: the environment delete distinguishes 204/404/401/403/other by status (with the same 404 access check as `cleanup`), so a benign already-gone environment no longer warns "Failed to delete"
- `scheduled-cleanup`: the environment and container image are kept when the ZAD delete failed in the same pass, mirroring the `cleanup` guard — the environments listing is the only discovery mechanism for retries
- `cleanup`: the container image is also kept while the ZAD deployment still exists (a live deployment may still pull it)
- `cleanup`, `scheduled-cleanup`: a 404 that cannot be verified — the read call failed, or no `github-token` was available to make it — is reported as `unknown` instead of being treated as "already deleted"; HTTP 401 now reports `permission_denied` instead of `unknown`
- `scheduled-cleanup`: once the admin token is established as broken, the environments skipped for the rest of the run say so, instead of being silently counted as not cleaned
- `scheduled-cleanup`: the container image being kept because the ZAD delete failed is now logged like the environment keep, instead of the step passing silently
- `zad-common`: the delete-result `jq` parse gets the same non-JSON fallback as its siblings, so unexpected zad output no longer aborts the step before outputs are written

### Added
- `cleanup`: new `github-env-delete-reason` output (`not_found`, `permission_denied`, `zad_delete_failed`, `unknown`; empty on success) so callers can tell "already gone" from "admin token broken"

## [4.1.0] - 2026-08-05

### Added
- `deploy`: new `health-status-codes` input to control which HTTP codes the `wait-for-ready` check accepts. Takes single codes and ranges (e.g. `200,204` or `200-399,401`)

### Fixed
- `deploy`: the `wait-for-ready` check no longer fails deployments that sit behind authentication. `401` and `403` now count as ready by default, since an auth challenge proves the app is serving; previously only `200-399` passed and such deployments timed out

### Internal
- Dependabot waits five days before proposing a new action version (`cooldown.default-days: 5`), raising the built-in three-day default so a compromised release has more time to be spotted. Security updates are exempt and still arrive immediately. No effect on the published actions.

## [4.0.6] - 2026-06-19

### Changed
- Bump zad-cli from v0.6.0 to v0.8.0 (admin orphan-report/orphan-confirm commands, and a new structured error diagnosis layer with source labels, next-step suggestions and CI exit codes 1/2/3)
- Update `report_zad_error` to read zad-cli's new diagnosis JSON (`headline`, `summary`, `next_steps`) so error annotations surface the cause and remediation; falls back to the old flat `error` field for version skew. Network/unknown failures (HTTP status 0) now keep their message instead of dropping it.

## [4.0.5] - 2026-05-19

### Changed
- Bump zad-cli from v0.5.0 to v0.6.0 (restore deployment, pvc-snapshots and admin commands, async admin delete, syncs with upstream ZAD API changes from 2026-05-18; zad-cli drops the `-s` alias and renders list commands as tables, but the actions do not parse that output so no behaviour change here)

## [4.0.4] - 2026-05-07

### Changed
- Bump zad-cli from v0.3.0 to v0.5.0 (v2 deployment read endpoints, mutation confirmations, faster `describe`, plus error/validation fixes)
- Bump `softprops/action-gh-release` from v2 to v3 in release workflow (moves release job to Node 24 runtime)

## [4.0.3] - 2026-04-21

### Changed
- Bump zad-cli from v0.2.1 to v0.3.0 (syncs with upstream ZAD API changes from 2026-04-20)

## [4.0.2] - 2026-04-21

### Changed
- Bump zad-cli from v0.1.2 to v0.2.1 (fixes crash on empty task-polling response, RijksICTGilde/zad-cli#11)

## [4.0.1] - 2026-04-07

### Changed
- Bump zad-cli from v0.1.1 to v0.1.2
- Update all documentation references from `@v3` to `@v4`
- Update root README API section to reflect zad-cli usage

## [4.0.0] - 2026-04-07

### Changed
- **all actions**: Replace curl+bash API layer with [zad-cli](https://github.com/RijksICTGilde/zad-cli) (pinned to v0.1.1)
  - **deploy**: ~200 lines of curl/jq/polling replaced by single `zad deployment create` call
  - **cleanup**: ~80 lines of curl/polling replaced by single `zad deployment delete` call
  - **scheduled-cleanup**: same inline curl/polling replaced by shared `zad_delete_deployment` helper
  - Retry logic, task polling, and error handling now delegated to the CLI
  - Net reduction: ~310 lines of duplicated bash
- **scripts/zad-common.sh**: Rewritten — `curl_with_retry`, `poll_task`, and `build_poll_url` replaced by `install_zad_cli`, `validate_input`, `validate_integer`, `report_zad_error`, and `zad_delete_deployment`
- **all actions**: ZAD configuration now uses `ZAD_*` env vars (`ZAD_API_URL`, `ZAD_PROJECT_ID`, `ZAD_MAX_RETRIES`, `ZAD_RETRY_DELAY`, `ZAD_TASK_TIMEOUT`, `ZAD_TASK_POLL_INTERVAL`) consumed directly by the CLI

### Added
- **all actions**: `astral-sh/setup-uv` step to ensure `uv` is available on GitHub runners
- **all actions**: `$HOME/.local/bin` added to `GITHUB_PATH` after install so `zad` is available across steps

### Fixed
- **all actions**: `validate_input` and `validate_integer` now `exit 1` instead of `return 1` (validation failures were silently ignored without `set -e`)
- **scheduled-cleanup**: Add missing `validate_input "project-id"` check (was present in deploy and cleanup but missing here)
- **all actions**: Improve error message when CLI fails with no HTTP status code

## [3.2.0] - 2026-03-20

### Added
- **deploy** action: Optional domain configuration inputs (`domain-format`, `subdomain`, `base-domain`) for custom hostname generation
  - Input validation consistent with existing fields
  - Early-fail when `domain-format` contains "subdomain" but `subdomain` is not set

### Changed
- **deploy**: URL fallback removed — action now fails with an error when the API response does not include a URL, instead of silently constructing one

## [3.1.0] - 2026-03-19

### Added
- **cleanup**: Multi-container deletion support
  - New `containers` input: JSON array of `[{"org": "...", "name": "...", "tag": "..."}]`
  - Deletes all container images in a single cleanup call
  - When set, `container-org`/`container-name`/`container-tag` inputs are ignored
  - Best-effort: each container deletion is independent
  - Backward compatible: existing single-container inputs continue to work

### Fixed
- **deploy**: Fix multi-component `urls` output writing multi-line JSON to `GITHUB_OUTPUT` — use `jq -c` for compact single-line output

## [3.0.0] - 2026-03-19

### Changed
- **BREAKING**: Migrate from synchronous V1 API to async V2 API
  - Deploy, cleanup, and scheduled-cleanup now use `/api/v2/` endpoints
  - Operations return a task ID immediately (HTTP 202) and are polled until completion
  - Task progress (percentage, current step) is logged during polling
  - Users must update from `@v2` to `@v3` to use this version
- **all actions**: Extract `curl_with_retry`, `poll_task`, and `build_poll_url` to shared `scripts/zad-common.sh`
- **all actions**: Poll URL construction now handles absolute URLs from the API (not just relative paths)
- **cleanup, scheduled-cleanup**: Failed delete tasks now log `::error::` instead of `::warning::` (consistent with deploy)

### Added
- **all actions**: New `task-timeout` input (default: `300`s) — maximum wait for async task completion
- **all actions**: New `task-poll-interval` input (default: `3`s) — interval between task status polls
- **deploy** action: Multi-component deployment support
  - New `components` input: JSON array of `[{"name": "...", "image": "..."}]`
  - Deploys all components in a single API call
  - When set, `component` and `image` inputs are ignored
  - New `urls` output: JSON object mapping component names to URLs
  - `url` output returns the first component's URL for backward compatibility
  - PR comment combines all component URLs into a single comment
  - `component` and `image` inputs are now optional (at least one approach must be provided)

### Fixed
- **deploy**: PR comment URL parsing now uses tab delimiter instead of `=`, preventing breakage when URLs contain query parameters
- **all actions**: `poll_task()` now fails fast on 4xx HTTP errors instead of retrying until timeout
- **scheduled-cleanup**: Added missing validation for `task-timeout` and `task-poll-interval` inputs

## [2.4.0] - 2026-03-03

### Added
- **deploy** action: Per-component PR comments
  - Each component now gets its own PR comment (e.g. `## 🚀 Preview Deployment — web`)
  - No more overwriting: deploying multiple components via matrix strategy creates separate comments
  - Re-deploying a component updates only its own comment
  - Cleanup action still removes all component comments (matches on shared header prefix)

### Fixed
- **deploy** action: Use URL from API response instead of hardcoded construction
  - Projects with `subdomain` configuration (e.g. deployment-name mode) now get the correct URL
  - Falls back to constructed URL with a warning if API response doesn't include URLs

## [2.3.0] - 2026-02-19

### Added
- **deploy** action: New `path-suffix` input to append a path to the deployment URL (e.g. `/docs/`)
  - The suffix is included in the `url` output, PR comment, and QR code
  - Handles leading/trailing slashes gracefully

## [2.2.1] - 2026-02-19

### Fixed
- **scheduled-cleanup**: Allow `$` regex anchor in `environment-pattern` and `pr-number-pattern` inputs (was incorrectly blocked as a dangerous shell character)

## [2.2.0] - 2026-02-19

### Added
- **deploy**, **cleanup**, and **scheduled-cleanup** actions: Retry with exponential backoff for transient ZAD API errors
  - New inputs: `max-retries` (default: `3`), `retry-delay` (default: `2`)
  - Retries on network errors (HTTP 000), rate limits (429), and server errors (500-504)
  - Does not retry on auth errors (401, 403) or not found (404)
  - Backoff: 2s → 4s → 8s (worst-case 14s extra)
  - Retry logic extracted into shared `curl_with_retry` bash function
  - Note: only ZAD API calls are retried; GitHub API calls use best-effort error handling
- **scheduled-cleanup** action: Periodically find and clean up stale PR environments
  - Scans GitHub environments matching a configurable regex pattern
  - Checks PR state and marks closed/merged PRs as stale
  - Optional age-based cleanup via `max-age-days`
  - Dry-run mode for safe testing
  - Cleans up ZAD deployments, GitHub deployments/environments, and container images
  - Smart rate limiting: reads `X-RateLimit-Remaining` header and only pauses when approaching the limit (replaces blind 0.5s delay)
  - Input validation for `environment-pattern` and `pr-number-pattern` (including sed `e` flag injection protection)
  - `cleaned-count` output defaults to `0` when no cleanup is needed
  - Compact JSON output for `stale-environments` to prevent GITHUB_OUTPUT corruption
  - Safe date parsing: warns and skips age check instead of falling back to epoch 0
  - Container deletion uses `2>/dev/null` instead of `2>&1` to prevent stderr leaking into captured output

### Changed
- **deploy**, **cleanup**: ZAD API calls now retry 3 times by default on transient errors (was 0).
  This adds up to 14s extra delay on persistent failures. Set `max-retries: '0'` to restore previous fail-fast behavior.
- **deploy**, **cleanup**: `github-token` default now consistently quoted as `'${{ github.token }}'`

### Fixed
- **scheduled-cleanup**: `cleaned-count` no longer counts 404 (already deleted) as successfully cleaned
- **scheduled-cleanup**: Admin token no longer leaks into subsequent operations if environment deletion fails (uses subshell)
- **scheduled-cleanup**: `pr-number-pattern` is now validated in both find-stale and cleanup steps (defense-in-depth)

## [2.1.0] - 2026-02-18

### Added
- **deploy** and **cleanup** actions: Skip bot PR deployments by default
  - New input: `skip-bot-prs` (default: `true`)
  - New output: `skipped`
  - Detects bots via GitHub user type and known bot list (dependabot, renovate, pre-commit-ci, github-actions)
  - Set `skip-bot-prs: 'false'` to restore previous behavior
  - Supports both `pull_request` and `pull_request_target` events

### Security
- CI workflow: Add explicit `permissions: contents: read` to all jobs to comply with GitHub security best practices

## [2.0.1] - 2026-02-06

### Fixed
- **deploy** QR code not displaying in PR comments (switched from base64 PNG to text-based UTF8 format)
- **cleanup** action: Handle deletion of last tagged package version by deleting entire package when needed

### Changed
- Update all documentation examples to use `@v2` instead of `@v1`
- SECURITY.md: Mark v1.x.x as end of life, v2.x.x as supported

## [2.0.0] - 2026-02-02

### Added
- **cleanup** action: PR comment delete feature
  - Delete the deploy PR comment when PR is closed (default: enabled)
  - New inputs: `delete-pr-comment`, `comment-header`
  - New output: `pr-comment-deleted`

### Removed
- **BREAKING** `cleanup` action: `update-pr-comment` input (use `delete-pr-comment` instead)
- **BREAKING** `cleanup` action: `pr-comment-updated` output (use `pr-comment-deleted` instead)

### Migration from v1

If you use the cleanup action with `update-pr-comment`, update your workflow:
- Replace `update-pr-comment: true` with `delete-pr-comment: true`
- The output `pr-comment-updated` is now `pr-comment-deleted`
- Note: `delete-pr-comment` defaults to `true`, so you can remove it if you want the comment deleted

## [1.3.0] - 2026-02-02

### Added
- **deploy** action: Wait for ready feature
  - Wait for deployment to be reachable before continuing
  - New inputs: `wait-for-ready`, `health-endpoint`, `wait-timeout`, `wait-interval`
  - Polls deployment URL until HTTP 2xx/3xx or timeout
  - PR comment only appears after deployment is healthy (when combined with `comment-on-pr`)
- **deploy** action: QR code in PR comment
  - New input: `qr-code` (default: `false`)
  - QR code for easy mobile testing of preview deployments
  - Generated locally using `qrencode` (no external API calls, privacy-friendly)
- `.editorconfig` for consistent editor formatting
- `.github/dependabot.yml` for automated GitHub Actions updates
- `.gitignore` for local settings and Claude plans
- `.claude/` configuration for AI assistant (coding rules, skills, workflow)

### Changed
- `.pre-commit-config.yaml`: require minimum version 4.5.0
- `CONTRIBUTING.md`: simplify setup with `uv` instead of `pip`
- `release.yml`: verify CHANGELOG entry exists, rollback tag on failure
- **deploy** and **cleanup** actions: `github-token` now defaults to `github.token`
  - No longer necessary to explicitly pass `github-token: ${{ secrets.GITHUB_TOKEN }}`
  - Only needed when using a custom PAT for cross-repository operations
- Bump `actions/checkout` from v4 to v6

### Internal
- Added justfile for common development tasks
- Added pre-commit.ci configuration (weekly autoupdates, skip duplicates with CI)

## [1.2.0] - 2026-01-22

### Added
- **cleanup** action: PR comment update feature
  - Update the deploy PR comment to show cleanup status when PR is closed
  - New inputs: `update-pr-comment`, `comment-header`
  - New output: `pr-comment-updated`

## [1.1.0] - 2026-01-22

### Added
- **deploy** action: PR commenting feature
  - Automatically post/update a comment on PRs with the deployment URL
  - New inputs: `comment-on-pr`, `github-token`, `comment-header`
  - Upsert behavior: updates existing comment instead of creating duplicates
- CI/CD pipeline with ShellCheck, actionlint, and yamllint
- Branch protection and governance files (CODEOWNERS, issue templates, PR template)
- CONTRIBUTING.md with development guidelines
- SECURITY.md with security policy
- Pre-commit hooks configuration

### Fixed
- ShellCheck warnings: properly quoted GITHUB_OUTPUT
- Actionlint configuration to only lint workflow files

## [1.0.0] - 2026-01-22

### Added
- Initial release of ZAD Actions
- **deploy** action: Deploy container images to ZAD Operations Manager
  - Support for cloning configuration from existing deployments
  - `force-clone` parameter to re-clone even if deployment exists
  - Input validation for security (alphanumeric, hyphens, underscores, dots only)
  - 60-second curl timeout to prevent hanging
- **cleanup** action: Remove ZAD deployments and GitHub resources
  - Delete ZAD deployments via Operations Manager API
  - Delete GitHub deployments (mark inactive, then delete)
  - Delete GitHub environments (requires admin token)
  - Delete container images from GHCR
  - Best-effort cleanup (continues even if individual steps fail)
- Comprehensive documentation with examples
- EUPL-1.2 license

### Security
- Input validation before logging to prevent injection attacks
- Secure handling of API keys via environment variables
- Dangerous character detection for container inputs

[3.2.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v3.2.0
[3.1.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v3.1.0
[3.0.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v3.0.0
[2.4.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.4.0
[2.3.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.3.0
[2.2.1]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.2.1
[2.2.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.2.0
[2.1.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.1.0
[2.0.1]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.0.1
[2.0.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v2.0.0
[1.3.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.3.0
[1.2.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.2.0
[1.1.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.1.0
[1.0.0]: https://github.com/RijksICTGilde/zad-actions/releases/tag/v1.0.0
