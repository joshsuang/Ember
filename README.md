# Ember

A compact native macOS study companion prototype, built with SwiftUI and Apple frameworks only. The app uses realistic locally generated sample sessions and stores changes in `UserDefaults`; it has no account, server, sync, or database layer.

## Run

- **Xcode:** Open [`Ember.xcodeproj`](Ember.xcodeproj) and run the `Ember` macOS target.
- **Swift toolchain (no Xcode app required):** run `./run.sh` from this directory. The helper builds a native `.app` into `.build/Ember.app` using the installed macOS SDK and launches it.

The project targets macOS 14+, defaults to dark mode, and opens at a comfortable 1120 × 790-point window size.
