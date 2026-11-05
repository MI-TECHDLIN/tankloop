# Pre-submission validation plan

**Status: Planned as of 05 November 2026.** No interviews, partner agreements, comprehension results, device outcomes or research-gate passes are asserted by this document. Every activity, recruitment count, checklist and review below is **Planned** until an attributable evidence record establishes what actually happened.

**Research window:** 06-19 November 2026, inclusive, with 20 November reserved for publication and verification. The entry must be published **before 21:00 UTC on 20 November 2026** (22:00 WAT). Target publication at 18:00 UTC to leave recovery time; a repository push is not proof that the competition project page is published. (Blueprint, p. 22.)

**Source:** *TankLoop Full Product Blueprint Flutter*, Product Requirements + System Design v1.0, prepared 01 November 2026. The six research gates are on p. 21; acceptance and measurement guidance is on pp. 19-21; honest-result and demonstration boundaries are on pp. 22-24.

This is a short process-feasibility, usability and comprehension study. It cannot establish water-quality prevalence, treatment efficacy, reduced illness, regulatory approval or production readiness. The prototype's water records remain visibly simulated even when a real person completes a task. Observed human task results and synthetic water records must remain separate. (Blueprint, pp. 3, 21, 24.)

## 1. Ownership, recruitment and evidence discipline (Planned)

Assign names to these roles before the first session. Roles can overlap; each session still needs a facilitator and an independent note-taker, and the engineer should not coach a participant through the interface.

| Owner role | Responsibility |
| --- | --- |
| Research lead | Facility permission, participant recruitment and consent, past-event interviews, resident sessions, baseline comparison and research register. |
| Evidence lead | Laboratory outreach, method/custody walkthroughs, qualified reviewer identification, wording review and claim-to-source checks. |
| Engineering lead | Reproducible generated scenarios, build/device inventory, isolated demo setup, offline fault exercises and implementation handoffs. |

Recruitment targets, not achieved counts:

- One consenting design-partner facility, with a manager and field lead; pursue a reserve facility if access falls through. No facility partnership is claimed until permission is documented.
- Discovery: two caretakers/collectors, two managers/approvers and four residents, using 20-30 minute interviews. Seek concrete past events, not favorable general opinions.
- Laboratory feasibility: two or three qualified laboratory partners, using 45-60 minute walkthroughs. At least one must provide written method/handling feasibility and identify an authorized reviewer to meet the testing-operability gate.
- Resident comprehension: eight formative participants and eight different final-round participants, with variation in literacy, language preference and Android/browser familiarity. Final participants must not have seen the formative tasks or baseline comparison.
- Baseline comparison: six operational participants doing role-relevant paired tasks; these may be discovery participants. Report overlap and role composition rather than counting repeat participation as new independent evidence.
- Offline evaluation: two physical low-end Android devices, targeting one 2 GB RAM device and one 3 GB RAM device if available. Record actual models and Android versions; emulator-only results do not pass the physical-device gate.

These are small convenience samples, not representative population samples. Recruitment shortfalls, refusals, access problems and unavailable language variants are limitations, not grounds to invent or silently replace evidence. (Blueprint, pp. 6, 21-23.)

Before recruitment or collection:

- [ ] Obtain facility permission for interviews, record inspection, photographs and any maintenance observation; agree what may be quoted publicly.
- [ ] Obtain voluntary participant consent and separate permission for recording, quotations or photographs. Permit skipping questions and stopping without penalty.
- [ ] Explain that the prototype does not test participants' drinking water, and all exercise water records are generated and labeled simulated.
- [ ] Keep contact details, consent records, raw media and private operational/lab documents in access-controlled research storage, not the public repository. Publish only de-identified, consented material.
- [ ] Agree research-data access, retention/deletion and responsible owners before collection; do not invent a deployment legal policy. Seek qualified review before real deployment.
- [ ] Freeze task prompts, scenarios, scoring, recruitment targets and decision thresholds before the first scored session; date the protocol version. Record later changes and keep cohorts separate.

(Blueprint, pp. 2, 18-21.)

## 2. Research gates and proposed decision thresholds (Planned)

The thresholds below are proposed study decision rules, not WHO standards or statistically powered proof. Approve and preregister them, with a dated protocol version, before data collection. A failed or untested gate stays open; a deadline does not turn it into a pass. (Blueprint, pp. 20-23.)

