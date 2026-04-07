<p align="center">
<img height="128" src="https://github.com/Neighbor-Z/SwiftMTP/blob/main/Materials/MTPIcon-macOS-Default-128x128@2x.png">
</p>



<h1 align="center">SwiftMTP</h1>

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat)]()[![Platform: macOS 12.0+](https://img.shields.io/badge/Platform-macOS%2012.0%2B-blue.svg?style=flat)]()[![License: GPL](https://img.shields.io/badge/License-GPL-green.svg)]()

**SwiftMTP** is a light-weight, modern, Swift-based utility for interacting with MTP (Media Transfer Protocol) devices on macOS. It allows users to browse, manage, and transfer files between a Mac and external devices like Android phones.

Inspired by [OpenMTP](https://github.com/ganeshrvel/openmtp/), SwiftMTP reuses the kalam backend to provide a consistently high-performance transfer experience while maintaining a compact footprint.

---

## Features

- **Device Management**: Easily connect/disconnect MTP devices and select specific storage devices.
- **File Browsing**: Deeply navigate through device directories with a native macOS feel.
- **Bi-directional Transfer**: Import and export files with support for **Drag-and-Drop**.
- **File Operations**: Create new folders and delete files directly on the device.
- **Progress Tracking**: Real-time transfer progress bars and status indicators.
- **Localization**: Multilingual support via `Localizable.xcstrings`.

---

## Screenshot

![Main UI](https://github.com/Neighbor-Z/SwiftMTP/blob/main/Materials/screenshot.png)

---



|                    | SwiftMTP       | OpenMTP                                                 | A from MAS    | B from MAS                                                | C from MAS            |
| :----------------- | :------------- | :------------------------------------------------------ | :------------ | :-------------------------------------------------------- | --------------------- |
| `arch`             | 🟢 Universal    | ⚠️Separate packages                                      | 🟢 Universal   | 🔴 Apple Silicon Only                                      | 🟢 Universal           |
| **macOS Support**  | 12.0+          | 11.0+                                                   | 🟢 10.15+      | 12.0+                                                     | 🔴 14.6+               |
| **App Size**       | 🟢 < 20MB       | 🔴 ~360MB                                                | 🟢 < 20MB      | 🟢 < 20MB                                                  | 🟢 < 20MB              |
| **Transfer Speed** | 🟢 Fast         | 🟢 Fast                                                  | 🔴 Slow        | Average                                                   | 🔴 Unrecognized Device |
| **User Interface** | 🟢 Native Swift | 🔴 Web-based                                             | Near-Native   | Near-Native                                               | Near-Native           |
| **Localization**   | 🟢 Full App     | English, characters in other languages can be displayed | ⚠️English Only | 🔴 Only latin alphabet displayed, other characters  in '?' | ⚠️English Only         |
| **Drag & Drop**    | 🟢 Supported    | 🟢 Supported                                             | -             | 🔴 Not Supported                                           | -                     |



## Architecture

The project is structured to bridge high-level Swift with low-level MTP kernel interactions:

```text
SwiftMTP/
├──SwiftMTP/                  # Main App Source
│   ├── SwiftMTPApp.swift     # Entry point
│   ├── Views/                # SwiftUI UI Layer
│   ├── Models/               # Data models
│   └── Services/             # KalamMTPManager (Connection & Transfer logic)
├──KalamShim/                # C shim bridging Swift and the MTP kernel
├──ffi/                      # Kalam backend source
├──CKalam/                   # Module map for C headers
└──lib/                      # Runtime dependencies (kalam.dylib, libusb.dylib)
```

---

## Getting Started

### Prerequisites
* **Xcode 15.0+**
* **macOS 12.0+**

### Build & Run
1.  Please build Kalam backend first. Refer to `ffi/kalam/native/README.md`. This step will build necessary dynamic libraries (`kalam.dylib` & `libusb.dylib`) and will place them under `lib`.
2.  Open `SwiftMTP.xcodeproj` in Xcode.
3.  Select your target platform (macOS).
4.  Press Run.

---

## Realized

- [x] Drag-and-Drop
- [x] Automatic device connect detection
- [x] Transfer progress bar and status indicators
- [x] Multi selections and export

## To do

- [ ] Multiple connections at same time 

## License

[GPL](https://github.com/Neighbor-Z/SwiftMTP/blob/main/LICENSE)

---
**Need help?** If you encounter any issues, please open an [Issue](https://github.com/Neighbor-Z/SwiftMTP/issues).

