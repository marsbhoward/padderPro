PadderPro
=========

PadderPro is a macOS application that transforms game controller (joystick/gamepad) inputs into keyboard and mouse events.

If you've ever played a game that only supports mouse and keyboard but you'd rather use a controller, PadderPro lets you map controller inputs to:

* Key presses (including multi-key combinations)
* Mouse clicks (left, right, middle, back, forward)
* Mouse movement — vertical and horizontal, with proportional (analog) cursor speed
* Scrolling
* Switching between configurations on-the-fly

PadderPro supports multiple configurations (one per game or program) and can map a controller button to switch between them.

PadderPro is built on top of [Enjoyable 2 (Enjoy2) by @nongraphical](http://nongraphical.com), which is itself based on [Enjoyable by Sam McCall](https://yukkurigames.com/enjoyable/). It modernizes that codebase for current macOS releases and adds controller-trigger detection, separate dual-stick handling, analog cursor speed, and concurrent key + mouse mappings.

## Features

* **Controllers** — USB or Bluetooth gamepads, joysticks, and multi-axis controllers
* **Triggers** — analog triggers (e.g. LT/RT) are detected and usable as buttons
* **Dual sticks** — left and right sticks are detected separately (Stick 1 / Stick 2) with Up / Down / Left / Right sub-actions
* **Analog mouse movement** — cursor speed scales with how far the stick is pushed, plus a 1–10 sensitivity slider
* **Concurrent mapping** — the "Also press key" option fires a key press at the same time as the primary action (e.g. move the cursor *and* hold a key from one stick direction)
* **Persistent configs** — mappings are saved to disk and restored on launch; a **Save** button lets you save on demand, and configs are also saved automatically on quit

## Building and running

PadderPro builds with Xcode. Because of how macOS ties permissions to an app's code signature (see [Permissions](#permissions)), the project ships with a helper script that builds, signs with a stable local certificate, and launches the app:

```bash
cd <path-to-repo>
./build_run.sh
```

Alternatively, open the project in Xcode and run it:

```bash
open <path-to-repo>/Enjoy2.xcodeproj
```

Then press **⌘R** to build and run.

> Note: a plain Xcode build is ad-hoc signed, whose signature hash changes on every build. macOS treats each rebuild as a new app and drops previously-granted permissions. `build_run.sh` re-signs each build with a stable local certificate so permissions persist. Use it for day-to-day development.

## Permissions

PadderPro needs two macOS privacy permissions, both granted in **System Settings → Privacy & Security**:

* **Input Monitoring** — to read controller input
* **Accessibility** — to synthesize keyboard and mouse events

On first launch you'll be prompted to grant these. Approve them, then quit and relaunch PadderPro so the grants take effect.

## How to use

1. Launch PadderPro and connect a controller.
2. While PadderPro is paused (not active), press a button or move a stick to jump to that input's mapping. The input appears selected in the left panel.
3. Choose a mapping option on the right:
   * **Press a key** — opens the keyboard picker; choose one or more keys
   * **Mouse movement vertical** — Up / Down
   * **Mouse movement horizontal** — Left / Right
   * **Mouse button** — Left / Right click
   * **Mouse scroll** — Up / Down
   * **Toggle mouse scope** — switches between global and single-window mouse modes
   * **Switch to configuration** — activates another configuration
4. (Optional) Check **Also press key** to fire a key press concurrently with the selected action, and pick the key.
5. (Optional) Adjust the **Speed** slider to set the cursor sensitivity for mouse-movement mappings.
6. Click **Save**, then press **Start** to activate. Switch to your target app and use the controller.

### Mouse scope modes

PadderPro offers two mouse-movement scopes: global and single-window. It starts in global mode; map any controller button to the **Toggle mouse scope** action to switch between them at runtime.

## Configuration files

All configuration files (mappings and translations) are stored in the user's Application Support directory:

    ~/Library/Application Support/PadderPro/

The files are JSON-encoded and portable across machines.

## Requirements

* macOS 13.0 (Ventura) or later
* A USB or Bluetooth gamepad / joystick / controller

## Changelog

### Version 1.2

* Rebranded to PadderPro
* Updated for current macOS (incl. macOS Tahoe) compatibility
* Replaced the Carbon framework with modern NSWorkspace APIs
* Replaced JSONKit with NSJSONSerialization
* Added analog-trigger detection (usable as buttons)
* Separate left/right stick handling with directional sub-actions
* Mouse movement split into independent vertical and horizontal mappings
* Proportional (analog) cursor speed based on stick deflection, plus a sensitivity slider
* Concurrent "Also press key" mapping alongside any primary action
* Explicit **Save** button and on-quit autosave
* Stable local code signing so privacy permissions persist across rebuilds

### Version 1.1 (Enjoy2)

* Mouse movement support
* Mouse button support
* Scrollwheel support
* Two mouse movement modes
