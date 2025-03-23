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
	music(10)
end

function _update()
	frames=((frames+1)%30)
	update_player()
	update_light()
	update_objects()
	cx = flr(room.x / 128) * 128
	cy = flr(room.y / 128) * 128
end

function _draw()
	cls()
	camera(cx, cy)
	draw_light()
	map(0, 0, 0, 0)
	draw_objects()
	draw_player()
	draw_room()
	-- line()
	if btn(🅾️) and lulu.select then
		-- Dessiner la grid de la map
		-- for i=0,1 do
		-- 	for j=0,16 do
		-- 		if (i == 0) line(0, max(0,(j*8)),128,max(0,(j*8)), 8)
		-- 		if (i == 1) line(max(0,(j*8)),0,max(0,(j*8)),128,8)
		-- 	end
		-- end
		pset(ima_light.x,ima_light.y,11)
		circ(lulu.x_g, lulu.y_g, lulu.ima_range, 12) --desinner le circle de ima_light
	end
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
		lights_left = 3,
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
		light_selected = 
		{
			nil, -- id light
			0 -- index dynamique
		},
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
	--if they have finished the lvl
	if pactual.passed then
		if lulu.passed and hades.passed then
			lulu.passed = false
			hades.passed = false
		end
		switch_character()
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
	pactual.dy += 0.20

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

	if check_flag(0, pactual.x, pactual.y) or check_flag(0, pactual.x + 7, pactual.y) then
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
	if not lulu.in_light or hades.in_light then
		restart_level()
	end


	pactual.y_g = ceil(pactual.y / 8) * 8
	pactual.x_g = ceil(pactual.x / 8) * 8

	--clamp れき la map
	pactual.x = mid(room.x, pactual.x, room.w - 8)
	pactual.y = mid(room.y, pactual.y, room.h - 8)
	--animations
	if not pactual.g then
		pactual.sprite = pactual.default_sprite + 1
	else
		pactual.sprite = pactual.default_sprite
	end
end

function switch_character()
	--switch characters
	if (pactual == lulu) then
		pactual = hades
		lulu.select = false
		hades.select = true
	elseif (pactual == hades) then
		pactual = lulu
		lulu.select = true
		hades.select = false
	end
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
		color = 9
	}
	lights = {}
	create_light(-2 * 8, 10 * 8, 52)
	create_light(9 * 8, 12 * 8, 32)
	create_light(18 * 8, 12 * 8, 32)
end

function update_light()

	-- lulu
		if btn(🅾️) then
			if lulu.select then
				update_light_lulu()
			end
				--hades
			if hades.select then
				update_light_hades()
			end
		end
		if (hades.select and not btn(🅾️)) hades.light_selected[1] = nil
		if (lulu.select and not btn(🅾️)) lulu.using_light = false
end

function update_light_lulu()
	if not lulu.using_light then
		--setting position of light
		ima_light.y = lulu.y_g
		ima_light.x = lulu.x_g
		lulu.using_light = true
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
			if not check_flag(0, x, y) and frames % 3 == 0 then
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
		lulu.lights_left -= 1
	end
end

function update_light_hades()
	-- hades a une variable qui stocke temporairement la light selected
	if #lights > 0 then
		local index = hades.light_selected[2]
		local count = #lights
		hades.light_selected[1] = lights[index + 1]
		if (btnp(➡️)) hades.light_selected[2] = (hades.light_selected[2] + 1) % count
		if (btnp(⬅️)) hades.light_selected[2] = (hades.light_selected[2] - 1) % count

		if btnp(❎) then
			del(lights,hades.light_selected[1])
			hades.light_selected[2] = 0
		end
	end
end

function draw_light()
	draw_lights()
	draw_imaginary_light()
	draw_hades_turnoff()
end

function draw_imaginary_light()
	if btn(🅾️) and lulu.select then
		circfill(ima_light.x, ima_light.y, ima_light.radius / 2, ima_light.color)
		pset(ima_light.x,ima_light.y,8)
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
	if (hades.light_selected[1] != nil) then
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
end

function next_room()
	-- room.x = flr(lulu.x / 128) * 128
	-- room.y = flr(lulu.y / 128) * 128
	-- room.w = room.x + 128
	-- room.h = room.y + 128
	-- room.id = index_room(room.x, room.y)

	--[[ TEST ]]
	local x = (room.x + 128)
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
		room.id = 1
	end


	return {
		id,
		x,
		y,
		w,
		h
	}
end

function index_room(x, y)
	return flr(x / 128) + flr(y / 128) * 8
end
function draw_room()
	-- print("room:"..room.id, room.x + 10, room.y + 10, 8)
end

function restart_level()
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
	if (collision(lulu,doors.lulu)) lulu.passed = true
	if (collision(hades,doors.hades)) hades.passed = true
end

