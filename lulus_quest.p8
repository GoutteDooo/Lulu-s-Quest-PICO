pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function _init()
	init_player()
	init_light()
	init_room()
  init_objects()
	cx = 0
	cy = 0
	frames = 0
	room_transition_pending = false
	i_room = 0
	is_in_switch = false
	lives = 3
	music(10)
	--DEBUG
	debug_light = false
end

function _update()
	frames=((frames+1)%30)
	update_player()
	update_room()
	update_light()
	update_objects()
	cx = room.x
	cy = room.y
end

function _draw()
	cls()
	camera(cx, cy)
	draw_light()
	map(0, 0, 0, 0)
	draw_objects()
	draw_player()
	-- line()
	if btn(🅾️) and lulu.select then
		-- Dessiner la grid de la map
		-- for i=0,1 do
		-- 	for j=0,16 do
		-- 		if (i == 0) line(0, max(0,(j*8)),128,max(0,(j*8)), 8)
		-- 		if (i == 1) line(max(0,(j*8)),0,max(0,(j*8)),128,8)
		-- 	end
		-- end
		-- pset(ima_light.x,ima_light.y,11)
	end
	draw_ui()
	debug_print()
end

-->8
--player

function init_player()
	lulu = {
		x = 1 * 8,
		y = 13 * 8,
		x_g = x,
		y_g = y,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		default_sprite = 1,
		sprite = 1,
		flipx = false,
		select = true,
		in_light = true,
		using_light = false, --to know if player is holding C key
		ima_range = 6 * 8, --range of ima_light
		lights_left = 1,
		passed = false, --pass lvl
		id = "lulu"
	}
	hades = {
		x = 15 * 8,
		y = 14 * 8,
		x_g = x,
		y_g = y,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		default_sprite = 5,
		sprite = 5,
		flipx = true,
		select = false,
		in_light = false,
		using_light	= false,
		light_selected = 
		{
			nil, -- id light
			0 -- index dynamique
		},
		turnoffs_left = 1,
		passed = false, --pass lvl
		id = "hades"
	}
	pactual = lulu
end

function draw_player()
	--if they have finished the lvl
	if not (lulu.passed) then
		spr(lulu.sprite, lulu.x, lulu.y, 1, 1, lulu.flipx)
	end
	if not (hades.passed) then
		spr(hades.sprite, hades.x, hades.y, 1, 1, hades.flipx)
	end
end

