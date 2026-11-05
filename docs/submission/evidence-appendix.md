# TankLoop evidence appendix outline

<!-- Blueprint p.24 identifies the source list; p.21 defines research gates; p.2 defines evidence labels. -->

This appendix should accompany the public project page and live physical demonstration. It should make clear which statements are source-backed, which are design decisions, and which remain research gates. It must not turn simulated demonstration records into evidence of tested water.

## 1. Sources cited in the blueprint

Record the full citation, URL or document identifier, access/check date, and the claim it supports.

1. **S1 — Xylem Global Student Innovation Challenge 2026 official rules and deadline**  
   `https://xyleminnovationchallenge.bemyapp.com/`  
   Use for submission format, eligibility, public-page requirements, and deadline. Verify directly before publication; the blueprint does not establish these rules by itself.
2. **WHO 2024 guidance on small water supplies**  
   Use for the contextual framing of small/decentralized water systems and the need for risk-management practices. Record the exact edition and URL from the final blueprint/source pack.
3. **WHO sanitary-inspection packages**  
   Use for the proposed inspection structure for boreholes with motorized pumps, piped storage tanks, and piped distribution networks. Record attribution/licensing and the exact package identifiers (S5–S7).
4. **Previously submitted TankLoop / ProofPour / low-cost water-screening briefs**  
   Use as prior team context only. Identify which statements are inherited concepts rather than independently validated findings.
5. **Any additional laboratory, privacy, or regulatory references added before publication**  
   Add only after source review. Do not cite a standard, regulator, or lab partner as endorsing TankLoop without written permission.

## 2. Research gates before real deployment

These are validation activities, not completed evidence:

- Interview facilities to test whether the proposed accountability gap matches real workflows.
- Conduct walkthroughs with **2–3 qualified laboratory partners** covering intake, rejection, attestation, corrections, and reporting.
- Observe at least one maintenance or spending decision from concern through authorization.
- Run unassisted resident comprehension tests for public statuses, dates, evidence scope, and limitations.
- Test drafts, queued uploads, conflict handling, and account switching on low-end Android devices with unreliable connectivity.
- Compare a controlled TankLoop workflow with a paper or WhatsApp baseline.
- Confirm sampling methods, reviewer authority, privacy/retention practices, escalation arrangements, and deployment governance.

## 3. Evidence classification matrix

### Simulated for the live demonstration

- Facility, asset, inspection, sample, custody event, laboratory result, incident, work order, follow-up, timestamps, actors, photos, and QR record.
- Any named organization, resident, laboratory, or facility shown during the demonstration.
- Any elapsed-time, completion, assignment, or public-comprehension number shown in the UI.

Simulation must be visibly labeled during the demonstration and on the public-facing project materials. These records demonstrate workflow behavior only.

### Designed or proposed

- Flutter + Supabase architecture and role-specific surfaces.
- Offline-first draft/outbox behavior and server-required transitions.
- Evidence dimensions, status language, state machines, audit events, QR projection, and permissions.
- Proposed impact metrics and their interpretation cautions.
- The claim that a connected workflow could reduce accountability gaps; this remains a hypothesis until research.

### To be validated

- Whether the problem occurs as described at a specific pilot facility.
- Whether facilities and laboratories would adopt the workflow.
- Whether the proposed checklist and statuses are understandable and appropriate in context.
- Whether offline sync, permissions, RLS, storage, notifications, and audit controls work safely in deployment.
- Whether the sampling, review, privacy, retention, language, and regulatory arrangements are sufficient.
- Any impact on response time, evidence completeness, resident comprehension, or operational outcomes.

## 4. Claims the appendix must explicitly exclude

- “The water is safe.”
- “TankLoop detected contamination.”
- “The simulated result is a real test.”
- “A completed repair proves resolution.”
- “A negative result covers all hazards or the whole distribution system.”
- “The prototype is regulatory certification, a laboratory, or a treatment recommendation.”

## 5. Publication checklist

- Confirm official Xylem rules, eligibility, required page fields, and the 20 November 2026, 21:00 UTC deadline.
- Replace team placeholders only with consented names and roles.
- Add exact source metadata and attribution/licensing notes.
- Check the physical demonstration materials and public-facing screens for the `SIMULATED DEMO DATA` label.
- Confirm public pages expose no private reporter details, precise private locations, unreviewed attachments, credentials, or secrets.
- Preserve the distinction between source-backed material, design decisions, and research gates in the final appendix.
