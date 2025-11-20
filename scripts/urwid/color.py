#!/usr/bin/env python3

from __future__ import annotations
import urwid

def exit_on_q(key: str) -> None:
    if key in {"q", "Q"}:
        raise urwid.ExitMainLoop()


palette = [
    ("banner", "", "", "", "#fff", "#000"),
    ("streak", "", "", "", "g50", "#60a"),
    ("bg", "", "", "", "g38", "#808")
]


txt = urwid.Text(("banner", " Hello World "), align="center")
map1 = urwid.AttrMap(txt, "streak")
fill = urwid.Filler(map1)
map2 = urwid.AttrMap(fill, "bg")
loop = urwid.MainLoop(map2, palette, unhandled_input=exit_on_q)
loop.screen.set_terminal_properties(colors=256)

loop.run()