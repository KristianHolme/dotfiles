-- Extra autostart. Night-light schedule lives in hyprsunset.conf; start the
-- daemon so those profiles apply. Network panel replaced nm-applet.
o.exec_on_start("hyprsunset")

-- After lock DPMS, software-replug the Samsung U32E850 (HDMI 4K@60 / Iris Xe).
o.exec_on_start((os.getenv("HOME") or "") .. "/dotfiles/bin/dotfiles-hypr-hdmi-relink.sh watch")
