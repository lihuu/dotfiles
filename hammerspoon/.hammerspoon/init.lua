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

local function isTableEmpty(t)
	if t == nil then
		return true
	end
	for _, _ in ipairs(t) do
		return true
	end
	return false
end

-- list connected usb devices
local devices = hs.usb.attachedDevices()
if isTableEmpty(devices) then
	print("No USB devices found")
else
	for i, device in ipairs(devices) do
		print(string.format("Device %d:", i))
		print(string.format("  Vendor ID: 0x%x", device:vendorID()))
		print(string.format("  Product ID: 0x%x", device:productID()))
		print(string.format("  Manufacturer: %s", device:manufacturer()))
		print(string.format("  Product Name: %s", device:productName()))
		print("--------------------")
	end
end


local command = "system_profiler SPBluetoothDataType"

local a,b,c,d = hs.execute(command, false)

print(a)
print(b)
print(c)
print(d)
