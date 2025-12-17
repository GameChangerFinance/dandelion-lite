#!/usr/bin/env .venv/bin/python3

from __future__ import annotations

import requests
import wizard_lib as w
import subprocess
import urwid
from python_on_whales import docker  
import podman
# import yaml
import json
import aria2p
from pathlib import Path
import secrets
import string
import psutil
from collections import deque
from podman.errors import NotFound

w.setup_logger()

config = w.load_dot_env()

aria_process = w.start_aria_service()


def get_docker_status():

    docker_status = {}

    with podman.PodmanClient() as client:
        if not client.ping():
            return {"error": {"status": "down", "health": "unknown"}}

        config = w.load_dot_env()
        project_name = config["PROJ_NAME"]

        running_containers = client.containers.list()  # default: running only

        for c in running_containers:
            
                container_status = c.inspect()

                name = container_status["Name"]
                status = container_status["State"]["Status"]
                health = (
                    container_status["State"].get("Health", {}).get("Status", "none")
                )
       
                if name == project_name + "-cardano-node-ogmios-1":
                    try:
                        logs = container_status["State"].get("Health", {}).get("Log", [])
                        healthLog = logs[-1].get("Output", "").split(" - ")[1] if logs else ""
                    except IndexError:
                        healthLog = ""
                elif name == project_name +  "-cardano-db-sync-1":
                    try:
                        logs = container_status["State"].get("Health", {}).get("Log", [])
                        healthLog = logs[-1].get("Output", "").split("\n")[1] if logs else ""
                    except IndexError:
                        healthLog = ""
                else:
                    healthLog = ""

                try:
                    port = get_docker_port(name)
                except UnboundLocalError:
                    port = ""                    

                if name.startswith(project_name):
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
             config = w.load_dot_env()
             
             if v.name.startswith(config["PROJ_NAME"]):
                volume_list.append(v.name)

    return volume_list


def generate_password(key):

    alphabet = string.ascii_letters + string.digits
    password = ''.join(secrets.choice(alphabet) for i in range(20))
    
    # result = subprocess.run(["bash", w.SCRIPT_DIR + "/generate_password.sh"], check=True, capture_output=True, text=True,)
    # password = result.stdout.strip()

    w.set_env_value("POSTGRES_PASSWORD", password)


def get_docker_port(name):
    
    result = subprocess.run(["bash", "docker", "inspect", name, "--format={{json .NetworkSettings.Ports}}"], check=True, capture_output=True, text=True,)
    
    ports = json.loads(result.stdout)
    
    for container_port, mapping in ports.items():
        
        if mapping is not None:
            host_port = mapping[0]["HostPort"]
    
    return host_port


def check_port_status(port):
    port_status = ""

    for conn in psutil.net_connections(kind='inet'):
        if conn.laddr.port == int(port) and conn.status == 'LISTEN':
            laddr = f"{conn.laddr.ip}:{conn.laddr.port}" if conn.laddr else ""
            raddr = f"{conn.raddr.ip}:{conn.raddr.port}" if conn.raddr else ""
            port_status = f"{conn.type.name:4} {conn.family.name:6} {laddr:22} {raddr:22} {conn.status}"
    
    if len(port_status) > 0:
        return "Listening"
    else:
        return ""


def check_domain_access(url) -> bool:
    # url = f"http://{domain}.myaddr.io:{port}"
    # print(f"\nChecking external access to {url}...")
    
    w.logger.debug("Url: %s", url)

    status = ""

    try:
        response = requests.get(url, timeout=5)
        if response.status_code < 400:
            status = f"Reachable from outside."
            return status
        else:
            status = f"Responded with status {response.status_code}."
            return status
    except requests.RequestException:
        status = f"Not reachable externally."
        # print(f"\033[38;5;99mYou may need to forward port {port} on your router to this computer.\033[0m")
        # print("\033[38;5;99mTypical guide: https://portforward.com\033[0m")
        return status


def get_log_end(file_path, offset=1):
    """
    Get a line from the bottom of a file.
    
    offset=1  -> last line
    offset=2  -> second-to-last line
    offset=3  -> third-to-last line, etc.
    """
    with open(file_path, "r") as f:
        last_lines = deque(f, maxlen=offset)
    return last_lines[0].rstrip("\n")  # first element is the requested line


def open_firewall_port(key):
    
    config = w.load_dot_env()

    cmd = ["pkexec", "ufw", "allow", config["HAPROXY_PORT"]]
    proc = subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
        )

    print(proc.stdout)
    print(proc.stderr)


