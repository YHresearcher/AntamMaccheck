🌐 **Language / Ngôn ngữ:** [Tiếng Việt](README.md) | English

# An Tâm  Check

<p align="center">
  <img src="resources/MascotSidebar.png" alt="An Tâm Check mascot — a laptop holding a checklist" width="180">
</p>

<p align="center"><strong>A used-Mac inspection app from <a href="https://vitinhantam.com">Vi Tính An Tâm</a>.</strong></p>

> **Sold with care, so you can buy with peace of mind.**

Open the app and it reads the machine's specs, then walks you through checking each part: screen, keyboard, trackpad, speakers, microphone, webcam, ports, appearance, battery, storage, MDM and Activation Lock. When everything is done, the Report page sums it all up: whether the machine is good, what still needs attention, and a closing note from An Tâm.

The app is written in SwiftUI and runs on **macOS 13 or later**. The current version is **1.2** (build 5).

## Download

The newest build is always in this repo's **Releases**. Every successful build on the `main` branch creates a new Release, with the latest one marked Latest:

- All releases: https://github.com/YHresearcher/AntamMaccheck/releases
- Download the latest directly (no GitHub login needed): https://github.com/YHresearcher/AntamMaccheck/releases/latest/download/AnTam-Mac-check-macOS.zip

Download the zip, unzip it once to get `An Tam Mac check.app`, drag it into your Applications folder and open it.

## Real images

The images below are real assets from the app (the sidebar mascot, the MacBook photo on the device card, and the test icons), not redrawn illustrations:

<p align="center">
  <img src="resources/MacBookPhoto.png" alt="MacBook photo on the device info card" width="480">
</p>

<p align="center">
  <img src="resources/IconLaptop.png" width="32" alt="Screen">
  <img src="resources/ban_phim_keyboard.png" width="32" alt="Keyboard">
  <img src="resources/trackpad.png" width="32" alt="Trackpad">
  <img src="resources/loa_speaker.png" width="32" alt="Speakers">
  <img src="resources/microphone.png" width="32" alt="Microphone">
  <img src="resources/webcam_camera.png" width="32" alt="Webcam">
  <img src="resources/IconBolt.png" width="32" alt="Ports">
  <img src="resources/IconSearch.png" width="32" alt="Appearance">
  <img src="resources/IconBattery.png" width="32" alt="Battery">
  <img src="resources/IconDrive.png" width="32" alt="SSD">
</p>

> Real screenshots of the three pages (Overview, Step-by-step checks, Report) will be added later — see the "Still needed" section at the end of this file.

## First launch

This build is not Apple-signed and not notarized (only ad-hoc signed to prevent tampering after packaging), so macOS may block it when you first open it. How to open it:

1. Right-click the app and choose **Open**, then click **Open** in the confirmation dialog.
2. If it is still blocked, go to **System Settings → Privacy & Security**, scroll down to Security and click **Open Anyway**, then enter your Mac password.
3. Do not turn off Gatekeeper system-wide, and do not run as root to get past the warning.

If the app quits immediately or no window appears, run it from Terminal:

```bash
"/Applications/An Tam Mac check.app/Contents/MacOS/AnTamMacCheck"
```

Copy the last error message and send it to the developers. To check the signature and your macOS version:

```bash
codesign --verify --deep --strict --verbose=2 "/Applications/An Tam Mac check.app"
file "/Applications/An Tam Mac check.app/Contents/MacOS/AnTamMacCheck"
sw_vers -productVersion
```

## Privacy

The app asks for exactly **2 permissions**, and only when you start that test yourself — opening the app asks for nothing:

| Permission | Asked when | What it is used for |
| --- | --- | --- |
| **Camera** | When you start the **Webcam** test | Shows a live preview so you can judge clarity and noise yourself. Nothing is recorded, saved or sent anywhere. |
| **Microphone** | When you press record in the **Microphone** test | Records a short sample and plays it back on the device so you can judge clarity yourself. The recording is only stored temporarily on the machine. |

The app does **not** request and does not need: Screen Recording, Input Monitoring, Accessibility or Location. The keyboard and trackpad are read from events inside the app's own window, so no system permission is needed for them.

The permission dialog language follows your macOS system language (English system → English text, Vietnamese system → Vietnamese text), not the in-app language button. To get English dialogs while the system is in Vietnamese, set a per-app language for the app in **System Settings → General → Language & Region** (Applications section).

**If you clicked "Don't Allow" when the dialog appeared:**

