# TankLoop

## From a water concern to an accountable response

TankLoop is a water-quality operations and transparency platform for the **Xylem Global Student Innovation Challenge 2026**, Water Quality track. It helps facilities record concerns, assign accountable action, preserve evidence, verify follow-up, and communicate a dated public status.

<!-- Blueprint p.3–4: TankLoop is an accountability layer, not a sensor or laboratory. -->

In decentralized water systems, information can be fragmented across paper, messaging apps, staff memory, and laboratory reports. A concern may be noticed without a clear owner, a repair may be completed without documented verification, or residents may receive a status without enough context. TankLoop is designed to connect those handoffs.

> **Important:** TankLoop does not sense contamination, replace qualified sampling or testing, provide treatment instructions, or declare water “safe.” All data used in demonstrations is simulated and must be visibly labeled as simulated.

## What TankLoop includes

### Five product surfaces

- **TankLoop Field:** Flutter Android experience for inspections, sample capture, assigned work, evidence, and QR scanning.
- **TankLoop Manage:** responsive workspace for facility managers and administrators to review facilities, incidents, approvals, and reports.
- **TankLoop Verify:** low-data public portal for dated water-point records, open concerns, and resident feedback.
- **TankLoop Lab:** specialist workflow for sample intake, result attestation, evidence review, and corrections.
- **TankLoop Control:** governance tools for onboarding, roles, audit access, and safety controls.

### Seven connected modules

1. Facility and water-network registry
2. Inspections and scheduled maintenance
3. Sampling, custody, and laboratory records
4. Incidents, work orders, and verification
5. Public water records
6. Communication and escalation
7. Reporting, administration, and support

The planned demonstration follows one coherent spine: **inspection → sample → lab result → incident → fix → verified follow-up → public QR record**. Demonstration records are synthetic workflow fixtures, not evidence that real water was tested.

## Trust guardrails

TankLoop keeps evidence source, verification stage, operational concern, and freshness distinct. It is designed so that:

- an inspection is not presented as a laboratory result;
- a rejected sample cannot satisfy verification;
- completed repair does not automatically resolve an incident;
- corrections preserve earlier results, reasons, actors, and timestamps;
- unresolved concerns cannot be hidden behind a friendly status;
- public records state when data is missing, outdated, unverified, or limited in scope;
- private reporter details and unreviewed files stay out of public views; and
- no status says that water is safe.

These are product and governance requirements, not claims that the full system is already deployed or validated.

## Architecture and technology

<!-- Blueprint p.15–16: proposed architecture and monorepo boundaries. -->

TankLoop is planned as a Flutter and Supabase system with typed domain boundaries:

- **Flutter + Dart** for mobile and responsive web experiences
- **Riverpod** for state and dependency injection
- **go_router** for navigation and guarded deep links
- **Drift over SQLite** for relational offline persistence and queued commands
- **Supabase PostgreSQL** for cloud data with tenant-scoped Row Level Security
- **Supabase Auth and Storage** for sessions and access-controlled evidence
- **Edge Functions and constrained RPCs** for privileged transitions, public projections, audit, and notifications

The intended monorepo layout is:

```text
tankloop/
  apps/
    field_app/               # Flutter Android-first experience
    portal_web/              # Flutter Web role-aware experience
  packages/
    design_system/           # tokens, widgets, typography
    domain/                  # entities, states, use cases
    data/                    # repositories and adapters
    offline_sync/            # outbox and conflict resolution
    shared_forms/            # schema-driven inspection forms
    localization/            # language resources
  supabase/
    migrations/              # versioned SQL and RLS policies
    functions/               # privileged transitions and public reads
    tests/                   # authorization and RLS checks
  docs/
    submission/              # public submission materials
```

## Project status and roadmap

This repository is an active challenge prototype and design proposal, not a production water-quality service. The current priority is a dependable vertical demonstration with clearly labeled simulated records and explicit trust boundaries.

Planned sequence:

1. Implement and test domain entities, state machines, and transition invariants.
2. Establish the shared design system and inspection forms.
3. Add a local-first data path and offline draft behavior.
4. Build the field inspection and manager incident workflow.
5. Add the public QR record with mandated limitation language.
6. Integrate Supabase authentication, RLS, storage, and privileged transitions.
7. Validate with facilities, qualified laboratories, residents, offline devices, and a paper or messaging baseline.

Real deployment would additionally require operational partners, agreed sampling methods, privacy and retention review, regulatory review, and sustained support. The proposed impact metrics are workflow measures, not a composite water-safety score.

## Challenge context

TankLoop is being prepared for the **Xylem Global Student Innovation Challenge 2026**. The project page, live physical demonstration, and evidence appendix distinguish source-backed context, design decisions, research gates, and simulated records. See [`docs/submission/`](docs/submission/) for the current public-facing materials.

## Team of 3

- **[Name]** — [role]
- **[Name]** — [role]
- **[Name]** — [role]

Replace placeholders only with consented team details and after confirming the official challenge requirements.

## Getting started

Project setup and development instructions are being added in the repository setup documentation. Once available, start there for environment prerequisites, dependency installation, local services, and validation commands. This README intentionally does not invent commands that are not yet present.

## Submission materials

- [Public project page](docs/submission/project-page.md)
- [Evidence appendix outline](docs/submission/evidence-appendix.md)
