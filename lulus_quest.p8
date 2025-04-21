pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
SFX = {
	{0,-1,0,12},
	{0,-1,16,20},
}
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
	bo_spr = 22
	music(7)
	--DEBUG
	debug_light = false
	--TEST
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
	map(0, 0, 0, 0, 128, 128, 0)
	draw_light()
	map(0, 0, 0, 0, 128, 128, 7)
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
		id = "lulu",
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
		sprite_hide = 3,
		flipx = false,
		select = true,
		in_light = true,
		using_light = false, --to know if player is holding C key
		using_black_light = false,
		ima_range = 6 * 8, --range of ima_light
		lights_left = 1,
		passed = false, --pass lvl
		shield = {
			timer = 0,
			time_set = 5*30,
			active = true,
			r = 16,
		}
	}
	hades = {
		id = "hades",
		x = 15 * 8,
		y = 13 * 8,
		x_g = x,
		y_g = y,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		default_sprite = 5,
		sprite = 5,
		sprite_hide = 7,
		flipx = true,
		select = false,
		in_light = false,
		using_light	= false,
		using_black_light = false,
		ima_range = 6 * 8, 
		light_selected = 
		{
			nil, -- id light
			0 -- index dynamique
		},
		turnoffs_left = 1,
		passed = false, --pass lvl
	}
	keys_owned = 0
	pactual = lulu
end

function draw_player()
	--if they have finished the lvl
	if not (lulu.passed) then
		lulu.sprite = pactual == lulu and lulu.sprite or lulu.sprite_hide
		spr(lulu.sprite, lulu.x, lulu.y, 1, 1, lulu.flipx)
	end
	if not (hades.passed) then
		hades.sprite = pactual == hades and hades.sprite or hades.sprite_hide
		if hades.sprite == hades.sprite_hide then
			palt(0,false)
			palt(12,true)
		end
		spr(hades.sprite, hades.x, hades.y, 1, 1, hades.flipx)
		palt()
	end
end

function update_player()
	--delay when switching
	if is_in_switch then
		is_in_switch = frames == 30 and true or false
		return
	end
	--if they have finished the lvl
	if pactual.passed then
		switch_character()
		return
	end

	if pactual.using_black_light then
		update_black_light()
		return
	end

	if btn(🅾️) then
		if pactual == lulu and ima_light.x != nil then
			if ima_light.x > lulu.x then
				lulu.flipx = false
			else
				lulu.flipx = true
			end
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
			-- sfx(0,-1,0,12)
			sfx(SFX[1][1],SFX[1][2],SFX[1][3],SFX[1][4])
		end
	end
	pactual.y += pactual.dy
	pactual.dx *= 0.6
	if pactual == lulu then
		pactual.dy += 0.20
	else
		pactual.dy += 0.13
	end

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

	--if fall in water or lava

	if check_flag(1, pactual.x + 4, pactual.y) then
		restart_level()
		sfx(8)
		return
	end

	--collisions lulu and light
	pactual.in_light = false
	for l in all(lights) do
		if collision_light(pactual, l) then
			pactual.in_light = true
			break
		end
	end

	--maybe pactual has collide with a light, but if it is in black light, it cancels the condition
		for bl in all(black_lights) do
			if collision_black_light(pactual, bl) then
				if pactual == lulu then
					pactual.in_light = true
					break
				elseif pactual == hades then
					pactual.in_light = false
					break
				end
			end
		end

	--shield of lulu
		if lulu.shield.r and lulu.shield.active then
			lulu.shield.timer = lulu.shield.timer + 1 -- 30 fps (ex: 150 = 5 secondes)
			lulu.in_light = true
			if collision_black_light(hades, {x = lulu.x or 0, y = lulu.y or 0, r = lulu.shield.r - 4 or 0}) then
				hades.in_light = true
			end
			if lulu.shield.timer > lulu.shield.time_set then
				lulu.shield.active = false
				lulu.shield.timer = 0
				lulu.shield.time_set = 0
			end
		end

		--CONDITIONS FOR LIGHTS
	if (not lulu.in_light and not lulu.passed) or (hades.in_light and not hades.passed) or pactual.y >= room.h-1 then
		if lives > 0 then
			-- lives = lives - 1
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

	--interactions
	if black_orbs[1] != nil then
		foreach(
			black_orbs, function(bo)
				if collision(pactual, bo) then
					pactual.using_black_light = true
					ima_light_bo.x = pactual.x_g
					ima_light_bo.y = pactual.y_g
					ima_light_bo.r = bo.r
					sfx(10)
					del(black_orbs,bo)
				end
			end
		)
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
				-- sfx(3)
				sfx(SFX[2][1],SFX[2][2],SFX[2][3],SFX[2][4])
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

function disable_shield()
	lulu.shield.active = false
	lulu.shield.timer = 0
	lulu.shield.time_set = 0
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
		r = 16,
		color = 12
	}
	lights = {}
	create_light(-2 * 8, 10 * 8, 26)
	create_light(9 * 8, 12 * 8, 16)
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
	if not btn(🅾️) then 
		lulu.using_light = false
		hades.using_light = false
		hades.light_selected[1] = nil
		sfx(7,-2)
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
		local x = ima_light.x - ima_light.r
		local y = ima_light.y - ima_light.r
		create_light(x, y, ima_light.r,"white",1,10)
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