function update_player()
	if is_in_switch then
		is_in_switch = frames == 30 and true or false
		return
	end
	--if they have finished the lvl
	if pactual.passed then
		switch_character()
		return
	end

	if btn(🅾️) then
		if ima_light.x > lulu.x then
			lulu.flipx = false
		else
			lulu.flipx = true
		end
		return
	end

	--switch characters
	if btnp(⬇️) and not btn(🅾️) then
		switch_character()
		return
	end

	if btn(⬅️) then
		pactual.dx -= 1.33
		pactual.flipx = true
	end
	if btn(➡️) then
		pactual.dx += 1.33
		pactual.flipx = false
	end
	if btnp(⬆️) then
		if pactual.g then
			pactual.dy = -2.5
			sfx(0)
		end
	end
	pactual.y += pactual.dy
	pactual.dx *= 0.6
	if pactual == lulu then
		pactual.dy += 0.20
	else
		pactual.dy += 0.13
	end

	-- interact(newx, newy)
	if check_flag(0, pactual.x + 3, pactual.y + 8) or check_flag(0, pactual.x + 5, pactual.y + 8) then
		pactual.g = true
		pactual.dy = 0
		pactual.y = flr(pactual.y / 8) * 8
	else
		pactual.g = false
	end

	if pactual.dx > 0 then
		if not check_flag(0, pactual.x + 9, pactual.y + 7) and not check_flag(0, pactual.x + 9, pactual.y) then
			pactual.x += pactual.dx
		end
	elseif pactual.dx < 0 then
		if not check_flag(0, pactual.x - 1, pactual.y + 7) and not check_flag(0, pactual.x - 1, pactual.y) then
			pactual.x += pactual.dx
		end
	end
	--another security check in case of accel
	if check_flag(0, pactual.x + 7, pactual.y + 7) then
		pactual.x -= 1
	end
	--another security check in case of accel
	if check_flag(0, pactual.x, pactual.y + 7) then
		pactual.x += 1
	end

	if check_flag(0, pactual.x + 1, pactual.y) or check_flag(0, pactual.x + 6, pactual.y) then
		pactual.dy = 0
		pactual.y += 1
	end

	--collisions lulu and light
	pactual.in_light = false
	for l in all(lights) do
		if collision_light(pactual, l) then
			pactual.in_light = true
			break
		end
	end

	if (not lulu.in_light and not lulu.passed) or (hades.in_light and not hades.passed) or pactual.y >= room.h-1 then
		if lives > 0 then
			lives = lives - 1
			if i_room == 0 then 
				restart_game()
				sfx(9)
				return
			end
			restart_level()
			sfx(8)
		else
			restart_game()
			sfx(9)
			end
	end

	pactual.y_g = ceil(pactual.y / 8) * 8
	pactual.x_g = ceil(pactual.x / 8) * 8

	--clamp れき la map
	if not room_transition_pending then
		pactual.x = mid(room.x, pactual.x, room.w - 8)
		pactual.y = mid(room.y, pactual.y, room.h - 8)
	end

	--animations
	--jump
	if not pactual.g then
		pactual.sprite = pactual.default_sprite + 3
	else
		--move
		if pactual.dx > 0.2 or pactual.dx < -0.2 then
			pactual.sprite = frames % 8 >= 4 and pactual.default_sprite + 1 or pactual.default_sprite
			if frames % 8 == 0 then
				sfx(3)
			end
		else
			pactual.sprite = pactual.default_sprite
		end
	end
end

function switch_character()
	--switch characters
	if (pactual == lulu) then
		pactual = hades
		lulu.select = false
		reinit_character()
		hades.select = true
		is_in_switch = true
	elseif (pactual == hades) then
		pactual = lulu
		lulu.select = true
		reinit_character()
		hades.select = false
		is_in_switch = true
	end
end

function reinit_character()
	pactual.dx = 0
	pactual.dy = 0
	pactual.g = false
end

-->8
--map

function check_flag(flag, x, y)
	local sprite = mget(x / 8, y / 8)
	return fget(sprite, flag)
end

-->8
--lights

function init_light()
	ima_light = {
		x = lulu.x + 4,
		y = lulu.x + 4,
		radius = 32,
		color = 12
	}
	lights = {}
	create_light(-2 * 8, 10 * 8, 52)
	create_light(9 * 8, 12 * 8, 32)
end

function update_light()
	-- lulu
		if btn(🅾️) then
			if lulu.select and lulu.lights_left > 0 then
				update_light_lulu()
			end
				--hades
			if hades.select then
				update_light_hades()
			end
		end
		if (hades.select and not btn(🅾️)) then
			hades.using_light = false
			hades.light_selected[1] = nil
			sfx(7,-2)
		end
		if (lulu.select and not btn(🅾️)) then 
			lulu.using_light = false
			sfx(4,-2)
		end
end

function update_light_lulu()
	if not lulu.using_light then
		--setting position of light
		ima_light.y = lulu.y_g
		ima_light.x = lulu.x_g
		lulu.using_light = true
		sfx(4)
	end

	local xsign = 0
	local ysign = 0
	local dirpressed = false
	
	if (btn(⬅️)) xsign = -1
	if (btn(➡️)) xsign = 1
	if (btn(⬆️)) ysign = -1
	if (btn(⬇️)) ysign = 1
	if ((btn(⬅️)) or (btn(➡️)) or (btn(⬆️)) or (btn(⬇️))) dirpressed = true

	if dirpressed then
			local x = ima_light.x + xsign * 8
			local y = ima_light.y + ysign * 8
			
			-- Vれたrification du dれたplacement normal
			if frames % 3 == 0 then
				ima_light.x = mid(room.x, flr(x / 8) * 8, room.w)
				ima_light.y = mid(room.y, flr(y / 8) * 8, room.h)
			end

		-- Vれたrification de la distance par rapport au joueur (lulu)
		local dx = ima_light.x - lulu.x_g
		local dy = ima_light.y - lulu.y_g
		local dist = sqrt(dx * dx + dy * dy)

		if dist > lulu.ima_range then
				-- Limiter la position sur le cercle
				local angle = atan2(dx, dy)
				ima_light.x = lulu.x_g + round((cos(angle) * lulu.ima_range)/8)*8
				ima_light.y = lulu.y_g + round((sin(angle) * lulu.ima_range)/8)*8
		end
	end

	if btnp(❎) and lulu.select and lulu.lights_left > 0 then
		local x = ima_light.x - (ima_light.radius / 2)
		local y = ima_light.y - (ima_light.radius / 2)
		create_light(x, y, ima_light.radius)
		sfx(5)
		lulu.lights_left -= 1
	end
