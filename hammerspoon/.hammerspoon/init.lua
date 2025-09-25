--require("hs.ipc")

local mods = { "cmd", "alt", "ctrl" }
-- hhkb的键位比较特殊，使用上面的那个mods按起来不爽
local hhkbMods = { "cmd", "alt", "shift" }

local spoonInstall = hs.loadSpoon("SpoonInstall", true)
if spoonInstall ~= nil then
	spoonInstall:andUse("ModalMgr")
	spoonInstall:andUse("AClock")
	spoonInstall:andUse("CountDown")
    -- Disable BingDaily for now, it seems does not work well.
	--spoonInstall:andUse("BingDaily")

	-- 在屏幕上显示时间
	hs.hotkey.bind(mods, "T", function()
		spoon.AClock:toggleShow()
		-- get current time as 2025-08-29T20:54:52+08:00
		local currentTime = os.date("%Y-%m-%d %H:%M:%S")
		-- hs.alert.show("Current time: " .. currentTime)
		-- add to clipboard
		hs.pasteboard.setContents(currentTime)
	end)
end
hs.loadSpoon("Shortcuts", true)
hs.loadSpoon("AutoIme", true)
spoon.Shortcuts:init(mods)
spoon.Shortcuts:init(hhkbMods)
spoon.AutoIme:init()
