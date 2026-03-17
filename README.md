# DECL Web Viewer

Flutter and web-based tools for visualizing DECL schematic files.

## Overview

This repo contains:

- **Flutter app** under `flutter/` – a modern DECL viewer UI that:
  - Lets you **browse and load any `.decl` file** directly in the browser (no backend required for Flutter web).
  - Renders:
    - A **topology view** (components and nets).
    - A **detailed schematic view** (instances, pins, and nets).
    - A **PCB-style view** (board-style representation derived from the same schematic).

### Prerequisites

- Flutter SDK (3.x)
- A recent Chrome browser (for Flutter web)

### Running the Flutter app

From the repo root:

```bash
cd flutter
flutter pub get
flutter run -d chrome
```

This will open the DECL viewer in Chrome.

### Using the Flutter viewer

- Click the **“Browse DECL file”** button in the header.
- Choose any `.decl` file from your machine.
- The UI will update to show:
  - **Topology**: components and nets from the file.
  - **Schematic view**: instance pins and net connections.
  - **PCB view**: a board-style visualization based on the same schematic.

The header title and subtitle update dynamically based on the selected file name.

## License

This repository does not yet declare a license. Add one to `LICENSE` if you intend to share or open source this code.