end

function update_light_hades()
	-- hades a une variable qui stocke temporairement la light selected
	if #lights > 0 and hades.turnoffs_left > 0 then
		if not hades.using_light then
			sfx(7)
			hades.using_light = true
		end
		local index = hades.light_selected[2]
		local count = #lights
		hades.light_selected[1] = lights[index + 1]
		if (btnp(➡️)) hades.light_selected[2] = (hades.light_selected[2] + 1) % count
		if (btnp(⬅️)) hades.light_selected[2] = (hades.light_selected[2] - 1) % count
		if btnp(❎) then
			del(lights,hades.light_selected[1])
			hades.light_selected[2] = 0
			hades.turnoffs_left -= 1
			sfx(6)
	end
	else
		--#light = 0 ou hades n'a plus de power
		hades.light_selected[1] = nil
	end
end

function draw_light()
	draw_lights()
	draw_imaginary_light()
	draw_hades_turnoff()
end

function draw_imaginary_light()
	if btn(🅾️) and lulu.select and lulu.lights_left > 0 then
		circfill(ima_light.x, ima_light.y, ima_light.radius / 2, ima_light.color)
		circ(lulu.x_g, lulu.y_g, lulu.ima_range, 12) --desinner le circle de ima_light
		-- pset(ima_light.x,ima_light.y,8)
	end
end

function draw_lights()
	foreach(
		lights, function(l)
			sspr(12 * 8, 0, l.w, l.h, l.x, l.y, l.radius, l.radius)
		end
	)
end

function draw_hades_turnoff()
	if (hades.light_selected[1] != nil) and #lights > 0 then
		--check if selected light already exists
		local i = hades.light_selected[2] + 1
		local x = lights[i].x + lights[i].radius/ 2
		local y = lights[i].y+ lights[i].radius / 2
		local r = lights[i].radius / 2
		circfill(x, y, r, 8)
	end
end

function create_light(x, y, r, flag, color)
	local new_light = {
		id = #lights,
		x = x,
		y = y,
		radius = r,
		h = 32,
		w = 32,
		flag = flag or 1,
		color = color or 10
	}
	add(lights, new_light)
end