--animations
function draw_objects()
	--doors
	local flip = frames % 10 >= 5  -- Alterne toutes les 5 frames
	local top_spr = 35
	local bottom_spr = 51

	-- Dessine la porte dimensionnelle
	spr(top_spr, doors.lulu.x, doors.lulu.y, 1, 1, flip, false)
	spr(bottom_spr, doors.lulu.x, doors.lulu.y + 8, 1, 1, flip, false)

	spr(top_spr, doors.hades.x, doors.hades.y, 1, 1, flip, false)
	spr(bottom_spr, doors.hades.x, doors.hades.y + 8, 1, 1, flip, false)
end

-->8
--helper functions

function debug_print()
	if (collision(lulu,doors.lulu)) print("collides !",10,50,8)
	-- print("door lulu: "..doors.lulu.x,10,20,8)
	-- print(doors.lulu.y,65,20,8)
	-- print("lulu: "..flr(lulu.x),10,30,9)
	-- print(flr(lulu.y),45,30,9)
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
	result = sqrt((p.x + p.h / 2 - l.x - l.radius / 2) ^ 2 + (p.y - l.y - l.radius / 2) ^ 2) < l.radius / 2
	return result
end

__gfx__
00000000088888800888888000000000000000000222222002222220000000000000000000000000000000000000000000000000000066666666000000000000
000000008888888888888888000000000000000022222222222222220000000000000000000000000000000000000000000000000666aaaaaaaa666000000000
007007008899999888999998000000000000000022222f2222222f220000000000000000000000000000000000000000000000066aaaaaaaaaaaaaa660000000
00077000899ff9f9899ff9f900000000000000000229ff920229ff9200000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaa6000000
0007700089fc9fc989fc9fc90000000000000000022ffff2022ffff20000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaa600000
00700700089fff90089fff9000000000000000000121d1020121d102000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaa60000
000000000088880004888840000000000000000001dddd0005dddd5000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaa6000
000000000040040000000000000000000000000001500500010000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
666666660000000000000000dddddddd00000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
655555560000000000000000dddccddd00000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
655555560000000000000000ddccccdd00000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
655555560000000000000000dccccccd00000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
655555560000000000000000dccccccd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
655555560000000000000000dccc7ccd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
655555560000000000000000dcc77ccd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
666666660000000000000000dcc77ccd0000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
000000000000000000000000dcc77ccd0000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
000000000000000000000000dcc77ccd00000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaa6000
000000000000000000000000dcc7cccd000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaa60000
000000000000000000000000dccccccd0000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaa600000
000000000000000000000000dccccccd00000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaa6000000
000000000000000000000000ddccccdd0000000000000000000000000000000000000000000000000000000000000000000000066aaaaaaaaaaaaaa660000000
000000000000000000000000dddccddd0000000000000000000000000000000000000000000000000000000000000000000000000666aaaaaaaa666000000000
000000000000000000000000dddddddd000000000000000000000000000000000000000000000000000000000000000000000000000066666666000000000000
__gff__
0000000000000000000000000202020200000000000000000000000002020202010000000000000000000000020202020000000000000000000000000202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000020202020202020202020202020202020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2020202020202020202020202020202020202020202020202020202020202020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
2000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
300100000904008030090200c0200e0301203015040190401c04023050270500a0000d0000f00013000170001f0002a0003e0003f0002e000240001d00017000120000f0000c0000a00008000060000500005000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000337000000037700000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000200c053306051861500700306253800318615000030c053000031861500003306250000318615000030c053000031861500003306250000318615000030c05300003186150000330625000001861530635
011000000c053306051861500700306253800318615000030c053000031861500003306250000318615000030c0530000324605000033c6050000324605000030c003000030c0003062530625306253062530625
01100020024000250002045021200e01002145020200e11002040021250e01002140020250e11002040021150e04002120020150e14002020021150e04002120020150e14002020021150e04002110020450e110
000300200974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743097430974309743
011000200c0431834318343372412464318343372410f2430c04318343372410f3432464318343372410f3430c0433724118343372412464337241183430f3430c04337241183433724124643372410f3431b643
01100020021000200002140020250e11002040020250e1100204002025021100e14002025020100e14002015020400e1200201002045021200e1100204002125020100e14002120020150e04002120021400e015
011a00201a1401d030210401c1301f040230301a1401d0301a1401d030210401c1301f040230301d140210301814021130230401f1301c1401a1301f1401c03021140181302104023130211401f1301c1401d130
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
011000201d050240502905024050290502905029050240502405027050290500000024050240502405000000000002405029050220501f0502205024050240502405024050270502905027050270502405024050
011000001c0501d0501e0501f0502105023050240501c0001d0001f00021000200001c0001d0001f000200001c0001d0001e0001f000210002300024000000000000000000000000000000000000000000000000
011000201f0401f0201b0401b020160401602014040140201f0401f0201b0401b0201604016020140401402020040200201b0401b0201804018020160401602020040200201b0401b02018040180201604016020
0110000016720167201f7201f7201b7201b720167201672014720147201f7201f7201b7201b7201672016720147201472020720207201b7201b7201872018720167201672020720207201b7201b7201872018720
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
00 02034344
01 37794344
00 383a4344
00 37394344
00 37394344
00 383a4344
02 37394344
01 1b1c4344
03 1b1c4344

