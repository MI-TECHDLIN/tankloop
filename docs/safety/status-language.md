# Safety and public status language

**Status:** Demo wording contract. Qualified scientific review, resident comprehension testing and localization review are **Planned**, not completed validation.

**Source:** *TankLoop Full Product Blueprint Flutter*, Product Requirements + System Design v1.0, prepared 01 November 2026. Page citations use the numbered PDF pages: screen requirements are on p. 10, microcopy and evidence dimensions on p. 11, public states and further scientific rules on p. 12, and transition guards on p. 13.

This guide extends the existing [shared status-language contract](../status-language.md). Its public-state strings and blueprint microcopy are repeated verbatim below for screens and the simulator. They are not a second vocabulary. Keep both guides consistent in any future approved wording change. The [simulation contract](../simulation.md) defines how generated records are produced.

## 1. Hard guardrails

TankLoop does not sense contamination itself or substitute for qualified sampling, testing, maintenance or regulatory oversight. It coordinates an accountable response; it does not certify water or establish a reduction in illness. (Blueprint, p. 3.)

The blueprint's five hard guardrails are:

1. Never display "This water is safe" from one result or an inspection alone.
2. Keep unverified submissions separate from verified lab findings.
3. Never automatically notify a government office without an authorized arrangement.
4. Never conceal a confirmed concern behind a friendly status such as "maintenance in progress".
5. Do not invent laboratory data, field observations, study outcomes or regulatory certification.

For this demo, no screen may declare water "safe". Explicitly labeled synthetic records are workflow examples, never invented evidence presented as real observations. A server receipt for a synthetic record establishes receipt, not a real laboratory finding. (Blueprint, pp. 3, 21, 23-24; shared status and simulation contracts.)

## 2. Public states and exact copy

These six labels and sentences are the public wording contract. Replace bracketed placeholders with the corresponding evidence fields; never render a placeholder to a resident. Quotation marks below delimit copy and are not part of the displayed sentence. (Blueprint, p. 12.)

| Public state | Display rule | Exact copy |
| --- | --- | --- |
| No valid current data | No qualifying reviewed test within the configured review window. | "We do not have a current verified test record for this point." |
| Risk observed | Inspection issue, without a verified measurement. | "Inspection concern reported on [date]. Testing may be needed." |
| Under investigation | A finding, complaint or workflow requires review. | "A water-quality concern is being investigated." |
| Confirmed finding | A reviewed laboratory result meets the relevant incident trigger. | "A verified [indicator] finding was recorded on [date]." |
| Corrective action underway | An authorized work order exists and the case remains open. | "Work is underway. Verification has not yet been completed." |
| Follow-up reviewed | A scope-specific reviewed sample is available. | "Follow-up sample reviewed on [date]; [exact finding]." |

### Placeholder and date rules

- `[indicator]` is the exact reported analyte or indicator, not a substitute such as "all contaminants".
- `[date]` in the inspection sentence is the concern's reported date; in the confirmed-finding sentence it is the finding's reviewed/recorded date; in the follow-up sentence it is the follow-up review date. A sentence describing a sample's finding uses its collection date. Show those meanings explicitly in the detailed record rather than treating the dates as interchangeable.
- `[exact finding]` preserves indicator, reported finding, units where applicable, sample date and scope limitations. Avoid duplicate sentence-ending punctuation when inserting a complete finding sentence.
- The current shared implementation uses UTC `YYYY-MM-DD` in standardized sentences. Detailed timestamps use the facility time zone, including its abbreviation. Preserve collection, testing, review and publication times separately, and show reported time uncertainty. (Blueprint, pp. 10-11, 14; shared status-language contract.)
- Currentness is a configured, method-appropriate policy, not proof of continuing water quality. The initial 30-day demonstration window is a demo policy, not a WHO interval or an approved institutional monitoring schedule. (Blueprint, pp. 11-12; [implementation boundaries](../implementation.md).)

### Combining states without hiding evidence

The four evidence dimensions remain independent; a headline is not a universal water-quality score. Several statements can apply to one point at once. (Blueprint, pp. 11-13.)

- An open confirmed finding remains primary even when corrective work is underway or a newer sample looks normal. Show the work sentence as an additional response statement, not a replacement for the finding.
- Show missing current evidence alongside an open concern when applicable. An old normal result stays visibly historical and cannot suppress the concern.
- Keep all outstanding concerns visible. "Follow-up reviewed" describes a reviewed sample, not automatic incident closure or whole-system certification.
- An unknown or revoked QR identifier, failed lookup or unavailable service makes no current water-quality claim. Do not convert an error or missing record into a reassuring status.
- Show icon, text and color together, with timestamps and provenance. Do not use a green badge to imply potability, rely on color alone, or animate a warning away. Loading, empty, error, permission-denied, offline, stale-data and success states must be explicit where applicable. (Blueprint, pp. 10-11, 13; shared status-language contract.)