def generate_ssl_certificate(key):
    w.logger.debug("Generating certificate")

    config = w.load_dot_env()
    
    restart_service_cron("x")

    with podman.PodmanClient() as client:
        if not client.ping():
            return {"error": {"status": "down", "health": "unknown"}}

        cron_container_name = config["PROJ_NAME"] + "-cron-1"
        # cmd = ["/bin/bash", "/scripts/cron/myaddrdns/certbot.sh", ">>", "/var/log/myaddrdns_certbot.log", "2>&1"]
        cmd = ["/bin/bash", "/scripts/cron/myaddrdns/certbot_log.sh"]
        try:
            w.logger.debug("try cert")
            container = client.containers.get(cron_container_name)
            container.exec_run(cmd, stdout=True, stderr=True)
            # w.logger.debug("Exit code:", result)
            # w.logger.debug("Output:\n", result.output.decode())
        except NotFound:
            w.logger.debug("except cert")
            # subprocess.run(["bash", "docker", "compose", "up", "cron", "-d" ], check=True, capture_output=True, text=True,)

    restart_service_haproxy("x")


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
   
    for d in downloads:

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


def build_status_display_access():
    config = w.load_dot_env()
  
    port_status = ("HA-proxy port " + config["HAPROXY_PORT"] + ": ").ljust(20) + check_port_status(config["HAPROXY_PORT"])
    
    my_domain = "https://" + w.get_domain() + ".myaddr.io:" + config["HAPROXY_PORT"]

    dns_status = "Domain:".ljust(20) + check_domain_access(my_domain)
    
    logFilePath = w.SCRIPT_DIR + "/../../logs/cron/myaddrdns_update.log"

    myaddr_log_status = get_log_end(logFilePath, offset=2)
    myaddr_status = "Myaddr status:".ljust(20) + myaddr_log_status

    logFilePath = w.SCRIPT_DIR + "/../../logs/cron/myaddrdns_certbot.log"

    certbot_log_status = get_log_end(logFilePath, offset=2)
    certbot_status = "Certbot status:".ljust(20) + certbot_log_status

    addresses = w.resolve_domain(w.get_domain() + ".myaddr.io")
    address_status = "IPv4:".ljust(20) + str(addresses["ipv4"]) + "\n" + "IPv6:".ljust(20) + str(addresses["ipv6"])


    status = my_domain + "\n\n" +  port_status + "\n" + dns_status + "\n" + myaddr_status + "\n" + certbot_status + "\n" + address_status
    w.logger.debug("Stat: %s", status)

    return status


def restart_service_cron(key):
    w.logger.debug("Restarting cron")
    config = w.load_dot_env()
   
    with podman.PodmanClient() as client:
        if not client.ping():
            return {"error": {"status": "down", "health": "unknown"}}

        cron_container_name = config["PROJ_NAME"] + "-cron-1"

        # Restart the container
        try:
            w.logger.debug("try cron")
            container = client.containers.get(cron_container_name)
            container.restart()
        except NotFound:
            w.logger.debug("except")
            subprocess.run(["bash", "docker", "compose", "up", "cron", "-d" ], check=True, capture_output=True, text=True,)


def restart_service_haproxy(key):
    w.logger.debug("Restarting haproxy")
    config = w.load_dot_env()
   
    with podman.PodmanClient() as client:
        if not client.ping():
            return {"error": {"status": "down", "health": "unknown"}}

        cron_container_name = config["PROJ_NAME"] + "-haproxy-1"

        # Restart the container
        try:
            w.logger.debug("try ha")
            container = client.containers.get(cron_container_name)
            container.restart()
        except NotFound:
            w.logger.debug("except ha")
            # subprocess.run(["bash", "docker", "compose", "up", "cron", "-d" ], check=True, capture_output=True, text=True,)


def add_downloads_backups(key):
    volumes = list_podman_volumes()
    
    for v in volumes:
        project, service = v.split("_")

        w.logger.debug(service)
        filename = service + ".tar.gz"
        
        # backupDir = str(Path("~/Downloads/dandobak/").expanduser())

        # Use dot env for environment variable expansion
        config = w.load_dot_env()
        # print(config)

        remoteBackupURL =  config["REMOTE_BACKUP_URL"]
        backupDir = config["BACKUP_DIR"]

        remoteBackupUser = w.get_env_value("REMOTE_BACKUP_USER")
        remoteBackupPassword = w.get_env_value("REMOTE_BACKUP_PASSWORD")
        w.add_aria_download(filename, remoteBackupURL, backupDir, remoteBackupUser, remoteBackupPassword)

        # w.logger.debug()


def add_downloads_csnapshot(key):
    w.logger.debug("CSnapshot")
    NETWORK = "preprod"  # or "testnet"

    if NETWORK == "mainnet":
        remoteBackupURL = "https://downloads.csnapshots.io/mainnet/"
        json_url = remoteBackupURL + "mainnet-db-snapshot.json"
    else:
        remoteBackupURL = "https://downloads.csnapshots.io/testnet/"
        json_url = remoteBackupURL + "testnet-db-snapshot.json"

    # Fetch the JSON
    response = requests.get(json_url)
    response.raise_for_status()  # raise error if request failed
    data = response.json()

    # Extract the file_name from the JSON and build the full URL
    # assuming the JSON structure is a list of objects as in your jq example
    filename = data[0]['file_name']

    config = w.load_dot_env()
    backupDir = config["BACKUP_DIR"]

    w.logger.debug("Filename: %s", filename)
    w.add_aria_download(filename, remoteBackupURL, backupDir)
 

