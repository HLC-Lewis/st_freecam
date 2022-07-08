--		     --
-- Variables --
---------------

local enable_developer_tools = true
local camera = {
	handle = nil,
	active_mode = 1,
	sensitivity = 5.0,

	speed = 10,
	speed_intervals = 2,
	min_speed = 2,
	max_speed = 100,
	boost_factor = 10.0,

	keybinds = {
		toggle = 0x446258B6, -- 0x446258B6 = Page Up
		boost = `INPUT_SPRINT`, -- INPUT_SPRINT, Left Shift
		decrease_speed = 0xDE794E3E, --Q
		increase_speed = 0xCEFD9220, -- E
		forward = `INPUT_MOVE_UP_ONLY`, -- W
		reverse = `INPUT_MOVE_DOWN_ONLY`, -- S
		left = `INPUT_MOVE_LEFT_ONLY`, -- A
		right = `INPUT_MOVE_RIGHT_ONLY`, -- D
		up = `INPUT_JUMP`, -- Space
		down = `INPUT_DUCK`, -- Ctrl
		switch_mode = `INPUT_AIM`,
		mode_action = 0x07CE1E61
	},

	modes = {
		{
			label = "Freecam",
			left_click_action = function(coords)
				return
			end
		},
		{
			label = "Teleport Player",
			left_click_action = function(coords)
				print("HERE")
				SetEntityCoords(PlayerPedId(), coords)
			end
		},
	}

}

-- To be re-enabled
camera.keybinds.enable_controls = { 
	`INPUT_FRONTEND_PAUSE_ALTERNATE`,
	`INPUT_MP_TEXT_CHAT_ALL`,
	camera.keybinds.decrease_speed,
	camera.keybinds.increase_speed
}


--		              --
-- Movement Functions --
------------------------

local function get_relative_location(_location, _rotation, _distance)
	_location = _location or vector3(0,0,0)
	_rotation = _rotation or vector3(0,0,0)
	_distance = _distance or 10.0

	local tZ = math.rad(_rotation.z)
	local tX = math.rad(_rotation.x)

	local absX = math.abs(math.cos(tX))

	local rx = _location.x + (-math.sin(tZ) * absX) * _distance
	local ry = _location.y + (math.cos(tZ) * absX) * _distance
	local rz = _location.z + (math.sin(tX)) * _distance

	return vector3(rx,ry,rz)
end

local function get_camera_movement(location, rotation, frame_time)
	local multiplier = 1.0

	if IsDisabledControlJustPressed(0, camera.keybinds.increase_speed) then
		camera.speed = camera.speed + camera.speed_intervals
		camera.speed = math.min(camera.speed, camera.max_speed)
	elseif IsDisabledControlJustPressed(0, camera.keybinds.decrease_speed) then
		camera.speed = camera.speed - camera.speed_intervals
		camera.speed = math.max(camera.speed, camera.min_speed)
	end

	if IsDisabledControlPressed(0, camera.keybinds.boost) then
		multiplier = camera.boost_factor
	end

	local speed = camera.speed * frame_time * multiplier

	if IsDisabledControlPressed(0, camera.keybinds.right) then
		local camera_rotation = vector3(0,0,rotation.z)
		location = get_relative_location(location, camera_rotation + vector3(0,0,-90), speed)
	elseif IsDisabledControlPressed(0, camera.keybinds.left) then
		local camera_rotation = vector3(0,0,rotation.z)
		location = get_relative_location(location, camera_rotation + vector3(0,0,90), speed)
	end

	if IsDisabledControlPressed(0, camera.keybinds.forward) then
		location = get_relative_location(location, rotation, speed)
	elseif IsDisabledControlPressed(0, camera.keybinds.reverse) then
		location = get_relative_location(location, rotation, -speed)
	end

	if IsDisabledControlPressed(0, camera.keybinds.up) then
		location = location + vector3(0,0,speed)
	elseif IsDisabledControlPressed(0, camera.keybinds.down) then
		location = location + vector3(0,0,-speed)
	end

	return location
end

local function get_mouse_movement()
	local x = GetDisabledControlNormal(0, GetHashKey('INPUT_LOOK_UD'))
	local y = 0
	local z = GetDisabledControlNormal(0, GetHashKey('INPUT_LOOK_LR'))
	return vector3(-x, y, -z) * camera.sensitivity
end

local function render_collision(current_location, new_location)
	if current_location ~= new_location then
		RequestCollisionAtCoord(new_location.x, new_location.y, new_location.z)
		Citizen.InvokeNative(0x387AD749E3B69B70, new_location.x, new_location.y, new_location.x, new_location.y, new_location.z, 50.0, 0) -- LOAD_SCENE_START
		Citizen.InvokeNative(0x5A8B01199C3E79C3) -- LOAD_SCENE_STOP
	end
