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
	game_version = "07"
	level = 1
	last_level = 16
	selected_level = 1 -- used in menu
	debug_mode = false -- shows debug info and unfogs each level
	debug_text = "debug mode"
	win = false
	lose = false
	in_game = false -- determines whether a level is in progress
	title_active = true
	levelling_up = false
	spotlight = false
	hints_active = false
	credits_active = false
	t = 0 -- game time in frames
	unfog_frames = 3 -- how fast the unfogging happens
	caption_frames = 3 -- how fast the captions move
	cat_frames = 1 -- number of frames between each cat move animation
	menu_items = 7
	medal_text = {"gold", "silver", "bronze", "none"}
	medal_sprite = {12, 13, 14, 15}
	anim_frame = 0 -- allows sprites to animate
	offset = 0 -- screen offset for shaking
	move_step = 9 -- variable governing move animation
	moving = false
	play_music = true
	play_sounds = true
	ice = false
	x = 64
	y = 24
	dx = 0
	dy = 0
	dir = "r"
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
	if moves <= 0 and in_game then game_lose() end
	if win and mab_small_x < 16 then -- animate mab at end
		mab_retreat_step()
	end

	if btnp() != 0 or sliding then
		-- a button has been pressed
		if title_active then
			title_active = false
			level_reset() -- start current level
		elseif level_start_menu then
			if btnp(4) then level_start() end
			if btnp(5) then
				level_start()
				menu_open()
			end
		elseif in_game then
			if not moving then
				move_process()
			end
		elseif menu_active then
			menu_process_input()
		elseif levelling_up then
			level_end_process_option()
		elseif lose then
			if btnp(4) then
				lose = false
				level_reset()
			else return end
		elseif win == false and lose == false then -- start new level
			level_reset()
		elseif win and not credits_active then
			draw_credits()
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
	if title_active then draw_pandora() return end
	if not in_game and not menu_active and not level_start_menu then return end

	shake_screen()
	draw_everything()
end

-- conventions: map is zero-based, arrays are 1-based.

-- to do next
-- enhance music
-- animate some background cells eg torch, water

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
	rectfill(34, 78, 94, 106, 0)
	rect(33, 77, 93, 105, 14)
	print("⬆️⬇️⬅️➡️  move", 36, 80, 15)
	draw_controls("z", 36, 88)
	draw_controls("x", 36, 96)
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
	hints_active = false
	socky_add = 0
	move_step = 9 -- to avoid cat sliding back across screen
	anim_frame = 0 -- so that each level starts the same way
	level_period = #obs_data[level]
	dir = "r" -- current direction
	selected_level = level
	unfog_reset()
	obstacle_update()
	switch_reset()
	unfog_circle()
	draw_everything()
	in_game = false
	level_start_menu = true
end

function level_start()
	if level == 16 then level_16_reset() end
	if debug_mode then unfog_start() end
	level_start_menu = false
	in_game = true
	sfx(-1) -- stop playing sound
	if play_music then music(level_music[level]) end -- main theme
end

function level_16_reset()
	mab_reset()
	mabx = 0
	maby = 0
	mab_active = false
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
		draw_pandora()
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
		level_reset()
	end
end

function game_win()
	rectfill(0, 16, 127, 79, 0)
	local perfect = true
	for k in all(best_medal) do
		-- if any medal is not gold then it's not perfect
		if k != 1 then perfect = false break end
	end
	if perfect then
		for i=0, 15 do -- draw rainbows
			spr(208, i*8, 8)
			spr(208, i*8, 112)
		end
		spr(255, 96, 24) -- trophy
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
	sfx(-1)
	music(-1)
	local lose_text = "pandora is sleepy - try again"
	local lose_colour = 2
	in_game = false
	if mab_hit then
		lose_text = "mab got you"
		lose_colour = 8
		mab_hit = false
	end
	rectfill(0, 40, 127, 79, lose_colour)
	spr(1, 8, 64, 1, 1, false, true) -- upside down cat
	draw_controls("z", 96, 64)
	print3d(lose_text, 8, 48, 10, 0)
	if play_sounds then sfx(51) end
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

-- music
-- 01 main bass
-- 02 upbeat drum
-- 03 main melody
-- 04 intro drum
-- 05 descending backing
-- 06-10 dark and final boss
-- 11 start of final zone
-- 12-14 ice
-- 15-17 machine

function move_process()
	newx = x
	newy = y
	if not sliding and not btnp(5) then anim_frame += 1 end
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
		if play_sounds then 
			if level != 16 then sfx(48)
			else sfx(52) end
		end -- level end tune
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
	-- set switch to open
	switch[6] = to_open -- set switch/door data to open
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
		offset = 1
		mab_active = true
		mab_eyes_open = false
		mab_hit = false
		debug_text = "mab start"
		mabx = a
		maby = b
		if play_sounds then sfx(50) end
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
	-- move mab slowly across top right
	if (t - mab_start_time) % 30 != 29 then return end
	debug_text = "move mab"
	mab_small_x += 1
	rectfill(64, 0, 127, 7, 12)
	map(120, 16, 8, 0, 16, 0)
	draw_pandora()
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
	draw_hints()
	draw_pandora()
	draw_level_start_menu()
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
	if level == 1 then spr(252, 80, 24) end
	if level == 16 then
		spr(27, 56, 0) -- draw mab socky
	else -- draw goal
		spr(24, 120, goal_height[level] * 8)
	end
end

function draw_level_start_menu()
	if level_start_menu == false then return end
	debug_text = "level start menu"
	rectfill(0, 40, 127, 87, 0)
	rect(-1, 40, 128, 87, 10)
	print("level "..tostr(level), 8, 48, 7)
	print(level_name[level], 8, 56, 14)
	print(level_hint[level], 8, 72, 8)
	if level_hint_sprites[level] != "" then
		draw_controls(level_hint_sprites[level], 8, 72)
	end
end

function draw_controls(control, a, b)
	-- draw "z/o" or "x/x" at coordinates a, b
	if control == "z" then
		spr(194, a, b)
		spr(193, a+16, b)
	elseif control == "x" then
		spr(195, a, b)
		spr(192, a+16, b)
	end
	spr(196, a+8, b)
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

