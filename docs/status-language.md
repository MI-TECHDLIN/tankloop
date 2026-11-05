# Status language

Claims preserve source, verification stage, operational concern and freshness independently. Inspection observations, H₂S screening, total coliforms and E. coli results are not interchangeable. A work-order completion is not an incident resolution.

## Blueprint microcopy

The following pairs retain the blueprint's microcopy (page 11):

| Do not write | Write instead |
| --- | --- |
| "SAFE" | "No E. coli detected in this sample on [date]; other hazards were not assessed." |
| "Contaminated: tank lid missing" | "Inspection risk observed: tank lid missing. No test result is implied." |
| "All issues fixed" | "Repair recorded; verification is still pending." |
| "Verified forever" | "Last independently reviewed result: [date], for [indicator]." |
| "Report failed" | "Your report was saved on this device. We will upload it when a connection is available." |

The current inspection UI gives explicit **Sync now** actions and says pending work remains on-device until acknowledged. It does not promise background upload or say "saved" before persistence completes.

## Public states

These phrases follow the blueprint's public-state table (page 12):

| State | Wording |
| --- | --- |
| No valid current data | "We do not have a current verified test record for this point." |
| Risk observed | "Inspection concern reported on [date]. Testing may be needed." |
| Under investigation | "A water-quality concern is being investigated." |
| Confirmed finding | "A verified [indicator] finding was recorded on [date]." |
| Corrective action underway | "Work is underway. Verification has not yet been completed." |
| Follow-up reviewed | "Follow-up sample reviewed on [date]; [exact finding]." |

Confirmed findings remain primary while open, even when work is underway or a newer sample looks normal. Work progress can appear as an additional accountable-response statement. Missing current data is also shown when a concern remains open.

The public page always includes:

> A test describes one sample, at one point, at one time. It does not establish the safety of the whole water system.

It also shows the exact indicator, method, reported value, units, detection limit, collection/test/review/publication times, provenance and simulation labeling. Standardized wording uses UTC dates; detailed timestamps use the facility time zone and include its abbreviation. Historical tests remain visibly historical.

Unknown/revoked QR and service failure pages make no current water-quality claim. A missing, rejected or unreviewed result is never rendered as a valid negative. H₂S copy explicitly says it does not establish E. coli presence or absence. No screen generates treatment instructions or represents a simulated laboratory review as real evidence.

Authoritative projection logic: `packages/domain/lib/src/public_record.dart` and `supabase/migrations/202611050003_public_projection.sql`.
