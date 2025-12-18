from __future__ import annotations

import urwid
import typing
from functools import partial
import logging
import os
from dotenv import dotenv_values, load_dotenv
import re
from pathlib import Path
import time
import subprocess
import aria2p
import pyperclip
import dns.resolver

if typing.TYPE_CHECKING:
    from collections.abc import Callable, Hashable, Iterable

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
print(SCRIPT_DIR)
envFilePath = SCRIPT_DIR + "/../../.env"

focus_map = {"heading": "focus heading", "options": "focus options", "line": "focus line"}

def exit_program(key):
    raise urwid.ExitMainLoop()     


def get_domain():
    config = load_dot_env()
    
    domain = config["NODE_TICKER"] +"-" + config["PROJ_NAME"]
    # w.logger.debug(type(domain))
    # logger.debug(domain)
    return domain


def update_interface(key):

    config = load_dot_env()
    # logger.debug(get_domain())
    top.widget_refs["domain"].set_edit_text(get_domain())
    top.widget_refs["proxy_port"].set_edit_text("sudo ufw allow " + config["HAPROXY_PORT"])


def save_user_info(key, value):
    logger.debug("Save - key: %s, value: %s", key, value)
    set_env_value(key,value)
    update_interface(key)


def start_aria_service():
    cmd = [
    "aria2c",
    "--enable-rpc",
    "--rpc-listen-all=true",
    "--rpc-allow-origin-all",
    "--dir=/home/maarten/Downloads",
    "--continue=true",
    "--max-connection-per-server=16",
    "--split=16",
    "--min-split-size=1M",
    "--check-certificate=false"
    ]

    # Start aria2c in the background
    # stdout and stderr can be redirected to avoid blocking
    with open(os.devnull, "w") as fnull:
        process = subprocess.Popen(cmd, stdout=fnull, stderr=fnull)

    print("aria2c started in the background with PID:", process.pid)

    time.sleep(2)

    return process


def add_aria_download(filename, remoteBackupURL, backupDir, remoteBackupUser = "", remoteBackupPassword = ""):
    
    # Connect to the running aria2c RPC server
    aria2 = aria2p.API(
        aria2p.Client(
            host="http://localhost",
            port=6800,
            secret=""   # Fill in if you set --rpc-secret
        )
    )

    url = remoteBackupURL + filename

    options = {
        "continue": "true",
        "max-connection-per-server": "16",
        "split": "16",
        "min-split-size": "1M",
        "check-certificate": "false",
        "disable-ipv6": "true",        
        "http-user": remoteBackupUser,
        "http-passwd": remoteBackupPassword,
        "out": filename,
        "dir": backupDir,  # expand of ~/Downloads
    }

    aria2.add_uris([url], options=options)


def get_aria_downloads():
    # Connect to the running aria2c RPC server
    aria2 = aria2p.API(
        aria2p.Client(
            host="http://localhost",
            port=6800,
            secret=""   # Fill in if you set --rpc-secret
        )
    )

    downloads = aria2.get_downloads()
    
    return downloads


def resolve_domain(domain: str) -> dict:
    """
    Resolve a domain to its IPv4 and IPv6 addresses.
    
    Args:
        domain (str): The domain name to resolve.
    
    Returns:
        dict: {'ipv4': [...], 'ipv6': [...]}
    """
    resolver = dns.resolver.Resolver()
    result = {'ipv4': [], 'ipv6': []}

    # Resolve IPv4
    try:
        answers = resolver.resolve(domain, 'A')
        result['ipv4'] = [rdata.address for rdata in answers]
    except dns.resolver.NoAnswer:
        pass
    except dns.resolver.NXDOMAIN:
        pass

    # Resolve IPv6
    try:
        answers = resolver.resolve(domain, 'AAAA')
        result['ipv6'] = [rdata.address for rdata in answers]
    except dns.resolver.NoAnswer:
        pass
    except dns.resolver.NXDOMAIN:
        pass

    return result


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
        key = super().keypress(size, key)

        # logger.debug("Key: %s", key)
        # logger.debug("Edit: %s", self.edit_text)

        if self.callback:
            self.callback(self.envKey, self.edit_text)

        return key


class EditField(urwid.Edit):
    ARROW_KEYS = {'up', 'down', 'left', 'right', 'page up', 'page down', 'home', 'end'}

    def __init__(
        self,
        caption: str ,
        edit_text: str,
        ref: str | None = None
    ) -> None:
        # caption = "  " + caption.ljust(15) + ": "
        super().__init__(caption, edit_text=edit_text)
                        
        if ref:
            top.widget_refs[ref] = self

    def keypress(self, size, key):
        
        # if key == 'enter':  # or any key you like
        if key not in self.ARROW_KEYS:
            pyperclip.copy(self.edit_text)
            logger.debug("Copied to clipboard: %s", self.edit_text)
        
        key_pressed = super().keypress(size, key)
        # logger.debug("Key: %s", key)
        # logger.debug("Edit: %s", self.edit_text)
        return key_pressed


class TextField(urwid.Text):
    def __init__(
        self,
        caption: str ,  
        ref: str | None = None     
    ) -> None:
        super().__init__("  " + caption)
        
        # Add a named reference of this widget to the top level object,
        # for easy access. Otherwise you have to walk the tower of 
        # babel list.
        if ref:
            top.widget_refs[ref] = self


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

    def update_choices(self, new_choices: list[urwid.Widget]) -> None:
        # Remove old choices (assuming header + line + divider = first 3)
        self.walker[3:-1] = new_choices
        self.choices = new_choices

    def open_menu(self, button: MenuButton) -> None:
        top.open_form(self.menu)


class HorizontalBoxes(urwid.Columns):
    def __init__(self,) -> None:
        super().__init__([], dividechars=1)
        self.widget_refs: dict[str, urwid.Widget] = {}

    def open_box(self, box: urwid.Widget) -> None:
        # logger.debug("open_box")
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
        # logger.debug("open_form %s", self)

        if self.contents:
            del self.contents[self.focus_position + 1 :]

        # logger.debug("Append %s", box)
        self.contents.append(
            (
                urwid.AttrMap(box, "options", focus_map),
                self.options(urwid.GIVEN, 70),
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

def load_dot_env():
    
    envFilePath = SCRIPT_DIR + "/../../.env"

    if not os.path.exists(envFilePath):
        logger.debug(".env not found")
        envFilePath = SCRIPT_DIR + "/../../.env.example.preprod"

    config = dotenv_values(envFilePath)

    return config

def get_env_value(key: str) -> None:

    envFilePath = SCRIPT_DIR + "/../../.env"
    
    if not os.path.exists(envFilePath):
        logger.debug(".env not found")
        envFilePath = SCRIPT_DIR + "/../../.env.example.preprod"

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

