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
spoon.AutoIme:init(false)
spoon.AutoIme:start()

hs.shutdownCallback = function()
	if spoon.AutoIme ~= nil then
		spoon.AutoIme:stop()
	end
end

------------------------------------------------------------
-- Prefix + letter -> App switch (bundle id)
-- + cycle windows within the same app
------------------------------------------------------------

-- ✅ 只改这里：选择你的前缀键
-- local PREFIX = {"ctrl"}                 -- Ctrl + <letter>
-- local PREFIX = {"alt"}                  -- Option + <letter>
-- local PREFIX = {"ctrl", "space"}        -- ❌ hs.hotkey 不支持把 space 放在 modifiers 里（见下方说明）
local PREFIX = { "ctrl", "alt" } -- 推荐：Ctrl + 字母（最稳、最通用）

-- 映射：按键 -> bundle id
local appKeymap = {
	a = "com.google.antigravity",
	e = "org.gnu.Emacs",
	c = "com.google.Chrome",
	s = "com.apple.Safari", -- Slack: "com.tinyspeck.slackmacgap"
	t = "dev.warp.Warp-Stable", -- iTerm2: "com.googlecode.iterm2"
	f = "com.apple.finder",
	v = "com.microsoft.VSCode",
	w = "com.tencent.xinWeChat",
	n = "com.yinxiang.Mac",
	p = "com.openai.chat",
}

local function findApp(bundleID)
	return hs.application.get(bundleID) or hs.application.find(bundleID)
end

local function getCycleableWindows(app)
	if not app then
		return {}
	end

	local wins = app:allWindows() or {}
	local filtered = {}

	for _, w in ipairs(wins) do
		if w and w:isStandard() and w:isVisible() then
			table.insert(filtered, w)
		end
	end

	table.sort(filtered, function(a, b)
		return (a:id() or 0) < (b:id() or 0)
	end)

	return filtered
end

local function nextWindow(windows, currentWin)
	local n = #windows
	if n == 0 then
		return nil
	end
	if n == 1 then
		return windows[1]
	end

	local currentID = currentWin and currentWin:id() or nil
	if not currentID then
		return windows[1]
	end

	local idx = nil
	for i, w in ipairs(windows) do
		if w:id() == currentID then
			idx = i
			break
		end
	end
	if not idx then
		return windows[1]
	end

	local nextIdx = idx + 1
	if nextIdx > n then
		nextIdx = 1
	end
	return windows[nextIdx]
end

local function switchOrCycle(bundleID)
	if not bundleID or bundleID == "" then
		return
	end

	local frontApp = hs.application.frontmostApplication()
	local frontBundle = frontApp and frontApp:bundleID() or nil

	local app = findApp(bundleID)

	-- 未运行：启动并聚焦
	if not app then
		hs.application.launchOrFocusByBundleID(bundleID)
		return
	end

	-- 当前已在目标 app：循环窗口
	if frontBundle == bundleID then
		local wins = getCycleableWindows(app)
		local curWin = hs.window.focusedWindow()
		local w = nextWindow(wins, curWin)

		if w then
			w:focus()
		else
			app:activate(true)
		end
		return
	end

	-- 切到目标 app，并尽量聚焦窗口
	app:activate(true)
	hs.timer.doAfter(0.03, function()
		local a = findApp(bundleID)
		if not a then
			return
		end

		local wins = getCycleableWindows(a)
		if #wins > 0 then
			local mw = a:mainWindow()
			if mw and mw:isStandard() and mw:isVisible() then
				mw:focus()
			else
				wins[1]:focus()
			end
		else
			a:activate(true)
		end
	end)
end

-- 绑定热键：PREFIX + letter
for key, bundleID in pairs(appKeymap) do
	hs.hotkey.bind(PREFIX, key, function()
		switchOrCycle(bundleID)
	end)
end

hs.alert.show("App switcher loaded")
