if not Global.editor_mode then
	return
end

Hooks:PostHook(NavigationManager, "init", "BLENavManagerInit", function(self)
	self._debug = true
	self:set_debug_draw_state(true)
end)

function NavigationManager:update(t, dt)
	if self._debug then
		self._builder:update(t, dt)

		if self._debug_draw_options then
			local options = self._draw_enabled
			local data = self._draw_data
			if data and type(options) == "table" then
				local options = self._debug_draw_options

				if options.blockers then
					self:_draw_nav_blockers()
				end

				-- Added by BLE
				if options.obstacles then
                    self:_draw_nav_obstacles()
                end

				if options.covers then
					self:_draw_covers()
				end

				if options.pos_reservations then
					self:_draw_pos_reservations(t)
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
			nav_blocker_help = Draw:brush(Color(0.1, 0, 1, 0))
		},
		offsets = {
			Vector3(-1, -1),
			Vector3(-1, 1),
			Vector3(1, -1),
			Vector3(1, 1)
		}
	}
end

--TODO look into updating this into the latest (support self._selected_segment_id)
function NavigationManager:set_debug_draw_state(options)
    local temp = {}
	local fast_drawing = true
    if type(options) == "table" then
        for k, option in pairs(options) do
            if type(option) == "table" then
				if k == "fast_drawing" then
					fast_drawing = option.value
				else
                	temp[k] = option.value
				end
            end
        end 

		if table.size(temp) > 0 then
        	options = temp
		else
			options = nil
		end
    end
    if options and (not self._draw_enabled or fast_drawing ~= self._use_fast_drawing) then
		self._use_fast_drawing = fast_drawing
        self:_init_draw_data()
        self._draw_data.start_t = TimerManager:game():time()
    end
    self._draw_enabled = options
end

function NavigationManager:build_complete_clbk(draw_options)
	if self._builder:is_data_complete() then
		self:_create_load_data_from_builder()

		BLE:log("Navigation data Progress: Done!")

		local data = self._load_data

		if data.version < 6 then
			BLE:log("Navigation data Progress: Converting to V6 format")

			data = self:_convert_nav_data_v5_to_v6(self._load_data)
		end

		self:_load_nav_data(data)
		self._quad_field:clear_all()

		local setup_data = {
			quad_grid_size = self._grid_size,
			sector_grid_size = self._sector_grid_size
		}

		self._quad_field:setup(setup_data, callback(self, self, "clbk_navfield"))
		self._quad_field:set_nav_link_filter(NavigationManager.ACCESS_FLAGS)
		-- self:_send_nav_field_to_engine(data) This was absent from BLE, possibly caused issues. If this can be uncommented we can probably remove this function
		self:_resolve_segment_neighbours()
	end

	self:set_debug_draw_state(draw_options)

	if self._build_complete_clbk then
		self._build_complete_clbk()
	end

	BLE.Utils:GetLayer("ai"):reenable_disabled_units()
end


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