function update_black_light()
	local xsign = 0
	local ysign = 0
	local dirpressed = false
	
	if (btn(⬅️)) xsign = -1
	if (btn(➡️)) xsign = 1
	if (btn(⬆️)) ysign = -1
	if (btn(⬇️)) ysign = 1
	if ((btn(⬅️)) or (btn(➡️)) or (btn(⬆️)) or (btn(⬇️))) dirpressed = true

	if dirpressed then
			local x = ima_light_bo.x + xsign * 8
			local y = ima_light_bo.y + ysign * 8
			
			-- Vれたrification du dれたplacement normal
			if frames % 3 == 0 then
				ima_light_bo.x = mid(room.x, flr(x / 8) * 8, room.w)
				ima_light_bo.y = mid(room.y, flr(y / 8) * 8, room.h)
			end

		-- Vれたrification de la distance par rapport au joueur (lulu)
		local dx = ima_light_bo.x - pactual.x_g
		local dy = ima_light_bo.y - pactual.y_g
		local dist = sqrt(dx * dx + dy * dy)

		if dist > pactual.ima_range then
				-- Limiter la position sur le cercle
				local angle = atan2(dx, dy)
				ima_light_bo.x = pactual.x_g + round((cos(angle) * pactual.ima_range)/8)*8
				ima_light_bo.y = pactual.y_g + round((sin(angle) * pactual.ima_range)/8)*8
		end
	end

	if btnp(❎) then
		local x = ima_light_bo.x
		local y = ima_light_bo.y
		create_light(x, y, ima_light_bo.r, "black")
		sfx(10, -2)
		sfx(11)
		pactual.using_black_light = false
	end
end

function draw_light()
	draw_lights()
	draw_imaginary_light()
	draw_hades_turnoff()
end

function draw_imaginary_light()
	if btn(🅾️) and lulu.select and lulu.lights_left > 0 then
		circfill(ima_light.x, ima_light.y, ima_light.r, ima_light.color)
		circ(lulu.x_g, lulu.y_g, lulu.ima_range, 12) --desinner le circle de ima_light
		-- pset(ima_light.x,ima_light.y,8)
	end
	if pactual.using_black_light then
		circfill(ima_light_bo.x, ima_light_bo.y, ima_light_bo.r, ima_light_bo.c)
		circ(pactual.x_g, pactual.y_g, pactual.ima_range, ima_light_bo.c)
	end
end

function draw_lights()
	foreach(
		lights, function(l)
			-- sspr(12 * 8, 0, l.w, l.h, l.x, l.y, l.r, l.r)
			circfill(l.x+l.r, l.y+l.r, l.r,l.color) 
			circ(l.x+l.r, l.y+l.r, l.r, 6)
		end
	)
	--black lights
	foreach(
		black_lights, function(bl)
			pal(14,3+128,1)
			circfill(bl.x, bl.y, bl.r, 14)
			circ(bl.x, bl.y, bl.r, 13)
		end
	)

	--shield
	if lulu.shield.active then
		-- on interpole le rayon pour qu'il diminue avec le temps
		local ratio = 1.2 - lulu.shield.timer / lulu.shield.time_set
		local r = ceil(lulu.shield.r * ratio)
		
		local cx = lulu.x + lulu.w / 2
		local cy = lulu.y + lulu.h / 2
		circfill(cx, cy, r, 12)
		circ(cx, cy, r, 7) 
	end
end

function draw_hades_turnoff()
	if (hades.light_selected[1] != nil) and #lights > 0 then
		--check if selected light already exists
		local i = hades.light_selected[2] + 1
		local x = lights[i].x + lights[i].r
		local y = lights[i].y+ lights[i].r
		local r = lights[i].r
		circfill(x, y, r, 8)
	end
end