| Gate | Planned activity | Evidence required to meet the gate | If evidence is missing or contrary |
| --- | --- | --- | --- |
| R1: Is the accountability gap real? | Past-event interviews and consented record review. | At least two specific concern-to-response timelines corroborated by another role or a dated record; locate an actual delay, missing owner, communication failure or failed follow-up. | Describe the gap as a hypothesis. If funding or lab access is the main barrier, revise the problem/operating-model claim instead of claiming software solves it. |
| R2: Can testing be operated correctly? | Two or three lab-partner walkthroughs. | Written method/handling feasibility, costs and turnaround, intake/rejection criteria, custody requirements and a designated qualified reviewer from at least one partner. | Keep real sampling and laboratory partnership unvalidated; show synthetic workflow only, with no tested-water claim or endorsement. |
| R3: Will managers approve action? | Observe one real maintenance/spending decision with permission. | Trace a named approver, resources, authority limits, approval evidence and reliable internal escalation route. | A role-play can diagnose the prototype but cannot satisfy this real-observation gate. State the authority/funding constraint. |
| R4: Do residents understand the portal? | Unassisted formative and final-round tasks. | Final cohort of eight: no critical false reassurance, no repair-as-resolution interpretation and no synthetic-as-measured interpretation; at least seven correctly interpret each scored date/scope/currentness/next-step task. | Revise presentation, retest with new participants, or leave comprehension unvalidated. Do not release safety-relevant claims merely to meet the competition date. |
| R5: Does offline design work? | Physical Android tests with controlled interruptions and identity/permission failures. | No lost saved actions, duplicate accepted events, misleading publication or cross-account cached data; eligible queued actions receive receipts after foreground retry. Record unsupported features separately. | Hand defects to engineering, rerun affected scenarios and limit the capability claim to what actually passed. |
| R6: Is the workflow better? | Counterbalanced paired scenarios versus the facility's paper/WhatsApp process. | Paired observed data support improved owner/deadline or evidence completeness without worse safety interpretation; disclose task-time tradeoffs and all failures. | Make no improvement claim. Retain the baseline's strengths and investigate the actual bottleneck. |

R1-R6 currently all have status **Planned**, with no recorded results. The final cohort thresholds are usability release gates, not a claim that all residents will understand the product. (Blueprint, p. 21.)

## 3. Fourteen-day execution calendar (Planned)

Dates are November 2026. Record appointment and evidence timestamps with their time zones. Batch interviews and tests so analysis and consent work are not deferred until submission day.

| Date | Planned work and owners | Planned checkpoint/output |
| --- | --- | --- |
| 06 | Research: permissions, consent, recruitment and protocol freeze. Evidence: contact lab partners. Engineering: inventory builds, devices and safe demo environment. | Named owners, dated protocol, outreach log and explicit missing-access list. |
| 07 | Research: field/collector past-event interviews. Evidence: first lab walkthrough. Engineering: generated scenario catalogue. | Consented event timelines; method/custody questions; seed/model/day references. |
| 08 | Research: resident past-event interviews. Evidence: second lab walkthrough. Engineering: install/warm the Android builds and capture device baselines. | Communication timelines, partner notes and actual device inventory. |
| 09 | Research: manager/approver interviews and request a real maintenance observation. Evidence: optional third walkthrough. Engineering: first airplane-mode/restart exercises. | Authority map, partner feasibility gaps and first fault records. |
| 10 | Research: synthesize R1 and run four formative resident sessions. Evidence: draft handling/method feasibility for partner confirmation. Engineering: reconcile offline records/receipts. | R1 decision evidence, formative scores and loss/duplicate checks. |
| 11 | Research: remaining four formative sessions. Evidence: confirm reviewer identity, report/rejection/correction rules and written feasibility. | R2 checkpoint; complete formative findings with no outcome claims yet assumed. |
| 12 | Research: observe the maintenance/spending decision if permission and timing allow. Evidence: review disputed scientific wording. Engineering: receive prioritized usability/safety defect handoffs. | R3 evidence or explicit non-completion; wording issues and next decisions. |
| 13 | Research: first three paired baseline sessions. Evidence: check scenario scope and approval conditions. Engineering: implement approved fixes in its own workstream and continue offline fault tests. | Paired task sheets; versioned fixes and fault outcomes. |
| 14 | Research: remaining three paired baseline sessions and first four final comprehension sessions on the frozen revision. Engineering: second-device offline batch. | R6 paired dataset; first final-round scores; device outcomes. |
| 15 | Research: remaining four final comprehension sessions. Evidence: review scope/uncertainty interpretations. Engineering: complete ordinary queued-action and negative authorization tests. | R4/R5 checkpoint with raw denominators and critical errors. |
| 16 | Research: score paired comparisons and both resident cohorts separately. Evidence: assess lab/governance gaps. Engineering: reproduce and triage any failures. | Gate decisions, contrary evidence and constrained claim list. |
| 17 | Engineering: rerun affected device cases after fixes. Research/evidence: retest changed wording with a fresh full final cohort if recruitable; otherwise leave R4 open. | Linked before/after artifacts; no selective replacement of failed answers. |
| 18 | Research: populate the evidence appendix. Evidence: trace every claim to a source or observed result. Engineering: supply build hashes, fault logs and reproducible demo references. | De-identified results, limitations and completed/planned/not-run distinctions. |
| 19 | Cross-review appendix, wording, consent, simulation disclosures and recorded presentation; freeze the demonstrated build. | Final claim audit and publication package, with every unresolved gate disclosed. |