1. Open **System Settings → Privacy & Security → Camera** (or **Microphone**).
2. Turn the switch back on for **An Tâm Check**.
3. Open that test again and it will work.

You can revoke either permission at any time in the same place. Turning a permission off does not break the app — only that test will be unavailable until you turn it back on.

**Your data stays on your machine:** the app sends no data anywhere. Test results are only saved into the JSON report when you export it yourself.

## How to use

When you open the app it reads the machine's specs (friendly name, model ID, serial number, chip, RAM, macOS) and reads the battery and storage by itself; it does not run any other test on its own. The sidebar has 3 pages, in order:

- **Overview:** the Mac info card (friendly name, Model ID, serial number, CPU, CPU/GPU core counts, RAM, SSD, battery + health + charging/not charging, macOS), the MDM + Activation Lock row, and a "Passed x/10 checks" summary + the list of 10 checks.
- **Step-by-step checks:** a grid of 10 checks colored by status, then a wizard that goes through them one by one. Each step has 4 choices: **Passed**, **Failed** (describe the fault), **Not tried**, **Stop all**. The **Passed** button only works after you have actually done that test — you cannot pass a test just by opening it. The Battery and SSD steps show the numbers already read before you can confirm.
- **Report:** the overall verdict, detailed results, a note from An Tâm, and a button to export the JSON report (`AnTam-Mac-check-report.json`).

The **About** button in the sidebar opens the shop's introduction (logo, slogan, 2 branches, 6-month warranty, vitinhantam.com, version).

