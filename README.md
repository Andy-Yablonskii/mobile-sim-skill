# mobile-sim — Claude Code skill

Lets Claude drive the iOS Simulator (and Android emulator) on its own: screenshots,
accessibility tree, taps, typing, logs, dev-client builds and a second Metro — so it can
reproduce mobile bugs and verify fixes end-to-end instead of asking you for logs.

## Install

```bash
git clone https://github.com/Andy-Yablonskii/mobile-sim-skill ~/.claude/skills/mobile-sim
brew install cameroncooke/axe/axe        # simulator input + accessibility tree
```

Requires macOS with Xcode (simctl). Android commands need the Android SDK (`adb`, `emulator`).

## Use

In Claude Code: `/mobile-sim` (or just ask it to "check it on the simulator").

The helper works on its own too:

```bash
~/.claude/skills/mobile-sim/scripts/sim.sh shot home    # screenshot (point-scaled copy too)
~/.claude/skills/mobile-sim/scripts/sim.sh ui Save      # find elements + tap coordinates
~/.claude/skills/mobile-sim/scripts/sim.sh tap 196 778
```

## Files

- `SKILL.md` — the playbook Claude follows
- `scripts/sim.sh` — simulator driver (AXe + simctl)
- `scripts/ui.py` — flattens the accessibility tree into `label @(x,y)` lines
