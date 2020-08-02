pico-8 cartridge // http://www.pico-8.com
version 28
__lua__
-- # pandora
-- my first pico-8 game

-- ## game loop
-- conventions: zero-based by default to make maths easier.
-- arrays start from 1, so transform them to 0-based coordinates.

-- to do next

-- fix moving mechanics
-- comment out
-- make sure only one move is taken each time you move

-- do i need 'moving' anymore?
-- make pandora move more smoothly -- stuck
-- make clouds move
-- create more levels
-- make ice mechanic
-- make lose progress screen like cuphead
-- make title screen
-- make mab
-- add other cats to levels

function _init()
	-- global variables:
	win = false
	lose = false
	in_game = false -- determines whether a level is in progress
	last_level = 3
	level = 1
	t = 0 -- game time in frames
	unfog_frames = 3
	caption_frames = 3
	cat_frames = 1
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
	moves = 10000 -- counts number of moves excluding against walls
	anim_frame = 0 -- allows sprites to animate
	offset = 0 -- screen offset for shaking
	move_step = 9 -- variable governing move animation
	dx = 0
	dy = 0
	get_level_data()

	-- colour setup:
	palt(13, true) -- set colour 13 transparent
	palt(0, false) -- and black not

	-- gameplay setup:
	level_reset()
end

function _update()
	-- input and move
	t += 1
	if moves <= 0 then game_lose() end

	if btnp() != 0 then
		-- a button has been pressed
		if in_game then
			process_move()
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
	if in_game then catch_up() end
end

function _draw()
	if not in_game then return end

	shake_screen()
	draw_everything()
end

-- ## main flow functions

function ar(a)
	-- convert 0-based pixel to 1-based array position.
	-- 0 maps to 1, 8 maps to 2
	return flr(a/8) + 1
end

function px(a)
	-- convert 1-based array position to 0-based pixel. 1 maps to 0, 2 maps to 8
	return (a-1) * 8
end

function level_reset()
	x = start_pos[level][1]  -- current position in pixels from 0
	y = start_pos[level][2]
	unfog_active = false
	socky_collect = false
	caption_active = false
	move_step = 9 -- to avoid cat sliding back across screen
	anim_frame = 0 -- so that each level starts the same way
	level_period = #obs_data[level]
	dir = "r" -- current direction
	fog_reset()
	obstacle_update()
	unfog_circle()
	draw_everything()
	--unfog_start() -- while designing
	in_game = true
	caption_show("level "..tostr(level), 3, 11, 10)
end

function level_up()
	in_game = false
	if level != last_level then
		print("end of level "..tostr(level).."!", 32, 64, 7)
		print("press any key", 32, 72, 7)
		level += 1
		return
	else
		game_win()
	end
end

function game_win()
	print("you win!", 32, 64, 7)
	print("press any key", 32, 72, 7)
	win = true
end

function game_lose()
	in_game = false
	print("you lose :(", 32, 64, 7)
	print("press any key", 32, 72, 7)
	lose = true
end

-- ## movement functions

-- flag key
-- 0 = all wall
-- 1 = up wall
-- 2 = down wall
-- 3 = left wall
-- 4 = right wall
-- 5 = danger

-- ## player move functions

function process_move()
	newx = x
	newy = y
	anim_frame += 1
	obstacle_update()
	if btnp(⬆️) then attempt_move("u")
	elseif btnp(⬇️) then attempt_move("d")
	elseif btnp(⬅️) then attempt_move("l")
	elseif btnp(➡️) then attempt_move("r")
	end
end

function attempt_move(a)
	just_moved = false
	dir = a
	if a == "u" then newy = y-8
	elseif a == "d" then newy = y+8
	elseif a == "l" then newx = x-8
	elseif a == "r" then newx = x+8
	end

	if can_move() then start_player_move() end
	check_current_cell()
end

function start_player_move()
	-- start a single move
	-- count down moves once
	-- update new position immediately but don't draw yet
	-- start animation 4210
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

