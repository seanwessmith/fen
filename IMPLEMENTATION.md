# Heron Implementation Guide (to usable beta)

This guide turns the current scaffold into a usable beta app.

- App/HeronApp (Xcode project + app target)
- Packages/Core (models, data store, sync, media, networking, permissions)
- Packages/UI (design system + shared components)
- Packages/Features (SwiftUI feature modules)

The guiding priorities from OVERVIEW.md:
- Offline-first capture and background sync
- Reliable media pipeline with deterministic memory limits
- Consent profiles and data portability
- Performance and "never fails in the woods" reliability

## Definition of a usable beta

A beta is considered usable when the app supports these end-to-end flows on a
real device, offline:

- Create an observation with photos and notes
- View a journal list with thumbnails and detail pages
- Edit metadata (notes, consent profile, tags)
- Survive app restarts and airplane mode
- Safe-mode recovery if caches or local data corrupt
- Export a portable bundle (observations + media + consent policy)

Network sync can be stubbed initially, but the queue and consent gating should
exist so a backend can be added without re-architecting.

## Milestone 0: Project alignment and wiring (day 0)

- Set deployment target on HeronApp target to iOS 17.0 or 18.0.
- Add local packages to the app target:
  - Packages/Core
  - Packages/UI
  - Packages/Features
- Replace template SwiftData files in App/HeronApp/HeronApp:
  - Replace ContentView with RootView (tab or split view)
  - Remove Item.swift and the template SwiftData container
- Create these folders (if missing):
  - App/Bridges (UIViewControllerRepresentable, UIViewRepresentable)
  - App/HeronUIKitComponents (UIKit-only components wrapped by SwiftUI)
  - App/Resources (static assets, sample data, exports)

Deliverable: app builds and shows feature placeholders via RootView.

## Milestone 1: Data model and storage (week 1)

Goal: local persistence for observations and media.

1) Core models (Packages/Core/HeronModels)
- Observation
  - id, createdAt, notes, consentProfileID
  - optional: location, tags, species guess, confidence
- MediaAsset
  - id, observationID, localURL, createdAt
- ConsentProfile
  - id, name, policy (noTraining, researchOnly, ccBy)

2) Local store (Packages/Core/HeronDataStore)
- Implement ObservationStore backed by SwiftData (iOS 17+)
- Add MediaStore for media metadata
- Define a lightweight SyncQueue entity (pending uploads)
- Add migration strategy for model changes

3) File storage (Packages/Core/HeronMedia)
- Store full-res media in app documents directory
- Store thumbnails in caches directory
- Provide an ImagePipeline:
  - downscale to max pixel size
  - generate thumbnails in background
  - deterministic memory budget for in-memory caches

Deliverables:
- Save/load observations and media locally
- Media stored on disk and survives app relaunch
- Thumbnails created on a background queue

## Milestone 2: Capture flow (week 2)

Goal: take a photo and create an observation locally.

- Build CaptureView in Packages/Features/HeronFeatureCapture
- Use PHPickerViewController or AVCapture for photo capture
- Collect metadata:
  - notes
  - optional location (CoreLocation)
  - consent profile selection
- Persist observation and media using Core store + Media pipeline
- Add permission prompts in Info.plist
  - NSCameraUsageDescription
  - NSPhotoLibraryAddUsageDescription
  - NSLocationWhenInUseUsageDescription (if location is used)

Deliverable: capture a photo + note and see it in local storage.

## Milestone 3: Journal and detail (week 3)

Goal: browse, search, and edit existing observations.

- Build JournalView in Packages/Features/HeronFeatureJournal
- List observations with thumbnails
  - paginated / virtualized list
  - progressive image loading
- Detail view:
  - full-size images
  - notes editing
  - tags, location, consent profile
- Bulk metadata editing (multi-select list)

Deliverable: list, detail, and edit observations locally.

## Milestone 4: Consent profiles and data rights (week 4)

Goal: consent policy is first-class and exportable.

- Build SettingsView in Packages/Features/HeronFeatureSettings
- CRUD consent profiles
- Attach consentProfileID to observations
- Export bundle:
  - JSON or CSV metadata
  - images
  - consent profile metadata
- Add a "withdrawal/escrow" local toggle (blocks sync/export)

Deliverable: consent profiles stored, attached, and exported.

## Milestone 5: Offline sync queue (week 5)

Goal: sync-ready architecture without a full backend.

- Implement SyncEngine queue in Packages/Core/HeronSync
  - enqueue observation when created or edited
  - persist queue items
  - respect consent policy before upload
- Implement NetworkClient stub in app target
  - no-op or mock server endpoint
- Add manual "sync now" UI in Settings
- Add background task hook for future server sync (BGTaskScheduler)

Deliverable: enqueue and drain queue locally (stub network).

## Milestone 6: Performance and reliability (week 6)

Goal: field-reliable behavior with safe mode.

- Image pipeline optimizations
  - cap decode size, use thumbnail cache
- Deterministic memory limits
  - bounded in-memory cache
- Safe mode
  - detect corrupted caches
  - allow user to reset caches without reinstall
- Telemetry hooks (Packages/Core/HeronTelemetry)
  - lightweight local logging with opt-in

Deliverable: app stays stable with large photo sets and recovers gracefully.

## Milestone 7: Beta hardening (week 7)

Goal: get to TestFlight-ready beta.

- Add unit tests for:
  - store save/load
  - media pipeline
  - consent gating
- Add UI tests for:
  - capture flow
  - journal list + detail
- Add app icon, launch screen, and basic theming
- Validate privacy strings and permissions
- Create Beta build configuration (optional)
- Run on multiple devices, including low-memory iPhones

Deliverable: beta build that is stable and testable on-device.

## Release checklist (TestFlight)

- App name, bundle ID, versioning
- Privacy usage strings complete
- Crash + analytics (optional, opt-in)
- Exportable data format documented
- Basic onboarding flow
- Beta feedback channel (email or in-app)

## Open decisions (confirm early)

- Minimum iOS target (17.0 vs 18.0)
- SwiftData vs Core Data (SwiftData recommended for iOS 17+)
- Camera capture method (PHPicker vs AVCapture)
- Export format (JSON + assets recommended)
- Whether sync should be local-only for beta or backed by a dev server

