# DECL Web Viewer

Web server and UI for visualizing DECL schematic files.

## Overview

This project provides:

- A small Node/Express server (`src/server.js`) to serve static assets and example DECL files.
- A browser-based viewer UI (under `public/`) for exploring and visualizing `.decl` schematic files.

## Prerequisites

- Node.js >= 18
- npm (comes with Node)

## Installation

From the project root:

```bash
npm install
```

This will install the server and development dependencies (Express, Morgan, Nodemon, etc.).

## Running the Server

Start the server in normal mode:

```bash
npm start
```

Start the server in development mode (with auto-restart via Nodemon):

```bash
npm run dev
```

By default, the server listens on the port configured in `src/server.js` (often `3000` or similar). Once running, open your browser and navigate to that port, for example:

```text
http://localhost:3000
```

## Project Structure

- `src/server.js` - Express server entry point.
- `public/` - Static front-end assets and the main HTML/JS/CSS for the DECL viewer UI.
- `examples/decls/` - Sample `.decl` schematic files you can load in the viewer.
- `package.json` - Project metadata, scripts, and dependencies.

## Working with Example DECL Files

Example DECL files live under `examples/decls/` (for example `esp32-led-test.decl`). The server is set up to serve these files so that the front-end viewer can load them. Use the UI controls in the browser to select and visualize an example file.

## Development Notes

- Use `npm run dev` during development so the server reloads automatically on changes.
- If you change front-end files under `public/`, simply refresh the browser to see updates.

## License

This repository does not yet declare a license. Add one to `LICENSE` if you intend to share or open source this code.