function catch_up()
	-- adds a temp offset to character based on time
	if move_step >= 5 then return end
	move_pixels = {4, 2, 1, 0} -- shows at each move_step, how many pixels close to the new position the player should be
	if (t - move_time) % cat_frames == 0 then
		dx = move_pixels[move_step] * (prevx-x) / 8
		dy = move_pixels[move_step] * (prevy-y) / 8
		move_step += 1
	end
end

function can_move()
	if (newx<0 or newx>120 or newy<0 or newy>120) then return false end
	-- return false if 0th flag is set for target cell:
	if fget(mget(map_data_pos[level][1] + newx/8, map_data_pos[level][2] + newy/8), 0) then return false end
	return true
end

function check_current_cell()
	-- checks new cell for anything interesting
	-- check if you've reached goal
	if x == 120 and y == goal_height[level] * 8 then
		level_up()
		return
	end
	-- check if you've reached socky
	if x/8 == socky_pos[level][1] and y/8 == socky_pos[level][2] and socky_collect == false then
		socky_collect = true
		unfog_start()
	end
	-- check for moving obstacles
	if obstacles[ar(y)][ar(x)] > 0 then obstacle_hit() end
	-- check for static obstacles, if flag 5 is set for currrent cell:
	if fget(mget(map_data_pos[level][1] + x/8, map_data_pos[level][2] + y/8), 5) then obstacle_hit() end
end

function show_debug_info()
	rectfill(0, 0, 64, 15, level_bg)
	print("x "..tostr(x).." y "..tostr(y), 0, 0, 7)
	print("dx "..tostr(dx).." dy "..tostr(dy).." ms "..tostr(move_step), 0, 8, 7)
end

-- ## fog functions

function fog_reset()
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
	caption_show("socky!", 1, 12, 7)
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
	-- todo set all obstacles to 0 in a level
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
	show_debug_info()
	draw_caption()
	draw_moves()
end

