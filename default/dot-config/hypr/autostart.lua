-- Extra autostart. Night-light schedule lives in hyprsunset.conf; start the
-- daemon so those profiles apply. Network panel replaced nm-applet.
o.exec_on_start("hyprsunset")
