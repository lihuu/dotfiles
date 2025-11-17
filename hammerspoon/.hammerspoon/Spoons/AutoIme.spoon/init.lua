local obj = {
	debug = false,
}

obj.__index = obj

obj.name = "AutoIme"
obj.version = "1.0"

local function now()
	return hs.timer.secondsSinceEpoch()
end

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
--
local function bundleIdToAppName(bundleId)
	local appName = appNameFromBundleId(bundleId)
	print("Find valid AppName: ", appName)
	return appName
end

local getAppBundleId = function(win)
	return win:application():bundleID()
end

-- 设置的时候，layout和method都要设置
local changeInputMethod = function(config)
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

	if configChanged then
		-- 如果有修改，保存到文件中
		local newConfig = { inputMethod = initConfig.inputMethod, bundleIdToNameCache = bundleIdToNameCache }
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
	local inputMethodBeforeSwitch = {}

	windowFilter:subscribe(hs.window.filter.windowFocused, function(win)
		local appName = getAppBundleId(win)
		local config = inputMethodConfig[appName]
		if config == nil then
			return
		end
		print_log("----Current App: " .. appName .. "message START----")
		if config.shouldSwitchBack then
			inputMethodBeforeSwitch[appName] =
				{ layout = hs.keycodes.currentLayout(), method = hs.keycodes.currentMethod() }
		end
		changeInputMethodDelayed(config.inputMethod)
		print_log("----Current App: " .. appName .. "message END----")
	end)

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
			print_log("----Switch Back App: " .. bundleId .. "message START----")
			changeInputMethodDelayed(oldInputMethod)
			print_log("----Switch Back App: " .. bundleId .. "message END----")
		end
	end)

	self._subscribed = true
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