Every public point page retains this exact shared limitation:

> A test describes one sample, at one point, at one time. It does not establish the safety of the whole water system.

This is existing application copy grounded in the blueprint's scope rules, not a new certification statement. (Blueprint, pp. 3, 11-12.)

## 3. Verbatim microcopy and when it is truthful

The replacement strings below are the blueprint's microcopy on p. 11 and match the shared guide.

| Do not write | Write instead | Required context |
| --- | --- | --- |
| "SAFE" | "No E. coli detected in this sample on [date]; other hazards were not assessed." | A valid, appropriately reviewed E. coli result actually supports non-detection under its recorded method and detection limit. |
| "Contaminated: tank lid missing" | "Inspection risk observed: tank lid missing. No test result is implied." | A recorded inspection supports the missing-lid observation. It is not a laboratory measurement. |
| "All issues fixed" | "Repair recorded; verification is still pending." | Repair completion is recorded, but the incident's verification requirements have not yet been satisfied. |
| "Verified forever" | "Last independently reviewed result: [date], for [indicator]." | Authorized independent review and a linked report exist; the date and indicator remain visible. Simulated review must also retain its simulation disclosure. |
| "Report failed" | "Your report was saved on this device. We will upload it when a connection is available." | Durable local saving has succeeded and the promised upload behavior actually exists. Do not use this promise for an unsaved report or a foreground-only retry flow. |

### Current foreground-only sync flow

The first slice has explicit **Sync now** actions, not an operating-system background upload scheduler. For its saved, queued inspection, reuse the current application sentence:

> Your inspection is saved on this device. It remains pending until a receipt is received.

Use `Draft saved on device` only after persistence succeeds. A failed write must not say "saved". A pending command must not say "delivered", "published" or "confirmed". A receipt is shown only after acknowledgement; an authorization failure remains blocked for review. Offline laboratory attestation, publication and final incident closure cannot acquire authority from a client label. (Blueprint, pp. 11, 16-17; shared status-language and implementation contracts.)

## 4. Four independent evidence dimensions

Do not collapse these dimensions into one badge, numeric score or "water safety" ranking. In particular, "laboratory" describes a source, not necessarily a reviewed result; "reviewed" does not describe universal safety; and "none recorded" does not establish absence of hazards. (Blueprint, pp. 11-13.)

| Dimension | Values or fields | What it establishes |
| --- | --- | --- |
| Evidence source | Resident report / inspection / field screen / laboratory | Where the evidence came from. A complaint is not a measured contaminant. |
| Verification stage | Draft / submitted / received / reviewed / rejected / superseded | The evidence's review state. Rejected or superseded evidence cannot masquerade as a current valid result. |
| Operational concern | None recorded / observed risk / open incident / under investigation / verification pending | The response state, separate from a sample's finding. |
| Freshness | Sampling, testing, review, publication and last-update dates; policy-based "not current" | When each event occurred and whether evidence meets the applicable review window. A refresh is not a new sample. |

The blueprint also distinguishes provenance grades: **user-reported**, **field-screened**, **lab-uploaded**, **independently reviewed**. These are not interchangeable and do not erase source, stage, concern or freshness. Preserve the sample/point identity, custody, method, reported value, units, detection limit, reviewer, linked report and correction lineage. Public summaries must omit private reporter details and unreviewed attachments. (Blueprint, pp. 8, 13-14.)

Simulation provenance is a mandatory additional disclosure across every dimension. A synthetic laboratory source with a simulated review is still synthetic, regardless of a realistic workflow or a real database acknowledgement. (Blueprint, pp. 21, 24.)

## 5. Scientific interpretation rules

1. **Invalid or rejected samples:** Never publish them as valid negatives and never let them satisfy verification. Exact explanatory copy: "No valid result from this sample." An absent, unreviewed or superseded result is also not a valid current negative. (Blueprint, pp. 11, 13.)
2. **E. coli:** The blueprint cites the WHO guideline value as "not detectable in any 100 mL sample". Preserve the laboratory method, reported detection limit, value and units. Do not turn this guideline into a whole-system "safe" badge or silently reinterpret a different assay as an E. coli result. (Blueprint, p. 11, references S4 and S8.)
3. **H₂S:** This is a screening indicator only and does not prove that E. coli is present or absent. Further investigation follows expert-approved policy. For the current simulator's screening result, retain the exact form below, choosing only the supported detected/not-detected variant. (Blueprint, p. 12; shared projection contract.)

   > H₂S screening indicator detected in this sample on [date]. This does not establish E. coli presence or absence.

   > H₂S screening indicator not detected in this sample on [date]. This does not establish E. coli presence or absence.