-->8
--rooms
function init_room()
	room = {
		id = 0,
		x = 0,
		y = 0,
		w = 128,
		h = 128
	}

	rooms_data = 
	{
		--1
		{
			lights = 
			{
				{x = 17, y = 12, radius = 40},
				{x = 25, y = 12, radius = 40}
			},
			pos = 
			{
				lulu = {x = 17, y = 14},
				hades = {x = 17, y = 7}
			},
			doors = 
			{
				lulu = {x = 30, y = 13},
				hades = {x = 31, y = 10}
			},
			powers = 
			{
				lulu = 1,
				hades = 1
			}
		},
		--2
		{
			lights = 
			{
				{x = 34, y = 9, radius = 48},
				{x = 43, y = 9, radius = 64}
			},
			pos = 
			{
				lulu = {x = 34, y = 11},
				hades = {x = 32, y = 14}
			},
			doors = 
			{
				lulu = {x = 46, y = 13},
				hades = {x = 46, y = 10}
			},
			powers = 
			{
				lulu = 2,
				hades = 2
			}
		},
		--3
		{
			lights = 
			{
				{x = 50, y = 8, radius = 38},
				{x = 56, y = 8, radius = 46}
			},
			pos = 
			{
				lulu = {x = 51, y = 10},
				hades = {x = 62, y = 10}
			},
			doors = 
			{
				lulu = {x = 63, y = 8},
				hades = {x = 48, y = 9}
			},
			powers = 
			{
				lulu = 2,
				hades = 2
			}
		},
		--4
		{
			lights = 
			{
				{x = 65, y = 8, radius = 32},
				{x = 70, y = 0, radius = 48},
				{x = 72, y = 8, radius = 32}
			},
			pos = 
			{
				lulu = {x = 65, y = 10},
				hades = {x = 78, y = 10}
			},
			doors = 
			{
				lulu = {x = 70, y = 1},
				hades = {x = 75, y = 1}
			},
			powers = 
			{
				lulu = 2,
				hades = 1
			}
		},
		--5
		{
			lights = 
			{
				{x = 80, y = 1, radius = 40},
				{x = 84, y = 4, radius = 40},
				{x = 91, y = 10, radius = 48},
				{x = 89, y = 5, radius = 32}
			},
			pos = 
			{
				lulu = {x = 81, y = 2},
				hades = {x = 81, y = 13}
			},
			doors = 
			{
				lulu = {x = 94, y = 12},
				hades = {x = 94, y = 1}
			},
			powers = 
			{
				lulu = 1,
				hades = 1
			}
		}
	}
end

function update_room()
	--if they have finished the lvl
	if room_transition_pending then
		next_room()
		room_transition_pending = false
		lulu.passed = false
		hades.passed = false
	end
end

function next_room()
	local x = room.x + 128
	--TEST
	x = 4 * 128
	local y = room.y
	if (x >= 1024) then
		x = 0
		y = y + 128
		if (y >= 512) then -- We are at the end of the map
		y = 0
		end
	end
	local w = x + 128
	local h = y + 128
	local id = room.id + 1
	if (id == 33) then
		id = 1
	end

	room = new_room(id, x, y, w, h)
	i_room = index_room(room.x, room.y)
	create_room()
	sfx(1)
end

function create_room()
	for l in all(lights) do
		del(lights,l)
	end
	for l in all(rooms_data[i_room].lights) do
		create_light(l.x * 8, l.y * 8, l.radius)
	end
	--doors
	doors.lulu.x = rooms_data[i_room].doors["lulu"].x * 8
	doors.lulu.y = rooms_data[i_room].doors["lulu"].y * 8
	doors.hades.x = rooms_data[i_room].doors["hades"].x * 8
	doors.hades.y = rooms_data[i_room].doors["hades"].y * 8
	--pos
	lulu.x = rooms_data[i_room].pos["lulu"].x * 8
	lulu.y = rooms_data[i_room].pos["lulu"].y * 8
	hades.x = rooms_data[i_room].pos["hades"].x * 8
	hades.y = rooms_data[i_room].pos["hades"].y * 8
	--powers
	lulu.lights_left = rooms_data[i_room].powers["lulu"]
	hades.turnoffs_left = rooms_data[i_room].powers["hades"]
end

function new_room(id, x, y, w, h)
	return {
		id = id,
		x = x,
		y = y,
		w = w,
		h = h
	}
end

function index_room(x, y)
	return flr(x / 128) + flr(y / 128) * 8
end

function restart_level()
	create_room()
end

function restart_game()
	_init()
end

-->8
--objects

--init objects
function init_objects()
	-- coordonnれたes pour lvl 1, a update れき chaque changement de room
	doors = {
		lulu = {
			x = 7 * 8,
			y = 13 * 8
		},
		hades = {
			x = 9 * 8,
			y = 13 * 8
		}
	}
end

function update_objects()
	-- When someone enter its doors, passed will be turn on and character will disappear
	if collision(lulu, doors.lulu) then
		lulu.passed = true
		if not door_sound_played then
			sfx(2)
			door_sound_played = true
		end
	end
	if collision(hades, doors.hades) then
		hades.passed = true
		if not door_sound_played then
			sfx(2)
			door_sound_played = true
		end
	end
	
	-- nouvelle vれたrification
	if lulu.passed and hades.passed and not room_transition_pending then
		room_transition_pending = true
		door_sound_played = false
	end
	
