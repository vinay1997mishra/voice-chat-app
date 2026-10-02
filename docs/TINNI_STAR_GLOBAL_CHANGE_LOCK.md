# Tinni Star — Global Change Lock

<!-- GLOBAL_CHANGE_LOCK_V1 -->
## GLOBAL CHANGE LOCK — USER AUTHORITY ONLY

**Baseline:** everything currently implemented in Tinni Star and everything currently documented in this blueprint is locked by default.

Rules:
- No existing screen, layout, visual hierarchy, button, navigation path, function, backend rule, permission boundary, wallet/gift rule, room/seat behavior, realtime behavior, game behavior, profile/CP/family behavior, Owner/Admin behavior, asset placement, category, counter, timer, sorting rule, or other current app behavior may be removed, replaced, renamed, reordered, resized, restyled, weakened, or reverted unless the user explicitly asks for that specific change.
- A new request is additive by default. It must not silently delete or replace an older working function unless the user explicitly says to remove/replace/change it.
- Bug fixes, crash fixes, build fixes, security fixes, performance work, refactors, backend migrations, and dependency upgrades may be done without separate design approval only when they preserve the locked product behavior. If they would change user-visible behavior or product rules, explicit user instruction is required first.
- Where an older blueprint line conflicts with a newer user-confirmed rule, the **latest explicit user instruction wins**, and the blueprint must be updated in the same change so the old rule cannot return.
- Sections labeled CLEAR, PARTIAL, VIDEO/ASSET NEEDED, or unresolved may be completed only from a new user instruction/reference; do not invent a replacement behavior that changes already-working surfaces.
- Merges/cherry-picks/branch recovery must preserve the locked current behavior. Older branches, old screenshots, old layouts, or legacy code must never overwrite newer confirmed behavior.
- Every intentional product-behavior change must update the relevant blueprint rule in the same commit/change set.
- This global lock remains in force until the user explicitly changes or revokes it.

**Interpretation:** if the user has not asked to change it, keep it as it is.


## Baseline reference

The lock applies to the current Tinni Star implementation and blueprint state on branch `fix/final-gift-rocket-flow` at the time this policy is introduced. Later commits may extend or fix the app, but they do not implicitly unlock older confirmed behavior.

## Developer/agent checklist

Before changing Tinni Star behavior:
1. Identify the exact user instruction authorizing the change.
2. Preserve unrelated current behavior.
3. Update the relevant blueprint rule in the same change.
4. Add/adjust a regression test when the rule is mechanically testable.
5. Do not restore behavior from an older branch merely because it existed previously.
