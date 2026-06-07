# Samsung Battery Health via ADB (macOS)

How to read Samsung Galaxy battery wear / health on a Mac when the on-device
**Settings → Battery → Battery information** screen is region-locked.

---

## Prerequisites

- `adb` installed: `brew install android-platform-tools`
- USB-C cable + the phone

## 1. Enable USB debugging on the phone

1. Settings → **About phone** → **Software information** → tap **Build number** 7×
2. Settings → **Developer options** → enable **USB debugging**
3. Set USB mode to **File transfer / MTP** (not "Charging only")
4. Plug into Mac → on the phone tap **Allow** on the *"Allow USB debugging?"* popup
   (check *Always allow from this computer*)

## 2. Confirm the device is connected

```bash
adb devices -l
```

Expected: a line ending in `device` (not `unauthorized` / `offline`).

| State | Fix |
|---|---|
| (empty) | Check cable / USB mode is File transfer |
| `unauthorized` | Unlock phone, tap **Allow** on the popup |
| `offline` | Unplug/replug, or `adb kill-server && adb start-server` |

## 3. Read battery health

```bash
adb shell dumpsys battery | grep -iE "Asoc|Bsoh|FirstUseDate|LLB CAL|cycle"
```

Full dump (live voltage, temp, charge counter, etc.):

```bash
adb shell dumpsys battery
```

---

## How to read the output

| Field | Meaning |
|---|---|
| **`mSavedBatteryAsoc` / `AsocData`** | **ASOC = battery health %** (remaining capacity vs. new). This is the headline wear number — same value the locked "Battery health" screen would show. |
| **`mSavedBatteryBsoh`** | BSOH = coarse State-of-Health bucket (Good / Normal / Service required). 100.00 = Good. |
| `battery FirstUseDate` | First power-on date (YYYYMMDD) |
| `LLB CAL` | Battery cell manufacture date (YYYYMMDD) |
| `mSavedBatteryMaxTemp` | Highest temp ever recorded (×0.1 °C, e.g. 515 = 51.5 °C) |
| `mSavedBatteryMaxCurrent` | Highest current ever (µA) |
| `Charge counter` | Current charge in µAh (÷1000 = mAh) at the present level |
| `level` / `voltage` / `temperature` | Live %, mV, ×0.1 °C |

**Estimated current full capacity (mAh) = ASOC% × design capacity.**

### Notes / caveats

- **Cycle count is NOT exposed over ADB** (`cycle_count: 0`); Samsung gates the
  real counter behind root. ASOC is the reliable wear metric anyway.
- `/sys/class/power_supply/battery/charge_full*` are **not readable without root**
  on modern Samsung — use `dumpsys battery` instead.
- Charge counter ÷ level is **not** an accurate capacity estimate (non-linear);
  trust ASOC.

### Design capacities (mAh) — S25 family

| Model | Code | Design |
|---|---|---|
| Galaxy S25 | SM-S931 | 4000 |
| Galaxy S25+ | SM-S936 | 4900 |
| Galaxy S25 Ultra | SM-S938 | 5000 |
| Galaxy S25 Edge | SM-S937 | 3900 |

---

## Example reading — 2026-06-08

Device: **Galaxy S25 (SM-S931B)**, serial `RFCY50QFS2B`

| Metric | Value |
|---|---|
| **ASOC (health)** | **96%** |
| **BSOH** | **100.00 (Good)** |
| **Est. full capacity** | **~3,840 mAh** (96% × 4,000) |
| **Wear** | **~4%** |
| Cell manufactured | 2025-05-14 |
| First used | 2025-08-12 (~10 months in service) |
| Max temp ever | 51.5 °C |
| Max current ever | ~4.98 A |
| Live state | 66%, 4.114 V, 37.7 °C, 2,719 mAh charge counter |

**Verdict: ~4% wear after ~10 months — excellent.**