function draw_pandora()
	if spotlight then
		circfill(x+dx+3, y+dy+3, 5, 10)
		circfill(x+dx+3, y+dy+3, 4, 9)
	end
	local blinktime = t % 150
	if (blinktime >= 120 and blinktime < 123)
	or (blinktime >= 126 and blinktime < 129) then
		pal(10, 0) -- make eyes black
	end
	if dir == "u" then spr(5 + anim_frame%2, x+dx, y+dy)
	elseif dir == "d" then spr(3 + anim_frame%2, x+dx, y+dy)
	elseif dir == "l" then spr(1 + anim_frame%2, x+dx, y+dy, 1, 1, true, false) -- flip r sprite
	elseif dir == "r" then spr(1 + anim_frame%2, x+dx, y+dy) -- dir == "r" or default
	end
	reset_palette()
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
	rectfill(120, 0, 126, 5, level_bg[level])
	print3d(tostr(moves), 128 - #m*4, 0, level_hint_colour[level], 0)
end

function draw_menu()
	if menu_active == false then return end
	local music_status = "on"
	local sounds_status = "on"
	local spotlight_status = "on"
	local hint_status = "on"
	if not play_music then music_status = "off" end
	if not play_sounds then sounds_status = "off" end
	if not spotlight then spotlight_status = "off" end
	if not hints_active then hint_status = "off" end
	draw_menu_outline()
	draw_controls("x", 104, 16)
	print("retry level", 24, 20, 8)
	print("spotlight is "..spotlight_status, 24, 28, 9)
	print("hints are "..hint_status.." this level", 24, 36, 10)
	print("music is "..music_status, 24, 44, 11)
	print("sounds are "..sounds_status, 24, 52, 12)
	print("jump to level "..selected_level, 24, 60, 14)
	print("close", 24, 68, 8)
	spr(24, 8, 11 + menu_option * 8)
	spr(25, (selected_level - 1) * 8, 104)
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

function draw_hints()
	if not hints_active then return end
	-- draws a sequence of numbers guiding the player
	local i = 1
	for k in all(level_hints[level]) do
		print3d(tostr(i), k[1]*8 + 2, k[2]*8 + 1, level_hint_colour[level], 0)
		i += 1
	end
end

function draw_credits()
	rectfill(0, 16, 127, 111, 0)
	print("pandora", 8, 24, 10)
	print("by andrew hick .com", 40, 24, 9)
	print("tested by:", 8, 40, 15)
	print("2bitchuck alan alex clive", 8, 48, 14)
	print("dan frieda iris joe", 8, 56, 8)
	print("kittycat mum naomi tim", 8, 64, 11)
	print("and victoria", 8, 72, 12)
	spr(11, 60, 71)
	print("thanks for playing :)", 8, 88, 10)
	credits_active = true
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
	menu_option = 1 -- current selected option
	-- set menu sprite for each cell
	-- allow menu to be opened and closed using button 2
	caption_show("menu", 2, 8, 14)
	in_game = false
end

function menu_process_input()
	if btnp(⬆️) then menu_option -= 1
	elseif btnp(⬇️) then menu_option += 1
	elseif btnp(4) or btnp(⬅️) or btnp (➡️) then menu_choose()
	elseif btnp(5) then menu_close()
	end
	if menu_option > menu_items then menu_option = 1 end
	if menu_option <= 0 then menu_option = menu_items end
end

function menu_choose()
	if menu_option == 1 and btnp(4) then level_reset()
	elseif menu_option == 4 then
		if play_music then
			play_music = false
			music(-1)
		else
			play_music = true
			music(level_music[level])
		end
	elseif menu_option == 2 then
		spotlight = not spotlight
	elseif menu_option == 3 then
		hints_active = not hints_active
	elseif menu_option == 5 then
		if play_sounds then
			play_sounds = false
			sfx(-1)
		else
			play_sounds = true
			sfx(41)
		end
	elseif menu_option == 6 then
		-- todo level select
		if btnp(⬅️) then
			selected_level -= 1
			if selected_level <=  0 then selected_level = 16 end
		elseif btnp(➡️) then
			selected_level += 1
			if selected_level > 16 then selected_level = 1 end
		elseif btnp(4) and selected_level != level then menu_close() end
	elseif menu_option == 7 then
		menu_close()
	end
end

function menu_close()
	menu_active = false
	in_game = true
	if selected_level != level then -- jump to a new level
		level = selected_level
		level_reset()
	end
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
	level_name = {
		"catflap",
		"mildly offensive",
		"spiky junction",
		"sunset swamp",
		"sparkly cavern",
		"dark dungeon",
		"ice spiral",
		"battenberg castle",
		"frozen maze",
		"bath house",
		"the gorgon",
		"limestone garden",
		"the mangle",
		"the factory",
		"alternation",
		"mab showdown"
	}
	level_hint = {
		"       ok",
		"       menu",
		"go with the flow",
		"hints available in menu",
		"lost? use spotlight",
		"       to wait",
		"sliding is fun",
		"don't repeat yourself",
		"faces good, cracks bad",
		"three switches and a socky",
		"just go with it",
		"look for the stopping points",
		"       really helps",
		"sw ne nw se s n w e",
		"pick a direction and go",
		"face your nemesis"
	}
	level_hint_sprites = {
		"z", "x", "", "", "", "z", "", "",
		"", "", "", "", "z", "", "", ""
	}
	level_bg = {3, 3, 3, 3, 0, 0, 12, 14, 12, 4, 4, 3, 5, 5, 4, 12} -- level background colour
	level_music = {1, 1, 1, 18, 18, 18, 26, 26, 26, 1, 1, 1, 34, 34, 34, 17}
	goal_height = {7, 9, 5, 10, 1, 14, 7, 7, 8, 14, 3, 2, 10, 8, 15, 0} -- cells from top of screen, base 0
	fog_height = {7, 6, 1, 1, 1, 3, 3, 1, 3, 1, 1, 3, 10, 2, 1, 4} -- cells from top of screen, base 0. must be >= 1
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
		{4, 15}, -- 11
		{0, 3}, -- 12
		{15, 1}, -- 13
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
		{0, 112}, -- 11
		{0, 8}, -- 12
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
		-- [1] minimum moves needed to complete level without socky
		-- [2] minimum moves needed to complete level with socky
		-- excluding socky bonus, subtract 10 from final score when calculating this
		-- [3] moves allowed for each level (default [1] + 5 but add more if harder)
		-- [4] remaining points needed for gold
		-- [5] remaining points needed for silver
		-- [6] remaining points needed for bronze (default 5, get through level as quick as poss without socky)
		-- if increasing the number of allowed moves by m,
		-- 1 and 2 won't change, and increase 3,4,5,6 by m. 
		{34, 44, 44, 20, 15, 10}, -- (+5 moves compared to v6)
		{30, 62, 40, 20, 15, 10}, -- +5
		{28, 28, 38, 20, 15, 10}, -- +5, level 3 is quickest with socky
		{43, 53, 53, 20, 15, 10}, -- +5
		{80, 94, 95, 25, 20, 15}, -- +5. extra leeway as level is complex
		{68, 76, 98, 40, 35, 30}, -- +11. perfect is 68 with shortcuts, 82 without shortcuts. So to be fair, moves allowed = 82 + 16.
		{15, 22, 25, 20, 15, 10}, -- +5
		{21, 26, 36, 25, 20, 15}, -- +10
		{21, 22, 41, 30, 25, 20}, -- +11
		{74, 94, 94, 30, 25, 20}, -- +10
		{28, 35, 43, 25, 20, 15}, -- +10
		{34, 42, 59, 35, 30, 25}, -- +15
		{33, 41, 63, 40, 35, 30}, -- +15
		{52, 62, 82, 40, 35, 30}, -- +15
		{18, 19, 43, 35, 30, 25}, -- +15
		{65, 73, 80, 25, 20, 15} -- +10 
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
				{1, 7}, {7, 8}, {1, 9}
			},
			{}, {} -- nothing in remaining 2 periods
		},
		{ -- level 15
			{}, -- placeholders for each period, see below
			{},
			{},
			{}
		},
		{ -- level 16
			{{13, 13}, {13, 11}, {13, 10}, {14, 13}, {14, 12}, {14, 10}},
			{{13, 13}, {13, 12}, {13, 10}, {14, 12}, {14, 11}},
			{{13, 12}, {13, 11}, {14, 13}, {14, 11}, {14, 10}}
		}
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
		-- {10, 6}, {11, 6}, {11, 7}, commented to give respite
		{4, 8}, {5, 8}, {4, 9}, {5, 9},
		{2, 10}, {3, 10}, {2, 11}, {3, 11},
		-- {6, 10}, {6, 11}, {7, 11},
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
		{{16}}, -- 16 means no switches
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
		{
			{1, 12, 3, 2, 233, false},
			{10, 12, 3, 15, 233, false},
			{6, 7, 13, 3, 233, false},
			{9, 7, 3, 13, 233, false}
		},
		{
			{12, 12, 1, 6, 233, false},
			{6, 4, 12, 5, 233, false},
			{1, 10, 12, 7, 233, false},
			{3, 2, 10, 7, 233, false},
			{10, 6, 14, 2, 217, false}
		},
		{{16}},
		{ -- level 14
			{14, 5, 3, 4, 217, false},
			{0, 4, 11, 12, 217, false},
			{14, 11, 13, 8, 217, false}
		},
		{{16}},
		{{16}}
	}
	level_hints = { -- coordinates, number
		{{15, 13}, {6, 7}}, -- 1
		{{2, 11}, {12, 11}}, -- 2
		{{7, 10}, {12, 1}}, -- 3
		{{4, 4}, {14, 4}, {10, 14}}, -- 4
		{{13, 15}, {0, 2}, {13, 8}}, -- 5
		{{14, 1}, {12, 6}, {6, 8}, {0, 13}, {4, 14}}, -- 6
		{{14, 14}, {11, 12}, {2, 15}, {12, 12}, {10, 10}, {8, 8}}, -- 7
		{{2, 11}, {11, 1}, {3, 3}, {6, 5}, {6, 14}, {13, 3}}, -- 8
		{{14, 5}, {10, 10}, {8, 14}, {8, 6}, {2, 15}, {5, 11}, {13, 0}, {1, 2}, {1, 8}}, -- 9
		{{1, 3}, {7, 1}, {14, 10}, {6, 8}, {1, 11}}, -- 10
		{{1, 9}, {3, 9}, {5, 9}, {9, 6}, {6, 8}, {5, 15}, {12, 3}}, -- 11
		{{11, 12}, {8, 4}, {0, 5}, {4, 14}, {4, 2}, {10, 14}, {9, 10}, {10, 9}, {12, 14}, {13, 2}}, -- 12
		{{0, 10}, {5, 10}, {6, 9}, {10, 1}, {14, 5}, {13, 10}}, -- 13
		{{5, 14}, {9, 2}, {14, 4}, {0, 3}, {14, 12}, {7, 14}, {7, 3}, {1, 8}, {14, 8}}, -- 14
		{{6, 1}, {6, 14}, {3, 15}}, -- 15
		{{1, 10}, {7, 13}, {5, 8}, {9, 5}, {10, 15}, {13, 3}, {2, 1}} -- 16
	}
	level_hint_colour = {10, 10, 10, 9, 9, 9, 7, 7, 7, 7, 7, 7, 14, 14, 14, 7}
	ice_data = {false, false, false, false, false, false, true, true, true, false, false, false, false, false, false, false}
	level_sprites = {34, 49, 80, 100, 88, 91, 113, 209, 118, 227, 239, 61, 205, 214, 222, 244} -- for progress bar
	best_medal = {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4} -- best medal for each level so far, 1=gold, 4=none
