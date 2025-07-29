local homePath = hs.fs.pathToAbsolute("~") -- 会自动展开 ~

local obj = {}

function obj:init()
	-- 1. 初始化 Menubar 和基础菜单
	local myMenubar = hs.menubar.new()
	myMenubar:setTitle("🚀") -- 使用一个 emoji 作为图标

	-- 定义一个全局的菜单数据表，方便后续动态修改
	--
	local menuData = {
		{
			title = "显示提醒",
			fn = function()
				hs.alert.show("这是一个通用菜单项")
			end,
		},
		{
			title = "打开用户目录",
			fn = function()
				-- 使用 shell 命令打开用户目录
				print("Start to open user directory")
				hs.task.new("/usr/bin/open", nil, { homePath }):start()
			end,
		},

		{
			title = "重新加载配置",
			fn = function()
				hs.reload()
			end,
		},
	}

	-- Finder 专属的菜单项
	local finderMenuItem = {
		title = "打开下载文件夹",
		fn = function()
			-- 使用 shell 命令打开“下载”文件夹
			hs.task.new("/usr/bin/open", nil, { "~/Downloads" }):start()
		end,
	}

	-- 封装一个更新菜单的函数，方便调用
	function updateMenubar()
		myMenubar:setMenu(menuData)
	end

	-- 初始时先设置一次菜单
	updateMenubar()

	-- 2. 创建应用监视器
	local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
		-- 3. 在回调函数中处理事件
		if appName == "Finder" then
			if eventType == hs.application.watcher.launched then
				hs.alert.show("检测到访达启动，正在添加菜单...")
				-- 4. 动态更新菜单：在第一个位置插入 Finder 专属菜单
				table.insert(menuData, 1, finderMenuItem)
				-- 5. 应用更新
				updateMenubar()
			elseif eventType == hs.application.watcher.terminated then
				hs.alert.show("检测到访达退出，正在移除菜单...")
				-- 6. 处理应用退出：从菜单中移除专属项
				-- 遍历菜单找到并移除它
				for i, item in ipairs(menuData) do
					if item.title == finderMenuItem.title then
						table.remove(menuData, i)
						break
					end
				end
				-- 应用更新
				updateMenubar()
			end
		end
	end)

	-- 启动监视器
	appWatcher:start()
end

return obj
