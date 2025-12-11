from __future__ import annotations

import urwid
import typing
from functools import partial
import logging
import os
from dotenv import dotenv_values, load_dotenv
import re
from pathlib import Path

if typing.TYPE_CHECKING:
    from collections.abc import Callable, Hashable, Iterable

focus_map = {"heading": "focus heading", "options": "focus options", "line": "focus line"}

def exit_program(key):
    raise urwid.ExitMainLoop()     


def save_user_info(key, value):
    logger.debug("Save - key: %s, value: %s", key, value)
    set_env_value(key,value)


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
        callback: typing.Callable[[str], typing.Any] | None = save_user_info,
        envKey: str = ""
    ) -> None:
        caption = "  " + caption.ljust(15) + ": "
        super().__init__(caption, edit_text=get_env_value(envKey))
        self.callback = callback
        self.envKey = envKey

    def keypress(self, size, key):
        if key == "enter" and self.callback:
            self.callback(self.envKey, self.edit_text)  # Call callback with current text
        return super().keypress(size, key)


class EditField(urwid.Edit):
    def __init__(
        self,
        caption: str ,
        edit_text: str
    ) -> None:
        # caption = "  " + caption.ljust(15) + ": "
        super().__init__(caption, edit_text=edit_text)
                        
    
class TextField(urwid.Text):
    def __init__(
        self,
        caption: str ,       
    ) -> None:
        super().__init__("  " + caption)
        
        
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


class Choice(urwid.WidgetWrap[MenuButton]):
    def __init__(
        self,
        caption: str | tuple[Hashable, str] | list[str | tuple[Hashable, str]],
        callback: Callable[[MenuButton], typing.Any] = exit_program,
    ) -> None:
        self.caption = caption

        button = MenuButton(
            caption,
            callback=partial(self.item_chosen, callback=callback),
        )

        super().__init__(button)

    def item_chosen(self, button: MenuButton, callback) -> None:
        response = urwid.Text([" ", self.caption, "\n"])
        done = MenuButton("Ok", callback=callback)
        response_box = urwid.Filler(urwid.Pile([response, done]))
        top.open_box(urwid.AttrMap(response_box, "options"))        


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

logger = logging.getLogger("mypassword")

def setup_logger():
    # Create a dedicated logger
    logger.setLevel(logging.DEBUG)  # Only messages DEBUG or higher

    # Create a file handler
    fh = logging.FileHandler(SCRIPT_DIR + "/debug.log", mode="w")  # 'w' overwrites each run
    fh.setLevel(logging.DEBUG)

    # Optional: format messages
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
    fh.setFormatter(formatter)

    # Clear old handlers just in case
    if logger.hasHandlers():
        logger.handlers.clear()

    logger.addHandler(fh)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
print(SCRIPT_DIR)

envFilePath = SCRIPT_DIR + "/../../.env"
config = dotenv_values(envFilePath)
config2 = load_dotenv(envFilePath)

def get_env_value(key: str) -> None:

    with open(envFilePath) as f:
        for line in f:
            if line.startswith(key):
                key, value = line.strip().split("=", 1)
    
    return value

def set_env_value(key: str, value: str) -> None:
    env_path = Path(envFilePath)
    key_re = re.compile(rf"^\s*{re.escape(key)}\s*=")

    lines = []
    updated = False

    if env_path.exists():
        for line in env_path.read_text().splitlines(keepends=False):
            if key_re.match(line) and not line.lstrip().startswith("#"):
                lines.append(f"{key}={value}")
                updated = True
            else:
                lines.append(line)

    if not updated:
        lines.append(f"{key}={value}")

    env_path.write_text("\n".join(lines) + "\n")


top = HorizontalBoxes() 

