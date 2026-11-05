# TankLoop

## One-line pitch

**TankLoop helps facilities record water concerns, assign accountable action, verify follow-up, and publish an honest, dated public record—without claiming that software can test water or declare it safe.**

<!-- Blueprint p.1, p.3, p.10: this is a design proposal; public copy must not imply measured or certified water quality. -->

## The problem

In facilities that depend on decentralized water systems, information about inspections, samples, repairs, and laboratory reports can be fragmented across paper, messaging apps, staff memory, and separate providers. A concern may be noticed without a clear owner; a repair may be completed without a documented follow-up; residents may receive a status without enough context to understand what it means.

The exact failure pathway at a future pilot site still requires research. TankLoop treats this as an accountability and communication problem, not as proof that any particular facility has unsafe water.

## The solution

TankLoop is a Flutter and Supabase water-quality operations and transparency platform. It provides a shared workflow for:

- recording inspections and resident concerns;
- registering samples and chain-of-custody events;
- preserving laboratory provenance and reviewer authorization;
- assigning incidents and work orders;
- requiring follow-up evidence before an incident can be resolved; and
- publishing a limited QR-accessible record with clear dates, evidence scope, and outstanding concerns.

TankLoop is not a sensor, laboratory, treatment system, or regulator. It does not generate treatment instructions, replace qualified sampling or testing, or declare water “safe.”

## How it works

1. **Inspect:** a field worker records an observation against a water asset using a versioned checklist, including notes and evidence.
2. **Sample:** a collector registers a sample and custody events with stable identifiers.
3. **Review:** an authorized laboratory workflow records whether a sample is valid and preserves result revisions and provenance.
4. **Respond:** a manager triages an incident, assigns an owner, tracks corrective work, and records interim communication.
5. **Verify:** a follow-up sample and review are linked to the incident; completed repair alone cannot close it.
6. **Communicate:** a public QR record shows a dated, limited status and explicitly identifies missing, outdated, unverified, or simulated information.

The project demonstration uses **simulated data only**, visibly labeled as simulated. No demo record is evidence that real water was tested or that a facility is safe.

## Who it serves

- **Caretakers and field inspectors:** offline-capable inspections, assigned work, and evidence capture.
- **Facility managers and wardens:** incident triage, ownership, approvals, and communication history.
- **Sample collectors and qualified laboratory reviewers:** sample identity, custody, result provenance, and corrections.
- **Residents and students:** a low-data public record that explains what is known, what is not known, and what concern is outstanding.
- **Institutions and governance teams:** tenant boundaries, audit history, role controls, and reporting.

## Intended impact and measurement

The initial measurement plan focuses on workflow reliability and comprehension rather than a composite “water safety score.” Proposed metrics include:

| Metric | What it can indicate | Interpretation caution |
|---|---|---|
| Case-assignment completeness | Whether reported cases have an accountable owner | More assignments can reflect more reporting workload, not better water quality |
| Evidence completeness | Whether required inspection, custody, result, and action records are present | Complete records do not prove the underlying observation or result is correct |
| Retest completion | Whether required follow-up is completed | A higher rate may reflect more open concerns or better process discipline |
| Median time-to-action | Time from a recorded concern to an authorized action | Faster is not always better if review, safety, or consent steps are skipped |
| Public comprehension | Whether residents can understand the dated status and its limits | A comprehension test is needed; page views alone are not comprehension |
| Offline reliability | Whether drafts and queued work survive low-connectivity conditions | This measures product behavior, not water conditions |
| Data currentness | Whether published records are within the configured freshness policy | Current data can still be incomplete or limited to one indicator |

These metrics are design proposals, not measured outcomes. TankLoop will not combine them into a single safety score.

## Team

**Team of 3:** [Name] · [Role] · [Name] · [Role] · [Name] · [Role]  
Team eligibility and challenge requirements should be confirmed against the official challenge rules before publication.

## Limitations and next steps

This entry is a prototype and design proposal. It has no basis for claiming that any facility’s water is safe, that a simulated result is real, or that the workflow satisfies local regulatory requirements. A real deployment would require:

- interviews with facilities about the accountability gap;
- walkthroughs with two or three qualified laboratory partners;
- observation of a maintenance or spending decision;
- unassisted resident comprehension testing;
- offline testing on low-end Android devices;
- comparison with paper or messaging-based workflows;
- privacy, retention, consent, and Nigerian regulatory review; and
- agreed sampling methods, reviewer authorization, and operational partners.

<!-- Blueprint p.19–20, p.21, p.23–24: metrics, research gates, risks, and post-hackathon validation remain open. -->

