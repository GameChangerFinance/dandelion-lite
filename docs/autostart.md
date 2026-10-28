# Autostart and deployment controls

Use autostart to bring your deployment up when the server boots. You can still
manage the same containers through the Dandoman menu or manual Compose commands.

## Enable autostart

On the Ubuntu Server setup described in the README, install Podman and its Docker
compatibility commands, then run `scripts/dandoman.sh` and select
`Setup->Run on system start`. Follow the installer's session-persistence guidance.

The installer creates a systemd service named after `PROJ_NAME` in your `.env`
and enables it for subsequent boots. It does not start or restart your deployment
during installation. To start it now, use the service command printed by the
installer, for example:

```sh
sudo systemctl start dandolite-preprod.service
```

Replace `dandolite-preprod` with your configured `PROJ_NAME` in service commands.
The generated service runs Podman Compose as the operator who installed it, using
the project's Compose and `.env` files. This autostart helper targets the Podman
setup; it does not install a Docker Engine service.

## Keep the deployment running after logout

Complete the installer's `KillUserProcesses=no` instruction on the host:

1. Open the login manager configuration:

   ```sh
   sudoedit /etc/systemd/logind.conf
   ```

2. Under the existing `[Login]` section, add or uncomment this setting. Remove
   the leading `#` if present, and change an existing `yes` value to `no`:

   ```ini
   [Login]
   KillUserProcesses=no
   ```

   Keep one active `KillUserProcesses` assignment in this file. Configuration
   snippets in `logind.conf.d` override the main file; inspect the combined
   configuration with `systemd-analyze cat-config systemd/logind.conf` and resolve
   any conflicting override before continuing.

3. Save the file and apply the change by restarting the host's login manager:

   ```sh
   sudo systemctl restart systemd-logind
   ```

`KillUserProcesses=no` prevents logind from killing processes in a login session's
scope when that session ends. This matters when operating rootless Podman from
SSH or a local login: session cleanup must not terminate processes needed by your
deployment after you disconnect. This is a host-wide policy; other users' session
processes can also remain running after logout.

The installer also runs `loginctl enable-linger` for the installing operator.
Lingering starts that user's systemd manager at boot and keeps it running after
logout, supporting the user-level Podman socket without an open login session.
As that operator, verify it with:

```sh
loginctl show-user "$USER" -p Linger
```

Expect `Linger=yes`. If needed, run `loginctl enable-linger` as that operator and
check again. Lingering and `KillUserProcesses=no` cover different process scopes:
configure both for this setup. The deployment service's enablement provides boot
startup; these persistence settings let user services and session processes
continue independently of an interactive login. See the official
[logind configuration](https://www.freedesktop.org/software/systemd/man/255/logind.conf.html)
and [lingering](https://www.freedesktop.org/software/systemd/man/255/loginctl.html)
documentation for details.

## Manage the same deployment

Run manual commands from your deployment directory, as the same operator account
used to install autostart. Keep the same container backend and project name.
The Compose file sets the project name from `PROJ_NAME`; avoid overriding it with
`-p` or `COMPOSE_PROJECT_NAME` when managing this deployment.

| Action | Command or menu item | Effect |
| --- | --- | --- |
| Start or reload containers | `docker compose up -d` or `Docker->Docker Up/Reload` | Starts the existing project, applying configuration changes when needed. |
| Stop and remove containers | `docker compose down` or `Docker->Docker Down` | Takes the project down without deleting its named volumes. |
| Check containers | `docker compose ps` or `Docker->Docker Status` | Shows current container state. |
| Start the systemd unit | `sudo systemctl start dandolite-preprod.service` | Runs Compose `up -d` if the unit is inactive. |
| Stop the systemd unit | `sudo systemctl stop dandolite-preprod.service` | Runs Compose `down` when the unit is active. |
| Check the systemd unit | `systemctl status dandolite-preprod.service` | Shows the startup unit's state. |

Using Compose after systemd startup controls the same project; it does not create
a second deployment. Different operator accounts, container backends, or project
names can target different containers.

The unit uses `RemainAfterExit=yes`, so `active (exited)` means its startup command
completed successfully. Check container state separately with `docker compose ps`.
After a manual `docker compose down`, the unit can still appear active, and
`systemctl start` will not rerun its startup command. Use `docker compose up -d`
to bring those containers back. Likewise, containers started manually can run
while the unit is inactive; use Compose to stop them in that case.

## Terminal sessions and shutdown

Use `docker compose up -d` to leave containers running in the background. Running
`docker compose up` without `-d` attaches it to your terminal; pressing `Ctrl+C`
stops those containers. Exiting Dandoman does not run `docker compose down`.

Stopping containers manually does not disable autostart for the next boot. To
disable future autostart, run `sudo systemctl disable dandolite-preprod.service`;
this does not stop currently running containers.

Shutting down the server stops its containers. Stopping Docker Engine normally
stops its containers too, unless live restore is configured. Podman's API service
can become inactive while containers keep running; its API service status alone
does not indicate deployment health.
