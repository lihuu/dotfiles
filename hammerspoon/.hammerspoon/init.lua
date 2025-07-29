require("hs.ipc")

local mods = { "cmd", "alt", "ctrl" }
-- hhkb的键位比较特殊，使用上面的那个mods按起来不爽
local hhkbMods = { "cmd", "alt", "shift" }

local spoonInstall = hs.loadSpoon("SpoonInstall", true)
if spoonInstall ~= nil then
	spoonInstall:andUse("ModalMgr")
	spoonInstall:andUse("AClock")
	spoonInstall:andUse("CountDown")
	spoonInstall:andUse("BingDaily")

	-- 在屏幕上显示时间
	hs.hotkey.bind(mods, "T", function()
		spoon.AClock:toggleShow()
	end)
end
hs.loadSpoon("Shortcuts", true)
hs.loadSpoon("AutoIme", true)
spoon.Shortcuts:init(mods)
spoon.Shortcuts:init(hhkbMods)
spoon.AutoIme:init()