function draw_level()
	rectfill(0,0,127,127,level_bg)
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

	print(caption_text, 65 - #caption_text * 2, 121, 0)
	print(caption_text, 64 - #caption_text * 2, 120, 7)
end

function draw_moves()
	local m = tostr(moves)
	print(tostr(moves), 129 - #m*4, 1, 0)
	print(tostr(moves), 128 - #m*4, 0, 9)
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

-- ## level by level data:

function get_level_data()
	level_bg = 3
	goal_height = {7, 9, 5} -- cells from top of screen, base 0
	fog_height = {7, 6, 1} -- cells from top of screen, base 0. must be >= 1
	socky_pos = { -- in cells base 0
		{15, 12}, -- 1
		{2, 10}, -- 2
		{7, 2} -- 3
	}
	start_pos = { -- in pixels, 0 to 120
		{24, 112}, -- 1
		{0, 48}, -- 2
		{0, 80} -- 3
	}
	map_data_pos = { -- in cells on datasheet
		{0, 0}, -- 1
		{16, 0}, -- 2
		{32, 0} -- 3
	}
	obs_data = {
		-- in each level's data, each time period has a set of obstacles.
		-- 16, 16 represents no obstacle. coordinates start from 0. -- TO CHANGE
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
		}
	}
end

--[[ some characters
a█ b▒ c🐱 d⬇️ e░ f✽ g●
h♥ i☉ j웃 k⌂ l⬅️ m😐 n♪
o🅾️ p◆ q… r➡️ s★ t⧗ u⬆️
vˇ w∧ x❎ y▤ z▥
]]--

__gfx__
00000000ddd0dd0ddddddddddd0dd0ddddddddddd0dd0ddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
00000000ddd0a0adddd0dd0dd00a0add0d0dd0ddd0000dddd0dd0ddd000000000000000000000000000000000000000000000000000000000000000000000000
00700700d000000dd000a0add00000dd000a0addd00000ddd0000d0d000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000dd0000000dd00000dd000000ddd00000ddd000000d000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000dd000000ddd00000ddd00000ddd00000ddd000000d000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000dd0000000dd00000ddd00000ddd00000ddd00000dd000000000000000000000000000000000000000000000000000000000000000000000000
00000000d0ddd0dd0ddddd0ddd00d0dddd0d00dddd0d00dddd00d0dd000000000000000000000000000000000000000000000000000000000000000000000000
00000000dddddddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111dddadddd000000000000000000000000ddddfefdddd7dddddddddddddddddddd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111ddd99ddd000000000000000000000000ddddfef0de2e28dddddddddddddddddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111111111111111111119a999add000000000000000000000000dddd8880d27e800dddd8ddddddd8dddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111a999a99d000000000000000000000000ddd8ff807ee8220ddd8d0ddddddd8ddd
d1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d111d111d1111111111111111111111111999a9950000000000000000000000000dd88ff00d2820000ddd8ddddddd8d0dd
dddddddddddddddd1ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d1111111111d509950d000000000000000000000000f8ff880dd802020ddddd0ddddddd0ddd
ddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111111111111111111111111111ddd950dd000000000000000000000000f88f800ddd00000ddddddddddddddddd
dddddddddddddddddd1ddd1d1d1d1d1d1d1d1d1d1d1d1d1d111d111d11111111dddd0ddd000000000000000000000000d00000dddddd0ddddddddddddddddddd
ddddddddddddddddffffff4f555555555555555555555555444444444ddddddd00000000000000000000000000000000dd45554ddddddddddddddddddddddddd
ddddddddddddddddffffff4f555ffffffffffffffffff5552424242424dddddd00000000000000000000000000000000d4ffff43d8ddd8dddddddddddddddddd
ddddddddddddddddfffffffffffff0f0f0f0f0f0f0f0ffff44444444444ddddd00000000000000000000000000000000df0f2f43dd0ddd0dddd8dddddddddddd
dddddddddddddddd44f44f44f4fff4f4f4f4f4f4f4f4ff0f424242424242dddd00000000000000000000000000000000dfff0f4ddddddddddd8d8ddddd8d8ddd
ddddddddddddddddff4ffffff0fff0f0f0f0f0f0f0f0ff4f4444444444444ddd00000000000000000000000000000000df3fff43ddddddddddd0d0ddddd8d0dd
dddddddddddddfddfffffffff0fff3f0f0f0f3f0f0f0ff3f24242424242424dd000000000000000000000000000000003f0f1f43d8ddd8dddddddddddddd0ddd
dddddddddfddddddff4ffffff4fff3fff4fff3fff4ffff3f444444444444444d000000000000000000000000000000003fff1f3ddd0ddd0ddddddddddddddddd
ddddddddddddddddf444f44ffffddddddddddddddddddfff424242424242424200000000000000000000000000000000d333d33ddddddddddddddddddddddddd
ccccccccccccccccccccccccccccccccccccccccddb35ddd3533323335333233ddddddddcccccccccccccccc0000000000000000000000000000000000000000
cccccccccccccccccccc76ccddccccccccccccccd33b35dd3355335333553353dddaddddccccccccccccccdd0000000000000000000000000000000000000000
cccccccccccc76ccccc76ccc3dddcccccccccccc3b3330dd5333303553333030ddbdddddccccccccccccddd30000000000000000000000000000000000000000
ccccccccc76c776ccccccccc3bddddcccccccccc3333335d3033333550333305ddddddddccccccccccdd333d0000000000000000000000000000000000000000
cccccccc7777766ccccccccc333333ddccccccccd305305d23355333d55050ddddddddddccccccccdd33b3d30000000000000000000000000000000000000000
ccccccccc666c6cccccccccc3333335dddccccccd5d405dd33533030dddddddddbddddddccccccddd33333330000000000000000000000000000000000000000
ccccccccccccccccc76cccccd3b33335ddddccccddd42ddd55333325ddddddddddddddadccccddb3333333500000000000000000000000000000000000000000
ccccccccccccccccccccccccd533350dddddddccddd42ddd32500550ddddddddddddddddccdd3dddd533350d0000000000000000000000000000000000000000
11111111001111110000000000111111000000001111111100111111c1111111dddd00000000dddd000000000000000000000000000000000000000000000000
111111110011111100000000001111110000000011111c110011111111111111dd0000000000000d000000000000000000000000000000000000000000000000
111111111111111111111111001111110011111111111111001111111c111111d00011111111110d000000000000000000000000000000000000000000000000
111111111111111111111111001111110011111111111111d011111111111111d00111111111111d000000000000000000000000000000000000000000000000
111111111111111111111111001111110011111111111111d01111111111111dd011111111111111000000000000000000000000000000000000000000000000
111111111111111111111111001111110011111111c11111d01111111111111dd011111111111111000000000000000000000000000000000000000000000000
111111111111111111111111001111110011111111111111d01111111111111d0011111111111111000000000000000000000000000000000000000000000000
111111111111111111111111001111110011111111111111dd111111111111dd0011111111111111000000000000000000000000000000000000000000000000
ddddddddddd0adddddddddddddddddddddddddddddda0dddddd445dddd5a5ddd0000000000000000000000000000000000000000000000000000000000000000
adddddddddd495ddadddddddddddddadaddddddddd4945daddd5a0ddddd905ad0000000000000000000000000000000000000000000000000000000000000000
94dadda4ddda4ddd94daddddddddd4949ddddda5dda45449add495ddad44a4940000000000000000000000000000000000000000000000000000000000000000
45494495dd5944dd45495ddddda4454544dad494dd94405494a440dd944490400000000000000000000000000000000000000000000000000000000000000000
45d45d45ddd4addd45540ddddd95504040494045dd540540409445dd454540450000000000000000000000000000000000000000000000000000000000000000
40554545ddd494dd4d54addddd44a54555544540ddd4554d4540dddd404045450000000000000000000000000000000000000000000000000000000000000000
45d54040ddd440ddddd495dddd549d4ddd544addddd0454d4d45dddd45d5454d0000000000000000000000000000000000000000000000000000000000000000
dddd4545ddd545ddddd540dddd044ddddd0559dddddddddddd4ddddd4ddd4ddd0000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000200000000001010101010100000000010000000101010101010101000101000000000001010101010101010101000000000000010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
30303030303030303030303030303030303030303030313030303030303030313030393a3653505050505050505243400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3334303030303031303030303032303031303030303030303030303030303030393a36513651382100000000005143450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
36363334303032303030303030303031303230393a353636352c36333432393a353637513651000000535050005143400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
362c363636363636363636363533343030393a36362c3637363636372c1d3636003700513651000000510000005143400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2c3536363635213635232424242535333a353737373737003737373537373736210000513751000000510051005550500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3636362c363636363535353735353636000000003800210000000000000000510000215100512e2e2e510051210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
373737373700351d3737372137373737005350545050505054505050501d00510000385135512e2e2e510055505050520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
271d0021000000000000002100000000005138510000000051000000000000510021385100512e2e2e510000000000510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
26270000000053505050505050505050005100512f00510051001d5050505056005050575056000000555050505000510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
26262700000051000021000000000000005100512f215100510048490000000000001f1f1f00002100001f1f1f0000510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222200210051000000000000005100215100512f00510051004647001d505200001f1f1f00213821001f1f1f0021510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222222000000380000000021000051000051000000005100510000213800005100001f1f1f00002100001f1f1f0038510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222250505050505050505200005100005550505050562155505050501d0051005050545050000000505054505000510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222220000000000000000510000513800000000000000380000000000002151000000514442000000444251363700510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222222210000000000000051000051000021000000000000000000000000005100000051434521001d434051444242510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222222380000000021380000002100005050505050505050521d535050505056000000514340424242414051434540510000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
