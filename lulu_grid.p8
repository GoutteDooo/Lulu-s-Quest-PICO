pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
function _init()
	init_player()
	init_light()
	init_room()
	cx = 0
	cy = 0
	music(10)
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
		x_g = x,
		y_g = y,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		dj = false,
		default_sprite = 1,
		sprite = 1,
		flipx = false,
		select = true,
		in_light = true,
		id = "lulu"
	}
	ph = {
		x = 15 * 8,
		y = 14 * 8,
		x_g = x,
		y_g = y,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		dj = false,
		default_sprite = 5,
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
	if btnp(⬇️) and not btn(🅾️) then
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
		if pactual.g or pactual.dj then
			pactual.dy = -2.5
			sfx(0)
			if not pactual.g and pactual.dj then
				pactual.dj = false
			end
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

	pactual.y_g = ceil(pactual.y / 8) * 8
	pactual.x_g = ceil(pactual.x / 8) * 8

	--animations
	if not pactual.g then
		pactual.sprite = pactual.default_sprite + 1
	else
		pactual.sprite = pactual.default_sprite
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

	-- after
	-- dresser la grille de la map (dans draw)
	-- x et y de ima_light doivent れちtre au plus proche du x et y de lulu
	-- lorsqu'une direction est pressれたe, dれたplacer l'ima_light
	-- 
	-- before
	if btn(🅾️) and pl.select then
		ima_light.x = pl.x + 4
		ima_light.y = pl.y + 8 - (ima_light.radius / 2)
		local xsign = 0
		local ysign = 0
		local dirpressed = false
		if btn(⬅️) then
			xsign = -1
		end
		if btn(➡️) then
			xsign = 1
		end
		if btn(⬆️) then
			ysign = -1
		end
		if btn(⬇️) then
			ysign = 1
		end
		if btn(⬅️)
			or btn(➡️)
			or btn(⬆️)
			or btn(⬇️) 
		then
			dirpressed = true
		end
		if dirpressed then
			-- checks for collisions
			-- moves at the farthest possible until we hit a wall
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
	-- line()
	if btn(🅾️) and pl.select then
		-- Dessiner la grid de la map
		for i=0,1 do
			for j=0,16 do
				if (i == 0) line(0,j*8,128, j*8, 8)
				if (i == 1) line(j*8,0,j*8,128,8)
			end
		end
	end

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
	if pactual.x_g != nil then
			print("("..pactual.x_g, 5, 20, 8)
			print(";"..pactual.y_g, 20, 20, 8)
			print(")", 35, 20, 8)
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
00000000088888800888888000000000000000000222222002222220000000000000000000000000000000000000000000000000000066666666000000000000
000000008888888888888888000000000000000022222222222222220000000000000000000000000000000000000000000000000666aaaaaaaa666000000000
007007008899999888999998000000000000000022222f2222222f220000000000000000000000000000000000000000000000066aaaaaaaaaaaaaa660000000
00077000899ff9f9899ff9f900000000000000000229ff920229ff9200000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaa6000000
0007700089fc9fc989fc9fc90000000000000000022ffff2022ffff20000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaa600000
00700700089fff90089fff9000000000000000000121d1020121d102000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaa60000
000000000088880000848840000000000000000001dddd0001d5dd5000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaa6000
000000000040040000000000000000000000000001500500010000000000000000000000000000000000000000000000006aaaaaaaaaaaaaaaaaaaaaaaaaa600
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
2000200000200000000000000000002020000000000000000000000020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000200000202020200000000000202020000000000000000000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000200000202020202000000000000020000000000000000000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000202020202000000000000020000000000000200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2000000000200020202000000000000020000000000020200000200020002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

