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
	dflt_delay_switch = 3 --3 frames
	delay_switch = dflt_delay_switch
	lives = 3
	bo_spr = 22
	sfx_timer = 0
	music(0)
	pulsator_state = false
	animation_timer = 0
	shake = 0
	music_object = {false, 0}
	--DEBUG
	tp = false
	--TEST
end

function _update()
	frames=((frames+1)%30)
	if sfx_timer > 0 then
		sfx_timer -= 1
	end

	if animation_timer > 0 then
		animation_timer -= 1
		return
	end
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
	-- screenshake
	if shake>0 then
		shake-=1
		-- camera()
		if shake>0 then
			camera(-2+rnd(5)+cx,-2+rnd(5)+cy)
		end
	end

	map(0, 0, 0, 0, 128, 64, 0)
	draw_light()
	draw_objects()
	map(0, 0, 0, 0, 128, 64, 7)
	draw_walls() -- TEST
	foreach(butterflies, function(b)
		draw_butterfly(b)
	end)	
	foreach(gates, function(g)
		draw_gates(g)
	end)
	-- line()
	-- Doors
	draw_doors()
	draw_player()
	draw_acristals()
	draw_messages()
	--DEBUG
	if btn(🅾️) and lulu.select then
		-- Dessiner la grid de la map
		for i=0,1 do
			for j=0,16 do
				if (i == 0) line(0, max(0,room.y + (j*8)),room.x + 128,max(0,room.y + (j*8)), 8)
				if (i == 1) line(max(0,room.x + (j*8)),0,max(0,room.x + (j*8)),room.y + 128,8)
			end
		end
		pset(ima_light.x,ima_light.y,11)
	end

	-- draw outside of the screen for screenshake
	rectfill(-5,-5,-1,133,0)
	rectfill(-5,-5,133,-1,0)
	rectfill(-5,128,133,133,0)
	rectfill(128,-5,133,133,0)

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
		gravity = 0.18,
		is_jumping = false,
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
		gravity = 0.11,
		is_jumping = false,
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
		shield = {
			timer = 0,
			time_set = 5*30,
			active = true,
			r = 16,
		}
	}
	--globals to both
	keys_owned = 0
	pactual = lulu
	friction = 0.7
	accel = 1
	accel_air = 0.9
	jumping = 2.5
	max_dx = 2.2
	chars = { lulu, hades }
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

	-- pset(pactual.x + 9, pactual.y + 6, 8)
	-- pset(pactual.x + 9, pactual.y + 2, 8)
	-- pset(pactual.x - 1, pactual.y + 6, 8)
	-- pset(pactual.x - 1, pactual.y + 2, 8)
end

function update_player()
	--delay when switching
	if is_in_switch then
		delay_switch = delay_switch - 1
		if delay_switch <= 0 then
			is_in_switch = false
			delay_switch = dflt_delay_switch
		end
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
		-- !! TEST !! --
		----------------
		return
	end

	--switch characters
	if btnp(⬇️) and not btn(🅾️) then
		switch_character()
		return
	end

	if not lulu.using_light and not hades.using_light then move_characters() end

	--if fall in water or lava

	if check_flag(1, pactual.x + 4, pactual.y) then
		restart_level()
		return
	end

	--COLLISIONS LIGHTS --
	----------------------
	for c in all(chars) do c.in_light = false end

	--dynamic lights
	for dl in all(dynamic_lights) do
		for c in all(chars) do
			if collision_black_light(c, dl) then
				if dl.type == "white" then
					c.in_light = true
				elseif dl.type == "anti" then
					c.in_light = false
				-- elseif dl.type == "black" then
				-- 	c.in_light = c == lulu and true or false
				end
			end
		end
	end

	for l in all(lights) do
		for c in all(chars) do
			if collision_light(c, l) then
				c.in_light = true
			end
		end
	end

	--maybe pactual has collide with a light, but if it is in black light, it cancels the condition
	for bl in all(black_lights) do
		for c in all(chars) do
			if collision_black_light(c, bl) then
				c.in_light = c == lulu and true or false
			end
		end
	end

	for b in all(butterflies) do
		for c in all(chars) do
			if collision_black_light(c, b) then
				if b.light == "white" then
					c.in_light = true
				elseif b.light == "black" then
					c.in_light = c == lulu and true or false
				elseif b.light == "anti" then
					c.in_light = false
				end
			end
		end
	end

	--shield of lulu
	if lulu.shield.active then
		lulu.shield.timer = lulu.shield.timer + 1 -- 30 fps (ex: 150 = 5 secondes)
		lulu.in_light = true
		if collision_black_light(hades, {x = lulu.x or 0, y = lulu.y or 0, r = lulu.shield.r - 4 or 0}) then
			hades.in_light = true
		end
		if lulu.shield.timer > lulu.shield.time_set then
			disable_shield(lulu)
		end
	end

	--shield of hades
	if hades.shield.active then
		hades.shield.timer = hades.shield.timer + 1 -- 30 fps (ex: 150 = 5 secondes)
		hades.in_light = false
		if collision_black_light(lulu, {x = hades.x or 0, y = hades.y or 0, r = hades.shield.r or 0}) then
			lulu.in_light = true
		end
		if hades.shield.timer > hades.shield.time_set then
			disable_shield(hades)
		end
	end

		--CONDITIONS FOR LIGHTS
	if (not lulu.in_light and not lulu.passed) or (hades.in_light and not hades.passed) or pactual.y >= room.h-1 then
			-- lives = lives - 1
		if i_room == 0 then 
			restart_game()
			return
		end
		restart_level()
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
					sfx_timer = 20
					sfx(52,3)
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
			if pactual.using_light then pactual.sprite = pactual.default_sprite end
			--STEP MOVES
			-- I think I'll remove it for better listening of music
			-- if frames % 8 == 0 then
			-- 	psfx(59)
			-- end
		else
			pactual.sprite = pactual.default_sprite
		end
	end
end

function move_characters()
	-- INPUT
	local move = 0
	if btn(⬅️) then move -= 1 pactual.flipx = true end
	if btn(➡️) then move += 1 pactual.flipx = false end
	if btnp(⬆️) and pactual.g then
		pactual.dy = -jumping
		pactual.is_jumping = true
		psfx(62,3)
	end
	if not btn(⬆️) and pactual.is_jumping and pactual.dy < 0 then
		pactual.dy = pactual.dy * 0.5
		pactual.is_jumping = false
	end

	local accel = pactual.g and accel or accel_air

	-- PHYSIQUE
	-- dx
	pactual.dx += move * accel
	pactual.dx *= friction
	--limit left/right speed
	pactual.dx = mid(-max_dx, pactual.dx, max_dx)
	--cut deceleration when stop moving
	if pactual.dx < 0.1 and pactual.dx > -0.1 then pactual.dx = 0 end
	--dy
	foreach(chars, function(c)
		if c.dy then
			c.dy += c.gravity
			c.y += c.dy
		end
	end)

	--COLLISIONS
	--if next moves collides with gates, no more moves possible
	local new_x = pactual.x + pactual.dx
	local new_y = pactual.y + pactual.dy
	foreach(gates, function(g)
		if collision({x = new_x, y = new_y, w = pactual.w, h = pactual.h}, g) then
			if not g.opened then
				pactual.dx = 0
				pactual.dy = 0
			end
		end
	end)

	-- COLLISION SOL
	local grounded
	foreach(chars, function(c)
		grounded = check_flag(0, c.x + 3, c.y + c.h)
		or check_flag(0, c.x + 5, c.y + c.h)
		if grounded then
			c.g = true
			c.is_jumping = false
			c.dy = 0
			c.y = flr(c.y / c.h) * c.h
		else
			c.g = false
		end
	end)

	-- MOUVEMENT HORIZONTAL + COLLISIONS
	if pactual.dx > 0 then
		if not check_flag(0, pactual.x + 8, pactual.y + 6)
		and not check_flag(0, pactual.x + 8, pactual.y + 2) then
			pactual.x += pactual.dx
		end
	elseif pactual.dx < 0 then
		if not check_flag(0, pactual.x - 1, pactual.y + 6)
		and not check_flag(0, pactual.x - 1, pactual.y + 2) then
			pactual.x += pactual.dx
		end
	end

	-- COLLISIONS LATれ웃RALES
	if check_flag(0, pactual.x + 7, pactual.y + 7) then pactual.x -= 1 end
	if check_flag(0, pactual.x, pactual.y + 7) then pactual.x += 1 end

	-- COLLISION PLAFOND
	if check_flag(0, pactual.x + 1, pactual.y + 1)
	or check_flag(0, pactual.x + 6, pactual.y + 1) then
		pactual.dy = 0
		pactual.y += 1
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
	foreach(chars, function(c)
		c.dx = 0
		c.dy = 0
		c.g = false
	end)
	is_in_switch = true
end

function disable_shield(character)
	character.shield.active = false
	character.shield.timer = 0
	character.shield.time_set = 0
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
		sfx(55,-2)
		sfx(58,-2)
	end
	update_dynamic_lights()
end

function update_light_lulu()
	if not lulu.using_light then
		--setting position of light
		ima_light.y = lulu.y_g
		ima_light.x = lulu.x_g
		lulu.using_light = true
		psfx(58,3)
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
		psfx(57)
		lulu.lights_left -= 1
	end
end

function update_light_hades()
	-- hades a une variable qui stocke temporairement la light selected
	if #lights > 0 and hades.turnoffs_left > 0 then
		if not hades.using_light then
			psfx(55,3)
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
			psfx(56,3)
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
		sfx(52, -2)
		psfx(51)
		pactual.using_black_light = false
	end
