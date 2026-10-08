# TinyScan – The &lt;1 MB PDF Document Scanner

TinyScan is a high-performance, cross-platform Flutter application designed for users who need to scan, digitize, and share documents without worrying about massive file sizes. Built with a **"Utility-First"** philosophy, TinyScan guarantees every PDF you generate is optimized for email, web uploads, and low-bandwidth sharing by strictly keeping file sizes **under 1.0 MB**.

---

## Features

| Feature | Details |
|---|---|
| 📷 **Document Scanning** | Capture pages with the device camera or import from the photo gallery |
| 🗜️ **Smart Compression** | Iterative JPEG quality reduction + image resizing keeps every PDF under 1 MB |
| ⬛ **Grayscale Mode** | Toggle grayscale to dramatically reduce file size for text documents |
| 📄 **Multi-Page PDFs** | Reorder pages with drag-and-drop before generating |
| 👁️ **Built-in Viewer** | Pinch-to-zoom PDF viewer with page counter |
| 📤 **One-tap Sharing** | Share directly via email, messaging apps, etc. |
| 🗑️ **Document Management** | Rename, view, share, and delete saved documents |
| 📱 **Cross-Platform** | Runs on Android (API 21+) and iOS (12+) |

---

## Architecture

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── document.dart            # Document data model
├── screens/
│   ├── home_screen.dart         # Document list screen
│   ├── scanner_screen.dart      # Camera/gallery capture + PDF generation
│   └── pdf_viewer_screen.dart   # Full-screen PDF viewer
├── services/
│   ├── image_processor.dart     # Image resize, grayscale & JPEG compression
│   ├── pdf_generator.dart       # PDF assembly with <1 MB size guarantee
│   └── document_storage.dart    # Persistent metadata storage
└── widgets/
    └── document_card.dart       # Document list tile widget
```

---

## The &lt;1 MB Guarantee

`PdfGenerator` enforces the size limit through a two-stage pipeline:

1. **`ImageProcessor.compressImagesToFitBudget`** – tries JPEG quality levels
   `[85, 70, 55, 40, 28, 18, 10]` and stops as soon as the total compressed
   image data fits within `1 MB − 40 KB PDF overhead`.
2. **Second-pass safety net** – if the assembled PDF still exceeds 1 MB (rare
   for many pages), `PdfGenerator` halves the budget and recompresses.

`PdfGenerationResult.withinSizeLimit` is `true` when the output file is
strictly `< 1 048 576 bytes`, and the UI shows a warning badge when it is not.

---

## Getting Started

### Prerequisites

- Flutter 3.10+ / Dart 3.0+
- Android SDK 21+ **or** iOS 12+

### Install & Run

```bash
flutter pub get
flutter run
```

### Run Tests

```bash
flutter test
```

---

## Permissions

| Platform | Permission | Reason |
|---|---|---|
| Android | `CAMERA` | Capture document photos |
| Android | `READ_MEDIA_IMAGES` | Import from gallery (Android 13+) |
| Android | `READ_EXTERNAL_STORAGE` | Import from gallery (Android ≤12) |
| iOS | `NSCameraUsageDescription` | Capture document photos |
| iOS | `NSPhotoLibraryUsageDescription` | Import from gallery |

---

## Dependencies

| Package | Purpose |
|---|---|
| `pdf` | PDF document assembly |
| `image` | Image decoding, resizing, grayscale, JPEG encoding |
| `image_picker` | Camera capture and gallery import |
| `pdfx` | PDF viewer widget |
| `share_plus` | Cross-platform file sharing |
| `path_provider` | Platform-specific file-system paths |
| `shared_preferences` | Document metadata persistence |
| `permission_handler` | Runtime permission requests |
| `uuid` | Unique document identifiers |