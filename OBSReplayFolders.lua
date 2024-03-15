obs = obslua

function script_description()
	return [[Saves replays to sub-folders using the current fullscreen video game executable name.
	
Author: redraskal]]
end

function script_load()
	ffi = require("ffi")
	ffi.cdef[[
		int get_running_fullscreen_game_path(char* buffer, int bufferSize)
	]]
	detect_game = ffi.load(script_path() .. "detect_game.dll")
	print(get_running_game_title())
	obs.obs_frontend_add_event_callback(obs_frontend_callback)
end

function obs_frontend_callback(event)
	if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
		local rootPath = get_replay_buffer_output()
		local targetFolderPath = {}
		local folder = get_running_game_title()
		if folder ~= nil then
			table.insert(targetFolderPath, folder)
		end
		table.insert(targetFolderPath, 'Unsorted')

		local profileName = obs.obs_frontend_get_current_profile()
		if profileName ~= nil then
			table.insert(targetFolderPath, profileName)
		end

		if rootPath ~= nil then
			local finalDir = check_create_dir(rootPath, targetFolderPath)

			move(rootPath, finalDir)
		end
	end
end
function check_create_dir(root, path)
	local dir = get_folder_path(root)
	for i = 1, #path do
		dir = dir .. "/" .. path[i]
		if not obs.os_file_exists(dir) then
			obs.os_mkdir(dir)
		end
	end
	return dir
end
function get_replay_buffer_output()
	local replay_buffer = obs.obs_frontend_get_replay_buffer_output()
	local cd = obs.calldata_create()
	local ph = obs.obs_output_get_proc_handler(replay_buffer)
	obs.proc_handler_call(ph, "get_last_replay", cd)
	local path = obs.calldata_string(cd, "path")
	obs.calldata_destroy(cd)
	obs.obs_output_release(replay_buffer)
	return path
end

function get_running_game_title()
	local path = ffi.new("char[?]", 260)
	local result = detect_game.get_running_fullscreen_game_path(path, 260)
	if result ~= 0 then
		return nil
	end
	result = ffi.string(path)
	local len = #result
	if len == 0 then
		return nil
	end
	local title = ""
	local i = 1
	local max = len - 4
	while i <= max do
		local char = result:sub(i, i)
		if char == "\\" then
			title = ""
		else
			title = title .. char
		end
		i = i + 1
	end
	return firstToUpper(title)
end

function move(oldPath, newDir)
	local file_name = get_file_name(oldPath)
	local newPath = newDir .. file_name
	print("Moving " .. oldPath .. " to " .. newPath)
	obs.os_rename(oldPath, newPath)
end
function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end
function get_folder_path(path)
	local sep = string.match(path, "^.*()/")
	local root = string.sub(path, 1, sep-1)
	return root
end
function get_file_name(path)
	local sep = string.match(path, "^.*()/")
	local name = string.sub(path, sep, string.len(path))
	return name
end