end

function draw_light()
	draw_dynamic_lights()
	draw_lights()
	draw_imaginary_light()
	draw_hades_turnoff()
end

function draw_imaginary_light()
	if btn(🅾️) and lulu.select and lulu.lights_left > 0 then
		circfill(ima_light.x, ima_light.y, ima_light.r, ima_light.color)
		circ(ima_light.x, ima_light.y, ima_light.r, ima_light.color+1)
		circ(lulu.x_g, lulu.y_g, lulu.ima_range, 12) --desinner le circle de ima_light
		-- pset(ima_light.x,ima_light.y,8)
	end
	if pactual.using_black_light then
		circfill(ima_light_bo.x, ima_light_bo.y, ima_light_bo.r, ima_light_bo.c)
		circ(ima_light_bo.x, ima_light_bo.y, ima_light_bo.r, ima_light_bo.c+1)
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
end

function draw_shields()
	--shield
	if lulu.shield.active then
		-- on interpole le rayon pour qu'il diminue avec le temps
		local ratio = 1.2 - lulu.shield.timer / lulu.shield.time_set
		local r = ceil(lulu.shield.r * ratio)
		
		local cx = lulu.x + lulu.w / 2
		local cy = lulu.y + lulu.h / 2
		circfill(cx, cy, r, 10)
		circ(cx, cy, r, 7) 
	end

	if hades.shield.active then
		-- on interpole le rayon pour qu'il diminue avec le temps
		local ratio = 1.2 - hades.shield.timer / hades.shield.time_set
		local r = ceil(hades.shield.r * ratio)
		
		local cx = hades.x + hades.w / 2
		local cy = hades.y + hades.h / 2
		pal(14,3+128,1)
		circfill(cx, cy, r, 14)
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
		circ(x, y, r, 8+1)
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

	-- DATAS MANUAL --
	------------------
	-- lights = { x, y, r, type(optional)}
	-- pos = { x, y }
	-- doors = { x, y }
	-- powers = { lulu (number), hades (number) }
	-- black_orbs = { x, y, r }
	-- shield_cristals = { x, y, timer (frames), r, lives, c (couleur)}
	-- chests = { { opened (boolean), locked (boolean), check_lock (boolean), content = { name (string), r (number)}, x, y } }
		-- pour les chests : si content.name = "turnoff" -> aucune autre data a insれたrer
		-- si content.name = "black_orb" -> content = { name, x, y, r }
	-- keys = { x, y, style (string = "chest" ou "door") }
	-- gates = { x, y, opened (boolean) }
	-- butterflies = { x, y, x1, y1, x2, y2, target (1 ou 2), speed (number), r (number), light (string = "white" ou "black"), spr_flip (boolean) }
	-- messages = { title (string), text (string) }
	-- p_data = {x, y, r_max, type (string = "white" ou "anti"), timer (frames), scale (float)}
	-- acristals = {x,y}
	rooms_data = {
    --1
    {
        lights = {
            {17,10,20},
            {25,11,22},
        },
        pos = {
            {19,14},
            {17,7},
        },
        doors = {
            {30,13},
            {31,9},
        },
        powers = {
            1,
            1,
        },
    },
    --2
    {
        lights = {
            {43,  7, 24},
            {35,  6, 16},
        },
        pos = {
            {45, 10},
            {34, 10},
        },
        doors = {
            {33,9},
            {46,9},
        },
        powers = {
            3,
            1,
        },
    },
    --3
    {
        lights = {
            {50,  8, 19},
            {56,  8, 23},
        },
        pos = {
            {53, 10},
            {62, 10},
        },
        doors = {
            {63,8},
            {48,9},
        },
        powers = {
            2,
            2
        },
    },
    --4
    {
        lights = {
            {65, 8, 16},
            {70, 0, 24},
            {72, 8, 16},
        },
        pos = {
            {67, 10},
            {78, 10},
        },
        doors = {
            {70,1},
            {75,1},
        },
        powers = {
            2,
            1,
        },
    },
    --5
    {
        lights = {
            {82, 9, 24},
            {91, 9, 32},
        },
        pos = {
            {82, 11},
            {80, 14},
        },
        doors = {
            {94,13},
            {94,10},
        },
        powers = {
            2,
            2,
        },
    },
    --6
    {
        lights = {
            {102,  1, 16},
            {108,  5, 24},
            { 99,  6, 12},
            {104, 12, 24},
        },
        pos = {
            {102, 2},
            {104, 5},
        },
        doors = {
            {101,14},
            {106,14},
        },
        powers = {
            3,
            2,
        },
    },
    --7
    {
        lights = {
            {113, 13, 16},
            {116, 13, 16},
            {119, 13, 16},
            {122,  9, 16},
        },
        pos = {
            {113, 14},
            {113, 11},
        },
        doors = {
            {126,13},
            {126,9},
        },
        powers = {
            1,
            0,
        },
        black_orbs = {
            {122,14,24},
        },
    },
    --8
    {
        lights = {
            {8,17,16},
            {3,21,16},
            {9,22,16},
        },
        pos = {
            {10,18},
            {1,18},
        },
        doors = {
            {13,29},
            { 8,29},
        },
        powers = {
            1,
            1,
        },
        black_orbs = {
            {8,23,32},
        },
    },
    --9
    {
        lights = {
            {22, 15, 16},
            {15, 16, 20},
            {19, 18, 16},
            {25, 19, 28},
            {19, 21, 16},
            {21, 25, 24},
        },
        pos = {
            {23, 17},
            {30, 17},
        },
        doors = {
            {23, 29},
            {24, 29},
        },
        powers = {
            4,
            7,
        },
        chests = {
            {
                false,
                true,
                false,
                {
                    "black_orb",
                    27,
                    30,
                    36,
                },
                28,
                30,
            },
        },
        keys = {
            {16, 25, "chest"},
        },
    },
    --10
    {
        lights = {
            {35, 17, 16},
            {35, 21, 16},
            {44, 24, 12},
        },
        pos = {
            {36, 19},
            {46, 18},
        },
        doors = {
            {46,25},
            {33,29},
        },
        powers = {
            2,
            1,
        },
        black_orbs = {
            {33, 19, 32},
        },
    },
    --11
    {
        lights = {
            {49, 17, 16},
            {55, 27,  8},
        },
        pos = {
            {49, 19},
            {59, 19},
        },
        doors = {
            {55, 29},
            {56, 29},
        },
        powers = {
            1,
            0,
        },
        shield_cristals = {
            {54, 19, 4, 12},
        },
    },
    --12
    {
        lights = {
            {65, 16, 16},
            {71, 21,  8},
            {69, 23,  8},
            {73, 23,  8},
            {71, 25,  8},
            {71, 27,  8},
            {71, 29,  8},
            {78, 29,  8},
        },
        pos = {
            {66, 18},
            {76, 18},
        },
        doors = {
            {76,20},
            {77,20},
        },
        powers = {
            2,
            1,
        },
        shield_cristals = {
            {70,17, 8,16,1},
            {67,21,10,16,2},
            {64,30,12,24,1},
        },
        chests = {
            {
                     false,
                     true,
                 false,
                   { "turnoff" },
                         74,
                         21,
            },
        },
        keys = {
            {69,28, "chest"},
            {75,28, "door"},
        },
        gates = {
            {76,30, false},
        },
    },
    --13
    {
        lights = {
            {82, 27, 16},
        },
        pos = {
            {84, 29},
            {91, 29},
        },
        doors = {
            {89,29},
            {87,29},
        },
        powers = {
            0,
            0,
        },
        keys = {
            {92,18,"door"},
            {86,30,"door"},
        },
        gates = {
            {85, 29,false},
            {90, 29,false},
        },
        shield_cristals = {
            {88,18,300,32,1,"red"}, 
        },
        butterflies = {
            {
                       86,17,
                      86,  17,
                      85, 27,
                  2,
                   0.5,
                       24,
                   "white",
                 false,
            },
        },
        messages = {
            {"hint","hADES JUMPS HIGHER THAN lULU" },
        },
    },
    --14
    {
        lights = {
            {101, 15, 16},
        },
        pos = {
            {103, 17},
            {105, 30},
        },
        doors = {
            {104,30},
            {104,16},
        },
        powers = {
            1,
            0,
        },
        keys = {
            {111,30,"door"},
            {103,23,"door"},
        },
        gates = {
            { 97,30,false},
            {102,19,false},
        },
        shield_cristals = {
            {101,17,10,10,1},
            {100,28,10,10,1},
            {106,17,10,10,1},
        },
        butterflies = {
            {
                 97,30,
                 97,30,
                 97,16,
                 2,
                 1,
                12,
                "white",
                 true,
            },
            {
                 99,28,
                 99,28,
                107,28,
                 2,
                 1,
                12,
                "white",
                 true,
            },
            {
                103,19,
                 99,19,
                109,19,
                 2,
                0.5,
                18,
                "black",
                 true,
            },
            {
                 98,23,
                 98,23,
                108,23,
                 2,
                0.5,
                24,
                "black",
                 true,
            },
        },
    },
    --15 HEART
    {
        lights = {
            {123, 16, 12},
        },
        pos = {
            {125, 17},
            {127, 17},
        },
        doors = {
            {112,22},
            {113,22},
        },
        powers = {
            0,
            1,
        },
        pulsator = {
            x = nil,
            y = nil,
            spr_r = 24,
            timer = 150,
            pulse_dur = 60,
            pulse_timer = 0,
            beat_delay = 210,
						is_broken = false,
            light_data = {r_max = 128, type = nil, spd = 1, ac_activated = nil, room_ac = {false, false} }, 
        },
        p_data = {117,30,128,"white",0},
    },
    --16
    {
			lights = {
				{6.5, 40, 24, "black"},
			},
			pos = {
				{5, 41},
				{7, 41},
			},
			doors = {
				{7,43},
				{8,43},
			},
			powers = {2,0},
			butterflies = {
				{4,34, 4,34,9,34, 2,0.6, 16,"anti", false},
				{2,41, 2,41,2,50, 2,0.6, 8,"anti", false},
				{5,34, 5,34, 19, 34, 1, 1,16,"white", true},
				{11,33, 11,33, 11, 50, 1, 0.7,8,"white", true}
			},
			keys = {
				{14,34,"door"},
				{0,33,"door"}
			},
			gates = {
				{13,40},
				{6,46}
			},
			acristals = {
				{7,46},
				{14,40}
			},
			p_data = {14,46,256,"white",180}
	},
	--17
	{
		lights = {
			{24,32,8}
		},
		pos = {
			{25, 33},
			{21, 33},
		},
		doors = {
			{30,43},
			{31,43}
		},
		powers = {0,0},
		butterflies = {
		},
		keys = {
			{31,32,"chest"},
			{16,43,"door"}
		},
		gates = {
			{27,44},
			{28,44},
			{29,44},
			{26,47},
		},
		acristals = {
			{28,35},
			{19,44}
		},
		p_data = {21,37,46,"white",180,2,16,1}
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
	-- ! ---- ! --
	-- ! TEST ! --
	-- ! ---- ! -- 
	if not tp then
		tp = true
		x = 128 * 1
		y = 128 * 2
	end
	-- if not pulsator_state then
	-- 	x = 0
	-- 	y = 256
	-- end
	-- x = 0
	-- y = 256
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
	sfx_timer = 30
	sfx(61,3)
	if i_room > 15 then
		music(27)
		sfx(47, -2)
	end
end

function create_room()
	-- set pulsator state on
	-- and put pulsator object into global pulsator object
	if i_room >= 15 and not pulsator_state then
		pulsator_state = true
		add(pulsator, rooms_data[15].pulsator)
	end
	--handle music
	if music_object[1] then
		music_object[1] = false
		music(music_object[2])
	end

	delete_objects()
	create_objects()
	--characters
	lulu.passed = false
	hades.passed = false
	lulu.in_light = true
	hades.in_light = false
	disable_shield(lulu)
	disable_shield(hades)
	local room = rooms_data[i_room]
	--doors
	doors.lulu.x = room.doors[1][1] * 8
	doors.lulu.y = room.doors[1][2] * 8
	doors.hades.x = room.doors[2][1] * 8
	doors.hades.y = room.doors[2][2] * 8
	--pos
	lulu.x = room.pos[1][1] * 8
	lulu.y = room.pos[1][2] * 8
	hades.x = room.pos[2][1] * 8
	hades.y = room.pos[2][2] * 8
	--powers
	lulu.lights_left = room.powers[1]
	hades.turnoffs_left = room.powers[2]
	door_sound_played = false
	--replay pulsator music if lvl 15 reached
	if i_room == 15 then
		music(-1)
		music(44)
		-- sfx(47, 0, 0, 14)
	end
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
	reinit_character()
	is_in_switch = true
	sfx_timer = 45
	sfx(53,3)
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
	gates = {}
	butterflies = {}
	messages = {
		{"hint","welcome to lulu's quest!"},
		{"hint","hold 🅾️ and move to\n prepare a light"},
		{"hint","press ❎ when holding 🅾️\n to cast a light"},
		{"hint","lulu (left) can only live\n into lights"},
		{"hint","hades (right) can only\n live out of lights"},
		{"hint","press ⬇️ to switch characters"},
		{"hint","hades can turn off lights\n the same way as lulu"},
		{"hint","you got all powers left\n at top of the screen"}, 
		{"hint","the goal is to bring\n your characters..."}, 
		{"hint","...to their respective doors."}, 
		{"hint","good luck!"},
	}
	pulsator = {}
	dynamic_lights = {}
	acristals = {}
	walls = {}
end

function update_objects()
	-- When someone enter its door, passed will be turn on and character will disappear
	if collision(pactual, pactual == lulu and doors.lulu or doors.hades) then
		pactual.passed = true
		if lulu.passed and lulu.shield.active then
			disable_shield(lulu)
		end
		if hades.passed and hades.shield.active then
			disable_shield(hades)
		end
		if not door_sound_played then
			psfx(60)
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
					psfx(50)
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
			psfx(60)
			keys_owned += 1
			del(keys,k)
		end
	end)

	--shield cristals
	foreach(shield_cristals, function(sc)
		for c in all(chars) do
			if collision(c,sc) then
				if not c.shield.active or c.shield.timer > c.shield.time_set * 0.8 then
					psfx(57)
					if sc.lives then sc.lives = sc.lives - 1 end
					if sc.lives and sc.lives <= 0 then
						del(shield_cristals,sc)
					end
					c.shield.active = true
					c.shield.time_set = sc.timer * 30
					c.shield.timer = 0
					c.shield.r = sc.r
				end
			end
		end
	end)
	--gates
	foreach(gates, function(g)
		if collision_gate(pactual,g) then
			if keys_owned > 0 and not g.opened then
				psfx(60)
				keys_owned -= 1
				g.opened = true
			end
		end
	end)
	--butterflies
	for b in all(butterflies) do
		update_butterfly(b)
	end
	--messages
	if messages[1] and (btnp(❎)) then
		deli(messages, 1)
	end
	--pulsator
	update_pulsator()

	--acristals
	update_acristals()
end

--animations
function draw_objects()
	--black orbs
	foreach(
		black_orbs, function(bo)
			spr(bo_spr, bo.x, bo.y, 1, 1, false, false)
			if frames > 20 then
				spr(bo_spr+1, bo.x, bo.y, 1, 1, false, false)
			end
		end
	)
	--butterflies
	foreach(butterflies, function(b)
		draw_butterfly_light(b)
	end)
	--shields
	draw_shields()
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
		draw_keys(k)
	end)
	--shield cristals
	foreach(shield_cristals, function(sc)
		if sc.lives then print(sc.lives, sc.x + 8, sc.y - 2, 11) end
		spr(sc.c == "red" and 21 or 20, sc.x, sc.y, 1, 1, false, false)
    -- points scintillants
    if frames % 15 < 7 then
			pset(sc.x+3, sc.y+1, 7)
			pset(sc.x+5, sc.y+3, 7)
		else
			pset(sc.x+5, sc.y+1, 7)
			pset(sc.x+3, sc.y+3, 7)
		end
	end)
	--gates & butterflies in _draw fct
	--pulsator
	if pulsator[1] then
		draw_pulsator()
	end
	--acristals are in _draw()
	--walls
	draw_walls()
