#!/usr/bin/env python3

from __future__ import annotations

import wizard_lib as w
import subprocess
import urwid
from python_on_whales import docker  
import podman
# import yaml
import json
import aria2p
from pathlib import Path

# composeFilePath = w.SCRIPT_DIR + "/../../docker-compose.yml"

# with open(composeFilePath) as f:
#     compose_data = yaml.safe_load(f)

w.setup_logger()

aria_process = w.start_aria_service()

def get_docker_status():

    docker_status = {}

    with podman.PodmanClient() as client:
        if not client.ping():
            return {"error": {"status": "down", "health": "unknown"}}

        running_containers = client.containers.list()  # default: running only

        for c in running_containers:
            container_status = c.inspect()

            name = container_status["Name"]
            status = container_status["State"]["Status"]
            health = (
                container_status["State"].get("Health", {}).get("Status", "none")
            )

            match name:
                case "dandolite-preprod-cardano-node-ogmios-1":
                    try:
                        healthLog = (
                            container_status["State"].get("Health", {}).get("Log", "none")[-1].get("Output", "none").split(" - ")[1]
                        )
                    except IndexError:
                        healthLog = ""

                case "dandolite-preprod-cardano-db-sync-1":
                    try: 
                        healthLog = (
                            container_status["State"].get("Health", {}).get("Log", "none")[-1].get("Output", "none").split("\n")[1]
                        )
                    except IndexError:
                        healthLog = ""
                case _:
                    healthLog = ""

            try:
                port = get_docker_port(name)
            except UnboundLocalError:
                port = ""                    

            docker_status[name] = { 'status': status, 'health': health, 'health_log': healthLog, 'port': port }

    # print(docker_status)
    return docker_status               


def list_podman_volumes():
    with podman.PodmanClient() as client:
        if not client.ping():
            return {"error": {"status": "down", "health": "unknown"}}

        volumes = client.volumes.list()
    
        volume_list = []

        for v in volumes:
             volume_list.append(v.name)

    return volume_list


def generate_password(key):
    result = subprocess.run(["bash", w.SCRIPT_DIR + "/generate_password.sh"], check=True, capture_output=True, text=True,)
    
    password = result.stdout.strip()
    w.set_env_value("POSTGRES_PASSWORD", password)

    w.logger.debug("Result: %s", password)


def get_docker_port(name):
    
    result = subprocess.run(["bash", "docker", "inspect", name, "--format={{json .NetworkSettings.Ports}}"], check=True, capture_output=True, text=True,)
    
    ports = json.loads(result.stdout)
    
    for container_port, mapping in ports.items():
        
        if mapping is not None:
            host_port = mapping[0]["HostPort"]
    
    return host_port


def open_firewall_port(password):
    
    port = get_docker_port("dandolite-preprod-haproxy-1")

    cmd = ["sudo", "-S", "ufw", "allow", port]
    proc = subprocess.run(
        cmd,
        input=password + "\n",
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
        )

    print(proc.stdout)
    print(proc.stderr)


def generate_ssh_certificate(key):

    result = subprocess.run(["bash", "docker", "compose", "down", "cron" ], check=True, capture_output=True, text=True,)
    print(result)

    result = subprocess.run(["bash", "docker", "compose", "exec", "-it", "cron", "/scripts/cron/myaddrdns/certbot.sh" ], check=True, capture_output=True, text=True,)
    print(result)

    result = subprocess.run(["bash", "docker", "compose", "up", "cron", "-d" ], check=True, capture_output=True, text=True,)
    print(result)
    
    w.logger.debug("Generating certificate")


def build_status_display_podman(data):
    lines = []

    for name, info in data.items():
        state = info["status"]
        health = info["health"]
        health_log = info["health_log"]
        port = info["port"]


        lines.append(f"{name.ljust(45)}  {state.ljust(10)}  {health.ljust(10)} {port.ljust(10)} {health_log.ljust(10)} ")

    if not lines:
        lines.append("No running containers")
    else:
        header = f"{"Container".ljust(45)}  {"State".ljust(10)}  {"Health".ljust(10)} {"Port".ljust(10)} {"Progress"}"
        lines.insert(0, header )

    # Join lines with newlines
    text_content = "\n".join(lines)

    # Return a single Text widget
    return text_content


