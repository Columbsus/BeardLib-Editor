if not Global.editor_mode then
	return
end

Hooks:PostHook(NavigationManager, "init", "BLENavManagerInit", function(self)
	self._debug = true
end)

function NavigationManager:update(t, dt)
	if self._debug then
		self._builder:update(t, dt)

		if self._debug_draw_options then
			local options = self._draw_enabled
			local data = self._draw_data
			if data and type(options) == "table" then
				local options = self._debug_draw_options
				local progress = self._use_fast_drawing and 1 or math.clamp((t - data.start_t) / (data.duration * 0.5), 0, 1)

				if options.quads then
					self:_draw_rooms(progress)
				end

				if options.boundaries then
					self:_draw_room_boundaries(progress)
				end

				if options.doors then
					self:_draw_doors(progress)
				end

				if options.blockers then
					self:_draw_nav_blockers()
				end

				if options.vis_graph then
					self:_draw_visibility_groups(progress)
				end

				if options.coarse_graph then
					self:_draw_coarse_graph()
				end

				if options.nav_links then
					self:_draw_anim_nav_links()
				end

				if options.covers then
					self:_draw_covers()
				end

				if options.pos_rsrv then
					self:_draw_pos_reservations(t)
				end

				-- Added by BLE
				if options.obstacles then
                    self:_draw_nav_obstacles()
                end

				if progress == 1 then
					self._draw_data.start_t = t
				end
			end
		end
	end

	self:_commence_coarce_searches(t)
end

function NavigationManager:_init_draw_data()
	local duration = not self._use_fast_drawing and 5 or nil

	self._draw_data = {
		next_draw_i_coarse = 1,
		next_draw_i_door = 1,
		next_draw_i_room = 1,
		next_draw_i_vis = 1,
		duration = duration,
		brush = {
			door = Draw:brush(Color(0.1, 0, 1, 1), duration),
			room_diag = Draw:brush(Color(1, 0.5, 0.5, 0), duration),
			room_diag_disabled = Draw:brush(Color(0.5, 0.7, 0, 0), duration),
			room_diag_obstructed = Draw:brush(Color(0.5, 0.5, 0, 0.5), duration),
			room_border = Draw:brush(Color(0.5, 0.3, 0.3, 0.8), duration),
			coarse_graph = Draw:brush(Color(0.2, 0.05, 0.2, 0.9)),
			vis_graph_rooms = Draw:brush(Color(0.6, 0.5, 0.2, 0.9), duration),
			vis_graph_node = Draw:brush(Color(1, 0.6, 0, 0.9), duration),
			vis_graph_links = Draw:brush(Color(0.2, 0.8, 0.1, 0.6), duration),
			pos_rsvr_unit = Draw:brush(Color(1, 1, 0, 0)),
			pos_rsvr = Draw:brush(Color(0.3, 1, 1, 0)),
			nav_blocker = Draw:brush(Color(0.1, 1, 0, 0)),
			nav_blocker_help = Draw:brush(Color(0.1, 0, 1, 0)),
			room_fill = Draw:brush(Color(0.3, 0.3, 0.3, 0.8), duration),
			room_fill_disabled = Draw:brush(Color(0.3, 0.8, 0.3, 0.3), duration),
			room_fill_obstructed = Draw:brush(Color(0.3, 0.8, 0, 0.8), duration),
		},
		offsets = {
			Vector3(-1, -1),
			Vector3(-1, 1),
			Vector3(1, -1),
			Vector3(1, 1)
		}
	}
end

function NavigationManager:set_debug_draw_state(options)
	self._debug_draw_options = options

	if options then
		options.selected_segment = nil

		if self._selected_segment_id  then
			for _, segment in pairs(self._nav_segments) do
				if segment.id == self._selected_segment_id then
					options.selected_segment = Idstring(segment.unique_id)

					break
				end
			end
		end

		if options.fast_drawing ~= self._use_fast_drawing then
			self._use_fast_drawing = options.fast_drawing
			self:_init_draw_data()
			self._draw_data.start_t = TimerManager:game():time()
		end
	end

	self._draw_enabled = options
	-- self._quad_field:set_draw_state(options) If this is added to release uncomment and remove the draw functions below
end

Hooks:PreHook(NavigationManager, "build_complete_clbk", "BLENavManagerPreBuildCompleteClbk", function(self)
	BLE:log("Navigation data Progress: Done!")
end)