end

function draw_doors(d)
	--doors
	local flip = frames % 10 >= 5  -- Alterne toutes les 5 frames
	spr(35, doors.lulu.x, doors.lulu.y, 1, 1, flip, false)
	spr(35, doors.lulu.x, doors.lulu.y + 8, 1, 1, not flip, true)
	spr(51, doors.hades.x, doors.hades.y, 1, 1, flip, false)
	spr(51, doors.hades.x, doors.hades.y + 8, 1, 1, not flip, true)
end

function create_black_orb(x, y,r)
	add(black_orbs, {x = x, y = y, r=r})
end

function delete_objects()
	local lists_to_clear = {
		lights,
		black_lights,
		chests,
		keys,
		shield_cristals,
		gates,
		butterflies,
		messages,
		dynamic_lights,
		acristals
	}
	--delete all objects from ancient room or actual if restart_level()
	for _, tbl in ipairs(lists_to_clear) do
		for obj in all(tbl) do
			del(tbl, obj)
		end
	end
	keys_owned = 0
	--reset data of pulsator
	if pulsator[1] and rooms_data[i_room].p_data then
		pulsator[1].timer = 0
		pulsator[1].light_data.room_ac[1] = false
		pulsator[1].light_data.room_ac[2] = false
	end
end


function create_objects()
	local room = rooms_data[i_room]
	--create lights from new room
	for l in all(room.lights) do
		create_light(l[1] * 8, l[2] * 8, l[3], l[4], l[5], l[6])
	end
	--black orb
	for bo in all(room.black_orbs) do
		create_black_orb(bo[1] * 8, bo[2] * 8, bo[3]) 
	end
	--chests
	for c in all(room.chests) do
		add(chests, {opened = c[1],locked = c[2],check_lock = c[3],content = c[4],x = c[5] * 8,y = c[6] * 8})
	end
	--keys
	for k in all(room.keys) do
		add(keys, {x = k[1] * 8, y = k[2] * 8, style = k[3]})
	end
	--shield cristals
	foreach(room.shield_cristals, function(sc)
		add(shield_cristals, {x = sc[1] * 8, y = sc[2] * 8, timer = sc[3], r = sc[4], lives = sc[5], c = sc[6]})
	end)
	--gates
	foreach(room.gates, function(g)
		add(gates, {x = g[1] * 8, y = g[2] * 8})
	end)
	--butterflies
	foreach(room.butterflies, function(b)
		add(butterflies, {x = b[1] * 8, y = b[2] * 8, x1 = b[3] * 8, y1 = b[4] * 8, x2 = b[5] * 8, y2 = b[6] * 8, target = b[7], speed = b[8], r = b[9], light = b[10]})
	end)
	--messages
	foreach(room.messages, function(m)
		add(messages, m)
	end)
	-- set dynamics data to pulsator
	if pulsator[1] and room.p_data then
		local p = room.p_data
		pulsator[1].x = p[1] * 8
		pulsator[1].y = p[2] * 8
		pulsator[1].light_data.r_max = p[3]
		pulsator[1].light_data.type = p[4]
		pulsator[1].timer = p[5]
		pulsator[1].light_data.ac_activated = p[6] or 0
		pulsator[1].is_broken = false
		pulsator[1].spr_r = p[7] or 24
		pulsator[1].light_data.spd = p[8] or 1
		end
	--acristals
	foreach(room.acristals, function(ac)
		add(acristals, {x = ac[1] * 8, y = ac[2] * 8, active = false, c_col = nil})
	end)

	--define walls
	for i=0,15 do
		for j=0,15 do
			-- local x = room.x and (room.x / 8 + i) or i
			-- local y = room.y and (room.y / 8 + j) or j
			local x = i
			local y = 32 + j
			local t = mget(x, y)
			if fget(t, 2) then
				add(walls, {x = x * 8, y = y * 8, broken = false, tile = t, break_anim = 0})
			end
		end
	end
	--if level restart and walls were broken, then restore them
	for w in all(walls) do
		if w.broken then
			mset(w.x/8, w.y/8, w.tile)
			w.broken = false
			w.break_anim = 0
		end
	end
