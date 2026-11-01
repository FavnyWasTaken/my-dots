# Introduction:
Sup everyone, this is my personal setup for Arch / CachyOS + Hyprland + Caelestia shell, wrapped into one script. Fresh install, a couple of commands, and the whole desktop (shell, apps, configs, themes, bootloader look) ends up the way I like it. No more "ok what was I even using" after every reinstall.

# What you will get?
Caelestia shell v2.5.0 + 17 upstream commits from my fork: my-caelestia-shell (branch custom). Monocraft font everywhere, custom assets, thats about it
Hyprland config (Lua-based), kitty, fish, starship, nvim, yazi, fastfetch, easyeffects, mpd + mpDris2 + ncmpcpp, equibop settings, nwg-look settings
Dark theme everywhere (GTK, Qt, browsers), my cursor, Papirus-Dark icons
Custom SDDM theme (pixel-cyberpunk)
Custom Limine bootloader look (font, palette, splash)
Animated wallpaper service (mpvpaper)
Package lists for the whole thing

# Installation

Make a normal user, log in to a graphical session (CachyOS with Hyprland is the easiest way), open a terminal and use this commands:

sudo pacman -S --needed git hyprland paru
git clone https://github.com/FavnyWasTaken/my-dots.git
cd ~/my-dots/
chmod +x install.sh
./install.sh

After end of script use reboot and enjoy the new system.

# Some information About This Dots

The system itself weighs ±14.1 GB when fully installed, the installation takes about 10-15 minutes if you have an internet speed of at least 80Mbpss and if you have a drive read speed of abembarrassments

# Some embarrassments







   

