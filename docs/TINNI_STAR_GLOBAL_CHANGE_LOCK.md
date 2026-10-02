# Tinni Star — Global Change Lock

<!-- GLOBAL_CHANGE_LOCK_V1 -->

- Canonical product source: `docs/TINNI_STAR_COMPLETE_IMPLEMENTATION_BLUEPRINT_V3.md`.
- Legacy Tinni Star blueprints have been removed and must not be recreated or used for rollback.
- Current implementation and latest explicit user-confirmed behavior are locked.
- The **latest explicit user instruction wins**.
- If the user has not asked to change it, keep it as it is.
- A new request is additive unless the user explicitly says remove/replace/change.
- Merges, cherry-picks, branch recovery, refactors, fixes and dependency changes must preserve unrelated locked behavior.
- Every intentional behavior change must update the canonical blueprint in the same change set.