end

--gates
function draw_gates(g)
		spr(not g.opened and 53 or 52, g.x, g.y, 1, 1, false, false)
	end

-->8
--butterflies

function update_butterfly(b)
	if lulu.using_light or hades.using_light then return end
	--PATROUILLE
	-- rれたcupれたrer la cible actuelle
	local tx = b.target == 1 and b.x1 or b.x2
	local ty = b.target == 1 and b.y1 or b.y2

	-- direction
	local dx = tx - b.x
	local dy = ty - b.y

	-- distance れき la cible
	local dist = sqrt(dx*dx + dy*dy)

	-- si proche, on change de direction
	if dist < b.speed then
		b.x = tx
		b.y = ty
		b.target = (b.target == 1) and 2 or 1
	else
		-- interpolation vers la cible
		b.x += (dx / dist) * b.speed
		b.y += (dy / dist) * b.speed
	end

	-- flip sprite
	b.spr_flip = dx > 0 and true or false
end

function draw_butterfly(b)
	spr(frames % 10 >= 5 and 33 or 34, b.x-4, b.y, 1,1, b.spr_flip)
end

function draw_butterfly_light(b)
	local blight = b.light
	if blight == "black" then
		pal(14,3+128,1)
	end
	local light_c = blight == "white" and 9 or blight == "black" and 14 or 0
	local circ_c = blight == "white" and 6 or blight == "black" and 13 or 6
	circfill(b.x, b.y, b.r, light_c)
	circ(b.x, b.y, b.r, circ_c)
end

-->8
--chests

function open_chest(c)
	sfx_timer = 20
	sfx(49,3)
	c.opened = true
	--crれたer le contenu du coffre au-dessus
	if c.content[1] == "black_orb" then
		create_black_orb(c.content[2] * 8, c.content[3] * 8, c.content[4])
	end
	if c.content[1] == "turnoff" then
		hades.turnoffs_left = hades.turnoffs_left + 1
	end
end
-->8
--keys

function draw_keys(k)
	if k.style == "chest" then
		if frames % 30 < 7 then
			spr(41, k.x, k.y, 1, 1, false, false)
		elseif frames % 30 < 14 or frames % 30 > 23 then
			spr(40, k.x, k.y, 1, 1, false, false)
		elseif frames % 30 < 24 then
			spr(41, k.x, k.y, 1, 1, true, false)
		end
	elseif k.style == "door" then
		if frames % 30 < 7 then
			spr(25, k.x, k.y, 1, 1, false, false)
		elseif frames % 30 < 14 or frames % 30 > 23 then
			spr(24, k.x, k.y, 1, 1, false, false)
		elseif frames % 30 < 24 then
			spr(25, k.x, k.y, 1, 1, true, false)
		end
	end
end

-->8
--messages

