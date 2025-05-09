pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

menuitem(1, "music on/off", function() 
	music_object[3] = not music_object[3]
	if not music_object[3] then music(-1) else music(music_object[2]) end
 end)
menuitem(2, "sfxs on/off", function() sfx_enabled = not sfx_enabled end)
menuitem(3, "next lvl", next_room)
menuitem(4, "pass 5 lvls", function()
for i=1,5 do
	next_room()
end
end)

function _init()
	init_player()
	init_light()
	init_room()
	init_objects()
	camx = 0   
	camy = 0
	frames = 0
	room_transition_pending = false
	i_room = 1
	is_in_switch = false
	dflt_delay_switch = 3 --3 frames
	delay_switch = dflt_delay_switch
	sfx_timer = 0
	pulsator_state = false
	animation_timer = 0
	shake = 0
	music_object = {false, 0, true} 
	-- {bool = change music, value = music pattern, bool = music on/off}
	sfx_enabled = true
	game_state = 1 -- 0 = title, 1 = game, 2 = restart_level
	pulsator_room = 16
	music(0)
	--!! DEPLOIEMENT
	-- create_room()
	-- !! FIN DEPLOIEMENT
	--!! TEST
	tp = false
	next_room()
	--!! FIN TEST
end

function _update()
	if animation_timer > 0 then
		animation_timer -= 1
		return
	end
	if game_state == 1 then
		update_game()
	elseif game_state == 2 then
		restart_level()
	end
end

function update_game() 
	frames=((frames+1)%30)
	if sfx_timer > 0 then
		sfx_timer -= 1
	end
	--handle music
	if music_object[1] and music_object[3] then
		music_object[1] = false
		music(music_object[2])
	end

	update_chars()
	update_room()
	update_light()
	update_objects()
	camx = room.x
	camy = room.y
end

function _draw()
	cls()
	camera(camx, camy)
	-- screenshake
	if shake>0 then
		shake-=1
		if shake>0 then
			camera(-2+rnd(5)+camx,-2+rnd(5)+camy)
		end
	end

	map(0, 0, 0, 0, 128, 64, 0)
	draw_light()
	draw_objects()
	map(0, 0, 0, 0, 128, 64, 7)
	draw_walls()
	map(0, 0, 0, 0, 128, 64, 3)
	map(0, 0, 0, 0, 128, 64, 0x10)
	-- Doors
	draw_doors()
	draw_chars()
	foreach(butterflies, function(b)
		draw_butterfly(b)
	end)
	draw_acristals()
	draw_messages()
	-- draw outside of the screen for screenshake
	rectfill(-5+camx,-5+camy,-1+camx,133+camy,0)
	rectfill(-5+camx,-5+camy,133+camx,-1+camy,0)
	rectfill(-5+camx,128+camy,133+camx,133+camy,0)
	rectfill(128+camx,-5+camy,133+camx,133+camy,0)
	--DEBUG
	if btn(🅾️) and lulu.select then
		-- Dessiner la grid de la map
		-- for i=0,1 do
		-- 	for j=0,16 do
		-- 		if (i == 0) line(0, max(0,room.y + (j*8)),room.x + 128,max(0,room.y + (j*8)), 8)
		-- 		if (i == 1) line(max(0,room.x + (j*8)),0,max(0,room.x + (j*8)),room.y + 128,8)
		-- 	end
		-- end
		-- pset(ima_light.x,ima_light.y,11)
	end

	draw_ui()
	debug_print()
end

-->8
--player

function generate_character(name)
	return 
	{
		id = name,
		x = 0,
		y = 0,
		x_g = x,
		y_g = y,
		h = 8,
		w = 8,
		dx = 0,
		dy = 0,
		g = false,
		gravity = name == "lulu" and 0.18 or 0.11,
		is_jumping = false,
		default_sprite = name == "lulu" and 1 or 5,
		sprite = default_sprite,
		sprite_hide = name == "lulu" and 3 or 7,
		flipx = true,
		select = name == "lulu" and true or false,
		in_light = name == "lulu" and true or false,
		using_light = false, --to know if player is holding C key
		using_black_light = false,
		ima_range = 6 * 8, --range of ima_light for white and black light
		powers_left = 0,
		passed = false,
		shield = {
			timer = 0,
			time_set = 0,
			active = false,
			def_r = 16,
			r = 16
		},
		light_selected = --for hades
		{
			nil, -- id light
			0 -- index dynamique
		},
	}
end

function init_player()
	lulu = generate_character("lulu")
	hades = generate_character("hades")
	--globals to both
	pactual = lulu
	keys_owned = 0
	friction = 0.7
	accel = 1
	accel_air = 0.7
	jumping = 2.5
	max_dx = 2.2
	lulu_bl = false
	chars = { lulu, hades }
end

function draw_chars()
	--if they already in current room
	if game_state == 2 then
		if not lulu.in_light then 
			lulu.sprite = 16
		end
		if hades.in_light then hades.sprite = 17 end
	end
	foreach(chars, function(c)
		if game_state == 1 then
			if not (c.passed) then
				c.sprite = pactual == c and c.sprite or c.sprite_hide
			else c.sprite = 0
			end
		end
	end)
	if lulu_bl then
		pal(9,7)
		pal(4,6)
		pal(12,2)
	end
	spr(lulu.sprite, lulu.x, lulu.y, 1, 1, lulu.flipx)
	pal(9,9)
	pal(4,4)
	pal(12,12)
	if hades.sprite == hades.sprite_hide or hades.sprite == 17 then
		palt(0,false)
		palt(12,true)
	end
	spr(hades.sprite, hades.x, hades.y, 1, 1, hades.flipx)
	palt()
end

function update_chars()
	--delay when switching
	if is_in_switch then
		delay_switch -= 1
		if delay_switch <= 0 then
			is_in_switch = false
			delay_switch = dflt_delay_switch
		end
		return
	end
	--if they have finished the lvl
	if pactual.passed then
		switch_characters()
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
	end

	--switch characters
	if btnp(⬇️) and not btn(🅾️) then
		switch_characters()
		return
	end

	if not lulu.using_light and not hades.using_light then move_characters() end

	--if fall in water or lava

	if check_flag(1, pactual.x + 4, pactual.y) then
		game_state = 2
		sfx_timer = 45
		fsfx(53,3)
		return
	end

	-- COLLISIONS LIGHTS --
	----------------------
	for c in all(chars) do c.in_light = false end

	--dynamic lights
	for dl in all(dynamic_lights) do
		for c in all(chars) do
			if collision_light(c, dl) then
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


	for al in all(anti_lights) do
		for c in all(chars) do
			if collision_light(c, al) then
				c.in_light = false
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
			if collision_light(c, bl) then
				c.in_light = c == lulu and true or false
			end
		end
	end

	for b in all(butterflies) do
		for c in all(chars) do
			if collision_light(c, b) then
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
		if collision_light(hades, {x = lulu.x or 0, y = lulu.y or 0, r = lulu.shield.r - 4 or 0}) then
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
		if collision_light(lulu, {x = hades.x or 0, y = hades.y or 0, r = hades.shield.r or 0}) then
			lulu.in_light = true
		end
		if hades.shield.timer > hades.shield.time_set then
			disable_shield(hades)
		end
	end
	
	--grey lights at the end because priority max
	for gl in all(grey_lights) do
		for c in all(chars) do
			if collision_light(c, gl) then
				c.in_light = true
			end
		end
	end

		--CONDITIONS FOR LIGHTS
	if (not lulu.in_light and not lulu.passed) or (hades.in_light and not hades.passed) or pactual.y >= room.h-1 then
		animation_timer = 30
		game_state = 2
		sfx_timer = 45
		fsfx(53,3)
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
					fsfx(52,3)
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
		pactual.dy = pactual.dy * 0.33
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
		c.dy += c.gravity
		c.y += c.dy
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
		if not check_flag(0, pactual.x + 7, pactual.y + 6)
		and not check_flag(0, pactual.x + 7, pactual.y + 2) then
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
	if check_flag(0, pactual.x - 1, pactual.y + 7) then pactual.x += 1 end

	-- COLLISION PLAFOND
	if check_flag(0, pactual.x + 1, pactual.y + 1)
	or check_flag(0, pactual.x + 6, pactual.y + 1) then
		pactual.dy = 0
		pactual.y += 1
	end
end


