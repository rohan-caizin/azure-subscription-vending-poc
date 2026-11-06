# Azure subscription vending (PoC)

Vends Azure landing zones from YAML requests using the Azure Verified Module
[`Azure/avm-ptn-alz-sub-vending`](https://registry.terraform.io/modules/Azure/avm-ptn-alz-sub-vending/azure)
(pinned to `0.3.4` in `modules/landing-zone/main.tf`).

One request file = one landing zone = one Terraform state = one pipeline job.

```
subscriptions/<team>/<name>.yaml    request (the only thing requesters edit)
        │
stacks/subscription/                root module: backend, provider, reads YAML
        │
modules/landing-zone/               validation, archetypes, naming, defaults
        │
Azure/avm-ptn-alz-sub-vending       creates the subscription and its baseline
```

## Layout

| Path | Owner | Purpose |
|---|---|---|
| `subscriptions/` | Requesters | One YAML file per landing zone, grouped by team |
| `config/platform.yaml` | Platform team | Values shared by all requests: region, management groups, hub, budget dates |
| `modules/landing-zone/` | Platform team | Request validation and archetypes (`corp`, `sandbox`) |
| `stacks/subscription/` | Platform team | Root module the pipeline runs once per request |
| `ci/` | Platform team | Cross-request validation, changed-request detection, plan gate |
| `platform/00-bootstrap/` | Platform team | Pipeline identities, OIDC trust, billing role. Applied by hand |
| `platform/10-core/` | Platform team | Management groups, policies, hub VNet, pipeline RBAC. Applied by hand |

## Requesting a landing zone

1. Copy an example from `subscriptions/` into your team's folder. The file name must equal `name`.
2. Fill in `name`, `archetype`, `owners` (Entra **group** object IDs), `budget_contacts`, `tags`
   and, if needed, `network` and `github_repo`.
3. Open a pull request. The pipeline validates every request and plans only the changed ones;
   each plan is posted on the PR.
4. After merge, a reviewer approves the `poc-apply` environment and the saved plans are applied.

**The file path is permanent.** It is the state key. Renaming or moving the file makes Terraform
try to create a second landing zone. Group files by team, not by archetype, so changing
archetype is a one-line edit.

### Create or adopt

| Request | Mode | Access granted at |
|---|---|---|
| no `subscription_id` | **create**: new subscription via the Subscription Alias API, billed to `BILLING_SCOPE` | subscription |
| `subscription_id` of another subscription | **adopt**: existing subscription | subscription |
| `subscription_id` = `platform_subscription_id` | **adopt-shared**: lives inside the platform subscription | its own resource groups only |

`name`, billing scope and workload are only read when a subscription is created.

## Giving people access

Access is granted to **Entra groups**, never to individual users.

- **Add or remove a person:** change the membership of the group listed in `owners`. No PR, no pipeline run:
  ```sh
  az ad group member add --group <group-object-id> --member-id $(az ad user show --id user@domain --query id -o tsv)
  ```
- **Give another team access:** add its group's object ID to `owners` in a PR.
- People from outside the tenant must be invited as guests first.

Each owner group gets the archetype's `owner_role` (Contributor) on the whole subscription, or,
in adopt-shared mode, Contributor on `rg-<name>-app` and Reader on `rg-<name>-network`.

Role assignments made by hand in the portal are not tracked by Terraform and are not reported by drift detection.

## Pipeline (GitHub Actions)

| Workflow | Trigger | What it does | Identity |
|---|---|---|---|
| `vending-pr` | Pull request | Validate, `terraform test`, plan each changed request, plan gate, PR comment | plan (read-only) |
| `vending-apply` | Merge to `main` | Plan changed requests → **approval on `poc-apply`** → apply the saved plans | plan, then apply |
| `vending-drift` | Nightly | Plan every request; opens an issue on drift | plan |
| `vending-destroy` | Manual | Destroy one request (cancels a created subscription) after approval | plan, then apply |

A change under `modules/`, `stacks/` or `config/` runs every request. Deleted request files are
never processed: to retire a landing zone, run `vending-destroy` first, then delete the file.

The plan gate (`ci/plan-gate.sh`) fails any plan that deletes or replaces a resource.
One-off, reviewed exceptions go in `ci/plan-gate-allow.txt`.

GitHub repository variables: `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ARM_CLIENT_ID_PLAN`,
`ARM_CLIENT_ID_APPLY` (outputs of `platform/00-bootstrap`) and `BILLING_SCOPE` (MCA invoice section ID).

## Tests

No Azure login needed; providers are mocked.

```sh
python ci/validate_requests.py
cd modules/landing-zone && terraform init -backend=false && terraform test
cd stacks/subscription  && terraform init -backend=false && terraform test
```

## Platform layers (applied by hand)

The pipeline cannot create the identity it signs in with or grant itself billing roles, so these
two layers are applied by a platform admin with `az login`, in order:

```sh
cd platform/00-bootstrap && terraform init && terraform apply   # identities, OIDC, billing role
cd platform/10-core      && terraform init && terraform apply   # management groups, policies, hub, RBAC
```

Both read `terraform.tfvars` (copy from `terraform.tfvars.example`; git-ignored).

## Migration from the single-state layout (one-time)

`poc-app1-dev` was created by the old `vending/` layer (state key `vending.tfstate`).
`stacks/subscription/migrate.tf` imports its resources into `subscriptions/app1/poc-app1-dev.tfstate`.
The first apply also deletes and re-creates the deploy identity's role assignment (same name, same
principal, same role), allowed once by `ci/plan-gate-allow.txt`. After that apply:

1. In a follow-up PR, delete `stacks/subscription/migrate.tf`, the `legacy_import` line in
   `stacks/subscription/tests/requests.tftest.hcl`, and the entry in `ci/plan-gate-allow.txt`.
2. Delete the orphaned `vending.tfstate` blob from the state container.

## Known limits

- An individual MCA account has no Dev/Test offer, so new subscriptions use the `Production` workload.
- The budget is subscription-scoped. In adopt-shared mode it measures the whole platform subscription.
- `budget_start` in `config/platform.yaml` applies to every request; a request created in a later
  month should pin its own `budget_start`.
- Cancelled subscriptions stay disabled for a while before Azure deletes them.
