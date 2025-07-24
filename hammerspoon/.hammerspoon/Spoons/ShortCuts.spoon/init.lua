local obj = {}

--
local function move_window_y(size)
	local win = hs.window.focusedWindow()
	local frame = win:frame()
	frame.y = frame.y + size
	win:setFrame(frame)
end

local function move_window_x(size)
	local win = hs.window.focusedWindow()
	local frame = win:frame()
	frame.x = frame.x + size
	win:setFrame(frame)
end

-- move window to left
local function left_move_window()
	move_window_x(-40)
end

-- move window to right
local function right_move_window()
	move_window_x(40)
end

-- move window up
local function up_move_window()
	move_window_y(-40)
end

-- move window down
local function down_move_window()
	move_window_y(40)
end

-- minimize all windows
local function minimize_all_window()
	local allWindows = hs.window.allWindows()
	for _, win in ipairs(allWindows) do
		if win:isVisible() and not win:isMinimized() then
			win:minimize()
		end
	end
end

-- unminimize all windows
local function unminimize_all_window()
	local allWindows = hs.window.allWindows()
	for _, win in ipairs(allWindows) do
		if win:isMinimized() then
			win:unminimize()
		end
	end
end

-- move window to next monitor
local function move_win_to_next_monitor()
	local win = hs.window.focusedWindow()
	local screen = win:screen()
	win:move(win:frame():toUnitRect(screen:frame()), screen:next(), true, 0)
end

-- set window to full screen
local function win_full_screen()
	local win = hs.window.focusedWindow()
	if win:isFullScreen() then
		win:setFullScreen(false)
	else
		win:setFullScreen(true)
	end
end

-- move mouse to next monitor
local function move_mouse_to_next_monitor()
	local screen = hs.mouse.getCurrentScreen()
	local nextScreen = screen:next()
	local rect = nextScreen:fullFrame()
	local center = hs.geometry.rectMidPoint(rect)
	hs.mouse.setAbsolutePosition(center)
end

-- switch window per app
local function switch_win_per_app()
	hs.eventtap.keyStroke({ "cmd" }, "`")
end

-- copy bundle ID of the focused window to clipboard
local function copy_bundle_id()
	local win = hs.window.focusedWindow()
	if win then
		local bundleID = win:application():bundleID()
		hs.pasteboard.setContents(bundleID)
		hs.alert.show("BundleID: " .. bundleID .. "\nCopied to clipboard!")
	else
		hs.alert.show("No active window")
	end
end

-- init bind default hotkeys, using custom mods
function obj:init(mods)
	if mods == nil then
		mods = { "ctrl", "alt", "cmd" } -- default modifier keys
	end
	hs.hotkey.bind(mods, "H", left_move_window, nil, left_move_window)
	hs.hotkey.bind(mods, "L", right_move_window, nil, right_move_window)
	hs.hotkey.bind(mods, "K", up_move_window, nil, up_move_window)
	hs.hotkey.bind(mods, "J", down_move_window, nil, down_move_window)
	hs.hotkey.bind(mods, "M", minimize_all_window)
	hs.hotkey.bind(mods, "U", unminimize_all_window)
	hs.hotkey.bind(mods, "N", move_win_to_next_monitor)
	hs.hotkey.bind(mods, "O", win_full_screen)
	hs.hotkey.bind(mods, "P", move_mouse_to_next_monitor)
	hs.hotkey.bind(mods, "I", switch_win_per_app)
	hs.hotkey.bind(mods, "B", copy_bundle_id)
end

-- bind custon hotkeys
function obj:bindHotKeys(mods, key, func, repeatable)
	if repeatable then
		hs.hotkey.bind(mods, key, func, nil, func)
	else
		hs.hotkey.bind(mods, key, func)
	end
end

return obj
