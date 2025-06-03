local hotkey = require("hs.hotkey")

-- hyper key
local hyper = { "alt", "ctrl", "cmd", "shift" }

-- disable animations
hs.window.animationDuration = 0

hotkey.bind(hyper, "\\", function()
	hs.reload()
end)

-- reload config
hs.alert.show("Config loaded")