**20 November publication checkpoint (Planned):** Publish by the internal 18:00 UTC target, inspect the competition page's published state, links and simulation labels, and retain a timestamped confirmation before the hard 21:00 UTC deadline. If research is incomplete, publish an honest simulated demonstration with the missing evidence disclosed, not a live water-safety service. (Blueprint, pp. 22-24.)

## 4. Past-event interview guides (Planned)

Use neutral prompts. Ask participants to reconstruct the most recent specific event before showing TankLoop. Do not ask "Would you use our helpful app?" or treat intent to adopt as observed adoption. Obtain consent before copying a record. (Blueprint, pp. 4, 6, 21.)

### Caretaker, inspector or sample collector

1. "Tell me about the last water concern, inspection problem or test request you handled. When and at which part of the system did it start?"
2. "What did you observe yourself, and what came from someone else or a laboratory?"
3. "Show how it was recorded, if you are comfortable doing so. Who received it, and how do you know?"
4. "Who became responsible, and was there a deadline? What happened next, in order?"
5. "What required approval, money, supplies or transport? Where did work wait?"
6. "Was sampling needed? Who chose the point/method, labeled the sample and handled its transfer? Was anything rejected or repeated?"
7. "How did you know the action was complete, and how did you know the concern was resolved? Was there a follow-up check?"
8. "What happens when the phone has no data, runs out of battery or is shared? Tell me about a specific lost or duplicated record."
9. "What was communicated to residents, by whom, and when? What remains unresolved?"

### Manager, warden or spending approver

1. "Walk through the last water-related maintenance decision from first notice to approval or refusal."
2. "What evidence reached you? Which sources could you rely on, and what was missing?"
3. "Who could authorize work and spending? What limit, substitute approver or escalation route applied?"
4. "Where did delay occur: information, authority, funding, contractor availability, laboratory access or another cause?"
5. "What proof did you require for repair completion and for case closure? Who reviewed follow-up evidence?"
6. "Who can approve a resident notice? Is any external reporting arrangement actually authorized?"
7. "Which record lets another person audit the decision? What would you refuse to publish?"
8. "What procurement, recurring service or lab cost would prevent use even if the interface worked?"

### Resident

1. "Describe the last time you had a concern about water here. What did you notice, and what did you do?"
2. "Where did you get information? What did the message actually say, and when?"
3. "Did you know who was responsible and what would happen next? How did you find out whether anything changed?"
4. "What did a test, repair message or absence of news mean to you? What did you still not know?"
5. "Which phone, browser and language would you normally use to read a notice? What makes a page hard to use?"
6. "What concern would you report, and what information would you prefer not to share publicly?"

For each event, record discovery, recording, assignment, approval, action, verification and communication timestamps where known; mark missing/uncertain times, evidence source, accountable role, observed bottleneck and contrary explanations. Corroboration is recorded explicitly, not assumed because several people share an opinion. Do not collect medical histories or claim that a reported illness was caused by a particular water point. (Blueprint, pp. 3-4, 14, 21.)

