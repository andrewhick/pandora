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
	debug_mode = false -- shows debug info and unfogs each level
	win = false
	lose = false
	in_game = false -- determines whether a level is in progress
	title_active = true
	levelling_up = false
	last_level = 6
	level = 1
	t = 0 -- game time in frames
	unfog_frames = 3 -- how fast the unfogging happens
	caption_frames = 3 -- how fast the captions move
	cat_frames = 1 -- number of cat tween frames without ice
	menu_items = 4
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
	caption_pattern = {1, 2, 3, 2, 1}
	medal_text = {"gold", "silver", "bronze", "none"}
	medal_sprite = {12, 13, 14, 15}
	anim_frame = 0 -- allows sprites to animate
	offset = 0 -- screen offset for shaking
	move_step = 9 -- variable governing move animation
	play_music = true
	play_sounds = true
	ice = false
	dx = 0
	dy = 0
	perfect_moves = 0
	initial_moves = 0
	socky_bonus = 10 -- bonus awarded on collecting socky, in addition to the moves reimbursed for the detour. revisit moves_data if changing this
	game_get_data()
	moves = 9999
	best_medal = {4, 4, 4, 4, 4, 4} -- best medal for each level so far, 1=gold, 4=none

	reset_palette()
	title_show()
end

function _update()
	-- input and move
	t += 1
	if moves <= 0 then game_lose() end

	if btnp() != 0 or ice then
		-- a button has been pressed
		if title_active then
			title_active = false
			level_reset() -- start current level
		elseif in_game then
			move_process()
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
	end
end

function _draw()
	if not in_game and not menu_active then return end

	shake_screen()
	draw_everything()
end

-- conventions: map is zero-based, arrays are 1-based.
-- use functions ar() and px() to convert between array and pixels.

-- to do next

-- make clouds move
-- create more levels
-- make ice mechanic
-- make mab
-- add other cats to levels

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
		pal(10, title_colour[13-i])
		map(0, 32, 8, 128-i*8, 14, 4)
	end
	reset_palette()
	spr(1, 64, 24) -- cat
	rectfill(32, 72, 95, 111, 2)
	rectfill(32, 112, 95, 119, 0)
	print("⬆️⬇️⬅️➡️ move", 40, 80, 7)
	spr(192, 40, 88)
	spr(196, 48, 88)
	spr(194, 56, 88)
	spr(193, 40, 96)
	spr(196, 48, 96)
	spr(195, 56, 96)
	print("select", 68, 88, 7)
	print("menu", 76, 96, 7)
end

function level_reset()
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
	if ice then cat_frames = 3
	else cat_frames = 1 end
	socky_add = 0
	move_step = 9 -- to avoid cat sliding back across screen
	anim_frame = 0 -- so that each level starts the same way
	level_period = #obs_data[level]
	dir = "r" -- current direction
	unfog_reset()
	obstacle_update()
	unfog_circle()
	draw_everything()
	if debug_mode then unfog_start() end
	in_game = true
	caption_show("level "..tostr(level), 3, 11, 10)
	sfx(-1) -- stop playing sound
	if play_music then music(1) end -- main theme
end

function level_restart()
	moves = moves_data[level][3] -- reset back to allowed number of moves
	level_reset()
end

function level_up()
	in_game = false
	level_end_menu()
end

function level_end_menu()
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
			game_win()
		end
	else -- restart level
		level_restart()
	end
end

function game_win()
	print3d("you win!", 32, 64, 7, 0)
	print3d("press any key", 32, 72, 7, 0)
	if moves >= initial_moves - perfect_moves then
		print3d("perfect!", 32, 80, 7, 0)
	end
	print3d("moves left "..tostr(moves), 32, 88, 7, 0)
	win = true
end

function game_lose()
	in_game = false
	print3d("you lose :( - press any key", 8, 8, 10, 2)
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

-- ## player move functions

function move_process()
	newx = x
	newy = y
	if not ice then anim_frame += 1 end
	obstacle_update()
	if btnp(⬆️) then move_attempt("u")
	elseif btnp(⬇️) then move_attempt("d")
	elseif btnp(⬅️) then move_attempt("l")
	elseif btnp(➡️) then move_attempt("r")
	elseif btnp(5) then menu_open()
	elseif ice then move_attempt(dir)
	end

	-- todo
	-- make ice movement smooth, based on time
	-- prevent manual control while moving on ice
