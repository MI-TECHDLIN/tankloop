# Server command boundary

This slice uses PostgreSQL `SECURITY DEFINER` RPCs, versioned in `../migrations/`.
Each command fixes its search path, derives the actor from `auth.uid()`, checks
active facility membership, and commits the state change and audit together.

`lookup_public_record` is the only anonymous read surface. The Flutter clients
use the publishable/anon key. Provider notifications and public concern moderation
are deferred.

`prepare-handover` is an authenticated, read-only Edge Function for staff draft
assistance. It uses the caller's JWT and `handover_snapshot` invoker RPC, never a
service-role client. Groq credentials stay in server secrets. See
[handover configuration, boundaries and evaluation](../../docs/handover.md).