Hooks:PostHook(NavigationManager, "build_complete_clbk", "BLENavManagerPostBuildCompleteClbk", function(self)
	BLE.Utils:GetLayer("ai"):reenable_disabled_units()
end)

local search = NavigationManager.search_coarse
function NavigationManager:search_coarse( ... )
    if self._builder._building then
        return
    end
    return search(self, ...)
end

function NavigationManager:_safe_remove_unit(unit) end
function NavigationManager:remove_AI_blocker_units() end

function NavigationManager:_draw_nav_blockers()
	if self._builder._helper_blockers then
		local nav_segments = self._builder._nav_segments
		local registered_blockers = self._builder._helper_blockers
		local all_blockers = World:find_units_quick("all", 15)

		for _, blocker_unit in ipairs(all_blockers) do
			local id = blocker_unit:unit_data().unit_id

			if registered_blockers[id] then
				local draw_pos = blocker_unit:oobb() and blocker_unit:oobb():center() or blocker_unit:position()
				local nav_segment = registered_blockers[id]

				if nav_segments and nav_segments[nav_segment] and self._selected_segment == nav_segment then
					Application:draw(blocker_unit, 1, 0, 0)
					Application:draw_cylinder(draw_pos, nav_segments[nav_segment].pos, 2, 0.8, 0.1, 0)
				end
			end
		end
	end
end

function NavigationManager:_draw_nav_obstacles()
	if self._obstacles then
		local draw = self._draw_data
		local brushes = draw and draw.brush
		for id, obstacle_data in ipairs(self._obstacles) do
			local unit = obstacle_data.unit
			if alive(unit) then
				Application:draw(unit, 1, 0, 1)
				brushes.obstacles:unit(unit)
			end
		end
	end
end

Hooks:PreHook(NavigationManager, "set_load_data", "BLENavManagerPreSetLoadData", function(self, data)
	self._load_data = deep_clone(data)
	self._builder:load(self._load_data)
end)



-- Readded since they were removed from the game --


function NavigationManager:_draw_rooms(progress)
	local selected_seg = self._selected_segment
	local room_mask

	if selected_seg and self._nav_segments[selected_seg] and next(self._nav_segments[selected_seg].vis_groups) then
		room_mask = {}

		for _, i_vis_group in ipairs(self._nav_segments[selected_seg].vis_groups) do
			local vis_group_rooms = self._builder._visibility_groups[i_vis_group].rooms

			for i_room, _ in pairs(vis_group_rooms) do
				room_mask[i_room] = true
			end
		end
	end

	local data = self._draw_data
	local rooms = self._builder._rooms
	local nr_rooms = #rooms
	local i_room = data.next_draw_i_room
	local wanted_index = math.clamp(math.ceil(nr_rooms * progress), 1, nr_rooms)

	while i_room <= wanted_index and i_room <= nr_rooms do
		local room = rooms[i_room]

		if not room_mask or room_mask[i_room] then
			self:_draw_room(room)
		end

		i_room = i_room + 1
	end

	if progress == 1 then
		data.next_draw_i_room = 1
	else
		data.next_draw_i_room = i_room
	end
end

function NavigationManager:_draw_room_boundaries(progress)
	local rooms = self._builder._rooms
	local nav_rooms = {}
	local selected_seg = self._selected_segment
	local room_mask

	if selected_seg and self._nav_segments[selected_seg] and next(self._nav_segments[selected_seg].vis_groups) then
		room_mask = {}

		for _, i_vis_group in ipairs(self._nav_segments[selected_seg].vis_groups) do
			local vis_group_rooms = self._builder._visibility_groups[i_vis_group].rooms

			for i_room, _ in pairs(vis_group_rooms) do
				room_mask[i_room] = true
			end
		end
	end

	for segment_i, current_segment in pairs(self._nav_segments) do
		local nav_room = {}

		for _, i_vis_group in ipairs(current_segment.vis_groups) do
			local vis_group_rooms = self._builder._visibility_groups[i_vis_group].rooms

			for room_idx, _ in pairs(vis_group_rooms) do
				table.insert(nav_room, rooms[room_idx])
			end
		end

		table.insert(nav_rooms, nav_room)
	end

	local room_count = #nav_rooms
	local draw_i = math.clamp(math.ceil(room_count * progress), 1, room_count - 1)

	for i = draw_i, draw_i + 1 do
		self:_draw_room_boundary(i, nav_rooms[i])
	end