### Maintenance decision observation

- [ ] Obtain permission before observing a real decision or reviewing its record.
- [ ] Trace the trigger, available evidence, decision-maker, approval limit, requested amount/resources and actual approval/refusal.
- [ ] Record handoffs, elapsed waits, substitute approver and what happens when resources are unavailable.
- [ ] Separate an approved repair from completed work and from reviewed verification.
- [ ] Identify resident-notice authority and the internal escalation route; do not send or promise external notices.
- [ ] Ask the manager to check the factual sequence and permitted public summary. A simulated exercise remains simulated and does not satisfy R3.

(Blueprint, pp. 6, 13, 21.)

## 5. Laboratory-partner walkthrough (Planned)

Send the partner the [safety wording guide](../safety/status-language.md) and a visibly generated example before the meeting. Ask for a feasibility review, not endorsement of TankLoop or attestation that synthetic water was tested. Do not call a lab accredited, independent or partnered without supporting qualification/permission. (Blueprint, pp. 6, 8, 21, 23.)

Walk a connected source/tank/tap example through collection, intake, result, correction and follow-up:

- [ ] **Qualification and scope:** organization, relevant method capability, qualification/accreditation evidence where applicable, reviewer identity/authority and conflicts of interest.
- [ ] **Study question and locations:** stable point IDs, connected system, purpose, indicator/analyte and method-specific follow-up requirements. A tap result cannot stand in for every point.
- [ ] **Collection requirements:** partner-specified container, sample volume, preservation, holding time, transport conditions, controls and collection training. Do not invent numeric limits from a generic app template.
- [ ] **Custody:** immutable sample ID, collector, collection time/time zone, seals, transfers, receiving actor/time and discrepancies; distinguish device-observed from received times.
- [ ] **Intake:** accepted/rejected criteria and reasons. Walk through a rejected sample and confirm it cannot become a valid negative or fulfill verification.
- [ ] **Method and reporting:** exact indicator, method/standard, quantitative or presence/absence format, units, reported value, detection limit and ambiguous/inconclusive outcomes.
- [ ] **Scientific interpretation:** E. coli, H₂S screening and total coliforms remain distinct; negative findings do not cover other hazards, future contamination or the whole network.
- [ ] **Review authority:** who may attest, what linked report is required, authentication, independence, any dual approval and separation from manager approval.
- [ ] **Corrections:** superseding revision preserves original result, reason, actor and time; clarify who is informed when verification is invalidated.
- [ ] **Follow-up/closure:** post-action timing, points, methods and acceptance criteria determined by the qualified partner; invalid/incomplete follow-up keeps the incident open.
- [ ] **Public language:** partner reviews the six state sentences, non-detection copy, scope caveat, freshness policy and hazard-specific advisory approval. No LLM-generated treatment instructions.
- [ ] **Operations:** written costs, turnaround, pickup/access constraints, capacity, report availability, privacy/data-sharing terms and permission to name the partner publicly.
- [ ] **Written output:** dated handling/method feasibility, designated reviewer, unresolved conditions and exact statements reviewed. Distinguish a review of the prototype from an agreement to provide real testing.

(Blueprint, pp. 8, 11-14, 18, 21.)

**Real field sampling remains Planned and conditional.** This schedule does not require it. Collect nothing until facility permission and laboratory sign-off cover the question, connected sampling points, repeat visits, method, containers, custody, times, controls and interpretation. If approved later, register that protocol separately before collection. A small site study supports feasibility and site-specific observations, not national prevalence or clinical impact. Without sign-off, disclose the open gate and keep water records synthetic. (Blueprint, pp. 21, 23-24.)

## 6. Resident comprehension protocol (Planned)

### Prepare the actual interface

Use the running generated demo and the exact shared wording, not a static hand-authored status carousel. Record build commit, model version, seed, day/exercise clock, route and point for each case. If ordering requires screenshots, capture actual rendered generated records, retain the simulation banner and label them as snapshots. Do not edit a screenshot to manufacture a state. A scenario not reachable in the tested build is not tested, not a presumed pass. (Blueprint, pp. 10-12, 21, 24; [simulation contract](../simulation.md).)

Cover all six public states plus the two adversarial cases below. Counterbalance case order across participants; use the same case set within a cohort.

