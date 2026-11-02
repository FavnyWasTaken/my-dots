<img width="2558" height="1437" alt="Unknown" src="https://github.com/user-attachments/assets/8ea4963d-0113-4df6-af03-79830582f1cc" />

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
## The basic theme itself is monochrome with slight shades of dark green.

# Installation:

Make a normal user, log in to a graphical session (CachyOS with Hyprland is the easiest way), open a terminal and use this command:
```
sudo pacman -S --needed git && git clone https://github.com/FavnyWasTaken/my-dots.git ~/my-dots && cd ~/my-dots && chmod +x install.sh && ./install.sh
```
After end of script use reboot and enjoy the new system.

# Some information About This Dots

The system itself weighs ±14.1 GB when fully installed, the installation takes about 10-15 minutes if you have an internet speed of at least 80Mbpss and if you have a drive read speed of least 2000 MB/sec. Basic usage RAM wo/ gpu-screen-recorder is 2.3 - 2.9 GB.

# Troubleshooting:

## 1. 
U can see that every minute after the start of the session, the RAM usage begins to increase, this is not a virus or a miner, this is the fault of the constant local screen recording that runs through GPUs screens recorder, if you need to disable this function go to ~/.config/hypr/hyprland/execs.lua go to line 38-41
```
- Replay buffer hl.exec_cmd( "gpu-screen-recorder -w screen -s 2560x1440 -f 60 -a default_output -c mp4 -r 1800 -restart-replay-on-save yes -bm cbr -q 20000 -o /home/favny/Videos/Replays")
```
and either delete these lines or comment them out. And re-enter the session. If u want to stay this function, replay videos saves on SUPER + F1 to ~/Video/Replays/U_NEW_REPLAY.mp4

## 2.

Some people may have a problem with changing the theme of the Celestia shell, this happens on weak SSDs/HDDs, it may be pink to fix it use: ``` systemctl --user restart quickshell-caelestia.service ``` And try it again. 

## 3.

No covers / "Unknown" in the music widget: check python-mutagen is installed and that the files actually have tags. A file without tags just shows as unknown, nothing can fix that except tagging it

# Music
My music (several GB) is not in the repo. Too big for git, and its not mine to publish anyway. The script only sets up mpd, mpDris2 and ncmpcpp so they work out of the box. After you copy your music to ~/Music, use this commands:
```
mpc clear
mpc update
mpd add /
```
After this open ncmpcpp (SUPER + M) and on TAB keybinds switch on u album and listing u favorite music (Or not favorite, I know something?)

# Credits
caelestia-dots/shell - the shell this is all about

Darkkal44/qylock - base of the SDDM theme (GPL, check the license in their repo)

Monocraft font

everyone whose packages I use in the lists




## License

MIT for my own stuff (see `LICENSE`). The SDDM theme in `sddm/pixel-cyberpunk` keeps its upstream GPL license. Third-party fonts, images and videos belong to their authors.