function switch_characters()
	--switch characters
	if (pactual == lulu) then
		pactual = hades
		lulu.select = false
		reinit_characters()
		hades.select = true
	elseif (pactual == hades) then
		pactual = lulu
		lulu.select = true
		reinit_characters()
		hades.select = false
	end
end

function reinit_characters()
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
end

function update_light()
	-- lulu
		if btn(🅾️) then
			if lulu.select and lulu.powers_left > 0 then
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
		if lulu.using_light then fsfx(52,-2) end
		fsfx(55,-2)
		fsfx(58,-2)
	end
	update_dynamic_lights()
end

function update_light_lulu()
	if not lulu.using_light then
		--setting position of light
		ima_light.y = lulu.y_g
		ima_light.x = lulu.x_g
		lulu.using_light = true
		if lulu_bl then psfx(52,3) else psfx(58,3) end
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

	if btnp(❎) and lulu.select and lulu.powers_left > 0 then
		local x = ima_light.x
		local y = ima_light.y
		if not lulu_bl then 
			create_light(x, y, ima_light.r,"white",10) 
		else 
			create_light(x, y, ima_light.r,"black",10)
		end
		if lulu_bl then psfx(51) else psfx(57) end
		shake = 6
		lulu.powers_left -= 1
	end
end

function update_light_hades()
	-- hades a une variable qui stocke temporairement la light selected
	if #lights > 0 and hades.powers_left > 0 then
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
			hades.powers_left -= 1
			psfx(56,3)
			shake = 6
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
		psfx(51)
		pactual.using_black_light = false
		shake = 12
	end
end

function draw_light()
	draw_dynamic_lights()
	draw_lights()
	--disable possibility to player to draw ima lights
	if game_state != 1 then return end
	draw_imaginary_light()
	draw_hades_turnoff()
end

function draw_imaginary_light()
	if btn(🅾️) and lulu.select and lulu.powers_left > 0 then
		circfill(ima_light.x, ima_light.y, ima_light.r, ima_light.color)
		circ(ima_light.x, ima_light.y, ima_light.r, ima_light.color+1)
		circ(lulu.x_g, lulu.y_g, lulu.ima_range, 8)
	end
	if pactual.using_black_light then
		circfill(ima_light_bo.x, ima_light_bo.y, ima_light_bo.r, ima_light_bo.c)
		circ(ima_light_bo.x, ima_light_bo.y, ima_light_bo.r, ima_light_bo.c+1)
		circ(pactual.x_g, pactual.y_g, pactual.ima_range, 8)
	end
end

