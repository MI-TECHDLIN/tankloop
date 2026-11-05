# Simulation contract

Every generated record is marked `is_simulated=true`. Screens show a simulation notice, synthetic evidence links use `simulation://`, and templates say they are design examples. No generated rate is a measured contamination rate or pilot outcome.

## Reproducibility

```sh
dart run packages/domain/bin/simulate.dart --seed=20261101 --days=10 --format=summary
dart run packages/domain/bin/simulate.dart --seed=20261101 --days=21 --format=json
```

Defaults are seed `20261101`, start `2026-11-01T06:00:00Z`, elapsed day `10`, two organizations and two facilities per organization. The CLI accepts elapsed days `0..365`. An engine can be advanced by smaller durations; unit tests compare incremental progression to a single jump.

The portable LCG uses `state = (1664525 * state + 1013904223) mod 2^32`. Equal seed, model version and inputs generate equal IDs, events and state. Same-time scheduled events have a deterministic sequence tie-breaker. Dart VM and JavaScript can represent all intermediate values exactly.

`packages/domain/lib/src/simulation.dart` is model version 1 and the source of truth. Generated names, topology and template content are fixtures; **the observations, times, workload, results and lifecycle progression are generated**, not a hand-authored status carousel.

## Model assumptions

- Each facility has a borehole -> pump -> overhead tank -> distribution line -> tap network; tanks are 5,000, 7,500 or 10,000 L. Borehole, tank outlet and tap have distinct sampling points.
- A versioned three-question tank inspection is due every three days. Synthetic colleagues complete about 65% of routine visits, leaving a field backlog. Each answer has a 5% synthetic observed-risk chance.
- Initial samples occur 12-83 hours after the start. Routine sampling repeats every 7-10 days plus 0-4 hours.
- Transit takes 90-239 minutes. Testing follows receipt by 18-30 hours; review follows testing by 2-7 hours; publication follows review by one hour. Intake rejects 6% of synthetic samples, retaining the reason.
- Measurements use a zero-inflated, right-skewed count model. Positive probability is 16% at the borehole, 30% at downstream points and 16% for verification samples. These parameters deliberately exercise the workflow and are not epidemiological estimates or treatment-efficacy claims.
- The demo method is `Membrane filtration (simulation)`, E. coli, `CFU/100 mL`, detection limit 1. Other indicators and screening limits have separate domain tests.
- A reviewed positive finding opens an incident. A synthetic manager triages, assigns and authorizes work. Repair completion occurs 36-60 hours later; acceptance is separate. A post-action checklist and follow-up sample are required before closure, with a recorded communication reference.
- Rejected follow-up samples are recollected. Repeat verified findings can reopen a case while preserving its earlier closure trail. Every lifecycle step calls the actual domain guards.

## Seeded database

Regenerate the SQL only through the engine:

```sh
dart run packages/domain/bin/simulate.dart --format=sql > supabase/seed.sql
```

Do not edit `supabase/seed.sql` manually. It is a transactional snapshot for a fresh database, including synthetic users, memberships, topology, evidence, guarded workflow states and audit. It records the model version, seed and simulated clock in organization settings. CI regenerates and diffs it to detect drift.

Supabase does not run the Dart event scheduler in the background. It loads a deterministic snapshot, then accepts authenticated commands against that shared state. Both apps read the same database exercise clock. Standalone simulation runs the event engine on-device and exposes **Advance 1 day**.

## Demo controls and limitations

- Field persists its advanced clock and acknowledged inspection commands. Changing the seed or starting-day define selects a different local namespace.
- Verify's simulation route accepts `?seed=<integer>&day=<0..365>` inside the hash route. Advancing it changes the URL, so the same dated baseline can be reopened.
- A copied Field link reproduces the generated baseline at that seed/day. It cannot transfer private, custom device submissions into a separate simulation instance. Use Supabase mode for the shared Field-to-Verify demonstration.
- Seeded QR tokens are reproducible. Real QR issuance must use unpredictable server-generated tokens and retain revocation audit.
- The model is a workload demonstration. It does not implement hydrodynamics, weather inference, sensor emulation, intervention recommendations or local health guidance.
