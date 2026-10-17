# Ember

Ember is a native SwiftUI study app for macOS and iPhone. It shares one study model, timer engine, persistence format and statistics implementation across both platforms. Study data is stored locally as JSON for offline use and synchronized using CloudKit’s private database and `CKSyncEngine`; there is no external service.

## Run

- **macOS:** Open [`Ember.xcodeproj`](Ember.xcodeproj) in Xcode and run the `Ember` target, or use `./run.sh` with the macOS Command Line Tools.
- **iPhone:** Open the same project in Xcode and run the `Ember iOS` target on an iOS 17+ simulator or device.

## iCloud configuration required

The Xcode project includes the shared `iCloud.app.ember.study` container identifier, CloudKit and remote-notifications entitlements. Before device sync can work, enroll/configure the Apple Developer team, register the App ID and iCloud container in Certificates, Identifiers & Profiles, enable iCloud/CloudKit and Push Notifications for **both** platform targets, associate both with the same container, and use a provisioning profile signed by that team. Confirm the container’s CloudKit schema in CloudKit Console (the app creates its `EmberStudyData` record in the private database). Development and production CloudKit environments are separate; deploy the schema to Production before release. Sign into the same iCloud account on each device. Push notification permission is not required for local timer functionality; sync can be delayed, and opening the app requests immediate reconciliation.

## Data and sync behavior

Each device saves changes locally first, including while offline. `CKSyncEngine` persists its serialized scheduling state. Record merges deduplicate sessions by UUID and study intervals by UUID, retain tombstones for intentional clears, merge settings/timer state by their modification timestamps, and count study time from the union of intervals so overlapping sessions are not counted twice. The timer is anchored to a wall-clock deadline; resuming Ember recalculates time from that deadline. Only one running interval is allowed per store. CloudKit may synchronize later, and concurrently running devices are reconciled rather than presented as real-time shared timers.

## Verification status

The macOS source build and logic checks can be run locally with the project scripts/toolchain. This checkout environment currently has Command Line Tools only: the iOS SDK and Xcode are not installed. Consequently the iOS target has not been compiled or exercised on a simulator/device here, and iCloud sync has not been tested with a signed Developer account on both platforms. Do not treat the configured CloudKit path as validated cross-device sync until those tests succeed.
