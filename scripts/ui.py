#!/usr/bin/env python3
"""Flatten `axe describe-ui` into one line per labelled element:

    [Type] 'label' val='…' @(cx,cy) WxH

Coordinates are element centers in points — pass them straight to `axe tap -x -y`.
Usage: ui.py <udid> [case-insensitive filter]
"""
import json
import subprocess
import sys

udid = sys.argv[1]
needle = (sys.argv[2] if len(sys.argv) > 2 else "").lower()
raw = subprocess.run(["axe", "describe-ui", "--udid", udid], capture_output=True, text=True, check=True).stdout
previous = None


def walk(node):
    global previous
    frame = node.get("frame") or {}
    label = node.get("AXLabel") or ""
    value = node.get("AXValue") or ""
    uid = node.get("AXUniqueId") or ""
    width, height = frame.get("width", 0), frame.get("height", 0)
    if (label or value or uid) and (width or height):
        line = f"[{node.get('type') or node.get('role') or '?'}] {label!r}"
        if value:
            line += f" val={value!r}"
        if uid and uid != label:
            line += f" id={uid!r}"
        line += f" @({frame['x'] + width / 2:.0f},{frame['y'] + height / 2:.0f}) {width:.0f}x{height:.0f}"
        # The AX tree often repeats a text node as its own child — print it once.
        if line != previous and (not needle or needle in line.lower()):
            print(line)
        previous = line
    for child in node.get("children") or []:
        walk(child)


for root in json.loads(raw):
    walk(root)
