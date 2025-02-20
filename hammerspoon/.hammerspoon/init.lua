-- hammerspoon
-- 向左移动窗口位置
local function left_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.x = f.x - 40
	win:setFrame(f)
end

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "H", left_move_window, nil, left_move_window)

local function right_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.x = f.x + 40
	win:setFrame(f)
end

-- 向右移动窗口位置
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "L", right_move_window, nil, right_move_window)

local function down_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.y = f.y + 40
	win:setFrame(f)
end

-- 向下移动窗口位置
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "J", down_move_window, nil, down_move_window)

local function up_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.y = f.y - 40
	win:setFrame(f)
end

-- 向上移动窗口位置
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "K", up_move_window, nil, up_move_window)

-- 最小化所有的窗口
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "M", function()
	local allWindows = hs.window.allWindows()
	for _, win in ipairs(allWindows) do
		if not win:isMinimized() then
			win:minimize()
		end
	end
end)

-- 取消最小化的窗口
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "U", function()
	local allWindows = hs.window.allWindows()
	for _, win in ipairs(allWindows) do
		if win:isMinimized() then
			win:unminimize()
		end
	end
end)

hs.loadSpoon("ModalMgr")
hs.loadSpoon("AClock")
hs.loadSpoon("CountDown")

-- 在屏幕上显示时间
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "T", function()
	spoon.AClock:toggleShow()
end)

-- 窗口移动到下一个显示器
hs.hotkey.bind({ "alt", "ctrl", "cmd" }, "n", function()
	local win = hs.window.focusedWindow()
	-- get the screen where the focused window is displayed, a.k.a. current screen
	local screen = win:screen()
	-- compute the unitRect of the focused window relative to the current screen
	-- and move the window to the next screen setting the same unitRect
	win:move(win:frame():toUnitRect(screen:frame()), screen:next(), true, 0)
end)

-- 屏幕全屏
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "O", function()
	local win = hs.window.focusedWindow()
	if win:isFullScreen() then
		win:setFullScreen(false)
	else
		win:setFullScreen(true)
	end
end)

-- 鼠标移动到上一个显示器
hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "p", function()
	local screen = hs.mouse.getCurrentScreen()
	local nextScreen = screen:next()
	local rect = nextScreen:fullFrame()
	local center = hs.geometry.rectMidPoint(rect)
	hs.mouse.setAbsolutePosition(center)
end)

-- 切换窗口
hs.hotkey.bind({ "ctrl", "cmd", "alt" }, "i", function()
	hs.eventtap.keyStroke({ "cmd" }, "`")
end)

local extractLastWord = function(str)
	local last_dot = str:match(".*%.") -- 查找最后一个句点的位置
	local last_word = str:sub(#last_dot + 1) -- 截取最后一个单词
	return last_word
end

local inputMethod = {
	ABC = { layout = "ABC", method = nil },
	Pinyin = { layout = "Pinyin - Simplified", method = "Pinyin - Simplified" },
}

-- 自动切换输入法
local inputMethodConfig = {
	kitty = { layout = "ABC", method = nil, shouldSwitchBack = false, inputMethod = inputMethod["ABC"] },
	VSCode = { layout = "ABC", method = nil, shouldSwitchBack = false, inputMethod = inputMethod["ABC"] },
	doubao = {
		layout = "Pinyin - Simplified",
		method = "Pinyin - Simplified",
		shouldSwitchBack = true,
		inputMethod = inputMethod["Pinyin"],
	},
	xinWeChat = {
		layout = "Pinyin - Simplified",
		method = "Pinyin - Simplified",
		shouldSwitchBack = true,
		inputMethod = inputMethod["Pinyin"],
	},
}

local inputMethodBeforeSwitch = {}

local getAppName = function(win)
	local bundleId = win:application():bundleID()
	print("Bunele Id:", bundleId)
	return extractLastWord(bundleId)
end

-- 不知道中文的设置的时候，设置layout不能实现输入法切换，必须使用setMethod来实现，这里做一下兼容
-- 其实在mac系统中，我的中文输入法使用的就是系统自带的，可以直接使用固定的值
local changeInputMethod = function(config)
	local layout = config.layout
	local method = config.method
	local currentLayout = hs.keycodes.currentLayout()
	if currentLayout == layout then
		return
	end
	if method == nil then
		hs.keycodes.setLayout(layout)
	else
		hs.keycodes.setMethod(method)
	end
end

-- 根据窗口自动切换输入法
hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function(win)
	local appName = getAppName(win)
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
	local appName = getAppName(win)
	local config = inputMethodConfig[appName]
	if config == nil then
		return
	end
	if config.shouldSwitchBack then
		local oldInputMethod = inputMethodBeforeSwitch[appName]
		if oldInputMethod == nil then
			return
		end
		changeInputMethod(oldInputMethod)
	end
end)
