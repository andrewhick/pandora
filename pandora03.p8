pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- # pandora
-- cat explore. socky find.

-- to export:
-- fn + f7 to capture label image
-- save pandora.p8.png
-- export pandora.html

function _init()
	-- global variables:
	game_version = "03"
	level = 16
	last_level = 16
	debug_mode = false -- shows debug info and unfogs each level
	debug_text = "debug mode"
	win = false
	lose = false
	in_game = false -- determines whether a level is in progress
	title_active = true
	levelling_up = false
	t = 0 -- game time in frames
	unfog_frames = 3 -- how fast the unfogging happens
	caption_frames = 3 -- how fast the captions move
	cat_frames = 1 -- number of frames between each cat move animation
	menu_items = 4
	medal_text = {"gold", "silver", "bronze", "none"}
	medal_sprite = {12, 13, 14, 15}
	anim_frame = 0 -- allows sprites to animate
	offset = 0 -- screen offset for shaking
	move_step = 9 -- variable governing move animation
	moving = false
	play_music = false
	play_sounds = true
	ice = false
	dx = 0
	dy = 0
	socky_bonus = 10 -- bonus awarded on collecting socky, in addition to the moves reimbursed for the detour. revisit moves_data if changing this
	moves = 9999
	mab_small_x = 16
	game_get_data()
	reset_palette()
	title_show()
end

function _update()
	-- input and move
	t += 1
	if moves <= 0 then game_lose() end
	if win and mab_small_x < 16 then -- animate mab at end
		debug_text = "do retreat step"
		mab_retreat_step()
	end

	if btnp() != 0 or sliding then
		-- a button has been pressed
		if title_active then
			title_active = false
			level_reset() -- start current level
		elseif in_game then
			if not moving then
				move_process()
			end
		elseif menu_active then
			menu_process_input()
		elseif levelling_up then
			level_end_process_option()
		elseif lose then
			lose = false
			level_restart()
		elseif win == false and lose == false then -- start new level
			level_reset()
		else
			_init()
			return
		end
	end

	-- check if socky was recently obtained and unfog screen 1 step
	if unfog_active then unfog_step() end
	if caption_active then caption_step() end
	if in_game then
		move_catch_up()
		if levelling_up and move_step >= 5 then level_up() end
		if mab_hit and move_step >= 5 then game_lose() end
	end
end

function _draw()
	if not in_game and not menu_active then return end

	shake_screen()
	draw_everything()
end

-- conventions: map is zero-based, arrays are 1-based.

-- to do next

-- animate some background cells eg torch, water
-- make pandora blink
-- create more levels
-- make mab

function ar(a)
	-- convert 0-based pixel to 1-based array position.
	-- 0 maps to 1, 8 maps to 2
	return flr(a/8) + 1
end

function px(a)
	-- convert 1-based array position to 0-based pixel.
	-- 1 maps to 0, 2 maps to 8
	return (a-1) * 8
end

function reset_palette()
	pal() -- reset palette
	palt(13, true) -- set colour 13 transparent
	palt(0, false) -- and black not
end

function title_show()
	rectfill(0, 0, 127, 127, 1)
	local title_colour = {10, 0, 5, 6, 7, 15, 14, 8, 9, 10, 11, 3}
	for i=1,12 do
		pal(10, title_colour[13-i]) -- swap yellow to different colours
		map(0, 32, 8, 128-i*8, 14, 4) -- write pandora
	end
	reset_palette()
	spr(1, 64, 24) -- cat
	rectfill(34, 78, 94, 106, 0)
	rect(33, 77, 93, 105, 14)
	print("⬆️⬇️⬅️➡️  move", 36, 80, 15)
	spr(193, 36, 88) -- o mobile
	spr(196, 44, 88) -- /
	spr(194, 52, 88) -- z keyboard
	spr(192, 36, 96) -- x mobile
	spr(196, 44, 96) -- /
	spr(195, 52, 96) -- x keyboard
	print("ok/wait", 64, 88, 14)
	print("menu", 76, 96, 8)
	print(game_version, 120, 120, 6)
end

function level_reset()
	debug_text = "reset level"
	x = start_pos[level][1]  -- current position in pixels from 0
	y = start_pos[level][2]
	dx = 0 -- in case character was part way through move
	dy = 0
	moves = moves_data[level][3]
	unfog_active = false
	socky_collect = false
	caption_active = false
	title_active = false
	menu_active = false
	levelling_up = false
	ice = ice_data[level]
	sliding = false
	socky_add = 0
	move_step = 9 -- to avoid cat sliding back across screen
	anim_frame = 0 -- so that each level starts the same way
	level_period = #obs_data[level]
	dir = "r" -- current direction
	unfog_reset()
	obstacle_update()
	switch_reset()
	unfog_circle()
	draw_everything()
	if level == 16 then level_16_reset() end
	if debug_mode then unfog_start() end
	in_game = true
	caption_show("level "..tostr(level), 3, 11, 10)
	sfx(-1) -- stop playing sound
	if play_music then music(1) end -- main theme
end

function level_16_reset()
	mab_reset()
	mabx = 0
	maby = 0
	mab_active = false
end

function level_restart()
	moves = moves_data[level][3] -- reset back to allowed number of moves
	level_reset()
end

function level_up()
	in_game = false
	sliding = false
	moving = false
	level_end_menu()
end

function level_end_menu()
	if level == 16 then
		rectfill(56, 0, 63, 7, 12) -- hide mab socky
		anim_frame = 0
		draw_player()
		spr(253, 64, 0)
	end	
	draw_menu_outline()
	local medal_this_try = 4
	-- award medal for this attempt: 1=gold 2=silver 3=bronze 4=none
	if moves >= moves_data[level][4] then medal_this_try = 1
	elseif moves >= moves_data[level][5] then medal_this_try = 2
	elseif moves >= moves_data[level][6] then medal_this_try = 3
	end

	print("pandora got through level "..tostr(level).."!", 8, 24, 7)
	print("medal:    "..medal_text[medal_this_try], 8, 40, 7)
	spr(medal_sprite[medal_this_try], 36, 40)
	print("continue", 32, 56, 11)
	print("retry level", 32, 64, 12)

	if medal_this_try < best_medal[level] then
		best_medal[level] = medal_this_try
	end
	draw_progress()
	level_end_option = 1 -- default is continue to next level
	spr(24, 16, 48 + level_end_option * 8)
end

function level_end_process_option()
	if btnp(⬆️) or btnp(⬇️) then
		level_end_option = 3 - level_end_option
		rectfill(16, 48, 23, 71, 0)
		spr(24, 16, 48 + level_end_option * 8)
	elseif btnp(4) then level_end_choose() end
end

function level_end_choose()
	if level_end_option == 1 then -- continue to next level
		if level != last_level then
			level += 1
			level_reset()
		else
			levelling_up = false
			game_win()
		end
	else
		level_restart()
	end
end

function game_win()
	rectfill(0, 16, 127, 79, 0)
	local perfect = true
	for k in all(best_medal) do
		-- if any medal is not gold then it's not perfect
		if k != 1 then perfect = false break end
	end
	perfect = true -- temp for debugging
	if perfect then
		for i=0, 15 do -- draw rainbows
			spr(208, i*8, 8)
			spr(208, i*8, 112)
		end
		spr(255, 96, 24)
		pal(10, 11)
		map(0, 40, 0, 32, 16, 4) -- write perfect in green
	else
		pal(10, 9)
		map(0, 36, 4, 32, 15, 4) -- write you win in orange
	end
	reset_palette()
	win = true
	mab_retreat_start()
end

function game_lose()
	local lose_text = "you lose :( - press any key"
	local lose_colour = 2
	in_game = false
	if mab_hit then
		lose_text = "mab got you. press any key"
		lose_colour = 8
		mab_hit = false
	end
	rectfill(0, 40, 127, 79, lose_colour)
	spr(1, 8, 64, 1, 1, false, true)
	print3d(lose_text, 8, 48, 10, 0)
	lose = true
end

-- ## movement functions

-- flag key
-- 0 = all wall
-- 1 = up wall (not used yet)
-- 2 = down wall (not used yet)
-- 3 = left wall (not used yet)
-- 4 = right wall (not used yet)
-- 5 = danger
-- 6 = ice
-- 7 = unassigned

-- ## player move functions

function move_process()
	newx = x
	newy = y
	if not sliding then anim_frame += 1 end
	obstacle_update()
	if btnp(5) then menu_open()
	elseif sliding then move_attempt(dir)
	elseif btnp(⬆️) then move_attempt("u")
	elseif btnp(⬇️) then move_attempt("d")
	elseif btnp(⬅️) then move_attempt("l")
	elseif btnp(➡️) then move_attempt("r")
	end
end

function move_attempt(a)
	just_moved = false
	dir = a
	if a == "u" then newy = y-8
	elseif a == "d" then newy = y+8
	elseif a == "l" then newx = x-8
	elseif a == "r" then newx = x+8
	end

	if move_possible() then
		move_do()
		check_current_cell()
	else  -- hit a wall
		if play_sounds then sfx(47) end
		sliding = false
	end
