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
from collections import deque

if typing.TYPE_CHECKING:
    from collections.abc import Callable, Hashable, Iterable


def go_up(path, levels=1):
    for _ in range(levels):
        path = os.path.dirname(path)
    return path

focus_map = {"heading": "focus heading", "options": "focus options", "line": "focus line"}

def exit_program(key):
    raise urwid.ExitMainLoop()     


def get_domain(config):
    
    project_name = config["PROJ_NAME"].replace("${NETWORK}", config["NETWORK"])
    # config = load_dot_env()
    domain = config["NODE_TICKER"] +"-" + project_name
    # try:
    #     domain = config["NODE_TICKER"] +"-" + config["PROJ_NAME"]
    # except KeyError:
    #     domain = ""        
    # # w.logger.debug(type(domain))
    # logger.debug(domain)
    return domain


def update_interface():
    top.widget_refs["domain"].set_edit_text(get_domain())
    top.widget_refs["proxy_port"].set_edit_text("sudo ufw allow 308" + top.config["PORT_OFFSET"])


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
    except dns.resolver.LifetimeTimeout:
        pass

    # Resolve IPv6
    try:
        answers = resolver.resolve(domain, 'AAAA')
        result['ipv6'] = [rdata.address for rdata in answers]
    except dns.resolver.NoAnswer:
        pass
    except dns.resolver.NXDOMAIN:
        pass
    except dns.resolver.LifetimeTimeout:
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
        # callback: typing.Callable[[str], typing.Any] | None = save_user_info,
        config: dict = {},
        ref: str | None = None
    ) -> None:
        caption = "  " + caption.ljust(15) + ": "
        super().__init__(caption, edit_text=config[ref])
        # super().__init__(caption, edit_text=self.config[envKey])
        # self.callback = callback
        self.envKey = ref

        if ref:
            top.widget_refs[ref] = self

    def keypress(self, size, key):
        key = super().keypress(size, key)

        # logger.debug("Key: %s", key)
        # logger.debug("Edit: %s", self.edit_text)

        # if self.callback:
        #     self.callback(self.envKey, self.edit_text)

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
        self.config = get_env_file()

    def update_choices(self, new_choices: list[urwid.Widget]) -> None:
        # Remove old choices (assuming header + line + divider = first 3)
        self.walker[3:-1] = new_choices
        self.choices = new_choices

    def open_menu(self, button: MenuButton) -> None:
        top.open_form(self.menu)


class HorizontalBoxes(urwid.Columns):
    def __init__(self, config=None) -> None:
        super().__init__([], dividechars=1)
        self.widget_refs: dict[str, urwid.Widget] = {}
        self.config = {}
        self.status = ""
    
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
        if self.contents:
            del self.contents[self.focus_position + 1 :]

        self.contents.append(
            (
                urwid.AttrMap(box, "options", focus_map),
                self.options(urwid.GIVEN, 70),
            )
        )

        self.focus_position = len(self.contents) - 1


logger = logging.getLogger("mypassword")


def setup_logger(DLITE_DIR):
    # Create a dedicated logger
    logger.setLevel(logging.DEBUG)  # Only messages DEBUG or higher

    # Create a file handler
    fh = logging.FileHandler(DLITE_DIR + "/wizard-debug.log", mode="w")  # 'w' overwrites each run
    fh.setLevel(logging.DEBUG)

    # Optional: format messages
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
    fh.setFormatter(formatter)

    # Clear old handlers just in case
    if logger.hasHandlers():
        logger.handlers.clear()

    logger.addHandler(fh)


def get_log_end(file_path, offset=1):
    """
    Get a line from the bottom of a file.
    
    offset=1  -> last line
    offset=2  -> second-to-last line
    offset=3  -> third-to-last line, etc.
    """

    last_lines = ""

    try: 
        with open(file_path, "r") as f:
            last_lines = list(deque(f, maxlen=offset))[0].rstrip("\n")
    except FileNotFoundError:
        logger.debug("Log file not found: %s", file_path)
        last_lines = ""
    except IndexError:
        logger.debug("Log index error")
        last_lines = ""

    return last_lines


def get_env_file():
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    DLITE_DIR = go_up(SCRIPT_DIR, 2)
    envFilePath = DLITE_DIR + "/.env"

    return envFilePath


def load_dot_env():

    envFilePath = get_env_file() 

    if not os.path.exists(envFilePath):
        logger.debug(".env not found")
        envFilePath = envFilePath + ".example.preprod"

    config = dotenv_values(envFilePath)

    return config


def get_env_value(key: str) -> None:

    envFilePath = get_env_file()

    value = ""
    # envFilePath = SCRIPT_DIR + "/../../.env"
    marker = "####        ADVANCED        #####"

    with open(envFilePath) as f:
        for line in f:
            if marker in line:
                break
            if line.startswith(key):
                key, value = line.strip().split("=", 1)
    
    return value


def get_user_env() -> dict:
    config = {}
    envFilePath = get_env_file()
    marker = "####        ADVANCED        #####"

    with open(envFilePath) as f:
        for line in f:
            line = line.strip()

            # stop at marker
            if marker in line:
                break

            # skip empty lines + comments
            if not line or line.startswith("#"):
                continue

            # must contain '=' to be valid
            if "=" not in line:
                continue

            # split key=value
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()

            config[key] = value

    return config


def set_env_value(key: str, value: str) -> None:
    envFilePath = get_env_file()
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

