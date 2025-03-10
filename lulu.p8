pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function _init()
	init_player()
	init_light()
	init_room()
	cx = 0
	cy = 0
end

function _update()
	update_player()
	update_light()
	update_room()
	cx = flr(pl.x / 128) * 128
	cy = flr(pl.y / 128) * 128
end

function _draw()
	cls()
	camera(cx, cy)
	draw_light()
	map(0, 0, 0, 0)
	draw_player()
	draw_room()
	debug_print()
end

-->8
--player

function init_player()
	pl = {
		x = 1 * 8,
		y = 2 * 8,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		dj = false,
		sprite = 1,
		flipx = false,
		select = true,
		in_light = true,
		id = "lulu"
	}
	ph = {
		x = 15 * 8,
		y = 14 * 8,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		dj = false,
		sprite = 5,
		flipx = true,
		select = false,
		in_light = false,
		id = "hades"
	}
	pactual = pl
end

function draw_player()
	spr(pl.sprite, pl.x, pl.y, 1, 1, pl.flipx)
	spr(ph.sprite, ph.x, ph.y, 1, 1, ph.flipx)
end

function update_player()
	if btn(🅾️) then
		if btn(⬅️) then
			pactual.flipx = true
		end
		if btn(➡️) then
			pactual.flipx = false
		end
		return
	end

	--switch characters
	if btnp(⬅️) and btnp(➡️) then
		--switch characters
		if (pactual == pl) then
			pactual = ph
			pl.select = false
			ph.select = true
		elseif (pactual == ph) then
			pactual = pl
			pl.select = true
			ph.select = false
		end
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
		elseif pactual.dj then
			pactual.dy = -2.5
			pactual.dj = false
		end
	end
	pactual.y += pactual.dy
	pactual.dx *= 0.6
	pactual.dy += 0.20

	-- interact(newx, newy)
	if check_flag(0, pactual.x + 3, pactual.y + 8) or check_flag(0, pactual.x + 5, pactual.y + 8) then
		pactual.g = true
		pactual.dj = true
		pactual.dy = 0
		pactual.y = flr(pactual.y / 8) * 8
	else
		pactual.g = false
		-- pactual.y = mid(room.y, pactual.y, room.h)
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
	if not pl.in_light or ph.in_light then
		restart_level()
	end
end

function interact(x, y)
	if check_flag(1, x, y) then
		return
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
		x = pl.x + 4,
		y = pl.x + 4,
		radius = 32,
		color = 9
	}
	lights = {}
	-- create_light(2 * 8, 11 * 8, 32)
	create_light(-2 * 8, 1 * 8, 64)
	create_light(-2 * 8, 8 * 8, 52)
	create_light(6 * 8, 13 * 8, 16)
	create_light(9 * 8, 12 * 8, 32)
end

function update_light()
	if btn(🅾️) and pl.select then
		ima_light.x = pl.x + 4
		ima_light.y = pl.y + 8 - (ima_light.radius / 2)
		local xsign = 0
		local ysign = 0
		local dirpressed = false
		if btn(⬅️) then
			xsign = -1
			dirpressed = true
		end
		if btn(➡️) then
			xsign = 1
			dirpressed = true
		end
		if btn(⬆️) then
			ysign = -1
			dirpressed = true
		end
		if btn(⬇️) then
			ysign = 1
			dirpressed = true
		end
		if dirpressed then
			--check for collisions
			-- move at the farthest possible until we hit a wall
			local x = ima_light.x + xsign
			local y = ima_light.y + ysign
			while not check_flag(0, x, y) do
				x += xsign
				y += ysign
				ima_light.x = x
				ima_light.y = y
				if check_flag(0, x, y) then
					ima_light.x -= xsign * (ima_light.radius / 2)
					ima_light.y -= ysign * (ima_light.radius / 2)
				end
				if x < room.x or x > room.w or y < room.y or y > room.h then
					-- no walls left
					break
				end
			end
		end
		if btn(❎) and pl.select then
			local x = ima_light.x - (ima_light.radius / 2)
			local y = ima_light.y - (ima_light.radius / 2)
			create_light(x, y, ima_light.radius)
		end
	end
end

function draw_light()
	draw_lights()
	draw_imaginary_light()
