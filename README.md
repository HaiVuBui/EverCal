# EverCal

A simple calendar application written in Flutter.

I built this because I wanted a functional calendar that actually looked good on my Linux desktop. It is specifically designed to work seamlessly with tiling window managers like Hyprland.

_[Evercal now has a weekview mode]_

## Screenshots

<table align="center">
  <tr>
    <th colspan="2">Week View</th>
  </tr>
  <tr>
    <td><img src="screenshots/v3_1.png" width="100%" /></td>
    <td><img src="screenshots/v3_2.png" width="100%" /></td>
  </tr>
  <tr>
    <th colspan="2">Month View</th>
  </tr>
  <tr>
    <td><img src="screenshots/DARK.png" width="100%" /></td>
    <td><img src="screenshots/LIGHT.png" width="100%" /></td>
  </tr>
</table>

## Features

- **Clean UI:** Minimalist design with Material 3/Expressive UI guidelines
- **Manual Events:** Create events directly inside EverCal.
- **ICS Import:** Import `.ics` calendars from Google Calendar, Outlook, or anywhere else.
- **Khal / vdir Support (Optional):** Read events from your local vdir calendars via `khal`
- **Theme Support:** Built-in Light and Dark modes. Also supports a global theme state and updates instantly when your system/theme changes.
- **WM + DE Friendly:**
  - **WM mode:** no titlebar/client decorations (border handled by the compositor).
  - **DE mode:** proper titlebar included for environments like KDE/GNOME.

## Installation

[![AUR version](https://img.shields.io/aur/version/evercal?logo=arch-linux&style=flat-square&color=blue)](https://aur.archlinux.org/packages/evercal)

### Arch Linux (AUR)

EverCal is now available to install directly from the [AUR](https://aur.archlinux.org/packages/evercal):

```bash
yay -S evercal
```

### Manual Installation

1.  Download `installer.tar.gz` from the [Releases](https://github.com/snes19xx/EverCal/releases) page.
2.  Extract the archive
3.  Run the script based on your needs, `install_wm.sh` if you don't want titlebar (wm mode) or `install_b.sh` if you want titlebar (gnome/kde)

eg:

```bash
tar -xzvf installer.tar.gz
cd installer
sudo ./install_Wm.sh
```
