#!/usr/bin/env python3

from __future__ import annotations
import typing
import urwid

if typing.TYPE_CHECKING:
    from collections.abc import Callable, Hashable, Iterable

class MenuButton(urwid.Button):
    def __init__(
        self,
        caption: str | tuple[Hashable, str] | list[str | tuple[Hashable, str]],
        callback: Callable[[MenuButton], typing.Any],
    ) -> None:
        super().__init__("", on_press=callback)
        self._w = urwid.AttrMap(
            urwid.SelectableIcon(["  \N{BULLET} ", caption], 2),
            None,
            "selected",
        )

class InputField(urwid.Edit):
    def __init__(
        self,
        caption: str ,
        edit_text: str = "",
        callback: typing.Callable[[str], typing.Any] | None = None,
    ) -> None:
        caption = " " + caption.ljust(15) + ": "
        super().__init__(caption)
        
        
        # self._w = urwid.AttrMap(
        #     urwid.SelectableIcon(["  \N{BULLET} ", caption], 2),
        #     None,
        #     "selected",
        # )

class SubMenu(urwid.WidgetWrap[MenuButton]):
    def __init__(
        self,
        caption: str | tuple[Hashable, str],
        choices: Iterable[urwid.Widget],
    ) -> None:
        super().__init__(MenuButton([caption, "\N{HORIZONTAL ELLIPSIS}"], self.open_menu))
        line = urwid.Divider("\N{LOWER ONE QUARTER BLOCK}")
        listbox = urwid.ListBox(
            urwid.SimpleFocusListWalker(
                [
                    urwid.AttrMap(urwid.Text(["\n  ", caption]), "heading"),
                    urwid.AttrMap(line, "line"),
                    urwid.Divider(),
                    *choices,
                    urwid.Divider(),
                ]
            )
        )
        self.menu = urwid.AttrMap(listbox, "options")

    def open_menu(self, button: MenuButton) -> None:
        top.open_box(self.menu)


class Form(urwid.WidgetWrap[MenuButton]):
    def __init__(
        self,
        caption: str | tuple[Hashable, str],
        choices: Iterable[urwid.Widget],
    ) -> None:
        super().__init__(MenuButton([caption, "\N{HORIZONTAL ELLIPSIS}"], self.open_menu))
        line = urwid.Divider("\N{LOWER ONE QUARTER BLOCK}")
        listbox = urwid.ListBox(
            urwid.SimpleFocusListWalker(
                [
                    urwid.AttrMap(urwid.Text(["\n  ", caption]), "heading"),
                    urwid.AttrMap(line, "line"),
                    urwid.Divider(),
                    *choices,
                    urwid.Divider(),
                ]
            )
        )
        self.menu = urwid.AttrMap(listbox, "options")

    def open_menu(self, button: MenuButton) -> None:
        top.open_form(self.menu)


class Choice(urwid.WidgetWrap[MenuButton]):
    def __init__(
        self,
        caption: str | tuple[Hashable, str] | list[str | tuple[Hashable, str]],
    ) -> None:
        super().__init__(MenuButton(caption, self.item_chosen))
        self.caption = caption

    def item_chosen(self, button: MenuButton) -> None:
        response = urwid.Text([" ", self.caption, "\n"])
        done = MenuButton("Ok", exit_program)
        response_box = urwid.Filler(urwid.Pile([response, done]))
        top.open_box(urwid.AttrMap(response_box, "options"))


def exit_program(key):
    raise urwid.ExitMainLoop()

menu_top = SubMenu(
    "Main Menu",
    [
        Form(
            "User info",
            [              
                InputField("Project name"),
                InputField("Port offset"),
                InputField("Node name"),
                InputField("Ticker"),
                InputField("E-mail (Cert)"),
            ],
        ),
        SubMenu(
            "DB password",
            [
                Choice("Generate"),
            ],
        ),
        Form(
            "Domain setup",
            [
                InputField("MyAddr token"),
                Choice("Generate ssh key"),
            ],
        ),
        SubMenu(
            "Check access",
            [
                Choice("Check Haproxy is running?"),
                Choice("Check Firewall rules"),
                Choice("Check reachable from outside"),
            ],
        ),
        SubMenu(
            "Sync node",
            [
                SubMenu(
                    "Download backup",
                    [
                        Choice("Sunflower MK2"),
                        Choice("AR3 mainnet"),
                    ],
                ),
                Choice("Download CSnapshot")
            ],
        ),

    ],
)


palette = [
    (None, "light gray", "black"),
    ("title", "light green", "black"),
    ("heading", "black", "light gray"),
    ("line", "black", "light gray"),
    ("options", "dark gray", "black"),
    ("focus heading", "white", "dark green"),
    ("focus line", "black", "dark green"),
    ("focus options", "black", "light gray"),
    ("selected", "white", "dark magenta"),
]
focus_map = {"heading": "focus heading", "options": "focus options", "line": "focus line"}

class HorizontalBoxes(urwid.Columns):
    def __init__(self) -> None:
        super().__init__([], dividechars=1)


    def open_box(self, box: urwid.Widget) -> None:
        if self.contents:
            del self.contents[self.focus_position + 1 :]

        self.contents.append(
            (
                urwid.AttrMap(box, "options", focus_map),
                self.options(urwid.GIVEN, 25),
            )
        )

        self.focus_position = len(self.contents) - 1

    def open_form(self, box: urwid.Widget) -> None:
        if self.contents:
            del self.contents[self.focus_position + 1 :]

        self.contents.append(
            (
                urwid.AttrMap(box, "options", focus_map),
                self.options(urwid.GIVEN, 50),
            )
        )

        self.focus_position = len(self.contents) - 1




title = r"""
  _____                  _      _ _             
 |  __ \                | |    | (_)            
 | |  | | __ _ _ __   __| | ___| |_  ___  _ __  
 | |  | |/ _` | '_ \ / _` |/ _ \ | |/ _ \| '_ \ 
 | |__| | (_| | | | | (_| |  __/ | | (_) | | | |
 |_____/ \__,_|_| |_|\__,_|\___|_|_|\___/|_| |_|
                                          wizard

"""
mainScreen = [urwid.Text(("title", title), align="center"), urwid.Divider()]


top = HorizontalBoxes()
top.open_box(menu_top.menu)

mainScreen.append(urwid.Filler(top, "middle", 10))    
body = urwid.ListBox(urwid.SimpleFocusListWalker(mainScreen))


urwid.MainLoop(body, palette).run()