| Case | Planned presentation | Correct interpretation to score |
| --- | --- | --- |
| C1 | No valid current data, including an expired review window. | No current qualifying record exists; this does not establish either safety or contamination. |
| C2 | Risk observed: missing tank lid. | An inspection risk, not measured contamination or an E. coli finding. |
| C3 | Under investigation: a resident concern awaiting review. | A concern requires investigation; the report is not a verified lab finding. |
| C4 | Confirmed finding with corrective work also underway. | The verified concern remains visible and open; work does not erase it. |
| C5 | Corrective action underway without completed verification. | Authorized response is underway; repair/work is not verified resolution. |
| C6 | Follow-up reviewed with a valid non-detection sentence. | Understand indicator, sample collection date and review date; other hazards/points/future conditions remain unassessed. |
| C7 | An older or newer normal sample alongside an open confirmed incident. | The sample does not hide or automatically close the current concern. |
| C8 | Rejected follow-up sample or unreviewed upload. | Not a valid negative or independent verification; required follow-up remains outstanding. |

### Run and score

1. Obtain consent, give only neutral navigation orientation, and note any prior exposure. Say: "We are testing whether people understand a prototype record. The exercise uses simulated water records; it does not test your drinking water. Please explain what you understand in your own words."
2. Ask the participant to open the point from its QR/link on their usual browser where possible. Record success, time, network condition and any assistance; no login requirement should be invented for public lookup.
3. For each case, ask without explaining the intended answer: "What does this record tell you?", "What was checked, where and when?", "What is still unknown or unfinished?", "What happens next, and where would you look or report a concern?" Ask which date is sample collection versus review when both appear.
4. Record the answer verbatim or in consented notes before any correction. Do not substitute satisfaction, a prompted yes/no answer or a facilitator's explanation for comprehension.
5. Code each case for evidence type, indicator/scope, dates/currentness, open concern/action, next step and simulation recognition. Also code critical errors: universal assurance, repair-as-resolution or simulated-as-measured interpretation. Ambiguous answers require a neutral clarification, not coaching; unresolved ambiguity does not count as correct.
6. A second scorer independently reviews de-identified responses against the frozen rubric. Preserve initial codes and resolve disagreements with reasons. Record assisted tasks as assisted and unsuccessful for the unassisted measure; do not drop them from the denominator.
7. After scoring, explain the limitations and reporting route. Do not tell participants that a real water source is safe or give generated treatment advice.

Test readable narrow-screen layout, large text, icon-plus-text warnings and the visible limitation before interpreting the finding. Screen-reader use is normal interaction, not coaching. English is the initial test language; release Pidgin or other hazard wording only after native-speaker and qualified review. State clearly which languages and accessibility modes were actually assessed. (Blueprint, pp. 10-12, 20-21.)

Allow 20-25 minutes per session, including consent and debrief. Run eight formative sessions to identify failures; hand problems to the appropriate owner. Freeze the revised build/protocol before the eight-person final round. Report both cohorts, every critical error and per-case/task denominators: for each applicable noncritical task in each case, at least seven of the eight final participants must interpret it correctly; any critical error anywhere prevents R4 passing. Any wording change after final testing invalidates that final result for the changed wording until a new full final cohort is tested; do not retest only the people who answered incorrectly and call the combined result a pass. If recruitment or time prevents retesting, disclose R4 as unmet. (Blueprint, pp. 21-23.)

## 7. Low-end Android and offline protocol (Planned)

Use a disposable test installation/account and isolated demonstration backend. Do not change shared or production infrastructure, fill a personal phone's storage, collect real samples or publish real resident notices for a fault exercise. Follow the [development setup](../development.md); record whether each run uses standalone simulation or the shared Supabase exercise. Independent simulation instances do not share submitted commands. (Blueprint, pp. 16-18; existing implementation/simulation contracts.)

Inventory each physical device: model, RAM, Android version, free storage, battery state, app/build commit, browser version, text scaling, permissions, backend mode, network and exercise clock. Warm/load authorized records online before interruption. Keep an expected list of command IDs and payloads so the final server receipts can be reconciled with saved actions.