end

function move_do()
	-- start a single move
	-- count down moves once if not sliding
	-- update new position immediately but don't draw yet
	-- start animation 4210
	if not sliding then move_sound() end
	moving = true
	dx = 0 -- temporary x offset
	dy = 0 -- temporary y offset
	move_step = 1
	move_time = t
	prevx = x
	prevy = y
	x = newx
	y = newy
	just_moved = true
	if (ice or check_flag(x, y, 6)) and not sliding then
		-- start slide if ice or new cell is icy
		sliding = true
		moves -= 1 -- only reduce moves once when on ice
		mab_step()
	elseif sliding and not ice and not check_flag (x, y, 6) then
		-- stop sliding
		sliding = false
	elseif not sliding then
		moves -= 1
		mab_step()
	end
	unfog_circle()
end

function move_sound()
	if not play_sounds then return end
	if dir == "u" then sfx(41)
	elseif dir == "d" then sfx(42)
	elseif dir == "l" then sfx(43)
	elseif dir == "r" then sfx(44)
	end
end

function move_catch_up()
	-- adds a temp offset to character based on time
	if move_step >= 5 then
		moving = false -- have finished move cycle
		return
	end
	-- move_pixels shows at each move_step, how many pixels close to the new position the player should be:
	if not sliding then move_pixels = {4, 2, 1, 0}
	else move_pixels = {6, 4, 2, 0} end -- more linear movement on ice.
	if (t - move_time) % cat_frames == 0 then
		dx = move_pixels[move_step] * (prevx-x) / 8
		dy = move_pixels[move_step] * (prevy-y) / 8
		move_step += 1
	end
end

function move_possible()
	if (newx<0 or newx>120 or newy<0 or newy>120) then return false end
	-- return false if 0th flag is set for target cell:
	if check_flag(newx, newy, 0) then return false end -- it's a wall
	return true
end

function check_flag(a, b, flag)
	-- checks if flag 0-7 is set for map at pixel coordinates a, b
	return fget(mget(map_data_pos[level][1] + a/8, map_data_pos[level][2] + b/8), flag)
end

function check_current_cell()
	-- checks new cell for anything interesting
	-- check if you've reached goal
	if (level == 16 and x == 56 and y == 0) -- get mab socky
	or (x == 120 and y == goal_height[level] * 8) then -- get goal
		levelling_up = true
		music(-1)
		if play_sounds then sfx(48) end -- level end tune
		return
	end
	-- check if you've reached socky
	if x/8 == socky_pos[level][1] and y/8 == socky_pos[level][2] and socky_collect == false then
		socky_collect = true
		if play_sounds then sfx(45) end
		-- reimburse extra moves it would have cost to get socky:
		socky_add = max(moves_data[level][2] - moves_data[level][1] + 10, 0) -- extra temporary socky boost of 10
		moves += socky_add
		unfog_start()
	end
	-- check for moving obstacles
	if obstacles[ar(y)][ar(x)] > 0 then obstacle_hit() end
	-- check for static obstacles, if flag 5 is set for currrent cell:
	if check_flag(x, y, 5) then obstacle_hit() end
	-- check for switch
	if switch_data[level][1] != 16 then check_switches() end
	-- check for mab eyes
	if level == 16 then check_mab_eyes() end
end

function check_switches()
	-- cycle through all switches
	-- landing on a switch permanently opens its door
	for k in all(switch_data[level]) do
		-- if coordinates match any switch_data[level][1] and [2] and open is false then
		if x/8 == k[1] and y/8 == k[2] and not k[6] then
			if play_sounds then sfx(49) end
			switch_set(k, true)
			debug_text = tostr(k[1])..","..tostr(k[2])..","..tostr(k[3])..","..tostr(k[4])..","..tostr(k[5])..","..tostr(k[6]) -- temp
		end
	end
end

function check_mab_eyes()
	for k in all(mab_data) do
		if x/8 == k[1] and y/8 == k[2] and k[5] == false then
			-- activate eye
			k[5] = true
			mab_start(k[3], k[4])
			debug_text = "mab start"
		end
	end
end

function switch_set(switch, to_open)
	-- set switch to to_open true/false
	-- switch is an array: switch x/y, door x/y, start sprite, open state
	local switch_sprite_adjust = 0
	if to_open then switch_sprite_adjust = 1 end
	-- set switch to open/closed and update map
	mset(
		map_data_pos[level][1] + switch[1],
		map_data_pos[level][2] + switch[2],
		switch[5] + switch_sprite_adjust -- use sprite + 1 if open
	)
	-- set door to open/closed and update map
	mset(
		map_data_pos[level][1] + switch[3],
		map_data_pos[level][2] + switch[4],
		switch[5] + 2 + switch_sprite_adjust --  use sprite + 1 if open
	)
	-- coordinates match a switch which is not open
	switch_data[level][6] = open_state -- set switch/door data to open
end

function switch_reset()
	-- reset all switches in current level
	for k in all(switch_data[level]) do
		-- if coordinates match any switch_data[level][1] and [2] and open is false then
		if k[1] != 16 then switch_set(k, false) end
	end
end

function show_debug_info()
	rectfill(0, 0, 64, 7, level_bg[level])
	print(debug_text, 0, 0, 15)
	-- print("x "..tostr(x).." y "..tostr(y), 0, 0, 7)
end

-- ## fog functions

function unfog_reset()
	-- set fog to max value (8) across map.
	-- all arrays are 1-based.
	fog = {}
	local h = fog_height[level]
	for j=1,16 do
		fog[j] = {}
		for i=1,16 do
			if j < h-1 then fog[j][i] = 0
				-- randomise fog at the rows above fog_height:
			elseif j == h-1 then fog[j][i] = flr(rnd(3)) + 2
			else fog[j][i] = 8 end
		end
	end
end

function unfog_circle()
	-- shows an area around the player defined by unfog_pattern
	for j=-4,4 do
		for i=-4,4 do
			-- coordinates of fog placement:
			local fogx = x+i*8
			local fogy = y+j*8
			-- don't do anything if fog position isn't in game field:
			if fogx >= 0 and fogx <= 120 and fogy >= 0 and fogy <= 120 then
				local unfog_amount = unfog_pattern[j+5][i+5]
				-- set fog level to minimum of (current level, current - unfog amount) but keep it above 0
				old_fog = fog[ar(fogy)][ar(fogx)]
				fog[ar(fogy)][ar(fogx)] = max(0, min(8 - unfog_amount, old_fog))
			end
		end
	end
end

function unfog_start()
	-- initialises function to unfog the whole screen
	offset = 0.125
	-- show how many extra points awarded by socky
	bonus_caption = ""
	ice_adjust = 0
	if ice then ice_adjust = 1 end
	if socky_add >= 1 then
		-- so that display is consistent,
		-- subtract one to account for move already started
		-- but add back on if on ice, as 1 point will have already been deducted at start of move
		bonus_caption = " +"..tostr(socky_add - 1 + ice_adjust)
	end
	caption_show("socky!"..bonus_caption, 1, 12, 7)
	unfog_active = true
	unfog_y = fog_height[level] * 8 - 16 -- y coordinate of the start of the unfogging, which moves up-right in strips
	unfog_start_time = t
end

function unfog_step()
	-- gradually unfogs the whole screen from top left to bottom right
	-- in strips from the left or bottom of the screen
	if unfog_y == 320 then -- unfog is complete
		unfog_active = false
		return
	end
	if t % unfog_frames == 0 then
		unfog_strip(0,unfog_y)
		unfog_y += 8
	end
end

function unfog_strip(lx, ly)
	-- unfog strip from lx, ly in up-right direction, last strip starting at (0, 248)
	while lx < 256 do
		-- set fog to a gradually decreasing strip upwards from lx, ly
		for unfog_level = 1,8 do
			local ly_offset = ly - unfog_level * 8
			if ly_offset >= 0 and ly_offset < 128 then
				-- unfog cell is on screen:
				unfog_cell(lx, ly_offset, unfog_level)
			end
		end
		lx += 8
		ly -= 8
	end
end

function unfog_cell(a, b, amt)
	old_fog = fog[b/8 + 1][a/8 + 1]
	fog[ar(b)][ar(a)] = max(0, min(8 - amt, old_fog))
end

-- ## obstacle functions:

function obstacle_reset()
	obstacles = {}
	for j=1,16 do
		obstacles[j] = {}
		for i=1,16 do
			obstacles[j][i] = 0
		end
	end
end

function obstacle_update()
	obstacle_reset()
	local step = anim_frame % level_period + 1
	-- get coordinates of all obstacles from current level at current time:
	obs = obs_data[level][step]
	for k in all(obs) do -- k is a pair of 0-based coordinates for an obstacle
		if k[2] * k[1] != 256 then -- check there is obstacle data
			obstacles[k[2] + 1][k[1] + 1] = 1
			-- default obstacle value = 1
		end
	end
