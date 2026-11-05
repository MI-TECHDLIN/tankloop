# RPC API

Supabase exposes these functions under `/rest/v1/rpc/<function>`. Use the publishable/anon key and, for commands, the signed-in user's bearer session. SQL in `supabase/migrations/` is the authoritative signature and authorization contract. Edge Functions are not required for this slice.

## Application path

### `submit_inspection`

Roles: scoped field member, manager or admin. A specifically assigned inspection also checks the assigned inspector unless a manager/admin is acting. The issued server template and version control validation.

```json
{
  "p_event_id": "<persistent-command-uuid>",
  "p_inspection_id": "<inspection-uuid>",
  "p_expected_version": 0,
  "p_answers": {
    "lid": {"choice": "yes", "note": "Simulated unsecured cover"},
    "leaks": {"choice": "no", "note": ""},
    "access": {"choice": "unknown", "note": "Not observable"}
  },
  "p_notes": "Simulated visit only",
  "p_observed_at": "2026-11-11T06:00:00Z"
}
```

Choices are `yes`, `no`, `unknown`, `not_applicable`. All required questions must be present; unknown question IDs are rejected. Question notes are limited to 1,000 characters, visit notes to 4,000. A `yes` creates a separate inspection-sourced incident, without implying a laboratory finding.

The receipt contains `client_event_id`, `inspection_id`, `version` and `received_at`. An identical retry by the same actor returns that receipt; changed content under the same event ID conflicts. Membership is rechecked on every retry.

### `lookup_public_record`

Anonymous request: `{"p_token":"<opaque-lowercase-hex-token>"}`. Tokens are 32-128 hexadecimal characters; production-issued tokens must be unpredictable. The seeded tokens are deliberately reproducible and are not production secrets.

Response: `token`, `point_label`, `facility_label`, `timezone`, `state`, `wording`, optional `action_wording`, `updated_at`, `is_simulated`, `is_current`, `concerns` and `tests`. Tests include exact indicator/method/value/units/detection limit and collection/test/review/publication times. Unknown, malformed or revoked tokens return JSON null. Service failure is distinct from a missing record in the UI.

## Server-only workflow commands

The manager/lab screens are deferred, but the commands are implemented and exercised by database tests:

| RPC | Role and principal guards |
| --- | --- |
| `register_sample` | Field; scoped point, collection time, intended method, preservation details and stable sample UUID |
| `transition_result` | Lab for receipt/intake/test/review; manager/admin for publication; expected version, chronology, exact method and linked report |
| `correct_result` | Lab; reviewed/published original, corrected value, report and reason; immutable revision lineage |
| `propose_work_order` | Field/manager/admin; active scoped incident, stable work UUID and task |
| `transition_work_order` | Manager/admin approves, accepts or requests rework; only the assigned worker starts/completes; due date and evidence required |
| `set_verification_plan` | Manager/admin; assigned/mitigating incident, expected version, scoped nonempty checklist/sample requirements |
| `transition_incident` | Manager/admin; expected version, triage/ownership/action/verification/communication guards appropriate to target |
| `escalate_incident` | Manager/admin; active critical incident or elapsed deadline, reason and expected version |
| `revoke_public_record` | Manager/admin; scoped token and reason; original identity retained |

Transitions accept `p_id`, `p_target`, `p_expected_version`, `p_payload`, `p_reason`. Useful payload fields:

- Result: `custody_note`, `rejection_reason`, or `indicator`, `method`, `value`, `units`, `detection_limit`; review uses `report_ref`.
- Work: approval uses `assignee_id`, `due_at`; completion uses `completion_evidence`.
- Incident triage: `priority` and `uncertainty`; assignment: `owner_id`, `due_at`, `required_response`; verification-pending: `controls_reviewed`, `notice_reviewed`, `notice_ref`; resolution: `communication_ref`; reopening: `cause`, `evidence_ref`.
- Plan requirements use `kind: sample` with `point_id`, `indicator`, `method`, or `kind: checklist` with `template_id`. The server applies the post-action cutoff. A laboratory incident needs all affected points and the original indicator/method covered.

There is no direct generic update endpoint for lifecycle state. Non-inspection transitions use optimistic version checks; clients must reload after an uncertain outcome before issuing another transition. Only commands with an explicit stable identity/receipt contract should be automatically retried.

## Failure mapping

| SQL/API code | Client behavior |
| --- | --- |
| `42501`, invalid/expired Auth JWT | Permission failure; retain local work and request renewed access |
| `40001`, `23505` | Version/idempotency conflict; retain for explicit review |
| `22023`, `23514` | Invalid checklist/evidence/transition; retain for review |
| Network and other service errors | Pending retry with local content retained |

Full negative-path examples are in `supabase/tests/trust_boundaries.test.sql`. The repository integration test uses only client-safe credentials; trusted CI setup separately provisions its disposable account.