def restore_backup():
    result = subprocess.run(["bash", w.SCRIPT_DIR + "scripts/docker/full-restore.sh",  ], check=True, capture_output=True, text=True,)
    

def restore_csnapshot():
    # result = subprocess.run(["bash", w.SCRIPT_DIR + "scripts/docker/full-restore.sh",  ], check=True, capture_output=True, text=True,)
    print("restore csnapshot")


def pause_downloads(key):
    aria2 = aria2p.API(
        aria2p.Client(
            host="http://localhost",
            port=6800,
            secret=""   # Fill in if you set --rpc-secret
        )
    )

    downloads = aria2.get_downloads()  
    for d in downloads:
        aria2.pause([d], force=True)


def start_downloads(key):
    aria2 = aria2p.API(
        aria2p.Client(
            host="http://localhost",
            port=6800,
            secret=""   # Fill in if you set --rpc-secret
        )
    )

    downloads = aria2.get_downloads()  
    for d in downloads:
        aria2.resume([d])


def delete_downloads(key):
    aria2 = aria2p.API(
        aria2p.Client(
            host="http://localhost",
            port=6800,
            secret=""   # Fill in if you set --rpc-secret
        )
    )

    downloads = aria2.get_downloads()  
    for d in downloads:
        aria2.remove([d], force=True, files=True, clean=True)


def refresh(loop, data):
    """Update the UI every 2 seconds."""
    lines_access = build_status_display_access()

    podman_data = get_docker_status()
    lines_podman = build_status_display_podman(podman_data)

    aria_data = w.get_aria_downloads()
    lines_aria = build_status_display_aria(aria_data)

    lines = lines_access + "\n\n" + lines_podman + "\n\n" + lines_aria

    status_widget.set_text(("Status", lines))
    loop.set_alarm_in(5, refresh)


def exit_program(key):
    aria_process.terminate()
    raise urwid.ExitMainLoop()
    

def full_restore(key):
    print("Full restore")


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
                w.TextField(""),
                w.InputField("IPv6 Enable", envKey="IP_V6_ENABLED"),
                w.TextField(""),
                w.InputField("Backup folder", envKey="BACKUP_DIR"),
                w.InputField("Backup URL", envKey="REMOTE_BACKUP_URL"),
                w.InputField("Backup user", envKey="REMOTE_BACKUP_USER"),
                w.InputField("Backup password", envKey="REMOTE_BACKUP_PASSWORD"),                
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
                w.EditField("  ", w.get_domain(), ref="domain"),
                w.TextField(""),
                w.EditField("  ", 'https://myaddr.tools/claim'),
                w.TextField('Copy the token and paste it in the input below'),
                w.TextField(""),
                w.InputField("MyAddr token", envKey="MYADDR_TOKEN"),
                w.TextField(""),
                w.Choice("Restart cron", restart_service_cron),
            ],
        ),
        w.Form(
            "SSL Certificate",
            [
                w.Choice("Generate", generate_ssl_certificate),
            ],
        ),        
        w.Form(
            "Firewall",
            [
                w.TextField("To allow connecting to all services from"),
                w.TextField("the outside a port needs to be opened"),
                w.TextField("Run this command in the terminal:"),
                w.TextField(""),
                w.Choice("Open port", open_firewall_port),
                w.TextField("\n  or run the following command in a seperate terminal\n"),
                w.EditField("  ", "sudo ufw allow " + config["HAPROXY_PORT"], ref="proxy_port" ),
            ],
        ),
        w.Form(
            "Sync node",
            [
                w.Choice("Download backup", add_downloads_backups),
                w.TextField("Run this command to restore from backups"),
                w.EditField(" ", "./scripts/docker/full-restore.sh"),
                # w.Choice("Restore from backup", restore_backup),
                w.TextField(""),
                w.Choice("Download CSnapshot", add_downloads_csnapshot),
                # w.Choice("Restore from CSnapshot", restore_csnapshot),
                w.TextField(""),
                w.Choice("Stop downloads", pause_downloads),
                w.Choice("Start downloads", start_downloads),
                w.Choice("Delete downloads", delete_downloads)
                
            ],
        ),
        w.TextField(""),
        w.Choice("Exit", exit_program)

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

# domain_widget = w.top.base_widget.base_widget.focus.base_widget._body[5].menu._original_widget._body[4]

node_status = "Loading..."

status_widget = urwid.Text(("Status", node_status))

padded_status = urwid.Filler(status_widget, "middle", height=10)

mainScreen = urwid.Pile([
    urwid.Text(("title", title), align="center"),
    urwid.Divider(),
    urwid.Filler(w.top, "middle", height=20),
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
