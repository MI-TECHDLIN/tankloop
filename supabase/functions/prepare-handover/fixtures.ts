import { type Snapshot, type Source } from "./core.ts";

// Synthetic evaluation data only. Never inserted into operational tables.
export const actor = "90000000-0000-4000-8000-000000000001";
export const pointId = "50000000-0000-4000-8000-000000000001";
export function source(kind: string, fields: Source["fields"], n = 1): Source {
  const record_id = kind === "point"
    ? pointId
    : `70000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
  return {
    id: `${kind}:${record_id}`,
    record_id,
    kind,
    revision: "a".repeat(32),
    is_simulated: false,
    fields,
  };
}
export function fixture(): Snapshot {
  return {
    kind: "point",
    id: pointId,
    label: "Evaluation outlet - synthetic fixture",
    organization_id: "10000000-0000-4000-8000-000000000001",
    facility_id: "20000000-0000-4000-8000-000000000001",
    sources: [
      source("point", {
        label: "Evaluation outlet",
        asset_id: "40000000-0000-4000-8000-000000000001",
      }),
      source("inspection", {
        state: "scheduled",
        due_at: "2026-11-09T12:00:00+00:00",
        version: 0,
      }),
      source("incident", {
        state: "verification_pending",
        has_owner: false,
        reported_at: "2026-11-08T12:00:00+00:00",
        version: 2,
      }),
      source("work_order", { state: "completed", due_at: null, version: 3 }),
      source("result", {
        state: "superseded",
        source: "laboratory",
        collected_at: "2026-10-09T12:00:00+00:00",
        value: "12.50",
        units: "cfu_per100ml",
        indicator: "e_coli",
        detection_limit: "1.00",
      }),
    ],
    counts: { point: 1, inspection: 1, incident: 1, work_order: 1, result: 1 },
    limit_per_kind: 8,
  };
}
