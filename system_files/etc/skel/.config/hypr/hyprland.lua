-- RakuOS Hyprland Configuration

require("config.animations")
require("config.autostart")
require("config.decorations")
require("config.variables")
require("config.environment")
require("config.inputs")

-- GloView is disabled for now: the plugin's own repo is not ready, so there is
-- nothing to install gloview-git from reliably. Re-enable both this line and the
-- matching block in config/binds.lua together -- binds.lua only registers the
-- shortcuts when hl.plugin.gloview exists, so loading the plugin without the
-- binds (or the reverse) is a half-enabled state.
-- hl.plugin.load("/usr/lib64/gloview.so")

require("config.binds")
require("config.misc")
require("config.monitors")
require("config.windowrules")
require("config.workspaces")
require("config.lid")
dofile(os.getenv("HOME") .. "/.config/hypr/layouts/fair.lua")
dofile(os.getenv("HOME") .. "/.config/hypr/layouts/deck.lua")

-- For Noctalia Color templates
require("noctalia").apply_theme()

-- Override border ke gradient 2 warna (primary->secondary) setelah apply_theme,
local noct = require("noctalia")
hl.config({
    general = {
        col = {
            active_border = {
                colors = { noct.colors.primary, noct.colors.secondary },
                angle = 45,
            },
        },
    },
})
