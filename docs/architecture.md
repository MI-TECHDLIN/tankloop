# TankLoop architecture

<!-- Blueprint p.12–18. These diagrams describe the planned design; implementation status is tracked in the repository roadmap. -->

TankLoop is planned as a local-first Flutter and Supabase platform. The diagrams are intentionally limited to the boundaries and invariants needed for the challenge vertical demonstration. A highlighted or described component is not necessarily implemented.

## 1. System architecture

```mermaid
flowchart LR
  field["TankLoop Field<br/>Flutter Android"]
  manage["TankLoop Manage<br/>Flutter responsive web"]
  verify["TankLoop Verify<br/>public Flutter web"]
  lab["TankLoop Lab<br/>responsive web"]
  clients["Flutter clients"]
  repos["Typed repositories<br/>domain commands"]
  local["Local-first layer<br/>Riverpod · Drift · sync coordinator · outbox"]
  supabase["Supabase<br/>Auth · PostgreSQL + RLS · Storage<br/>Edge Functions · Realtime"]
  partners["External partners<br/>qualified laboratory review<br/>SMS/email providers<br/>authorized institution systems"]
  field --> clients
  manage --> clients
  verify --> clients
  lab --> clients
  clients --> repos --> local --> supabase --> partners
```

**Planned boundary:** clients use typed use cases and repositories rather than arbitrary table access. Privileged transitions, public projections, audit writes, and notifications belong in Edge Functions or constrained security-definer RPCs. Flutter clients must not contain service-role keys.

## 2. Offline synchronization

```mermaid
flowchart LR
  save["LOCAL SAVE<br/>draft / inspection / concern"] --> outbox["OUTBOX<br/>client_event_id + expected version"]
  outbox --> upload["UPLOAD + AUTH<br/>idempotent server operation"]
  upload --> ack["SERVER ACK<br/>canonical timestamp + audit event"]
  ack --> refresh["REFRESH<br/>server projection and local state"]
  upload -. failure / retry .-> outbox
```

Offline drafts, inspections, photos, and concerns are candidates for local persistence. Lab attestation, public publication, membership changes, and incident closure require the server. Scientific results, authority assignments, and closure do not use client-side last-write-wins.

## 3. Separate state machines

The result, work-order, and incident lifecycles are separate. In particular, completing a work order does not resolve an incident.

```mermaid
stateDiagram-v2
  state "Result lifecycle" as Result {
    [*] --> collected
    collected --> received
    received --> valid
    received --> rejected
    valid --> tested
    tested --> reviewed
    reviewed --> published
    published --> superseded
  }
  state "Work-order lifecycle" as WorkOrder {
    [*] --> proposed
    proposed --> approval_pending
    approval_pending --> assigned
    assigned --> in_progress
    in_progress --> completed
    completed --> accepted
    completed --> rework
  }
  state "Incident lifecycle" as Incident {
    [*] --> reported
    reported --> triaged
    triaged --> assigned
    assigned --> mitigation_work
    mitigation_work --> verification_pending
    verification_pending --> resolved
    resolved --> reopened
  }
```

Resolution requires the configured checklist and sample requirements, an appropriately reviewed result, reviewer authorization, and recorded communication. A repeat verified finding can reopen an incident.

## 4. Simplified data model

```mermaid
erDiagram
  ORGANIZATION ||--o{ MEMBERSHIP : grants
  ORGANIZATION ||--o{ FACILITY : owns
  FACILITY ||--o{ WATER_SYSTEM : contains
  WATER_SYSTEM ||--o{ ASSET : has
  WATER_SYSTEM ||--o{ SAMPLING_POINT : exposes
  FACILITY ||--o{ CHECKLIST_TEMPLATE : uses
  SAMPLING_POINT ||--o{ INSPECTION : receives
  SAMPLING_POINT ||--o{ SAMPLE : produces
  SAMPLE ||--o{ CUSTODY_EVENT : records
  SAMPLE ||--o{ TEST_RESULT : yields
  TEST_RESULT ||--o{ INCIDENT : triggers
  INCIDENT ||--o{ WORK_ORDER : tracks
  INCIDENT ||--o{ VERIFICATION_REQUIREMENT : requires
  FACILITY ||--o{ PUBLIC_RECORD : publishes
  INCIDENT ||--o{ AUDIT_EVENT : records
  ORGANIZATION ||--o{ NOTIFICATION : sends
  ORGANIZATION ||--o{ OUTBOX_EVENT : queues
```

Stable identifiers, tenant-scoped access, distinct collected/tested/reviewed/published timestamps, immutable observations, and revision lineage are planned data-quality requirements.

## 5. Planned monorepo layout

```mermaid
flowchart TB
  root["tankloop/"] --> apps["apps/"]
  root --> packages["packages/"]
  root --> supabase["supabase/"]
  root --> docs["docs/"]
  root --> ci[".github/workflows/"]
  apps --> field["field_app/"]
  apps --> portal["portal_web/"]
  packages --> design["design_system/"]
  packages --> domain["domain/"]
  packages --> data["data/"]
  packages --> sync["offline_sync/"]
  packages --> forms["shared_forms/"]
  packages --> localization["localization/"]
  supabase --> migrations["migrations/"]
  supabase --> functions["functions/"]
  supabase --> tests["tests/"]
  docs --> submission["submission/"]
```

The current repository may contain only part of this planned layout. The diagram is a target boundary, not an inventory of completed implementation.

## First-slice implementation

The runnable Field/Verify slice now has [implementation notes](implementation.md) covering its package boundaries, lifecycle guards, tenant/public projection and durable outbox. See [delivery scope](delivery.md) for completed checks and deferred interfaces, and [development setup](development.md) to run it.
