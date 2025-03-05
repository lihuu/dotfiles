hs.loadSpoon("ModalMgr")
hs.loadSpoon("AClock")
hs.loadSpoon("CountDown")
--hs.hotkey.bind(mods, key, [message,] pressedfn, releasedfn, repeatfn) -> hs.hotkey object
-- 向左移动窗口位置
local function left_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.x = f.x - 40
	win:setFrame(f)
end

local mods = { "cmd", "alt", "ctrl" }

hs.hotkey.bind(mods, "H", left_move_window, nil, left_move_window)

local function right_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.x = f.x + 40
	win:setFrame(f)
end

-- 向右移动窗口位置
hs.hotkey.bind(mods, "L", right_move_window, nil, right_move_window)

local function down_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.y = f.y + 40
	win:setFrame(f)
end

-- 向下移动窗口位置
hs.hotkey.bind(mods, "J", down_move_window, nil, down_move_window)

local function up_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.y = f.y - 40
	win:setFrame(f)
end

-- 向上移动窗口位置
hs.hotkey.bind(mods, "K", up_move_window, nil, up_move_window)

-- 最小化所有的窗口
hs.hotkey.bind(mods, "M", function()
	local allWindows = hs.window.allWindows()
	for _, win in ipairs(allWindows) do
		if not win:isMinimized() then
			win:minimize()
		end
	end
end)

-- 取消最小化的窗口
hs.hotkey.bind(mods, "U", function()
	local allWindows = hs.window.allWindows()
	for _, win in ipairs(allWindows) do
		if win:isMinimized() then
			win:unminimize()
		end
	end
end)

-- 在屏幕上显示时间
hs.hotkey.bind(mods, "T", function()
	spoon.AClock:toggleShow()
end)

-- 窗口移动到下一个显示器
hs.hotkey.bind(mods, "n", function()
	local win = hs.window.focusedWindow()
	-- get the screen where the focused window is displayed, a.k.a. current screen
	local screen = win:screen()
	-- compute the unitRect of the focused window relative to the current screen
	-- and move the window to the next screen setting the same unitRect
	win:move(win:frame():toUnitRect(screen:frame()), screen:next(), true, 0)
end)

-- 屏幕全屏
hs.hotkey.bind(mods, "O", function()
	local win = hs.window.focusedWindow()
	if win:isFullScreen() then
		win:setFullScreen(false)
	else
		win:setFullScreen(true)
	end
end)

-- 鼠标移动到上一个显示器
hs.hotkey.bind(mods, "p", function()
	local screen = hs.mouse.getCurrentScreen()
	local nextScreen = screen:next()
	local rect = nextScreen:fullFrame()
	local center = hs.geometry.rectMidPoint(rect)
	hs.mouse.setAbsolutePosition(center)
end)

-- 切换窗口
hs.hotkey.bind(mods, "i", function()
	hs.eventtap.keyStroke({ "cmd" }, "`")
end)

-- 显示当前窗口的bundleID并复制到剪贴板
hs.hotkey.bind(mods, "B", function()
	local win = hs.window.focusedWindow()
	if win then
		local bundleID = win:application():bundleID()
		hs.pasteboard.setContents(bundleID)
		hs.alert.show("BundleID: " .. bundleID .. "\nCopied to clipboard!")
	else
		hs.alert.show("No active window")
	end
end)

local initConfig = hs.json.read("./config.json")

local inputMethodConfig = {}

for _, value in ipairs(initConfig.inputMethod) do
	local inputMethod =
		{ shouldSwitchBack = value.shouldSwitchBack, inputMethod = { layout = value.layout, method = value.method } }
	for _, app in ipairs(value.apps) do
		inputMethodConfig[app] = inputMethod
	end
end

-- 自动切换输入法

local inputMethodBeforeSwitch = {}

local getAppBundleId = function(win)
	return win:application():bundleID()
end

-- 设置的时候，layout和method都要设置
local changeInputMethod = function(config)
	local layout = config.layout
	local method = config.method
	local currentLayout = hs.keycodes.currentLayout()
	local currentMethod = hs.keycodes.currentMethod()
	--print("currentLayout: ", currentLayout, "currentMethod: ", currentMethod)
	if currentLayout == layout and (currentMethod == method) then
		return
	end
	hs.keycodes.setLayout(layout)
	if method ~= nil then
		hs.keycodes.setMethod(method)
	end
end

-- 根据窗口自动切换输入法
hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(win)
	local appName = getAppBundleId(win)
	local config = inputMethodConfig[appName]
	if config == nil then
		return
	end
	if config.shouldSwitchBack then
		inputMethodBeforeSwitch[appName] =
			{ layout = hs.keycodes.currentLayout(), method = hs.keycodes.currentMethod() }
	end
	changeInputMethod(config.inputMethod)
end)

-- 开启自动切换输入法之后，要不要切换回去
hs.window.filter.default:subscribe(hs.window.filter.windowUnfocused, function(win)
	local bundleId = getAppBundleId(win)
	local config = inputMethodConfig[bundleId]
	if config == nil then
		return
	end
	if config.shouldSwitchBack then
		local oldInputMethod = inputMethodBeforeSwitch[bundleId]
		if oldInputMethod == nil then
			return
		end
		changeInputMethod(oldInputMethod)
	end
end)

local lastVimInputMethod = nil
hs.hotkey.bind(mods, "A", function()
	-- change to abc layout
	local currentLayout = hs.keycodes.currentLayout()
	local currentMethod = hs.keycodes.currentMethod()
	if currentLayout == "Pinyin - Simplified" then
		lastVimInputMethod = { layout = currentLayout, method = currentMethod }
	else
		lastVimInputMethod = nil
	end
	changeInputMethod({ layout = "ABC", method = nil })
end)

hs.hotkey.bind(mods, "S", function()
	if lastVimInputMethod ~= nil then
		changeInputMethod({ layout = "Pinyin - Simplified", method = "Pinyin - Simplified" })
	end
end)

-- 加载键盘重映射模块
local keyboardRemap = require("keyboard_remap")

-- 设置目标键盘信息 (需要修改为你的蓝牙键盘信息)
-- TODO 需要重新实现
keyboardRemap.targetKeyboard = {
	name = "YOUR_BLUETOOTH_KEYBOARD_NAME", -- 替换为你的蓝牙键盘名称
	productID = 5678, -- 替换为你的蓝牙键盘productID
	transport = "Bluetooth", -- 指定仅匹配蓝牙键盘
}

-- 使用下面的函数来查找并打印你的蓝牙键盘信息
-- keyboardRemap.findKeyboards()

-- 添加快捷键来启用/禁用重映射
hs.hotkey.bind(mods, "R", function()
	if keyboardRemap.eventTap and keyboardRemap.eventTap:isEnabled() then
		keyboardRemap.stop()
		hs.alert.show("键盘重映射已禁用")
	else
		keyboardRemap.start()
		hs.alert.show("键盘重映射已启用")
	end
end)

-- 自动启动键盘重映射 (取消下面的注释来自动启动)
-- keyboardRemap.start()
