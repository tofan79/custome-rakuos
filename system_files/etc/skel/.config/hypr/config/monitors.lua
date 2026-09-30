-- Monitor wiki https://wiki.hypr.land/Configuring/Basics/Monitors/
-- output can be found with hyprctl monitors. Edit variables.lua for the monitor
-- outputs instead of here directly.
--
-- Nothing here is pinned to a particular machine. output comes from
-- variables.lua (empty, so Hyprland picks whatever is connected), mode is
-- "preferred" and position "auto" so any panel is placed by the compositor.
--
-- scale is deliberately left unset. Hyprland defaults to 1 when it is absent,
-- so this behaves exactly like scale = "1" without asserting a value that is
-- wrong for HiDPI panels -- a 2560x1600 laptop at 1 is unreadably small, and
-- pinning it here makes that look intentional to the next person reading the
-- config rather than like a default nobody chose. Hyprland 0.56 has no
-- autoscale, so HiDPI users should set it for their own output, e.g.
--
--     hl.monitor({ output = "eDP-1", scale = "2" })
--
-- Note that the skel is copied into a home once, at account creation. Editing
-- it afterwards does not reach existing users.
hl.monitor({
    output    = MONITOR1,
    mode      = "preferred",
    position  = "auto",
})