end

function obstacle_hit()
	offset = 0.5
	moves -= 4
	if just_moved == false then moves -= 1 end -- ensures score is always subtracted by 5 when obstacle hits you
	caption_show("-5", 2, 8, 9)
	if play_sounds then sfx(46) end
end

function caption_show(text, col1, col2, col3)
	caption_text = text
	cstep = ceil(#caption_text/4)
	caption_colours = {col1, col2, col3}
	caption_data = {}
	caption_reset_data()
	caption_active = true
	 -- data for each 8x8 character across bottom of screen with character and colour
end

function caption_reset_data()
	for i=1,16 do
		caption_data[i] = 16 -- reset caption data to blank
	end
end

function caption_step()
	-- gradually displays a caption at bottom of screen with colours expanding outwards
	-- gradually unfogs the whole screen from top left to bottom right
	-- in strips from the left or bottom of the screen
	if cstep >= 20 then
		caption_active = false
		return
	end
	if t % caption_frames == 0 then
		if cstep <= 12 then
			-- cycle through caption_pattern and set colour data:
			caption_reset_data()
			for i=1,#caption_pattern do
				local dp = 7-cstep+i -- draw position of left hand bar
				if dp >= 1 and dp <= 8 then
					caption_data[dp] = caption_colours[caption_pattern[i]]
					-- mirror the pattern on right hand side of bar
					caption_data[17-dp] = caption_colours[caption_pattern[i]]
				end
			end

			-- remove space from bar for caption
			local cells_to_clear = ceil(#caption_text/4)
			if cells_to_clear > 0 then
				for i=9-cells_to_clear,8+cells_to_clear do
					caption_data[i] = 16
				end
			end
		end
		cstep += 1
	end
end

function mab_start(a, b)
	-- initialises function to unfog the whole screen
		offset = 1
		mab_active = true
		mab_eyes_open = false
		mab_hit = false
		debug_text = "mab start"
		mabx = a
		maby = b
end

function mab_step()
	if not mab_active then return end
	maby += 1
	if maby >= 16 then
		mab_active = false
		debug_text = "mab inactive"
		return
	end
	-- check if collided with pandora
	local xdiff = x/8 - mabx
	local ydiff = y/8 - maby
	if ((ydiff == 1 or ydiff == 0) and (xdiff >= 0 and xdiff <=3)) -- at eye level
	or (ydiff == 2 and (xdiff == 1 or xdiff == 2)) then -- at mouth level
		debug_text = "mab hit"
		mab_hit = true
	end
	if ((ydiff >= 0 and ydiff <= 4) and (xdiff >= 0 and xdiff <=3)) then
		mab_eyes_open = true
	end
end

function mab_reset()
	mab_data = {
		-- eye position, mab start position, open
		{1, 14, 0, 0, false},
		{7, 12, 6, 0, false},
		{5, 7, 3, -1, false},
		{8, 5, 9, 0, false},
		{13, 5, 12, -2, false}
	}
end

function mab_retreat_start()
	mab_start_time = t
	mab_small_x = 8
end

function mab_retreat_step()
	if (t - mab_start_time) % 30 != 29 then return end
	debug_text = "move mab"
	mab_small_x += 1
	rectfill(64, 0, 127, 7, 12)
	map(120, 16, 8, 0, 16, 0)
	spr(254, mab_small_x*8, 0)
	dir="r"
	move_sound()
end

-- ## draw functions

function draw_everything()
	cls()
	draw_level()
	draw_obstacles()
	draw_mab_eyes()
	if mab_active then draw_mab(mabx, maby, mab_eyes_open) end
	draw_fog()
	draw_player()
	draw_caption()
	draw_moves()
	draw_menu()
	if debug_mode then show_debug_info() end
end

function draw_level()
	rectfill(0,0,127,127,level_bg[level])
	-- draw map
	map(map_data_pos[level][1], map_data_pos[level][2], 0, 0, 16, 16)
	-- draw socky
	if socky_collect == false then
		spr(28, socky_pos[level][1] * 8, socky_pos[level][2] * 8)
	end
	if level == 16 then
		spr(27, 56, 0) -- draw mab socky
	else -- draw goal
		spr(24, 120, goal_height[level] * 8)
	end
end

function draw_obstacles()
	for j=1,16 do
		for i=1,16 do
			if obstacles[j][i] > 0 then
				spr(29, px(i), px(j))
			end
		end
	end
end

function draw_fog()
	for j=0,15 do
		for i=0,15 do
			if fog[j+1][i+1] > 0 then
				spr(15 + fog[j+1][i+1], i*8, j*8)
			end
		end
	end
end

function draw_player()
	if dir == "u" then spr(5 + anim_frame%2, x+dx, y+dy)
	elseif dir == "d" then spr(3 + anim_frame%2, x+dx, y+dy)
	elseif dir == "l" then spr(1 + anim_frame%2, x+dx, y+dy, 1, 1, true, false) -- flip r sprite
	elseif dir == "r" then spr(1 + anim_frame%2, x+dx, y+dy) -- dir == "r" or default
	end
end

function draw_caption()
	if caption_active == false then return end

	for i=1,16 do
		if caption_data[i] != 16 then
			print("▤", px(i), 120, caption_data[i])
		end
	end

	print3d(caption_text, 64 - #caption_text * 2, 120, 7, 0)
end

function draw_moves()
	local m = tostr(moves)
	rectfill(120, 0, 127, 5, level_bg[level])
	print3d(tostr(moves), 128 - #m*4, 0, 6, 0)
end

function draw_menu()
	if menu_active == false then return end
	local music_status = "on"
	local sounds_status = "on"
	if not play_music then music_status = "off" end
	if not play_sounds then sounds_status = "off" end

	draw_menu_outline()
	print("restart level", 32, 24, 12)
	print("music is "..music_status, 32, 32, 14)
	print("sounds are "..sounds_status, 32, 40, 15)
	print("close", 32, 48, 8)
	spr(24, 16, 16 + menu_option * 8)
	draw_progress()
end

function draw_menu_outline()
	rectfill(0, 12, 127, 115, 0)
	for i=0,15 do
		spr(197, i*8, 8)
		spr(198, i*8, 112)
	end
end

function draw_progress()
	rectfill(16, 88, 23, 95, 3) -- green bit for level 3
	rectfill(48, 88, 71, 95, 12) -- blue bit for ice levels
	for i=1,last_level do
		spr(208, i*8 - 8, 80) -- progress bar
		spr(level_sprites[i], i*8 - 8, 88) -- level sprites
		spr(medal_sprite[best_medal[i]], i*8 - 8, 96) -- medals
	end
	rectfill(level*8 - 5, 80, 127, 87, 1) -- cut off progress bar
	spr(1, level*8 - 7, 80) -- cat
end

function draw_mab_eyes(a, b)
	if level != 16 then return end
	for k in all(mab_data) do
		local eye_sprite = 244
		if k[5] == true then eye_sprite = 245 end
		spr(eye_sprite, k[1]*8, k[2]*8)
	end
end

function draw_mab(a, b, open)
	if open then
		eye_sprite_l = 237
		eye_sprite_r = 238
		mouth_sprite = 251
	else
		eye_sprite_l = 244
		eye_sprite_r = 244
		mouth_sprite = 250
	end
	spr(246, a*8, b*8)
	spr(247, a*8 + 24, b*8)
	rectfill(a*8, b*8+8, a*8+31, b*8+15, 7)
	rectfill(a*8+8, b*8+16, a*8+23, b*8+23, 7)
	spr(248, a*8, b*8+16)
	spr(249, a*8+24, b*8+16)
	spr(eye_sprite_l, a*8+5, b*8+9)
	spr(eye_sprite_r, a*8+20, b*8+9)
	spr(mouth_sprite, a*8+12, b*8+16)
end

function print3d(text, xpos, ypos, col1, col2)
	print(text, xpos+1, ypos+1, col2)
	print(text, xpos, ypos, col1)
end

function shake_screen()
	-- code from doc robs
  local fade = 0.9
  local offset_x=16-rnd(32)
  local offset_y=16-rnd(32)
  offset_x*=offset
  offset_y*=offset

  camera(offset_x,offset_y)
  offset*=fade
  if offset<0.05 then
    offset=0
	end
end

function menu_open()
	menu_active = true
	menu_option = 1 -- current selected menu
	-- set menu sprite for each cell
	-- allow menu to be opened and closed using button 2
	caption_show("menu", 2, 8, 14)
	in_game = false
end

function menu_process_input()
	if btnp(⬆️) then menu_option -= 1
	elseif btnp(⬇️) then menu_option += 1
	elseif btnp(4) then menu_choose()
	elseif btnp(5) then menu_close()
	end
	if menu_option > menu_items then menu_option = 1 end
	if menu_option <= 0 then menu_option = menu_items end
end

function menu_choose()
	if menu_option == 1 then level_restart()
	elseif menu_option == 2 then
		if play_music then
			play_music = false
			music(-1)
		else
			play_music = true
			music(1)
		end
	elseif menu_option == 3 then
		if play_sounds then
			play_sounds = false
			sfx(-1)
		else
			play_sounds = true
			sfx(41)
		end
	elseif menu_option == 4 then
		menu_close()
	end
end

function menu_close()
	menu_active = false
	in_game = true
end

function add_arrays(a, b)
	-- see https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
	-- and https://stackoverflow.com/questions/39185608/duplicating-tables-in-lua
	local ab = {}
	for i=1, #a do -- copy table a
		ab[#ab + 1] = a[i]
	end
	for i=1, #b do -- then add each element of b
		ab[#ab + 1] = b[i]
	end
	return ab
end

-- ## level by level data:

function game_get_data()
	unfog_pattern={
		{0, 0, 0, 1, 2, 1, 0, 0, 0},
		{0, 1, 2, 3, 4, 3, 2, 1, 0},
		{0, 2, 4, 5, 6, 5, 4, 2, 0},
		{1, 3, 5, 7, 8, 7, 5, 3, 1},
		{2, 4, 6, 8, 8, 8, 6, 4, 2},
		{1, 3, 5, 7, 8, 7, 5, 3, 1},
		{0, 2, 4, 5, 6, 5, 4, 2, 0},
		{0, 0, 2, 3, 4, 3, 2, 1, 0},
		{0, 0, 0, 1, 2, 1, 0, 0, 0}
	}
	caption_pattern = {1, 2, 3, 2, 1} -- dictates colour of caption bars over time steps
	level_bg = {3, 3, 3, 3, 0, 0, 12, 14, 12, 4, 4, 4, 5, 5, 4, 12} -- level background colour
	goal_height = {7, 9, 5, 10, 1, 14, 7, 7, 8, 14, 8, 8, 10, 8, 15, 0} -- cells from top of screen, base 0
	fog_height = {7, 6, 1, 1, 1, 3, 3, 1, 3, 1, 1, 1, 1, 2, 1, 4} -- cells from top of screen, base 0. must be >= 1
	socky_pos = { -- in cells base 0
		{15, 12}, -- 1
		{2, 10}, -- 2
		{7, 2}, -- 3
		{15, 6}, -- 4
		{0, 7}, -- 5
		{11, 5}, -- 6
		{1, 15}, -- 7
		{2, 3}, -- 8
		{8, 2}, -- 9
		{12, 7}, -- 10
		{8, 2}, -- 11
		{8, 2}, -- 12
		{15, 2}, -- 13
		{7, 2}, -- 14
		{2, 15}, -- 15
		{2, 10} -- 16
	}
	start_pos = { -- in pixels, 0 to 120
		{24, 120}, -- 1
		{0, 48}, -- 2
		{0, 80}, -- 3
		{0, 80}, -- 4
		{0, 80}, -- 5
		{0, 8}, -- 6
		{0, 112}, -- 7
		{0, 56}, -- 8
		{0, 56}, -- 9
		{0, 56}, -- 10
		{0, 56}, -- 11
		{0, 56}, -- 12
		{0, 8}, -- 13
		{0, 64}, -- 14
		{0, 0}, -- 15
		{0, 120} -- 16
	}
	map_data_pos = { -- in cells on datasheet
		{0, 0}, -- 1
		{16, 0}, -- 2
		{32, 0}, -- 3
		{48, 0}, -- 4
		{64, 0}, -- 5
		{80, 0}, -- 6
		{96, 0}, -- 7
		{112, 0}, -- 8
		{0, 16}, -- 9
		{16, 16}, -- 10
		{32, 16}, -- 11
		{48, 16}, -- 12
		{64, 16}, -- 13
		{80, 16}, -- 14
		{96, 16}, -- 15
		{112, 16} -- 16
	}
	moves_data = {
		-- [1] perfect score for each level without socky
		-- [2] minimum moves needed to complete level with socky
		-- excluding socky bonus, subtract 10 from final score when calculating this
		-- [3] moves allowed for each level (default [1] + 5 but add more if harder)
		-- [4] remaining points needed for gold (default 15 = perfect)
		-- [5] remaining points needed for silver (default 10)
		-- [6] remaining points needed for bronze (default 5, get through level as quick as poss without socky)
		{34, 44, 39, 15, 10, 5},
		{30, 62, 35, 15, 10, 5},
		{28, 28, 33, 15, 10, 5}, -- level 3 is quickest with socky
		{43, 53, 48, 15, 10, 5},
		{80, 94, 90, 20, 15, 10}, -- give extra leeway as level is complex
		{68, 76, 87, 29, 24, 19}, -- 6. perfect is 68 with shortcuts, 82 without shortcuts. So to be fair, moves allowed = 82 + 5.
		{15, 22, 20, 15, 10, 5},
		{21, 26, 26, 15, 10, 5},
		{21, 22, 30, 19, 14, 9}, -- 9
		{74, 94, 84, 20, 15, 10}, -- 10
		{100, 100, 100, 15, 10, 5}, -- 11
		{100, 100, 100, 15, 10, 5}, -- 12
		{34, 42, 49, 25, 20, 15}, -- 13
		{56, 64, 71, 25, 20, 15}, -- 14
		{18, 19, 28, 20, 15, 10}, -- 15
		{100, 100, 100, 15, 10, 5} -- 16
	}
	obs_data = {
		-- in each level's data, each time period has a set of obstacles.
		-- 16, 16 represents no obstacle. coordinates start from 0.
		{{{16, 16}}}, -- level 1
		-- level 2:
		{
			{{4, 8}},
			{{4, 9}},
			{{4, 10}}
		},
		-- level 3:
		{
			{ -- 1st time period
				{2, 9}, {2, 10}, {2, 11},
				{6, 7}, {7, 6}, {8, 7},
				{10, 9}, {11, 10}, {12, 11}
			},
			{ -- 2nd time period
				{3, 9}, {3, 10}, {3, 11},
				{6, 6}, {7, 5}, {8, 6},
				{11, 9}, {12, 10}, {10, 11}
			},
			{ -- 3rd time period
				{4, 9}, {4, 10}, {4, 11},
				{6, 5}, {7, 7}, {8, 5},
				{12, 9}, {10, 10}, {11, 11}
			}
		},
		{{{16, 16}}}, -- level 4
		{{{16, 16}}}, -- level 5
		{ -- level 6
			{ -- period 1
				{6, 4}, {6, 3}, {4, 3}, {3, 3}, {1, 3}, {1, 4}, {1, 6}, {1, 7}, {6, 7}, {6, 6},
				{8, 8}, {10, 9}, {9, 10}, {8, 11}
			},
			{ -- period 2
				{6, 6}, {6, 5}, {6, 3}, {5, 3}, {3, 3}, {2, 3}, {1, 4}, {1, 5}, {1, 7},
				{9, 8}, {8, 9}, {10, 10}, {9, 11}
			},
			{ -- period 3
				{6, 5}, {6, 4}, {5, 3}, {4, 3}, {2, 3}, {1, 3}, {1, 5}, {1, 6}, {6, 7},
				{10, 8}, {9, 9}, {8, 10}, {10, 11}
			}
		},
		{{{16, 16}}}, -- level 7
		{{{16, 16}}}, -- level 8
		{{{16, 16}}}, -- level 9
		{{{16, 16}}}, -- level 10
		{{{16, 16}}}, -- level 11
		{{{16, 16}}}, -- level 12
		{ -- level 13
			{ -- period 1
				{8, 6}, {6, 5}, {6, 2}, {9, 2}, {10, 4}, -- middle top
				{13, 9}, {13, 6}, {11, 5}, {9, 7}, {10, 9}, -- right middle
				{3, 8}, {6, 8}, {3, 5}, -- left top
				{10, 12}, {7, 12}, {7, 9}, -- right bottom
				{2, 10}, {1, 8}, -- left middle
				{5, 13}, {7, 14}, -- middle bottom
				{3, 13}, {4, 11}, {2, 12} -- left bottom
			},
			{ -- period 2
				{7, 6}, {6, 4}, {7, 2}, {10, 2}, {10, 5}, -- middle top
				{13, 8}, {13, 5}, {9, 8}, -- right middle
				{4, 8}, {6, 7}, {5, 5}, {3, 6}, -- left top
				{10, 10}, {9, 12}, {7, 11}, {8, 9}, -- right bottom
				{3, 9}, {1, 10}, -- left middle
				{6, 12}, {5, 14}, -- middle bottom
				{4, 13}, {3, 11} -- left bottom
			},
			{ -- period 3
				{9, 6}, {6, 6}, {6, 3}, {8, 2}, {10, 3}, -- middle top
				{12, 9}, {13, 7}, {12, 5}, {9, 9}, -- right middle
				{5, 8}, {4, 5}, {3, 7}, -- left top
				{10, 11}, {8, 12}, {7, 10}, {9, 9}, -- right bottom
				{3, 10}, {1, 9}, -- left middle
				{5, 12}, {6, 14}, -- middle bottom
				{4, 12}, {2, 11} -- left bottom
			}
		}, 
		{ -- level 14
			{ -- period 1
				{11, 4}, {5, 6}, {1, 7}, {7, 8}, {1, 9}, {9, 10}, {3, 12}
			},
			{}, {} -- nothing in remaining 2 periods
		},
		{ -- level 15
			{}, -- placeholders for each period, see below
			{},
			{},
			{}
		},
		{{{16, 16}}} -- level 16
	}
	-- level 15 data is repeated so split it up to prevent duplication:
	level_15_obs_a = { -- 2x2 obstacles, periods 1 and 2
		{4, 2}, {5, 2}, {4, 3}, {5, 3},
		{2, 4}, {3, 4}, {2, 5}, {3, 5},
		{6, 4}, {7, 4}, {6, 5}, {7, 5},
		{4, 6}, {5, 6}, {4, 7}, {5, 7},
		{8, 6}, {9, 6}, {8, 7}, {9, 7},
		{6, 8}, {7, 8}, {6, 9}, {7, 9},
		{10, 8}, {11, 8}, {10, 9}, {11, 9},
		{8, 10}, {9, 10}, {8, 11}, {9, 11}
	}
	level_15_obs_b = { -- 2x2 obstacles, periods 3 and 4
		{2, 2}, {3, 2}, {2, 3}, {3, 3},
		{6, 2}, {7, 2}, {6, 3}, {7, 3},
		{10, 2}, {11, 2}, {10, 3}, {11, 3},
		{4, 4}, {5, 4}, {4, 5}, {5, 5},
		{8, 4}, {9, 4}, {8, 5}, {9, 5},
		{2, 6}, {3, 6}, {2, 7}, {3, 7},
		{6, 6}, {7, 6}, {6, 7}, {7, 7},
		{10, 6}, {11, 6}, {11, 7},
		{4, 8}, {5, 8}, {4, 9}, {5, 9},
		{2, 10}, {3, 10}, {2, 11}, {3, 11},
		{6, 10}, {6, 11}, {7, 11},
		{10, 10}, {11, 10}, {10, 11}, {11, 11}
	}
	level_15_obs_c = { -- 1x1 obstacles at bottom right, periods 1 and 3
		{13, 4}, {12, 5}, {13, 6}, {12, 7},
		{13, 8}, {12, 9}, {13, 10}, {12, 11},
		{4, 13}, {5, 12}, {6, 13}, {7, 12},
		{8, 13}, {9, 12}, {10, 13}, {11, 12},
		{12, 13}, {13, 12}
	}
	level_15_obs_d = { -- 1x1 obstacles at bottom right, periods 2 and 4
		{12, 4}, {13, 5}, {12, 6}, {13, 7},
		{12, 8}, {13, 9}, {12, 10}, {13, 11},
		{4, 12}, {5, 13}, {6, 12}, {7, 13},
		{8, 12}, {9, 13}, {10, 12}, {11, 13},
		{12, 12}, {13, 13}
	}
	obs_data[15][1] = add_arrays(level_15_obs_a, level_15_obs_c)
	obs_data[15][2] = add_arrays(level_15_obs_a, level_15_obs_d)
	obs_data[15][3] = add_arrays(level_15_obs_b, level_15_obs_c)
	obs_data[15][4] = add_arrays(level_15_obs_b, level_15_obs_d)
	switch_data = {
		-- switch x/y, door x/y, 1st switch sprite, is_open?
		{{16}}, -- 16 means no data
		{{16}},
		{{16}},
		{{16}},
		{{16}},
		{{16}},
		{{16}},
		{{16}},
		{{16}},
		{
			{2, 0, 11, 14, 233, false},
			{12, 2, 13, 14, 233, false},
			{14, 12, 9, 14, 233, false},
		},
		{{16}},
		{{16}},
		{{16}},
		{ -- level 14
			{14, 5, 3, 4, 217, false},
			{0, 4, 11, 12, 217, false},
			{14, 11, 13, 8, 217, false}
		},
		{{16}},
		{{16}}
	}
	ice_data = {false, false, false, false, false, false, true, true, true, false, false, false, false, false, false, false}
	level_sprites = {34, 49, 80, 100, 88, 91, 113, 209, 118, 28, 28, 28, 205, 214, 222, 244} -- for progress bar
	best_medal = {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4} -- best medal for each level so far, 1=gold, 4=none
end

--[[ some characters
a█ b▒ c🐱 d⬇️ e░ f✽ g●
h♥ i☉ j웃 k⌂ l⬅️ m😐 n♪
o🅾️ p◆ q… r➡️ s★ t⧗ u⬆️
vˇ w∧ x❎ y▤ z▥
]]--

__gfx__
00000000ddd0dd0ddddddddddd0dd0ddddddddddd0dd0ddddddddddd0000000000000000000000000000000000000000a00000a0700000700000000000000000
00000000ddd0a0adddd0dd0dd00a0add5d0dd0ddd0000dddd0dd0ddd00000000000000000000000000000000000000009aa0aa90670007609900099050000050
00700700d000000dd000a0add00000dd000a0addd00000ddd0000d5d00000000000000000000000000000000000000009a0aa090607770604499944000505000
00077000000000dd0000000dd00000dd000000ddd00000ddd000000d000000000000000000000000000000000000000090090090600600604004004050000050
00077000000000dd000000ddd00000ddd00000ddd00000ddd000000d000000000000000000000000000000000000000049909940666666602444442000000000
00700700000000dd0000000dd50000ddd00000ddd00000ddd00000dd000000000000000000000000000000000000000004000400060006000240420005000500
0000000050ddd0dd0ddddd0ddd00d0dddd0d00dddd0d05dddd00d0dd000000000000000000000000000000000000000000444000006660000022200000050000
00000000dddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111dddadddd0000000000000000dddd282dddddfefdddd7dddddddddddddddddddd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111ddd99ddd0000000000000000dddd2820ddddfef0de2e28dddddddddddddddddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111111111111111111119a999add0000000000000000dddd1110dddd8880d27e800dddd8ddddddd8dddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111a999a99d0000000000000000ddd12210ddd8ff807ee8220ddd8d0ddddddd8ddd
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111999a99500000000000000000dd112200dd88ff00d2820000ddd8ddddddd8d0dd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111d509950d00000000000000002122110df8ff880dd802020ddddd0ddddddd0ddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111111111111111111111111111ddd950dd00000000000000002112100df88f800ddd00000ddddddddddddddddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111dddd0ddd0000000000000000d00000ddd00000dddddd0ddddddddddddddddddd
ddddddddddddddddffffff4f555555555555555555555555444444444dddddddffffff4fff7777ff4610011fddddddd4dd45554ddddddddddddddddddddddddd
ddddddddddddddddffffff4f555ffffffffffffffffff5552424242424ddddddfffff400ff7777ff4110011fdddddd24d4ffff43d8ddd8dddddddddddddddddd
ddddddddddddddddfffffffffffff0f0f0f0f0f0f0f0ffff44444444444dddddfffff405fff77fff4110511fddddd444df0f2f43dd0ddd0dddd8dddddddddddd
dddddddddddddddd44f44f44f4fff4f4f4f4f4f4f4f4ff0f424242424242dddd44f444504777777441155114dddd4242dfff0f4ddddddddddd8d8ddddd8d8ddd
ddddddddddddddddff4ffffff0fff0f0f0f0f0f0f0f0ff4f4444444444444dddff4ff4004110061f4115511fddd44444df3fff43ddddddddddd0d0ddddd8d0dd
dddddddddddddfddfffffffff0fff3f0f0f0f3f0f0f0ff3f24242424242424ddfffff4004110011f4115511fdd2424243f0f1f43d8ddd8dddddddddddddd0ddd
dddddddddfddddddff4ffffff4fff3fff4fff3fff4ffff3f444444444444444dff4ff4444116011f77777777d44444443fff1f3ddd0ddd0ddddddddddddddddd
ddddddddddddddddf444f44ffffddddddddddddddddddfff4242424242424242f444f44f4110011f7777777742424242d333d33ddddddddddddddddddddddddd
ccccccccccccccccccccccccccccccccccccccccddb35dddd533323d35333233ddddddddccccccccccccccccccccccccddbdd23d000000000000000000000000
cccccccccccccccccccc76ccddccccccccccccccd33b35dd3355335333553353dddaddddccccccccccccccddccccccccd33d23bd000000000000000000000000
cccccccccccc76ccccc76ccc3dddcccccccccccc3b3330dd5333303553333030ddbdddddccccccccccccddd3cc5ccccc323b3353000000000000000000000000
ccccccccc76c776ccccccccc3bddddcccccccccc3333335d3033333550333305ddddddddccccccccccdd333dcc5cccccd3205230000000000000000000000000
cccccccc7777766ccccccccc333333ddccccccccd305305d23355333d55050ddddddddddccccccccdd33b3d3cc5cccccb3032035000000000000000000000000
ccccccccc666c6cccccccccc3333335dddccccccd5d405dd33533030dddddddddbddddddccccccddd3333333c555cccc32300350000000000000000000000000
ccccccccccccccccc76cccccd3b33335ddddccccddd42ddd55333325ddddddddddddddadccccddb333333350c555cccc23050500000000000000000000000000
ccccccccccccccccccccccccd533350dddddddccddd42dddd2500550ddddddddddddddddccdd3dddd533350dc555ccccd00050dd000000000000000000000000
11111111001111110000000000111111000000001111111100111111c1111111dddd00000000dddd1ddddd1d1ddddd1d1ddd5d1d1d5d5d1d1d55051d15050515
111111110011111100000000001111110000000011111c110011111111111111dd0000000000000dddd1ddddddd1dddd5dd1ddd555d1d5d50551d55005515050
111111111111111111111111001111110011111111111111001111111c111111d00011111111110dddddddddd1ddd1ddd15dd1ddd15d515d5155515551055105
111111111111111111111111001111110011111111111111d011111111111111d00111111111111dddd1ddddddd1ddd15dd15dd15dd15dd15551055150510051
111111111111111111111111001111110011111111111111d01111111111111dd011111111111111d1ddd1ddd1ddd1ddd1ddd15d5155d15d5105d10501050105
111111111111111111111111001111110011111111c11111d01111111111111dd011111111111111ddddddddddd1ddddd5d15dddd5d15dd5d05150d550515050
111111111111111111111111001111110011111111111111d01111111111111d0011111111111111dddddd1d1ddddd1d1d5ddd1d1d55d51d1505551d15050515
111111111111111111111111001111110011111111111111dd111111111111dd0011111111111111dd1ddddddd1d1ddddd1d1dd5d51d15d55515105050151050
ddddddddddd0adddddddddddddddddddddddddddddda0dddddd445dddd5a5ddd00000000800000000c0000000000000000000000000000005005000515050055
adddddddddd495ddadddddddddddddadaddddddddd4945daddd5a0ddddd905ad0a00000000000e000000f0005555055500000555000005000000000000505000
94dadda4ddda4ddd94daddddddddd4949ddddda5dda45449add495ddad44a49400000b0000200000000100000000050000000500000000000500050505000105
45494495dd5944dd45495ddddda4454544dad494dd94405494a440dd944490400004000000000008000000400000050000000000000000000005000050010050
45d45d45ddd4addd45540ddddd95504040494045dd540540409445dd454540450000000300000000000700000000000000000000000000000500000505000505
40554545ddd494dd4d54addddd44a54555544540ddd4554d4540dddd404045457000000009000000000000000555555505550000050000000005000050010000
45d54040ddd440ddddd495dddd549d4ddd544addddd0454d4d45dddd45d5454d0000000000000000000005000500000005000000000000005000005010050015
dddd4545ddd545ddddd540dddd044ddddd0559dddddddddddd4ddddd4ddd4ddd0050000000040000000000000500000000000000000000000050000000105000
e9e9e9e9e9e9e9e91c1c1c1c1c1c1c1c1c1c1c1c01010101010101010101010105000000050000000600000aa00000000000000090090900d000000ddddddddd
dd9e999e999e999eddc1ccc1ccc1ccc1ccc1ccc1dd101110111011101110111055565565656565555556666500665655000000009909090900000011dd0000dd
3ddd9a999a999a993dddcecccecccecccecccecc3ddd1111111111111111111100000500000006000000060000000500000000009909099000011111d001111d
3bdddda9a9a9a9a93bddddececececececececec3bdddd11111111111111111100000600000006000000060000000600000000009909090900111111d011111d
333333dd9a9a9a9a333333ddcececececececece333333dd111111111111111100000500000005000000050000000600000000000000000000111111d011111d
3333335ddda9aaa93333335dddeceeeceeeceeec3333335ddd1111111111111155665585656656555556665666565555000000000900000000111111d011111d
d3b33335ddddaaaad3b33335dddde9eee9eee9eed3b33335dddd1c111c111c1105000898050000000500000005000000000000009999999901111111dd1111dd
d533350dddddddaad533350ddddddd9e9e9e9e9ed533350dddddddc1c1c1c1c106000089a500000005000000050000000000000009000000d111111ddddddddd
dddd77ddddd77dddd777777ddddd77ddd777777ddd7777ddd777777ddddddddd7777777776777677ddddddddddd7dddd7776777777777777dddddddddddddddd
d77777777d7777dd777777777777777777777767d777777d7ee77ee7444455557777777777777777dddddd7d77d7d6dd66657666777777e7ddddddddddddd6dd
d77777777d1771dd777777767777777777777776d777767d77777777555549447777777777777777dddddddddd776ddd6665766677f77777dddddddddddd666d
d7777767777777777777777777777776d7776767d77777777e7777e7499999957777777777777777d6dddddd6676777d5555655577777777ddddd77dd77666d6
77777676dd7117d77777777777677777777777767777777677eeee77555549447777777777777777dddddddddd76ddd677777776777777776dd777d777d7766d
77677766dd7776d7d7777777777777767777676d7777776777777777444455557777776777777777dddddddddd7d6ddd7666666577777c77d777777d777d7d76
7677766ddd7767ddd77767676767676d767676d67777777677777776dd74477d7676767d77777777dddd6dddd6dd6ddd766666657a777777777777d777d7d7d7
d76766dddd6776dddd7676dd767676ddd7676d6d7777776dd767676dd77777dd67d767dd67776777ddddddddddddd6dd65555555777777777d7d7d7d7d7d7d7d
00000000000000bc0000000000000000020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000
eeeeffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7c8c7c8c7c8c7cbc7c8c7ccc7c8c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
eeeeffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bcac9cbcbcbc9cac9cacbc009cbc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffeeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000dc000000bc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bcbc7c8cbcbc00bcbcbcbc7c8c00bc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9cbc9cac9cac009cecacbcbcbc00dc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9cac0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000bc0000bc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7c8c7c8c7ccc7ccc7c8c7cccbccc00bc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bcac9cccbc00bccc9ccc9ccc9ccc00dc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bc0000000000bc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d66666ddd66666dd5777775d5775775dddddddddfffffffdfffffff4ddddaaaaaaadddddadadadaaadadadadadadadadaaaaaaaaddaaadddadadadaa00000000
6ddddd6d6ddddd6d5557755d5577755dddddd6ddf00000f4f00000f4ddaadddddddaadddadaddadddaddadadadadadaddddddddddadddaddaaadaaad00000000
6d6d6d6d6d666d6d5577555d5577755ddddd6dddf4fff4f4f4fff4f4dadddaaaaadddaddaddaddaaaddaddadadadadadaaaaaaaaadaaadadaddaddaa00000000
6dd6dd6d6d6d6d6d5777775d5775775dddd6ddddf4f0f4f4f4f0f4f4dadaadddddaadadddadaadddddaadaddadadadadddddddddadadadaddaaaaadd00000000
6d6d6d6d6d666d6d5555555d5555555ddd6dddddfff4f4f4fff4f4f4addaddaaaddaddaddadddaaaaadddaddadadadadaaaaaaaaadaaadadaadddaaa00000000
6ddddd6d6ddddd6dddddddddddddddddd6dddddd0004f4f40004f4f4adaddadddaddadadddaadddddddaadddadadadaddddddddddadddaddddaaaddd00000000
d66666ddd66666dd5555555d5555555dddddddddfffff4fffffff4ffadadadaaadadadadddddaaaaaaadddddadadadadaaaaaaaaddaaadddaaadaaaa00000000
dddddddddddddddddddddddddddddddddddddddd0000000000000d00adadadadadadadadddddddddddddddddadadadaddddddddddddddddddddddddd00000000
11111111eeeeffff77777777d45454ddcc7c7c7c54545454a00aa00aa00aa00acc7c7c7cd555555dd555555dcc7c7c7cddddddddcc7c7c7ccc7c7c7c00000000
11188881eeeeffff77777777d45954dd7dcdcdcd4444444400aa00aa0aaaaaaa7ccccccd08800880000bb000700cc00ddddbbddd7ccccccd7ccccccd00000000
88899998eeeeffff77777777d45954ddccccccc1949494940aa00aa00aa00aa0ccc00cc15885588555bbbb55c00cc001ddb333ddcccaacc1cccaacc100000000
999aaaa9eeeeffff77777777d45945dd7dcdcdcd99999959aa00aa00aaa00aa07cc00ccd000880000bb00bb07cc00ccddb3ddb3d7caaaacd7ccaaccd00000000
aaabbbbaffffeeee77777777d54945ddccccccc19a9a9a5aa00aa00aaaaaaaaaccccccc1555885555bb55bb5ccc00cc1db3ddb3dcccaacc1ccaaaac100000000
bbbccccbffffeeee77777777d59995dd7dcdcdcd55a0aa5000aa00aa0aa00aaa7cc00ccd0880088000bbbb00700cc00ddd3bb3dd7ccaaccd7ccaaccd00000000
ccceeeecffffeeee77777777d54945ddccccccc15000a0000aa00aa00aaaaaa0ccccccc158855885555bb555c00cc001ddd33dddccccccc1ccccccc100000000
eee1111effffeeee77777777d77477ddcd1d1d1d00000000aa00aa00aa00aa00cd1d1d1dd000000dd000000dcd1d1d1dddddddddcd1d1d1dcd1d1d1d00000000
777777777777777f7f9ff490ffffffff7777777f777777774444ffffffffffff7f9ff4902929dddddddddddd99999999dddddddddd0ddddddddd0ddd00000000
7ffffffffffffff47f9ff490944440407ffffff4766666674444ffff944440407f9ff4909299044dd444444d92299229dd999fddd0900ddddd0090dd00000000
7ffff9ff7ffffff47f9ff4907f9ff4907ff7fff4777777774444ffff7f9ff4907f9ff4902929404dd4aaa94d92229299d9fdd9fd0909900d0099090d00000000
7faffffffffffff47f9ff4907f9ff4907ffffff4766666674444ffff7f9ff4907f9ff4909999004dd4a9a94d99222999d9fdd9fd0900090d0900090d00000000
7ffffffffafffff47f9ff4907f9ff4907ffffaf477777777ffff44447f9ff4907f9ff490d040404dd4aaa94d99922299d9fdd9fd0900090d0900090d00000000
7fffff7fffff9ff47f9ff4907f9ff4907f9ffff476666667ffff44447f9ff4907f9ff490d400004dd499994d99292229d9fdd9fdd09990ddd09990dd00000000
7ffffffffffffff47f9ff490777779797ffffff477777777ffff44447f9ff49077777999d444444dd444444d92299229dd999fdddd000ddddd000ddd00000000
f4444444444444447f9ff490fffffffff444444477777777ffff44447f9ff490ffffffffdddddddddddddddd99999999dddddddddddddddddddddddd00000000
55555555994499496565656594994994dd000ddddd000ddd0dddddddddddddd7d77777777777777dd550055ddd5005dddddddddd0dd7dddddddddddd99799499
50c00006444594445050505044444444d09990ddd09990dd00dddddddddddd77dd777777777777ddd500005dd500005ddddddddd9797dddddddddddd9da994d9
5c0101064445444456565656444444440990990d0900090d000dddddddddd777dd777777777777dddd0000ddd56ee65ddddddddd7577007dddddd0d7d9a9949d
501000064444944405050505444444440990990d0900090d0000dddddddd7777ddd7777777777dddddd00ddd65622656ddddddddd7777007d7077979dd9945dd
500010064445944465656565444444440990990d0900090d00000dddddd77777dddd77777777ddddddd00ddd556226557d7dddddd700777770077757ddd94ddd
50100006444544445050505044444444d09990ddd09990dd070700dddd777777ddddd777777ddddddd0000dd50200205979777ddd70777777770777ddd7a94dd
50000006444594445656565644444444dd000ddddd000ddd0007000dd7777777ddddddd77ddddddd06000060560ee065d77777ddd7dddd7007700777ddd94ddd
56666666455545550505050555455455dddddddddddddddd7077707777777777ddddddddddddddddddddddddddd00ddddd7dd7dddddddddd07ddddd7d444500d
__gff__
0000000000000000000000000000000000000000000000000000000000200000000001010101010101010101010000000101010101010101000101010100000001010101010101010101000000000000010101010101010101010100000000000101010101010101000000000100010101010101010101010101000001010100
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101010101010101010100000001010101404001000001000101000101010101014001010000010000000000000100000000000000000000000000
__map__
30303030303030303030303030303030303030303030313030303030303030313030393a3653505050505050505243404b4b4b44000037363c3665666767676700000000000000005900000000585900585a586c596c6c6c6c6c6c6c6c6c6c6c7e7f7e7f7e7f7e7f7e7f7e7f7e7f707c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c
333430303030303130303030303230303130303030303b303030303030303030393a36513651382100000000005143454b6e4b4a000000003736360062636464005800590000580000590058005c5b5b5b5b5b5b5b5c5c5d5d5d5c5c5b68696c7000000000000000000000000000007c7cd1d1d1d17c7cd1d1d1d1d17cd1d17c
3c363334303b32303030303030303031303230393a3536333a2c36333432393a353637513651000000535050005143404b4b6e4a6f006f00004a35363636606100000000585a005a005a0000005a5a5b6c6c6c6c6c6c6c6c5d6c5d5d6c6a6b0000000000000000007a0000007000007c7cd1d1d17c7c7cd1d17c7cd17cd1d17c
362c35363c3636333a3c36363533343030393a363c2c363c353836372c38363600370051365100000051000000514340444b4a6e21000000004a4b3c4c4c373c0059005900000000000059005a00005c6c2f1e1e1e1e1e6c5c6c6c6c6c6c5b000000700000000000000000000000007c7cd1d1d1d1d1d1d17cd1d1d1d1d1d17c
2c38213c2135373637232424242535333a353737373c3700373c37353737373c210000513751000000510051005550504b4a6f38006f6e006e424b4b4c4d4e44005a00005a58000059005900580058596c2f6c6c6c6c2e6c5b6c5d5c5d6c5c6c0000000000007a00000070000000007c7cd1d1d1d17cd1d17cd17cd1d17cd17c
363c362c3836363c353821002138363c000000003800210000000021000000510000215100512e2e2e51005121004a4b4b6f38216f00006e4a4b6e4c44424e4f000059005c5c5a5900000058590000006c2f6c68696c2e6c5c6c5c5b5c6c5d6c7a00000070000000000000000000007c7cd17c7c7c7cd17c7cd17cd17c7cd17c
3737373c371d35003737373737373737005350545050505054505050501d00510000385135512e2e2e510055505050524a00216f00006e41424b4b4c4d4e444f005a00595a5c5b5b595a0000005a00006c2f6c6a6b6c2e6c5d6c5d5c5d6c5d0000000000000000007600007a0071007c7cd1d1d1d17cd1d1d1d17cd1d1d1d17c
27000021000000000000002100000000005138510000000051000000000000510021385100512e2e2e510000000000516f006f00006f004a4b6e4c44424e4f4f0058000000585b6869590000590000586c2f6c5b5b6c2e6c6c6c6c6c5c6c5c6c00007a0000007b7a0000000000000000d1d1d1d1d17cd1d1d1d1d1d1d1d1d1d1
26270000000053505050505050505050005100512f00510051005050501d505600505057505600000055505050500051000000006f00006e4b434c434e444f445a00005a0000596a6b5b5800000058005b5b6c68696c5c5d2f2f2f5b5b5c5c6c0000000000000000007000000071007c7cd1d17cd1d1d171d1777cd1d1d1d17c
26262700000051000021000000000000005100512f215100510048490000000000001f1f1f00002100001f1f1f0000516f6e420021006e4a4b434d434e4f445e000058000000585a5b5b5c59590059005c6c5b6a6b6c5c6c2f2f2f6c5c6c5c6c0000000000700000000000000000007c7c7cd1d1d17cd1d1d1d17cd1d1d1d17c
22292200210051000000000000005100215100512f00510051004647001d505200001f1f1f00213821001f1f1f002151002100386e424a4b444c4d4e445f5f5e000000595800000058595c5c005800005d6c5c6c5b6c5c6c2f2f2f6c5d6c5d6c0000000000000000000000700000007c7c7cd17c7c7cd17c7c7c7cd17c7cd17c
222a22000000380000000021000051000051000000005100510000213800005100001f1f1f00002100001f1f1f0038516f6e4200004a6e4b4c444e444f5f445e5859005a0059005900005958000059005c6c5d6c5c6c5b6c2f2f2f6c5d6c5d6c000000700000007a000000000000007c7cd1d1d1d1d1d1d1d1d17cd1d1d1d17c
22222250505050505050505200005100005550505050560055505050501d005100505054505000000050505450500051000000006f4a4b6e4c434e435f445e5d00000058005a000000000000590058005b6c5c6c5d6c5b5b5b5b5b6c6c6c6c6c0000000000000000000000000070007c7cd17cd1d17cd1d17cd1d1d17cd1d17c
2922220000000000000000510000513800000000000000210000000000002151000000514442000000444251363700516f006f21006e4b4c4d434f435f5e445d005a5900000058005800595a000000005b5b5b6c5c6c6c6c6c6c6c6c68696c6c7d7d7700007a0000000000000000007c7cd1d1d1d17cd1d1d17c7c7cd1d1d17c
2a2222210000000000000051000051000021535054505238535054505200005100000051434521001d434051444242510000006f4a4b6e4d4d434f5f5e5e5d440000000058005a00005a0000580059005d6c6c6c5b5b5c5d005d5c5b6a6b5b5b00000000000000000000000000007a7c7cd17cd1d1d1d1d1d1d1d1d1d1d17c7c
222228380000000021380000002100005050563851005550560051215550505600000051434042424241405143454051000000004a4b4c6e4d4342425e445d4300585a000000005800000000000000005d5d5d5d5d6c6c6c6c6c6c6c6c595a587d0000000000000000000000007a707c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c
7e7f7e7f7e7600000000007a0000727f0000000000e0e1000000000000e4e0e120000000000000000000000000000000000000000000000000000000000000002f1dc7ccc8decbd4d4cb000000000000d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d50000d6d6d6d6d6ded6d6d6d6d6d6d4d400310000000000003200000031320000
7978787800000000707b00000000007900e4e0e100000000e0e1e0e100004be400000000000000000000000000000000000000000000000000000000000000002f1dcbdecb00c9ccccca00c7ccccc8004c4bd8d6d6d6d6d6d6d6d6d6d6d6d61d0000000000000000000000000000d4e4f2f2f3f2f2f2f2f2f2f2f2f2f2f2f2f2
d30000000000007000727300700000740000e4000000e4000000000000e44ce400000000000000000000000000000000000000000000000000000000000000002f1dc9ccca001f1f1f1f2fcbdddecb004b4a00000000d400d44a4b4c4d4e4fd6d6002d2d2f2f2d2dd4d42d2dd4d400e6f2f0f0f2f0f0f2f0f0f2f0f0f2f0f0f2
74007000007273000000000000000000e300e300e300e3e0e1e0e100e0e14ee400000000000000000000000000000000000000000000000000000000000000002fc7c8d4d4d42ec7ccc82fcbd4d4cb004a00d400d4d4d4d6d4d6d4d4d44f5fd6d6002d2d2f2f2d2dd4d42d2dd4e400e6f2f0f0f1f0f0f1f0f0f1f0f0f1f0f0f2
000000700000000000000000000076000038000000210000006fe44b4d4f5f5e0000000000000000000000000000000000000000000022222222000000000000d6c9cad4d4d42ecbddcb2fc9ccccca00d90000dbd6d6d6d6d6d6d6d7d45f5ed6d6001f1f2d2d2f2f2d2dd4d42f2d00e6e0e1e0e1f0e1e0e1e0e1e0e1e4f3e0e1
000000000000000000d3000000000000e30044424200e3e4e0e1e0e1e0e14fe40000000000000000000000000000000000000000000000000000000000000000d6d4d42f1e1e2dc9ccca2d1e1e1e00000000d4d6d4d4d4d6ddd6d4d6d45ed9d6d6001f1f2d2d2f2f2d2dd4e42d2f00e6e7f1f3e7f3f1f3f1f3f1f3f1e7f1f3e7
770000710000710000710071007100000000434045004a4c4d4e4f5f5ee44de40000000000000000000000000000000000000000220000000000002200000000d6d4d42fc7c82e1e1e2dc7ccc82ec7ccd4d6d4d6d4d7d6d6d6d6d4d6d45dddd6d6002d2d1f1f2d2d1e1e2d2d2f2d00e6e2f0f0e2f0f0e7f0f0e7f0f0e2f0f0e2
000000000000007a00000000000000e3000043404000e3e0e1e0e1e45de44be400000000000000000000000000000000000000002200ec0000ec002200000000d6d4d42fc9ca2e44422fcbd8cb2ecbd4d4d7d4d6d4d6d4d6d4d6d4d6d4d4d4d4dd002d2d1f1f2d2d1e1ed42d2d2f00e6e2f0f0e2e5f0e8f0f0e2f0f0e2f0f0e2
7a000000000000007a00000000007a000000434040384a4b4d4e4f5f5ee400e400000000000000000000000000000000000000002200002b2700002200000000d61fd42d1f1f2e43402fc9ccca2ecbde0000d6d6d6d6d6d7d6d6d6d6d6db0000d600d4d42d2d2f2fd4d42f2f2f2d00e6e2f0f0e2f0f0f3f0f0e2f0f0e2f0f0e2
007600710000710000710071007100e3e30043454721e3e4e0e1e0e1e0e100e400000000000000000000000000000000000000002227002626002b2200000000d62ecd2fd400001f1f1f2fd41f2ec9ccd4d7d4d6d4d6d4d6d4d6d4d6d4d4d4d4d600d4d42d2d2f2fd4e42f2f2d2f00e6e2f3f1e2e0e1e7f3f1e2f1f3e2f3f1e2
000000760000750000750000007600000000002100000000e400000000004b4d0000000000000000000000000000000000000000002626262626260000000000002e1e1e0000002ec7c82fd4d4000000d4d6d4d6d4d6d6d6d6d7d4d6d45dd4d6d6002d2dd4d42dde2f2f2d2d2f2d00e6e2f0f0e2f0f0e2f0f0e2f0f0e2f0f0e2
00700000000076000072727300000000e300e300e300e300e400e44be0e100e40000000000000000000000000000000000000000000022222222000000000000d6002f1e1e00dd2ec9ca2fd4d4c7ccc80000d4d6d4d6d4d6d4d4d4d6d45ed9d6d6002d2dd4e42d2d2f2f2d2d2d2f00e6e2f0f0e2f0f0e2f0f0e2f0f0e2f0f0e2
000000007a0000000000000000000000e400e46ee40000000000e44d4fe400e40000000000000000000000000000000000000000000000000000000000000000d6002fcd2e2f1e2e1e1e1ed4d4cbd4cbde00d4d7d6d6d6d6d6d6d6db4f5f5ed6d600d4d42f2d2f2d2f2d2f2d2f2d00e6e2f0f0e2f0f0e8f0e5e2f0f0e2f0f0e2
0000700075000075007a7b7a00007000e400e4e0e1e0e1e0e1e0e1e0e1e0e1e40000000000000000000000000000000000000000000000000000000000000000d600d41f2e2fcdd4d4d4d4c7c8c9ccca4a00d4d4d400d4d6d4d4d44dd44f5fd6d600d4e42d2f2d2f2d2f2d2f2d2f00e6e8f0f0e8f0f0f1f0f0e8f0f0e8f0f0e8
00000000740000760000000000000000e40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d6000000001f1f2ed4d4d4c9ca1d1d1d4b4a00000000dd00004a4b4c4d4e4fd6d4d4000000000000000000000000e4e6e4f1f3f1f3f1e4f1f3e4e6f1e4f1f3e4
00700000000000000072797973000000e0e1e0e1e0e1e0e1e0e1e0e1e0e1e0e10000000000000000000000000000000000000000000000000000000000000000d4d6d6d6d6d7d6d6d6d6d6d6d6d6d6d64c4bd8d6d6d6d6d6d6d6d6d6d6d6d61dd4e400e6e6e6e6e6e6e6e6e6e6e6e600f1f3e0e1e0e1e0e1e0e1e6e6e6e6e0e1
__sfx__
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000905509005090550905509005090550905509005040550400504055040550400504055040550400500055000050005500055000050005500055000050b0550b0050b0550b0550b0050b0550b0550b005
001000000963309603396332160308603096232d6230960309633046032d63327603046030962321623046030963300603396330060300603096232d62300603096330b6032d6330b6030b603096232162321603
0010000021760217652170023760247602476521765217002376023765247652376521760217611c7611c70123760237651c7001c7601c765277002376023765237001c7601c76523700177651c7652376528765
001000000960309603396032160308603096032d6030960309603046032d60327603046030960321603046032163300603396030060300603096032d60300603096030b6032d6030b60321613216132162321633
0010000024754247543475424754247542475428754247541f7541f754237541f7541f7541f754237541f7541c7541c7541f7541c7541c7541c7541f7541c7541a7541a7541a7541e7541a7541a7541e7541a754
001000000a600316000f600146001a600216002160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000c74015700137201270018710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
01030000187401570013720127000c710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
0103000013740157000c7201270018710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
010300000c74015700187201270013710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
010c000024770287702b77024770287702b7703076030755307453073524705007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00060000351202f15029170231601d15017140111300b120051102a100121001d1000f100181000c1000f10008100081000410001100021000010000100001000010000100001000010000100001000010000100
001000000305000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001a7701e7701f7701e770217702377024770267701f7701f7701f7701f7751f7651f7551f7451f73500700007000070000700007000070000700007000070000700007000070000700007000070000700
000300000763007650076300a60024630246502463024610006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
__music__
00 41424344
01 01515244
00 01515244
00 01054444
00 01050444
00 01050244
00 01050244
00 01020344
00 01020344
00 01024344
00 01024344
00 01020344
00 01020344
00 01050244
00 01050244
00 01020344
02 01020344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424351
00 41426044