The **EN/VI language button** in the sidebar (a globe icon, under the About button) switches the whole interface between English and Vietnamese — including the verdict, the "A note from An Tâm" verses (translated as rhymed poetry, like the shop's PCcheck app) and the exported JSON report. Your choice is remembered for the next launch. The shop name, branch addresses and machine data (model name, serial number, SMART...) stay as they are, because they are proper nouns / system data.

### The 10 checks

- **Screen:** a fullscreen test with 12 colors (white, black, red, green, blue, grey 25/50/75%, yellow, cyan, magenta, warm white). Use ← / → to change color, Esc to exit. You must view all 12 colors before you can confirm. The app does not detect dead pixels or color tint by itself — you observe them.
- **Keyboard:** type a real key and the matching key on the virtual keyboard lights up green. At least 10 keys must be recognized before you can confirm. Left/right modifier keys (Caps, Shift, Ctrl, Option, Cmd, Fn) are detected through macOS `flagsChanged`, because they do not send ordinary key-press events. The built-in MacBook keyboard has no right Ctrl, so that key only lights up with an external keyboard.
- **Trackpad:** just move a finger on the trackpad, no need to press click. At least 10 movements are needed. An external mouse produces similar movement, so confirming it is really the trackpad still needs a person to check (try clicking, dragging, scrolling, multi-touch).
- **Speakers:** plays an 8-second stereo test tune: 4 seconds on the left channel first, then 4 seconds on the right. Listen to each side for buzzing, distortion or volume imbalance.
- **Microphone:** press record, say a sentence, stop, then press play back to judge clarity yourself.
- **Webcam:** the app asks for camera permission, then shows a live preview for you to judge clarity and noise yourself.
- **Ports:** reads the list of USB/Thunderbolt devices the system can see. To be sure about each port, plug a real device into each port and see whether it appears in the list. A device appearing in the list does not mean every physical port is good.
- **Appearance:** check by eye: case, hinges, dents, signs of opening, swollen battery, charging port.
- **Battery:** shows battery health (%), cycle count and current charge level. The "Passed" button only works once battery health has been read. Below 80% health the battery is degraded — factor in replacement cost.
- **SSD:** shows each detected drive (name, capacity, SMART). The "Passed" button only works once a drive has been detected. SMART not readable does not mean the drive is broken, and does not mean it is good either — it just means it could not be confirmed.

### Battery, storage and Activation Lock

- **Battery (Battery Analyzer):** cycle count, design capacity, full charge capacity, estimated health percentage, current charge level. The capacity ratio is only an estimate, not a certification that the battery is good.
- **Storage and SMART:** drive name, capacity, SMART status. SMART not readable (common on Apple Silicon) does not mean the drive is broken, and does not mean it is good either — it just means it could not be confirmed.
- **Activation Lock:** read directly on the machine, no password or erase needed, via `system_profiler SPHardwareDataType`. Only available on Apple Silicon or T2-chip Macs. If it is on, the machine is still locked to the previous owner's Apple account — do not buy it until it is removed. Apple removed the public serial-number lookup page in 2017, so it cannot be checked remotely. The surest check is still to erase the machine and activate it again to see whether it asks for the old Apple account — but that is an extra step, not a requirement.

### MDM

The app checks MDM automatically when it opens (and when you click **Check again**): it runs `profiles status -type enrollment` and reads 2 items: MDM enrollment and Automated Enrollment (DEP). The two extra checks (management profile, erase and reactivate) are shown right inside the MDM card on the Overview page — there is no separate detail page.

- If either one is Yes, the verdict blocks the purchase outright: do not buy until the owner explains and removes the management properly.
- If both are No, the device is about **80% likely to have no MDM** — not 100%. For more certainty, check the management profile as well, and only erase the machine and reactivate it to see whether a Remote Management screen appears if you want to be extra sure. Only do that with the owner's consent and after backing up the data.
- This command only reads the current state; it cannot verify ownership or the Apple Business/School Manager link in every situation.

## Overall verdict (Report page)

The verdict is generated automatically from all tabs, in this priority order: blocked, then failed, then not enough data, then notes, then passed.

| Verdict | When |
| --- | --- |
| **NOT RECOMMENDED TO BUY** | MDM/ADE detected, or Activation Lock is on. |
| **FAULTS FOUND — NEEDS REVIEW** | A functional check failed, battery below 80%, or SMART reports a fault. |
| **NOT ENOUGH DATA — CANNOT CONCLUDE** | A functional check is still untried. |
| **CHECKS DONE — POINTS TO NOTE** | Everything functional passed, but there are points to note: battery 80–89%, over 1000 cycles, SMART unreadable, Activation Lock unverified... |
| **MACHINE LOOKS GOOD — PASSED ALL CHECKED ITEMS** | 10/10 items passed: 8 functional checks passed, battery 90% or more, SMART Verified, both MDM items No, Activation Lock off. |

Apple's battery thresholds: below 80% the battery is degraded, so factor in replacement cost; over 1000 cycles is beyond a MacBook's design cycle count.

**"A note from An Tâm"** sits at the end of the Report page, the same way the shop's PCcheck app does it: 5 groups of the shop's verses, one fixed couplet picked per scenario (good machine, usable machine, needs negotiating, many faults, do not buy). If there is not enough data yet, there is no note. The overall verdict, the note and the Activation Lock status are all included in the exported JSON report.

## Limits to know

- The functional checks are observed and confirmed by the technician; the app does not diagnose for you. There is no CPU/GPU load test yet.
- The verdict is not a certification that a Mac is safe to buy. It only summarizes what was checked inside the app.
- The app sends no data anywhere. The camera and microphone only turn on when you start that test yourself, and the recording is only stored temporarily on the machine.
- The MDM and Activation Lock checks only read the current state on the machine; they do not replace erasing the machine and reactivating it for a final check with the seller.

## Build from source

Requires macOS 13 or later with a Swift toolchain:

```bash
swift run AnTamMacCheck
```

The GitHub build (Actions → **Build An Tam Mac check**) runs on every push to `main`, on every pull request, and on manual runs. Every successful build on `main` creates a new Release (tag `build-<build number>-<attempt>`, marked Latest) with the `AnTam-Mac-check-macOS.zip` file. Pull request builds do not create a Release. Build artifacts are kept in Actions for comparison.

## Shop info

- **Vi Tính An Tâm** — https://vitinhantam.com
- Branch 1: 52 Nguyễn Cửu Vân, Long An ward, Tây Ninh province
- Branch 2: 218/3 Street 11, Thủ Đức ward, Ho Chi Minh City
- 6-month warranty on the whole machine (shop introduction content, not a software guarantee).

## License

The battery-reading method references MacMonitor's AppleSmartBattery attribute selection (MIT), without using their interface or private SMC bridge — see `THIRD_PARTY_NOTICES.md`. The project has not imported source from Aman Check, mac-check or Battery Monitor. Any third-party code added later must follow its license terms and keep its copyright notice.

---

## Still needed for this README

- **Real screenshots** of the 3 pages (Overview, Step-by-step checks, Report) running on a real Mac — send them and they will be added to the "Real images" section.
- **Photos of the Camera/Microphone permission dialogs** (if available) to illustrate the Privacy section.
- **The actual Gatekeeper wording** on your Mac (it varies slightly by macOS version) — tell me if it differs from the description above.