| Test | Planned end-user procedure | Evidence and safe expected outcome |
| --- | --- | --- |
| O1: Local save and restart | Load an assigned inspection; enter airplane mode; complete and save it; close/terminate and reopen the app. | Same answers, notes, issued template, observed time and command ID survive. Show saved/pending only after durable persistence; no delivery/publication claim. |
| O2: Retry and lost acknowledgement | Restore connectivity, use **Sync now**, interrupt around acknowledgement, then retry and double-tap submission. | Reconcile one accepted command/receipt and at most one resulting concern; identical retry retains the original ID and receipt. No duplicate incident. |
| O3: Weak/captive network and interrupted upload | Repeat with weak signal/captive Wi-Fi and termination during submission. Test photos/partial attachments only if that build actually supports them. | Retained pending work and understandable recovery, not false success. Unsupported attachment behavior is recorded as not tested, never inferred from notes-only tests. |
| O4: Permission and account isolation | Queue a test action; revoke its dedicated membership; reconnect. Sign out and sign into a different authorized test organization/account. | Revoked submission is blocked, not acknowledged; no previous account's private cached assignments or records appear. Record any unavailable switching flow. |
| O5: Time and conflict | On the dedicated device, introduce clock skew; exercise two authorized clients submitting against an outdated version. | Device-observed and authoritative times remain distinguishable; authority/scientific/closure changes are not silently last-write-wins. Preserve blocked/conflict evidence. |
| O6: Public lookup offline/error | Open the QR page, lose connection, refresh, and try unknown/revoked identifiers. | Explicit unavailable/unknown or visibly cached/stale information; no fabricated live status or reassuring badge. A failed lookup makes no current water-quality claim. |
| O7: Privileged actions offline | Attempt applicable attestation, publication, approval and closure flows while disconnected. If the UI does not implement them, record that boundary. | No offline final authority or public publication. Do not claim testing of a flow that was unavailable; server/API tests are separate evidence. |
| O8: Failed local write and constrained UI | In an isolated test install/harness, exercise a failed persistence write; inspect 200% text scaling, narrow screens and screen-reader labels on the physical device. | A failed save never says saved. Warnings, dates, simulation labels and recovery actions remain readable and operable without color alone. |

(Blueprint, pp. 10-11, 16-17, 20-21.)

Run ten ordinary eligible offline actions per device across at least three disconnect/reconnect cycles. Record all attempted actions, including failed saves and intentional permission/conflict rejections. Compare saved IDs/payloads with receipts after each cycle and after restart. Observe for two minutes after each **Sync now** on a working connection; record any remaining pending action rather than assuming delivery. A later successful retry must have its own timestamped proof. The proposed gate requires zero lost saved actions, duplicate accepted events, false confirmed/public states or cross-account leakage, and eventual acknowledgement of every ordinarily eligible saved command before closing the test record.

Report `acknowledged offline actions / all submitted offline actions`, plus accepted, pending and intentionally blocked cohorts with their counts. Never hide rejected trials to inflate reliability. Record wall-clock save/retry times and explain network conditions; the simulation's event clock is not measured network or operational performance. (Blueprint, pp. 17, 20-21.)

The first slice does not promise background OS upload, cold offline web launch, encrypted local storage, full attachment capture or a conflict-resolution UI. Device outcomes, backend/authorization evidence and unavailable capabilities must be separate. Emulator or unit-test success is supporting technical evidence, not a substitute for this physical end-user test. (Blueprint, pp. 16-17, 20-21; [implementation boundaries](../implementation.md).)

## 8. Paper/WhatsApp workflow comparison (Planned)

Agree the facility's actual baseline with its operators before constructing the comparison. Use consented, redacted process examples and synthetic exercise data, not private resident messages or real public alerts. Obtain no treatment/repair outcome claim from a role-play. (Blueprint, pp. 4, 19-22.)