function draw_messages()
	if messages[1] then
		local bg_col = 7
		local f_col = 1
		local title_col = 9
		local bg_title_col = 5
		local border_col = 4
		local x1 = room.x+4
		local y1 = room.y+14
		local x2 = room.x+124
		local y2 = room.y+36
		rectfill(x1, y1, x2, y2, bg_col)
		rect(x1, y1, x2, y2, border_col)
		rectfill(x1+3, y1-2, x1 + 3  + #messages[1][1]*4, y1+4, bg_title_col)
		print(messages[1][1],x1+4,y1-1,title_col)
		print(messages[1][2],x1+4,y1+8,f_col)
		if messages[2] then print("❎->",x2-16,y2-6,13) end
		if not messages[2] then print("❎end",x2-20,y2-6,13) end
	end
end

-->8
--pulsator

function draw_pulsator()
	-- osciller uniquement si pulse_timer actif
	local pulse_ratio = pulsator[1].pulse_timer / pulsator[1].pulse_dur
	local scale = pulsator[1].spr_r / 10  - (pulsator[1].light_data.ac_activated * 0.2) + 0.5 * pulse_ratio -- grossit れき chaque battement
	-- flips
	local flipx = frames % 15 < 7
	local flipy = frames % 30 < 15

	-- palette dynamique
	if frames % 30 < 10 then
		pal(12,8)
	elseif frames % 30 < 20 then
		pal(12,7)
	else
		pal(12,12)
	end

	-- position
	local cx = pulsator[1].x + pulsator[1].spr_r
	local cy = pulsator[1].y + pulsator[1].spr_r

	-- dessiner sprite
	local w = 32 * scale
	local h = 32 * scale
	local x = pulsator[1].x + (48 - w) / 2
	local y = pulsator[1].y + (48 - h) / 2
	sspr(12*8, 0, 32, 32, x, y, w, h, flipx, flipy)

	-- effets れたlectriques (garde ton effet !)
	for i = 1, 5 do
		local a = rnd(1) * 2 * 3.141592653589793
		local r1 = (20 + rnd(5)) * scale * 0.6
		local r2 = (r1 + rnd(5)) * scale * 0.6
		local x1 = cx + cos(a) * r1
		local y1 = cy + sin(a) * r1
		local x2 = cx + cos(a) * r2
		local y2 = cy + sin(a) * r2
		local c = rnd(1) < 0.5 and 7 or 12
		line(x1, y1, x2, y2, c)
	end

	pal(12,12)
end

function update_pulsator()
	if (lulu.using_light or hades.using_light) and i_room > 15 then return end
	if pulsator[1] then
		--Aprれそs chaque pulsation, on rejoue le SFX electrical effects
		-- if pulsator[1].timer == 30 and i_room == 15 then sfx(47, 0, 0, 14) end

		--A less before the next pulsation, prevent the player
		local beat_delay = pulsator[1].beat_delay - pulsator[1].light_data.ac_activated * 30
		-- if pulsator[1].timer == beat_delay - 30 and i_room == 15 then sfx(47, 0, pulsator[1].light_data.type == "white" and 16 or 19, 1) end

		pulsator[1].timer += 1
		if pulsator[1].timer >= beat_delay then
			-- un battement se produit
			pulsator[1].pulse_timer = pulsator[1].pulse_dur -- dれたclenche une pulsation visuelle
			pulsator[1].timer = 0
			-- SFX
			if sfx_timer == 0 and i_room != 15 then
				sfx(48, -1)
				sfx_timer = 30
				sfx(48, 3, pulsator[1].light_data.type == "white" and 7 or 14, 1)
			end
			
			-- update light from pulsator
			local new_dyna_light = create_dynamic_light(pulsator[1].x + 24, pulsator[1].y + 24, pulsator[1].light_data.type, pulsator[1].light_data.spd, pulsator[1].light_data.r_max, pulsator[1].spr_r)
			add(dynamic_lights, new_dyna_light)
			pulsator[1].light_data.type = pulsator[1].light_data.type == "anti" and "white" or "anti"
		end
		-- diminuer le pulse progressivement
		if pulsator[1].pulse_timer > 0 then
			pulsator[1].pulse_timer -= 1
		end
	end
end

function break_pulsator()
	--if we are here, then all acristals are activated
	if not pulsator[1].is_broken then
		-- this function is called when both characters activated the acristals
		-- timer of pulsator reset to 0
		pulsator[1].timer = 0
		-- wait 1 sec
		animation_timer = 60
		-- screenshake
		shake = 60
		-- wait 0.5 sec and delete acristals
		pulsator[1].is_broken = true
		music(-1)
		music_object[1] = true
		music_object[2] = 27
		sfx(47, -2)
		sfx_timer = 120
		sfx(63)
	end
		--when animation is finished, delete the acristals and destroy walls
	if animation_timer == 0 then 
		for i=1,#acristals do
			del(acristals,acristals[i])
		end
		foreach(walls, function(w)
			--break walls
			w.broken = true
			mset(w.x/8, w.y/8, 0)
			--accelerate pulsator just for the end of the lvl
		end)
	end
end


-->8
--acristals
function draw_acristals()
	foreach(acristals, function(ac)
		--alterner toutes les 5 frames
		local state = frames % 20 >= 10
		local s = ac.active and 54 or state and 39 or 38
		spr(s, ac.x, ac.y, 1, 1, false, false)
		-- if ac is active, then it throws a light towards the pulsator
		if ac.active then
			-- coordonnれたes du centre du cristal
			local ax = ac.x + 4
			local ay = ac.y + 4
			-- coordonnれたes du centre du pulsator
			local px = pulsator[1].x + 24
			local py = pulsator[1].y + 24

			-- nombre d'れたclairs
			local nb_bolts = 3
			-- nombre d'れたtapes par れたclair
			local steps = 8

			for j=1, nb_bolts do
				for i=0,steps-1 do
					local t1 = i / steps
					local t2 = (i+1) / steps

					local x1 = lerp(ax, px, t1) + rnd(7) - 1
					local y1 = lerp(ay, py, t1) + rnd(7) - 1
					local x2 = lerp(ax, px, t2) + rnd(7) - 1
					local y2 = lerp(ay, py, t2) + rnd(7) - 1
					pal(14,3+128,1)
					palt(0, false)
					palt(12, true)
					-- couleur alれたatoire parmi un choix れたlectrique
					local c = ({10, 14, 0})[1 + flr(rnd(3))]
					line(x1, y1, x2, y2, c)
					palt(12, false)
					palt(0, true)
					pal(14,14)
				end
			end
		end
	end)
end

function update_acristals()

	--check for collision with chars
	for i, ac in pairs(acristals) do
		for c in all(chars) do
			--check each frame if collision with a character
			if not ac.active and collision(c,ac) then
				ac.active = true
				ac.c_col = c
				pulsator[1].light_data.ac_activated += 1
				pulsator[1].light_data.room_ac[i] = true
				psfx(47,3)
				break
			end
		end
		--if it has a collision with a char, now check each frames if collision is still there
		if ac.active then
			if not collision(ac.c_col,ac) then
				ac.active = false
				pulsator[1].light_data.ac_activated -= 1
				pulsator[1].light_data.room_ac[i] = false
				ac.c_col = nil
				psfx(47,3)
			end
		end
	end
	--check if all acristals are activated
	if pulsator[1] then
		for ac in all(pulsator[1].light_data.room_ac) do
			if not ac then return end
		end
		break_pulsator()
	end
end

-->8
-- dynamic lights
function create_dynamic_light(x, y, type, spd, r_max, r_default)
	return {
		x = x,
		y = y,
		r = r_default or 32,
		r_max = r_max,
		type = type,
		spd = spd
	}
end

function update_dynamic_lights()
	if (lulu.using_light or hades.using_light) and i_room > 15 then return end
	foreach(dynamic_lights, function(dl)
		if dl.r < dl.r_max then
			dl.r += dl.spd
		end
		if dynamic_lights[2] and dynamic_lights[2].r == dynamic_lights[2].r_max then
			deli(dynamic_lights, 1)
		end
	end)
end

function draw_dynamic_lights()
	foreach(dynamic_lights, function(dl)
		local c = dl.type == "anti" and 0 or 9
		if dl.type == "black" then
			pal(14,3+128,1)
			c = 14
		end
		circfill(dl.x, dl.y, dl.r, c)
		circ(dl.x, dl.y, dl.r, dl.type == "white" and c+1 or 0)
	end)
end

-->8
--walls
function draw_walls()
	foreach(walls, function(w)
		if w.broken and w.break_anim < 24 then
			--animate walls
			w.break_anim += 1
			local frame_idx = flr(w.break_anim / 6)
			if frame_idx > 3 then frame_idx = 3 end
			spr(123 + frame_idx, w.x, w.y)
			if w.break_anim == 24 then
				spr(0, w.x, w.y)
			end
		end
	end)
end


-->8
--UI
function draw_ui()
	local x = room.x
	local y = room.y
	palt(0, false)
	palt(12, true)
	--# lights
	for i = 1, lulu.lights_left do
		spr(49, x + i * 8, y + 4)
	end
	--# turnoffs
	for i = 1, hades.turnoffs_left do
		spr(50, x + 120 - i * 8, y + 4)
	end
	--# keys
	if keys_owned > 0 then
		sspr(9*8, 3*8, 8, 8, pactual.x + 6, pactual.y - 2, 8, 8)
	end
	palt()
end

-->8
--helper functions

function debug_print()
	print("lvl: "..i_room, room.x+40,room.y+2,8)
	if pulsator[1] then
		print(pulsator[1].light_data.room_ac[1] and "true" or "false")
		print(pulsator[1].light_data.room_ac[2] and "true" or "false")
		print(pulsator[1].light_data.ac_activated)
	end
	print("room.x: "..room.x)
	print("room.y: "..room.y)
	if walls[1] and walls[2] then
		print(walls[1].broken and "true" or "false")
		print(walls[2].broken and "true" or "false")
	end
	print(shake)
	print(animation_timer)
	-- if pulsator[1] then
	-- 	print("timer:"..pulsator[1].timer, room.x + 4,room.y+50,11)
	-- 	print(type(pulsator[1].pulse_timer))
		-- rectfill(room.x + 4, room.y + 50, room.x + 4 + 30, room.y + 50 + 50, 7)
		-- for k,v in pairs(pulsator[1]) do
		-- end
	-- end
	-- if dynamic_lights[1] and dynamic_lights[2] then
	-- 	print("two dynas")
	-- 	if dynamic_lights[3] then print("three now :(...") end
	-- end
	-- print("timer:"..lulu.shield.timer, pactual.x,pactual.y-10,11)
		-- print("active:"..(lulu.shield.active and 'true' or 'false'), lulu.x,lulu.y-10,11) 
		-- print("delay:"..delay_switch, lulu.x,lulu.y-20,11)
	-- foreach(gates, function(g)
	-- 	if collision(pactual,g) then
	-- 		print("gate: "..g.x, pactual.x-28,pactual.y-10,8)
	-- 		print("opened: "..(g.opened and "true" or "false"), pactual.x-28,pactual.y-20,8)
	-- 		print("keys: "..keys_owned, pactual.x-28,pactual.y-30,8)
	-- 	end
	-- end)
	-- print("dx: "..pactual.dx, pactual.x,pactual.y-10,8)
	-- print("dy: "..pactual.dy, pactual.x,pactual.y-20,8)
	-- rectfill(room.x+39, room.y+1, room.x+39+20+8, room.y+1+8, 7)
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
	return dist - 2 <= l.r
end

function collision_black_light(p, l)
	local lx = l.x
	local ly = l.y
	local rx = max(p.x, min(lx, p.x + p.w))
	local ry = max(p.y, min(ly, p.y + p.h))
	local dx = lx - rx
	local dy = ly - ry
	local dist = sqrt(dx*dx + dy*dy)
	-- print("dist: "..flr(dx*dx + dy*dy), pactual.x, pactual.y - 10, 7)
	-- pset(rx, ry, 11)  -- centre du joueur
	-- pset(lx, ly, 8)   -- centre du cercle
	return dist + 2 <= l.r
end

function collision_gate(p, g)
	local px1 = p.x
	local py1 = p.y
	local px2 = p.x + p.w
	local py2 = p.y + p.h
	local gx1 = g.x + 2
	local gy1 = g.y + 2
	local gx2 = g.x + 6
	local gy2 = g.y + 6
	return not (px1 > gx2
				or py1 > gy2
				or px2 < gx1
				or py2 < gy1)
end

function psfx(num)
	if sfx_timer <= 0 then
		sfx(num,3)
	end
end

function lerp(a,b,t)
	return a+(b-a)*t
end

__gfx__
00000000088888800888888001111110088888800222222002222220c111111c0222222000000000000000000000000000000000000011111111000000000000
00000000888888888888888811111111888888882222222222222222111111112222222200000000000000000000000000000000011111111111111000000000
000000008899999888999998114444418899999822222f2222222f2211111d1122222f2200000000000000000000000000000001111c15555551111110000000
00000000899ff9f9899ff9f9144dd4d4899ff9f90229ff920229ff92c113dd310229ff9200000000000000000000000000000011115ccc555555551111000000
0000000089fc9fc989fc9fc914d14d1489fc9fc9022ffff2022ffff2c11dddd1022ffff20000000000000000000000000000011155555ccdd5555cc511100000
00000000089fff90089fff90014ddd40089fff900121d1020121d102c01050c10121d1020000000000000000000000000000111c55ddddcccddd5c5551110000
000000000088880000888800001111000088880001dddd0010dddd00c05555cc01dddd000000000000000000000000000001115ccdddddddcddddcdd55111000
00000000004004000004500000500500040000400140040010045000c02cc2cc040000400000000000000000000000000011155dcdddddddcddddcddd5511100
0333333099099099aa0aa0aabb0bb0bb0000000000000000000000000000000000000000000000008000000800000000001155ddccddddddccddccdddd551100
33bbbb3390000009a000000ab000000b0000c0000000800000000000000000000004000000040000000000000000000001115ddddccddddddcccccddddd51110
3b3333b3000000000000000000000000000c7c000008780000030000000300000004000000464000000000000000000001155dddddcddddddddddcddddd55110
3b3bb3b390000009a000000ab000000b0000c0000000800000393000003a30000004000000040000000000000000000001155dddddcddddddddddcddddd55110
3b3bb3b390000009a000000ab000000b000010000000200000393000003a3000000400000004000000000000000000001115ddddddcddd11111dccdddddd5111
3b3333b300000000000000000000000000001000000020000003000000030000000400000004400000000000000000001155ddddddcdd1111111ccdddddd5511
33bbbb3390000009a000000ab000000b00001000000020000000000000000000000400000004000000000000000000001155ddddddcd111111111cddddddd511
0333333099099099aa0aa0aabb0bb0bb00111110002222200000000000000000000000000000000080000008000000001155ddddddc1111111111cddddddd511
6666666607070a00070700000005500008800880000000000000000000000000000000000000000000000000000000001155dddddcc111111111ccddddddd511
6555555600444a4000444a400055550088888888000000000000000000000000000a0000000a0000000000000880000011555dddccdcc1111111c1dddddd5511
655555560000000000000a000558855088888888080800000007000000080000000a000000a9a000888888880088888011555dddcdd1ccccc111c1ddddddcc11
6555555600000000000000005588885588888788888880000076700000828000000a0000000a0000888888880008888011155dddcddd1111c111ccccccccc111
655555560000000000000000588998858888778888888000076a6700082a2800000a0000000a0000848888880000880001155dddcdddd111cc11cddddd555110
6555555600000000000000005899998508888880088800000076700000828000000a0000000aa000888888880000000001155dddcccddd111c1cdddddd555110
6555555600000000000000005899798500888800008000000007000000080000000a0000000a00008888884800600000011155ddcdccdddddccccddddd551110
666666660000000000000000589779850008800000000000000000000000000000000000000000008888888860660606001155cccddccdddddddcdddd5551100
66666666ccc0ccccccc0cccc0005500000455400004444000000000000000000000aa000ccc0cccc8888888888888888001115c555ddcdddddddccd555511100
65565556cc0a0ccccc080ccc005555000000000000455400000000000999999004444440cc0a0ccc8888888888888888000111cc55ddcccddddddcc555111000
65665556c0a7a0ccc08a80cc055dd5500000000000444400000b00009974449946665554c0a6a0cc8884888888888888000011c555555dccddddddcc51110000
666556660a777a0c08aaa80c55dddd55000000000045540000b3b0009744444946655554cc0a0ccc8888888888888888000001115555555cc555555511100000
65565656c0a7a0ccc08a80cc5dd22dd500000000004444000b3a3b009999999997444449cc0a0ccc88888888888888880000001111555555c555551111000000
65566556cc0a0ccccc080ccc5d2222d5000000000045540000b3b000974aa44997444449cc0aa0cc88888888888888880000000111111555cc51111110000000
65556556ccc0ccccccc0cccc5d2272d50000000000444400000b00009744444997444449cc0a0ccc888888488888888800000000011111111c11111000000000
66666666cccccccccccccccc5d2772d50045540000455400000000009999999999999999ccc0cccc888888888888888800000000000011111111000000000000
000001111110000000000011eeeeeeee000111000000000000111000055555500555555555505505555555500555555000000000505555055055055566666666
000011111111000000000011eeeeeeee001111100000010001111100555555555555555555555555555555555555555500000000555655555555555566666666
000111111111100000000011eeeeeeee011111111111111101111110555665555555556655555555565665555556655500000000655666665655655566666666
001111111111110000000011eeeeeeee111111111111111111111111556666555555566665566566666665555556665500000000666666666665665666666666
011111111111111000000011eeeeeeee111111111111111111111111556665555556666666666666666666555566655500000000666666666666666666666666
111111111111111100000111eeeeeeee011111101111111111111110555655555556666666666666666666555566665500000000666666666666666666666666
111111111111111100000011eeeeeeee00111110010000000111110055555555555666dd66666666666666655556655500000000666666666666666666666666
111111111111111100000011eeeeeeee00011100000000000011100005555550555666dd66666666d66666555556665500000000666666666666666666666666
1111111111111111110000000001100000000000d666655555556666055555505556666666666666666665555556665500000000055555005005555066666666
11111111111111111110000000111100000000006665555005556666556766555555666666666666666655555566666500000000555555555555555566666666
11111111111111111100000001111110000000006665550000555666567766650556666666666666666665505556655500000000555555555566555566d66666
01111111111111101100000011111111000000006655500000055556577666755556666666666666666665555566665500000000555666556666655566666d66
00111111111111001100000011111111000000005555000000005556567777755555666666666666666655555666655500000000556666666666655566666666
000111111111100011000000111111110000000055500000000005555667666505556666666666666666655055566665000000000566dd666666655566666666
000011111111000011000000011111100000000055000000000000555567665555566666666666666666555555666555000000000556dd666d66555066d666d6
00000111111000001100000000011100000000005000000000000005055555505556666666666666666665555556665500000000555666666666555066666666
11111111111111110000000000111100111111115000000000000005000000005566666d66666666dd6666555566655500000000055566666666655500000000
11111110111111110000000001111100111111115500000000000055000000005556666666666666dd6666555556655500000000055566d666dd655000000000
111110000011111100111000001111001111111155500000000005550000000055666666666666666666655555666655000000005556666666dd665000000000
11110000000111110011110000111100111111116555000000005555000000005556666666566666666655555556665500000000555666666666665500000000
11110000000001110111110000111100111111116555500000055566000000005556666666566665666655555566655500000000555666665566655500000000
11100000000000110111111000111110111111116665550000555666000000005555665655555555656555555556655500000000555566555555555500000000
11000000000000111111111100111100111111116666555005555666000000005555555555555555555555555555555500000000555555555555555500000000
1100000000000001111111110011110011111111666655555556666d000000000555555550550555555555500555555000000000055550050055555000000000
10000000000000111111111100111100000000000555555555555555555555500555555555555555555555500555555000000000000000000000000000000000
11000000000000111111111101111110000000005555555555565555555555555555555555555555555555555567665500000050000000000000000000000000
11000000000001110111111011111111000000005556565656566565556655555556665555555555566665555677066555500565000000000000000000000000
11100000000011110011111011111111000000005566666666666666666666555566666556555566666666555770067550050005000000000000000000000000
11111000000011110011110011111111000000005566666666666666666666555566666666555565566666555600007550000075500000750000000000000000
11111100000111110001110001111110000000005555665566666666656565555556666555555555556665555660666556005065565550650000000000000000
11111111011111110000000000111100000000005555555565666565555555555555555555555555555555555567665556600655565005555050000500000000
11111111111111110000000000011000000000000555555555555555555555500555555555555555555555500555555055656655556565665555550500000000
9696969696f5959596959596969696f5000000000000000000000200000000000202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
46740616469695a654d6a65437545485000000000050000000100200020202020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
464607174615b5000000242500000085000000000002020000020200000000000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
946767677700b57400002425876797f5000000000231313131313102620000000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a55454545454b5747400041400000085000000023131313131313131020000000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50024d56767976767e5051500000085730002023131023131023131310200000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50057e60415b50514b6242500007485020202313102a1a1a1a10231310200000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50000041500b6000514041400876795000000313131a10000a13131310000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
95770415000075000005461500000085000000313131a10000a13131310000000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50415b40010755000b4051426576796000002313102a1a1a1a10231310202020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a51500d66767976797e6240574002736000202313131023131023131310200000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
957700000515b5333275247416070037005300023131313131313102020232330200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50000002425b5000075740000160700020200620231313131313153030300000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a55454b42425869794a4000026001607000202020202020000020202020202020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
95a400b50414000086a6003536000016000000000000000000000200000000000200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
95f5e4f5e4e4e4e4a400003636260000000000000000000000005300000000730202020202020202020202020202020202020202020202020202020202020202
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
0000000000000000000001000202020200000000000000000000020002020202818080000000808000000200020202028500000000008004000002000202020280808080808080010101010100010101808080808001018501010101000101018080808080010100010101010001010080808080800101010101018080808000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
59595959595959595959595959595f596959595f5959595959595959596969695f594f4f69695959596969694f4f4f4f595959595959595959595959595955564f4f696969696969696969694f4f4f4f59595959595959595959595959595959595f593a3a5a00000058593a3a5959595f595959595959595959595959595959
595556595f59595959595f5959595959005859595969695959595f595a000000594f4f5500005659556300006d4f4f4f59595959595959595f595959595f65664f5a00004252234064606133584f5556585f595959595f59595959595f5959593a3a3a3a3a5a00000068593a3a3a3a59593a5959595955565f5959593a3a3a59
59656659595f59595959595959595959005859696a425268596959595a6262484f4f6a000000005b0063004064684f4f5959595f5959595959595959595959595f5a00004252006464707100585f6566595959595959595959595f5959595959595f59593a5a00620000585f3a3a3a3a593a3a59595965665959593a3a3a3a59
595959595959595f595959595f59595900586a52004252616b6358596a6464584f5572000053006b0073406464646d4f59595959595955565959595959595959696a0000425220506464647869595f59595556595959595959595959595959595f593a593a59494a700068696969593a593a3a3a3a595f5959593a3a3a3a3a59
5959595959595959595f595556595959006b4252004041000063585a606148695a000000006300720000506464606158595f5959595965665f595959595959596451004742520000614751006356595f59656659695969595959696959595f59593a3a593a3a3a5a6170000000636859593a3a3a3a3a5959593a3a3a3a3a3a59
5959595f59595959595959656659595900004252006160000063585a70716b005a41000000630000404100506470715859595959595959595959595959595959510000007170000047720000630056596859595a005b4268595a000058595959593a3a3a3a3a3a5a0061700000630058593a3a3a3a3a3a593a3a3a3a3a3a3a59
595959595969696959595959595f595900004252000000000073586a505100005a51000000630040645100006164645859695969695959595959695959696969000000005051004700000000730000680058695a006b4041685a000068695959593a5f59696969767976770000630058593a3a3a3a3a3a3a3a3a3a3a3a3a3a59
5f5959596e0000474b68696969695959000040410000000000006b00000000005a6200000063487a51000000006164585a006b6464686969695a63586a425200000000004b6200000073000000004051005b006b00005051006b000063006859593a5955006200425200720000730058593a3a3a3a3a3a3a3a5959595f595959
6969696e004041005b007164646d595949494a510000000000000000000000005a47000000486a5100000053000050586a00005064606164516b636b0042522370000000584a00000063000000405100006b7000000000000063000063000058593a5a00007576797676494a005300585f595959595959595959596969696959
00006300005051005b71606164516d6969595a000000000000000000000000335a230000405b510000004b6300003358337000005070715100007300004752006470000068697a0000630000405100000000617000000000006300007300005b593a5a00006300404100586a00630058596969696969696969696e5100003358
00005300004252005b6170715100720063685a410000000000000062000000005a000040486a00000000684a000000580064700000616000000053000042524b6464700000000062006300405100717000000072620000000063004b0000335b5f3a594a0063005051006b52006300585a007300004051716040510000003358
0000630000425200470061510000000063006b51000000530000405100005d49594949496a000000000000684d4d4d594949494a00787a0048494a00484d4e594d4d4e4d76767976767679764d4d4e4e7a000000630000000073005b000000583a3a595a00630040410042520048495f5a007300405171604051005300004859
00006300004252005b000000000000007300630000000063004051000075695f5f59696a2a2a2a2a2a2a2a2a686959595959595a0071700058595a00585959595f59696a000000000000000068595f59007876797679767a000000584d4976593a3a5f594a63005051004252485f2a2a59767676797676767679767a45456859
00006300004252235b3300000000000000006300006200634051005300002358596a3a3a3a3a3a3a3a3a3a3a3a3a6859595f5959494949495959594959595f59596a2a2a2a2a2a2a2a2a2a2a2a2a685900000000630078797a007869696a23583a3a59595a63000000004248593a3a3a5a004051716040510000006300002358
0000634e4e4252005b00006200004d4e00006300004d4d4e51000063000000585a3a3a3a3a3a3a3a3a3a3a3a3a3a3a585959595f59595959595f5959595f59596a3a3a3a3a3a3a3a3a3a3a3a3a3a3a6800000000630000720000000000610058593a3a3a5a234b2a2a4b33583a3a3a595a405171604051494900006300002358
4d4e4d4f4f4e4d4e6b4d4d4e4d4d4f4f4d4d4e4e4d4f4f4f594e4d4d4e4d4d595f49494949494949494949494949494f5959595959595f595f595959595959593b3b3b3b3b3b3b3b3b3b3b3b3b3a3a3a594e4d4d4e4d4e4d4e4d4d4d4e4d4d59595f3b3b5a235b3b3b5b33583b3b59595f494949494949595f49494949494959
5a00405161645b000063000042586a2a59596a600071600000000040646061585a5200004041000063000071606d69595f596969696959595969695959596959596a600000007160005041006d593a3a5959595959696969696969695955565900405161700a0000335b47000040606100000000000000000000000000000000
5a40510000615b000063000042583a3a596a60007160000040410050647071585a52000050510000630071600061645859550040606168696a63616d696e42586e6000000071600000005041006d593a595959596a00000000000000566566594051000061700001005b00007164707100000000000000000000000000000000
5a51000000005b000063000047593a3a5a60005d4d494d4e76797676767976795a524b004252000073716000000061585a0040647071510000630061700042586000000071604b00004b00504100583a59595f5a000000000000000000585f59510048767679767676797a40604b646000000000000000000000002020202020
5949494a00005b410048494959593a3a5a00716d6969696e42520000000072005a52584a4252000071600000754949595a4064646451000000635300617042584976767676765a45455b005d767669695959595a00000075497700007559595900005b000000000000007160475b517800000000000000202020202000000000
5f59595a00005b504158595f593a3a3a6a7160000000006342520000000000005f79696976767679767a00000068595f594e4d4e4d4e5e46445d4e4e4d4e4d596a00716000475b00005b005b23330063595f595a000000005b0000000058595547005b000048767976767976795b000000000000202020000000000000000000
5969696a00006b005068696959593a3a767676767976767679767676795e00005a520000006300007200000000406859593a3a3a3a3a5a0000585f5959593a3a0071605300475b00005b005b0000006359595959770000005b0000000058596570005b7a445b454545454545455b460000002020200000000000000000000000
5a426352000053000050410058593a3a405142520000007164410078796e45455a4545454563454600006200405100585f595959593a5a70005859593a3a3a597160007876766e4545687969764a00475955565a000000005b00000075595f5961705b63005b007876764977005b7a0023332000000000000000000000000000
5a476352000063000000504158593a3a510042520000716061510000000000405a524b00005300000000634048494959593a3a3a3a3a5a617058593a3a593a59600000630000000000000000005b45455965665a000000755a0000000058595900785b63785b000000635b00005b000000002000000000000000000000000000
5949494949494949494a005058595f3a5300425200487676764a0000000000615a525b00484979767676767969696959593a59595f595a0061583a3a3a593a5f7a454663006200000040410000587a005959595a000000005b0000000058595f00005b63006876767a635b00785b000020202000000000000000000000000000
2a2a2a5959595f59595a00005859593a63004252756a00000058492a2a2a4d495a525b00686e00000063000040512358593a3a3a3a3a5a0071583a593a593a592a2a4d4976764a000048797a005b635359595f5977000000584a000000585f5900005b470000426352635b00425b457800000000000000000000000000000000
59593a3a59595959595a00005859593a47454545454653000068593a3a3a3a595a525b00630000000063004051000058593a5959593a5a7160583a593a593a3a3a3a3a5a60475b00005b6061415b63475959595500000000585a000000585955470058767679767976766977425b000000000000000000000000000000000000
595f3a3a3a3a5f59596a00006859593a63004252620063000000583a3a3a3a3a5a52584a63000000004b40515d4949593a3a5f593a3a5a6000583a593a595f595f3a3a5a70715b00625b7071475b63735f595a0000000047595a47000058596500005b617000000042520000425b530000000000000000000000000000000000
593a3a595f3a59596a4445454568593a2a2a2a78794a63787a00686969593a3a5a525859492a472a2a6b2a75595f5959595959593a595a0000583a593a3a59596969696e50515b00635b4761485f7a7059595a00007576695f5977000058595900006b476170000042520000486b470000000000000000000000000000000000
593a5959593a595a330000000023583a3a3a3a3a3a5b63233340510000583a3a5a3358593a3a3a3a3a3a3a3a59595959595f3a3a3a595a2333583a59593a3a3a6061604445756e00636d7976696e606156595a00000000335b23000047585959707879797a61705d767976766a00004000000000000000000000000000000000
3a3a5f59593a595a000000620000583a3a3a3a3a3a5a63000051000044583a3a5a00583a3a3a3a3a3a3a3a3a3a595f593a3a3a593a595a0000583a59593a595f707170000000000063000000716000476659594d4d4a00005b005d4d4959595f617000005300615b230000005300406400000000000000000000000000000000
59595959593a59594949494949495f593b3b3b3b3b59494949494949495f3b3b59495959595959595f595959595959593b593b593b59594949593b5f593a3a594d4e4d4e4e4d4e4d4d4d4d4e4d4e4d49595f59595f594d4d5949595f595959594e4d4e4d4d4e4d6b004e4d4e4d4d4e4d00000000000000000000000000000000
__sfx__
a100000034670250701f0701a070170701507013070100700f0700c0700a07008070070700507004070040700c4100c4200c4300c4400c4500c4600c4700c4700c4700c4700c4700c4700c4700c4700c4700c470
010110202435024340187301874018750187601876018760187501875018750187501875018750187501875018752187521875218752187521875218752187521875218752187521875218752187521875218752
01011c20346700d07007070020703c6703c6603c6603c6503c6503c6503c6403c6403c6403c6303c6303c6303c6303c6303c6203c6203c6203c6203c6203c6203c6203c6103c6103c6103c6103c6103c6103c610
0100000034670250701f0701a060170601505013050100500f0400c0400a04008040070300503004020030200201001010000100c4000c4000c4000c4000c4000c4000c4000c4000c4000c4000c4000c4000c400
312400002473424732247322473224732247322473224732257342573225732257322673426732267322673227734277322773227732277322773227732277322473424735247002470035710357203573035740
3324000020734207322073220732207322073220732207321c7341c7321c7321c7321d7341d7321d7321d7321f7341f7321f7321f7321f7321f7321f7321f73220734207351d7001d70010b3010b4028a5010b60
45240000299602b960299602c960359603396033732337222e9602c9602b9602b7322b7222b7122b7122b712249602596027960277322772227712299602475124960247322472224712309602e9602c9602b960
8d240000293462533620326183161d31619326143360c3462b34627336223261f3161f3161b32616336133462b34627336243261f3161f3161b32618336133462c3462933624326203162b316273261833614346
c5240000144421444518432184351d4321d43519432194351844218445194321943515432154351943219435164421644519432194351d4321d43519432194351f4421f445204322043524432244351b4321b435
c52400001b525144321443518422184251d4221d42519422194251843218435194221942515422154251942219425164321643519422194251d4221d42519422194251f4321f435204222042524422244251b422
d12400000d1150d1250d1350d1450d1550d1450d1350d12505115051250513505145051550514505135051250a1150a1250a1350a1450a1550a1450a1350a1250311503125031350314503155031450313503125
d324000030014300123001230012300123001230012300122c0142c0122c0122c0122c0122c0122c0122c01229014290122901229012290122901229012290122e0142e0122e0122e0122e0122e0122e0122e012
c5240000145221452518522185251d5221d52519522195251852218525195221952515522155251952219525165221652519522195251d5221d52519522195251f5221f525205222052524522245251b5221b525
c524000000000145121451518512185151d5121d51519512195151851218515195121951515512155151951219515165121651519512195151d5121d51519512195151f5121f515205122051524512245151b512
c12400000d0150d0150d0150d0150d0250d0250d0250d02505015050150501505015050250502505025050250a0150a0150a0150a0150a0250a0250a0250a0250301503015030150301503025030250302503025
c1240000144121441518412184151d4121d41519412194151842218425194221942515422154251942219425164221642519422194251d4221d42519422194251f4321f43520432204351f4321f4351b4321b435
c12400001b515144121441518412184151d4121d41519412194151841218415194121941515412154151941219415164121641519412194151d4121d41519412194151f4221f42520422204251f4221f4251b422
d52400000d1250d1350d1450d1550d1550d1550d1450d13505125051350514505155051550515505145051350a1250a1350a1450a1550a1550a1550a1450a1350312503135031450315503155031550314503135
c5240000244422444522432224352443224435224322243524442244452243222435254322543524432244352444224445224322243524432244352243222435224422244520432204351f4321f4352043220435
c52400001b425244322443522422224252442224425224222242524432244352242222425254222542524422244252443224435224222242524422244252242222425224322243520422204251f4221f42520422
c5240000144321443518432184351d4421d4451f4421f4451f4521f4551d4421d44518432184351843218435164321643519432194351d4421d44522442224452545225455244422444520442204451f4421f445
c5240000204251143211435144321443518442184452044220445194421944516432164351943219435154321543511432114351643216435194421944524452244552543225435224422244520432204351f432
d52400000d1250d1350d1450d1550d1550d1550d1450d13505125051350514505155051550515505145051350a1250a1350a1450a1550a1550a1550a1450a1350f1340f1300f1300f1300f135061000610006100
d324000030014300123001230012300123001230012300122c0142c0122c0122c0122c0122c0122c0122c01229014290122901229012290122901229012290122e0142e0122e0122e0122e0152d0002d0002d000
c5240000294162541620416184161d41619416144160c4162b41627416224161f4161f4161b41616416134162b41627416244161f4161f4161b41618416134162c4262942624426204162b416274261843614436
3324000010b7000600006000060028a703f6153d60010b7010b7000600006000060028a703f615356003560010b7000600006000060028a703f6153560010b7010b70006000060010b7028a703f61510b7010b70
a124000001374013750d47501475084750d475014750147503374033750f475034750a4750f475034750347500374003750c47500475074750c4750047500475053740537511475054750c475114750547505475
c5240000294462543620426184161d41619426144360c4462b44627436224261f4161f4161b42616436134462b44627436244261f4161f4161b42618436134462c4462943624426204162b416274261843614446
c324000010b3000600006000060018a303f6003d60010b3010b4000600006000060019a3000000356003560010b400060000600006001aa403f6003560010b4010b50006000060010b501ba403f60010b6010b60
3124000000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0029724297322974229752
3124000030960307323196030960307322c96030960319603096030732307222e9602e7322e7222e7122e712309603196030960319603396033742337322c7512c9602c7322c7222c7122c9602b9602996027960
31240000299602b960299602c960359603396033732337222e9602c9602b9602b7322b7222b7122b7122b712249602596027960277322772227712299602475124960247322472224712309602e9602c9602b960
4524000030960307323196030960307322c96030960319603096030732307222e9602e7322e7222e7122e712309603196030960319603396033742337322c7512c9602c7322c7222c7122c9602b9602996027960
45240000299602b960299602c960359603396033732337222e9602c9602b9602b7322b7222b7122b7122b71224960259602796027732277222771229960247512496024732247222471224940247222471224712
a12400000d870013750d87501475088750d475018750147503870033750f875034750a8750f475038750347500870003750c87500475078750c4750087500475058700537511875054750c875114750587505475
7b2400003e6153f6003c6153f6003f6003f6003c6153f6003f6003f6003c6253f6003f6003f6003c6253f6003f6003f6003c6353f6003f6003f6003d6353f6003f6003f6003d6453f6003f6003f6003e6453f600
332400003f6253f6003e6453f6003f6003f6253e6453f6253f6003f6003e6453f6003f6003f6253e6453f6253f6253f6003e6453f6003f6003f6253e6453f6253f6003f6003e6453f6003f6003f6253e6453f625
35240000209501d930249531d930299531d930259531d930249501f930259531f930229531f930259531f930229501f930249531f930279531f930249531f93029950209302c953209302b953209302795320930
35240000209501d930249531d930299531d930299531d9302b9501f9302c9531f9302b9531f930279531f9302b9501f9302c9531f9302e9531f9302b9531f9302b950209302c9532093030953209302995320930
d524000000000209301d910249331d910299331d910259331d910249301f910259331f910229331f910259331f910229301f910249331f910279331f910249331f91029930209102c933209102b9332091027933
d524000020910209301d910249331d910299331d910299331d9102b9301f9102c9331f9102b9331f910279331f9102b9301f9102c9331f9102e9331f9102b9331f9102b930209102c93320910309332091029933
0124000020734207322073220732207322073220732207321d7341d7321d7321d7321d7321d7321d7321d7321f7341f7321f7321f7321f7321f7321f7321f7322073420732207322073220732207322073220732
312400002473424732247322473224732247322473224732257342573225732257322573225732257322573227734277322773227732277322773227732277322773427732277322773227732277322773227732
012400003075033700337002e75000000000002c7500000000000000000000000000000000000000000000003075000000000002e75000000000002c750000000000000000000000000000000000000000000000
9124000014040000002004000000140400000020040000000d0400000019040000000d0400000019040000000f040000001b040000000f040000001b040000001404000000200400000014040000002004000000
312400003074030720307102e7402e7202e7102c7402c7202c710000000000000000000000000000000000003074030720307102e7402e7202e7102c7402c7202c71000000000000000029724297322974229752
90240000140400000020040000001404000000200400000015040000002104000000160400000022040000000f040000001b040000000f040000001b04000000140400c000200000500005410054200543005440
0605000c166301864018630176401663015640166301864019630196401763016640196300b6400163001600126552e65501600226552a6550260002600016000060001600016000060001600026000160000000
0679010f016300164001630016400263000650126552e655036200163001620026300a650226552a65501600126552e65501600226552a6550260002600016000060001600016000060001600026000160000000
320400000202005030080400c05010050160501805003020080300d040140501a0501d050080100a0200b0200c0300e0301003013030170401b0401f040250502c05031050350503c0603c0503c0413c0313c021
000300001904314043100430b0430304315043110430b043050430a04305043030430004300003090030900309003090030900309003090030900309003090030900309003090030900309003090030900309003
22030000027510275102751027510475105751097510c7510f76114771187711b7711e771207712177121771207711f7711d7711a7711877115761127510f7510d7510b751087510775106751057510475103751
280400200705005051030310102101031000510005100051010310402105031070510a0510d05110031120211503117051180511805117031150211303111051100510e0510d0310b02109031070510605104051
000400003e06338655340552d64028045256532f0452b6432804326033226351e0531b64518043280352563322033206331a0351764316635220331c62516013116130e0130b6150701307015046100101501615
00020000360702d67025060206601c060186501605013650100500f6500d0500b6500904007640050400464003040026300163001630016300161001610016100161000610006100061000610006100061000610
00030020017400174101741027410374105741087410b7410e7411075112751137511475115751157511575115751157511475114751137511275111741107410d7410c7410a7410874105741037410174100741
000200003b56436561315512c5512855125551225511f5411d5411a541185411553113531115310f5210d5210c5210a5110951108511065110551104511045110351103511025110251102511015110151101511
00010000005540055100551005510055100551015510155102551045510555107551085510a5510c5510d5410f541115411354115541185411a5411d5311f5312253125531275312b5312f52133521395213d521
000400101073610731127311373114731167311773118731187311873117731157311373112731107310f7310d7310d7310d7310d7310f7311073112731137311473116731167311573114731137311173111731
000200000e0100901005010000100100001000000000000000000000000000000000000000000017000110000d00028000250001f0001b000160000d000070000300002000000000000000000000000000000000
000100000254002540025400454006540095400b5400e5401054012540145401555016550175501755017550165501555013550115500e5500c5400b540095400854007540065400554004540035400254002540
000200000c5401054014550195501e55022560265602a56016540185401b5501f5502256026560295602c5402e5401e540215502455026550295502b5502d5502f560315603456037560395603c5703e5703f570
000200000904108031090210c0210e0311203115041190411c04123051270510a0000d0010f00113001170010e0000900005000000002e000240011d00117001120010f0010c0010a00108001060010500105001
06ff00001363538665126051d605266052d6052e6052a6052d6052c6052b60529605226051a605136050d60507605036050060517605126050d60506605026050060501605016000060001600026000160000600
__music__
01 0c0d0e4b
00 0f100a4b
00 0809114b
00 1213110b
00 14151617
00 1d181a1c
00 1e1b1a19
00 1f191a1b
00 20191a1b
00 21191a1b
00 251c1a27
00 26191a28
00 25191a27
00 26191a28
00 6b2a294c
00 2b2a294c
00 2b2a2c29
00 2d042e6e
00 201a191b
00 06191a1b
00 20191a07
02 21191a07
01 0c0d0e4b
00 0f100a4b
00 0809114b
00 1213110b
00 14151617
00 1d182223
00 1e1b2224
00 1f1b2224
00 201b2224
00 211b2224
00 25272259
00 26282223
00 25272224
00 26282224
00 6b2a294c
00 2b2a294c
00 2b2a292c
00 2d04052e
00 201b2224
00 061b2224
00 20072224
02 21072224
03 304a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 494a4b4c
00 704a4b4c