function create_light(x, y, r, type, flag, color)
	local new_light = {
		id = #lights,
		x = x,
		y = y,
		r = r,
		h = 32,
		w = 32,
		flag = flag or 1,
		color = color or 9,
		type = type or "white"
	}

	if (type == "black") then
		new_light.flag = 2
		add(black_lights, new_light)
	else
		add(lights, new_light)
	end
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
				{x = 17, y = 10, r = 20},
				{x = 25, y = 11, r = 22}
			},
			pos = 
			{
				lulu = {x = 19, y = 14},
				hades = {x = 17, y = 7}
			},
			doors = 
			{
				lulu = {x = 30, y = 13},
				hades = {x = 31, y = 9}
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
				{x = 34, y = 9, r = 24},
				{x = 43, y = 9, r = 32}
			},
			pos = 
			{
				lulu = {x = 36, y = 11},
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
				{x = 50, y = 8, r = 19},
				{x = 56, y = 8, r = 23}
			},
			pos = 
			{
				lulu = {x = 53, y = 10},
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
				{x = 65, y = 8, r = 16},
				{x = 70, y = 0, r = 24},
				{x = 72, y = 8, r = 16}
			},
			pos = 
			{
				lulu = {x = 67, y = 10},
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
				{x = 91, y = 7, r = 24},
				{x = 83, y = 6, r = 16}
			},
			pos = 
			{
				lulu = {x = 93, y = 10},
				hades = {x = 82, y = 10}
			},
			doors = 
			{
				lulu = {x = 81, y = 9},
				hades = {x = 94, y = 9}
			},
			powers = 
			{
				lulu = 3,
				hades = 1
			}
		},
		--6
		{
			lights = 
			{
				{x = 102, y = 1, r = 16},
				{x = 108, y = 5, r = 24},
				{x = 99, y = 6, r = 12},
				{x = 104, y = 12, r = 24},
			},
			pos = 
			{
				lulu = {x = 102, y = 2},
				hades = {x = 104, y = 5}
			},
			doors = 
			{
				lulu = {x = 101, y = 14},
				hades = {x = 106, y = 14}
			},
			powers = 
			{
				lulu = 3,
				hades = 2
			}
		},
		--7
		{
			lights = 
			{
				{x = 113, y = 13, r = 16},
				{x = 116, y = 13, r = 16},
				{x = 119, y = 13, r = 16},
				{x = 122, y = 9, r = 16},
			},
			pos = 
			{
				lulu = {x = 113, y = 14},
				hades = {x = 113, y = 11}
			},
			doors = 
			{
				lulu = {x = 126, y = 13},
				hades = {x = 126, y = 9}
			},
			powers = 
			{
				lulu = 1,
				hades = 0
			},
			black_orb = 
			{
				{x = 122, y = 14, r = 24},
			}
		},
		--8
		{
			lights = 
			{
				{x = 8, y = 17, r = 16},
				{x = 3, y = 21, r = 16},
				{x = 9, y = 22, r = 16},
			},
			pos = 
			{
				lulu = {x = 10, y = 18},
				hades = {x = 1, y = 18}
			},
			doors = 
			{
				lulu = {x = 13, y = 29},
				hades = {x = 8, y = 29}
			},
			powers = 
			{
				lulu = 1,
				hades = 1
			},
			black_orb = 
			{
				{x = 8, y = 23, r = 32},
			}
		},
		--9
		{
			lights = 
			{
				{x = 22, y = 15, r = 16},
				{x = 15, y = 16, r = 20},
				{x = 19, y = 18, r = 16},
				{x = 25, y = 19, r = 28},
				{x = 19, y = 21, r = 16},
				{x = 21, y = 25, r = 24},
			},
			pos = 
			{
				lulu = {x = 23, y = 17},
				hades = {x = 30, y = 17}
			},
			doors = 
			{
				lulu = {x = 23, y = 29},
				hades = {x = 24, y = 29}
			},
			powers = 
			{
				lulu = 4,
				hades = 7
			},
			chests = 
			{
				{
					opened = false,
					locked = true,
					check_lock = false,
					content = {
						name = "black_orb",
						r = 36
					},
					x = 28,
					y = 30,
				}
			},
			keys = {
				{
					x = 16,
					y = 25
				}
			}
		},
		--10
		{
			lights = 
			{
				{x = 35, y = 17, r = 16},
				{x = 35, y = 21, r = 16},
				{x = 44, y = 24, r = 12},
			},
			pos = 
			{
				lulu = {x = 36, y = 19},
				hades = {x = 46, y = 18}
			},
			doors = 
			{
				lulu = {x = 46, y = 25},
				hades = {x = 33, y = 29}
			},
			powers = 
			{
				lulu = 2,
				hades = 1
			},
			black_orb = {
				{x = 33, y = 19, r = 32},
			}
		},
		--11
		{
			lights = 
			{
				{x = 51, y = 17, r = 16},
			},
			pos = 
			{
				lulu = {x = 52, y = 19},
				hades = {x = 59, y = 19}
			},
			doors = 
			{
				lulu = {x = 55, y = 29},
				hades = {x = 56, y = 29}
			},
			powers = 
			{
				lulu = 2,
				hades = 1
			},
			shield_cristals = {
				{x = 49, y = 19, timer = 3, r = 16},
			}
		},
		--12
		{
			lights = 
			{
				{x = 65, y = 17, r = 16},
			},
			pos = 
			{
				lulu = {x = 66, y = 18},
				hades = {x = 77, y = 18}
			},
			doors = 
			{
				lulu = {x = 77, y = 20},
				hades = {x = 74, y = 27}
			},
			powers = 
			{
				lulu = 3,
				hades = 3
			},
			shield_cristals = {
				{x = 70, y = 17, timer = 5, r = 16, lives = 1},
				{x = 66, y = 21, timer = 5, r = 16, lives = 1},
				{x = 64, y = 30, timer = 10, r = 24, lives = 3},
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
	local y = room.y
	if (x >= 1024) then
		x = 0
		y = y + 128
		if (y >= 512) then -- We are at the end of the map
		y = 0
		end
	end
	--TEST
	-- x = 512
	-- y = 128
	--END TEST
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
	delete_objects()
	create_objects()
	--characters
	lulu.passed = false
	hades.passed = false
	lulu.in_light = true
	hades.in_light = false
	disable_shield()
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
	black_orbs = {}
	ima_light_bo = {
		x = 0,
		y = 0,
		r = 24,
		c = 1
	}
	black_lights = {}
	chests = {}
	keys = {}
	shield_cristals = {}
end

function update_objects()
	-- When someone enter its door, passed will be turn on and character will disappear
	if collision(pactual, pactual == lulu and doors.lulu or doors.hades) then
		pactual.passed = true
		if lulu.shield.active then
			disable_shield()
		end
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
	
	--chests
	foreach(chests, function(c)
		if collision(pactual,c) and c.opened == false then
			if c.locked and keys_owned > 0 then
				keys_owned -= 1
				open_chest(c)
			elseif c.locked and keys_owned == 0 then
				if c.check_lock then
					c.check_lock = false
					sfx(12)
				end
			elseif c.locked == false then
				open_chest(c)
			end
		end
		if not collision(pactual,c) and c.locked and not c.check_lock then
			c.check_lock = true
		end
	end)

	--keys
	foreach(keys, function(k)
		if collision(pactual,k) then
			sfx(2)
			keys_owned += 1
			del(keys,k)
		end
	end)

	--shield cristals
	foreach(shield_cristals, function(sc)
		if collision(lulu,sc) then
			sfx(5)
			lulu.shield.active = true
			lulu.shield.time_set = sc.timer * 30
			lulu.shield.timer = 0
			lulu.shield.r = sc.r
			sc.lives = sc.lives - 1
			if sc.lives == 0 then
				del(shield_cristals,sc)
			end
		end
	end)
end

--animations
function draw_objects()
	--doors
	local flip = frames % 10 >= 5  -- Alterne toutes les 5 frames
	local d_lulu = 35
	local d_hades = 51
	--black orbs
	foreach(
		black_orbs, function(bo)
			spr(bo_spr, bo.x, bo.y, 1, 1, false, false)
			if frames > 20 then
				spr(bo_spr+1, bo.x, bo.y, 1, 1, false, false)
			end
		end
	)

	-- Desspritee la porte dimensionnelle
	spr(d_lulu, doors.lulu.x, doors.lulu.y, 1, 1, flip, false)
	spr(d_lulu, doors.lulu.x, doors.lulu.y + 8, 1, 1, not flip, true)
	spr(d_hades, doors.hades.x, doors.hades.y, 1, 1, flip, false)
	spr(d_hades, doors.hades.x, doors.hades.y + 8, 1, 1, not flip, true)

	--chests
	foreach(chests, function(c)
		if c.opened then
			spr(56, c.x, c.y, 1, 1, false, false)
		else
			spr(55, c.x, c.y, 1, 1, false, false)
		end
	end)
	--keys
	foreach(keys, function(k)
		spr(57, k.x, k.y, 1, 1, false, false)
	end)
	--shield cristals
	foreach(shield_cristals, function(sc)
		spr(15, sc.x, sc.y, 1, 1, false, false)
	end)
end

function create_black_orb(x, y,r)
	add(black_orbs, {x = x, y = y, r=r})
end

function delete_objects()
	--delete all lights from ancient room
	for l in all(lights) do
		del(lights,l)
	end
	for bl in all(black_lights) do
		del(black_lights,bl)
	end
	for c in all(chests) do
		del(chests,c)
	end
	for k in all(keys) do
		del(keys,k)
	end
	keys_owned = 0
	for sc in all(shield_cristals) do
		del(shield_cristals,sc)
	end
end

function create_objects()
	--create lights from new room
	for l in all(rooms_data[i_room].lights) do
		create_light(l.x * 8, l.y * 8, l.r)
	end
	--black orb
	for bo in all(rooms_data[i_room].black_orb) do
		create_black_orb(bo.x * 8, bo.y * 8, bo.r)
	end
	--chests
	for c in all(rooms_data[i_room].chests) do
		create_chest(c)
	end
	--keys
	for k in all(rooms_data[i_room].keys) do
		create_key(k.x * 8, k.y * 8)
	end
	--shield cristals
	foreach(rooms_data[i_room].shield_cristals, function(sc)
		add(shield_cristals, {x = sc.x * 8, y = sc.y * 8, timer = sc.timer, r = sc.r})
	end)
end

-->8
--chests

function create_chest(c)
	local new_chest = {
		opened = c.opened,
		locked = c.locked,
		content = c.content,
		x = c.x * 8,
		y = c.y * 8
	}
	add(chests, new_chest)
end

function open_chest(c)
	sfx(13)
	c.opened = true
	--crれたer le contenu du coffre au-dessus
	if c.content.name == "black_orb" then
		create_black_orb(c.x, c.y-10, c.content.r)
	end
end

function create_key(x, y)
	add(keys, {x = x, y = y})
end

-->8
--UI
function draw_ui()
	local x = room.x
	local y = room.y
	palt(0, false)
	palt(12, true)
	for i = 1, lulu.lights_left do
		spr(49, x + i * 8, y + 4, 1, 1, false, false)
	end
	for i = 1, hades.turnoffs_left do
		spr(50, x + 120 - i * 8, y + 4, 1, 1, false, false)
	end
	for i = 1, lives do
		--nothing
	end
	palt()
end

-->8
--helper functions

function debug_print()
	-- print("timer:"..lulu.shield.timer, pactual.x,pactual.y-10,11)
	if lulu.shield.r then
		print("shield.r:"..lulu.shield.r, pactual.x,pactual.y-10,11)
	end
	-- print("lvl: "..i_room, pactual.x,pactual.y-10,8)
	-- if chests[1] != nil then
	-- 	print("chests: "..chests[1].content.name, pactual.x,pactual.y-10,8)
		-- print("x: "..chests[1].x, pactual.x,pactual.y-20,8)
		-- print("y: "..chests[1].y, pactual.x,pactual.y-30,8)
		-- print("p.x: "..pactual.x, pactual.x,pactual.y-40,8)
		-- print("p.y: "..pactual.y, pactual.x,pactual.y-50,8)
	-- end
	--TEST
	-- foreach(chests, function(c)
	-- 	if collision(pactual, c) then
	-- 		print("collides!", pactual.x, pactual.y - 10, 8)
	-- 	end
	-- end)
	-- for bl in all(black_lights) do
	-- 	if collision_black_light(pactual, bl) then
	-- 			print("coll!", pactual.x, pactual.y - 10, 8)
	-- 	end
	-- end
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
	-- print(lulu.in_light,lulu.x,lulu.y-10,8)
	-- print(hades.in_light,hades.x,hades.y-10,8)
	-- print("frames: "..frames,10,10,8)
	-- print("dx: "..lulu.dx,10,20,11)
	-- if (not lulu.in_light) then debug_light = true end
	-- print("out ? "..(debug_light and 'true' or 'false'),lulu.x,lulu.y-20,8)
	-- print("x: "..lulu.x,lulu.x,lulu.y-20,8)
	-- print("y: "..lulu.y,lulu.x,lulu.y-10,8)
	
end

function round(a)
	return flr(a + 0.5)
end

--collisions
function collision(p, o)
	return not (p.x > o.x + 4
				or p.y > o.y + 8
				or p.x + 4 < o.x
				or p.y + 4 < o.y)
end

function collision_light(p, l)
	local px = p.x + p.w / 2
	local py = p.y + p.h / 2
	local lx = l.x + l.r
	local ly = l.y + l.r

	local dx = px - lx
	local dy = py - ly
	local dist = sqrt(dx*dx + dy*dy)
	-- print("dist: "..flr(dist), hades.x, hades.y - 10, 7)
	return dist <= l.r + 2
end

function collision_black_light(p, l)
	local lx = l.x + l.r / l.r
	local ly = l.y + l.r / l.r
	local rx = max(p.x, min(lx, p.x + p.w))
	local ry = max(p.y, min(ly, p.y + p.h))
	local dx = lx - rx
	local dy = ly - ry
	local dist = sqrt(dx*dx + dy*dy)
	-- print("dist: "..flr(dist), pactual.x, pactual.y - 10, 7)
	-- pset(rx, ry, 11)  -- centre du joueur
	-- pset(lx, ly, 8)   -- centre du cercle
	return dist <= l.r
end

__gfx__
00000000088888800888888001111110088888800222222002222220c111111c0222222000000000000000000000000000000000000000000000000000000000
0000000088888888888888881111111188888888222222222222222211111111222222220000000000000000000000000000000000000000000000000000c000
007007008899999888999998114444418899999822222f2222222f2211111d1122222f22000000000000000000000000000000000000000000000000000c7c00
00077000899ff9f9899ff9f9144dd4d4899ff9f90229ff920229ff92c113dd310229ff920000000000000000000000000000000000000000000000000000c000
0007700089f39fc989f39fc914d14d5489f39fc9022ffff2022ffff2c11dddd1022ffff200000000000000000000000000000000000000000000000000001000
00700700089fff90089fff90014ddd40089fff900121d1020121d102c01050c10121d10200000000000000000000000000000000000000000000000000001000
000000000088880000888800001111000088880001dddd0010dddd00c05555cc01dddd0000000000000000000000000000000000000000000000000000001000
00000000004004000004500000500500040000400140040010045000c02cc2cc0400004000000000000000000000000000000000000000000000000000111110
00000000000000000333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000033bbbb3300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000003b3333b300000000000000000000000000030000000300000000000000000000000000000000000000000000000000000000000000000000
00000000000000003b3bb3b300000000000000000000000000393000003a30000000000000000000000000000000000000000000000000000000000000000000
00000000000000003b3bb3b300000000000000000000000000393000003a30000000000000000000000000000000000000000000000000000000000000000000
00000000000000003b3333b300000000000000000000000000030000000300000000000000000000000000000000000000000000000000000000000000000000
000000000000000033bbbb3300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
666666660009000000888000dddddddd088008800000000000045400000000000000000000000000000000009909909900000000000000000000000000000000
65555556009a9000088a8800dddccddd88888888000000000004640000000000000000000000a000000000009000000900000000000000000000000000000000
6555555609aaa90088a88880ddccccdd888888880808000000045400000000000000a000000a7a00888888880000000000000000000000000000000000000000
655555569aaaaa908a888a80dccccccd888887888888800000046400000000000000a00000a777a0888888889000000900000000000000000000000000000000
6555555609aaa9008888a880dccccccd8888778888888000000454000000000000aa7aa0000a7a00848888889000000900000000000000000000000000000000
65555556009a9000088a8800dccc7ccd0888888008880000000464000000a0000000a0000000a000888888880000000000000000000000000000000000000000
655555560009000000888000dcc77ccd008888000080000000045400000a7a000000a00000000000888888489000000900000000000000000000000000000000
666666660000000000000000dcc77ccd0008800000000000000464000000a0000000000000000000888888889909909900000000000000000000000000000000
00060000ccc0ccccccc0cccc5555555500000000000000000000000000000000000aa0000000000088888888aa0aa0aabb0bb0bb000000000000000000000000
00006000cc0a0ccccc080ccc555885550000000000000000000000000999999004444440000a000088888888a000000ab000000b000000000000000000000000
00060000c0a7a0ccc08a80cc55888855000000000000000000000000997444994666555400a9a000888488880000000000000000000000000000000000000000
000060000a777a0c08aaa80c588888850000000000000000000000009744444946655554000a000088888888a000000ab000000b000000000000000000000000
00060000c0a7a0ccc08a80cc588888850000000000000000000000009999999997444449000a000088888888a000000ab000000b000000000000000000000000
00006000cc0a0ccccc080ccc58887885000000000000000000000000974aa44997444449000aa000888888880000000000000000000000000000000000000000
00060000ccc0ccccccc0cccc588778850000000000000000033333309744444997444449000a000088888848a000000ab000000b000000000000000000000000
00006000cccccccccccccccc58877885000000000000000003bbbb3099999999999999990000000088888888aa0aa0aabb0bb0bb000000000000000000000000
000000000000000000000000eeeeeeee000000000000000000000000055555500555555555505505555555500555555000000000505555055055055566666666
000000000000000000000000eeeeeeee000000000000000000000000555555555555555555555555555555555555555500000000555655555555555566666666
000000000000000000000000eeeeeeee000000000000000000000000555665555555556655555555565665555556655500000000655666665655655566666666
000000000000000000000000eeeeeeee000000000000000000000000556666555555566665566566666665555556665500000000666666666665665666666666
000000000000000000000000eeeeeeee000000000000000000000000556665555556666666666666666666555566655500000000666666666666666666666666
000000000000000000000000eeeeeeee000000000000000000000000555655555556666666666666666666555566665500000000666666666666666666666666
000000000000000000000000eeeeeeee00000000000000000000000055555555555666dd66666666666666655556655500000000666666666666666666666666
000000000000000000000000eeeeeeee00000000000000000000000005555550555666dd66666666d66666555556665500000000666666666666666666666666
0000000000000000000000000000000000000000d666655555556666555555555556666666666666666665555556665500000000055555005005555066666666
00000000000000000000000000000000000000006665555005556666556555555555666666666666666655555566666500000000555555555555555566666666
00000000000000000000000000000000000000006665550000555666555555650556666666666666666665505556655500000000555555555566555566d66666
00000000000000000000000000000000000000006655500000055556555555555556666666666666666665555566665500000000555666556666655566666d66
00000000000000000000000000000000000000005555000000005556555555555555666666666666666655555666655500000000556666666666655566666666
000000000000000000000000000000000000000055500000000005555565555505556666666666666666655055566665000000000566dd666666655566666666
000000000000000000000000000000000000000055000000000000555555556555566666666666666666555555666555000000000556dd666d66555066d666d6
00000000000000000000000000000000000000005000000000000005555555555556666666666666666665555556665500000000555666666666555066666666
00000000000000000000000000000000000000005000000000000005000000005566666d66666666dd6666555566655500000000055566666666655500000000
00000000000000000000000000000000000000005500000000000055000000005556666666666666dd6666555556655500000000055566d666dd655000000000
000000000000000000000000000000000000000055500000000005550000000055666666666666666666655555666655000000005556666666dd665000000000
00000000000000000000000000000000000000006555000000005555000000005556666666566666666655555556665500000000555666666666665500000000
00000000000000000000000000000000000000006555500000055566000000005556666666566665666655555566655500000000555666665566655500000000
00000000000000000000000000000000000000006665550000555666000000005555665655555555656555555556655500000000555566555555555500000000
00000000000000000000000000000000000000006666555005555666000000005555555555555555555555555555555500000000555555555555555500000000
0000000000000000000000000000000000000000666655555556666d000000000555555550550555555555500555555000000000055550050055555000000000
00000000000000000000000000000000000000000555555555555555555555500555555555555555555555500000000000000000000000000000000000000000
00000000000000000000000000000000000000005555555555565555555555555555555555555555555555550000000000000000000000000000000000000000
00000000000000000000000000000000000000005556565656566565556655555556665555555555566665550000000000000000000000000000000000000000
00000000000000000000000000000000000000005566666666666666666666555566666556555566666666550000000000000000000000000000000000000000
00000000000000000000000000000000000000005566666666666666666666555566666666555565566666550000000000000000000000000000000000000000
00000000000000000000000000000000000000005555665566666666656565555556666555555555556665550000000000000000000000000000000000000000
00000000000000000000000000000000000000005555555565666565555555555555555555555555555555550000000000000000000000000000000000000000
00000000000000000000000000000000000000000555555555555555555555500555555555555555555555500000000000000000000000000000000000000000
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200420000420042004200004200420000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200420000420042004200004200420000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200420000420042004200004200420000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200424200424242004242004242420000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200a3000000000000a3a300a3a300a3a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002a300a300a300a300a3a300a3000000a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002a300a300a300a300a3000000a30000a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200a3a30000a30000a3a300a3a30000a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000
__gff__
0000000000000000000000000002020000000000000000000000000002020202810000000000000000000200020202020000000000000004000000000002020200000000000000010101010100010101000000000001010101010101000000010000000000010100010101010000000000000000000101010101010000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
59595959595959595959595959595f596959595f595959595959595959696969595959595959595959595959595959595959595959595959595959595959595920202020202020202020202020202020202020202020202020202020202020202020203a3a2020202020203a3a20202020202020202020202020202020202020
595959595f59595959595f5959595959005859595969695959595f595a000000585f595959595f59595959595f59595959595959595959595f595959595f595920200030300023000030003320202020200000300000000030000000300000203a3a3a3a3a2000000000203a3a3a3a20203a202020202020202020203a3a3a20
59595f59595f59595959595959595959005859696a000068596959595a000048595959595959595959595f59595959595959595f5959595959595959595959592020003030002300003000332020202020000030000000003000000030000020202020203a200000000020203a3a3a3a203a3a20202020202020203a3a3a3a20
595959595959595f595959595f59595900586a00000000006b0058596a00005859595f5959595959595959595959595959595959595955565959595959595959202000303000200000300020202020202000000000000000300000000000002020203a203a202020000020202020203a203a3a3a3a20202020203a3a3a3a3a20
5959595959595959595f595959595959006b0000000000000000586a0000486959595959695969595959696959595f59595f5959595965665f595959595959590000002030000000002000000020202020000000000000000000000000000020203a3a203a3a3a200000000000002020203a3a3a3a3a2020203a3a3a3a3a3a20
5959595f595959595959595959595959000000000000000000005b0000006b006859595a005b0068595a000058595959595959595959595959595959595959590000000030000000200000000000202020000000000000000000000000000020203a3a3a3a3a3a200000000000000020203a3a3a3a3a3a203a3a3a3a3a3a3a20
595959595969696959595959595f5959000000000000000000006b00000000000058695a006b0000685a000068695959596959696959595959596959596969690000000030000020000000000000002020000000000000000000000000000020203a2020202020202020200000000020203a3a3a3a3a3a3a3a3a3a3a3a3a3a20
5f5959596e0000474b6869696969595900000000000000000000000000000000005b006b00000000006b0000000068595a006b0000686969695a00586a3000000000000020000000000000000000000020000000000020200000000000000020203a2000000000000000000000000020203a3a3a3a3a3a3a3a20202020202020
6969696e000000005b000000006d595949494a00000000000000000000000000006b00000000000000000000000000586a00000000303000006b006b003000230000000000200000000000000000000020200000002020000000000000000020203a200000202020202020200000002020202020202020202020202020202020
00000000000000005b00000000006d6969595a000000000000000000000000330000000000000000000000000000005b330000000030300000000000004700230000000000002000000000000000000020230000002000000000200000003320203a200000000000000020200000002020202020202020202020200000003320
00000000000000005b0000000000000000685a0000000000000000000000003300000000000000000000004b0000335b3300000000303000000000000000004b0000000000000000000000000000000020230000202000000000202000003320203a202000000000000020000000002020000000000000000000000000003320
00000000000000005b0000000000000000006b0000000000000000000000787947000000000000000000005b000033584949494a00787a0048494a00484d4e5920202020202020202020202020202020202020202000000000000020202020203a3a202000000000000000000020202020000000000000000000000000002020
00000000000000005b000000000000000000000000000000000000000078797a007876767676767a000000584d4976595959595a0000000058595a005859595920202020000000000000000020202020202020202a2a2a2a2a2a2a2a202020203a3a2020200000000000000020202a2a20202020202020202020202000002020
00000000000000235b330000000000000000000000000000000000000000230000000000000078797a007869696a2358595f5959494949495959594959595f5920202a2a2a2a2a2a2a2a2a2a2a2a202020203a3a3a3a3a3a3a3a3a3a3a3a20203a3a20202000000000000020203a3a3a20000000000000000000000000002320
0000004e4e0000235b33000000004d4e00000000004d4d4e0000000000002300000000000000000000000000000023585959595f59595959595f5959595f5959203a3a3a3a3a3a3a3a3a3a3a3a3a3a20203a3a3a3a3a3a3a3a3a3a3a3a3a3a20203a3a3a20230000000033203a3a3a2020000000000000000000000000002320
4d4e4d4f4f4e4d4e6b4d4d4e4d4d4f4f4d4d4e4e4d4f4f4f594e4d4d4e4d4d4d4d4e4d4d4e4d4e4d4e4d4d4d4e4d4d5959595959595959595f595959595959593a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a2020202020202020202020202020202020203a3a2023202a2a2033203a3a202020202020202020202020202020202020
2000000000002000000000000020202a00000000000000000000000000000020202020000000000000000000002020202020202020202020202020202020202000000000000000000000000000000000000000000000000033200000000000002020202020202020202020202020202020202020202020202020202020202020
20000000000020000000000000203a3a0000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000f000000000000000000000000000000000133200000000000002000000000000000000000000000002020000000000000000000000000000020
20000000000020000000000020203a3a00000020202020202020202020202020200020000000000000000000000000202000000000000000000000000000002000000100000020000020000000050000000020202020202020200000002000002000000000000000000000000000002020000000000000000000000000000020
20202020000020000020202020203a3a00000000000000000000000000000000200020200000000000000000202020202000000000000000000000000000002020202020202020200020000020202020000020000000000000000000202000202000000000000000000000000000002020000000000000000000000000000020
202020200000200000202020203a3a3a00000000000000000000000000000000202020202020202020200000002020202020202020202000002020202020202000000000000020000020000020000000000020000020202020202020202000002000000000000000000000000000002020000000000000000000000000000020
20202020000020000020202020203a3a2020202020202020202020202020000020000000000000000000000000002020203a3a3a3a3a20000020202020203a3a00000f00000020002020000020000000000020200020000000000000002000002000000000000000000000000000002020000000000000000000000000000020
20000000000000000000000020203a3a300000000000000000000000000000002000000000000000000000000000002020202020203a2000002020203a3a3a2000002020202020000020202020200020000020000020002020202020002020002000000000000000000000000000002020000000000000000000000000000020
20000000000000000000000020203a3a3000000000000000000000000000000020002000000000000000000000000020203a3a3a3a3a20000020203a3a203a2000000000000020200000000000200000000020002020000000002000002000002000000000000000000000000000002020000000000000000000000000000020
2020202020202020202000002020203a3000000000202020202000000000000020002000202020202020202020202020203a20202020200000203a3a3a203a2000000000000000000000000000202000000020000020202020002000202000002000000000000000000000000000002020000000000000000000000000000020
2a2a2a2020202020202000002020203a30000000202000000020202a2a2a2a2020002000000000000000000000002320203a3a3a3a3a200000203a203a203a2000002020202020002020202000200000000020200000000000002000002000202000000000000000000000000000002020000000000000000000000000000020
20203a3a20202020202000002020203a20000000000000000020203a3a3a202020002000000000000000000000002320203a2020203a200000203a203a203a3a00000020000020000020000000200020000020202020202020202020002000002000000000000000000000000000002020000000000000000000000000000020
20203a3a3a3a2020202000002020203a00000000000000000000203a3a3a3a3a200020200000200000200000202020203a3a20203a3a200000203a203a20202020000020000020200020000020200000000020000000000000000000002000002000000000000000000000000000002020000000000000000000000000000020
203a3a20203a2020200000000020203a00000000202000202000202020203a3a20002020202a202a2a202a2020202020202020203a20200000203a203a3a202020202020000020000020000000202000000020000000000000000000202020002000000000000000000000000000002020000000000000000000000000000020
203a2020203a2020330000000023203a2a2a2a2a2a2000233300000000203a3a203320203a3a3a3a3a3a3a3a2020202020203a3a3a20202333203a20203a3a3a00000000002020002020202020200000000020202000002020202020200000002000000000000000000000000000002020000000000000000000000000000020
3a3a2020203a2020330000000023203a3a3a3a3a3a2000233300000000203a3a2033203a3a3a3a3a3a3a3a3a3a2020203a3a3a203a20202333203a20203a20200f000000000000000000000000000020000000000000002023000000000000002000000000000000000000000000002020000000000000000000000000000020
20202020203a202020202020202020203a3a3a3a3a2020202020202020203a3a202020202020202020202020202020203a203a203a20202020203a20203a3a2020202020202020202020202020202020000000000000202023050000000000202020202020202020202020202020202020202020202020202020202020202020
__sfx__
000200000904108031090210c0210e0311203115041190411c04123051270510a0000d0010f00113001170010e0100901005010000102e000240011d00117001120010f0010c0010a00108001060010500105001
000200000c5201052014530195301e53022540265402a54016520185201b5301f5302254026540295402c5202e5201e520215302453026530295302b5302d5302f540315403454037540395403c5503e5503f550
000100000254002540025400454006540095400b5400e5401054012540145401555016550175501755017550165501555013550115500e5500c5400b540095400854007540065400554004540035400254002540
000200000e0100901005010000100100001000000000000000000000000000000000000000000017000110000d00028000250001f0001b000160000d000070000300002000000000000000000000000000000000
000400101073610731127311373114731167311773118731187311873117731157311373112731107310f7310d7310d7310d7310d7310f7311073112731137311473116731167311573114731137311173111731
00010000005540055100551005510055100551015510155102551045510555107551085510a5510c5510d5410f541115411354115541185411a5411d5311f5312253125531275312b5312f52133521395213d521
000200003b56436561315512c5512855125551225511f5411d5411a541185411553113531115310f5210d5210c5210a5110951108511065110551104511045110351103511025110251102511015110151101511
00030020017400174101741027410374105741087410b7410e7411075112751137511475115751157511575115751157511475114751137511275111741107410d7410c7410a7410874105741037410174100741
00020000360702d67025060206601c060186501605013650100500f6500d0500b6500904007640050400464003040026300163001630016300161001610016100161000610006100061000610006100061000610
000400003e06338655340552d64028045256532f0452b6432804326033226351e0531b64518043280352563322033206331a0351764316635220331c62516013116130e0130b6150701307015046100101501615
000400200705005051030310102101031000510005100051010310402105031070510a0510d05110031120211503117051180511805117031150211303111051100510e0510d0310b02109031070510605104051
00030000027510275102751027510475105751097510c7510f76114771187711b7711e771207712177121771207711f7711d7711a7711877115761127510f7510d7510b751087510775106751057510475103751
000300001904314043100430b0430304315043110430b043050430a04305043030430004300003090030900309003090030900309003090030900309003090030900309003090030900309003090030900309003
000400000202005030080400c05010050160501805003020080300d040140501a0501d050080100a0200b0200c0300e0301003013030170401b0401f040250502c05031050350503c0603c0503c0413c0313c021
0002000004651060510b651100511365115051186511f0510d0510e6510f05110651130511465118051186511d0511d651250512365124651276512c0542d650340513265139051390513b0513f6513f6513e651
001a00201a1401d030210401c1301f040230301a1401d0301a1401d030210401c1301f040230301d140210301814021130230401f1301c1401a1301f1401c03021140181302104023130211401f1301c1401d130
011800201c0501d0501e0501f050210502305024050260501c7001f7001f7001c7001c7001a7001f7001a7001a700187001f700187001f7001c7001c7001f7001c700187001c7000070000700007000070000000
010100200905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053090530905309053
012000201a0501a0501a0101a0101d0501d0501d0101d0101c0501c0501c0101c0101f0501f0501f0101f0101a0501a0501a0101a0101d0501d0501d0101d0101c0501c0501c0101c0101f0501f0501f0101f010
001000201a6530000000000000001d6530000000000000001a6531a6531a653000001d6530000000000000001a6531a6531a653000001d6531d65300000000001a6531a6531a653000001d6531d6531d6531d653
001000202615026150261202612029150291502912029120281502815028120281202b1502b1502b1202b1202615026150261202612029150291502912029120281502815028120281202b1502b1502b1202b120
001000001a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0501a0001a0001a0001a000
00100000000000000000000000002604026030290402903028040280302b0402b0302604026030290402903028040280302b0402b0302604026030290402903028040280302b0402b03026040260302904029030
011000001a6000000000000000001a6531d6001d653000001a6531d6001d6531a6001a6531d6001d653000001a6531a6001d6531d6531a6531a6001d6531d6001a653000001d6531a6001a6531d6001d65300000
00080020280402804028030280302b0402b0402b0302b0302604026040260302603029040290402903029030280402804028030280302b0402b0402b0302b0302604026040260302603029040290402903029030
001000001a6531d6001d653000001a6531d6001d6531a6001a6531d6001d653000001a6531a6001d6531d6531a6531a6001d6531d6001a653000001d6531d6531d6531d6001d6531d6001d6531d6531d6531d653
001000002d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0402d0402d0402d0402d0402d0402d0302d0302d0302d0302d0302d0202d0202d0202d0102d010
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

