# fixfuxi
A script to fix audio and microphone issues on the Fuxi headset and potentially other wireless headsets on Linux.


# USB Headset Audio Fix (Linux / PipeWire)

Automatic fix for common **USB headset issues on Linux**, especially on systems using **PipeWire + WirePlumber**.

This project adjusts audio system behavior to ensure USB gaming headsets work correctly, both **wired** and **through a wireless dongle**.

---

## Problems This Project Solves

Some USB headsets fail on Linux due to limitations in the device's internal mixer. Common issues include:

- audio working on only **one side of the headset**
- **microphone starting muted or at zero**
- failures when **lowering system volume**
- issues when switching between **USB and wireless mode**
- device entering **automatic suspend**
- PipeWire configuring audio channels incorrectly

---

## How It Works

The solution adjusts **PipeWire/WirePlumber** audio policy so the system uses **software volume control** instead of the headset's internal mixer.

This avoids common issues in USB devices with broken or incomplete mixers.

As a result, the system gets:

- properly working stereo audio  
- stable microphone behavior after reboot  
- reliable switching between **USB and wireless**  
- normal system volume behavior  

---

## Compatibility

Works on modern Linux distributions that use **PipeWire**, such as:

- Ubuntu
- Linux Mint
- Fedora
- Arch Linux
- Pop!_OS
- Nobara
- Garuda
- other PipeWire-based distributions

---

## Supported Devices

Although it was created for the **Fuxi H3**, this project works with most **USB gaming headsets**, including:

- wired USB headsets  
- wireless headsets with a USB dongle  
- devices identified as **USB Audio**

---

## When to Use

Use this project if your headset has:

- one-sided audio  
- microphone that stops working  
- problems when changing volume  
- issues switching between cable and wireless

## How to Use

1. Clone the repository:

```
git clone https://github.com/jeffrichardchemistry/fixfuxi.git
cd fixfuxi
```

2. Make the scripts executable:

```
chmod +x FixFuxiH3.sh
chmod +x fuxi_alsa_100.sh
```

3. Run the script:

```
./FixFuxiH3.sh
```

The script performs three operations automatically:

- applies the WirePlumber stability patch
- applies the ALSA output volume adjustment to 100% for Fuxi cards
- installs user-level systemd persistence to reapply settings at session startup and periodically (covers headset reconnection)
- retries card detection and volume application during boot/login (automatic retries)

4. Restart your session or system (optional, recommended the first time):

```
reboot
```

After restarting, your audio system should be correctly configured for USB headsets.

## Execution Modes

### Adjust only Fuxi output volume (manual)

```
./FixFuxiH3.sh --volume-only
```

Ou via wrapper legado:

```
./fuxi_alsa_100.sh
```

### Install/update persistence only

```
./FixFuxiH3.sh --install-only
```

### Run without installing persistence

```
./FixFuxiH3.sh --no-persist
```

### Run with detailed logs

```
./FixFuxiH3.sh --debug
```

## Persistence (systemd --user)

Automatically installed files:

- ~/.config/systemd/user/fixfuxi-volume.service
- ~/.config/systemd/user/fixfuxi-volume.timer

Behavior:

- runs at user session startup
- reapplies settings continuously every 20 seconds
- covers dongle/headset reconnection during the session
- at boot/login, retries while waiting for Fuxi cards to become available
- persistent service runs with detailed logs enabled

Useful commands:

```
systemctl --user status fixfuxi-volume.timer
systemctl --user status fixfuxi-volume.service
journalctl --user -u fixfuxi-volume.service -n 50 --no-pager
journalctl --user -u fixfuxi-volume.service -f
```

## Uninstall Persistence

```
systemctl --user disable --now fixfuxi-volume.timer
rm -f ~/.config/systemd/user/fixfuxi-volume.service
rm -f ~/.config/systemd/user/fixfuxi-volume.timer
systemctl --user daemon-reload
```

## Quick Troubleshooting

- If no Fuxi card is found, connect the headset and run `aplay -l` to validate detection.
- If the headset appears a few seconds after login, wait for automatic retries (up to ~30s).
- If microphone gain becomes too high or clips, this project does not force capture controls to 100%.
- If `wireplumber.service` does not exist in your environment, volume adjustment still works through ALSA.
