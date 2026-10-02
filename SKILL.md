---
name: mobile-sim
description: Drive the iOS Simulator (and Android emulator) yourself to reproduce mobile bugs and verify fixes end-to-end in React Native / Expo apps — screenshots, accessibility tree, taps, typing, logs, a dev-client build and a second Metro. Use when asked to "check it on the simulator", "test it on the device", "reproduce this bug", "verify the fix/flow", or before calling any mobile fix done. Never hand the user a request for logs or screenshots you can get yourself.
---

# mobile-sim — drive the simulator, prove the behavior

Reproduce first, fix second, verify third — all on the device, with evidence. The user should
not have to paste logs, share credentials or tap anything.

## Rules

- **Never stop the user's processes.** Their Metro (usually 8081), simulator session and
  servers stay up. Need a bundler? Start your own on another port (8082+).
- Keep secrets out of output: tokens/passwords go in `chmod 600` temp files, never echoed.
- Temporary instrumentation (debug `console.log`, harness patches) is removed before you finish.
- Report concisely: what reproduced, root cause, fix, evidence (requests + status codes + screenshot).

## 0. Preflight

```bash
xcrun simctl list devices booted                # a booted device?
command -v axe || brew install cameroncooke/axe/axe
S=~/.claude/skills/mobile-sim/scripts/sim.sh    # helper (run with no args for usage)
$S shot start && $S ui | head -40               # what's on screen
lsof -nP -iTCP -sTCP:LISTEN | grep -E ':(80[0-9]{2})'   # whose Metros are running
```

Read the screenshot (`*_pt.png` is downscaled so **pixel = point = tap coordinate**).

## 1. Look → act → observe loop

- **Look:** `$S ui [filter]` gives labels + center coords; `$S shot <name>` for visuals.
- **Act:** `$S tap x y`, `$S tap-label "Save"`, `$S type "text"`, `$S swipe …`.
- **Observe:** Metro log (`[API]`-style request logs, `console.*`), `$S jslog 2` (JS errors from
  the device log), backend logs. "Nothing happened" with **no request sent** means the bug is
  client-side before the network call — instrument there.
- After every code change, **restart the flow from a fresh mount** — Fast Refresh keeps state,
  so a poisoned form/screen stays poisoned.

## 2. Getting a debuggable app (Expo / React Native)

1. Check what's installed: `xcrun simctl listapps booted | grep -A3 <bundle-id>`. A **Release**
   build embeds its bundle and never talks to Metro; its crash logs show
   `Release-iphonesimulator/main.jsbundle`.
2. Build a dev client (background it; 5–20 min):
   `CI=1 npx expo run:ios --configuration Debug --device <UDID> --no-bundler`
   (`--port` and `--no-bundler` are mutually exclusive.)
3. Own Metro on a free port, logs to a file:
   `TMPDIR=<tmp>/metro-tmp [EXPO_PUBLIC_X=…] npx expo start --port 8082 --dev-client > <tmp>/metro.log 2>&1`
   - Process env beats `.env`. `EXPO_PUBLIC_*` values are **inlined into the bundle**, so an
     isolated `TMPDIR` keeps your transform cache (and overrides) away from the user's Metro.
   - Strip ANSI codes before grepping its log: `sed 's/\x1b\[[0-9;]*m//g'`.
4. Connect: `$S open "<scheme>://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8082"`
   (scheme from `app.json`). `expo run:ios` may auto-connect to 8081 — redirect it.
5. Deep links (`<scheme>://some/route`) jump straight to a screen and skip the index/auth
   redirect — useful when a launch-time check (paywall, SDK init) gets in the way.

## 3. When the backend blocks you

Paywall/402, missing credentials, or a shared environment you must not pollute:

1. Check project memory/docs for a recorded harness recipe first.
2. Otherwise run the backend locally from its repo (`git archive origin/<branch>` into a temp
   dir — don't touch the user's checkout), with its own compose project, ports and container
   names. Look in its config for feature gates (subscription/paywall checks) and debug-only
   auth shortcuts (e.g. a fixed OTP when `DEBUG` is on), and create a throwaway test account.
3. Point **your** Metro at it via `EXPO_PUBLIC_*` env overrides (step 2.3).

## 4. Debug tactics that pay off

- Silent no-op submit → log the form library's invalid callback (React Hook Form:
  `handleSubmit(onValid, (errors) => console.log(errors))`). Forms that don't render every
  error swallow validation failures.
- A ternary swapping two same-type containers full of `<Controller>`/stateful children → React
  reuses them **by position** and leaks the previous step's values. Fix with distinct `key`s.
- Naive datetimes from an API (`2026-10-02T12:28:00`, no `Z`) parse as **local** time in JS —
  check displayed times against what was entered.
- Prove backend-side gaps with the API directly (curl with a token from a 600-mode file) and
  compare list counts before/after the action.

## 5. Simulator gotchas

- Out-of-process UI (Files/document picker, share sheets) is **not** in the AX tree → navigate by
  screenshot. Files picker shows the app's own folder once
  `$(xcrun simctl get_app_container booted <bundle> data)/Documents` has a file in it.
  Photos: `xcrun simctl addmedia booted <img>`.
- Floating overlays steal taps: Expo dev-tools gear (drag it away with a 1.2 s `swipe`),
  LogBox toasts at the bottom (tap their ✕), floating tab bars over bottom content.
- Small scrollable dropdowns: tap inside the visible list box, not the coordinates the AX tree
  reports for off-screen rows.
- `axe type` follows the simulator keyboard layout — verify the field value with `$S ui`.
- zsh has no `PIPESTATUS`; capture exit codes without pipes.

## 6. Android quick reference

```bash
adb devices; emulator -list-avds; emulator -avd <name> -no-audio &
adb exec-out screencap -p > shot.png                 # pixels, not dp
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml   # bounds + text
adb shell input tap X Y; adb shell input text 'hello%sworld'; adb shell input swipe X1 Y1 X2 Y2 300
adb reverse tcp:8082 tcp:8082                        # device → your Metro
adb logcat '*:S' ReactNativeJS:V                     # JS logs
```

An Android dev client needs `npx expo run:android`, which generates `android/` — do it in a
git worktree if the project doesn't commit native folders.

## 7. Finish

Remove instrumentation, rerun the exact failing flow on the final code, run the project's
type-check/lint, then leave the user's environment as found (or say exactly what is still running
and how to stop it).