end

--animations
function draw_objects()
	--doors
	local flip = frames % 10 >= 5  -- Alterne toutes les 5 frames
	local d_lulu = 35
	local d_hades = 51
	-- Desspritee la porte dimensionnelle
	spr(d_lulu, doors.lulu.x, doors.lulu.y, 1, 1, flip, false)
	spr(d_lulu, doors.lulu.x, doors.lulu.y + 8, 1, 1, not flip, true)
	spr(d_hades, doors.hades.x, doors.hades.y, 1, 1, flip, false)
	spr(d_hades, doors.hades.x, doors.hades.y + 8, 1, 1, not flip, true)
end

-->8
--UI
function draw_ui()
	local x = room.x
	local y = room.y
	for i = 1, lulu.lights_left do
		spr(33, x + i * 8, y + 4, 1, 1, false, false)
	end
	for i = 1, hades.turnoffs_left do
		spr(34, x + 120 - i * 8, y + 4, 1, 1, false, false)
	end
	for i = 1, lives do
		spr(37, x + i * 8, y + 10, 1, 1, false, false)
	end
end

-->8
--helper functions

function debug_print()
	-- if (collision(lulu,doors.lulu)) print("collides !",10,50,8)
	-- print("room: "..index_room(room.x,room.y),lulu.x,lulu.y-10,8)
	-- print(room.y,45,20,8)
	-- print(room.id,10,40,12)
	-- for l in all(lights) do
	-- 	if collision_light(pactual, l) then	
	-- 		print("col : "..l.id,lulu.x,lulu.y - l.id*10,8)
	-- 	end
	-- end
	-- print("index room: "..i_room,lulu.x,lulu.y-10,8)
	print(lulu.in_light,lulu.x,lulu.y-10,8)
	print(hades.in_light,hades.x,hades.y-10,8)
	print("frames: "..frames,10,10,8)
	print("dx: "..lulu.dx,10,20,11)
	if (not lulu.in_light) then debug_light = true end
	print("out ? "..(debug_light and 'true' or 'false'),lulu.x,lulu.y-20,8)
	-- print("x: "..lulu.x,lulu.x,lulu.y-20,8)
	-- print("y: "..lulu.y,lulu.x,lulu.y-10,8)
	
end

function round(a)
	return flr(a + 0.5)
end

--collisions
function collision(p, o)
	return not (p.x > o.x + 8
				or p.y > o.y + 8
				or p.x + 8 < o.x
				or p.y + 8 < o.y)
end

function collision_light(p, l)
	local px = p.x + p.w / 2
	local py = p.y + p.h / 2
	local lx = l.x + l.radius / 2
	local ly = l.y + l.radius / 2

	local dx = px - lx
	local dy = py - ly
	local dist = sqrt(dx*dx + dy*dy)
	print("dist: "..flr(dist), hades.x, hades.y - 10, 7)
	return dist <= (l.radius + 6) / 2
end

