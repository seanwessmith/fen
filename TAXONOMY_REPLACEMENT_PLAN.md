# Taxonomy Replacement Plan (Replace Placeholder With Real Identification)

## Recommendation on Your Options

1. **Use now (primary): Option 3 + Option 5**
   - Use iNaturalist CV API for real taxonomy predictions now.
   - Keep architecture hybrid: cloud-first, on-device fallback.
   - This is the fastest path to Seek-like quality with minimal model ops burden.

2. **Use next (secondary): Option 2**
   - Add a pre-trained iNat Core ML model for offline fallback and lower latency.
   - Good fit with offline-first goals in this codebase.

3. **Use only as a limited fallback: Option 1**
   - Apple Vision built-ins are fine for coarse categories, not high-quality species ID.
   - Keep as emergency fallback only (if cloud + Core ML fail).

4. **Defer: Option 4**
   - Training our own model is high effort (data, infra, eval, MLOps).
   - Not the right first step while taxonomy is still placeholder.

## Current State (What Exists Today)

- Placeholder taxonomy is hardcoded in capture flow:
  - `Packages/Features/Sources/FenFeatureCapture/FenFeatureCapture.swift` (`startSpeciesIdentification`)
  - Always returns `Eukaryota > Animalia > ... > Lemur` after a delay.
- Taxonomy display is already wired in capture + journal UIs.
- `Observation.Taxonomy` model already supports hierarchical ranks.
- A minimal networking abstraction exists (`NetworkClient`), but no real species ID client yet.

## Target Architecture

`Camera photo -> SpeciesIdentifier service -> ranked taxonomy candidates -> Observation save`

Execution mode:
- **Online**: iNaturalist CV API (`/v1/computervisions/score_image`) with optional `lat/lng/date`.
  - Token page: https://www.inaturalist.org/users/api_token
- **Offline**: on-device Core ML iNat classifier fallback.
- **Last resort**: mark unidentified (or coarse built-in Vision label if desired).

## Phased Plan

## Phase 0 - Define contracts and injection points

Goal: isolate species ID logic from `CaptureView`.

Tasks:
- Add a `SpeciesIdentifier` protocol (async classify image data, optional location/date context).
- Add DTOs for:
  - Candidate label
  - Confidence score
  - Structured taxonomy ranks
  - Source (`cloud`, `onDevice`, `fallback`)
- Inject the identifier into `CaptureView` instead of hardcoding taxonomy in the view.
- Preserve current save behavior: successful ID stores taxonomy; otherwise save as unidentified.

Planned files:
- `Packages/Core/Sources/FenModels/FenModels.swift` (extend models if needed)
- `Packages/Core/Sources/FenNetworking/*` (new protocol/DTO module location if preferred)
- `Packages/Features/Sources/FenFeatureCapture/FenFeatureCapture.swift` (dependency injection only)
- `App/FenApp/FenApp/RootView.swift` (wire concrete implementation)

Exit criteria:
- No taxonomy literals in UI layer.
- Capture flow still works with a mock identifier.

## Phase 1 - Cloud-first real taxonomy (iNaturalist API)

Goal: replace placeholder taxonomy with real predictions quickly.

Tasks:
- Implement iNaturalist client:
  - Multipart image upload to `/v1/computervisions/score_image`
  - Optional `lat`, `lng`, `observed_on` enrichment
- Parse top predictions and map API taxonomy to `Observation.Taxonomy`.
- Add robust error handling:
  - timeout
  - invalid response
  - empty predictions
  - network unavailable
- Keep UX responsive:
  - pending state while scoring
  - deterministic fallback to unidentified on hard failure

Exit criteria:
- Real taxonomy appears in capture/journal for successful API responses.
- No regressions in save flow when API fails.

## Phase 2 - Offline fallback (pre-trained iNat Core ML)

Goal: support airplane mode and reduce API dependency.

Tasks:
- Select a pre-trained iNat model that can run on target devices.
- Convert/package model for Core ML (if needed).
- Add Vision/Core ML inference path returning top-N candidates.
- Map model output labels to structured taxonomy ranks.
- Route logic:
  - if online: cloud first, on-device fallback
  - if offline: on-device first

Exit criteria:
- Taxonomy still works in offline mode with reasonable latency.
- Cloud and on-device results share one normalized result format.

## Phase 3 - Ranking improvements (quality pass)

Goal: improve precision without retraining.

Tasks:
- Add location/date priors (if permissions granted).
- Re-rank candidates by plausibility for region/season.
- Confidence gating:
  - High confidence -> species
  - Medium -> genus/family
  - Low -> unidentified

Exit criteria:
- Fewer wrong species-level predictions.
- Better graceful degradation at low confidence.

## Phase 4 - Hardening, observability, and rollout

Goal: make it reliable for field use.

Tasks:
- Add unit tests for:
  - API parsing/mapping
  - fallback routing
  - confidence thresholds
- Add integration tests with mocked network responses.
- Add telemetry events for:
  - identify started/succeeded/failed
  - source used (`cloud` vs `onDevice`)
  - latency buckets
- Feature flag rollout:
  - enable for internal builds first
  - then wider rollout

Exit criteria:
- Identification path is test-covered and measurable.
- Rollout can be reversed quickly via flag.

## Practical Decision Matrix (What Makes Sense Right Now)

- **Best immediate ROI**: Option 3 + Option 5
- **Best offline strategy**: Option 2 (after cloud path is stable)
- **Only partial utility**: Option 1
- **Long-term R&D**: Option 4

## Risks and Mitigations

- API quota/rate limits:
  - Mitigate with local cache + retry policy + on-device fallback.
- Incorrect taxonomy mapping:
  - Mitigate with explicit mapping tests and sample fixtures.
- Latency spikes on mobile networks:
  - Mitigate with timeout, optimistic UI, and background retry controls.
- Offline model size/performance tradeoff:
  - Mitigate by benchmarking at least two candidate models before committing.

## Suggested Delivery Order

1. Phase 0 + Phase 1 (replace placeholder with real cloud taxonomy)
2. Phase 2 (offline Core ML fallback)
3. Phase 3 (priors and ranking)
4. Phase 4 (hardening + staged rollout)