- Give six operational participants the same three-minute orientation to each tool and role-appropriate tasks, with a 15-minute cutoff per scenario. Use two matched generated scenarios with different point/date details but equivalent evidence, approvals, work and verification requirements; freeze the brief, checklist and cutoff before sessions.
- Counterbalance order: three use baseline then TankLoop, three TankLoop then baseline; counterbalance scenario assignment too. Record the allocation before sessions. Keep final resident-comprehension participants unexposed to this exercise.
- Provide the same starting information and task cutoff. Observe recording the source, assigning an owner/deadline, handling approval, attaching/locating required evidence, distinguishing repair from verification, and preparing an accurate resident update. Do not coach missing steps.
- Record unavailable TankLoop actions as unavailable and incomplete; do not replace them with facilitator-performed steps or a static mock and call the workflow complete. Restrict any improvement claim to the role/tasks actually observed.
- Measure owner-plus-deadline completeness, required evidence fields, correct verification handling, communication accuracy, task completion, observed elapsed task time, assistance and errors. Preserve paired rows by participant/role/scenario/tool rather than reporting only an aggregate favorable result.
- Report counts/denominators and paired changes; use medians and ranges for task time. Small convenience samples and learning effects limit inference. Scenario time is not real laboratory turnaround or actual time-to-repair.
- R6 is met only if observed completeness improves without worse safety interpretation. If the baseline matches or outperforms TankLoop, report that and adapt the claim. A hypothetical future improvement is not an observed result.

(Blueprint, pp. 19-22.)

## 9. Evidence register and appendix handoff (Planned)

Feed results into the existing [submission evidence appendix](../submission/evidence-appendix.md), without converting generated app records into research findings. The blueprint distinguishes source-backed material, design decisions and research gates; completed research also needs its method, actual observations and limitations. (Blueprint, pp. 2, 21-24.)

For each evidence item, record:

| Field | Required entry |
| --- | --- |
| Identity | Evidence ID, R1-R6 gate, precise claim/question, owner and date/time. |
| Research status | Planned initially; later record what actually ran, what completed, and what failed or was not run, with reasons. |
| Provenance | Source citation/page or consented session/device/partner reference; distinguish observed research, design proposal and synthetic water records. |
| Method | Protocol version, prompts/tasks, participant role/language and overlap, scenario allocation, build/model/seed/clock or device/network conditions. |
| Observation | Raw count and denominator, timed measure where applicable, qualitative finding and contrary evidence. Leave results empty while Planned. |
| Proof | Access-controlled raw artifact reference plus a de-identified public summary/consented quote; qualification and sign-off reference where required. |
| Decision | Proposed threshold, actual gate outcome, limitation, owner of the resulting change and any linked retest. |

Planned gate-to-appendix outputs:

| Gate | Planned appendix material | Current status |
| --- | --- | --- |
| R1 | Corroborated event timelines, bottlenecks, alternative explanations and permission-safe excerpts. | Planned; no observations recorded. |
| R2 | Method/handling feasibility, qualification/reviewer evidence, cost/turnaround constraints and unresolved agreements. | Planned; no partner sign-off recorded. |
| R3 | Approval/spending chain, escalation authority and observed resource constraints. | Planned; no decision observation recorded. |
| R4 | Separate formative/final scores, denominators, critical errors, tested wording/build/languages and limitations. | Planned; no comprehension results recorded. |
| R5 | Physical-device inventory, command/receipt reconciliation, fault outcomes, defects and unsupported features. | Planned; no device outcomes recorded. |
| R6 | Counterbalanced allocation, paired task data, completeness/time/error comparisons and contrary findings. | Planned; no comparison results recorded. |

At the 18-19 November review:

- [ ] Replace no planned count with an achieved count unless its underlying artifact supports it. Do not copy the blueprint's illustrative success numbers as results.
- [ ] Trace every public claim to its source or actual observation; label a design proposal, simulated exercise and observed participant result distinctly.
- [ ] Include recruitment shortfalls, refusals, assisted tasks, failed trials, missing partner permissions and all untested capabilities.
- [ ] Link accepted changes and retests; do not claim that documenting a fix proves it works.
- [ ] Redact identifying/private information and publish quotations/partner names only with permission.
- [ ] Check every generated screen, result, export and recording for a visible simulation disclosure using the [safety wording guide](../safety/status-language.md).
- [ ] Obtain qualified scientific review for any hazard/advisory wording actually released; disclose absent review instead of implying endorsement.
- [ ] Keep real deployment permissions, method approval, privacy/retention, public-notice authority and production operations as open gates unless separately evidenced.
- [ ] Confirm the published competition page before the deadline and retain timestamped publication proof.

Permitted reporting form: "In [actual number] simulated workflow sessions using [build/protocol], [observed count]/[actual denominator] completed [task], with [limitations]." This describes measured task behavior around simulated records, not tested water or reduced contamination. No result may claim water certification, national prevalence, illness reduction or a successful live pilot from this two-week plan. (Blueprint, pp. 3, 21-24.)
