# 🦌 CariMediaScan

**All the technical details of your video, audio and Blackmagic RAW files — right in the macOS Finder's right-click menu.**

*Read this in [Français](README.fr.md).*

CariMediaScan is a macOS **Automator Quick Action**. Right-click any media file in the Finder and instantly get its full technical breakdown in a clean, native window — no application to install, no software to open. It can even be assigned to a keyboard shortcut.

Made by [Caribou Labs](https://carrillat.fr) · by Nathan Carrillat.

---

## Why

There are plenty of tools out there to inspect video files. I wanted something simple, living directly inside the Finder: no app to launch, just a right-click "Quick Action" you can trigger with a keyboard shortcut. Since it didn't really exist, I built it.

---

## Features

### 🎬 Video
Resolution (with label: 4K UHD, Full HD…), precise frame rate, codec (H.264, HEVC, ProRes, AV1…), pixel format, color space with **HDR10 / HLG / Dolby Vision / HDR10+** detection, bitrate, **start timecode**, and driver — plus one line per **audio track** and **subtitle track** (language, format, `default` / `forced` / `SDH` flags).

### 🎵 Audio
Codec, format, bitrate, sample rate, **bit depth** (16/24-bit), channels, full **music tags** (title, artist, album, year, track, genre) and display of the **embedded cover art** with its resolution.

### 🎥 Blackmagic RAW
A complete on-set camera report: resolution, fps, compression & bitrate, gamma/gamut, embedded LUT, camera model & firmware, lens, shot settings (ISO, aperture, focal length, shutter, white balance), production metadata (director, scene, take, reel, date) and estimated duration.

### ➕ Also
- **Folder navigation** with the arrow keys (↑ ↓ ← →), wrapping at both ends
- **Live update**: click another file in the Finder and the window refreshes on its own
- **Compare mode**: select two files to see both reports side by side
- **Resizable window** with scrolling content
- **Copy** the whole report to the clipboard in one click

---

## Requirements

- **macOS**
- **[ffmpeg](https://ffmpeg.org/)** (provides `ffprobe`) for the full details:
  ```sh
  brew install ffmpeg
  ```
  Without ffmpeg, the script falls back to macOS Spotlight metadata — functional but less detailed.
- **Blackmagic RAW** support relies on the Spotlight plugin installed with **DaVinci Resolve**.

---

## Installation

1. Download `CariMediaScan.workflow` (see [Releases](../../releases), or build it yourself — see below).
2. Double-click it, or drag it into `~/Library/Services/`.
3. macOS may ask for permission to control the Finder (needed for click-to-update): click **Allow**.

### Build it yourself from the script

If you only have `CariMediaScan.sh`:

1. Open **Automator** → **New Document** → **Quick Action**.
2. Set *"Workflow receives current"* to **files or folders** in **Finder**.
3. Add an **Run Shell Script** action.
4. Set **Shell: `/bin/zsh`** and **Pass input: as arguments** (important).
5. Paste the entire contents of [`CariMediaScan.sh`](CariMediaScan.sh).
6. Save (⌘S) as **CariMediaScan**.

---

## Usage

Right-click a media file in the Finder → **Quick Actions → CariMediaScan**.

| Control | Action |
| --- | --- |
| `← →` or `↑ ↓` | Previous / next file in the folder |
| Click in the Finder | Selecting a file updates the window |
| Resize | Drag the window edges; content scrolls |
| **Copy** | Copies the report to the clipboard |
| `Return` / `OK` / `Esc` | Closes the window |

### Optional: keyboard shortcut

**System Settings → Keyboard → Keyboard Shortcuts → Services** (*Files and Folders* section) → find **CariMediaScan** and assign a combination (e.g. `⌃⌥⌘I`). Then just select a file in the Finder and press it.

---

## Supported formats

**Video** — MP4 · MOV · M4V · MKV · AVI · WebM · MTS / M2TS · TS · WMV · FLV · MPG / MPEG · 3GP · OGV · VOB · MXF · BRAW (Blackmagic RAW)

**Audio** — MP3 · FLAC · WAV · M4A · AAC · OGG · Opus · AIFF · WMA · ALAC · APE · WV

---

## Documentation

A one-page explainer sheet is available in [English](docs/CariMediaScan-Guide-EN.pdf) and [French](docs/CariMediaScan-Fiche-FR.pdf).

---

## License

Released under the [MIT License](LICENSE).

---

<sub>CariMediaScan — by Caribou Labs 🦌</sub>