end

function move_attempt(a)
	just_moved = false
	dir = a
	if a == "u" then newy = y-8
	elseif a == "d" then newy = y+8
	elseif a == "l" then newx = x-8
	elseif a == "r" then newx = x+8
	end

	if move_possible() then move_do()
	elseif play_sounds then sfx(47) end -- hit wall
	check_current_cell()
end

function move_do()
	-- start a single move
	-- count down moves once
	-- update new position immediately but don't draw yet
	-- start animation 4210
	move_sound()
	moves -= 1
	dx = 0 -- temporary x offset
	dy = 0 -- temporary y offset
	move_step = 1
	move_time = t
	prevx = x
	prevy = y
	x = newx
	y = newy
	just_moved = true
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
	if move_step >= 5 then return end
	if not ice then move_pixels = {4, 2, 1, 0}
	else move_pixels = {6, 4, 2, 0} end -- shows at each move_step, how many pixels close to the new position the player should be.
		-- more linear movement on ice.
	if (t - move_time) % cat_frames == 0 then
		dx = move_pixels[move_step] * (prevx-x) / 8
		dy = move_pixels[move_step] * (prevy-y) / 8
		move_step += 1
	end
end

function move_possible()
	if (newx<0 or newx>120 or newy<0 or newy>120) then return false end
	-- return false if 0th flag is set for target cell:
	if fget(mget(map_data_pos[level][1] + newx/8, map_data_pos[level][2] + newy/8), 0) then return false end
	return true
end

function check_current_cell()
	-- checks new cell for anything interesting
	-- check if you've reached goal
	if x == 120 and y == goal_height[level] * 8 then
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
	if fget(mget(map_data_pos[level][1] + x/8, map_data_pos[level][2] + y/8), 5) then obstacle_hit() end
end

function show_debug_info()
	rectfill(0, 0, 64, 7, level_bg[level])
	print("target "..tostr(initial_moves - perfect_moves), 0, 0, 7)
	-- print("x "..tostr(x).." y "..tostr(y), 0, 0, 7)
	-- print("dx "..tostr(dx).." dy "..tostr(dy).." ms "..tostr(move_step), 0, 8, 7)
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
	if socky_add >= 1 then bonus_caption = " +"..tostr(socky_add - 1) end
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

-- ## caption functions

