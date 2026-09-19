if not Global.editor_mode then
	return
end

function NavFieldBuilder:_create_build_progress_bar(title, num_divistions)
	if not self._progress_dialog then
		local status = BLE.Utils:GetPart("status")
		self._progress_dialog = status:StatusDialog(title, "expanding room", {{name = "Cancel", callback = function()
			self._progress_dialog_cancel = true
			BLE.Utils:GetLayer("ai"):reenable_disabled_units()
		end}})
	end
end

function NavFieldBuilder:_update_progress_bar(percent_complete, title)
	if self._progress_dialog then
		self._progress_dialog:GetItem("Sub"):SetText(title)
	end
end

function NavFieldBuilder:_destroy_progress_bar()
	if self._progress_dialog then
		self._progress_dialog:Destroy()
		self._progress_dialog = nil
	end
end

function NavFieldBuilder:_expand_rooms()
	local progress

	local function can_room_expand(expansion_data)
		if expansion_data then
			for side, seg_list in pairs(expansion_data) do
				if next(seg_list) then
					return true
				end
			end
		end
	end

	local function expand_room(room)
		local expansion_data = room.expansion_segments
		local progress

		for dir_str, exp_dir_data in pairs(expansion_data) do
			for i_segment, segment in pairs(exp_dir_data) do
				if #self._rooms >= self._max_nr_rooms then
					print("!\t\tError. Room # limit exceeded")

					exp_dir_data[i_segment] = nil

					break
				end

				local new_enter_pos = Vector3()
				local size_1 = segment[1][self._perp_dim_str_map[dir_str]] + self._grid_size * 0.5
				local size_2 = room.borders[dir_str] + (self._neg_dir_str_map[dir_str] and -1 or 1) * self._grid_size * 0.5

				mvector3["set_" .. self._perp_dim_str_map[dir_str]](new_enter_pos, size_1)
				mvector3["set_" .. self._dim_str_map[dir_str]](new_enter_pos, size_2)
				mvector3.set_z(new_enter_pos, segment[1].z)

				local gnd_ray = self:_sphere_ray(new_enter_pos + self._up_vec, new_enter_pos + self._down_vec, self._gnd_ray_rad)

				if gnd_ray then
					mvector3.set_z(new_enter_pos, gnd_ray.position.z)
				else
					Application:error("! Error. NavFieldBuilder:_expand_rooms() ground ray failed! segment", segment[1], segment[2])
					Application:draw_cylinder(new_enter_pos + self._up_vec, new_enter_pos + self._down_vec, self._gnd_ray_rad, 1, 0, 0)
					Application:set_pause(true)

					progress = false

					break
				end

				local new_i_room = self:_analyse_room(dir_str, new_enter_pos)
				local new_room = self._rooms[new_i_room]

				progress = true

				managers.navigation:_draw_room(room)

				break
			end

			if progress then
				break
			end
		end

		return progress
	end

	for i_room, room in ipairs(self._rooms) do
		local expansion_segments = room.expansion_segments

		while not progress and can_room_expand(expansion_segments) do
			local text = "expanding room " .. tostring(i_room) .. " of " .. tostring(#self._rooms)

			self:_update_progress_bar(1, text)

			progress = expand_room(room)

			if progress then
				break
			end
		end
	end

	if not progress then
		self._building.stage = 2
		self._building.second_pass = true
	end
end