end

function NavigationManager:_draw_room_boundary(index, nav_room_list)
	if not nav_room_list then
		return
	end

	self._hulls = self._hulls or {}

	if not self._hulls[index] then
		print("[NavigationManager] generating boundary hull for room: ", index)

		local room_hull = self:_compute_room_hull(nav_room_list)
		local r, g, b = CoreMath.hsv_to_rgb(math.random() * 255, 1, 1)

		self._hulls[index] = {
			hull = room_hull,
			brush = Draw:brush(Color(1, r, g, b), 10)
		}
	end

	local draw = self._draw_data
	local brushes = draw and draw.brush
	local hull_data = self._hulls[index]
	local hull_points = hull_data.hull:hull()

	for i = 1, #hull_points - 1 do
		if hull_points[i] and hull_points[i + 1] then
			hull_data.brush:line(hull_points[i], hull_points[i + 1], 5)
		end
	end

	hull_data.brush:line(hull_points[1], hull_points[#hull_points], 5)
end

function NavigationManager:_compute_room_hull(nav_room_list)
	local point_cloud = {}
	local draw = self._draw_data
	local offsets = draw and draw.offsets

	for i, room in ipairs(nav_room_list) do
		local borders = room.borders
		local height = room.height

		table.insert(point_cloud, Vector3(borders.x_pos + offsets[1].x, borders.y_pos + offsets[1].y, height.xp_yp))
		table.insert(point_cloud, Vector3(borders.x_pos + offsets[2].x, borders.y_neg + offsets[2].y, height.xp_yn))
		table.insert(point_cloud, Vector3(borders.x_neg + offsets[3].x, borders.y_pos + offsets[3].y, height.xn_yp))
		table.insert(point_cloud, Vector3(borders.x_neg + offsets[4].x, borders.y_neg + offsets[4].y, height.xn_yn))
	end

	local hull = Quickhull:new(point_cloud, #point_cloud)

	hull:compute()

	return hull
end

function NavigationManager:_draw_nav_blockers()
	if self._builder._helper_blockers then
		local mvec3_set = mvector3.set
		local mvec3_rot = mvector3.rotate_with
		local mvec3_add = mvector3.add
		local obj_name = Idstring("help_blocker")
		local nav_segments = self._builder._nav_segments
		local registered_blockers = self._builder._helper_blockers
		local all_blockers = World:find_units_quick("all", 15)
		local help_blocker_object

		for _, blocker_unit in ipairs(all_blockers) do
			local id = blocker_unit:unit_data().unit_id

			if registered_blockers[id] then
				help_blocker_object = blocker_unit:get_object(obj_name)

				if help_blocker_object then
					local draw_pos = help_blocker_object:position()
					local nav_segment = registered_blockers[id]

					if nav_segments and nav_segments[nav_segment] and self._selected_segment == nav_segment then
						Application:draw_sphere(draw_pos, 30, 0, 0, 1)
						Application:draw_cylinder(draw_pos, nav_segments[nav_segment].pos, 2, 0, 0.3, 0.6)
					end
				else
					local draw_pos = blocker_unit:position()
					local nav_segment = registered_blockers[id]

					if nav_segments and nav_segments[nav_segment] and self._selected_segment == nav_segment then
						Application:draw_sphere(draw_pos, 30, 1, 0, 0)
						Application:draw_cylinder(draw_pos, nav_segments[nav_segment].pos, 2, 0.8, 0.1, 0)
					end
				end
			end
		end
	end
end

function NavigationManager:_draw_room(room, instant)
	local draw, brushes, offsets

	if instant then
		offsets = {
			Vector3(-1, -1),
			Vector3(-1, 1),
			Vector3(1, -1),
			Vector3(1, 1)
		}
	else
		draw = self._draw_data
		brushes = draw and draw.brush
		offsets = draw and draw.offsets
	end

	local dir_vec_map = self._dir_str_to_vec
	local borders = room.borders
	local height = room.height
	local my_center = self._builder:_calculate_room_center(room)
	local xp_yp_draw = Vector3(borders.x_pos + offsets[1].x, borders.y_pos + offsets[1].y, height.xp_yp)
	local xp_yn_draw = Vector3(borders.x_pos + offsets[2].x, borders.y_neg + offsets[2].y, height.xp_yn)
	local xn_yp_draw = Vector3(borders.x_neg + offsets[3].x, borders.y_pos + offsets[3].y, height.xn_yp)
	local xn_yn_draw = Vector3(borders.x_neg + offsets[4].x, borders.y_neg + offsets[4].y, height.xn_yn)

	if instant then
		Application:draw_line(xp_yp_draw, xp_yn_draw, 0.5, 0.5, 0.5)
		Application:draw_line(xn_yp_draw, xn_yn_draw, 0.5, 0.5, 0.5)
		Application:draw_line(xp_yp_draw, xn_yp_draw, 0.5, 0.5, 0.5)
		Application:draw_line(xp_yn_draw, xn_yn_draw, 0.5, 0.5, 0.5)
		Application:draw_line(xp_yp_draw, xn_yn_draw, 0.5, 0.5, 0)
		Application:draw_line(xn_yp_draw, xp_yn_draw, 0.5, 0.5, 0)
	else
		local brush = brushes.room_border

		brush:line(xp_yp_draw, xp_yn_draw)
		brush:line(xn_yp_draw, xn_yn_draw)
		brush:line(xp_yp_draw, xn_yp_draw)
		brush:line(xp_yn_draw, xn_yn_draw)

		local nsi = room.vis_group and self:get_nav_seg_from_i_vis_group(room.vis_group)

		local ns = nsi and self._nav_segments[nsi]

		if ns and ns.disabled then
			brush = brushes.room_diag_disabled
		else
			brush = brushes.room_diag
		end

		if room.obstructed then
			brush = brushes.room_diag_obstructed
		end

		brush:line(xp_yp_draw, xn_yn_draw)
		brush:line(xn_yp_draw, xp_yn_draw)

		if ns and ns.disabled then
			brushes.room_fill_disabled:quad(xp_yp_draw, xp_yn_draw, xn_yn_draw, xn_yp_draw)
		elseif room.obstructed then
			brushes.room_fill_obstructed:quad(xp_yp_draw, xp_yn_draw, xn_yn_draw, xn_yp_draw)
		else
			brushes.room_fill:quad(xp_yp_draw, xp_yn_draw, xn_yn_draw, xn_yp_draw)
		end
	end

	local expansion = room.expansion

	if expansion then
		for dir_str, side_expansion in pairs(expansion) do
			for obstacle_type, obstacle_segments in pairs(side_expansion) do
				local color, rad

				if obstacle_type == "walls" then
					rad = 3
					color = Vector3(1, 0, 0)
				elseif obstacle_type == "spaces" then
					rad = 2.2
					color = Vector3(0, 1, 0)
				elseif obstacle_type == "stairs" then
					rad = 1, 8
					color = Vector3(1, 0.4, 0)
				elseif obstacle_type == "cliffs" then
					rad = 1, 6
					color = Vector3(0.2, 0.1, 0)
				else
					rad = 1
					color = Vector3(0.5, 0.5, 0.5)
				end

				for i_obs_seg, obstacle_segment in pairs(obstacle_segments) do
					Application:draw_cone(obstacle_segment[1], obstacle_segment[2], rad, color.x, color.y, color.z)
				end
			end
		end
	end

	if room.expansion_segments then
		for dir_str, seg_list in pairs(room.expansion_segments) do
			local color, rad

			if self._builder._neg_dir_str_map[dir_str] then
				rad = 3.5
				color = Vector3(0.5, 0.5, 0.5)
			else
				rad = 4
				color = Vector3(1, 1, 1)
			end

			for i_seg, seg in pairs(seg_list) do
				Application:draw_cylinder(seg[1], seg[2], rad, color.x, color.y, color.z)
			end
		end
	end

	if room.neighbours then
		for side, neighbour_list in pairs(room.neighbours) do
			local color, rad

			if self._builder._neg_dir_str_map[side] then
				rad = 3.2
				color = Vector3(0, 0.5, 0.5)
			else
				rad = 4
				color = Vector3(0, 1, 1)
			end

			for i_neighbour, neighbour_data in pairs(neighbour_list) do
				Application:draw_cylinder(neighbour_data.overlap[1], neighbour_data.overlap[2], rad, color.x, color.y, color.z)
				Application:draw_line(my_center, (neighbour_data.overlap[1] + neighbour_data.overlap[2]) * 0.5, color.x, color.y, color.z)
			end
		end
	end
end

function NavigationManager:_draw_doors(progress)
	local selected_seg = self._selected_segment
	local room_mask

	if selected_seg and self._nav_segments[selected_seg] and next(self._nav_segments[selected_seg].vis_groups) then
		room_mask = {}

		for _, i_vis_group in ipairs(self._nav_segments[selected_seg].vis_groups) do
			local vis_group_rooms = self._builder._visibility_groups[i_vis_group].rooms

			for i_room, _ in pairs(vis_group_rooms) do
				room_mask[i_room] = true
			end
		end
	end

	local data = self._draw_data
	local doors = self._builder._room_doors -- Changed
	local nr_doors = #doors
	local i_door = data.next_draw_i_door
	local wanted_index = math.clamp(math.ceil(nr_doors * progress), 1, nr_doors)

	while i_door <= wanted_index and i_door <= nr_doors do
		local door = doors[i_door]

		if not room_mask or room_mask[door.rooms[1]] or room_mask[door.rooms[2]] then
			self:_draw_door(door)
		end

		i_door = i_door + 1
	end

	if progress == 1 then
		data.next_draw_i_door = 1
	else
		data.next_draw_i_door = i_door
	end
end

function NavigationManager:_draw_door(door)
	local brush = self._draw_data.brush.door

	brush:cylinder(door.pos, door.pos1, 2)
end

function NavigationManager:_draw_anim_nav_links()
	if not self._nav_links then
		return
	end

	local brush = Draw:brush(Color(0.3, 0.8, 0.2, 0.1))
	local brush_obstructed = Draw:brush(Color(0.6, 0.2, 0.05, 0.025))

	for element, _ in pairs(self._nav_links) do
		local start_pos = element:value("position")

		;(element:nav_link():is_obstructed() and brush_obstructed or brush):cone(element:nav_link_end_pos(), start_pos, 20)
	end
end

function NavigationManager:_draw_covers()
	local reserved = self.COVER_RESERVED
	local cone_height = Vector3(0, 0, 80)
	local arrow_height = Vector3(0, 0, 1)

	for i_cover, cover in ipairs(self._covers) do
		local draw_pos = cover[1]
		local tracker = cover[3]

		if tracker:lost() then
			Application:draw_cone(draw_pos, draw_pos + cone_height, 30, 1, 0, 0)

			local placed_pos = tracker:position()

			Application:draw_sphere(placed_pos, 20, 1, 0, 0)
			Application:draw_line(placed_pos, draw_pos, 1, 0, 0)
		else
			Application:draw_cone(draw_pos, draw_pos + cone_height, 30, 0, 1, 0)
		end

		Application:draw_rotation(draw_pos + arrow_height, Rotation(cover[2], math.UP))

		if cover[reserved] then
			Application:draw_sphere(draw_pos, 18, 0, 0, 0)
		end
	end
end

function NavigationManager:_draw_geographic_segments()
	if not next(self._geog_segments) then
		return
	end

	local seg_rad = 3
	local seg_color = Vector3(0.8, 0.2, 0.1)
	local room_rad = 2
	local room_color = Vector3(1, 1, 1)

	for i_seg, segment in pairs(self._geog_segments) do
		local borders = self:_calculate_geographic_segment_borders(i_seg)
		local height = 300
		local top_right = Vector3(borders.x_pos, borders.y_pos, height)
		local top_left = Vector3(borders.x_neg, borders.y_pos, height)
		local bottom_right = Vector3(borders.x_pos, borders.y_neg, height)
		local bottom_left = Vector3(borders.x_neg, borders.y_neg, height)

		Application:draw_cylinder(top_right, top_left, seg_rad, seg_color.x, seg_color.y, seg_color.z)
		Application:draw_cylinder(top_left, bottom_left, seg_rad, seg_color.x, seg_color.y, seg_color.z)
		Application:draw_cylinder(bottom_left, bottom_right, seg_rad, seg_color.x, seg_color.y, seg_color.z)
		Application:draw_cylinder(bottom_right, top_right, seg_rad, seg_color.x, seg_color.y, seg_color.z)
	end
end

function NavigationManager:_draw_visibility_groups(progress)
	local selected_seg = self._selected_segment

	if not selected_seg or not self._nav_segments[selected_seg] then
		return
	end

	local selected_vis_groups = self._nav_segments[selected_seg].vis_groups
	local nr_vis_groups = #selected_vis_groups

	if nr_vis_groups == 0 then
		return
	end

	local all_vis_groups = self._builder._visibility_groups
	local all_rooms = self._builder._rooms
	local builder = self._builder
	local draw_data = self._draw_data
	local brush_node = draw_data.brush.vis_graph_node
	local brush_rooms = draw_data.brush.vis_graph_rooms
	local brush_links = draw_data.brush.vis_graph_links
	local i_vis_group = draw_data.next_draw_i_vis
	local wanted_index = math.clamp(math.floor(nr_vis_groups * progress), 0, nr_vis_groups)

	while wanted_index > 0 and i_vis_group <= wanted_index do
		local vis_group = all_vis_groups[selected_vis_groups[i_vis_group]]

		brush_node:sphere(vis_group.pos, 30)

		for i_vis_room, _ in pairs(vis_group.rooms) do
			local room_c = builder:_calculate_room_center(all_rooms[i_vis_room])

			brush_rooms:line(vis_group.pos, room_c)
		end

		for i_neigh_group, _ in pairs(vis_group.vis_groups) do
			local neigh_group = all_vis_groups[i_neigh_group]

			brush_links:cylinder(vis_group.pos, neigh_group.pos, 2)

			if neigh_group.seg ~= selected_seg then
				brush_links:sphere(neigh_group.pos, 20)
			end
		end

		i_vis_group = i_vis_group + 1
	end

	if progress == 1 then
		draw_data.next_draw_i_vis = 1
	else
		draw_data.next_draw_i_vis = i_vis_group
	end
end

function NavigationManager:_draw_coarse_graph()
	local all_nav_segments = self._nav_segments
	local all_doors = self._room_doors
	local all_vis_groups = self._builder._visibility_groups
	local cone_height = Vector3(0, 0, 50)

	for seg_id, seg_data in pairs(all_nav_segments) do
		local neighbours = seg_data.neighbours

		for neigh_i_seg, door_list in pairs(neighbours) do
			local pos = all_nav_segments[neigh_i_seg].pos
			local color = {
				1,
				1,
				0
			}

			if all_nav_segments[neigh_i_seg].disabled then
				color = {
					1,
					0,
					0
				}
			elseif seg_data.blocked_group or all_nav_segments[neigh_i_seg].blocked_group then
				color = {
					1,
					0.5,
					0
				}

				self._draw_data.brush.blocked:center_text(pos + cone_height * 2, all_nav_segments[neigh_i_seg].blocked_group)
			end

			Application:draw_cone(pos, seg_data.pos, 12, unpack(color))
			Application:draw_cone(pos, pos + cone_height, 40, unpack(color))
		end
	end
end

function NavigationManager:_draw_pos_reservations(t)
	local to_remove = {}

	for key, res in pairs(self._pos_reservations) do
		local entry = res[1]

		if entry.expire_t and t > entry.expire_t then
			table.insert(to_remove, key)
		end

		if not entry.expire_t then
			Application:draw_sphere(entry.position, entry.radius, 0, 0, 0)

			if res.unit then
				if alive(res.unit) then
					Application:draw_cylinder(entry.position, res.unit:movement():m_pos(), 3, 0, 0, 0)
				else
					debug_pause("[NavigationManager:_draw_pos_reservations] dead unit. reserved from:", res.stack, "unit name:", res.u_name)
					Application:draw_sphere(entry.position, entry.radius + 5, 1, 0, 1)
				end
			end
		else
			Application:draw_sphere(entry.position, entry.radius, 0.3, 0.3, 0.3)
		end
	end

	for _, key in ipairs(to_remove) do
		self._pos_reservations[key] = nil
	end
end

function NavigationManager:get_nav_seg_from_i_room( i_room )
	return self._builder._visibility_groups[ self._builder._rooms[ i_room ].vis_group ].seg
end

function NavigationManager:get_nav_seg_from_i_vis_group( i_group )
	return self._builder._visibility_groups[ i_group ].seg
end