function caption_show(text, col1, col2, col3)
	caption_text = text
	cstep = ceil(#caption_text/4)
	caption_colours = {col1, col2, col3}
	caption_data = {}
	reset_caption_data()
	caption_active = true
	 -- data for each 8x8 character across bottom of screen with character and colour
end

function reset_caption_data()
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
			reset_caption_data()
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

-- ## draw functions

function draw_everything()
	cls()
	draw_level()
	draw_socky()
	draw_goal()
	draw_obstacles()
	draw_fog()
	draw_player()
	draw_caption()
	draw_moves()
	draw_menu()
	if debug_mode then show_debug_info() end
end

function draw_level()
	rectfill(0,0,127,127,level_bg[level])
	map(map_data_pos[level][1], map_data_pos[level][2], 0, 0, 16, 16) -- draw entire map
end

function draw_socky()
	if socky_collect == false then
		spr(28, socky_pos[level][1] * 8, socky_pos[level][2] * 8)
	end
end

function draw_goal()
	spr(24, 120, goal_height[level] * 8)
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
	print3d(tostr(moves), 128 - #m*4, 0, 7, 0)
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
	rectfill(0, 80, 47, 87, 1)
	spr(1, level*8 - 8, 80)
	for i=1,last_level do
		spr(level_sprites[i], i*8 - 8, 88)
		spr(medal_sprite[best_medal[i]], i*8 - 8, 96)
	end
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
	-- allow menu to be closed 
	menu_active = false
	in_game = true
end

-- ## level by level data:

function game_get_data()
	level_bg = {3, 3, 3, 3, 0, 0}
	goal_height = {7, 9, 5, 10, 1, 14} -- cells from top of screen, base 0
	fog_height = {7, 6, 1, 1, 1, 3} -- cells from top of screen, base 0. must be >= 1
	socky_pos = { -- in cells base 0
		{15, 12}, -- 1
		{2, 10}, -- 2
		{7, 2}, -- 3
		{15, 6}, -- 4
		{0, 7}, -- 5
		{11, 5} -- 6
	}
	start_pos = { -- in pixels, 0 to 120
		{24, 120}, -- 1
		{0, 48}, -- 2
		{0, 80}, -- 3
		{0, 80}, -- 4
		{0, 80}, -- 5
		{0, 8}, -- 6
	}
	map_data_pos = { -- in cells on datasheet
		{0, 0}, -- 1
		{16, 0}, -- 2
		{32, 0}, -- 3
		{48, 0}, -- 4
		{64, 0}, -- 5
		{80, 0}, -- 6
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
		}
	}
	moves_data = {
		-- [1] perfect score for each level
		-- [2] minimum moves needed to complete level with socky
		-- (excluding socky bonus, subtract 10 from final score when calculating this)
		-- [3] moves allowed for each level (default [1] + 5)
		-- [4] remaining points needed for gold (default 15)
		-- [5] remaining points needed for silver (default 10)
		-- [6] remaining points needed for bronze (default 5)
		{34, 44, 39, 15, 10, 5},
		{30, 62, 35, 15, 10, 5},
		{28, 28, 33, 15, 10, 5}, -- level 3 is quickest with socky
		{43, 53, 48, 15, 10, 5},
		{80, 94, 90, 20, 15, 10}, -- give extra leeway as level is complex
		{68, 76, 87, 29, 24, 19} -- perfect is 68 with shortcuts, 82 without shortcuts. So to be fair, moves allowed = 82 + 5.
	}
	level_moves = {39, 35, 33, 48, 90, 87} -- number of moves given
	ice_data = {false, false, false, false, false, false}
	level_sprites = {34, 49, 80, 100, 88, 91}
end

--[[ some characters
a█ b▒ c🐱 d⬇️ e░ f✽ g●
h♥ i☉ j웃 k⌂ l⬅️ m😐 n♪
o🅾️ p◆ q… r➡️ s★ t⧗ u⬆️
vˇ w∧ x❎ y▤ z▥
]]--

__gfx__
00000000ddd0dd0ddddddddddd0dd0ddddddddddd0dd0ddddddddddd0000000000000000000000000000000000000000a00000a0700000700000000000000000
00000000ddd0a0adddd0dd0dd00a0add5d0dd0ddd0000dddd0dd0ddd00000000000000000000000000000000000000009aa0aa90670007609900099055000550
00700700d000000dd000a0add00000dd000a0addd00000ddd0000d5d00000000000000000000000000000000000000009a0aa090607770604499944050555050
00077000000000dd0000000dd00000dd000000ddd00000ddd000000d000000000000000000000000000000000000000090090090600600604004004050000050
00077000000000dd000000ddd00000ddd00000ddd00000ddd000000d000000000000000000000000000000000000000049909940666666602444442050000050
00700700000000dd0000000dd50000ddd00000ddd00000ddd00000dd000000000000000000000000000000000000000004000400060006000240420005000500
0000000050ddd0dd0ddddd0ddd00d0dddd0d00dddd0d05dddd00d0dd000000000000000000000000000000000000000000444000006660000022200000555000
00000000dddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111dddadddd000000000000000000000000ddddfefdddd7dddddddddddddddddddd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111ddd99ddd000000000000000000000000ddddfef0de2e28dddddddddddddddddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111111111111111111119a999add000000000000000000000000dddd8880d27e800dddd8ddddddd8dddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111a999a99d000000000000000000000000ddd8ff807ee8220ddd8d0ddddddd8ddd
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111999a9950000000000000000000000000dd88ff00d2820000ddd8ddddddd8d0dd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111d509950d000000000000000000000000f8ff880dd802020ddddd0ddddddd0ddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111111111111111111111111111ddd950dd000000000000000000000000f88f800ddd00000ddddddddddddddddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111dddd0ddd000000000000000000000000d00000dddddd0ddddddddddddddddddd
ddddddddddddddddffffff4f555555555555555555555555444444444dddddddffffff4fff7777ff4610011fffffff4fdd45554ddddddddddddddddddddddddd
ddddddddddddddddffffff4f555ffffffffffffffffff5552424242424ddddddfffff400ff7777ff4110011fffffff4fd4ffff43d8ddd8dddddddddddddddddd
ddddddddddddddddfffffffffffff0f0f0f0f0f0f0f0ffff44444444444dddddfffff405fff77fff4110511fffffffffdf0f2f43dd0ddd0dddd8dddddddddddd
dddddddddddddddd44f44f44f4fff4f4f4f4f4f4f4f4ff0f424242424242dddd44f44450477777744115511444f44f44dfff0f4ddddddddddd8d8ddddd8d8ddd
ddddddddddddddddff4ffffff0fff0f0f0f0f0f0f0f0ff4f4444444444444dddff4ff4004110061f4115511fff4fffffdf3fff43ddddddddddd0d0ddddd8d0dd
dddddddddddddfddfffffffff0fff3f0f0f0f3f0f0f0ff3f24242424242424ddfffff4004110011f4115511fffffffff3f0f1f43d8ddd8dddddddddddddd0ddd
dddddddddfddddddff4ffffff4fff3fff4fff3fff4ffff3f444444444444444dff4ff4444116011f77777777ff4fffff3fff1f3ddd0ddd0ddddddddddddddddd
ddddddddddddddddf444f44ffffddddddddddddddddddfff4242424242424242f444f44f4110011f77777777f444f44fd333d33ddddddddddddddddddddddddd
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
adddddddddd495ddadddddddddddddadaddddddddd4945daddd5a0ddddd905ad0a00000000000e000000f0005555055500000555003000000000000000505000
94dadda4ddda4ddd94daddddddddd4949ddddda5dda45449add495ddad44a49400000b0000200000000100000000050000000500000000300500050505000105
45494495dd5944dd45495ddddda4454544dad494dd94405494a440dd944490400004000000000008000000400000050000000000000000000005000050010050
45d45d45ddd4addd45540ddddd95504040494045dd540540409445dd454540450000000300000000000700000000000000000000000000000500000505000505
40554545ddd494dd4d54addddd44a54555544540ddd4554d4540dddd404045457000000009000000000000000555555505550000030000000005000050010000
45d54040ddd440ddddd495dddd549d4ddd544addddd0454d4d45dddd45d5454d0000000000000000000005000500000005000000000003005000005010050015
dddd4545ddd545ddddd540dddd044ddddd0559dddddddddddd4ddddd4ddd4ddd0050000000040000000000000500000000000000000000000050000000105000
e9e9e9e9e9e9e9e91c1c1c1c1c1c1c1c1c1c1c1c01010101010101010101010105000000050000000600000aa00000000000000090090900d000000ddddddddd
dd9e999e999e999eddc1ccc1ccc1ccc1ccc1ccc1dd101110111011101110111055565565656565555556666500665655000000009909090900000011dd0000dd
3ddd9a999a999a993dddcecccecccecccecccecc3ddd1111111111111111111100000500000006000000060000000500000000009909099000011111d001111d
3bdddda9a9a9a9a93bddddececececececececec3bdddd11111111111111111100000600000006000000060000000600000000009909090900111111d011111d
333333dd9a9a9a9a333333ddcececececececece333333dd111111111111111100000500000005000000050000000600000000000000000000111111d011111d
3333335ddda9aaa93333335dddeceeeceeeceeec3333335ddd1111111111111155665585656656555556665666565555000000000900000000111111d011111d
d3b33335ddddaaaad3b33335dddde9eee9eee9eed3b33335dddd1c111c111c1105000898050000000500000005000000000000009999999901111111dd1111dd
d533350dddddddaad533350ddddddd9e9e9e9e9ed533350dddddddc1c1c1c1c106000089a500000005000000050000000000000009000000d111111ddddddddd
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000bc0000000000000000020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7c8c7c8c7c8c7cbc7c8c7ccc7c8c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bcac9cbcbcbc9cac9cacbc009cbc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d66666ddd66666dd5777775d5775775dddddddddfffffffdfffffff4ddddaaaaaaadddddadadadaaadadadadadadadadaaaaaaaaddaaaddd0000000000000000
6ddddd6d6ddddd6d5557755d5577755dddddd6ddf00000f4f00000f4ddaadddddddaadddadaddadddaddadadadadadaddddddddddadddadd0000000000000000
6d6d6d6d6d666d6d5577555d5577755ddddd6dddf4fff4f4f4fff4f4dadddaaaaadddaddaddaddaaaddaddadadadadadaaaaaaaaadaaadad0000000000000000
6dd6dd6d6d6d6d6d5777775d5775775dddd6ddddf4f0f4f4f4f0f4f4dadaadddddaadadddadaadddddaadaddadadadadddddddddadadadad0000000000000000
6d6d6d6d6d666d6d5555555d5555555ddd6dddddfff4f4f4fff4f4f4addaddaaaddaddaddadddaaaaadddaddadadadadaaaaaaaaadaaadad0000000000000000
6ddddd6d6ddddd6d0000000d0000000dd6dddddd0004f4f40004f4f4adaddadddaddadadddaadddddddaadddadadadaddddddddddadddadd0000000000000000
d66666ddd66666dd0000000d0000000dddddddddfffff4fffffff4ffadadadaaadadadadddddaaaaaaadddddadadadadaaaaaaaaddaaaddd0000000000000000
dddddddddddddddddddddddddddddddddddddddd0000000000000d00adadadadadadadadddddddddddddddddadadadaddddddddddddddddd0000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000200000000001010101010101010101010000000101010101010101000101010100000001010101010101010101000000000000010101010101010101010100000000000101010101010101000000000100010100000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
30303030303030303030303030303030303030303030313030303030303030313030393a3653505050505050505243404b4b4b44000037363c3665666767676700000000000000005900000000585900585a586c596c6c6c6c6c6c6c6c6c6c6c0000000000000000000000000000000000000000000000000000000000000000
333430303030303130303030303230303130303030303b303030303030303030393a36513651382100000000005143454b6e4b4a000000003736360062636464005800590000580000590058005c5b5b5b5b5b5b5b5c5c0000005c5c5b68696c0000000000000000000000000000000000000000000000000000000000000000
3c363334303b32303030303030303031303230393a3536333a2c36333432393a353637513651000000535050005143404b4b6e4a6f006f00004a35363636606100000000585a005a005a0000005a5a5b6c6c6c6c6c6c6c6c006c5c6c6c6a6b6c0000000000000000000000000000000000000000000000000000000000000000
362c35363c3636333a3c36363533343030393a363c2c363c353836372c38363600370051365100000051000000514340444b4a6e21000000004a4b3c4c4c373c0059005900000000000059005a00005c6c2f1e1e1e1e1e6c5c6c6c6c6c6c5b6c0000000000000000000000000000000000000000000000000000000000000000
2c38213c2135373637232424242535333a353737373c3700373c37353737373c210000513751000000510051005550504b4a6f38006f6e006e424b4b4c4d4e44005a00005a58000059005900580058596c2f6c6c6c6c2e6c5c6c0000006c5c6c0000000000000000000000000000000000000000000000000000000000000000
363c362c3836363c353821002138363c000000003800210000000021000000510000215100512e2e2e51005121004a4b4b6f38216f00006e4a4b6e4c44424e4f000059005c5c5a5900000058590000006c2f6c68696c2e6c5b6c0000006c5c6c0000000000000000000000000000000000000000000000000000000000000000
3737373c371d35003737373737373737005350545050505054505050501d00510000385135512e2e2e510055505050524a00216f00006e41424b4b4c4d4e444f005a00595a5c5b5b595a0000005a00006c2f6c6a6b6c2e6c5b6c0000006c006c0000000000000000000000000000000000000000000000000000000000000000
27000021000000000000002100000000005138510000000051000000000000510021385100512e2e2e510000000000516f006f00006f004a4b6e4c44424e4f4f0058000000585b6869590000590000586c2f6c5b5b6c2e6c6c6c6c6c5c6c006c0000000000000000000000000000000000000000000000000000000000000000
26270000000053505050505050505050005100512f00510051005050501d505600505057505600000055505050500051000000006f00006e4b434c434e444f445a00005a0000596a6b5b5800000058005c5c6c68696c005d2f2f2f5c5c5c006c0000000000000000000000000000000000000000000000000000000000000000
26262700000051000021000000000000005100512f215100510048490000000000001f1f1f00002100001f1f1f0000516f6e420021006e4a4b434d434e4f445e000058000000585a5b5b5c5959005900006c5c6a6b6c006c2f2f2f6c5c6c006c0000000000000000000000000000000000000000000000000000000000000000
22292200210051000000000000005100215100512f00510051004647001d505200001f1f1f00213821001f1f1f002151002100386e424a4b444c4d4e445f5f5e000000595800000058595c5c00580000006c006c5c6c006c2f2f2f6c006c5c6c0000000000000000000000000000000000000000000000000000000000000000
222a22000000380000000021000051000051000000005100510000213800005100001f1f1f00002100001f1f1f0038516f6e4200004a6e4b4c444e444f5f445e5859005a0059005900005958000059005c6c006c006c5c6c2f2f2f6c5c6c5b6c0000000000000000000000000000000000000000000000000000000000000000
22222250505050505050505200005100005550505050560055505050501d005100505054505000000050505450500051000000006f4a4b6e4c434e435f445e5d00000058005a000000000000590058005b6c5c6c006c5b5b5b5b5b6c6c6c5b6c0000000000000000000000000000000000000000000000000000000000000000
2922220000000000000000510000513800000000000000210000000000002151000000514442000000444251363700516f006f21006e4b4c4d434f435f5e445d005a5900000058005800595a000000005b5b5b6c5c6c6c6c6c6c6c6c68696c6c0000000000000000000000000000000000000000000000000000000000000000
2a2222210000000000000051000051000021535054505238535054505200005100000051434521001d434051444242510000006f4a4b6e4d4d434f5f5e5e5d440000000058005a00005a000058005900006c6c6c5b5c00000000005c6a6b5b5b0000000000000000000000000000000000000000000000000000000000000000
222228380000000021380000002100005050563851005550560051215550505600000051434042424241405143454051000000004a4b4c6e4d4342425e445d4300585a00000000580000000000000000005d00005c6c6c6c6c6c6c6c6c595a580000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000905509005090550905509005090550905509005040550400504055040550400504055040550400500055000050005500055000050005500055000050b0550b0050b0550b0550b0050b0550b0550b005
011000000963309603396332160308603096232d6230960309633046032d63327603046030962321623046030963300603396330060300603096232d62300603096330b6032d6330b6030b603096232162321603
0110000021760217652170023760247602476521765217002376023765247652376521760217611c7611c70123760237651c7001c7601c765277002376023765237001c7601c76523700177651c7652376528765
011000000960309603396032160308603096032d6030960309603046032d60327603046030960321603046032163300603396030060300603096032d60300603096030b6032d6030b60321613216132162321633
0110000024754247543475424754247542475428754247541f7541f754237541f7541f7541f754237541f7541c7541c7541f7541c7541c7541c7541f7541c7541a7541a7541a7541e7541a7541a7541e7541a754
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
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000c74015700137201270018710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
01030000187401570013720127000c710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
0103000013740157000c7201270018710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
010300000c74015700187201270013710067000d7001c700147001e7001e7001e7001e7001e7001c7001c7001b700197001770014700127000d7000a700067000070000700007000070000700017000270002700
010c000024770287702b77024770287702b7703076030755307453073524705007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00060000351202f15029170231601d15017140111300b120051102a100121001d1000f100181000c1000f10008100081000410001100021000010000100001000010000100001000010000100001000010000100
001000000305000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001a7701e7701f7701e770217702377024770267701f7701f7701f7701f7751f7651f7551f7451f73500700007000070000700007000070000700007000070000700007000070000700007000070000700
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