end

function draw_imaginary_light()
	if btn(🅾️) and pl.select then
		circfill(ima_light.x, ima_light.y, ima_light.radius / 2, ima_light.color)
	end
end

function draw_lights()
	foreach(
		lights, function(l)
			sspr(12 * 8, 0, l.w, l.h, l.x, l.y, l.radius, l.radius)
		end
	)
end

function create_light(x, y, r, flag, color)
	local new_light = {
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

function update_room()
	room.x = flr(pl.x / 128) * 128
	room.y = flr(pl.y / 128) * 128
	room.w = room.x + 128
	room.h = room.y + 128
	room.id = index_room(room.x, room.y)
end

function index_room(x, y)
	return flr(room.x / 128) + flr(room.y / 128) * 8
end

function draw_room()
	print(room.id, room.x + 10, room.y + 10, 7)
end

function restart_level()
	_init()
end

-->8
--helper functions

function debug_print()
	for l in all(lights) do
		if collision_light(pl, l) then
			print("collision", 10, 20, 7)
		end
	end
end

--collisions
function collision(a, b)
	return not (a.x > b.x + b.w
				or a.y > b.y + b.h
				or a.x + a.w < b.x
				or a.y + a.h < b.y)
end

function collision_light(p, l)
	result = sqrt((p.x + p.h / 2 - l.x - l.radius / 2) ^ 2 + (p.y - l.y - l.radius / 2) ^ 2) < l.radius / 2
	return result
end

__gfx__
00000000088888800000000000000000000000000222222000000000000000000000000000000000000000000000000000000000000066666666000000000000
000000008888888800000000000000000000000022222222000000000000000000000000000000000000000000000000000000000666aaaaaaaa666000000000
007007008899999800000000000000000000000022222f22000000000000000000000000000000000000000000000000000000066aaaaaaaaaaaaaa660000000
00077000899ff9f90000000000000000000000000229ff920000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaa6000000
0007700089fc9fc9000000000000000000000000022ffff2000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaa600000
00700700089fff900000000000000000000000000121d10200000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaa60000
000000000088880000000000000000000000000001dddd000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaa6000
000000000040040000000000000000000000000001500500000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
6666666600000000000000000dddddd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
6555555600000000000000000dddddd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
6555555600000000000000000ddccdd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
6555555600000000000000000ddccdd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6
6555555600000000000000000ddccddd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
655555560000000000000000dddc7ddd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
655555560000000000000000ddd77ddd000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaaaa60
666666660000000000000000ddd77ddd0000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
000000000000000000000000ddd77ddd0000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
000000000000000000000000ddd77ddd00000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaa6000
000000000000000000000000ddd7cddd000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaa60000
000000000000000000000000dddccdd00000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaa600000
0000000000000000000000000ddccdd000000000000000000000000000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaa6000000
0000000000000000000000000ddccdd00000000000000000000000000000000000000000000000000000000000000000000000066aaaaaaaaaaaaaa660000000
0000000000000000000000000dddddd00000000000000000000000000000000000000000000000000000000000000000000000000666aaaaaaaa666000000000
0000000000000000000000000dddddd0000000000000000000000000000000000000000000000000000000000000000000000000000066666666000000000000
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
00000000000000000000000000000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000202020200000000000000000000000002020202010000000000000000000000020202020000000000000000000000000202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2000202020202020202020202020202020202020202020202020202020202020000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000202000202000202020200000202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000202000202000002020202000202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000202000200000000020002000200020000000000000000000000000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000202000000000000000002000000020000000000000000000000000002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000202000000000000000000000000020000000000000000000000000002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000200000000000000000000000002020000000000000000000000020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000200000002020200000000000202020000000000000000000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000200000002020202000000000000020000000000000000000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000002020202000000000000020000000000000200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000020202000000000000020000000000020200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000202000000000000020000000002020200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000200000000000000020000000202020200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000023202300000000000020000020202020200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000033203300000000000020002020202020200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2020202020202020202020202020202020202020202020200000200020002020200000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020202020202000000000200020000020200000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020202020202000000000200020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020202020202000000000200000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020202020200000000000200000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020202020200000000000200000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020202020000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000002000000000202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000000020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000002020202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000000000000000000000000000202020202020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
