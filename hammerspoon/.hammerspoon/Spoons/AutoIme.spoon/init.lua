local obj = {
	debug = false,
}

obj.__index = obj

obj.name = "AutoIme"
obj.version = "1.1"

local function startWith(str, prefix)
	return str:sub(1, #prefix) == prefix
end

local function print_log(message)
	if obj.debug then
		if startWith(message, "--") then
			print(message)
		else
			print("   " .. message)
		end
	end
end

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
local function bundleIdToAppName(bundleId)
	local appName = appNameFromBundleId(bundleId)
	print("Find valid AppName: ", appName)
	return appName
end

local getAppBundleId = function(win)
	local app = win and win:application()
	return app and app:bundleID() or nil
end

-- 设置的时候，layout和method都要设置
local changeInputMethod = function(config)
	if not config or not config.layout then
		return
	end
	local layout = config.layout
	local method = config.method
	local currentLayout = hs.keycodes.currentLayout()
	local currentMethod = hs.keycodes.currentMethod()
	print_log("target input method: " .. layout .. ", " .. (method or "nil"))
	print_log("Current layout: " .. currentLayout .. ", method: " .. (currentMethod or "nil"))
	if currentLayout == layout and (currentMethod == method) then
		print_log("Same input method, no need to change")
		return
	end
	hs.keycodes.setLayout(layout)
	if method ~= nil then
		hs.keycodes.setMethod(method)
	end
	print_log(
		"Input method changed to: " .. hs.keycodes.currentLayout() .. ", " .. (hs.keycodes.currentMethod() or "nil")
	)
end

local changeInputMethodDelayed = function(config, delay)
	delay = delay or 0.05
	hs.timer.doAfter(delay, function()
		changeInputMethod(config)
	end)
end

--- 标题是否命中某条 TUI 规则（Lua pattern + 大小写不敏感 contains）
local function matchTuiTitleRule(title, rules)
	if not title or title == "" or not rules then
		return nil
	end
	local lowerTitle = title:lower()
	for _, rule in ipairs(rules) do
		if rule.patterns then
			for _, pattern in ipairs(rule.patterns) do
				if title:match(pattern) then
					return rule
				end
			end
		end
		if rule.contains then
			for _, needle in ipairs(rule.contains) do
				if needle and needle ~= "" and lowerTitle:find(needle:lower(), 1, true) then
					return rule
				end
			end
		end
	end
	return nil
end

function obj:init(debug)
	-- Initialize the spoon
	self.debug = debug or false

	local windowFilter = hs.window.filter.new(false)
	local configPath = hs.configdir .. "/config.json"
	local initConfig = hs.json.read(configPath)

	-- 这相当于做了一个缓存，这样就不需要每次都去查找应用名称，并且查询应用的名称使用了，spotlight索引了，可能出现索引没有构建完成，而导致应用名称查找失败的问题

	-- process config and custom filter
	local configChanged = false
	local inputMethodConfig = {}
	local bundleIdToNameCache = initConfig.bundleIdToNameCache or {}
	for _, value in ipairs(initConfig.inputMethod) do
		local inputMethod = {
			shouldSwitchBack = value.shouldSwitchBack,
			inputMethod = { layout = value.layout, method = value.method },
		}
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

	-- 终端内 TUI 标题检测（qwen-code / grok-build / claude-code / opencode 等，见 config.json）
	local tuiTitleDetection = initConfig.tuiTitleDetection or {}
	local tuiApps = {}
	for _, bundleId in ipairs(tuiTitleDetection.apps or {}) do
		tuiApps[bundleId] = true
		-- 确保这些终端也在 windowFilter 中（通常已在 inputMethod 里）
		local appName = bundleIdToNameCache[bundleId]
		if appName == nil then
			appName = bundleIdToAppName(bundleId)
			bundleIdToNameCache[bundleId] = appName
			configChanged = true
		end
		if appName then
			windowFilter:setAppFilter(appName, true)
		end
	end

	if configChanged then
		-- 保留原有其它配置字段，只更新缓存
		local newConfig = {}
		for k, v in pairs(initConfig) do
			newConfig[k] = v
		end
		newConfig.bundleIdToNameCache = bundleIdToNameCache
		local file = io.open(configPath, "w")
		if file then
			file:write(hs.json.encode(newConfig, true))
			file:close()
			print_log("Config saved to " .. configPath)
		else
			print_log("Failed to save config to " .. configPath)
		end
	end

	self.inputMethodConfig = inputMethodConfig
	self.tuiApps = tuiApps
	self.tuiTitleRules = tuiTitleDetection.rules or {}
	self._subscribed = false
	self.wf = windowFilter
	self.wf:setCurrentSpace(true)
	print_log("AutoIme initialized")
end

function obj:start()
	if self._subscribed then
		return self
	end
	local windowFilter = self.wf
	windowFilter:unsubscribeAll()
	local inputMethodConfig = self.inputMethodConfig or {}
	local tuiApps = self.tuiApps or {}
	local tuiTitleRules = self.tuiTitleRules or {}
	local inputMethodBeforeSwitch = {}
	local lastInputMethod = {}

	--- 根据当前窗口决定应使用的输入法配置
	local function resolveInputMethod(win, appConfig)
		local bundleId = getAppBundleId(win)
		if not bundleId or not appConfig then
			return nil, nil
		end

		-- 终端 App：优先按标题判断是否在跑 TUI（如 qwen-code）
		if tuiApps[bundleId] then
			local title = win:title() or ""
			local rule = matchTuiTitleRule(title, tuiTitleRules)
			if rule then
				print_log(
					string.format(
						"TUI title match: name=%s title=%s",
						rule.name or "?",
						title
					)
				)
				return {
					layout = rule.layout,
					method = rule.method,
				}, "tui:" .. (rule.name or "unknown")
			end
			-- 未命中 TUI：强制默认（ABC），不用 lastUsed，避免从 TUI 带出中文到 shell
			print_log("TUI title no match, use default IME for terminal. title=" .. title)
			return appConfig.inputMethod, "terminal-default"
		end

		if appConfig.shouldSwitchBack then
			return appConfig.inputMethod, "switch-back"
		end

		local lastUsed = lastInputMethod[bundleId]
		if lastUsed then
			return lastUsed, "last-used"
		end
		return appConfig.inputMethod, "default"
	end

	local function applyForWindow(win, reason)
		if not win then
			return
		end
		local bundleId = getAppBundleId(win)
		if not bundleId then
			return
		end
		local config = inputMethodConfig[bundleId]
		if config == nil then
			return
		end

		print_log("----" .. (reason or "apply") .. " App: " .. bundleId .. " START----")

		-- shouldSwitchBack 的 App：进入时记下当前输入法
		if config.shouldSwitchBack and not tuiApps[bundleId] then
			inputMethodBeforeSwitch[bundleId] =
				{ layout = hs.keycodes.currentLayout(), method = hs.keycodes.currentMethod() }
		end

		local target, source = resolveInputMethod(win, config)
		print_log("resolved source=" .. (source or "nil"))
		if target then
			changeInputMethodDelayed(target)
		end
		print_log("----" .. (reason or "apply") .. " App: " .. bundleId .. " END----")
	end

	windowFilter:subscribe(hs.window.filter.windowFocused, function(win)
		applyForWindow(win, "Focused")
	end)

	-- 同一终端窗口内启动/退出 qwen 时，标题变化需要重新判断
	windowFilter:subscribe(hs.window.filter.windowTitleChanged, function(win)
		if not win then
			return
		end
		local focused = hs.window.focusedWindow()
		if not focused or focused:id() ~= win:id() then
			return
		end
		local bundleId = getAppBundleId(win)
		if not bundleId or not tuiApps[bundleId] then
			return
		end
		applyForWindow(win, "TitleChanged")
	end)

	windowFilter:subscribe(hs.window.filter.windowUnfocused, function(win)
		local bundleId = getAppBundleId(win)
		local config = bundleId and inputMethodConfig[bundleId]
		if config == nil then
			return
		end

		-- 终端 TUI 检测 App：不记忆 lastUsed，始终以标题/默认定输入法
		if tuiApps[bundleId] then
			print_log("----Unfocused terminal (tui-aware): " .. bundleId .. "----")
			return
		end

		if config.shouldSwitchBack then
			local oldInputMethod = inputMethodBeforeSwitch[bundleId]
			if oldInputMethod == nil then
				return
			end
			print_log("----Switch Back App: " .. bundleId .. " START----")
			changeInputMethodDelayed(oldInputMethod)
			print_log("----Switch Back App: " .. bundleId .. " END----")
		else
			lastInputMethod[bundleId] =
				{ layout = hs.keycodes.currentLayout(), method = hs.keycodes.currentMethod() }
		end
	end)

	self._subscribed = true
	return self
end

function obj:stop()
	if not self._subscribed then
		return self
	end

	self.wf:unsubscribeAll()
	self._subscribed = false
	return self
end

return obj
