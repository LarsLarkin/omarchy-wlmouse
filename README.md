# omarchy-wlmouse 

Bar widget + details panel for **Omarchy** to monitor and configure **WLmouse** gaming mice using the external `wl-mouse` CLI.

This plugin runs inside the long-running Omarchy shell (Quickshell). It is **unsandboxed** and runs with your user permissions.

## Features

- Bar widget: connection status + battery percentage
- Details panel:
  - Polling rate
  - LOD (0.7 / 1 / 2)
  - Debounce
  - DPI stages (set per stage + set active stage)
  - Angle snap / Motion sync / Ripple control (on/off)
  - Angle tune
  - Sleep time (minutes)
- Low battery notifications:
  - Warning at **25%**
  - Critical at **15%**
  - Sound alerts
- Right-click on the bar widget opens the WLmouse web app via `omarchy-launch-webapp`

## Supported devices

Depends on what `wl-mouse` supports (BEAST series, etc.). See:
https://github.com/Creationsss/wl-mouse

## Dependencies (runtime)

Required:
- `wl-mouse` CLI (external dependency): https://github.com/Creationsss/wl-mouse
- `timeout` (coreutils) (provided by Omarchy)
- `notify-send` (libnotify) (provided by Omarchy)

Optional:
- `paplay` (PulseAudio/PipeWire) for sound notifications (provided by Omarchy)
- `omarchy-launch-webapp` (provided by Omarchy) for right-click webapp

## Permissions (required)

`wl-mouse` needs read/write access to the `hidraw` device.

Create a udev rule:

```bash
echo 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="36a7", MODE="0666"' | sudo tee /etc/udev/rules.d/99-wlmouse.rules > /dev/null
```

Reload udev rules:

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## Installing `wl-mouse` (recommended on Omarchy / Arch)

### 1) Install Cargo (Rust toolchain)

This installs the Rust package manager needed to build `wl-mouse`:

```bash
sudo pacman -S cargo
```

### 2) Install `wl-mouse` using Cargo

This compiles and installs the `wl-mouse` binary into `~/.cargo/bin/wl-mouse`:

```bash
cargo install --git https://github.com/Creationsss/wl-mouse --locked
```


## Install the plugin

```bash
omarchy plugin add https://github.com/LarsLarkin/omarchy-wlmouse.git --enable
```

After install:
- The widget should appear in the bar.
- Left-click opens the panel.
- Right-click opens the WLmouse web app (edit URL in `BarWidget.qml` if desired).

## Update

If you installed via `omarchy plugin add`, update using Omarchy’s plugin tooling (or re-add / pull depending on your workflow).

## Uninstall

Disable/remove the plugin with Omarchy tooling, or remove the folder:

```bash
omarchy plugin remove omarchy-wlmouse
```


### Uninstall `wl-mouse` (installed via Cargo)

If you installed `wl-mouse` using `cargo install`, remove it with:

```bash
cargo uninstall wl-mouse
```
If you no longer have Cargo/Rust installed, you can remove the binary manually:

  Default Cargo install location:
  ```Bash
  rm -f ~/.cargo/bin/wl-mouse
  ```

(Optional) Remove the udev rule

If you added the udev rule, remove it and reload udev:

```Bash
sudo rm -f /etc/udev/rules.d/99-wlmouse.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

(Optional) Uninstall Cargo/Rust on Omarchy (Arch)

On Arch/Omarchy, cargo is provided by the rust package. To remove it:

```Bash
sudo pacman -Rns rust
```
Remove folder:
```bash
rm -rf $HOME/.cargo
```
Note: remove Rust only after uninstalling wl-mouse with cargo uninstall, otherwise you will need to delete the wl-mouse binary manually.






## Sound alerts (optional)

This plugin can play a sound when low-battery notifications fire (25% warning / 15% critical).

### Disable sound alerts
Open `Service.qml` in the plugin folder (~/.config/omarchy/plugins/omarchy-wlmouse) and set:

```qml
property bool soundEnabled: false
```
Then reload Omarchy shell (or restart the shell) and the plugin will stop playing sounds.

Logs:

```bash
qs log -p "$OMARCHY_PATH/shell" --tail 200 | grep -i omarchy-wlmouse
```




## Security notes

- The plugin runs **unsandboxed** as your user inside the Omarchy shell process.
- It does **not** run `sudo` by itself.
- Any udev rules or system configuration must be applied manually by the user.

## License

MIT

Third-party:
- `wl-mouse` is a separate project and is installed independently:
  https://github.com/Creationsss/wl-mouse