end

--[[ some characters
a█ b▒ c🐱 d⬇️ e░ f✽ g●
h♥ i☉ j웃 k⌂ l⬅️ m😐 n♪
o🅾️ p◆ q… r➡️ s★ t⧗ u⬆️
vˇ w∧ x❎ y▤ z▥
]]--

__gfx__
00000000ddd0dd0ddddddddddd0dd0ddddddddddd0dd0ddddddddddd0000000000000000000000000000000008800880a00000a0700000700000000000000000
00000000ddd0a0adddd0dd0dd00a0add5d0dd0ddd0000dddd0dd0ddd00000000000000000000000000000000888888889aa0aa90670007609900099050000050
00700700d000000dd000a0add00000dd000a0addd00000ddd0000d5d00000000000000000000000000000000877888889a0aa090607770604499944000505000
00077000000000dd0000000dd00000dd000000ddd00000ddd000000d000000000000000000000000000000008788888890090090600600604004004050000050
00077000000000dd000000ddd00000ddd00000ddd00000ddd000000d000000000000000000000000000000000888888049909940666666602444442000000000
00700700000000dd0000000dd50000ddd00000ddd00000ddd00000dd000000000000000000000000000000000888888004000400060006000240420005000500
0000000050ddd0dd0ddddd0ddd00d0dddd0d00dddd0d05dddd00d0dd000000000000000000000000000000000088880000444000006660000022200000050000
00000000dddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000000008800000000000000000000000000000000000
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111dddadddddddadddd00000000dddd282dddddfefdddd7dddddddddddddddddddd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111ddd99ddddda99ddd00000000dddd2820ddddfef0de2e28dddddddddddddddddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111111111111111111119a999addda999add00000000dddd1110dddd8880d27e800dddd8ddddddd8dddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111a999a99da999a99d00000000ddd12210ddd8ff807ee8220ddd8d0ddddddd8ddd
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111999a9950d59a900000000000dd112200dd88ff00d2820000ddd8ddddddd8d0dd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111d509950ddda990dd000000002122110df8ff880dd802020ddddd0ddddddd0ddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111111111111111111111111111ddd950dddd9990dd000000002112100df88f800ddd00000ddddddddddddddddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111dddd0dddddd000dd00000000d00000ddd00000dddddd0ddddddddddddddddddd
ddddddddddddddddffffff4f555555555555555555555555444444444dddddddffffff4fff7777ff4610011fddddddd4dd45554ddddddddddddddddddddddddd
ddddddddddddddddffffff4f555ffffffffffffffffff5552424242424ddddddfffff400ff7777ff4110011fdddddd24d4ffff43d8ddd8dddddddddddddddddd
ddddddddddddddddfffffffffffff0f0f0f0f0f0f0f0ffff44444444444dddddfffff405fff77fff4110511fddddd444df0f2f43dd0ddd0dddd8dddddddddddd
dddddddddddddddd44f44f44f4fff4f4f4f4f4f4f4f4ff0f424242424242dddd44f444504777777441155114dddd4242dfff0f4ddddddddddd8d8ddddd8d8ddd
ddddddddddddddddff4ffffff0fff0f0f0f0f0f0f0f0ff4f4444444444444dddff4ff4004110061f4115511fddd44444df3fff43ddddddddddd0d0ddddd8d0dd
dddddddddddddfddfffffffff0fff3f0f0f0f3f0f0f0ff3f24242424242424ddfffff4004110011f4115511fdd2424243f0f1f43d8ddd8dddddddddddddd0ddd
dddddddddfddddddff4ffffff4fff3fff4fff3fff4ffff3f444444444444444dff4ff4444116011f77777777d44444443fff1f3ddd0ddd0ddddddddddddddddd
ddddddddddddddddf444f44ffffddddddddddddddddddfff4242424242424242f444f44f4110011f7777777742424242d333d33ddddddddddddddddddddddddd
ccccccccccccccccccccccccccccccccccccccccddb35dddd533323d35333233ddddddddccccccccccccccccccccccccddbdd23d33333b3b0000000000000000
cccccccccccccccccccc76ccddccccccccccccccd33b35dd3355335333553353dddaddddccccccccccccccddccccccccd33d23bd3333b3b30000000000000000
cccccccccccc76ccccc76ccc3dddcccccccccccc3b3330dd5333303553333030ddbdddddccccccccccccddd3cc5ccccc323b335333333b3b0000000000000000
ccccccccc76c776ccccccccc3bddddcccccccccc3333335d3033333550333305ddddddddccccccccccdd333dcc5cccccd32052303333b3b30000000000000000
cccccccc7777766ccccccccc333333ddccccccccd305305d23355333d55050ddddddddddccccccccdd33b3d3cc5cccccb30320353b3b33330000000000000000
ccccccccc666c6cccccccccc3333335dddccccccd5d405dd33533030dddddddddbddddddccccccddd3333333c555cccc32300350b3b333330000000000000000
ccccccccccccccccc76cccccd3b33335ddddccccddd42ddd55333325ddddddddddddddadccccddb333333350c555cccc230505003b3b33330000000000000000
ccccccccccccccccccccccccd533350dddddddccddd42dddd2500550ddddddddddddddddccdd3dddd533350dc555ccccd00050ddb3b333330000000000000000
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
d77777777d7777dd777777777777777777777767d777777d7ee77ee754545a457777777777777777dddddd7d77d7d6dd66657666777777e7ddddddddddddd6dd
d77777777d1771dd777777767777777777777776d777767d777777774aaaa9a47777777777777777dddddddddd776ddd6665766677f77777dddddddddddd666d
d7777767777777777777777777777776d7776767d77777777e7777e75999999a7777777777777777d6dddddd6676777d5555655577777777ddddd77dd77666d6
77777676dd7117d77777777777677777777777767777777677eeee77499999957777777777777777dddddddddd76ddd677777776777777776dd777d777d7766d
77677766dd7776d7d7777777777777767777676d7777776777777777555559547777776777777777dddddddddd7d6ddd7666666577777c77d777777d777d7d76
7677766ddd7767ddd77767676767676d767676d67777777677777776000450007676767d77777777dddd6dddd6dd6ddd766666657a777777777777d777d7d7d7
d76766dddd6776dddd7676dd767676ddd7676d6d7777776dd767676dddd45ddd67d767dd67776777ddddddddddddd6dd65555555777777777d7d7d7d7d7d7d7d
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
11111111eeeeffff77777777d454545dcc7c7c7c54545454a00aa00aa00aa00acc7c7c7cd555555dd555555dcc7c7c7cddddddddcc7c7c7ccc7c7c7c00000000
11188881eeeeffff77777777d4aaa45d7dcdcdcd4444444400aa00aa0aaaaaaa7ccccccd08800880000bb000700cc00ddddbbddd7ccccccd7ccccccd00000000
88899998eeeeffff77777777d4a9945dccccccc1949494940aa00aa00aa00aa0ccc00cc15885588555bbbb55c00cc001ddb333ddcccaacc1cccaacc100000000
999aaaa9eeeeffff77777777d4a9955d7dcdcdcd99999959aa00aa00aaa00aa07cc00ccd000880000bb00bb07cc00ccddb3ddb3d7caaaacd7ccaaccd00000000
aaabbbbaffffeeee77777777da999a5dccccccc19a9a9a5aa00aa00aaaaaaaaaccccccc1555885555bb55bb5ccc00cc1db3ddb3dcccaacc1ccaaaac100000000
bbbccccbffffeeee77777777d599955d7dcdcdcd55a0aa5000aa00aa0aa00aaa7cc00ccd0880088000bbbb00700cc00ddd3bb3dd7ccaaccd7ccaaccd00000000
ccceeeecffffeeee77777777d009000dccccccc15000a0000aa00aa00aaaaaa0ccccccc158855885555bb555c00cc001ddd33dddccccccc1ccccccc100000000
eee1111effffeeee77777777dd450dddcd1d1d1d00000000aa00aa00aa00aa00cd1d1d1dd000000dd000000dcd1d1d1dddddddddcd1d1d1dcd1d1d1d00000000
777777777777777f7f9ff490ffffffff7777777f7777777722224444ffffffff7f9ff4902929dddddddddddd99999999dddddddddd0ddddddddd0dddb333000a
7ffffffffffffff47f9ff490944440407ffffff47666666722224444944440407f9ff4909299044dd444444d92299229dd999fddd0900ddddd0090dd00abb33b
7ffff9ff7ffffff47f9ff4907f9ff4907ff7fff477777777222244447f9ff4907f9ff4902929404dd4aaa94d92229299d9fdd9fd0909900d0099090d3a300ab3
7faffffffffffff47f9ff4907f9ff4907ffffff476666667222244447f9ff4907f9ff4909999004dd4a9a94d99222999d9fdd9fd0900090d0900090d33ab3303
7ffffffffafffff47f9ff4907f9ff4907ffffaf477777777444422227f9ff4907f9ff490d040404dd4aaa94d99922299d9fdd9fd0900090d0900090d33b33a33
7fffff7fffff9ff47f9ff4907f9ff4907f9ffff476666667444422227f9ff4907f9ff490d400004dd499994d99292229d9fdd9fdd09990ddd09990dd3333ab03
7ffffffffffffff47f9ff490777779797ffffff477777777444422227f9ff49077777999d444444dd444444d92299229dd999fdddd000ddddd000ddd3ab330b3
f4444444444444447f9ff490fffffffff444444477777777444422227f9ff490ffffffffdddddddddddddddd99999999dddddddddddddddddddddddda30abb30
55555555994499496565656594994994dd000ddddd000ddd0dddddddddddddd7d77777777777777dd550055ddd5005dddddddddd0cc7ccccdddddddd99799499
50c00006444594445050505044444444d09990ddd09990dd00dddddddddddd77dd777777777777ddd500005dd550055ddddddddd9797ccccdddddddd9da994d9
5c0101064445444456565656444444440990990d0900090d000dddddddddd777dd777777777777dddd0000ddd608806ddddddddd7577007cddddd0d7d9a9949d
501000064444944405050505444444440990990d0900090d0000dddddddd7777ddd7777777777dddddd00ddd66888866ddddddddc7777007d7077979dd9945dd
500010064445944465656565444444440990990d0900090d00000dddddd77777dddd77777777ddddddd00ddd578228750d7dddddc700777770077757ddd94ddd
50100006444544445050505044444444d09990ddd09990dd070700dddd777777ddddd777777ddddddd0000dd502002059790ddddc70777777770777ddd7a94dd
50000006444594445656565644444444dd000ddddd000ddd0007000dd7777777ddddddd77ddddddd0600006050722705d7770ddd7777cc7007700777ddd94ddd
56666666455545550505050555455455dddddddddddddddd7077707777777777dddddddddddddddddddddddddd6006dddd7d7ddd7cc7cc7c07ddd7d7d444500d
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111110110111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111110a0a111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111000000111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111110000001111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111110000001111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111110000001111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111115011101111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111111a1a1a1a111111111111111111111111111111111111111111111111111111111
111111111111aaaaaaa111111111aaaaaaa111111111aaaaaaa111111111aaaaa1a1a1a11111aaaaaaa111111111aaaaaaaaaaaa1111aaaaaaa1111111111111
1111111111aa1111111aa11111aa1111111aa11111aa1111111aa11111aa1111a1a1a1a111aa1111111aa11111aa11111111111111aa1111111aa11111111111
111111111a111aaaaa111a111a111aaaaa111a111a111aaaaa111a111a111aaaa1a1a1a11a111aaaaa111a111a111aaaaaaaaaaa1a111aaaaa111a1111111111
111111111a1aa11111aa1a111a1aa11111aa1a111a1aa11111aa1a111a1aa111a1a1a1a11a1aa11111aa1a111a1aa111111111111a1aa11111aa1a1111111111
11111111a11a11aaa11a11a1a11a11aaa11a11a1a11a11aaa11a11a1a11a11aaa1a1a1a1a11a11aaa11a11a1a11a11aaaaaaaaaaa11a11aaa11a11a111111111
11111111a1a11a111a11a1a1a1a11a111a11a1a1a1a11a111a11a1a1a1a11a11a1a1a1a1a1a11a111a11a1a1a1a11a1111111111a1a11a111a11a1a111111111
11111111a1a1a1aaa1a1a1a1a1a1a1aaa1a1a1a1a1a1a1aaa1a1a1a1a1a1a1aaa1a1a1a1a1a1a1aaa1a1a1a1a1a1a1aaaaaaaaaaa1a1a1aaa1a1a1a111111111
11111111a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a111111111a1a1a1a1a1a1a1a111111111
11111111a1a1a0a0a0a1a1a1a1a1a0aaa0a1a1a1a1a1a0a0a0a1a1a1a1a1a0aaa1a1a1a1a1a1a0aaa0a1a1a1a1a1a0a000000000a1a1a0aaa0a1a1a111111111
11111111a1a0a1a11a10a1a1a1a01a11a1a0a1a1a1a0a1a1a1a0a1a1a1a01a110a01a1a1a1a01a111a10a1a1a1a0a1a111111111a1a01a11a1a0a1a111111111
11111111a0a1a0a0a01a10a1a01a10aaa0a1a0a1a0a1a0a0a0a1a0a1a01a10aaa10a01a1a01a10aaa01a10a1a0a1a0a000000000a01a10aaa0a1a0a111111111
11111111a0a0a1a111aa1a111a1aa111a1a0a0a1a0a0a1a1a1a0a0a11a1aa11101aa0a011a1aa11111aa1a11a0a0a1a1111111111a1aa111a1a0a0a111111111
11111111a1a0a1a0aa101a010a101aaaa1a0a1a1a1a0a1a0a1a0a1a10a101aaaaa010a010a101aaaaa101a01a1a0a1a0000000000a101aaaa1a0a1a111111111
11111111a1a1a0a1101aa10101aa1011a0a1a1a1a1a1a0a1a0a1a1a101aa1011010aa10101aa1011101aa101a1a1a0a11111111101aa1011a0a1a1a111111111
11111111a1a1a1a0aaa101010101aaaaa1a1a1a1a1a1a1a0a1a1a1a10101aaaaaaa101010101aaaaaaa10101a1a1a1a0000000000101aaaaa1a1a1a111111111
11111111a1a1a1a10101010101010101a1a1a1a1a1a1a1a1a1a1a1a101010101010101010101010101010101a1a1a1a11111111101010101a1a1a1a111111111
11111111a1a1a5a50501010101010500050101010101050505010101010105000101010101010500050101010101050555555555010105000501010111111111
11111111a1a5a1a11015010101051011010501010105010101050101010510115051010101051011101501010105010111111111010510110105010111111111
11111111a5a1a5a50510150105101500050105010501050505010501051015000150510105101500051015010501050555555555051015000501050111111111
11111111a5a5a1a11100101110100111010505010505010101050501101001115100505110100111110010110505010111111111101001110105050111111111
11111111a1a5a1a50015105150151000010501010105010501050101501510000051505150151000001510510105010555555555501510000105010111111111
11111111a1a1a5a11510015151001511050101010101050105010101510015115150015151001511151001510101050111111111510015110501010111111111
11111111a1a1a1a50001515151510000010101010101010501010101515100000001515151510000000151510101010555555555515100000101010111111111
11111111a1a1a1a15151515151515151010101010101010101010101515151515151515151515151515151510101010111111111515151510101010111111111
11111111010106065651515151515655565151515151565656515151515156555151515151515655565151515151565666666666515156555651515111111111
11111111010601011516515151561511515651515156515151565151515615116561515151561511151651515156515111111111515615115156515111111111
11111111060106065615165156151655565156515651565656515651561516555165615156151655561516515651565666666666561516555651565111111111
11111111060601011155151115155111515656515656515151565651151551116155656115155111115515115656515111111111151551115156565111111111
11111111010601065516156165161555515651515156515651565151651615555561656165161555551615615156515666666666651615555156515111111111
11111111010106011615516161551611565151515151565156515151615516116165516161551611161551615151565111111111615516115651515111111111
11111111010101065551616161615555515151515151515651515151616155555551616161615555555161615151515666666666616155555151515111111111
11111111010101016161616161616161515151515151515151515151616161616161616161616161616161615151515111111111616161615151515111111111
11111111515157576761616161616766676161616161676767616161616167666161616161616766676161616161676777777777616167666761616111111111
11111111515751511617616161671611616761616167616161676161616716117671616161671611161761616167616111111111616716116167616111111111
11111111575157576716176167161766676167616761676767616761671617666176716167161766671617616761676777777777671617666761676111111111
11111111575751511166161116166111616767616767616161676761161661117166767116166111116616116767616111111111161661116167676111111111
11111111515751576617167176171666616761616167616761676161761716666671767176171666661716716167616777777777761716666167616111111111
111111115151575117166171716617116eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee6111111111716617116761616111111111
111111115151515766617171717166666e00000000000000000000000000000000000000000000000000000000000e0777777777717166666161616111111111
111111115151515171717171717171716e00000000000000000000000000000000000000000000000000000000000e0111111111717171716161616111111111
1111111161616f6f7f71717171717f777e000fffff000fffff000fffff000fffff0000000000fff00ff0f0f0fff00e0fffffffff71717f777f71717111111111
11111111616f6161171f7171717f17117e00fff0fff0ff000ff0fff00ff0ff00fff000000000fff0f0f0f0f0f0000e0111111111717f1711717f717111111111
111111116f616f6f7f171f717f171f777e00ff000ff0ff000ff0ff000ff0ff000ff000000000f0f0f0f0f0f0ff000e0fffffffff7f171f777f717f7111111111
111111116f6f616111771711171771117e00ff000ff0fff0fff0fff00ff0ff00fff000000000f0f0f0f0fff0f0000e011111111117177111717f7f7111111111
11111111616f616f771f17f1f71f17777e000fffff000fffff000fffff000fffff0000000000f0f0ff000f00fff00e0ffffffffff71f1777717f717111111111
1111111161616f611f1771f1f1771f117e00000000000000000000000000000000000000000000000000000000000e0111111111f1771f117f71717111111111
111111116161616f7771f1f1f1f177777e00000000000000000000000000000000000000000000000000000000000e0ffffffffff1f177777171717111111111
1111111161616161f1f1f1f1f1f1f1f17e00000000000000000000000000000000000000000000000000000000000e0111111111f1f1f1f17171717111111111
1111111171717e7efef1f1f1f1f1fefffe0057777750000000000666660000000ee0e0e000e0e0e0eee0eee0eee00e0eeeeeeeeef1f1fefffef1f1f111111111
11111111717e71711f1ef1f1f1fe1f11fe005557755000000600600000600000e0e0e0e00e00e0e0e0e00e000e000e0111111111f1fe1f11f1fef1f111111111
111111117e717e7efe1f1ef1fe1f1efffe005577555000006000606660600000e0e0ee000e00e0e0eee00e000e000e0eeeeeeeeefe1f1efffef1fef111111111
111111117e7e717111ff1f111f1ff111fe005777775000060000606060600000e0e0e0e00e00eee0e0e00e000e000e01111111111f1ff111f1fefef111111111
11111111717e717eff1e1fe1ef1e1ffffe005555555000600000606660600000ee00e0e0e000eee0e0e0eee00e000e0eeeeeeeeeef1e1ffff1fef1f111111111
1111111171717e711e1ff1e1e1ff1e11fe00000000000600000060000060000000000000000000000000000000000e0111111111e1ff1e11fef1f1f111111111
111111117171717efff1e1e1e1e1fffffe00555555500000000006666600000000000000000000000000000000000e0eeeeeeeeee1e1fffff1f1f1f111111111
1111111171717171e1e1e1e1e1e1e1e1fe00000000000000000000000000000000000000000000000000000000000e0111111111e1e1e1e1f1f1f1f111111111
11111111f1f1f8f8e8e1e1e1e1e1e8eeee00577577500000000006666600000000000000000088808880880080800e0888888888e1e1e8eee8e1e1e111111111
11111111f1f8f1f11e18e1e1e1e81e11ee00557775500000060060000060000000000000000088808000808080800e0111111111e1e81e11e1e8e1e111111111
11111111f8f1f8f8e81e18e1e81e18eeee00557775500000600060606060000000000000000080808800808080800e0888888888e81e18eee8e1e8e111111111
11111111f8f8f1f111ee1e111e1ee111ee00577577500006000060060060000000000000000080808000808080800e01111111111e1ee111e1e8e8e111111111
11111111f1f8f1f8ee181e818e181eeeee00555555500060000060606060000000000000000080808880808008800e08888888888e181eeee1e8e1e111111111
11111111f1f1f8f1181ee18181ee1811ee00000000000600000060000060000000000000000000000000000000000e011111111181ee1811e8e1e1e111111111
11111111f1f1f1f8eee181818181eeeeee00555555500000000006666600000000000000000000000000000000000e08888888888181eeeee1e1e1e111111111
11111111f1f1f1f18181818181818181ee00000000000000000000000000000000000000000000000000000000000e011111111181818181e1e1e1e111111111
11111111e1e1e9e989818181818189888e00000000000000000000000000000000000000000000000000000000000e0999999999818189888981818111111111
11111111e1e9e1e118198181818918118eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0111111111818918118189818111111111
11111111e9e1e9e98918198189181988890000000000000000000000000000000000000000000000000000000000000999999999891819888981898111111111
11111111e9e9e1e11188181118188111818989818989818181898981181881119188989118188111118818118989818111111111181881118189898111111111
11111111e1e9e1e98819189198191888818981818189818981898181981918888891989198191888881918918189818999999999981918888189818111111111
11111111e1e1e9e11918819191881911898181818181898189818181918819119198819191881911191881918181898111111111918819118981818111111111
11111111e1e1e1e98881919191918888818181818181818981818181919188888881919191918888888191918181818999999999919188888181818111111111
11111111e1e1e1e19191919191919191818181818181818181818181919191919191919191919191919191918181818111111111919191918181818111111111
1111111181818a8a9a91919191919a999a91919191919a9a9a91919191919a999191919191919a999a91919191919a9aaaaaaaaa91919a999a91919111111111
11111111818a8181191a9191919a1911919a9191919a9191919a9191919a1911a9a19191919a1911191a9191919a919111111111919a1911919a919111111111
111111118a818a8a9a191a919a191a999a919a919a919a9a9a919a919a191a9991a9a1919a191a999a191a919a919a9aaaaaaaaa9a191a999a919a9111111111
111111118a8a81811199191119199111919a9a919a9a9191919a9a9119199111a199a9a119199111119919119a9a91911111111119199111919a9a9111111111
11111111818a818a991a19a1a91a1999919a9191919a919a919a9191a91a199999a1a9a1a91a1999991a19a1919a919aaaaaaaaaa91a1999919a919111111111
1111111181818a811a1991a1a1991a119a91919191919a919a919191a1991a11a1a991a1a1991a111a1991a191919a9111111111a1991a119a91919111111111
111111118181818a9991a1a1a1a19999919191919191919a91919191a1a199999991a1a1a1a199999991a1a19191919aaaaaaaaaa1a199999191919111111111
1111111181818181a1a1a1a1a1a1a1a1919191919191919191919191a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a19191919111111111a1a1a1a19191919111111111
1111111191919b9baba1a1a1a1a1abaaaba1a1a1a1a1abababa1a1a1a1a1abaaa1a1a1a1a1a1abaaaba1a1a1a1a1ababbbbbbbbba1a1abaaaba1a1a166616161
11111111919b91911a1ba1a1a1ab1a11a1aba1a1a1aba1a1a1aba1a1a1ab1a11bab1a1a1a1ab1a111a1ba1a1a1aba1a111111111a1ab1a11a1aba1a161616161
111111119b919b9bab1a1ba1ab1a1baaaba1aba1aba1abababa1aba1ab1a1baaa1bab1a1ab1a1baaab1a1ba1aba1ababbbbbbbbbab1a1baaaba1aba161616661
111111119b9b919111aa1a111a1aa111a1ababa1ababa1a1a1ababa11a1aa111b1aabab11a1aa11111aa1a11ababa1a1111111111a1aa111a1ababa161611161
11111111919b919baa1b1ab1ba1b1aaaa1aba1a1a1aba1aba1aba1a1ba1b1aaaaab1bab1ba1b1aaaaa1b1ab1a1aba1abbbbbbbbbba1b1aaaa1aba1a166611161
1111111191919b911b1aa1b1b1aa1b11aba1a1a1a1a1aba1aba1a1a1b1aa1b11b1baa1b1b1aa1b111b1aa1b1a1a1aba111111111b1aa1b11aba1a1a111111111
111111119191919baaa1b1b1b1b1aaaaa1a1a1a1a1a1a1aba1a1a1a1b1b1aaaaaaa1b1b1b1b1aaaaaaa1b1b1a1a1a1abbbbbbbbbb1b1aaaaa1a1a1a111111111
1111111191919191b1b1b1b1b1b1b1b1a1a1a1a1a1a1a1a1a1a1a1a1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1a1a1a1a111111111b1b1b1b1a1a1a1a111111111