def build_status_display_aria(downloads):
    lines = []

    # for item in data.items():
    w.logger.debug(downloads)
    
    for d in downloads:

        w.logger.debug(f"Name: {d.name}")
        # print(f"Status: {d.status}")
        # print(f"Progress: {d.progress_string()}")
        # print(f"Download speed: {d.download_speed_string()}")
        # print(d.error_code)
        # print(d.error_message)
        # print(d.dir)
        # print(d.root_files_paths)
        # # print(d.files[0].uris)
        # print("---")
        # aria2.remove([d], force=True, files=True, clean=True)

        lines.append(f"{d.name.ljust(45)}  {d.status.ljust(10)}  {"{:.1f}".format(d.progress).rjust(15)} {"  "} {d.download_speed_string().ljust(15)}")

    if not lines:
        lines.append("No downloads")
    else:
        header = f"{"Volume".ljust(45)}  {"Status".ljust(10)}  {"Progress (%)".rjust(15)}  {""}  {"Speed".ljust(15)} "
        lines.insert(0, header )

    # # Join lines with newlines
    text_content = "\n".join(lines)

    # # Return a single Text widget
    # text_content = "bla"

    return text_content


def add_downloads(key):
    volumes = list_podman_volumes()
    
    for v in volumes:
        project, service = v.split("_")

        w.logger.debug(service)
        filename = service + ".tar.gz"
        remoteBackupURL =  "https://dando-snapshot.m2tec.nl/backups/preprod/"
        backupDir = str(Path("~/Downloads/dandobak/").expanduser())
        remoteBackupUser = "dando"
        remoteBackupPassword = "backup4DNOs"
        w.add_aria_download(filename, remoteBackupURL, backupDir, remoteBackupUser, remoteBackupPassword)

        # w.logger.debug()


def refresh(loop, data):
    """Update the UI every 2 seconds."""

    aria_data = w.get_aria_downloads()
    lines = build_status_display_aria(aria_data)

    status_widget.set_text(("Status",lines))

    # w.logger.debug("Refresh - %s", lines)

    loop.set_alarm_in(2, refresh)


def exit_program(key):
    aria_process.terminate()
    raise urwid.ExitMainLoop()
    

menu_top = w.SubMenu(
    "Main Menu",
    [
        w.Form(
            "User info",
            [              
                w.InputField("Project name", envKey="PROJ_NAME"),
                w.InputField("Port offset", envKey="PORT_OFFSET"),
                w.InputField("Node name", envKey="NODE_NAME"),
                w.InputField("Ticker", envKey="NODE_TICKER"),
                w.InputField("E-mail (Cert)", envKey="NODE_EMAIL"),
            ],
        ),
        w.SubMenu(
            "DB password",
            [
                w.Choice("Generate", generate_password),
            ],
        ),
        w.Form(
            "Domain setup",
            [
                w.TextField("Go to the link below and claim this domain:"),
                w.EditField("  ", w.config["NODE_TICKER"] +"-" + w.config["PROJ_NAME"]),
                w.TextField(""),
                w.EditField("  ", 'https://myaddr.tools/claim'),
                w.TextField('Copy the token and paste it in the input below'),
                w.TextField(""),
                w.InputField("MyAddr token", envKey="MYADDR_TOKEN")
            ],
        ),
        w.Form(
            "SSL Certificate",
            [
                w.Choice("Generate ssh key", generate_ssh_certificate),
            ],
        ),        
        w.Form(
            "Firewall",
            [
                w.TextField("To allow connecting to all services from"),
                w.TextField("the outside a port needs to be opened"),
                w.TextField("Run this command in the terminal:"),
                w.TextField(""),
                w.TextField("sudo ufw allow " + get_docker_port("dandolite-preprod-haproxy-1") ),
                # w.EditField("  Password: ", ''),
                # w.TextField(""),
                # w.Choice("Add HA-proxy to Firewall rules", open_firewall_port("test")),
            ],
        ),
        w.Form(
            "Sync node",
            [
                w.SubMenu(
                    "Download backup",
                    [
                        w.Choice("Sunflower MK2", add_downloads),
                        w.Choice("AR3 mainnet"),
                    ],
                ),
                w.Choice("Download CSnapshot")
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

w.logger.debug("Start")

title = r"""
  _____                  _      _ _             
 |  __ \                | |    | (_)            
 | |  | | __ _ _ __   __| | ___| |_  ___  _ __  
 | |  | |/ _` | '_ \ / _` |/ _ \ | |/ _ \| '_ \ 
 | |__| | (_| | | | | (_| |  __/ | | (_) | | | |
 |_____/ \__,_|_| |_|\__,_|\___|_|_|\___/|_| |_|
                                          wizard

"""

w.top.open_box(menu_top.menu)

node_status = "Loading..."

status_widget = urwid.Text(("Status", node_status))

padded_status = urwid.Filler(status_widget, "middle", height=10)

mainScreen = urwid.Pile([
    urwid.Text(("title", title), align="center"),
    urwid.Divider(),
    urwid.Filler(w.top, "middle", height=15),
    urwid.Divider(top=3),
    status_widget
])

filler = urwid.Padding(
    urwid.Filler(mainScreen, valign='top'),
    left=5,          # padding on the left
    right=5          # padding on the right
)

# loop = urwid.MainLoop(filler,palette).run()
loop = urwid.MainLoop(filler,palette)
loop.set_alarm_in(0, refresh)
loop.run()