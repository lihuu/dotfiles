-- Module for keyboard remapping
local keyboardRemap = {}

-- Function to get the currently connected keyboards (both USB and Bluetooth)
function keyboardRemap.getConnectedKeyboards()
	local keyboards = {}

	-- Get all connected HID devices (includes both USB and Bluetooth)
	local allDevices = hs.host.interfaceStyle() -- Just to init HID subsystem
	local hidDevices = hs.hid.devices() or {}

	for _, device in ipairs(hidDevices) do
		-- Filter for keyboards
		if device.usagePage == 0x01 and device.usage == 0x06 then -- Generic Desktop / Keyboard usage
			print(
				string.format(
					"Found keyboard device: %s (Vendor: 0x%04x, Product: 0x%04x)",
					device.productName or "Unknown",
					device.vendorID or 0,
					device.productID or 0
				)
			)

			keyboards[#keyboards + 1] = {
				name = device.productName or "Unknown",
				vendorName = device.vendorName or "Unknown",
				vendorID = device.vendorID,
				productID = device.productID,
				transport = device.transport, -- "Bluetooth" or "USB" or other
			}
		end
	end

	return keyboards
end

-- Function to detect if the target keyboard is connected
function keyboardRemap.isTargetKeyboardConnected(targetKeyboard)
	local keyboards = keyboardRemap.getConnectedKeyboards()
	for _, keyboard in ipairs(keyboards) do
		-- For Bluetooth keyboards, sometimes just matching name and productID is more reliable
		-- as vendorID might be reported differently
		if keyboard.name == targetKeyboard.name and keyboard.productID == targetKeyboard.productID then
			if targetKeyboard.transport == nil or keyboard.transport == targetKeyboard.transport then
				return true
			end
		end
	end
	return false
end

-- Create a keyboard event watcher
keyboardRemap.eventTap = nil

-- Configuration for the target keyboard
keyboardRemap.targetKeyboard = {
	name = "YOUR_KEYBOARD_NAME", -- Replace with your keyboard's name
	vendorID = 1234, -- Replace with your keyboard's vendor ID
	productID = 5678, -- Replace with your keyboard's product ID
	transport = "Bluetooth", -- Specifically look for Bluetooth keyboards
}

-- Key mapping configuration
keyboardRemap.keyMappings = {
	[96] = 53, -- ` (grave accent) -> esc (keycode 53)
	[53] = 96, -- esc (keycode 53) -> ` (keycode 96)
}

-- Function to start the remapping
function keyboardRemap.start()
	if keyboardRemap.eventTap and keyboardRemap.eventTap:isEnabled() then
		print("Keyboard remapping already running")
		return
	end

	if keyboardRemap.eventTap then
		keyboardRemap.eventTap:start()
		print("Keyboard remapping started")
		return
	end

	keyboardRemap.eventTap = hs.eventtap.new(
		{ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
		function(event)
			if not keyboardRemap.isTargetKeyboardConnected(keyboardRemap.targetKeyboard) then
				return false
			end

			local keyCode = event:getKeyCode()
			local newKeyCode = keyboardRemap.keyMappings[keyCode]

			if newKeyCode then
				local flags = event:getFlags()
				local isKeyDown = event:getType() == hs.eventtap.event.types.keyDown

				-- Create a new event with the mapped keycode
				local newEvent = hs.eventtap.event.newKeyEvent(flags, newKeyCode, isKeyDown)
				newEvent:post()
				return true -- Prevent the original event
			end

			return false -- Pass through unmapped keys
		end
	)

	keyboardRemap.eventTap:start()
	print("Keyboard remapping initialized and started")
end

-- Function to stop the remapping
function keyboardRemap.stop()
	if keyboardRemap.eventTap then
		keyboardRemap.eventTap:stop()
		print("Keyboard remapping stopped")
	else
		print("No keyboard remapping to stop")
	end
end

-- Helper function to find your keyboard details (run this to get your keyboard info)
function keyboardRemap.findKeyboards()
	local keyboards = keyboardRemap.getConnectedKeyboards()
	if #keyboards == 0 then
		print("No keyboards found. Make sure your keyboard is connected.")
		return
	end

	print("Found " .. #keyboards .. " keyboard devices:")
	for i, keyboard in ipairs(keyboards) do
		print(
			string.format(
				"%d: %s (Vendor: %s, VendorID: %d, ProductID: %d, Transport: %s)",
				i,
				keyboard.name,
				keyboard.vendorName,
				keyboard.vendorID or 0,
				keyboard.productID or 0,
				keyboard.transport or "Unknown"
			)
		)
	end
end

return keyboardRemap
