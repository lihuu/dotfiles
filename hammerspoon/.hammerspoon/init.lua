--hammerspoon
--向左移动窗口位置

local function left_move_window()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  f.x = f.x - 20
  win:setFrame(f)
end

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "H", left_move_window,nil,left_move_window)

local function right_move_window()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  f.x = f.x + 20
  win:setFrame(f)
end

--向右移动窗口位置
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "L", right_move_window,nil,right_move_window)

local function down_move_window()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  f.y = f.y + 20
  win:setFrame(f)
end

--向下移动窗口位置
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "J",down_move_window,nil, down_move_window)

local function up_move_window()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  f.y = f.y - 20
  win:setFrame(f)
end

--向上移动窗口位置
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "K",up_move_window,nil,up_move_window)


--最小化所有的窗口
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "M", function()
  local allWindows = hs.window.allWindows()
  for _,win in ipairs(allWindows) do
      if not win:isMinimized() then
          win:minimize()
      end
  end
end)


--取消最小化的窗口
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "U", function()
  local allWindows = hs.window.allWindows()
  for _,win in ipairs(allWindows) do
      if win:isMinimized() then
          win:unminimize()
      end
  end
end)

hs.loadSpoon("ModalMgr")
hs.loadSpoon("AClock")
hs.loadSpoon("CountDown")



--在屏幕上显示时间
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "T", function()
    spoon.AClock:toggleShow()
end)