__gfx__
00000000088888800888888008888880088888800222222002222220022222200222222000000000000000000000000000000000000066666666000000000000
000000008888888888888888888888888888888822222222222222222222222222222222000000000000000000000000000000000666aaaaaaaa666000000000
007007008899999888999998889999988899999822222f2222222f2222222f2222222f22000000000000000000000000000000066aaaaaaaaaaaaaa660000000
00077000899ff9f9899ff9f9899ff9f9899ff9f90229ff920229ff920229ff920229ff920000000000000000000000000000006aaaaaaaaaaaaaaaaaa6000000
0007700089fc9fc989fc9fc989fc9fc989fc9fc9022ffff2022ffff2022ffff2022ffff2000000000000000000000000000006aaaaaaaaaaaaaaaaaaaa600000
00700700089fff90089fff90089fff90089fff900121d1020121d1020121d1020121d10200000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaa60000
000000000088880000888800008888000088880001dddd0010dddd0001dddd0001dddd000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaa6000
000000000040040000045000040004000400004001400400100450000140040004000040000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
66666666000a000000888000dddddddd08800880000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
6555555600aaa000088a8800dddccddd88888888000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
655555560aa9aa0088a88880ddccccdd888888880808000000000000000000000000000000000000cccccccc000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
65555556aa999aa08a888a80dccccccd888887888888800000000000000000000000000000000000cccccccc000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
655555560aa9aa008888a880dccccccd888877888888800000000000000000000000000000000000cccccccc0000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
6555555600aaa000088a8800dccc7ccd088888800888000000000000000000000000000000000000cccccccc0000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
65555556000a000000888000dcc77ccd008888000080000000000000000000000000000000000000cccccccc0000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
666666660000000000000000dcc77ccd000880000000000000000000000000000000000000000000cccccccc00000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
00060000000000000000000055555555000000000000000000000000000000000000000000000000cccccccc88888888006aaaaaaaaaaaaaaaaaaaaaaaaaa600
00006000000000000000000055588555000000000000000000000000000000000000000000000000cccccccc888888880006aaaaaaaaaaaaaaaaaaaaaaaa6000
00060000000000000000000055888855000000000000000000000000000000000000000000000000cccccccc8888888800006aaaaaaaaaaaaaaaaaaaaaa60000
00006000000000000000000058888885000000000000000000000000000000000000000000000000cccccccc88888888000006aaaaaaaaaaaaaaaaaaaa600000
00060000000000000000000058888885000000000000000000000000000000000000000000000000cccccccc888888880000006aaaaaaaaaaaaaaaaaa6000000
00006000000000000000000058887885000000000000000000000000000000000000000000000000cccccccc88888888000000066aaaaaaaaaaaaaa660000000
00060000000000000000000058877885000000000000000000000000000000000000000000000000cccccccc88888888000000000666aaaaaaaa666000000000
00006000000000000000000058877885000000000000000000000000000000000000000000000000cccccccc8888888800000000000066666666000000000000
__gff__
0000000000000000000000000202020200000000000000000000000002020202010000000000000000000000020202020000000000000000000000000202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2020202020202020202020202020200020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000
2020202000002020200000202020202000202020000000002020000020000000202020202020200020202000202020202020202020202020202020202020202020202000300023000030003320202020200000000020202020202000000033200000000000000000000000000000000000000000000000000000000000000000
2020002020002020202000202020202000202020000000002000000020000020202000202020002020202020202020202020202020202020202020202020202020200000300023000030003320202020200000000020202020202000000033200000000000000000000000000000000000000000000000000000000000000000
2020202020202000202020000020202000002000000000002000202020000020202020202020202020200020000020202020202020202020202020202020202020000000300000000030000020202020200000000020202020202000000020200000000000000000000000000000000000000000000000000000000000000000
2020202020202000200020202020202000200000000000000000202000002020202020202020202020202020202020202020202020202020202020202020202000000000300000000020000000202020200000000020202020202000000000200000000000000000000000000000000000000000000000000000000000000000
2020200020202020202020202020202000000000000000000000200000002000002020200020002020200000200020202020202020202020202020202020202000000000300000002000000000002020200000000020202020202000000000200000000000000000000000000000000000000000000000000000000000000000
2020002020200020202020202020202000000000000000000000200000000000002020200020000020200000202020202020202020202020202020202020202000000000300000200000000000000020200000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
2020202020000020202020202020202000000000000000000000000000000000002000200000000000200000000020202000200000202000002000202030000000000000200000000000000000000000200000000020202020202000000000200000000000000000000000000000000000000000000000000000000000000000
2020202000000000202020200020202000202000000000000000000000000000002000000000000000000000000000202000000000203000000000200030002300000000002000000000000000000000200000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
2020000000000000200000200000202000202000000000000000000000000000000000000000000000000000000000203300000000303000000000000020002300000000000020000000000000000000200000000020202020202000000000200000000000000000000000000000000000000000000000000000000000000000
200000000000000020000000000000000020200000000000000000000000003b000000000000000000000000000033203300000000303000000000000000002000000000000000000000000000000000200000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
200000000000000020000000000000000000200000000000000000000000003b000000000000000000000020000033202020202000202000202020002020202020202020202020202020202020202020200000000020202020202000000000200000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000002020202020202020202000000020202020202020202000000000202020002020202020202020000000000000000020202020200000000020202020202000000023200000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000203b000000000000002020200020202020232020202020202020202020202020202020202020202a2a2a2a2a2a2a2a20202020200500000020202020202000000023200000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000003b000000000000000000000000000000232020202020202020202020202020202020202020203a3a3a3a3a3a3a3a20202020202020000020202020202000002020200000000000000000000000000000000000000000000000000000000000000000
20202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020203a3a3a3a3a3a3a3a20202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
300100000904008030090200c0200e0301203015040190401c04023050270500a0000d0000f00013000170001f0002a0003e0003f0002e000240001d00017000120000f0000c0000a00008000060000500005000
000200000c5201052014530195301e53022540265402a54016520185201b5301f5302254026540295402c5202e5201e520215302453026530295302b5302d5302f540315403454037540395403c5503e5503f550
000100000254002540025400454006540095400b5400e5401054012540145401555016550175501755017550165501555013550115500e5500c5400b540095400854007540065400554004540035400254002540
000200000e01009010050100001001000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500201073012731147311573117731197311773115731147311273110731107311273114731157311773119731197311773115731147311273110731107311273114731157311773119731197311773113731
000200002d554235411d5411654113531115310f5310e5210d5210b5210b5210a5110a5110a5210b5310d53110531155311c54122541295412e5413255135551385513b5513d5513e5513e5513f5513f5513f551
000200003b56436561315512c5512855125551225511f5411d5411a541185411553113531115310f5210d5210c5210a5110951108511065110551104511045110351103511025110251102511015110151101511
00030020017400174101741027410374105741087410b7410e7411075112751137511475115751157511575115751157511475114751137511275111741107410d7410c7410a7410874105741037410174100741
00020000360702d67025060206601c060186501605013650100500f6500d0500b6500904007640050400464003040026300163001630016300161001610016100161000610006100061000610006100061000610
000400003e06338655340552d64028045256532f0452b6432804326033226351e0531b64518043280352563322033206331a0351764316635220331c62516013116130e0130b6150701307015046100101501615
001000000c053306051861500700306253800318615000030c053000031861500003306250000318615000030c0530000324605000033c6050000324605000030c003000030c0003062530625306253062500000
01100020024000250002045021200e01002145020200e11002040021250e01002140020250e11002040021150e04002120020150e14002020021150e04002120020150e14002020021150e04002110020450e110
000300200974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743
001000200c0431834318343372412464318343372410f2430c04318343372410f3432464318343372410f3430c0433724118343372412464337241183430f3430c04337241183433724124643372410f3431b643
00100020021000200002140020250e11002040020250e1100204002025021100e14002025020100e14002015020400e1200201002045021200e1100204002125020100e14002120020150e04002120021400e015
001a00201a1401d030210401c1301f040230301a1401d0301a1401d030210401c1301f040230301d140210301814021130230401f1301c1401a1301f1401c03021140181302104023130211401f1301c1401d130
011800201c0501d0501e0501f050210502305024050260501c7001f7001f7001c7001c7001a7001f7001a7001a700187001f700187001f7001c7001c7001f7001c700187001c7000070000700007000070000000
010100200905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053
012000201a0501a0501a0101a0101d0501d0501d0101d0101c0501c0501c0101c0101f0501f0501f0101f0101a0501a0501a0101a0101d0501d0501d0101d0101c0501c0501c0101c0101f0501f0501f0101f010
011000201a6530000000000000001d6530000000000000001a6531a6531a653000001d6530000000000000001a6531a6531a653000001d6531d65300000000001a6531a6531a653000001d6531d6531d6531d653
011000202615026150261202612029150291502912029120281502815028120281202b1502b1502b1202b1202615026150261202612029150291502912029120281502815028120281202b1502b1502b1202b120
011000001a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0001a0001a0001a000
01100000000000000000000000002604026030290402903028040280302b0402b0302604026030290402903028040280302b0402b0302604026030290402903028040280302b0402b03026040260302904029030
011000001a6000000000000000001a6531d6001d653000001a6531d6001d6531a6001a6531d6001d653000001a6531a6001d6531d6531a6531a6001d6531d6001a653000001d6531a6001a6531d6001d65300000
01080020280402804028030280302b0402b0402b0302b0302604026040260302603029040290402903029030280402804028030280302b0402b0402b0302b0302604026040260302603029040290402903029030
011000001a6531d6001d653000001a6531d6001d6531a6001a6531d6001d653000001a6531a6001d6531d6531a6531a6001d6531d6001a653000001d6531d6531d6531d6001d6531d6001d6531d6531d6531d653
011000002d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0402d0402d0402d0402d0402d0402d0302d0302d0302d0302d0302d0202d0202d0202d0102d010
011000200c0520000207052000020a0520c052000020c052000020c05207052000020a052000020c052000020c0520000207052000020a0520c0520c0020c0520c0020c05207052000020a052000020c00000002
011000040075300700007530070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010800002b0000000029000000002b000000002900000000280000000029000000002800000000260000000028000000002600000000240000000021000000001d000000001d000000001f000000002300000000
001000201d050240502905024050290502905029050240502405027050290500000024050240502405000000000002405029050220501f0502205024050240502405024050270502905027050270502405024050
001000001c0501d0501e0501f0502105023050240501c0001d0001f00021000200001c0001d0001f000200001c0001d0001e0001f000210002300024000000000000000000000000000000000000000000000000
001000201f0401f0201b0401b020160401602014040140201f0401f0201b0401b0201604016020140401402020040200201b0401b0201804018020160401602020040200201b0401b02018040180201604016020
0010000016720167201f7201f7201b7201b720167201672014720147201f7201f7201b7201b7201672016720147201472020720207201b7201b7201872018720167201672020720207201b7201b7201872018720
012000002b1002b1002b1002b1002b1002b1002b1002b1002b1002b1002b1002b1002b1002b1002b1002b1002e1002d1002b100241002d1002a1002d1002e1002a100281002b1002b1002b1002c1002c1002b100
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
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000000500000000000000000c050000000000000000000500000000000000000c050000000000000000000500000000000000000c050000000000000000000500000000000000000c050000000000000000
01100000020500000000000000000e050000000000000000020500000000000000000e050000000000000000020500000000000000000e0500000000000000000205000000000000000010050000000000000000
012000001c050180001a0001a0501c0001a0001805018000180001a0001a000180001c0001a00018050180001c0001c000180001a0001c0001800018000180001800000000000000000000000000000000000000
012000001c050180001a0001a0501c0001a0001805018000180001a0001a000180001c0001a0001c0501c0001c0001c000180001a0001c0001800018000180001800000000000000000000000000000000000000
011000200c0130c0030c003000530c0330c0030c0030c0030c0130c0030c003000530c0530c0030c0030c0030c0130c00300000000530c033000530c003000000c0530c0030c003000530c0530c0030c00300000
010f00002770027700277002770027700277003070030700307003070030700307002770027700277002770027700307002e7002e7002e7002e7002e7002b7002b7002e7002e7002b7002e7002b7002e70033700
010f00003070030700337003370035700377003770037700377003570033700307003070030700307003370035700377003770035700337003370033700337003770033700307003370037700337000000000000
010f0000030000300003000030000300003000030000500005000050000500005000050000300000000000000000000000030000500005000070000700007000050000300005000070000a000050000700003000
010f00201f0001f0002200024000270002700024000220001f0001f0001f00024000270002700024000220001f0001d0001f000220002700029000240001f0001f0001d000240002b000270001f0002900000000
__music__
01 097e7d7c
03 090b4f7c
01 12137d7c
00 14137d7c
00 154c4e44
00 16177d44
03 1819585a
03 20217d7c
01 3b3c4344
00 37434344
01 37794344
00 383a4344
00 37394344
00 37394344
00 383a4344
02 37394344
01 1b1c4344
03 1b1c4344

