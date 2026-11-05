# TankLoop recorded demo script

<!-- Blueprint p.23: 3–4 minute recorded presentation. Blueprint p.10: calm, precise, field-ready language. -->

**Target length:** approximately 3 minutes 35 seconds  
**Recording note:** Every record, name, timestamp, result, photo, and status shown below is **simulated for demonstration**. Keep a visible `SIMULATED DEMO DATA` label on screen throughout. Do not describe the scenario as a pilot, test, or real water-quality finding.

## 0:00–0:25 — Problem and promise

“TankLoop is a water-quality accountability platform. It is designed for facilities where information can be split between paper, WhatsApp, staff memory, and laboratory reports.

The problem is not simply missing data. The handoff can break: an inspection notices a risk, a sample is collected, a result arrives, someone must authorize a response, and residents need an honest update. TankLoop connects those steps without pretending that software can test water.

This entire walkthrough uses simulated records. TankLoop does not sense contamination and never declares water safe.”

## 0:25–0:55 — Inspection

“I’m starting as a field inspector at the simulated Riverside Hostel facility. I open the water point record for `Tank 01` and begin the versioned inspection checklist.

The checklist records observable conditions separately from laboratory evidence. In this simulated inspection, I mark the tank lid as damaged and add a note that standing water is visible near the access point. I attach a simulated photo and save the inspection.

The app can preserve a draft when connectivity is unavailable. The inspection is now an observed risk, not a test result. TankLoop records who submitted it, when, and which asset it concerns.”

## 0:55–1:25 — Sample and lab result

“The manager creates a simulated sampling task for the same point. A collector registers sample `SIM-2026-0042`, records the collection time and chain-of-custody handoff, and sends it to the lab workflow.

In the lab view, an authorized reviewer would accept or reject the sample, record the method and units, and attest the result. For this demo, the reviewer and result are simulated. I enter a simulated microbial finding and keep its provenance visible.

This is not a claim about Riverside Hostel or about tested water. It shows the separation between an inspection, a sample, and a reviewed laboratory record. A rejected sample could not satisfy verification.”

## 1:25–2:05 — Incident and corrective action

“The simulated reviewed result meets the configured incident trigger, so TankLoop opens an incident rather than silently changing a dashboard color.

The manager triages it, assigns an owner, sets a due date, and records a simulated interim measure. The work order moves through proposed, approved, assigned, in progress, and completed. Each transition retains an actor, reason, timestamp, and evidence reference.

The important guardrail is that completed repair is not the same as verified resolution. The incident remains open and moves to `verification pending`. Residents are not told that the water is safe; the public status can say that a concern is under investigation or that corrective action is underway.”

## 2:05–2:40 — Follow-up verification

“After the simulated repair, the team collects a second sample according to the simulated sampling plan. The follow-up result is also simulated. It is linked to the original incident and reviewed through the lab workflow.

Only when the required follow-up evidence, reviewer authorization, and communication record are present can the incident move to a resolved state. If the follow-up is missing, rejected, or shows a repeat concern, the incident stays open or reopens. Earlier results and corrections remain in the audit trail.”

## 2:40–3:10 — Public QR record

“Finally, I scan the simulated QR code on the water point. The public record is a narrow, read-only view: the point nickname, last published record, date, evidence scope, and any outstanding concern.

The page shows that this is simulated data and states what was not assessed. It does not expose private reporter information, unreviewed attachments, or an all-purpose safety score. A resident can report a concern without needing access to the internal workspace.”

## 3:10–3:35 — Trust, validation, and limitations

“TankLoop’s trust model keeps four things distinct: evidence source, verification stage, operational concern, and freshness. That prevents a green label or one negative result from being mistaken for a complete safety determination.

Before real deployment, we would validate the accountability gap with facility interviews, walk through the workflow with two or three lab partners, observe a maintenance decision, test resident comprehension, test low-end Android offline behavior, and compare the workflow with a paper or WhatsApp baseline.

This demo proves a designed workflow with simulated data. It does not prove water quality, treatment effectiveness, regulatory compliance, or deployment readiness. Those require qualified people, real sampling, governance, privacy review, and field validation.”

