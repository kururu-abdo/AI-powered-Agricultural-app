# Foundation architecture

## Dependency direction
View → Riverpod Notifier (ViewModel) → use case/repository interface → data implementation → SDK.
Domain entities and repository contracts use plain Dart. Firebase types remain in data/core.
Provider factories bind interfaces to implementations. Views must not query Firebase directly.
Add use cases for business workflows; do not create forwarding classes without a purpose.

## Structure
- `app/`: composition, theme, future navigation and localization.
- `core/core_database/`: Firebase setup, SDK providers and future local storage adapters.
- `core/core_network/`: future external HTTP APIs only.
- `core/core_security/`: future device unlock and secret storage.
- `core/core_ai/`: future on-device runtime, model lifecycle and vector index.
- `features/farm_membership/`: farm entities, server adapters, Riverpod state and UI.
- `security_tests/`: local Firestore emulator tests; never deployed.
- `features/<feature>/domain/`: entities, repository contracts, use cases.
- `features/<feature>/data/`: models, data sources, repository implementations.
- `features/<feature>/presentation/`: views, view_models, widgets.
- `shared/widgets/`: UI reused across features once needed.

Home, account recovery/verification and farm membership are implemented. Other modules remain
planned. Authentication uses a plain-Dart contract and a Firebase adapter, with
Riverpod command state separate from the session stream. See AUTHENTICATION_STEP_BY_STEP.md.

## Firebase and offline boundaries
Firebase Authentication owns credentials and token refresh. Never store passwords
for offline login. A previously persisted session plus device unlock is a distinct
flow from an online sign-in; implement it with explicit offline access policy.

Cloud Firestore is the primary backend document database. Its SDK can provide
persistent cache and pending document writes, but persistence is DISABLED in the
current release: all implemented farm data is authorization metadata, fetched
from the server. A future agricultural data layer must add scoped encrypted
offline storage and a safe cache/pending-write policy. Do not duplicate those
writes in a Dio queue. Treat snapshot isFromCache and hasPendingWrites separately:
cache provenance is not a connectivity signal, and pending writes are not success.
Write Futures may wait for server acknowledgement while offline; use local UI state
and snapshot metadata instead of blocking screens on acknowledgement.

The cache holds previously accessed data and may evict it. It is not a guaranteed
complete offline farm download, an encrypted SQLCipher store, a vector database,
or a durable AI model store. Before field use, add explicit offline packs for
selected farms, guides, models and media, with completeness checks and versions.
No app-level cache encryption is claimed in this foundation.

Future sync_manager observes Firestore state and owns a separate idempotent outbox
for media uploads or non-Firestore operations. Use immutable diagnostic IDs and
versioned plans; do not blindly use last-write-wins for agronomic decisions.
Cloud fallback must be a visible, consented policy, never an automatic upload of
private conversation/context simply because the connection returned.

## Tenancy and security
Implemented paths are `farms/{farmId}`, `farms/{farmId}/members/{uid}` and the
user-specific discovery mirror `users/{uid}/farms/{farmId}`. Flutter performs
online Firestore transactions directly. Security rules validate verified identity,
existing ownership, immutable owner fields and consistent membership/mirror state
using getAfter(). No Firebase Functions or Admin SDK is used. See
ACCOUNTS_AND_FARMS.md for the role matrix and transaction walkthrough.

At startup, the previous foundation's persisted Firestore cache is cleared before
use; no client farm writes or offline outbox exist yet. On logout Riverpod results
are invalidated. Do not keep clearing caches once offline agricultural writes are
introduced: add per-user data isolation and pending-operation reconciliation first.

## AI and scheduling (deferred)
Choose CV and LLM runtimes separately after measuring target Android/iOS hardware.
Require model hash/signature validation, resumable downloads, storage/RAM checks,
cancellation, lifecycle cleanup, model provenance and rollback. Do not infer soil
chemistry or definitive diagnoses from photos; expose uncertainty and expert escalation.
Use scheduled local notifications for farmer reminders; background workers are
best effort and do not guarantee an exact reminder time.