__gff__
0000000000000000000000000000000000000000000000000000000000200000000001010101010101010101010000000101010101010101000101010140000001010101010101010101000000000000010101010101010101010100000000000101010101010101000000000100010101010101010101010101000001010100
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101010101010101010100004001010101404001000001000101000101010101014001010000010000000100000100000000000000000000000000
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
7e7f7e7f7e7600000000007a0000727f0000000000e0e1000000000000e4e0e1e4d1e0e1e0e1e0e1e0e1e0e1e0e1e0e1e33c363c363334313030fd32393ac7cc2f1dc7ccc8decbd4d4cb000000000000d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d50000d6d6d6d6d6ded6d6d6d6d6d6d4d400310000000000003200000031320000
7978787800000000707b00000000007900e4e0e100000000e0e1e0e100004be4e4d1d100d1e6e6e6e6e6e6d1d1d1d1d1003d3d353c363c363533e73a3c38cbd62f1dcbdecb00c9ccccca00c7ccccc8004c4bd8d6d6d6d6d6d6d6d6d6d6d6d6d60000000000000000000000000000d4e4f2f2f3f2f2f2f2f2f2f2f2f2f2f2f2f2
d30000000000007000727300700000740000e4000000e4000000000000e44ce4e4d1e400efefefefe6efefefe0e1d1e4e3353d003d373c37383ce236370000002f1dc9ccca001f1f1f1f2fcbdddecb004b4a00000000d400d44a4b4c4d4e4fd6d6002d2d2f2f2d2dd4d42d2dd4d400e6f2f0f0f2f0f0f2f0f0f2f0f0f2f0f0f2
740070007b76730000007b007b000000e300e300e300e3e0e1e0e100e0e14ee4e4d1e4e6e600e6e6e6e6e6e6e600d1003de43de43de437e43736e2350000cbd7d6c7c8d4d4d42ec7ccc82fcbd4d4cb004a00d400d4d4d4d6d4d6d4d4d44f5fd6d6002d2d2f2f2d2dd4d42d2dd4e400e6f2f0f0f1f0f0f1f0f0f1f0f0f1f0f0f2
000000700000000000000000000076000038000000210000006fe44b4d4f5f5ee4d1efe636e6efefefefef36e6efd1e43def3d3d3d3d003d3d37e8000000c9ccd6c9cad4d4d42ecbddcb2fc9ccccca00d90000dbd6d6d6d6d6d6d6d6d45f5ed6d6001f1f2d2d2f2f2d2dd4d42f2d00e6e0e1e0e1e0e1e0e1e0e1e0e1e4f3e0e1
000000000000000000d300000000007be30044424200e3e4e0e1e0e1e0e14fe4e4e6efe6efe6e6e6e600e6efe6efe6e43de43de43de43de43de4e4e43de41dd4d6d4d42f1e1e2ec9ccca2d1e1e1e00000000d4d6d4d4d4d6ddd6d4d6d45ed9d6d6001f1f2d2d2f2f2d2dd4e42d2f00e6e7f1f3e7f3f1f3f1f3f1f3f1e7f1f3e7
770000710000710000710071007100000000434045004a4c4d4e4f5f5ee44de4e4e6e6e6efe600000000e6efe6efe6e43d003d3d3d3d3def3d3500353def3dd4d6d4d42fc7c82e1e1e2dc7ccc82ec7ccd4d6d4d6d4d6d6d6d6d6d4d6d45dddd6d6002d2d1f1f2d2d1e1e00002f2d00e6e2f0f0e2f0f0e7f0f0e7f0f0e2f0f0e2
000000000000007a00000000000000e3000043404000e3e0e1e0e1e45de44be4e4e6efe6efe600000000e6efe6e6e6e43ce43de43de43ce43de400e400e43dd4d6d4d42fc9ca2e44422fcbd8cb2ecbd4d4d7d4d6d4d6d4d6d4d6d4d6d4d4d4d4dd002d2d1f1f2d2d1e1ed4002d2f00e6e2f0f0e2e5f0e8f0f0e2f0f0e2f0f0e2
7b000000000000007a00000000007a000000434040384a4b4d4e4f5f5ee400e4e4e6efe6e6e6002b2700e6efe6efe6e43d3d3d3d3d3d3d3d003d3d3d3d3d3dd4d61fd42d1f1f2e43402fc9ccca2ecbde0000d6d6d6d6d6d7d6d6d6d6d6db0000d600d4d42d2d2f2fd4d42f2f2f2d00e6e2f0f0e2f0f0f3f0f0e2f0f0e2f0f0e2
007600710000710000710071007100e3e30043454721e3e4e0e1e0e1e0e100e4e4e6efe6efe626262626e6e6e6efe6e43de43de43de43de43de43de43de43dd4d62ecd2fd400001f1f1f2fd41f2ec9ccd4d7d4d6d4d6d4d6d4d6d4d6d4d4d4d4d600d4d42d2d2f2fd4e42f2f2d2f00e6e2f3f1e2e0e1e7f3f1e2f1f3e2f3f1e2
000000760000750000750000007600000000002100000000e400000000004b4de4e6efe6efe6e6e6e6e6e6efe6efe6e43d003d3d3d3d3d3d3d3d003d3d3d00d4002e1e1e0000002ec7c82fd4d4000000d4d6d4d6d4d6d6d6d6d6d4d6d45dd4d6d6002d2dd4d400de2f2f2d2d2f2d00e6e2f0f0e2f0f0e2f0f0e2f0f0e2f0f0e2
00700000000076000072727300000000e300e300e300e300e400e44be0e100e4e4d1efe636efefefefefef36e6efd1e43de43de43de43de43de43de43de43dd4d6002f1e1e00dd2ec9ca2fd4d4c7ccc80000d4d6d4d6d4d6d4d4d4d6d45ed9d6d6002d2dd4e400002f2f2d2d2d2f00e6e2f0f0e2f0f0e2f0f0e2f0f0e2f0f0e2
7b0000007a00007b0000000000000000e400e46ee40000000000e44d4fe400e4e400e4e6e6e6e6e6e6e600e6e6e4d1e43d3d003d3d3d3d3d3d3d3d3d003d3dd4d6002fcd2e2f1e2e1e1e1ed4d4cbd4cbde00d4d6d6d6d6d6d6d6d6db4f5f5ed6d600d4d42f2d2f2d2f2d2f2d2f2d00e6e2f0f0e2f0f0e8f0e5e2f0f0e2f0f0e2
0000700075000075007a7b7a00007000e400e4e0e1e0e1e0e1e0e1e0e1e0e1e4e4d1e400efe6efefefe6efefe0e1d1e43de43de43de43de43de43de43de43dd4d600d41f2e2fcdd4d4d4d4c7c8c9ccca4a00d4d4d400d4d6d4d4d44dd44f5fd6d600d4e42d2f2d2f2d2f2d2f2d2f00e6e8f0f0e8f0f0f1f0f0e8f0f0e8f0f0e8
00000000760000760000000000007b00e4000000000000000000000000000000d1d1d1d1d1e6e6e6e6e6e6d1d1d1d1e41d3d3d3d003d3d3d3d3d003d003d3dd4d6000000001f1f2ed4d4d4c9ca1d1d1d4b4a00000000dd00004a4b4c4d4e4fd6d4d4000000000000000000000000e4e6e4f1f3f1f3f1e4f1f3e4e6f1e4f1f3e4
7b760000000000000072797976000000e0e1e0e1e0e1e0e1e0e1e0e1e0e1e0e1e0e1e400d1d1e4e0e1e0e1e0e1e4d1e4424242424242424242424242424242d4d4d6d6d6d6d7d6d6d6d6d6d6d6d6d6d64c4bd8d6d6d6d6d6d6d6d6d6d6d6d6d6d4e400e6e6e6e6e6e6e6e6e6e6e6e600f1f3e0e1e0e1e0e1e0e1e6e6e6e6e0e1
__sfx__
001000000c0000c0000c0000c0000c0000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000905509005090550905509005090550905509005040550400504055040550400504055040550400500055000050005500055000050005500055000050b0550b0050b0550b0550b0050b0550b0550b005
001000000963309603396332160308603096232d6230960309633046032d63327603046030962321623046030963300603396330060300603096232d62300603096330b6032d6330b6030b603096232162321603
0010000021760217652170023760247602476521765217002376023765247652376521760217611c7611c70123760237651c7001c7601c765277002376023765237001c7601c76523700177651c7652376528765
001000000960309603396032160308603096032d6030960309603046032d60327603046030960321603046032163300603396030060300603096032d60300603096030b6032d6030b60321613216132162321633
0010000024754247542875424754247542475428754247541f7541f754237541f7541f7541f754237541f7541c7541c7541f7541c7541c7541c7541f7541c7541a7541a7541a7541e7541a7541a7541e7541a754
011000001576215752157521575215752157521575215752107521075210752107521075210752107521075211752117521175211752117521175211752117520b7520b7520b7520b7520b7520b7520b7520b752
0110000009752097520975209752097520975209752097520c7520c7520c7520c7520c7520c7520c7520c7520b7520b7520b7520b7520b7520b7520b7520b7521075210752107521075210752107521075210752
011000000907500005090750900509065090050904509005040750400504075040050406504005040450400500075000050007500005000650000500045000050b075000050b0750b0050b0650b0050b0450b005
001000001575215752157521575215752157521575215752177521775217752177521775217752177521775218752187521875218752187521875218752187521775217752177521775217752177521775217752
00100000346430060328633006031c623286031061300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300603006030060300000
011000001c7501c7501c7501c750107511075010750107501c7511c7501c7501c7501075110750107501075032772007042d772007042d77200704327723277200704007042d6552d6552d6552d6550c7500b750
011000002d7602d7552170023700287602876521705217001f760217651d7651f7651c7601c7601c7601c70123760237651c700247002470527700247502475526750267651c7052370029760297652370528705
01100000150650900515045090051503509005150250900510065040051004504005100350400510025040050c065000050c045000050c035000050c025000051706517005170450b005170350b005170250b005
01100000100650900510045090051003509005100250900510015040051001504005100150400510015040051c065000051c045000051c035000051c025000051c015170051c015170051c015170051c0150b005
011000000975209752097420974209732097320972209722047520475204742047420473204732047220472200752007520074200742007320073200722007220b7520b7520b7420b7420b7320b7320b7220b722
011000001514415144151441514415144151441514415144171441714417144171441714417144171441714418144181441814418144181441814418144181441a1441a1441a1441a1441a1441a1441a1441a144
0110000021140211452110023140241402414521145211002314023145241452314521140211411c1411c10123140231451c1001c1401c145271002314023145231001c1401c14523100171451c1452314528145
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000001000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0006000035623296532f67323673296631d66323653176531d64311643176330b63311623056230b6130f60305613086030460301603026030060300603006030060300603006030060300603006030060300603
001000001b7701a770197701877017770167701577014770137701377013770137751376513755137451373500700007000070000700007000070000700007000070000700007000070000700007000070000700
001000001a7701e770217701e770217702377026770287702b7702b7702b7702b7752b7652b7552b7452b73500700007000070000700007000070000700007000070000700007000070000700007000070000700
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
00 02030544
02 02030544
00 01020344
02 01020344
01 0b424344
01 08424344
00 08424344
00 080a4344
00 080a4344
00 08060a44
00 08070a44
00 08060a44
02 08090a44
01 0e424a44
00 0e424a44
01 0e0d4344
00 0e0d4344
00 0d0c4a44
00 0d0c4a44
00 0d0c0e44
02 0d0c0e44
01 0f424344
00 0f424344
00 0f104344
00 0f100444
00 0f100244
00 0f100244
00 0f110244
00 0f110244
00 0f100244
02 0f100244

