--- spoon ShortCuts
--- Some shortcuts for window management and mouse control in Hammerspoon
local obj = {}

-- 窗口移动步长自适应：按屏宽比例 + 刷新率档位
--
-- 思路：
--   step = 屏宽(points) × STEP_RATIO × freq_factor
--
-- 1) 用 currentMode().w 作为屏宽，而非 frame().w：
--    frame() 是可用区(去掉 Dock/菜单栏)，Dock 在侧边时会偏小；
--    currentMode().w 是完整屏宽，不受 Dock 影响。
--
-- 2) 用 points(逻辑像素) 而非物理像素：
--    points 已包含 HiDPI 缩放信息。同一物理屏开 @2x 时 mode.w=1920，
--    不开 @1x 时 mode.w=3840，代入公式后物理移动量自动一致，
--    无需单独处理缩放。
--
-- 3) 刷新率两档补偿：高刷屏(>=100Hz)按基准，低刷屏翻倍，
--    弥补系统按键 repeat 速率与刷新率无关带来的顿挫。
--
-- 校准点：MacBook Pro M4 16寸内置屏 (1728pt, 120Hz) 上保持 40pt 体感。
-- 调参指引：
--   - 整体太快/太慢 → 调 REF_STEP
--   - 低刷屏(60Hz)还想更快/更慢 → 调 FREQ_LOW_FACTOR
--   - 高/低刷分界 → 调 FREQ_THRESHOLD
local REF_WIDTH = 1728     -- 参考屏宽(points): MacBook Pro M4 16寸内置
local REF_STEP = 40        -- 参考步长(points): 高刷屏上的流畅步长
local STEP_RATIO = REF_STEP / REF_WIDTH
local FREQ_THRESHOLD = 100  -- >= 视为高刷
local FREQ_LOW_FACTOR = 2.0  -- 低刷屏步长翻倍补偿

-- 根据当前窗口所在屏幕的宽度和刷新率计算移动步长
local function move_step(win)
	local screen = win:screen()
	local mode = screen and screen:currentMode()
	local freq = mode and mode.freq
	local sw = mode and mode.w
	-- 外接显示器热插拔时 currentMode() 可能短暂返回 nil，回退到参考步长
	if not freq or freq <= 0 or not sw or sw <= 0 then
		return REF_STEP
	end
	local factor = (freq >= FREQ_THRESHOLD) and 1.0 or FREQ_LOW_FACTOR
	-- math.round 非标准 Lua 函数，用 floor(x+0.5) 替代
	return math.max(1, math.floor(sw * STEP_RATIO * factor + 0.5))
end

local function move_window_y(direction)
	local win = hs.window.focusedWindow()
	if not win then
		return
	end
	local step = move_step(win) * direction
	local frame = win:frame()
	frame.y = frame.y + step
	win:setFrame(frame)
end

local function move_window_x(direction)
	local win = hs.window.focusedWindow()
	if not win then
		return
	end
	local step = move_step(win) * direction
	local frame = win:frame()
	frame.x = frame.x + step
	win:setFrame(frame)
end

-- move window to left
local function left_move_window()
	move_window_x(-1)
end

-- move window to right
local function right_move_window()
	move_window_x(1)
end

-- move window up
local function up_move_window()
	move_window_y(-1)
end

-- move window down
local function down_move_window()
	move_window_y(1)
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

--- init bind default hotkeys, using custom mods
--- Parameters:
--- mods: table of modifier keys, default is { "ctrl", "alt", "cmd" }
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

--- bind custon hotkeys
------ Parameters:
--- mods: table of modifier keys, e.g. { "ctrl", "alt" }
--- key: string, the key to bind
--- func: function, the function to call when the key is pressed
--- repeatable: boolean, if true, the function will be called repeatedly while the key is held down
function obj:bindHotKeys(mods, key, func, repeatable)
	if repeatable then
		hs.hotkey.bind(mods, key, func, nil, func)
	else
		hs.hotkey.bind(mods, key, func)
	end
end

return obj
