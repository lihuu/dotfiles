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
--hs.hotkey.bind(mods, key, [message,] pressedfn, releasedfn, repeatfn) -> hs.hotkey object
-- 向左移动窗口位置
local function left_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.x = f.x - 40
	win:setFrame(f)
end

hs.hotkey.bind(mods, "H", left_move_window, nil, left_move_window)
hs.hotkey.bind(hhkbMods, "H", left_move_window, nil, left_move_window)

local function right_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.x = f.x + 40
	win:setFrame(f)
end

-- 向右移动窗口位置
hs.hotkey.bind(mods, "L", right_move_window, nil, right_move_window)
hs.hotkey.bind(hhkbMods, "L", right_move_window, nil, right_move_window)

local function down_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.y = f.y + 40
	win:setFrame(f)
end

-- 向下移动窗口位置
hs.hotkey.bind(mods, "J", down_move_window, nil, down_move_window)
hs.hotkey.bind(hhkbMods, "J", down_move_window, nil, down_move_window)

local function up_move_window()
	local win = hs.window.focusedWindow()
	local f = win:frame()
	f.y = f.y - 40
	win:setFrame(f)
end

-- 向上移动窗口位置
hs.hotkey.bind(mods, "K", up_move_window, nil, up_move_window)
hs.hotkey.bind(hhkbMods, "K", up_move_window, nil, up_move_window)

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
local fullScreen = function()
	local win = hs.window.focusedWindow()
	if win:isFullScreen() then
		win:setFullScreen(false)
	else
		win:setFullScreen(true)
	end
end
hs.hotkey.bind(mods, "O", fullScreen)
hs.hotkey.bind(hhkbMods, "O", fullScreen)

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

hs.hotkey.bind(hhkbMods, "i", function()
	hs.eventtap.keyStroke({ "cmd" }, "`")
end)

-- 显示当前窗口的bundleID并复制到剪贴板
local showCurrentBundleId = function()
	local win = hs.window.focusedWindow()
	if win then
		local bundleID = win:application():bundleID()
		hs.pasteboard.setContents(bundleID)
		hs.alert.show("BundleID: " .. bundleID .. "\nCopied to clipboard!")
	else
		hs.alert.show("No active window")
	end
end
hs.hotkey.bind(mods, "B", showCurrentBundleId)
hs.hotkey.bind(hhkbMods, "B", showCurrentBundleId)

-- 自动切换输入法

local initConfig = hs.json.read("./config.json")

local inputMethodConfig = {}

local windowFilter = hs.window.filter.new(false)
--- 将 bundleId 转为 appName（使用 Spotlight）
--- 如果找不到则返回 nil
local function appNameFromBundleId(bundleId)
	if not bundleId or bundleId == "" then
		return nil
	end

	-- 使用 mdfind 查找应用路径
	local findCmd = string.format("mdfind \"kMDItemCFBundleIdentifier == '%s'\"", bundleId)
	local result = hs.execute(findCmd)
	local appPath = result and result:match("([^\n]+)")

	if not appPath then
		hs.printf("⚠️ 未找到安装路径（bundleId=%s）", bundleId)
		return nil
	end

	-- 使用 mdls 获取显示名称
	local nameCmd = string.format("mdls -name kMDItemDisplayName -raw '%s'", appPath)
	local appName = hs.execute(nameCmd)
	if appName then
		return appName:gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")
	else
		hs.printf("⚠️ 无法读取 App Name（路径=%s）", appPath)
		return nil
	end
end

-- convert bundleId to appName and ignore unknown app
--
local function bundleIdToAppName(bundleId)
	local appName = appNameFromBundleId(bundleId)
	print("Find valid AppName: ", appName)
	return appName
end

local bundleIdToNameCache = initConfig.bundleIdToNameCache or {}

-- process config and custom filter
print("Start to process config")
print("InputMethod Config: ", hs.inspect(initConfig.inputMethod))
local configChanged = false
for _, value in ipairs(initConfig.inputMethod) do
	local inputMethod =
		{ shouldSwitchBack = value.shouldSwitchBack, inputMethod = { layout = value.layout, method = value.method } }
	for _, app in ipairs(value.apps) do
		inputMethodConfig[app] = inputMethod
		local appName = bundleIdToNameCache[app]
		print(appName)
		if appName == nil then
			appName = bundleIdToAppName(app)
			bundleIdToNameCache[app] = appName
			configChanged = true
		end
		if appName then
			windowFilter:setAppFilter(appName, true) -- 允许所有标题
		end
	end
end

if configChanged then
	-- 如果有修改，保存到文件中
	local newConfig = { inputMethod = initConfig.inputMethod, bundleIdToNameCache = bundleIdToNameCache }
	local filePath = hs.configdir .. "/config.json"
	local file = io.open(filePath, "w")
	if file then
		file:write(hs.json.encode(newConfig, true))
		file:close()
		print("Config saved to " .. filePath)
	else
		print("Failed to save config to " .. filePath)
	end
end

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
	if currentLayout == layout and (currentMethod == method) then
		return
	end
	hs.keycodes.setLayout(layout)
	if method ~= nil then
		hs.keycodes.setMethod(method)
	end
end

print("Finish processing config")
-- 根据窗口自动切换输入法

print("Start to add subscribe")

windowFilter:subscribe(hs.window.filter.windowFocused, function(win)
	local appName = getAppBundleId(win)
	local config = inputMethodConfig[appName]
	if config == nil then
		return
	end
	if config.shouldSwitchBack then
		inputMethodBeforeSwitch[appName] =
			{ layout = hs.keycodes.currentLayout(), method = hs.keycodes.currentMethod() }
	end
	print(
		"AppName: ",
		appName,
		"currentLayout: ",
		hs.keycodes.currentLayout(),
		"currentMethod: ",
		hs.keycodes.currentMethod()
	)
	changeInputMethod(config.inputMethod)
end)

print("Finish adding subscribe")

-- 开启自动切换输入法之后，要不要切换回去
windowFilter:subscribe(hs.window.filter.windowUnfocused, function(win)
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