4. **Total coliforms:** They are not identical to fecal indicators. Display analyte names exactly; do not relabel total coliforms as E. coli or infer fecal contamination solely from that label. (Blueprint, p. 12.)
5. **Scope of a negative:** A negative microbiological result does not settle chemical hazards, future contamination or other points in the distribution network. Water appearance, odor or TDS alone does not establish microbial safety, and a resident symptom report does not identify an illness-causing tap. (Blueprint, pp. 4, 11-12.)
6. **Sanitary inspection:** Use the applicable versioned WHO source-type package for a motorized borehole, piped storage tank or distribution network. Retain each question's source identifier, technical rationale and approved local modifications. An inspection is a risk-control aid, not a laboratory result. (Blueprint, p. 12, references S5-S7.)
7. **Treatment and health advice:** Do not generate treatment instructions with an LLM or release machine-translated hazard instructions without review. Any advisory needs qualified review for the measured hazard and local conditions; boiling does not make chemically contaminated water safe. No automatic medical diagnosis, regulator contact or certification is implied. (Blueprint, pp. 5, 8, 11-12.)

## 6. Lifecycle and authority wording

Keep these objects separate. Their states are not synonyms. (Blueprint, pp. 12-13.)

| Object | Blueprint lifecycle | Wording consequence |
| --- | --- | --- |
| Sample/result | Collected -> received -> valid / rejected -> tested -> reviewed -> published / superseded | Intake, testing, authorized review and publication are different events. |
| Work order | Proposed -> approval pending -> assigned -> in progress -> completed -> accepted / rework | A completed or accepted repair is not verified incident resolution. |
| Incident | Reported -> triaged -> assigned -> mitigation / work -> verification pending -> resolved / reopened | Closure requires the incident's evidence and authority, not a work-order button. |

Before wording can imply resolution, applicable checklist and sample requirements must be fulfilled, results appropriately reviewed, reviewer authorization recorded and communication recorded. The authorized manager's action remains distinct from the laboratory's attestation. Privileged transitions require server confirmation. (Blueprint, pp. 6, 13, 16.)

Hard invariants to preserve in screens, notifications and simulation:

- No official "independently verified" status without an authorized laboratory reviewer and linked report.
- Rejected samples cannot satisfy verification requirements.
- A client-side work-order button cannot resolve an incident.
- Laboratory corrections preserve the earlier result, reason, actor and timestamp through superseding revisions.
- An open incident cannot be hidden by an older normal test.
- Revoked QR identifiers cannot silently reattach to another asset without an audit event.
- Repeated verified findings, new evidence or invalidated verification can reopen a case; preserve its previous closure trail.
- Internal escalation is not proof that a government agency was contacted. External notification requires the authorized arrangement and confirmed delivery evidence. (Blueprint, p. 13.)

## 7. Simulation disclosure and do/don't examples

Use the current full banner verbatim, retaining its line break:

```text
SIMULATED DEMONSTRATION
Generated records, not real water tests.
```

The compact application banner is `SIMULATED DATA · No real water tests`. Its accessible disclosure is `Simulated demonstration. No real water tests.` A generated review badge says `Simulated lab review`. Submission exports and presentation materials retain `SIMULATED DEMO DATA` as required by the [evidence appendix](../submission/evidence-appendix.md). Keep a visible disclosure with any generated status, screenshot, shared point record or result. (Blueprint, pp. 21, 23-24; existing application and submission contracts.)

Generated observations, results and timeline progression must come from the seeded event engine and real guarded transitions, not a hand-authored status carousel. Record the model version, seed and exercise clock; do not treat synthetic event counts, turnaround or outcome rates as measured facility or research results. Physical sample collection and scientific review remain outside the simulator. (Blueprint, pp. 3, 21, 24; simulation contract.)

| Don't | Do |
| --- | --- |
| Call an uploaded, unreviewed file an "independently verified result". | Keep its review stage visible; use "A water-quality concern is being investigated." when that public state applies. |
| Replace an open confirmed finding with "maintenance in progress". | Keep "A verified [indicator] finding was recorded on [date]." primary and add "Work is underway. Verification has not yet been completed." |
| Call a rejected follow-up a reassuring negative. | Show "No valid result from this sample." and retain the open verification requirement. |
| Call a current screen refresh a fresh sample or live sensor reading. | Show collection, testing, review and publication dates separately, plus the simulated record clock where applicable. |
| Present generated lab findings as a pilot success, partner endorsement or water test. | Retain the simulation banner and `Simulated lab review`; publish only actually observed research results with their methods and limitations. |

Planned scientific and comprehension review is described in the [validation plan](../research/validation-plan.md). This guide's existence is not evidence that either review has happened.