function draw_lights()
	--anti lights before
	foreach(
		anti_lights, function(al)
			circfill(al.x, al.y, al.r,0)
			circ(al.x, al.y, al.r, 7)
		end
	)
	--lights
	foreach(
		lights, function(l)
			circfill(l.x, l.y, l.r,l.color)
			circ(l.x, l.y, l.r, 6)
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

function draw_grey_lights()
	--grey lights
	foreach(
		grey_lights, function(gl)
			circfill(gl.x, gl.y, gl.r, 7)
			circ(gl.x, gl.y, gl.r, 5)
		end
	)
end

function draw_shields()
	foreach(chars, function(c)
		if c.shield.active then
			-- on interpole le rayon pour qu'il diminue avec le temps
			local ratio = 1 - c.shield.timer / c.shield.time_set
			local r = c.shield.r
	
			local color_circle = c == hades and 14 or 10
			if ratio < 0.15 then 
				if frames % 5 == 0 then
					color_circle = 0
				end
			elseif ratio < 0.25 then
				if frames % 10 == 0 then
					color_circle = 0
				end
			elseif ratio < 0.4 then
				if frames % 15 == 0 then
					color_circle = 0
				end
			end
	
			local cx = c.x + c.w / 2
			local cy = c.y + c.h / 2
			if c == hades then pal(14,3+128,1) end
			circfill(cx, cy, r, color_circle)
			circ(cx, cy, r, 7)
		end
	end)
end

function draw_hades_turnoff()
	if (hades.light_selected[1] != nil) and #lights > 0 then
		--check if selected light already exists
		local i = hades.light_selected[2] + 1
		local x = lights[i].x
		local y = lights[i].y
		local r = lights[i].r
		circfill(x, y, r, 8)
		circ(x, y, r, 8+1)
	end
end

function create_light(x, y, r, type, color)
	local new_light = {
		id = #lights,
		x = x,
		y = y,
		r = r,
		h = 32,
		w = 32,
		color = color or 9,
		type = type or "white"
	}

	if (type == "black") then
		add(black_lights, new_light)
	elseif (type == "grey") then
		add(grey_lights, new_light)
	elseif type == "anti" then
		add(anti_lights, new_light)
	else
		add(lights, new_light)
	end
end

-->8
--rooms
function init_room()
	room = new_room(0, 0, 0, 128, 128)

	-- DATAS MANUAL --
	------------------
	-- lights = { x, y, r, type(optional)}
	-- doors = { x, y }
	-- powers = { lulu (number), hades (number) }
	-- black_orbs = { x, y, r }
	-- shield_cristals = { x, y, timer (frames), r, lives, c (couleur)}
	-- chests = { { opened (boolean), locked (boolean), check_lock (boolean), content = { name (string), r (number)}, x, y } }
		-- pour les chests : si content.name = "turnoff" -> aucune autre data a insれたrer
		-- si content.name = "black_orb" -> content = { name, x, y, r }
	-- gates = { x, y, rotation (true = horizontal, nothing = vertical) }
	-- butterflies = { x, y, x1, y1, x2, y2, target (1 ou 2), speed (number), r (number), light (string = "white" ou "black"), spr_flip (boolean) }
	-- messages = { title (string), text (string) }
	-- p_data = {x, y, r_max, type (string = "white" ou "anti"), timer (frames), scale (float), spr_r (number), spd (float)}
	-- acristals = {x,y}
	rooms_data = {
		--1
		{
			lights = {{2,13,22},{11,14,16}},
			powers = {1,1},
			messages = {
				{"tutorial","welcome to lulu's quest!"},
				{"tutorial","hold 🅾️ and move to\n prepare a light"},
				{"tutorial","press ❎ when holding 🅾️\n to cast a light"},
				{"tutorial","lulu (left) can only live\n into lights"},
				{"tutorial","hades (right) can only\n live out of lights"},
				{"tutorial","press ⬇️ to switch characters"},
				{"tutorial","hades can turn off lights\n the same way as lulu"},
				{"tutorial","you got all powers left\n at top of the screen"}, 
				{"tutorial","the goal is to bring\n your characters..."}, 
				{"tutorial","...to their respective doors."}, 
				{"tutorial","good luck!"},
			}
		},
    --2
    {
        lights = {{19,13,20},{28,13,24}},
        powers = {1,1},
    },
    --3
    {
        lights = {{45,  9, 24},{37,  8, 16}},
        powers = {3,1},
    },
    --4
    {
        lights = {{52, 11, 18},{59, 10, 22}},
        powers = {2,2},
    },
    --5
    {
        lights = {{67, 10, 16},{72, 2, 24},{75, 10, 16},},
        powers = {2,1,},
    },
    --6
    {
        lights = {{84, 12, 24},{95, 13, 32},},
        powers = {2,2},
    },
    --7
    {
        lights = {{104, 3, 16},{111, 8, 24},{101, 8, 12},{106, 14, 24}},
        powers = {3,2},
    },
    --8
    {
        lights = {{115, 14, 16},{119, 14, 16},{124, 11, 16}},
        powers = {1,0},
        black_orbs = {{122,14,24}},
    },
    --9
    {
        lights = {{10,19,16},{5,23,16},{11,24,16}},
        powers = {1,1},
        black_orbs = {{8,23,32}},
    },
    --10
    {
        lights = {{24, 17, 16},{17, 19, 20},{21, 20, 16},{29, 22, 28},{21, 23, 16},{23, 28, 24}},
        powers = {4,7},
        chests = {
            {false,true,false,{"black_orb",27,30,36,},28,30,}},
    },
    --11
    {
        lights = {{37, 19, 16},{37, 23, 16},{46, 26, 12}},
        powers = {2,1,},
        black_orbs = {{33, 19, 32}},
    },
    --12
    {
        lights = {{51, 19, 16},{56, 28,  8}},
        powers = {1,0},
        shield_cristals = {{54, 19, 4, 12}},
    },
    --13
    {
        lights = {{67, 18, 16},{72, 22,  8},{70, 24,  8},{74, 24,  8},{72, 26,  8},{72, 28,  8},{72, 30,  8},{79, 30,  8}},
        powers = {2,1,},
        shield_cristals = {{70,17, 8,16,1},{67,21,10,16,2},{64,30,12,24,1}},
        chests = {{false,true,false,{ "turnoff" },74,21}},
    },
    --14
    {
        lights = {{84, 29, 16}},
        powers = {0,0},
        shield_cristals = {{88,18,60,32,1,"red"}},
        butterflies = {{86,17,86,17,85, 27,2, 0.5,24,"white",false,}}
    },
    --15
    {
        lights = {{103, 17, 16}},
        powers = {1,0},
        shield_cristals = {{101,17,10,10,1},{100,28,10,10,1},{106,17,10,10,1}},
        butterflies = {
            { 97,30, 97,30, 97,16, 2, 1,12,"white", true},
            { 99,28, 99,28,107,28, 2, 1,12,"white", true},
            {103,19, 99,19,109,19, 2,0.5,18,"black", true},
            { 98,23, 98,23,108,23, 2,0.5,24,"black", true},
        },
    },
    --16 HEART
    {
			lights = {{125, 18, 12}},
			powers = {1,1},
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
			acristals = {{112,20},{127,22}},
			p_data = {117,30,128,"white",0},
    },
    --17
    {
			lvl_timer = 75,
			lights = {{6.5, 40, 24, "black"},},
			powers = {2,0},
			butterflies = {
				{4,34, 4,34,9,34, 2,0.6, 16,"anti", false},
				{2,41, 2,41,2,50, 2,0.6, 8,"anti", false},
				{5,34, 5,34, 19, 34, 1, 1,16,"white", true},
			},
			acristals = {{7,46},{14,40}},
			p_data = {14,46,256,"white",180},
	},
	--18
	{
		lights = {{25,33,8},{30,43,16,"black"}},
		powers = {2,0},
		butterflies = {{23,46,23,46,31,46,2,0.6,12,"white",true},},
		chests = {{false, true, false, {"white_orb"},16,37}},
		acristals = {{29,35},{19,43}},
		p_data = {21,36,46,"white",180,2,16,1}
	},
	--19
	{
		lights = {
			{34,33,8},
			{36,36,8,"anti"},
			{45,33,12,"black"},
			{40,39,10,"grey"},
			{40,43,10},
			{46,43,10},
			{46,45,10,"black"},
			{41,46,10},
			{36,46,10},
			{34,46,12,"black"},
		},
		powers = {0,0},
		messages = {{"hint","white lights takes priority\n over every lights"}},
		shield_cristals = {{45,40,12,26,1}},
		butterflies = {
			{25,43,29,43,47,43,1,0.2,10,"black",false},
			{25,46,29,46,47,46,1,0.2,10,"black",false},
		},
		p_data = {37,29,128,"white",180,4,16,5}
	},
	--lvl 20
	{
		lights = {
			{57,34,8},
			{50,34,12},
			{57.5,36,8,"anti"},
			{55.5,41.5,12,"grey"},
		},
		powers = {1,0},
		shield_cristals = {{53,39,60,20,1},{48,45,12,12,1}},
		butterflies = {{53,44,53,44,62,44,2,0.5,10,"anti",true}},
		acristals = {{51,46},{60,46}},
		p_data = {53,45,128,"white",0,4,20,2}
	},
	--21
	{
		lights = {
			{73,35,12},
			{66,42,16,"black"},
			{79,40,8},
			{79,38,8},
			{77,42,12,"grey"},
			{71,39,16,"grey"},
		},
		powers = {3,1},
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
		x = 128 * 7
		y = 128 * 0
	end
	-- !!END TEST
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
	fsfx(61,3)
	if i_room >= pulsator_room + 1 and music_object[2] != 27 then
		music_object[2] = 27
		reset_music()
		fsfx(48, -2)
	end
	-- !!  TEST !!
	keys_owned = 2
end

function reset_music()
	music_object[1] = true
end

function create_room()
	-- set pulsator state on
	-- and put pulsator object into global pulsator object
	if i_room >= pulsator_room and not pulsator_state then
		pulsator_state = true
		add(pulsator, rooms_data[16].pulsator)
	end

	delete_objects()
	create_objects()
	--characters
	local room = rooms_data[i_room]
	local i = 1
	foreach(chars, function(c) 
		c.passed = false
		c.in_light = c == lulu and true or false
		disable_shield(c)
		-- c.x = room.pos[i][1] * 8
		-- c.y = room.pos[i][2] * 8
		i += 1
	end)
	--powers
	lulu.powers_left = room.powers[1]
	hades.powers_left = room.powers[2]
	door_sound_played = false
	--replay pulsator sfx (with music fct) if lvl 15 reached
	if i_room == pulsator_room then
		music(-1)
		fsfx(48,0)
	end
end

function new_room(id, x, y, w, h)
	return {
		id = id,
		x = x,
		y = y,
		w = w,
		h = h,
		pos = {hades = {-1,-1}, lulu = {-1,-1}}
	}
end

function index_room(x, y)
	return (flr(x / 128) + flr(y / 128) * 8) + 1
end

function restart_level()
	create_room()
	reinit_characters()
	is_in_switch = true
	delay_switch = 10
	game_state = 1
end

-->8
--objects

function init_objects()
	-- coordonnれたes pour lvl 1, a update れき chaque changement de room
	doors = {
		lulu = {x = 0, y = 0},
		hades = {x = 0, y = 0}
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
	messages = {}
	pulsator = {}
	dynamic_lights = {}
	acristals = {}
	walls = {}
	grey_lights = {}
	anti_lights = {}
	mushroom = {}
end

function update_objects()
	-- When someone enter its door, passed will be turn on and character will disappear
	if not pactual.passed and collision(pactual, pactual == lulu and doors.lulu or doors.hades) then
		pactual.passed = true
		delay_switch = 10
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
		if not k.collected and collision(pactual,k) then
			psfx(60)
			keys_owned += 1
			k.collected = true
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
					c.shield.def_r = sc.r
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
				mset(g.x/8, g.y/8, g.tile+1)
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

	--mushroom
	if mushroom[1] and collision(lulu, mushroom[1]) then
		local m = mushroom[1]
		lulu_bl = true
		sfx_timer = 30
		music(-1)
		fsfx(59,3)
		del(mushroom, m)
		mset(m.x/8, m.y/8, 0)
		ima_light.color = 13
		animation_timer = 75
		reset_music()
	end
end

--animations
function draw_objects()
	--black orbs
	foreach(
		black_orbs, function(bo)
			spr(22, bo.x, bo.y, 1, 1, false, false)
			if frames > 20 then
				spr(23, bo.x, bo.y, 1, 1, false, false)
			end
		end)
	--butterflies
	foreach(butterflies, function(b)
		draw_butterfly_light(b)
	end)
	--shields
	draw_shields()
	--grey lights
	draw_grey_lights()
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
	--acristals and walls are in _draw()
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
		anti_lights,
		chests,
		keys,
		gates,
		shield_cristals,
		butterflies,
		messages,
		dynamic_lights,
		acristals,
		walls,
		grey_lights
	}
	local lists_to_reset = {
		walls,
		gates,
		keys
	}

	--if level restart, then restore them on the map before destroy
		for _, tbl in ipairs(lists_to_reset) do
			for obj in all(tbl) do
				mset(obj.x/8, obj.y/8, obj.tile)
			end
		end
		for _,p in pairs(room.pos) do
			mset(p[1], p[2], p[3])
		end
		
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
	local c_room = rooms_data[i_room]
	--create lights from new room
	for l in all(c_room.lights) do
		create_light(l[1] * 8, l[2] * 8, l[3], l[4], l[5])
	end
	--black orb
	for bo in all(c_room.black_orbs) do
		create_black_orb(bo[1] * 8, bo[2] * 8, bo[3]) 
	end
	--chests
	for c in all(c_room.chests) do
		add(chests, {opened = c[1],locked = c[2],check_lock = c[3],content = c[4],x = c[5] * 8,y = c[6] * 8})
	end
	--keys
	-- for k in all(c_room.keys) do
	-- 	add(keys, {x = k[1] * 8, y = k[2] * 8, style = k[3]})
	-- end
	--shield cristals
	foreach(c_room.shield_cristals, function(sc)
		add(shield_cristals, {x = sc[1] * 8, y = sc[2] * 8, timer = sc[3], r = sc[4], lives = sc[5], c = sc[6]})
	end)
	--butterflies
	foreach(c_room.butterflies, function(b)
		local bf = {x = b[1] * 8, y = b[2] * 8, x1 = b[3] * 8, y1 = b[4] * 8, x2 = b[5] * 8, y2 = b[6] * 8, target = b[7], speed = b[8], r = b[9], light = b[10]}
		add(butterflies, bf)
		if b[10] == "grey" then
			add(grey_lights, bf)
		end
	end)
	--messages
	foreach(c_room.messages, function(m)
		add(messages, m)
	end)

	-- set dynamics data to pulsator
	if pulsator[1] and c_room.p_data then
		local p = c_room.p_data
		pulsator[1].x = p[1] * 8
		pulsator[1].y = p[2] * 8
		pulsator[1].light_data.r_max = p[3]
		pulsator[1].light_data.type = p[4]
		pulsator[1].timer = p[5]
		pulsator[1].light_data.ac_activated = p[6] or 0
		pulsator[1].is_broken = false
		pulsator[1].spr_r = p[7] or 24
		pulsator[1].light_data.spd = p[8] or 1
	else
		pulsator_state = false
	end

	--acristals
	foreach(c_room.acristals, function(ac)
		add(acristals, {x = ac[1] * 8, y = ac[2] * 8, active = false, c_col = nil})
	end)

	--define walls, gates and doors
	for i=0,15 do
		for j=0,15 do
			local x = room.x > 0 and (room.x / 8 + i) or i
			local y = room.y > 0 and (room.y / 8 + j) or j
			local t = mget(x, y)
			--breaking walls
			if fget(t, 3) then
				add(walls, {x = x * 8, y = y * 8, broken = false, tile = t, break_anim = 0})
			end
			--gates
			if t == 52 or t == 26 then
				add(gates, {x = x * 8, y = y * 8, tile = t, opened = false})
			end
			--doors
			if t == 35 then
				doors["lulu"] = {x = x * 8, y = y * 8}
			elseif t == 51 then
				doors["hades"] = {x = x * 8, y = y * 8}
			end
			--chars
			if t == 1 then
				room.pos.lulu = {x, y, 1}
				chars[1].x = x * 8
				chars[1].y = y * 8
				mset(x, y, 0)
			elseif t == 5 then
				room.pos.hades = {x, y, 5}
				chars[2].x = x * 8
				chars[2].y = y * 8
				mset(x, y, 0)
			end
			--keys
			if t == 25 or t == 41 then
				add(keys, {x=x * 8, y=y * 8, style = t == 25 and "door" or "chest", tile = t, collected = false})
				mset(x, y, 0)
			end
			if t == 18 and not mushroom[1] then 
				add(mushroom, {x=x * 8, y=y * 8, tile = t})
			end
		end
	end
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
	if blight == "black" then pal(14,3+128,1) end
	local light_c = blight == "white" and 9 or blight == "black" and 14 or blight == "grey" and 7 or 0
	local circ_c = blight == "white" and 6 or blight == "black" and 13 or blight == "grey" and 5 or 6
	circfill(b.x, b.y, b.r, light_c)
	circ(b.x, b.y, b.r, circ_c)
end

-->8
--chests

function open_chest(c)
	sfx_timer = 20
	fsfx(49,3)
	c.opened = true
	--crれたer le contenu du coffre au-dessus
	content = c.content[1]
	if content == "black_orb" then
		create_black_orb(c.content[2] * 8, c.content[3] * 8, c.content[4])
	elseif content == "turnoff" then
		hades.powers_left += 1
	elseif content == "white_orb" then
		lulu.powers_left += 1
	end
end
-->8
--keys

function draw_keys(k)
	if k.collected then return end
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
	if not pulsator_state then return end
	-- osciller uniquement si pulse_timer actif
	local pulse_ratio = pulsator[1].pulse_timer / pulsator[1].pulse_dur
	local scale = pulsator[1].spr_r / 10  - (pulsator[1].light_data.ac_activated * 0.2) + 0.5 * pulse_ratio -- grossit れき chaque battement
	-- flips
	local flipx = frames % 15 < 7
	local flipy = frames % 30 < 15

	-- palette dynamique
	if frames % 30 < 10 then
		pal(12,9)
	elseif frames % 30 < 20 then
		pal(12,7)
	else
		pal(14,3+128,1)
		pal(12,14)
		pal(14,14)
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
		local r1 = (pulsator[1].spr_r * 2 + rnd(5)) * scale * 0.6
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
	if ((lulu.using_light or hades.using_light) and i_room > pulsator_room) or not pulsator_state then return end
	if pulsator[1] then
		--Aprれそs chaque pulsation, on rejoue le SFX electrical effects
		-- if pulsator[1].timer == 30 and i_room == 15 then sfx(47, 0, 0, 14) end

		--A less before the next pulsation, prevent the player
		local beat_delay = pulsator[1].beat_delay - pulsator[1].light_data.ac_activated * 25
		-- if pulsator[1].timer == beat_delay - 30 and i_room == 15 then sfx(47, 0, pulsator[1].light_data.type == "white" and 16 or 19, 1) end

		pulsator[1].timer += 1
		if pulsator[1].timer >= beat_delay then
			-- un battement se produit
			pulsator[1].pulse_timer = pulsator[1].pulse_dur -- dれたclenche une pulsation visuelle
			shake = 10
			pulsator[1].timer = 0
			-- SFX
			if sfx_timer == 0 and i_room != pulsator_room then
				fsfx(48, -1)
				sfx_timer = 30
				fsfx(48, 3, pulsator[1].light_data.type == "white" and 7 or 14, 1)
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
		-- timer of pulsator reset to 0
		pulsator[1].timer = 0
		-- wait 1 sec
		animation_timer = 60
		-- screenshake
		shake = 60
		-- wait 0.5 sec and delete acristals
		pulsator[1].is_broken = true
		fsfx(47, -2)
		sfx_timer = 120
		fsfx(63)
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
				fsfx(47,-2)
			end
		end
	end
	--check if all acristals are activated
	if pulsator[1] and #acristals > 0 then
		for ac in all(pulsator[1].light_data.room_ac) do
			if not ac then return end
		end
		--if we reach this, then all acristals are activated
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
	if (lulu.using_light or hades.using_light) and i_room > pulsator_room then return end
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
		circ(dl.x, dl.y, dl.r, c+1)
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
	local x = room.x + 12
	local ly = room.y + 4
	local hy = room.y + 12
	local ky = room.y + 20
	palt(0, false)
	palt(12, true)
	--# lights
	if lulu.powers_left > 0 then
		local lspr = lulu_bl and 19 or 49
		spr(lspr, room.x + 4, ly)
		palt(0, false)
		print("X"..lulu.powers_left, x-1, ly, 0)
		print("X"..lulu.powers_left, x+1, ly, 0)
		print("X"..lulu.powers_left, x, ly-1, 0)
		print("X"..lulu.powers_left, x, ly+1, 0)
		-- palt(0, true)
		print("X"..lulu.powers_left, x, ly, 11)
	end
	-- for i = 1, lulu.powers_left do
	-- 	spr(49, x + i * 8, y + 4)
	-- end
	--# turnoffs
	if hades.powers_left > 0 then
		spr(50, room.x + 4, hy)
		-- palt(0, false)
		print("X"..hades.powers_left, x-1, hy, 0)
		print("X"..hades.powers_left, x+1, hy, 0)
		print("X"..hades.powers_left, x, hy-1, 0)
		print("X"..hades.powers_left, x, hy+1, 0)
		print("X"..hades.powers_left, x, hy, 11)
	end
	-- for i = 1, hades.powers_left do
		-- 	spr(50, x + 120 - i * 8, y + 4)
		-- end
		--# keys
		if keys_owned > 0 then
		spr(57, room.x + 4, ky)
		print("X"..keys_owned, x-1, ky, 0)
		print("X"..keys_owned, x+1, ky, 0)
		print("X"..keys_owned, x, ky-1, 0)
		print("X"..keys_owned, x, ky+1, 0)
		print("X"..keys_owned, x, ky,11)
	end
	palt()
end

-->8
--helper functions

function debug_print()
	print("lvl: "..i_room, room.x+40,room.y+2,8)
	-- print("dsw:"..delay_switch)
	-- print(is_in_switch and "true" or "false")
	-- print("qui?"..pactual.id)
	-- print("atime:"..animation_timer)
	-- print("gs"..game_state)
	-- print("keys: "..keys_owned)
	-- for k,v in pairs(room.pos) do
	-- 	print(k..".x: "..v.x)
	-- 	print(k..".y: "..v.y)
	-- 	print(k..".t: "..v.t)
	-- end
	-- print("room.pos.lulu.x: "..room.pos.lulu.x)
	-- print("room.pos.lulu.y: "..room.pos.lulu.y)
	-- print("room.pos.lulu.t: "..room.pos.lulu.t)
	-- if pulsator[1] then
	-- 	print(pulsator[1].light_data.room_ac[1] and "true" or "false")
	-- 	print(pulsator[1].light_data.room_ac[2] and "true" or "false")
	-- 	print(pulsator[1].light_data.ac_activated)
	-- end
	-- print("room.x: "..room.x)
	-- print("room.y: "..room.y)
	-- if walls[1] and walls[2] then
	-- 	print(walls[1].broken and "true" or "false")
	-- 	print(walls[2].broken and "true" or "false")
	-- end
	-- print(shake)
	-- print(animation_timer)
	-- print(#pulsator)
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
	-- 	if collision_light(pactual, bl) then
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
	local gx1 = g.x - 2
	local gy1 = g.y - 2
	local gx2 = g.x + 10
	local gy2 = g.y + 10
	return not (px1 > gx2
				or py1 > gy2
				or px2 < gx1
				or py2 < gy1)
end

function fsfx(id, c, o, l)
	if sfx_enabled then
		sfx(id, c, o, l)
	end
end

function psfx(num)
	if sfx_timer <= 0 then
		fsfx(num,3)
	end
end

function lerp(a,b,t)
	return a+(b-a)*t
end

__gfx__
00000000088888800888888001111110088888800222222002222220c111111c0222222000000000000000000000000000000000000011111111000000000000
00000000888888888888888811111111888888882222222222222222111111112222222200000000000000000000000000000000011111111111111000000000
000000008899999888999998114444418899999822222f2222222f2211111d1122222f2200000000008008000050050000000001111c15555551111110000000
00000000899ff9f9899ff9f9144dd4d4899ff9f90229ff920229ff92c113dd310229ff9200000000000880000005500000000011115ccc555555551111000000
0000000089fc9fc989fc9fc914d14d1489fc9fc9022ffff2022ffff2c11dddd1022ffff20000000000088000000550000000011155555ccdd5555cc511100000
00000000089fff90089fff90014ddd40089fff900121d1020121d102c01050c10121d1020000000000800800005005000000111c55ddddcccddd5c5551110000
000000000088880000888800001111000088880001dddd0010dddd00c05555cc01dddd000000000000000000000000000001115ccdddddddcddddcdd55111000
00000000004004000004500000500500040000400140040010045000c02cc2cc040000400000000000000000000000000011155dcdddddddcddddcddd5511100
08888880c888888c00033000ccc0cccc0000000000000000000000000000000000000000000000004444444440000004001155ddccddddddccddccdddd551100
888888888888888800333300cc030ccc0000c0000000800000000000000000000004000000040000454545455000000501115ddddccddddddcccccddddd51110
888888888888888803a33330c03630cc000c7c000008780000000000000000000004000000464000454545455000000501155dddddcddddddddddcddddd55110
88888888c889889833333a330366630c0000c0000000800000088000000880000004000000040000444444444000000401155dddddcddddddddddcddddd55110
88898898c888888800044000c03630cc0000100000002000008838000088b800000400000004000000000000000000001115ddddddcddd11111dccdddddd5111
08888880c88888c800044000cc030ccc00001000000020000838888008b88880000400000004400000000000000000001155ddddddcdd1111111ccdddddd5511
00888800c88888cc00044000ccc0cccc00001000000020000004400000044000000400000004000000000000000000001155ddddddcd111111111cddddddd511
00800800c88cc8cc00044000cccccccc00001000000020000004400000044000000000000000000000000000000000001155ddddddc1111111111cddddddd511
6666666607070a00070700000005500008800880000000000000000000000000000000000000000000000000000000001155dddddcc111111111ccddddddd511
6555555600444a4000444a400055550088888888000000000000000000000000000a0000000a0000000000000880000011555dddccdcc1111111c1dddddd5511
655555560000000000000a000558855088888888080800000007000000080000000a000000a9a000888888880088888011555dddcdd1ccccc111c1ddddddcc11
6555555600000000000000005588885588888788888880000076700000828000000a0000000a0000888888880008888011155dddcddd1111c111ccccccccc111
655555560000000000000000588998858888778888888000076a6700082a2800000a0000000a0000848888880000880001155dddcdddd111cc11cddddd555110
6555555600000000000000005899998508888880088800000076700000828000000a0000000aa000888888880000000001155dddcccddd111c1cdddddd555110
6555555600000000000000005899798500888800008000000007000000080000000a0000000a00008888884800600000011155ddcdccdddddccccddddd551110
666666660000000000000000589779850008800000000000000000000000000000000000000000008888888860660606001155cccddccdddddddcdddd5551100
66666666ccc0ccccccc8cccc0005500000444400004554000000000000000000000aa000ccc0cccc8888888888888888001115c555ddcdddddddccd555511100
65565556cc0a0ccccc808ccc005555000045540000000000000000000999999004444440cc0a0ccc8888888888888888000111cc55ddcccddddddcc555111000
65665556c0a7a0ccc80008cc055dd5500044440000000000000b00009974449946665554c0a6a0cc8884888888888888000011c555555dccddddddcc51110000
666556660a777a0c8000008c55dddd55004554000000000000b3b0009744444946655554cc0a0ccc8888888888888888000001115555555cc555555511100000
65565656c0a7a0ccc80008cc5dd22dd500444400000000000b3a3b009999999997444449cc0a0ccc88888888888888880000001111555555c555551111000000
65566556cc0a0ccccc808ccc5d2222d5004554000000000000b3b000974aa44997444449cc0aa0cc88888888888888880000000111111555cc51111110000000
65556556ccc0ccccccc8cccc5d2272d50044440000000000000b00009744444997444449cc0a0ccc888888488888888800000000011111111c11111000000000
66666666cccccccccccccccc5d2772d50045540000455400000000009999999999999999ccc0cccc888888888888888800000000000011111111000000000000
000001111110000000000011eeeeeeee000111000000000000111000055555500555555555505505555555500555555099099099505555055055055566666666
000011111111000000000011eeeeeeee001111100000010001111100555555555555555555555555555555555555555590000009555655555555555566666666
000111111111100000000011eeeeeeee011111111111111101111110555665555555556655555555565665555556655500000000655666665655655566666666
001111111111110000000011eeeeeeee111111111111111111111111556666555555566665566566666665555556665590000009666666666665665666666666
011111111111111000000011eeeeeeee111111111111111111111111556665555556666666666666666666555566655590000009666666666666666666666666
111111111111111100000111eeeeeeee011111101111111111111110555655555556666666666666666666555566665500000000666666666666666666666666
111111111111111100000011eeeeeeee00111110010000000111110055555555555666dd66666666666666655556655590000009666666666666666666666666
111111111111111100000011eeeeeeee00011100000000000011100005555550555666dd66666666d66666555556665599099099666666666666666666666666
1111111111111111110000000001100000000000d6666555555566660555555055566666666666666666655555566655aa0aa0aa055555005005555066666666
111111111111111111100000001111000000000066655550055566665567665555556666666666666666555555666665a000000a555555555555555566666666
11111111111111111100000001111110000000006665550000555666567766650556666666666666666665505556655500000000555555555566555566d66666
011111111111111011000000111111110000000066555000000555565776667555566666666666666666655555666655a000000a555666556666655566666d66
001111111111110011000000111111110000000055550000000055565677777555556666666666666666555556666555a000000a556666666666655566666666
000111111111100011000000111111110000000055500000000005555667666505556666666666666666655055566665000000000566dd666666655566666666
000011111111000011000000011111100000000055000000000000555567665555566666666666666666555555666555a000000a0556dd666d66555066d666d6
000001111110000011000000000111000000000050000000000000050555555055566666666666666666655555566655aa0aa0aa555666666666555066666666
11111111111111110000000000111100111111115000000000000005000000005566666d66666666dd66665555666555bb0bb0bb055566666666655500000000
11111110111111110000000001111100111111115500000000000055000000005556666666666666dd66665555566555b000000b055566d666dd655000000000
111110000011111100111000001111001111111155500000000005550000000055666666666666666666655555666655000000005556666666dd665000055000
111100000001111100111100001111001111111165550000000055550000000055566666665666666666555555566655b000000b555666666666665500555500
111100000000011101111100001111001111111165555000000555660000000055566666665666656666555555666555b000000b555666665566655505555550
11100000000000110111111000111110111111116665550000555666000000005555665655555555656555555556655500000000555566555555555500022000
110000000000001111111111001111001111111166665550055556660000000055555555555555555555555555555555b000000b555555555555555500022000
1100000000000001111111110011110011111111666655555556666d0000000005555555505505555555555005555550bb0bb0bb055550050055555000022000
10000000000000111111111100111100000000000555555555555555555555500555555555555555555555500555555000000000000000000000000000000000
11000000000000111111111101111110000000005555555555565555555555555555555555555555555555555567665500000050000000000000000000000000
11000000000001110111111011111111000000005556565656566565556655555556665555555555566665555677066555500565000000000000000000000000
11100000000011110011111011111111000000005566666666666666666666555566666556555566666666555770067550050005000000000000000000000000
11111000000011110011110011111111000000005566666666666666666666555566666666555565566666555600007550000075500000750000000000000000
11111100000111110001110001111110000000005555665566666666656565555556666555555555556665555660666556005065565550650000000000500050
11111111011111110000000000111100000000005555555565666565555555555555555555555555555555555567665556600655565005555050000505550555
11111111111111110000000000011000000000000555555555555555555555500555555555555555555555500555555055656655556565665555550500400040
9696969696f5959596959596969696f5000000020050000000100200000000910200000000020000000000000000500202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
54740616469695a654d6a65437545485000200000075000000020200000002020200100000020000000000000002020202000000000000021000000000753202
02000000000002000000020000000202020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
910507174615b5000000242500009185000202020275000000000002000000000202020000020000000000000000000202910200020000020200000000750002
00000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
946767677700b57400002425876797f5000000027575757500000000020000000200020000020000000000000000000202020002000000020200020275750202
50000000000000000000000000000000020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a55454545454b57474000414000000850275027575757575757400000002000002000000000000000000000000000002027575000000020000000000757502a3
02020202020200000202020202020000020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50024d56767976767e50515000000850000027575757400000075000002020002000000000000000000000000000002023375000002000000000000750202a3
02020000000000000000020202020000020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50057e60415b50514b6041400007485020202000000a0b0b0b00000740200000200000000000091000000000000000202007500000000000000000002020202
02020000000000000000000202020000020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50000041500b6000514051500876795000000000000a00000a00000000000020200000000000002020000000000000202747550004100000000000000000002
0200000000000021000000000202c4c4020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
95770415000075000005144700430085000000000074a0a0a0a075000000000002000000000002020202000000000002020202a1020200000002020202020202
c6c6c60000000202020000000202c4c4020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a50415000010755000b4051426576796000202000000750000750000750202020200000202020202020202020202020202020000000200000002000000009102
0010c600000202020202000000c43233020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a51500576767976797e6240574002736004300020000000000000002020232330200000000430000000000000000000202000002000200020002000200000202
0000c600020202020202020000c40000020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
957700000515b5333275247416070037020200000200000000000075754300000202000000020000000002000000000200000002004300000000000200000202
02020202020202020202020202020202020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a500b4002425b5000075740000160700000202020202020000020202020202020202020202020202020202020200000200000202020202020202020200020202
02020202020202020202020202020202020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
a554b5b42425869794a400002600160700000000000000000002000000000000023233000000000000000000000200024100000000a000000000a0000002a3a3
02020202020202020202020202020202020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
9500b5b50414430086a600353600001691000000000000750000000000000092020000020000000002000000000000020200000000a000000000a0000002a302
02020202020202020202020202020202020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
95f595f5e4e4e4e4a40000363626000002020202020202020202020202020202020202020202020202020202020202020202020202a000000000a0020202a302
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
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000c4c4c4c40000000000000002
02000000c4c4c400000000000000000202000000c4c4c4c400000000000000020200000000000000000000000000000200420000420042004200004200420000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000c40000c40000000000000002
02000000c400c4c4000000000000000202000000c40000c4c4000000000000020200000000c4c4c4c40000000000000200420000420042004200004200420000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000c4c4c4c40000000000000002
02000000c40000c4000000000000000202000000c40000c4c4000000000000020200000000c40000c40000000000000200424200424242004242004242420000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000c40000c4c400000000000002
02000000c4c4c4c4000000000000000202000000c4c4c4c400000000000000020200000000c4c4c4c40000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000c4000000c400000000000002
02000000c40000c4c40000000000000202000000c40000c4c4000000000000020200000000c400c4c40000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000c4c4c4c4c400000000000002
02000000c4c4c4c4c40000000000000202000000c4000000c4000000000000020200000000c4c4c4c40000000000000200a3000000000000a3a300a3a300a3a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
0200000000000000000000000000000202000000c4c4c4c4c40000000000000202000000000000000000000000000002a300a300a300a300a3a300a3000000a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002a300a300a300a300a3000000a30000a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200a3a30000a30000a3a300a3a30000a3
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000
__gff__
0000000000000000000001020202020200009000000000000000919002020202818080000000808000000200020202028500000091908004000002010202020280808080808080010101010100010101808080808001018901010101000101018080808080010100010101010001018080808080800101010101018080808000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
565959595a6859655669595959595f595959595f5959595965665959595969695f594f4f69695959596969694f4f4f4f59655659595959595558595a585955564f4f696969696969696969694f4f4f4f595959593a59595959595959593a5959595f593a3a5a00000058593a3a5959595f5959595959595959593a5959593a59
665556595f4a58596547685959595959565959595969695959595f595955006f594f4f5500005659556300006d4f4f4f595965565959595a006d696a585f65664f5a00004252234064606133584f5556585f59593a3a3a3a5959593a3a3a59593a3a3a3a3a5a00000068593a3a3a3a593a3a3a59595955565f593a5959593a59
59656659595a5859596547685959596e005859696a425268596959595a6262484f4f6a000000005b0063004064684f4f59595965566959596547474758595a595f5a00004252006464707100585f6566595959595959593a3a3a3a3a59595959595f59593a5a01620000585f3a3a3a3a59593a3a5959656659593a3a59593a59
58595959595a585f5959654758596e6600586a52004252616b6358596a6464584f5572000053006b0073406464646d4f565959596500564f5949494959595a48696a006f425247506464647869595f5959555659595959595959593a3a3a3a595f593a593a59494a700068696969593a5959593a59595f5959593a3a3a3a3a59
58595959595a5859595f5965566a6659006b4252004041000063585a606148695a000000006300720000506464606158665f5959596562565f59595959595a586451004742520000614751006356595f59656659695969595959696959593a59593a3a593a3a3a5a61700000006368595959593a3a59593a3a3a3a593a595959
5959595f595a58595959594f6566595900004252006160000063585a70716b005a41000000630000404100506470715859595959595949655659595959595a58510000007170006f47720000630056596859595a005b4268595a000058593a3a593a3a3a3a3a3a5a0561700000630058595959593a3a3a3a595959593a3a5959
59595959596e585959595959595f595900004252000000000073586a505100005a51000000637f40645100006164645859695969695959596556695959696a68000000005051004700000000730000680058695a006b4041685a000068695959593a5f596969697679767700006300583a3a3a3a3a59595959595959593a3a3a
5f5959596e00565959686969695959596f0540410000000000006b00000000005a6200000063487a51000000006164585a006b6464686969697a63586a520000000000004b6200000073000000004051005b006b00005051006b000063006859593a596a00626f4252007200007300585959595959596959695959595f595959
6869596e004041565a007164646d595949494a510000000000000000000000005a47000000486a5100006f53000050586a000050646061645100636b4252002370000000584a00000063000000405100006b7000000000000063000063000058593a5a00007576797676494a005300585f5969595955005b5158596969696959
00005b00005051005b71606164516d6969595a000000000000000000000000335a230000405b510000004b6300003358337000005070715100007300424746006470000068697a00006300004051000000006170000000000063006f7300005b593a5a00006300404100586a00630058596a73565500406b716d6e5100003358
00006b00004252005b6170715100720063685a41000000000000006200006f005a000540486a00000000684a0001005800647001006160006f0053004252054b6464700100007f62006300405105717000000072620000000063004b0000335b5f3a597f0063005051006b52006300585a007300007160716040510000000058
0000630000425200470061510000000063006b51000000530000405100005d49594949496a000000000000684d4d4d594949494a00787a0048494a00484d4e594d4d4e4d76767976767679764d4d4e4e7a7f0000630100000073005b000000583a3a594a00630040410042520048495f5a05737f405171604051005347474859
000063000042520047000000000000007300630000000063004051000075695f5f5959592a2a2a2a2a2a2a2a595959595959595a0071700058595a6f585959595f59696a000000000000000068595f59007876797679767a000000584d4976593a3a5f594a63005051004252485f2a2a597676767976767676797679797a6859
0000636f004252234b330000000000050000630000620063405100530000235859593a3a3a3a3a3a3a3a3a3a3a3a59593a3a5959494949495959594959593a3a59592a2a2a2a2a2a2a2a2a2a2a2a595900000000630078797a007869696a23583a3a59595a63000000004248593a3a3a5a014060716040510000006300002358
0100634e4e4252006b000062006f4d4e00006301004d4d4e5100006300000058593a3a3a3a3a3a3a3a3a3a3a3a3a3a59593a3a3a3a3a3a3a3a3a3a3a3a3a3a59593a3a3a3a3a3a3a3a3a3a3a3a3a3a5905000000630000720000000000610058593a3a3a5a234b2a2a4b33583a3a3a595a40517160405d495e000063006f0058
4d4e4d4f4f4e4d4e474d4d4e4d4d4f4f4d4d4e4e4d4f4f4f594e4d4d4e4d4d595f5959595959595959595959595959595959593a59595f3a5f3a5959593a59593b3b3b3b3b3b3b3b3b3b3b3b3b3a3a3a594e4d4d4e4d4e4d4e4d4d4d4e4d4d59595f3b3b5a005b3b3b5b00583b3b59595f494949494959595f49494949494959
5a00405161645b000063000042586a2a59596a600071600000000040646061585a5200004041000063000071606d69595f596969696959595969695959596959596a600000007160005041006d593a3a593a59595969696969696969595f596500405161700a0000335b47000040606100000000000000000000000000000000
5a40510000615b000063000042583a3a596a60007160010040410550647071585a52000050510000630071600061645859550040606168696a63616d696e42586e6000000071600000005041006d593a3a3a59596a41000042520000685959594051000061700001005b00007164707100000000000000000000000001000005
5a517f0500005b000063010047593a3a5a60005d4d494d4e76797676767976795a524b004252000073716000050061585a0140647071510000630061700042586000000171604b00004b00504105583a3a595f5a0050417f4252000019585f59510048767679767676797a40604b646000000000000000000000002020202020
5949494a00005b410048494959593a3a5a00716d6969696e42520000000072005a52584a4252010071600000754949595a40646464517f0000635305617042584976767676765a45455b005d767669695959595a004051754977444675593a3a00005b000000340000007160475b517800000000000000202020202000000000
5f59595a00005b504158595f593a3a3a6a7160000000006342520000000000005f79696976767679767a00000068595f594e4d4e4d4e5e46445d4e4e4d4e4d596a00716000475b00005b005b23330063595f595a405100005b52000000583a5947005b000048767976767976795b000000000057570000000000000000000000
6969696a00006b005068696959593a3a767676767976767679767676795e00005a520000006300007200000000406859593a3a3a3a3a5a0000585f5959593a3a007160536f475b00005b005b007f006359595959774545455b45454545583a5970005b7a445b454545454545455b460020205757570000000000000000000000
47006352000053000050410058593a3a405142520000007164410078796e45455a454545456345460000620040516f585f595959593a5a70005859593a3a3a597160007876766e4545687969764a0047595f595a520000005b52006f75593a3a61705b63005b007876764977005b7a0023335757575700000020000000000000
474763526f0063000000504158593a3a510042520000716061510000000000405a524b00005300000000634048494959593a3a3a3a3a5a617058593a3a593a59600000630000000000000000005b45455659595a525300755a5200757659593a00785b63785b00197f635b00005b000057575757575757572020200000202020
4949494949494949494a005058595f3a460042527f487676764a0000000000615a525b00484979767676767969696959593a59595f595a0061583a3a3a593a5f7a454663006200000040417f00587a006659595a526300005b5200007158595f00005b63006876767a635b00785b001920202020202020202020202020200000
2a2a2a5959595f59595a00005859593a29004252756a00000058492a2a2a4d495a525b00686e00000063000040512358593a3a3a3a3a5a0071583a593a593a592a2a4d4976764a000048797a005b635359595f5977636200584a007160585f596f005b470000426352635b00425b457800000000000000000000000000000000
59593a3a59595959595a00005859593a47454545454653000068593a3a3a3a595a525b006300000000630040517f0058593a5959593a5a7160583a593a593a3a3a3a3a5a60475b00005b7261415b63473a3a595500636300585a716000585955470058767679767976766977425b000000000000000000000000000000000000
595f3a3a3a3a5f59596a00006859593a630042526200636f0000583a3a3a3a3a5a52584a63000000004b40515d4949593a3a5f593a3a5a6000583a593a595f595f3a3a5a70735b00625b6244475b63735f3a5a0000636347595a47005358596500005b617000000042520000425b530000000000000000000000000000000000
593a3a595f3a59596a4445454568593a2a2a2a78794a63787a00686969593a3a5a525859492a472a2a6b2a75595f5959595959593a595a0000583a593a3a59596969696e60295b00635b4719485f7a70593a5a00007576695f5977056358595900006b476170007f42520000486b470000000000000000000000000000000000
593a5959593a595a330000000023583a3a3a3a3a3a5b63233340510000583a3a5a3358593a3a3a3a3a3a3a3a59595959595f3a3a3a595a2333583a59593a3a3a6061604445756e00636d7976696e6061593a5a00013400335b23347147583a3a707879797a61705d767976766a00004000000000000000000000000000000000
3a3a5f59593a595a007f00620000583a3a3a3a3a3a5a63000051000044583a3a5a00583a3a3a3a3a3a3a3a3a3a595f593a3a3a593a595a0000583a59593a595f70717000000000006300006f347200475f3a594d4d4a19005b005d4d49593a5f617034005300615b23056f005300406400000000000000000000000000000000
59595959593a59594949494949495f593b3b3b3b3b59494949494949495f3b3b59495959595959595f595959595959593b593b593b59594949593b5f593a3a594d4e4d4e4e4d4e4d4d4d4d4e4d4e4d49593a59595f594d4d5949595f593a3a594e4d4e4d4d4e4d6b004e4d4e4d4d4e4d00000000000000000000000000000000
__sfx__
a100000034670250701f0701a070170701507013070100700f0700c0700a07008070070700507004070040700c4100c4200c4300c4400c4500c4600c4700c4700c4700c4700c4700c4700c4700c4700c4700c470
000110202456024550245402453018730187401875018760187601876018760187501875018750187501875018742187421874218742187421874218742187421875218752187521875218752187521875218752
30011c20346700d07007070020703c6603c6503c6503c6403c6403c6403c6303c6303c6303c6303c6303c6203c6203c6203c6203c6203c6203c6203c6203c6203c6103c6103c6103c6103c6103c6103c6103c610
0000000034670250701f0701a060170601505013050100500f0400c0400a03008030070300502004020030200201001010000151f0001a0001700015000130000c4000c4000c4000c4000c4000c4000c4000c400
302400002473424732247322473224732247322473224732257342573225732257322673426732267322673227734277322773227732277322773227732277322473424735247002470035710357203573035740
3324000020734207322073220732207322073220732207321c7341c7321c7321c7321d7341d7321d7321d7321f7341f7321f7321f7321f7321f7321f7321f73220734207351d7001d70010b3010b4028a5010b60
44240000299502b950299502c950359503395033722337222e9502c9502b9502b7222b7122b7122b7122b712249502595027950277222771227712299502473124950247222471224712309502e9502c9502b950
8c240000293462533620326183161d31619326143360c3462b34627336223261f3161f3161b32616336133462b34627336243261f3161f3161b32618336133462c3462933624326203162b316273261833614346
c4240000144421444518432184351d4321d43519432194351844218445194321943515432154351943219435164421644519432194351d4321d43519432194351f4421f445204322043524432244351b4321b435
c42400001b525144321443518422184251d4221d42519422194251843218435194221942515422154251942219425164321643519422194251d4221d42519422194251f4321f435204222042524422244251b422
d02400000d1150d1250d1350d1450d1550d1450d1350d12505115051250513505145051550514505135051250a1150a1250a1350a1450a1550a1450a1350a1250311503125031350314503155031450313503125
d224000030014300123001230012300123001230012300122c0142c0122c0122c0122c0122c0122c0122c01229014290122901229012290122901229012290122e0142e0122e0122e0122e0122e0122e0122e012
c5240000145221452518522185251d5221d52519522195251852218525195221952515522155251952219525165221652519522195251d5221d52519522195251f5221f525205222052524522245251b5221b525
c424000000000145121451518512185151d5121d51519512195151851218515195121951515512155151951219515165121651519512195151d5121d51519512195151f5121f515205122051524512245151b512
c12400000d0150d0150d0150d0150d0250d0250d0250d02505015050150501505015050250502505025050250a0150a0150a0150a0150a0250a0250a0250a0250301503015030150301503025030250302503025
c1240000144121441518412184151d4121d41519412194151842218425194221942515422154251942219425164221642519422194251d4221d42519422194251f4321f43520432204351f4321f4351b4321b435
c12400001b515144121441518412184151d4121d41519412194151841218415194121941515412154151941219415164121641519412194151d4121d41519412194151f4221f42520422204251f4221f4251b422
d52400000d1250d1350d1450d1550d1550d1550d1450d13505125051350514505155051550515505145051350a1250a1350a1450a1550a1550a1550a1450a1350312503135031450315503155031550314503135
c5240000244422444522432224352443224435224322243524442244452243222435254322543524432244352444224445224322243524432244352243222435224422244520432204351f4321f4352043220435
c42400001b425244322443522422224252442224425224222242524432244352242222425254222542524422244252443224435224222242524422244252242222425224322243520422204251f4221f42520422
c4240000144321443518432184351d4421d4451f4421f4451f4521f4551d4421d44518432184351843218435164321643519432194351d4421d44522442224452545225455244422444520442204451f4421f445
c4240000204251143211435144321443518442184452044220445194421944516432164351943219435154321543511432114351643216435194421944524452244552543225435224422244520432204351f432
d42400000d1250d1350d1450d1550d1550d1550d1450d13505125051350514505155051550515505145051350a1250a1350a1450a1550a1550a1550a1450a1350f1340f1300f1300f1300f135061000610006100
d224000030014300123001230012300123001230012300122c0142c0122c0122c0122c0122c0122c0122c01229014290122901229012290122901229012290122e0142e0122e0122e0122e0152d0002d0002d000
c4240000294162541620416184161d41619416144160c4162b41627416224161f4161f4161b41616416134162b41627416244161f4161f4161b41618416134162c4262942624426204162b416274261843614436
0224000010b7000600006000060028a703f6153d60010b5010b7000600006000060028a703f615356003560010b7000600006000060028a703f6153560010b5010b70006000060010b5028a703f61510b5010b50
a024000001354013650d46501465084650d465014650146503354033650f465034650a4650f465034650346500354003650c46500465074650c4650046500465053540536511465054650c465114650546505465
c4240000294462543620426184161d41619426144360c4462b44627436224261f4161f4161b42616436134462b44627436244261f4161f4161b42618436134462c4462943624426204162b416274261843614446
c224000010b3000600006000060018a303f6003d60010b3010b4000600006000060019a3000000356003560010b400060000600006001aa403f6003560010b4010b50006000060010b501ba403f60010b6010b60
3024000000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0000a0029714297222973229742
3024000030950307223195030950307222c95030950319503095030722307122e9502e7222e7122e7122e712309503195030950319503395033722337222c7312c9502c7222c7122c7122c9502b9502995027950
30240000299502b950299502c950359503395033722337222e9502c9502b9502b7222b7122b7122b7122b712249502595027950277222771227712299502473124950247222471224712309502e9502c9502b950
4424000030950307223195030950307222c95030950319503095030722307122e9502e7222e7122e7122e712309503195030950319503395033722337222c7312c9502c7222c7122c7122c9502b9502995027950
44240000299502b950299502c950359503395033722337222e9502c9502b9502b7222b7122b7122b7122b71224950259502795027722277122771229950247312495024722247122471224940247222471224712
a02400000d870013750d87501475088750d475018750147503870033750f875034750a8750f475038750347500870003750c87500475078750c4750087500475058700537511875054750c875114750587505475
7a2400003e6153f6003c6153f6003f6003f6003c6153f6003f6003f6003c6253f6003f6003f6003c6253f6003f6003f6003c6353f6003f6003f6003d6353f6003f6003f6003d6453f6003f6003f6003e6453f600
322400003f6253f6003e6453f6003f6003f6253e6453f6253f6003f6003e6453f6003f6003f6253e6453f6253f6253f6003e6453f6003f6003f6253e6453f6253f6003f6003e6453f6003f6003f6253e6453f625
35240000209501d930249531d930299531d930259531d930249501f930259531f930229531f930259531f930229501f930249531f930279531f930249531f93029950209302c953209302b953209302795320930
35240000209501d930249531d930299531d930299531d9302b9501f9302c9531f9302b9531f930279531f9302b9501f9302c9531f9302e9531f9302b9531f9302b950209302c9532093030953209302995320930
d524000000000209301d910249331d910299331d910259331d910249301f910259331f910229331f910259331f910229301f910249331f910279331f910249331f91029930209102c933209102b9332091027933
d524000020910209301d910249331d910299331d910299331d9102b9301f9102c9331f9102b9331f910279331f9102b9301f9102c9331f9102e9331f9102b9331f9102b930209102c93320910309332091029933
0124000020734207322073220732207322073220732207321d7341d7321d7321d7321d7321d7321d7321d7321f7341f7321f7321f7321f7321f7321f7321f7322073420732207322073220732207322073220732
312400002473424732247322473224732247322473224732257342573225732257322573225732257322573227734277322773227732277322773227732277322773427732277322773227732277322773227732
012400003075033700337002e75000000000002c7500000000000000000000000000000000000000000000003075000000000002e75000000000002c750000000000000000000000000000000000000000000000
9124000014040000002004000000140400000020040000000d0400000019040000000d0400000019040000000f040000001b040000000f040000001b040000001404000000200400000014040000002004000000
312400003074030720307102e7402e7202e7102c7402c7202c710000000000000000000000000000000000003074030720307102e7402e7202e7102c7402c7202c71000000000000000029714297222973229742
91240000140400000020040000001404000000200400000015040000002104000000160400000022040000000f040000001b040000000f040000001b04000000140400c000200000500005410054200543005440
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
000b000013710167101871013720167301874013750187101b7101d7201f7301b7401d7501f71022720247201f7302274024740297502b7502e750267002e7401f7002e720347002e710300002b7003000030000
000100000254002540025400454006540095400b5400e5401054012540145401555016550175501755017550165501555013550115500e5500c5400b540095400854007540065400554004540035400254002540
000200000c5401054014550195501e55022560265602a56016540185401b5501f5502256026560295602c5402e5401e540215502455026550295502b5502d5502f560315603456037560395603c5703e5703f570
000200000904108031090210c0210e0311203115041190411c04123051270510a0000d0010f00113001170010e0000900005000000002e000240011d00117001120010f0010c0010a00108001060010500105001
06ff00001363538675126051d605266052d6052e6052a6052d6052c6052b60529605226051a605136050d60507605036050060517605126050d60506605026050060501605016000060001600026000160000600
__music__
01 0c0d0e4b
00 0f100a4b
00 0809114b
00 1213110b
00 14151617
00 1d181a1c
00 1e1b1a19
00 1f1b1a19
00 201b1a19
00 211b1a19
00 25271a1c
00 26281a19
00 25271a19
00 26281a19
00 6b2a294c
00 2b2a294c
00 2b2a292c
00 2d04052e
00 201b1a19
00 061b1a19
00 20071a19
02 21071a19
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
00 494a4b4c
00 494a4b4c

