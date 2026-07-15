# Battery Monitor 1.2.0

A native macOS app that reads **Android phone battery health over ADB**, stores a local
history, projects battery wear, and exports a customer-ready PDF report — useful when the
phone's own battery-health screen is region-locked (e.g. Galaxy S25).

## What's new in 1.2.0
- **Health-source provenance** — every reading now records *how* health was measured
  (Samsung ASOC · sysfs `charge_full` · batterystats learned capacity), so history stays
  interpretable across devices and app versions. Recorded in the local store and in
  JSON exports; older exports still import cleanly.
- **Method-aware health label** — the "Health (ASOC)" label is now driven by the sample's
  recorded source, not guessed from the manufacturer.
- **Import fixes** — export/import now uses a single, fully tested merge path
  (duplicate samples deduped by device + timestamp).
- Internal: probe parsers share one set of unit conversions; release script gained an
  opt-in Developer ID + notarization path.

## Highlights
- **Live readout** — charge level, health % (Samsung ASOC), estimated mAh vs. design, BSOH, temperature, voltage.
- **Battery health first** — wear / health / capacity shown up front; volatile live values are a clearly
  timestamped snapshot that dims when the phone is unplugged.
- **Wear projection** — estimates the date the battery reaches an end-of-life threshold; refines as more
  readings accumulate.
- **History** — every reading stored locally (SwiftData) with charts.
- **Guided connection** — step-by-step assistant + a banner that surfaces the "tap Allow on your phone" prompt.
- **Customer PDF report** — one-page health report with verdict, figures, projection, chart and shop branding.
- **Export / import** — portable, versioned JSON.

## Supported devices (no root)
- **Samsung (One UI)** — ASOC %, BSOH, first-use & cell dates via `dumpsys battery`. Verified on Galaxy S25 (SM-S931B).
- **Xiaomi / Redmi / Poco (MIUI/HyperOS)** — learned capacity ÷ design via `dumpsys batterystats`. Verified on Poco F3 (M2012K11AG).
- **Any other Android** — sysfs `charge_full`, else batterystats learned capacity.

## Install
1. Requires macOS 14+ and `adb` (`brew install android-platform-tools`).
2. Download `BatteryMonitor-1.2.0.dmg`, open it, drag **Battery Monitor** to Applications.

> **Gatekeeper:** if this build is ad-hoc signed (not notarized), macOS will warn on first
> launch — open it once via **right-click → Open**, or run
> `xattr -dr com.apple.quarantine /Applications/BatteryMonitor.app`.

## Enable USB debugging on the phone
About phone → Software information → tap **Build number** ×7 → Developer options → **USB debugging** →
connect, set USB mode to **File transfer**, tap **Allow** on the phone. The in-app assistant walks you through it.