end


--				  --
-- Invoke Wrapper --
--------------------

local function draw_marker(type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts)
	Citizen.InvokeNative(0x2A32FAA57B937173, type, posX, posY, posZ, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, red, green, blue, alpha, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts)
end

local function draw_raycast(distance, coords, rotation)
	local camera_coord = coords

	local adjusted_rotation = {x = (math.pi / 180) * rotation.x, y = (math.pi / 180) * rotation.y, z = (math.pi / 180) * rotation.z}
	local direction = { x = -math.sin(adjusted_rotation.z) * math.abs(math.cos(adjusted_rotation.x)), y = math.cos(adjusted_rotation.z) * math.abs(math.cos(adjusted_rotation.x)), z = math.sin(adjusted_rotation.x)}

	local destination = 
	{ 
		x = camera_coord.x + direction.x * distance, 
		y = camera_coord.y + direction.y * distance, 
		z = camera_coord.z + direction.z * distance 
	}
	local a, b, c, d, e = GetShapeTestResult(StartShapeTestRay(camera_coord.x, camera_coord.y, camera_coord.z, destination.x, destination.y, destination.z, -1, -1, 1))

	return b, c, e
end

local function draw_text(text, x, y, centred)
	SetTextScale(0.35, 0.35)
	SetTextColor(255, 255, 255, 255)
	SetTextCentre(centred)
	SetTextDropshadow(1, 0, 0, 0, 200)
	SetTextFontForCurrentCommand(0)
	DisplayText(CreateVarString(10, "LITERAL_STRING", text), x, y)
end

local function developer_tools(location, rotation)
	local hit, coords, entity = draw_raycast(1000.0, location, rotation)
	draw_marker(0x50638AB9, coords, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, 255, 100, 100, 100, 0, 0, 2, 0, 0, 0, 0)
	draw_text(('Camera Mode\n%s (Speed: %.3f)\n======\nCoords: %.2f,%.2f,%.2f'):format(camera.modes[camera.active_mode].label, camera.speed, coords.x, coords.y, coords.z), 0.5, 0.01, true)

	if IsDisabledControlPressed(1, camera.keybinds.mode_action) and coords and camera.modes[camera.active_mode].left_click_action then -- Left click action
		camera.modes[camera.active_mode].left_click_action(coords)
	elseif IsDisabledControlJustReleased(0, camera.keybinds.switch_mode) then
		if camera.active_mode >= #camera.modes then
			camera.active_mode = 1
		else
			camera.active_mode = camera.active_mode + 1
		end
	end
end

--		              --
-- Endpoint Functions --
------------------------

local function stop_freecam()
	RenderScriptCams(false, true, 500, true, true)
	SetCamActive(camera.handle, false)
	DetachCam(camera.handle)
	DestroyCam(camera.handle, true)
	camera.handle = nil
end

local function start_freecam()
	camera.handle = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
	SetCamRot(camera.handle, GetGameplayCamRot(2), 2)
	SetCamCoord(camera.handle, GetGameplayCamCoord())
	RenderScriptCams(true, true, 500, true, true)

	while camera.handle do
		Citizen.Wait(0)

		local current_location = GetCamCoord(camera.handle)
		local current_rotation = GetCamRot(camera.handle, 2)

		local new_rotation = current_rotation + get_mouse_movement()
		if current_rotation.x > 85 then
			current_rotation = vector3(85, current_rotation.y, current_rotation.z)
		elseif current_rotation.x < -85 then
			current_rotation = vector3(-85, current_rotation.y, current_rotation.z)
		end

		local new_location = get_camera_movement(current_location, new_rotation, GetFrameTime())
		SetCamCoord(camera.handle, new_location)
		SetCamRot(camera.handle, new_rotation, 2)

		render_collision(current_location, new_location)
		if enable_developer_tools then
			developer_tools(current_location, new_rotation)
		end

		if IsDisabledControlJustReleased(0, camera.keybinds.toggle) then
			stop_freecam()
		end

		DisableFirstPersonCamThisFrame()
		DisableAllControlActions(0)

		for k, v in ipairs(camera.keybinds.enable_controls) do
			EnableControlAction(0, v)
		end
	end
end

local function toggle_camera()
	if camera.handle then
		stop_freecam()
	else
		start_freecam()
	end
end


--		            --
-- Endpoint Options --
----------------------
-- You can comment out any options you don't want

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if IsControlJustReleased(0, camera.keybinds.toggle) then
			toggle_camera()
		end
	end
end)

TriggerEvent('chat:addSuggestion', '/freecam', 'Toggle Freecam')
RegisterCommand('freecam', function(source, args, rawCommand)
	toggle_camera()
end)