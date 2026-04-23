# RedactFlow

Privacy-first iPhone utility for hiding sensitive details in photos and videos before sharing.

## Project Structure

```text
RedactFlow
├── RedactFlow.xcodeproj
└── RedactFlow
    ├── App
    ├── Core
    ├── Features
    │   ├── Home
    │   ├── Onboarding
    │   ├── PhotoRedaction
    │   ├── Settings
    │   └── VideoRedaction
    ├── Services
    ├── Shared
    │   ├── Components
    │   ├── Extensions
    │   └── Models
    ├── Assets.xcassets
    └── Preview Content
```

## Info.plist Permission Keys

The project generates its Info.plist from build settings and includes:

- `NSPhotoLibraryUsageDescription`
  - `RedactFlow lets you pick photos and videos from your library for offline redaction.`
- `NSPhotoLibraryAddUsageDescription`
  - `RedactFlow saves edited photos and videos to your library. Your media stays on your device.`

## Modern API Choice

The app uses a UIKit photo-library picker wrapper for full-access imports and a built-in limited-access browser when the user grants only selected Photos access. Video export uses `AVFoundation` with a CI-based video composition for a stable V1 pipeline.

## GitHub Pages

The repository includes a single combined Privacy Policy and Support page for GitHub Pages:

- `docs/index.html`

If you enable GitHub Pages from the `docs/` folder on the default branch, you can use one public URL for both privacy and support links.

## Manual Test Checklist

- Pick a photo from the library.
- Add multiple regions and confirm each can move and resize.
- Change region style between Blur, Pixelate, and Black Bar.
- Adjust intensity and corner radius on applicable styles.
- Use Undo and Redo after add, move, resize, style change, and delete.
- Export an edited image to Photos.
- Pick a video from the library.
- Add a region and confirm the V1 full-duration note is visible.
- Export an edited video to Photos.
- Deny Photos permissions and confirm the app shows a readable save error.
- Test a large image and a longer video clip for basic responsiveness.
