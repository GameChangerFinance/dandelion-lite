#!/usr/bin/env python3
from __future__ import annotations
import typing
import urwid

if typing.TYPE_CHECKING:
    from collections.abc import Iterable

choices = ["User info", "Generate db password", "Domain setup", "Check access", "Sync node"]

def menu(title: str, choices_: Iterable[str]) -> urwid.ListBox:
    body = [urwid.Text(("banner", title), align="center"), urwid.Divider()]

    for c in choices_:
        button = urwid.Button(c)
        urwid.connect_signal(button, "click", item_chosen, c)
        body.append(urwid.AttrMap(button, None, focus_map="reversed"))

    return urwid.ListBox(urwid.SimpleFocusListWalker(body))


def item_chosen(button: urwid.Button, choice: str) -> None:

    if choice == "User info":
        body = [urwid.Text(("banner", title), align="center"), urwid.Divider()]
        
        response = urwid.Text(["You chose 2", choice, "\n"])
        done = urwid.Button("Ok")
        urwid.connect_signal(done, "click", exit_program)

        main.original_widget = urwid.Filler(
            urwid.Pile(
                [
                    response,
                    urwid.AttrMap(done, None, focus_map="reversed"),
                ]
            )
        )
    else:
        response = urwid.Text(["You chose1 ", choice, "\n"])
        done = urwid.Button("Ok")
        urwid.connect_signal(done, "click", exit_program)

        main.original_widget = urwid.Filler(
            urwid.Pile(
                [
                    response,
                    urwid.AttrMap(done, None, focus_map="reversed"),
                ]
            )
        )


def exit_program(button: urwid.Button) -> None:
    raise urwid.ExitMainLoop()

def exit_on_q(key: str) -> None:
    if key in {"q", "Q"}:
        raise urwid.ExitMainLoop()

ascii_title = r"""
  _____                  _      _ _             
 |  __ \                | |    | (_)            
 | |  | | __ _ _ __   __| | ___| |_  ___  _ __  
 | |  | |/ _` | '_ \ / _` |/ _ \ | |/ _ \| '_ \ 
 | |__| | (_| | | | | (_| |  __/ | | (_) | | | |
 |_____/ \__,_|_| |_|\__,_|\___|_|_|\___/|_| |_|
                                          wizard

"""

# palette = [
#     ("banner", "black", "light gray"),
#     ("streak", "black", "dark red"),
#     ("bg", "black", "dark blue"),
# ]

palette = [
    ("banner", "", "", "", "#87ffaf", ""),
    ("streak", "", "", "", "g50", "#60a"),
    ("bg", "", "", "", "#87ffaf", "#000")
]


main = urwid.Padding(menu(ascii_title, choices), left=2, right=2)

background = urwid.AttrMap(
    urwid.SolidFill("\N{MEDIUM SHADE}"),
    'bg'              # palette entry name
)

top = urwid.Overlay(

    main,
    # urwid.SolidFill("\N{MEDIUM SHADE}"),
    background,
    align=urwid.CENTER,
    width=(urwid.RELATIVE, 60),
    valign=urwid.MIDDLE,
    height=(urwid.RELATIVE, 60),
    min_width=20,
    min_height=9,
)

# urwid.MainLoop(top, palette=[("reversed", "standout", "")])

loop = urwid.MainLoop(top, palette, unhandled_input=exit_on_q)
loop.screen.set_terminal_properties(colors=256)
loop.run()