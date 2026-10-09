# CLAUDE.md

## Project notes (read first)
Full project knowledge lives in the Obsidian vault at:

`C:\Users\princ\OneDrive\obsidian vault\developercontrol`

- Start with `Claude Start Here.md`. `Home.md` is the index of all notes.
- After meaningful work, update `06 History/Changelog.md` and `06 History/Work in Progress.md`, plus the notes in `07 Decisions & Rules/` and `08 Roadmap/` if anything there changed. Add a session note from `Templates/Session Log Template.md`.

## Must-know rules
- Android-only Flutter app (`com.ahmadjamil.developercontrol`). All settings logic is in `android/app/src/main/kotlin/com/ahmadjamil/developercontrol/SecureSettingsHelper.kt`, shared by the app, the Quick Settings tile and the schedule.
- On Android 17+ (API 37), `Settings.Global` reads of `development_settings_enabled` and `adb_enabled` always return 0 to apps, but writes still work. Never treat a 0 as OFF there.
- Never open a Settings screen from a toggle when `WRITE_SECURE_SETTINGS` is granted.
- Write order: ON = Developer Options, then USB Debugging. OFF = USB Debugging, then Developer Options.
- Kotlin, manifest or resource changes need a full rebuild (`flutter run`); hot reload isn't enough.
- The test phone is a Pixel 8 on an Android 17 beta, connected over wireless ADB. Turning USB debugging off drops that connection, so warn first.
- Commit or push only when asked.
