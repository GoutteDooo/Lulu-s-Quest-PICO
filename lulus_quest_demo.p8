pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
	
menuitem(3, "music on/off", function() 
	music_object[3] = not music_object[3]
	if not music_object[3] then music(-1) else music(music_object[2]) end
 end)
menuitem(4, "sfxs on/off", function() sfx_enabled = not sfx_enabled end)
menuitem(1, "next lvl", function() next_room() end)
menuitem(2, "pass 5 lvls", function()
for i=1,5 do
	next_room()
end
end)

function _init()
	init_player()
	init_room()
	init_objects()
	camx = 0   
	camy = 0
	frames = 0
	room_transition_pending = false
	i_room = 1
	is_in_switch = false
	dflt_delay_switch = 0 --3 frames
	delay_switch = dflt_delay_switch
	sfx_timer = 0
	pulsator_state = false
	animation_timer = 0
	shake = 0
	music_object = {false, nil, true}-- {bool = change music, value = music pattern, bool = music on/off}
	musics = {1,27}
	sfx_enabled = true
	game_state = 1 -- 0 = title, 1 = game, 2 = restart_level, 3 = end
	pulsator_room = 16
	clock = {0,0} --{min, sec}
	clock_timer = 0
	deaths = 0
	--!! DEPLOIEMENT
	create_room()
	-- !! FIN DEPLOIEMENT
	--!! TEST
	-- next_room(128 * 7, 128 * 1)
	-- super_lulu = false
	--!! FIN TEST
end

function _update()
	-- if game_state != 3 then
		clock[2] += frames % 30 == 0 and 1 or 0
		if clock[2] == 60 then
			clock[2] = 0
			clock[1] += 1
		end
	-- end
	if animation_timer > 0 then
		animation_timer -= 1
		return
	end
	if game_state != 2 then
		update_game()
	else
		restart_level()
	end
end

function update_game() 
	frames=((frames+1)%30)
	clock_timer -= clock_timer > 0 and 1 or 0
	if sfx_timer > 0 then
		sfx_timer -= 1
	end
	--handle music
	--if music is not already set and turned on by player
	if music_object[1] and music_object[3] then
		music_object[1] = false
		music(music_object[2])
	end
	update_room()
	camx = room.x
	camy = room.y
	--messages
	if messages[1] then
		if btnp(❎) then
			deli(messages, 1)
		end
		return
	end
	update_chars()
	update_light()
	update_objects()
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
	-- draw outside of the screen for screenshake
	rectfill(-5+camx,-5+camy,-1+camx,133+camy,0)
	rectfill(-5+camx,-5+camy,133+camx,-1+camy,0)
	rectfill(-5+camx,128+camy,133+camx,133+camy,0)
	rectfill(128+camx,-5+camy,133+camx,133+camy,0)
	--DEBUG
	-- if btn(🅾️) and lulu.select then
		-- Dessiner la grid de la map
		-- for i=0,1 do
		-- 	for j=0,16 do
		-- 		if (i == 0) line(0, max(0,room.y + (j*8)),room.x + 128,max(0,room.y + (j*8)), 8)
		-- 		if (i == 1) line(max(0,room.x + (j*8)),0,max(0,room.x + (j*8)),room.y + 128,8)
		-- 	end
		-- end
		-- pset(ima_light.x,ima_light.y,11)
	-- end

	draw_ui()
	draw_messages()
	if clock_timer > 0 and game_state != 3 then draw_clock() end
	draw_display()
	debug_print()
	if game_state == 3 then draw_end() end
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
		c_jump = false,
		on_ground = false,
		default_sprite = name == "lulu" and 1 or 5,
		sprite = default_sprite,
		sprite_hide = name == "lulu" and 3 or 7,
		flipx = true,
		select = name == "lulu" and true or false,
		in_light = name == "lulu" and true or false,
		using_light = false, --to know if player is holding C key
		ima_range = 6 * 8, --range of ima_light for white and black light
		powers_left = 0,
		passed = false,
		shield = {
			timer = 0,
			active = false,
			def_r = 16,
			r = 16
		},
		light_selected = --for hades
		{
			nil, -- id light
			0 -- index dynamique
		},
		hitbox = { x = 2, y = 1, w = 4, h = 7 },
	}
end

function init_player()
	lulu = generate_character("lulu")
	hades = generate_character("hades")
	--globals to both
	pactual = lulu
	gkeys = 0
	wkeys = 0
	casting_bl = false
	FRICTION = 0.8
	accel = 0.6
	accel_air = 0.4
	JUMP_VELOCITY = -2.5
	MAX_DX = 2.2
	super_lulu = false
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
	if super_lulu then
		--hairs | 9 orange to pink
		--coat | 8 red to purple
		--eyes | 12 blue to green
		--feet | 4 brown to red
		pal(9,14)
		-- pal(8,2)
		pal(12,3)
	end
	spr(lulu.sprite, lulu.x, lulu.y, 1, 1, lulu.flipx)
	pal(9,9)
	-- pal(8,8)
	pal(12,12)
	if hades.sprite == hades.sprite_hide or hades.sprite == 17 then
		palt(0,false)
		palt(12,true)
	end
	spr(hades.sprite, hades.x, hades.y, 1, 1, hades.flipx)
	palt()
end

function update_chars()
	if messages[1] then return end
	if is_in_switch then
		delay_switch -= 1
		if delay_switch <= 0 then
			is_in_switch = false
			delay_switch = dflt_delay_switch
		end
		return
	end

	if pactual.passed then
		switch_characters(pactual)
		return
	end

	if casting_bl then
		update_black_light(pactual)
		return
	end

	if btn(🅾️) and pactual == lulu and ima_light.x != nil then
		lulu.flipx = ima_light.x <= lulu.x
	end

	if btnp(⬇️) and not btn(🅾️) then
		switch_characters(pactual)
		return
	end

	for c in all(chars) do
		if not c.using_light then move_characters(c) end
	end

	if check_flag(1, pactual.x + 4, pactual.y) then
		game_state = 2
		sfx_timer = 45
		fsfx(53,3)
		return
	end

	--COLLISIONS LIGHTS--
	---------------------
	foreach(chars, function(c)
		local c_in_light = false
		for dl in all(dynamic_lights) do
			if collision_light(c, dl) then
				c_in_light = dl.type == "white"
			end
		end
		for al in all(anti_lights) do
			if collision_light(c, al) then
				c_in_light = false
			end
		end
		for l in all(lights) do
			if collision_light(c, l) then
				c_in_light = true
			end
		end
		for bl in all(black_lights) do
			if collision_light(c, bl) then
				c_in_light = c == lulu
			end
		end
		for b in all(butterflies) do
			if collision_light(c, b) then
				c_in_light = b.light == "white" or b.light == "grey" or (b.light == "black" and c == lulu) or (b.light == "dark" and c == hades)
			end
		end
		c.in_light = c_in_light
	end)

	local update_shield = function(char, target, active_state)
		if char.shield.active then
			char.shield.timer -= 1
			char.in_light = active_state
			if collision_light(target, {x = char.x or 0, y = char.y or 0, r = char.shield.r or 0}) then
				target.in_light = true
			end
			if char.shield.timer <= 0 then
				disable_shield(char)
			end
		end
	end

	update_shield(lulu, hades, true)
	update_shield(hades, lulu, false)

	for gl in all(grey_lights) do
		foreach(chars, function(c)
			if collision_light(c, gl) then
				c.in_light = true
			end
		end)
	end

	local condition_1 = not lulu.in_light and not lulu.passed
	local condition_2 = hades.in_light and not hades.passed
	if condition_1 or condition_2 or pactual.y >= room.h-1 then
		animation_timer, game_state, sfx_timer = 30, 2, 45
		fsfx(53,3)
	end

	pactual.y_g, pactual.x_g = ceil(pactual.y / 8) * 8, ceil(pactual.x / 8) * 8

	if not room_transition_pending then
		pactual.x = mid(room.x, pactual.x, room.w - 8)
		pactual.y = mid(room.y, pactual.y, room.h - 8)
	end

	if black_orbs[1] then
		foreach(black_orbs, function(bo)
			if collision(pactual, bo) then
				casting_bl, sfx_timer = true, 20
				ima_light_bo.x, ima_light_bo.y, ima_light_bo.r = pactual.x_g, pactual.y_g, bo.r
				fsfx(52,3)
				del(black_orbs, bo)
			end
		end)
	end

	--animations
	pactual.sprite = pactual.default_sprite
	if not pactual.on_ground then
		pactual.sprite = pactual.default_sprite + 3
	elseif pactual.dx > 0.2 or pactual.dx < -0.2 then
		pactual.sprite = frames % 8 >= 4 and pactual.default_sprite + 1 or pactual.default_sprite
		if pactual.using_light then pactual.sprite = pactual.default_sprite end
	end
end

function move_characters(c)
	--handle input
	local move, jump = 0, btn(❎) and not pactual.c_jump
	pactual.c_jump = btn(❎)
	if not pactual.using_light then
		move = btn(⬅️) and -1 or btn(➡️) and 1 or 0
		if move ~= 0 then pactual.flipx = (move == -1) end
	end
	if jump and pactual.on_ground then
		pactual.dy, pactual.on_ground, pactual.is_jumping = JUMP_VELOCITY, false, true
		psfx(62, 3)
	elseif not btn(❎) and pactual.is_jumping and pactual.dy < 0 then
		pactual.dy *= 0.5
	end
	if c.dy > 0 then c.on_ground = false end

  -- 2) apply horizontal acceleration & friction
	local acc = c.on_ground and accel or accel_air
	pactual.dx = mid(-MAX_DX, pactual.dx + move * acc, MAX_DX) * FRICTION
	if abs(pactual.dx) < 0.1 then pactual.dx = 0 end

  -- 3) apply gravity to both characters
	c.dy += c.gravity
	--horizontal move & collision
	local new_x, hb, ym = c.x + c.dx, c.hitbox, c.y + c.hitbox.y + c.hitbox.h / 2
	if not (is_solid_at(new_x + hb.x, ym) or is_solid_at(new_x + hb.x + hb.w, ym)) then
		c.x = new_x
	else
		c.dx = 0
	end

	-- 4) vertical move & collision
	c.y += c.dy
	if c.dy > 0 then
		if is_solid_at(c.x + hb.x, c.y + hb.y + hb.h) or is_solid_at(c.x + hb.x + hb.w, c.y + hb.y + hb.h) then
			c.on_ground, c.dy, c.y = true, 0, flr((c.y + hb.y + hb.h) / 8) * 8 - (hb.y + hb.h)
		end
	elseif c.dy < 0 then
		--head bump
		if is_solid_at(c.x + hb.x, c.y + hb.y) or is_solid_at(c.x + hb.x + hb.w, c.y + hb.y) then
			c.dy, c.y = 0, flr((c.y + hb.y) / 8) * 8 + 8 - hb.y
			--c.y push character just below the ceiling tile
		end
	end
end


function switch_characters(c)
	--switch characters
	pactual = pactual == hades and lulu or hades
	c.select = false
	reinit_characters()
	pactual.select = true
end

function reinit_characters()
	foreach(chars, function(c)
		c.dx, c.dy, c.on_ground = 0, 0, false
	end)
	is_in_switch = true
end

function disable_shield(c)
	c.shield.active = false
	c.shield.timer = 0
end

-->8
--map

function check_flag(flag, x, y)
	local sprite = mget(x / 8, y / 8)
	return fget(sprite, flag)
end

-->8
--lights

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
		if super_lulu then fsfx(52,-2) end
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
		if super_lulu then psfx(52,3) else psfx(58,3) end
	end
	using_light("classic",lulu)
end

function update_light_hades()
	-- hades a une variable qui stocke temporairement la light selected
	nb_lights = #lights
	if nb_lights > 0 and hades.powers_left > 0 then
		if not hades.using_light then
			psfx(55,3)
			hades.using_light = true
		end
		local index = hades.light_selected[2]
		hades.light_selected[1] = lights[index + 1]
		if (btnp(➡️)) hades.light_selected[2] = (hades.light_selected[2] + 1) % nb_lights
		if (btnp(⬅️)) hades.light_selected[2] = (hades.light_selected[2] - 1) % nb_lights
		--flip hades when light selected x is > hades.x
		if hades.light_selected[1].x < hades.x then
			hades.flipx = true
		else
			hades.flipx = false
		end
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

function update_black_light(char)
	using_light("orb",char)
end

function using_light(magic_used, c)
	local i_light = magic_used == "orb" and ima_light_bo or ima_light

	local xsign = 0
	local ysign = 0
	
	if (btn(⬅️)) xsign = -1
	if (btn(➡️)) xsign = 1
	if (btn(⬆️)) ysign = -1
	if (btn(⬇️)) ysign = 1

	if ((btn(⬅️)) or (btn(➡️)) or (btn(⬆️)) or (btn(⬇️))) then
			local x = i_light.x + xsign * 8
			local y = i_light.y + ysign * 8
			
			-- Vれたrification du dれたplacement normal
			if frames % 3 == 0 then
				i_light.x = mid(room.x, flr(x / 8) * 8, room.w)
				i_light.y = mid(room.y, flr(y / 8) * 8, room.h)
			end

		-- Vれたrification de la distance par rapport au perso
		local dx = i_light.x - c.x_g
		local dy = i_light.y - c.y_g
		local dist = sqrt(dx * dx + dy * dy)

		if dist > c.ima_range then
				-- Limiter la position sur le cercle
				local angle = atan2(dx, dy)
				i_light.x = c.x_g + round((cos(angle) * c.ima_range)/8)*8
				i_light.y = c.y_g + round((sin(angle) * c.ima_range)/8)*8
		end
	end

	if btnp(❎) then
		local x = i_light.x
		local y = i_light.y
		if c == lulu and lulu.powers_left > 0 and magic_used != "orb" then
				create_light(x, y, ima_light.r,super_lulu and "black" or "white",10) 
				if super_lulu then psfx(51) else psfx(57) end
				shake = 6
				lulu.powers_left -= 1
			else
				create_light(x, y, i_light.r, "black")
				psfx(51)
				casting_bl = false
				shake = 12
				c.c_jump = true --to prevent char from jumping
		end
	end
end

function draw_light()
	draw_dynamic_lights()
	-- map(0, 0, 0, 0, 128, 64, 0x80)
	draw_lights()
	--disable possibility to player to draw ima lights
	if game_state != 1 then return end
	if messages[1] then return end
	draw_imaginary_light()
	draw_hades_turnoff()
end

function draw_imaginary_light()
	local lulu_light = btn(🅾️) and lulu.select and lulu.powers_left > 0
	local i_light = lulu_light and ima_light or casting_bl and ima_light_bo or nil
	if i_light then
		circfill(i_light.x, i_light.y, i_light.r, i_light.c)
		circ(i_light.x, i_light.y, i_light.r, i_light.c+1)
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
	pal(3,3+128,1)
	foreach(
		black_lights, function(bl)
			circfill(bl.x, bl.y, bl.r, 3)
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
			local r = c.shield.r
			local color_circle = c == hades and 3 or 10
			local cx = c.x + c.w / 2
			local cy = c.y + c.h / 2
			if c == hades then pal(3,3+128,1) end
			circfill(cx, cy, r, color_circle)
			circ(cx, cy, r, 7)
			print(flr(c.shield.timer / 30), c.x + 4, c.y - 5, 11)
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
		r = r or 16,
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
	-- powers = { lulu (number), hades (number) }
	-- black_orbs = { x, y, r }
	-- shield_cristals = { x, y, timer (seconds), r, lives, c (couleur)}
	-- chests = { { opened (boolean), locked (boolean), check_lock (boolean), content = { name (string), r (number)}, x, y } }
		-- pour les chests : si content.name = "turnoff" -> aucune autre data れき insれたrer
		-- si content.name = "black_orb" -> content = { name, x, y, r }
	-- butterflies = { x, y, x1, y1, x2, y2, target (1 ou 2), speed (number), r (number), light (string = "white" ou "black") }
	-- messages = { title (string), text (string) }
	-- p_data = {x, y, r_max, type (string = "white" ou "anti"), timer (frames), (next are optionals: ) spr_r of pul (number), spd of dl (float)}
	rooms_data = {
		--1
		{
			lights = {{2,13,22},{11,14,16}},
			powers = {1,1},
			messages = {
				{"tutorial","welcome to lulu's quest!"},
				{"tutorial","hold 🅾️ and press ⬆️⬅️➡️or⬇️\n to prepare a light"},
				{"tutorial","press ❎ while holding 🅾️\n to cast a light"},
				{"tutorial","lulu (left) can only live\n inside of lights"},
				{"tutorial","press ⬇️ to switch characters"},
				{"tutorial","hades (right) can only\n live outside of lights"},
				{"tutorial","as hades, hold 🅾️+⬅️➡️ to\n prepare a turnoff and..."},
				{"tutorial","...press ❎ while holding 🅾️\n to turn off a light"},
				{"tutorial","your remaining powers are\n shown at the top left"}, 
				{"tutorial","the goal is to bring\n your characters..."}, 
				{"tutorial","...to their respective doors."}, 
				{"tutorial","good luck!"},
			},
			display = {
				{60,5, "❎   jump"},
				{60,12,"🅾️   power"},
				{60,19,"⬇️   switch"},
				{60,26,"⬅️➡️  move"},
				{60,33,"🅾️❎  cast"},
			},
			music = 45
		},
    --2
    {
        lights = {{19,13,20},{28,13,24}},
        powers = {1,1},
				music = 0,
    },
    --3
    {
        lights = {{45,  9, 24},{37,  8}},
        powers = {3,1},
    },
    --4
    {
        lights = {{52, 11, 18},{59, 10, 22}},
        powers = {2,2},
    },
    --5
    {
        lights = {{67, 10},{72, 2, 24},{75, 10},},
        powers = {2,1,},
    },
    --6
    {
        lights = {{84, 12, 24},{95, 13, 32}},
        powers = {2,2},
    },
    --7
    {
        lights = {{104, 3},{111, 8, 24},{101, 8, 12},{106, 14, 24}},
        powers = {3,2},
    },
    --8
    {
        lights = {{115, 14},{119, 14},{124, 11}},
        powers = {1,0},
        black_orbs = {{122,14,24}},
    },
    --9
    {
        lights = {{10,19},{5,23},{11,24}},
        powers = {1,1},
        black_orbs = {{8,23,32}},
    },
    --10
    {
        lights = {{24, 17},{17, 19, 20},{21, 20},{29, 22, 28},{21, 23},{23, 28, 24}},
        powers = {4,7},
        chests = {
            {false,true,false,{"black_orb",27,30,36,},28,30,}},
    },
    --11
    {
        lights = {{37, 19},{37, 23},{46, 26, 12}},
        powers = {2,1,},
        black_orbs = {{33, 19, 32}},
    },
    --12
    {
        lights = {{51, 19},{56, 28,  8}},
        powers = {1,0},
        shield_cristals = {{54, 19, 4, 12}},
    },
    --13
    {
        lights = {{67, 18},{72, 22, 8},{70, 24, 8},{74, 24, 8},{72, 26, 8},{72, 28, 8},{72, 30, 8},{79, 30, 8}},
        powers = {2,1,},
        shield_cristals = {{70,17, 8,16,1},{67,21,10,16,2},{64,30,12,24,1}},
        chests = {{false,true,false,{ "turnoff" },74,21}},
    },
    --14
    {
        lights = {{84, 29}},
        powers = {0,0},
        shield_cristals = {{88,18,60,32,1,"red"}},
        butterflies = {{86,17,86,17,85, 27,2, 0.5,24,"white"}}
    },
    --15
    {
        lights = {{103, 17}},
        powers = {1,0},
        shield_cristals = {{101,17,10,10,1},{100,28,10,10,1},{106,17,10,10,1}},
        butterflies = {
            { 97,30, 97,30, 97,16, 2, 1,12,"white"},
            { 99,28, 99,28,107,28, 2, 1,12,"white"},
            {103,19, 99,19,109,19, 2,0.5,18,"black"},
            { 98,23, 98,23,108,23, 2,0.5,24,"black"},
        },
    },
    --16 HEART
    {
			lights = {{120, 17.5, 20,"black"}},
			powers = {1,0},
			pulsator = {
					x = nil,
					y = nil,
					spr_r = 24,
					timer = 150,
					pulse_dur = 60,
					pulse_timer = 0,
					beat_delay = 210,
					is_broken = false,
					light_data = {r_max = 128, type = nil, spd = 1, room_ac = {false, false} }, 
			},
			p_data = {118,31,120,"white",0},
    },
    --17
    {
			lights = {{6.5, 40, 24, "black"}},
			powers = {2,0},
			p_data = {14,46,256,"white",180},
			music = 27
	},
	--18
	{
		lights = {{25,33,8,"black"},{30,43,16,"black"}},
		powers = {3,1},
		butterflies = {{23,46,23,46,31,46,2,0.6,12,"white"},},
		chests = {{false, true, false, {"wkey"},16,37}},
		p_data = {22.5,37.5,46,"white",180,12}
	},
	--19
	{
		lights = {
			{35,33,8,"grey"},
			{45,33,12,"black"},
			{40,39,10,"grey"},
			{40,46,10,"white"},
		},
		powers = {0,0},
		messages = {{"hint","white lights take priority\n over any light"}},
		shield_cristals = {{43,40,7,26,1}},
		butterflies = {
			{36,43,33,43,47,43,2,0.4,12,"black"},
			{36,46,33,46,47,46,2,0.4,12,"black"},
		},
		p_data = {38,30,108,"white",190,14,3}
	},
	--lvl 20
	{
		lights = {
			{57,34,8},
			{50,34,12, "grey"},
			{51,38,10,"black"},
			{56,41.5,10,"grey"},
		},
		powers = {1,0},
		shield_cristals = {{53,39,60,20,1},{48,45,12,12,1}},
		p_data = {54.25,46,128,"white",0,14,2}
	},
	--21
	{
		lights = {
			{73,35,8},
			{66,42,16,"black"},
			{79,39},
			{77,42,12,"grey"},
			{71,39,16,"grey"},
		},
		powers = {3,1},
		p_data = false,
		music = 46
	},
	--22
	{
		lights = {
			{81,44,12,"black"},
			{88,38,28},
			{90,33},
		},
		powers = {1,1},
		chests = {{false, true, false, {"black_orb",86,43,20},85,43}},
		p_data = {94.5,29.5,240,"white",200,16,1.5},
		music = 27
	},
	--23
	{
		lights = {
			--lulu
			{99,43},
			{107,43},
			{107,36},
			{99,36},
			--hades
			{98,46,12,"black"},
			{111,46,12,"black"},
			--lvl
			{103,45},
			{103,33},
		},
		powers = {3,1},
		butterflies = {
			{112,33,94,33,114,33,2,1,12,"black"},
			{100,46,97,46,110,46,1,0.6,12,"black"},
			{103,33,103,33,103,46,2,1,12,"dark"},
			{97,40,97,40,112,40,2,1,12,"dark"},
		},
		p_data = {101.5,38,128,"white",200,13},
		messages = {
			{"hint","red lights kill anyone\nwho enters them"}
		}
	},
	--24
	{
		lights = {{119,39,55,"black"}},
		powers = {7,0},
		messages = {
			{"a voice","you made a good job."},
			{"a voice","congratulations for all\nthese steps you reached."},
			{"a voice","you have now the choice,\nboth of you."},
			{"a voice","go right, but it will\nbe hard."},
			{"a voice","or go left, and finish\nyour mission."},
		},
		music = 47,
		display = {
			{900,288,"   <-finish"},
			{940,276,"   continue->"},
		},
	},
	--25
	{
		lights = {{120,40}},
		powers = {0,0},
	},
	--26
	{
		lights = {{120,40}},
		powers = {0,0},
		--p_data = {x,y,r_max,type (string = "white" ou "anti"), timer (frames), acristals (number), spr_r (number), spd (float)}
	},
	--27 (idk if i keep it)
	{
		lights = {
			{33,49,16},
			{39,49,16,"anti"},
			{39,54,16,"black"},
		},
		powers = {4,1},
		butterflies = {
			{39,54,39,54,47,54,2,0.6,12,"black"},
		},
		p_data = {38.25,62,140,"white",0,14,8}
	},
	--28
	{
		lights = {{120,40}},
		powers = {0,0},
		p_data = false
	},
	--29
	{
		lights = {{120,40}},
		powers = {0,0},
		p_data = false
	},
	--30
	{
		lights = {{120,40}},
		powers = {0,0},
		p_data = false
	},
	--31
	{
		lights = {{104,57,64,"black"}},
		powers = {0,0},
		p_data = false
	},
}
end

function update_room()
	--if they have finished the lvl
	if room_transition_pending then
		next_room()
		room_transition_pending = false
		lulu.passed, hades.passed = false, false
	end
end

function next_room(argx, argy)
	local x, y = argx or room.x + 128, argy or room.y
	if x >= 1024 then x, y = 0, y + 128 end
	if y >= 512 then y = 0 end -- We are at the end of the map
	local w, h = x + 128, y + 128
	local id = room.id + 1
	if id == 33 then id = 1 end

	room = new_room(id, x, y, w, h)
	i_room = index_room(room.x, room.y)
	create_room()
	sfx_timer = 30
	fsfx(61,3)
	clock_timer = 90
	-- !!  TEST !!
	-- if music_object[2] != 27 then reset_music(27) end
	-- gkeys = 2
	-- wkeys = 2
	-- !!END TEST
end

function reset_music(pat)
	music_object[1], music_object[2] = true, pat
end

function create_room()
	-- set pulsator state on
	-- and put pulsator object into global pulsator object
	if i_room >= pulsator_room and not pulsator_state then
		pulsator_state = true
		pulsator = rooms_data[16].pulsator
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
	--the end
	if i_room == 31 then
		--afficher le nombre de morts
		--afficher le temps
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
	deaths += 1
end

-->8
--objects

function init_objects()
	-- coordonnれたes pour lvl 1, れき update chaque changement de room
	ima_light = {
		x = lulu.x + 4,
		y = lulu.x + 4,
		r = 16,
		c = 12
	}
	doors = {
		lulu = {x = 0, y = 0},
		hades = {x = 0, y = 0}
	}
	lights = {}
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
	pulsator = nil
	dynamic_lights = {}
	acristals = {}
	walls = {}
	grey_lights = {}
	anti_lights = {}
	mushroom = {}
	display = {}
end

function update_objects()
	-- When someone enter its door, passed will be turn on and character will disappear
	if not pactual.passed and collision(pactual, pactual == lulu and doors.lulu or doors.hades) then
		pactual.passed = true
		delay_switch = 10
		-- cas particulier : end choice
		if i_room == 24 then
			if pactual == hades then
				end_finish()
			else
				end_continue()
			end
		end
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
			if c.locked and gkeys > 0 then
				gkeys -= 1
				open_chest(c)
			elseif c.locked and gkeys == 0 then
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
			if k.style == "door" then
				wkeys += 1
			else
				gkeys += 1
			end
			k.collected = true
		end
	end)

	--shield cristals
	foreach(shield_cristals, function(sc)
		for c in all(chars) do
			if collision(c,sc) then
				if not c.shield.active or c.shield.timer < (sc.timer*30)/2 then
					psfx(57)
					if sc.lives then sc.lives = sc.lives - 1 end
					if sc.lives and sc.lives <= 0 then
						del(shield_cristals,sc)
					end
					c.shield = {
						active = true,
						timer = sc.timer * 30,
						def_r = sc.r,
						r = sc.r
					}
				end
			end
		end
	end)
	--gates
	foreach(gates, function(g)
		if collision_gate(pactual,g) then
			if wkeys > 0 and not g.opened then
				psfx(54)
				wkeys -= 1
				mset(g.x/8, g.y/8, g.tile+1)
				g.opened = true
			end
		end
	end)
	--butterflies
	for b in all(butterflies) do
		update_butterfly(b)
	end
	--pulsator
	update_pulsator()

	--acristals
	update_acristals()

	--mushroom
	if mushroom[1] and collision(lulu, mushroom[1]) then
		local m = mushroom[1]
		super_lulu = true
		ima_light.c = 1
		sfx_timer = 30
		music(-1)
		fsfx(59,3)
		del(mushroom, m)
		mset(m.x/8, m.y/8, 0)
		animation_timer = 75
		reset_music(27)
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
	if pulsator then
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
		black_orbs,
		shield_cristals,
		butterflies,
		messages,
		display,
		dynamic_lights,
		acristals,
		walls,
		grey_lights
	}
	local lists_to_reset = {
		keys,
		gates,
		acristals,
		walls,
	}

	--if level restart, then restore them on the map before destroy
		for _, tbl in ipairs(lists_to_reset) do
			for obj in all(tbl) do
				mset(obj.x/8, obj.y/8, obj.tile)
			end
		end
		for _,p in pairs(room.pos) do --reset pos of hades & lulu
			mset(p[1], p[2], p[3])
		end
		
	--delete all objects from ancient room or current if restart_level() called
	for _, tbl in ipairs(lists_to_clear) do
		for obj in all(tbl) do
			del(tbl, obj)
		end
	end
	gkeys = 0
	wkeys = 0
	--reset data of pulsator
	if pulsator and rooms_data[i_room].p_data then
		pulsator.timer = 0
		pulsator.light_data.room_ac[1] = false
		pulsator.light_data.room_ac[2] = false
	end
	--reset sfxs
	sfx(-2)
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
	--display
	foreach(c_room.display, function(d)
		add(display, d)
	end)

	-- set dynamics data to pulsator
	if pulsator and c_room.p_data then
		local p = c_room.p_data
		pulsator.x = p[1] * 8
		pulsator.y = p[2] * 8
		pulsator.light_data.r_max = p[3]
		pulsator.light_data.type = p[4]
		pulsator.timer = p[5]
		pulsator.is_broken = false
		pulsator.spr_r = p[6] or 18
		pulsator.light_data.spd = p[7] or 1
	else
		pulsator_state = false
	end

	--acristals
	-- foreach(c_room.acristals, function(ac)
	-- 	add(acristals, {x = ac[1] * 8, y = ac[2] * 8, active = false, ch_col = nil})
	-- end)

	--find tiles to convert into objects
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
			--acristals
			if t == 38 then
				add(acristals, {x = x * 8, y = y * 8, active = false, ch_col = nil, used = false, tile = t})
				mset(x, y, 0)
			end
		end
	end
	--handle music
		if c_room.music and music_object[2] != c_room.music then
			reset_music(c_room.music)
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
	if blight == "black" then pal(3,3+128,1) end
	local light_c = blight == "white" and 9 or blight == "black" and 3 or blight == "grey" and 7 or 8
	local circ_c = blight == "white" and 6 or blight == "black" and 13 or blight == "grey" and 5 or 2
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
	elseif content == "wkey" then
		wkeys += 1
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
--messages & displays

function draw_messages()
	if messages[1] then
		local x1 = room.x+4
		local y1 = room.y+40
		local x2 = room.x+124
		local y2 = room.y+62
		--deep shadow
		for i=1,3 do
			rectfill(x1+i, y1+i, x2+i, y2+i, 2)
		end
		rectfill(x1, y1, x2, y2, 7)
		rect(x1, y1, x2, y2, 2)
		rectfill(x1+3, y1-2, x1 + 3  + #messages[1][1]*4, y1+4, 2)
		print(messages[1][1],x1+4,y1-1,9)
		print(messages[1][2],x1+4,y1+8,1)
		if messages[2] then print("❎->",x2-16,y2-6,13) end
		if not messages[2] then print("❎end",x2-20,y2-6,13) end
	end
end

function draw_display()
	if display[1] and i_room == 1 then
		rectfill(display[1][1]-4,display[1][2]-4,display[1][1]+50,#display*8,6)
		rect(display[1][1]-4,display[1][2]-4,display[1][1]+50,#display*8,2)
	end
	foreach(display, function(d)
		for i=1,2 do
			print(d[3][i], d[1]+i*8-8, d[2], 12)
		end
		for i=3,#d[3] do
			print(d[3][i], d[1]+i*4, d[2], 0)
		end
	end)
end

function draw_clock()
	local offset = clock[1] > 99 and 8 or clock[1] > 9 and 4 or 0
	if clock[2] < 10 then clock[2] = "0"..clock[2] end
	print(clock[1],room.x+50-offset,room.y+4,9)
	print(":"..clock[2],room.x+54,room.y+4,9)
end

-->8
--pulsator

function draw_pulsator()
	if not pulsator_state then return end
	-- osciller uniquement si pulse_timer actif
	local pr = pulsator.spr_r
	local pulse_ratio = pulsator.pulse_timer / pulsator.pulse_dur
	local scale = pr / 10 + 0.5 * pulse_ratio -- grossit れき chaque battement
	local broke = pulsator.is_broken
	-- flips
	local flipx = frames % 15 < 7
	local flipy = frames % 30 < 15

	-- palette dynamique pour les fissures du pulsateur
	if frames % 30 < 10 then
		pal(3,9)
	elseif frames % 30 < 20 then
		pal(3,7)
	else
		pal(3,3+128,1)
	end

	-- position
	local cx = pulsator.x + pr + rnd(1 * pr/10)
	local cy = pulsator.y + pr + rnd(1 * pr/10)

	-- dessiner sprite
	local w = pr * 2 * scale
	local h = pr * 2 * scale
	local x = cx - (w / 2)
	local y = cy - (h / 2)

	if broke then
		if frames % 30 < 20 then
			pal(1,7)
			pal(5,7)
			pal(13,6)
		else
			pal()
			pal(3,3+128,1)
		end
	else
	--electrical effects
		for i = 1, 5 do
			local a = rnd(1) * 2 * 3.141592653589793
			local r1 = (pr * 2 + rnd(5)) * 0.05 * pr
			local r2 = (r1 + rnd(5)) * 1.5
			local x1 = cx + cos(a) * r1
			local y1 = cy + sin(a) * r1
			local x2 = cx + cos(a) * r2
			local y2 = cy + sin(a) * r2
			local c = rnd(1) < 0.5 and 7 or 3
			line(x1, y1, x2, y2, c)
		end
	end

	sspr(12*8, 0, 32, 32, x, y, w, h, flipx, flipy)
	
	pal(1,1)
	pal(5,5)
	pal(13,13)
	pal(3,3)
end

function update_pulsator()
	if cannot_pulse() then return end
	if pulsator then
		--Aprれそs chaque pulsation, on rejoue le SFX electrical effects
		-- if pulsator.timer == 30 and i_room == 15 then sfx(47, 0, 0, 14) end
		local broken = pulsator.is_broken
		--A less before the next pulsation, prevent the player
		local beat_delay = broken and pulsator.beat_delay / 2 or pulsator.beat_delay
		if pulsator.timer == beat_delay - 30 and i_room != pulsator_room then fsfx(48, 3, pulsator.light_data.type == "white" and 6 or 13, 1) end

		pulsator.timer += 1
		if pulsator.timer >= beat_delay then
			local ptype = pulsator.light_data.type
			-- un battement se produit
			pulsator.pulse_timer = pulsator.pulse_dur -- dれたclenche une pulsation visuelle
			pulsator.timer = 0
			shake = 10
			-- SFX
			if sfx_timer == 0 and i_room != pulsator_room then
				fsfx(48, -1)
				sfx_timer = 30
				-- fsfx(48, 3, ptype == "white" and 7 or 14, 1)
				fsfx(48,3, ceil((rnd(1)*2))*7,1)
			end
			local pr = pulsator.spr_r
			-- update light from pulsator
			local new_dyna_light = create_dynamic_light(pulsator.x + pr, pulsator.y + pr, ptype, pulsator.light_data.spd, pulsator.light_data.r_max, pr)
			add(dynamic_lights, new_dyna_light)
			if broken then
				local types = {"white", "black", "anti"}
				local last_type = ptype
				local new_type = types[flr(rnd(1) * #types) + 1]
				while (new_type == last_type) do
					new_type = types[flr(rnd(1) * #types) + 1]
				end
				pulsator.light_data.type = new_type
			else
				pulsator.light_data.type = ptype == "anti" and "white" or "anti"
			end
		end
		-- diminuer le pulse progressivement
		if pulsator.pulse_timer > 0 then
			pulsator.pulse_timer -= 1
		end
	end
end

function break_pulsator()
	--if we are here, then all acristals are activated
	if not pulsator.is_broken then
		-- timer of pulsator reset to 0
		pulsator.timer = 0
		-- wait 1 sec
		animation_timer = 60
		-- screenshake
		shake = 60
		-- wait 2 sec and delete acristals
		pulsator.is_broken = true
		fsfx(47, -2)
		sfx_timer = 120
		fsfx(63)
	end
		--when animation is finished, delete the acristals and destroy walls
	if animation_timer == 0 then 
		foreach(acristals, function(ac)
			ac.used = true
		end)
		foreach(walls, function(w)
			--break walls
			w.broken = true
			mset(w.x/8, w.y/8, 0)
			--accelerate pulsator just for the end of the lvl
		end)
	end
end

function cannot_pulse()
	return ((lulu.using_light or hades.using_light) and i_room > pulsator_room) or not pulsator_state or pulsator.is_broken or casting_bl
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
			local px = pulsator.x + pulsator.spr_r
			local py = pulsator.y + pulsator.spr_r
			-- nombre d'れたtapes par れたclair
			local steps = 8

			for j=1, 3 do
				for i=0,steps-1 do
					local t1 = i / steps
					local t2 = (i+1) / steps

					local x1 = lerp(ax, px, t1) + rnd(7) - 1
					local y1 = lerp(ay, py, t1) + rnd(7) - 1
					local x2 = lerp(ax, px, t2) + rnd(7) - 1
					local y2 = lerp(ay, py, t2) + rnd(7) - 1
					pal(3,3+128,1)
					palt(0, false)
					palt(12, true)
					-- couleur alれたatoire parmi un choix れたlectrique
					local c = ({10, 3, 0})[1 + flr(rnd(3))]
					line(x1, y1, x2, y2, c)
					palt(12, false)
					palt(0, true)
					pal(3,3)
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
			if not ac.active and not ac.used and collision(c,ac) then
				ac.active = true
				ac.ch_col = c
				pulsator.light_data.room_ac[i] = true
				psfx(47,3)
				break
			end
		end
		--if it has a collision with a char, now check each frames if collision is still there
		if not ac.used and ac.active then
			if not collision(ac.ch_col,ac) then
				ac.active = false
				pulsator.light_data.room_ac[i] = false
				ac.ch_col = nil
				fsfx(47,-2)
			end
		end
	end
	--check if all acristals are activated
	if pulsator and #acristals > 0 then
		for ac in all(pulsator.light_data.room_ac) do
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
	if cannot_pulse() then return end
	foreach(dynamic_lights, function(dl)
		if dl.r < dl.r_max then
			dl.r += dl.spd
		end
		if dynamic_lights[2] and dynamic_lights[2].r >= dynamic_lights[2].r_max then
			deli(dynamic_lights, 1)
		end
	end)
end

function draw_dynamic_lights()
	foreach(dynamic_lights, function(dl)
		local c = dl.type == "anti" and 0 or 9
		if dl.type == "black" then
			pal(3,3+128,1)
			c = 3
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
	local x, ry = room.x + 12, {room.y + 4, room.y + 12, room.y + 20, room.y + 28}
	local powers = {
		{lulu.powers_left, super_lulu and 19 or 49, ry[1]},
		{hades.powers_left, 50, ry[2]}
	}
	local keys = {
		{gkeys, 57, ry[3]},
		{wkeys, 9, ry[4]}
	}

	palt(0, false)
	palt(12, true)

	for i, p in pairs(powers) do
		if p[1] > 0 then
			spr(p[2], room.x + 4, p[3])
			for dx = -1, 1, 2 do
				print(p[1], x + dx, p[3], 0)
				print(p[1], x, p[3] + dx, 0)
			end
			print(p[1], x, p[3], 11)
		end
	end

	for i, k in pairs(keys) do
		if k[1] > 0 then
			spr(k[2], room.x + 4, k[3])
			for dx = -1, 1, 2 do
				print(k[1], x + dx, k[3], 0)
				print(k[1], x, k[3] + dx, 0)
			end
			print(k[1], x, k[3], 11)
		end
	end

	palt()
end

-->8 end

function end_finish()
	next_room(128 * 6, 128 * 3)
	game_state = 3
end

function end_continue()
	next_room()
end

function draw_end()
	rectfill(784, 400, 864, 416, 15)
	print("congrats! \n you died: "..deaths.." times.", 788, 404,1)
end

-->8
--helper functions

function debug_print()
	-- if pulsator and rooms_data[i_room].p_data then
	-- 	print(" state: ")
	-- 	print(pulsator.is_broken and "broken" or "working")
	-- 	print(" type: "..pulsator.light_data.type)
	-- 	print(" timer: "..pulsator.timer)
	-- 	print(" ptimer: "..pulsator.pulse_timer)
	-- 	print(" beat delay: "..pulsator.beat_delay)
	-- end
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
    local px1, py1 = p.x, p.y
    local px2, py2 = p.x + p.w, p.y + p.h
    local gx1, gy1 = g.x - 2, g.y - 2
    local gx2, gy2 = g.x + 10, g.y + 10
    
    return px2 > gx1 and px1 < gx2 and py2 > gy1 and py1 < gy2
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

function is_solid_at(px, py)
  local tx, ty = flr(px/8), flr(py/8)
  return fget(mget(tx, ty), 0)
end

__gfx__
00000000088888800888888001111110088888800222222002222220c111111c02222220ccc0cccc000000000000000000000000000011111111000000000000
000000008888888888888888111111118888888822222222222222221111111122222222cc040ccc000000000000000000000000011111111111111000000000
000000008899999888999998114444418899999822222f2222222f2211111d1122222f22c04640cc000000000000000000000001111315555551111110000000
00000000899ff9f9899ff9f9144dd4d4899ff9f90229ff920229ff92c114dd410229ff92cc040ccc000000000000000000000011115333555555551111000000
0000000089fc9fc989fc9fc914d14d1489fc9fc9022ffff2022ffff2c11dddd1022ffff2cc040ccc0000000000000000000001115555533dd555533511100000
00000000089fff90089fff90014ddd40089fff900121d1020121d102c01050c10121d102cc0440cc00000000000000000000111355dddd333ddd535551110000
000000000088880000888800001111000088880001dddd0010dddd00c05555cc01dddd00cc040ccc0000000000000000000111533ddddddd3dddd3dd55111000
00000000004004000004500000500500040000400140040010045000c02cc2cc04000040ccc0cccc00000000000000000011155d3ddddddd3dddd3ddd5511100
08888880c888888c0002e000ccc0cccc0000000000000000000000000000000000000000000000004444444440000004001155dd33dddddd33dd33dddd551100
88888888888888880022ee00cc030ccc0000c0000000800000000000000000000004000000040000454545455000000501115dddd33dddddd33333ddddd51110
8888888888888888022eeee0c03630cc000c7c000008780000000000000000000004000000464000454545455000000501155ddddd3dddddddddd3ddddd55110
88888888c889889822eeeeee0366630c0000c0000000800000088000000880000004000000040000444444444000000401155ddddd3dddddddddd3ddddd55110
88898898c888888800054000c03630cc0000100000002000008838000088b800000400000004000000000000000000001115dddddd3ddd11111d33dddddd5111
08888880c88888c800054000cc030ccc00001000000020000838888008b88880000400000004400000000000000000001155dddddd3dd111111133dddddd5511
00888800c88888cc00044000ccc0cccc00001000000020000004400000044000000400000004000000000000000000001155dddddd3d1111111113ddddddd511
00800800c88cc8cc00044000cccccccc00001000000020000004400000044000000000000000000000000000000000001155dddddd311111111113ddddddd511
6666666607070a00070700000005500008800880000000000000000000000000000000000000000000000000000000001155ddddd3311111111133ddddddd511
6555555600444a4000444a400055550088888888000000000000000000000000000a0000000a0000000000000000000011555ddd33d33111111131dddddd5511
655555560000000000000a000558855088888888080800000007000000080000000a000000a9a000888888880000000011555ddd3dd13333311131dddddd3311
6555555600000000000000005588885588888788888880000076700000828000000a0000000a0000888888880000000011155ddd3ddd11113111333333333111
655555560000000000000000588998858888778888888000076a6700082a2800000a0000000a0000848888880000000001155ddd3dddd11133113ddddd555110
6555555600000000000000005899998508888880088800000076700000828000000a0000000aa000888888880000000001155ddd333ddd111313dddddd555110
6555555600000000000000005899798500888800008000000007000000080000000a0000000a00008888884800000000011155dd3d33ddddd3333ddddd551110
666666660000000000000000589779850008800000000000000000000000000000000000000000008888888800000000001155333dd33ddddddd3dddd5551100
00005000ccc0ccccccc8cccc0005500000444400004554000000000000000000000aa000ccc0cccc88888888888888880011153555dd3ddddddd33d555511100
00666600cc0a0ccccc808ccc005555000045540000000000000000000999999004444440cc0a0ccc88888888888888880001113355dd333dddddd33555111000
06444460c0a7a0ccc80008cc055dd5500044440000000000000b00009974449946665554c0a9a0cc88848888888888880000113555555d33dddddd3351110000
644545460a777a0c8000008c55dddd55004554000000000000b3b0009744444946655554cc0a0ccc888888888888888800000111555555533555555511100000
64445446c0a7a0ccc80008cc5dd22dd500444400000000000b3a3b009999999997444449cc0a0ccc888888888888888800000011115555553555551111000000
64444446cc0a0ccccc808ccc5d2222d5004554000000000000b3b000974aa44997444449cc0aa0cc888888888888888800000001111115553351111110000000
06444460ccc0ccccccc8cccc5d2272d50044440000000000000b00009744444997444449cc0a0ccc888888488888888800000000011111111311111000000000
00666600cccccccccccccccc5d2772d50045540000455400000000009999999999999999ccc0cccc888888888888888800000000000011111111000000000000
00000111111000000000001100000000000111000000000000111000055555500555555555505505555555500555555000999900505555055055055566666666
00001111111100000000001100000000001111100000010001111100555555555555555555555555555555555555555509000090555655555555555566666666
000111111111100000000011cccccccc011111111111111101111110555665555555556655555555565665555556655590000009655666665655655566666666
001111111111110000000011cccccccc111111111111111111111111556666555555566665566566666665555556665590000009666666666665665666666666
011111111111111000000011cccccccc111111111111111111111111556665555556666666666666666666555566655590000009666666666666666666666666
111111111111111100000111cccccccc011111101111111111111110555655555556666666666666666666555566665590000009666666666666666666666666
111111111111111100000011cccccccc00111110010000000111110055555555555666dd66666666666666655556655509000090666666666666666666666666
111111111111111100000011cccccccc00011100000000000011100005555550555666dd66666666d66666555556665500999900666666666666666666666666
11111111111111111100000000011000ccccccccd666655555556666055555505556666666666666666665555556665500777700055555005005555066666666
11111111111111111110000000111100cccccccc6665555005556666556766555555666666666666666655555566666507000070555555555555555566666666
11111111111111111100000001111110cccccccc6665550000555666567766650556666666666666666665505556655570000007555555555566555566d66666
01111111111111101100000011111111cccccccc6655500000055556577666755556666666666666666665555566665570000007555666556666655566666d66
00111111111111001100000011111111cccccccc5555000000005556567777755555666666666666666655555666655570000007556666666666655566666666
00011111111110001100000011111111cccccccc55500000000005555667666505556666666666666666655055566665700000070566dd666666655566666666
00001111111100001100000001111110cccccccc55000000000000555567665555566666666666666666555555666555070000700556dd666d66555066d666d6
00000111111000001100000000011100cccccccc5000000000000005055555505556666666666666666665555556665500777700555666666666555066666666
11111111111111110000000000111100111111115000000000000005000440005566666d66666666dd6666555566655500333300055566666666655500000000
111111101111111100000000011111001111111155000000000000550d4444d05556666666666666dd6666555556655503000030055566d666dd655000000000
11111000001111110011100000111100111111115550000000000555ddd55ddd55666666666666666666655555666655300000035556666666dd665000055000
11110000000111110011110000111100111111116555000000005555cddddddc5556666666566666666655555556665530000003555666666666665500555500
11110000000001110111110000111100111111116555500000055566ccc6cccc5556666666566665666655555566655530000003555666665566655505555550
11100000000000110111111000111110111111116665550000555666cc6c6ccc5555665655555555656555555556655530000003555566555555555500022000
11000000000000111111111100111100111111116666555005555666c6ccc6cc5555555555555555555555555555555503000030555555555555555500022000
1100000000000001111111110011110011111111666655555556666dcccccccc0555555550550555555555500555555000333300055550050055555000022000
10000000000000111111111100111100000000000555555555555555555555500555555555555555555555500555555000000000000000000000000000000000
11000000000000111111111101111110000000005555555555565555555555555555555555555555555555555567665500000050000000000000000000000000
11000000000001110111111011111111000000005556565656566565556655555556665555555555566665555677066555500565000000000000000000000000
11100000000011110011111011111111000000005566666666666666666666555566666556555566666666555770067550050005000000000000000000000000
11111000000011110011110011111111000000005566666666666666666666555566666666555565566666555600007550000075500000750000000000000000
11111100000111110001110001111110000440005555665566666666656565555556666555555555556665555660666556005065565550650000000000500050
11111111011111110000000000111100004444005555555565666565555555555555555555555555555555555567665556600655565005555050000505550555
11111111111111110000000000011000000550000555555555555555555555500555555555555555555555500555555055656655556565665555550500400040
9696969696f5959596959596969696f5363536b6005000000010b5757575750094a4545464b500002436250000005085f4969696969696f596969696969696f5
959696969696959595969596969695950043000000000000000200000000b0000000000000000000000000000000000002020202020202020202020202020202
5474061646d695a654d6a6543754548536b43600007500001787b6757575876795a5100000b500002436250000849495a5000005140000b61000003716753285
a600360024366596552474000000d695a10200000000000000020062000000000000910000000000000000000000000002020202000000000000000000000032
910507174615b500000024250000918536869774a77500041536257475640024f595e50000b5000024362500006595f5a5918494a71400d5e526260017750085
000036002436000000242500000044d6620202000002020202020202000000000275757575757575757575757500000002020200000000000000000000000000
946767677700b57400002425876797f5362536b67575757500362500746200249595a50004b654545454643500006595f56796a6000514d6e646467475755796
50003626243600004724252600000000020000000000000000000002020000000000000000000000000000007500007502330000000000000000000000020202
a55454545454b5747400041400876785a775b475757575757574250000b4072495955504461500002436253600000085a575750000047406002727167575d594
94946767677400007467949494a46444000000000000001000000000000000000000000010757575750000007500000002001000000000000000020200454545
a50024d56767976767e50515004362853625b57575757400000075644485772495a50446150000002436252700000085a533750017b4360000000000758495f5
95a51405142500000016d695f5a50000000002020000027575020000000000020000000075a0a0a0a07500007500000002020200000000000002020000450202
a50057e60415b50514b6041400d594956767a6171500a0b0b0b0000074b60024f5a54615001707912436252600000085a500755016b636000000000087969695
95a61607161400000017068695a50000000000000002023233020200000002000000007500a00000a00075007575000002000000000000000000000000450202
a50000041500b600051405150085f595460617060000a00000a000000035008795a61500174646d5e536253600007585a5747574001646072635261746461485
a6000005140514211706001685a50000000000000202020000020202000000000000007532a00000a03375007500000002000000000202020202020000450202
957704150000750000051447b4659595060415000074a0a0a0a0750017461400a5757562164674d6e674253662757485956797a7a167a4151684676767676795
0700000016148494a454545486a60000020000000002020202020200000000000000007500a00000a00075007500000002000000000000000000000000450202
a50415000010755000d5d4a4b54465950457a735000075000075001775846767a57575576797676767976797976767f595e646150005b50000b5000446159185
061000000084959695a4350000003233000200000000020202020000000200000000000074a0a0a0a07400007500007502000000000000000000000002450202
a5150057676797676795f5a5b644006506430074000000000000005797a63233a5757575004300750036750016061685e6461500b400867700b604b41500d595
07171426849555006595a42600000000000000000000000202000000000200000000000000757575750000007500000002025000000000000000000000450202
9577470005157533328595e61607003767a43562740026000000007575430000a574757547747575753674751707178546150700b5000043000446b5004785f5
676797679655000000659667676767a4000000000000000202000091020200927474000000000000000000007500000002020202020276767676767676450202
a500b4002425750000d6a6000016070000866767676777545484679767679767959767676797676797679767a77575851500879767676767676767a600d59595
a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a250000002a202020202a2a2020200000275757474747474a1747575757574000002020202020245454545454545450202
a55485a42425879767a7000026001607002425361607000000b6164646063600a53233007536007575007505147475854100001607a000044606a0000085a3a3
9595b38696969595959696969696969602020202a3a3a30202a3a3a3020002020000000000000000000000000000000002020202024545454545454545450202
a5008595a414004362b500353600001691242536001607750000174646073692a5000074753675757475757505147585a4000062160717460600a0006285a302
95f5b30000008696a600000000000000a3a3a3a3a3a3a30202020202020002a30050620000000074000000000000006202020202024545454545454545450202
9594f5f595e4e4e494a5003636260000e4d494e4d494d4e4d494e494d494e494959494949494949494949494949494f595949494a40446060000a0d59495a302
9595b3a2a2a2a2a2a2a2a28494949494b3b3b3b3b3b3b30291910000430002a30202020202020202020202020202020202020202454545454545454545450202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
74747474747474747474747474747494940202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020210000000000000000000000000000202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020202020200000002027500000000500202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200000000100000005000000000000000
02000000000000000000000000000002020000000000000000000000000000020275750000000000007575750202020202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000200740000740074007400007400740000
02000000000000000000000000000002020000000000000000000000000000020275757500000000007575750000000202000000c4c4c4c40000000000000002
02000000c4c4c400000000000000000202000000c4c4c4c400000000000000020200000000000000000000000000000200740000740074007400007400740000
02000000000000000000000000000002020000000000000000000000000000020275757502020200000202020000000202000000c40000c40000000000000002
02000000c400c4c4000000000000000202000000c40000c4c4000000000000020200000000000000000000000000000200740000740074007400007400740000
02000000000000000000000000000002020000000000000000000000000000020202757500000000000000000000020202000000c4c4c4c40000000000000002
02000000c40000c4000000000000000202000000c40000c4c4000000000000020200000000000000000000000000000200747400747474007474007474740000
02000000000000000000000000000002020000000000000000000000000000020200627575000000000000000062000202000000c40000c4c400000000000002
02000000c4c4c4c4000000000000000202000000c4c4c4c400000000000000020200000000000000000000000000000200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200020275750202020200000202000202000000c4000000c400000000000002
02000000c40000c4c40000000000000202000000c40000c4c4000000000000020210000000000000000000000000500200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020200000000000000000000000000000202000000c4c4c4c4c400000000000002
02000000c4c4c4c4c40000000000000202000000c4000000c4000000000000020202020276767676767676760202020200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020202750000000000000000000075020202000000000000000000000000000002
0200000000000000000000000000000202000000c4c4c4c4c4000000000000020245454545454545454545454545450200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020275750202020200000202020275750202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020245454545454545454545454545450200000000000000000000000000000000
02000000000000000000000000000002020000000000000000000000000000020275757533000000000000327575750202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020245454545454545454545454545450200000000000000000000000000000000
02100000000000000000000000005002020000000000000000000000000000020202757500000000000000007575020202000000000000000000000000000002
02000000000000000000000000000002020000000000000000000000000000020245454545454545454545454545450200000000000000000000000000000000
02020202020202020202020202020202020202020202020202020202020202020202020202000000000000020202020202020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000
__label__
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
8888822222288ffffff8888888888888888888888888888888888888888888888888888888888888888228228888228822888fff8ff888888822888888228888
8888828888288f8888f8888888888888888888888888888888888888888888888888888888888888882288822888222222888fff8ff888882282888888222888
8888822222288f8888f8888888888888888888888888888888888888888888888888888888888888882288822888282282888fff888888228882888888288888
8888888888888f8888f8888888888888888888888888888888888888888888888888888888888888882288822888222222888888fff888228882888822288888
8888828282888f8888f8888888888888888888888888888888888888888888888888888888888888882288822888822228888ff8fff888882282888222288888
8888882828288ffffff8888888888888888888888888888888888888888888888888888888888888888228228888828828888ff8fff888888822888222888888
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000088888800000000000000000000000000222222000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000888888880000000000000000000000002222222200000000000000000000000000000000000000000000000000000000
000000000000000000000000000000008899999800000000000000000000000022222f2200000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000899ff9f90000000000000000000000000229ff9200000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000089fc9fc9000000000000000000000000022ffff200000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000089fff900000000000000000000000000121d10200000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000088880000000000000000000000000001dddd0000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000004004000000000000000000000000000140040000000000000000000000000000000000000000000000000000000000
00000000055555500000000000000000055555500000000005555550000000000555555000000000000000000555555000000000055555500000000000000000
00000000555555550000000000000000555555550000000055555555000000005555555500000000000000005555555500000000555555550000000000000000
00000000555665550000000000000000555665550000000055566555000000005556655500000000000000005556655500000000555665550000000000000000
00000000556666550000000000000000556666550000000055666655000000005566665500000000000000005566665500000000556666550000000000000000
00000000556665550000000000000000556665550000000055666555000000005566655500000000000000005566655500000000556665550000000000000000
00000000555655550000000000000000555655550000000055565555000000005556555500000000000000005556555500000000555655550000000000000000
00000000555555550000000000000000555555550000000055555555000000005555555500000000000000005555555500000000555555550000000000000000
00000000055555500000000000000000055555500000000005555550000000000555555000000000000000000555555000000000055555500000000000000000
00000000055555500000000000000000055555500000000005555550000000000555555000000000000000000555555000000000055555500000000000000000
00000000555555550000000000000000555555550000000055555555000000005555555500000000000000005555555500000000555555550000000000000000
00000000555665550000000000000000555665550000000055566555000000005556655500000000000000005556655500000000555665550000000000000000
00000000556666550000000000000000556666550000000055666655000000005566665500000000000000005566665500000000556666550000000000000000
00000000556665550000000000000000556665550000000055666555000000005566655500000000000000005566655500000000556665550000000000000000
00000000555655550000000000000000555655550000000055565555000000005556555500000000000000005556555500000000555655550000000000000000
00000000555555550000000000000000555555550000000055555555000000005555555500000000000000005555555500000000555555550000000000000000
00000000055555500000000000000000055555500000000005555550000000000555555000000000000000000555555000000000055555500000000000000000
00000000055555500000000000000000055555500000000005555550000000000555555000000000000000000555555000000000055555500000000000000000
00000000555555550000000000000000555555550000000055555555000000005555555500000000000000005555555500000000555555550000000000000000
00000000555665550000000000000000555665550000000055566555000000005556655500000000000000005556655500000000555665550000000000000000
00000000556666550000000000000000556666550000000055666655000000005566665500000000000000005566665500000000556666550000000000000000
00000000556665550000000000000000556665550000000055666555000000005566655500000000000000005566655500000000556665550000000000000000
00000000555655550000000000000000555655550000000055565555000000005556555500000000000000005556555500000000555655550000000000000000
00000000555555550000000000000000555555550000000055555555000000005555555500000000000000005555555500000000555555550000000000000000
00000000055555500000000000000000055555500000000005555550000000077777777770000000000000000555555000000000055555500000000000000000
00000000055555500555555000000000055555500555555005555550000000070555555075555550000000000555555005555550055555500000000000000000
00000000555555555555555500000000555555555555555555555555000000075555555575555555000000005555555555555555555555550000000000000000
00000000555665555556655500000000555665555556655555566555000000075556655575566555000000005556655555566555555665550000000000000000
00000000556666555566665500000000556666555566665555666655000000075566665575666655000000005566665555666655556666550000000000000000
00000000556665555566655500000000556665555566655555666555000000075566655575666555000000005566655555666555556665550000000000000000
00000000555655555556555500000000555655555556555555565555000000071556555575565555000000005556555555565555555655550000000000000000
00000000555555555555555500000000555555555555555555555555000000017155555575555555000000005555555555555555555555550000000000000000
00000000055555500555555000000000055555500555555005555550000000017715555075555550000000000555555005555550055555500000000000000000
00000000000000000000000000000000000000000000000000000000000000017771777770000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000017777100000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000017711000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000001171000000000000000000000000000000000000000000000000000000000000
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
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88282888882288222822288888282888882228222822288888888888888888888888888888888888888888888888888888888888888888888888888888888888
88282882888288882828288888282882882828288828888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88828888888288222828288888222888882828222822288888888888888888888888888888888888888888888888888888888888888888888888888888888888
88282882888288288828288888882882882828882888288888888888888888888888888888888888888888888888888888888888888888888888888888888888
88282888882228222822288888222888882228222822288888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

__gff__
0000000000000000000001020202020200009000000000000000919002020202818080000000808000000200020202028500000091908004000002010202020280808002808080010101010100010101808080800101018901010101000101018080808080010101010101010001018080808080800101010101018080808000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
565959595a6859655669595959595f595959595f5959595965665959595969695f594f4f69695959596969694f4f4f4f596556696969555655404140585955564f4f696969696969696969694f4f4f4f595959593a59595959595959593a5959595f593a3a5a00000058593a3a5959595f5959595959595959593a5959593a59
665556595f4a58596547685959595959565959595969695959595f595955006f594f4f5500005659556300006d4f4f4f59596500000000004478767a585f65664f5a00004252234064606133584f5556585f59593a3a3a3a5959593a3a3a59593a3a3a3a3a5a00000068593a3a3a3a593a3a3a59595955565f593a5959593a59
59656659595a5859596547685959596e005859696a425268596959595a6262484f4f6a000000005b0063004064684f4f59595965757649496547474758595a595f5a00004252006464707100585f6566595959595959593a3a3a3a3a59595959595f59593a5a01620000585f3a3a3a3a59593a3a5959656659593a3a59593a59
58595959595a585f5959654758596e6600586a52004252616b6358596a6464584f5572000053006b0073406464646d4f565959596500564f5949494959595a48696a006f425247506464647869595f5959555659595959595959593a3a3a3a595f593a593a59494a700068696969593a5959593a59595f5959593a3a3a3a3a59
58595959595a5859595f5965566a6659006b4252004041000063585a606148695a000000006300720000506464606158665f5959596562565f59595959595a586451004742520000614751006356595f59656659695969595959696959593a59593a3a593a3a3a5a61700000006368595959593a3a59593a3a3a3a593a595959
5959595f595a58595959594f6566595900004252006160000063585a70716b005a41000000630000404100506470715859595959595949655659595959595a58510000007170006f47720000630056596859595a005b4268595a000058593a3a593a3a3a3a3a3a5a0561700000630058595959593a3a3a3a595959593a3a5959
59595959596e585959595959595f595900004252000000000073586a505100005a51000000637f40645100006164645859695969695959596556695959696a68000000005051004700000000730000680058695a006b4041685a000068695959593a5f596969697679767700006300583a3a3a3a3a59595959595959593a3a3a
5f5959596e00565959686969695959596f0540410000000000006b00000000005a6200000063487a51000000006164585a006b6464686969697a63586a520000000000004b6200000073000000004051005b006b00005051006b000063006859593a596a00626f4252007200007300585959595959596959695959595f595959
6869596e004041565a007164646d595949494a510000000000000000000000005a47000000486a5100006f53000050586a000050646061645100636b4252002370000000584a74000063000000405100006b7000000000000063000063000058593a5a00007576797676494a005300585f5969595955005b5158596969696959
00005b00005051005b71606164516d6969595a000000000000000000000000335a230000405b510000004b6300003358337000005070715100007300424746006470000068697a00006300004051000000006170000000000063006f7300005b593a5a00006300404100586a00630058596a73565500406b716d6e5100003358
00006b00004252005b6170715100720063685a41000000000000006200006f005a000540486a00000000684a0001005800647001006160006f0053004252054b6464700100007f62006300405105717000000072620000000063004b0000335b5f3a597f0063005051006b52006300585a007300007160716040510000000058
0000630000425200470061510000000063006b51000000530000405100005d49594949496a000000000000684d4d4d594949494a00787a0048494a00484d4e594d4d4e4d76767976767679764d4d4e4e7a7f0000630100000073005b000000583a3a594a00630040410042520048495f5a05737f405171604051005347474859
000063000042520047000000000000007300630000000063004051000075695f5f5959592a2a2a2a2a2a2a2a595959595959595a0071707458595a6f585959595f59696a000000000000000068595f59007876797679767a000000584d4976593a3a5f594a63005051004252485f2a2a597676767976767676797679797a6859
0000636f004252234b330000000000050000630000627463405100530000235859593a3a3a3a3a3a3a3a3a3a3a3a59593a3a5959494949495959594959593a3a59592a2a2a2a2a2a2a2a2a2a2a2a595900000000630078797a007869696a23583a3a59595a63000000004248593a3a3a5a014060716040510000006300002358
0100635d5e4252006b000062006f757600006301004d4d4e5100006300000058593a3a3a3a3a3a3a3a3a3a3a3a3a3a59593a3a3a3a3a3a3a3a3a3a3a3a3a3a59593a3a3a3a3a3a3a3a3a3a3a3a3a3a5905000000630074720000000000610058593a3a3a5a234b2a2a4b33583a3a3a595a40517160405d495e007463006f0058
4d4e4a6d6e484d4e474d4d4e4d4d494d4d4d4e4e4d4f4f4f594e4d4d4e4d4d595f5959595959595959595959595959595959593a59595f3a5f3a5959593a59593b3b3b3b3b3b3b3b3b3b3b3b3b3a3a3a594e4d4d4e4d4e4d4e4d4d4d4e4d4d59595f3b3b5a005b3b3b5b00583b3b59595f494949494959595f49494949494959
5a00405161645b000063000042586a2a59596a600071600000000040646061585a5200004041000063000071606d69595f596969696959595969695959596959596a600000007160005041006d593a3a593a59595969696969696969595f596500405161700a0000335b47000040606172724064514041010561647071605733
5a40510000615b000063000042583a3a596a60007160010040410550647071585a52000050510000630071600061645859550040606168696a63616d696e42586e6000000071600000005041006d593a3a3a59596a41000042520000685959594051000061700001005b000071647071267164600050515d5e00616460535700
5a517f0500005b000063010047593a3a5a60005d4d494d4e76797676767976795a524b004252000073716000050061585a0140647071510000630061700042586000740171604b00004b00504105583a3a595f5a0050417f4252000019585f59510048767679767676797a40604b6460494949494a40416d6e00716448494d4d
5949494a00005b410048494959593a3a5a00716d6969696e42520000000072005a52584a4252010071600000754949595a40646464517f0000635305617042584976767676765a45455b005d767669695959595a004051754977444675593a3a00005b000000340000007160475b51785f59595f5a606164707164756959595f
5f59595a00005b504158595f593a3a3a6a7160000000006342520000000000005f79696976767679770000000068595f594e4d4e4d4e5e46445d4e4e4d4e4d596a00716000475b00005b005b23330063595f595a405100005b52000000583a5947005b000048767976767976795b0000595969696e0000616464646464686969
6969696a00006b005068696959593a3a767676767976767679767676797a00005a520000006300007200000000406859593a3a3a3a3a5a0000585f5959593a3a007160536f475b00005b005b007f006359595959774545455b45454545583a5970005b7a445b454545454545455b4600696a5757000000006164646464700000
47006352000053000050410058593a3a405142520000007164700000004445455a4545454563454600006200405119585f595959593a5a70005859593a3a3a597160007876766e4545687969764a0047595f595a520000005b52006f75593a3a61705b63005b007876764977005b7a0023575757575700007147646061477026
474763526f0063000000504158593a3a510042520000716061600000000000405a524b00005300000000634048494959593a3a3a3a3a5a617058593a3a593a59600000630000000000000000005b45455659595a525300755a5200757659593a00785b63785b00197f635b00005b0000005757575757575748494a7071484949
4949494949494949494a005058595f3a460042527f487676764a0000000000615a525b1a484979767676767969696959593a59595f595a0061583a3a3a593a5f7a454663006274000040417f00587a006659595a526300005b5200007158595f00005b63006876767a635b00785b00194e4d494d494e4d495959594e495f5959
2a2a2a5959595f59595a00005859593a29004252756a00616058492a2a2a4d495a525b00686e00000063000040512358593a3a3a3a3a5a0071583a593a593a592a2a4d4976764a000048797a005b635359595f5977636200584a007160585f596f005b470000426352635b00425b4578595f5969696969595f5969696959595f
59593a3a59595959595a00005859593a47454545454653000068593a3a3a3a595a525b006300000000630040517f0058593a5959593a5a7160583a593a593a3a3a3a3a5a60475b00005b7261415b63473a3a595500636300585a716000585955470058767679767976766977425b00005f595540646441566955006352565959
595f3a3a3a3a5f59596a00006859593a630042526200636f0000583a3a3a3a3a5a52584a63000000004b40515d4949593a3a5f593a3a5a6000583a593a595f595f3a3a5a70735b00625b6244475b63735f3a5a0000636347595a47005358596500005b617000000042520000425b53005955716451616470000000635241565f
593a3a595f3a59596a4445454568593a2a2a2a78794a63787a00686969593a3a5a525859492a472a2a6b2a75595f5959595959593a595a0000583a593a3a59596969696e60295b00635b4719485f7a70593a5a00007579765f5977056358595900006b476170007f42520000486b470055716464417164600000006352504156
593a5959593a595a330000000023583a3a3a3a3a3a5b63233340510000583a3a5a3358593a3b3b3b3b3a3b3b59595959595f3a3a3a595a2333583a59593a3a3a6061604445756e00636d7976696e6061593a5a74013400335b23347147583a3a707879797a61705d767976766a00004000616464646464410000006352005041
3a3a5f59593a595a007f00620000583a3a3a3a3a3a5a63000051000044583a3a5a00583b3b3b3b3a3b3b3b3b3b3a5f593a3a3a593a595a0000583a59593a595f70717000000074006300006f347200475f3a594d4d4a19005b005d4d49593a5f617034005300615b23056f005300406400006164646464600000006352410050
59595959593a59594949494949495f593b3b3b3b3b59494949494949495f3b3b5949593b3b3b3b3b3b3b3b3b3b3b3b593b593b593b59594949593b5f593a3a594d4e4d4e4e4d4e4d4d4d4d4e4d4e4d49593b59595f5949495949595f593b3b594e4d4e4d4d4e4d6b004e4d4e4d4d4e4d00000050646464700000006352504100
__sfx__
a100000034670250701f0701a070170701507013070100700f0700c0700a07008070070700507004070040700c4100c4200c4300c4400c4500c4600c4700c4700c4700c4700c4700c4700c4700c4700c4700c470
000110202456024550245402453018730187401875018760187601876018760187501875018750187501875018742187421874218742187421874218742187421875218752187521875218752187521875218752
30011c20346700d07007070020703c6603c6503c6503c6403c6403c6403c6303c6303c6303c6303c6303c6203c6203c6203c6203c6203c6203c6203c6203c6203c6103c6103c6103c6103c6103c6103c6103c610
0000000034670250701f0701a060170601505013050100500f0400c0400a03008030070300502004020030200201001010000151f0001a0001700015000130000c4000c4000c4000c4000c4000c4000c4000c400
302400002473424732247322473224732247322473224732257342573225732257322673426732267322673227734277322773227732277322773227732277322473424735247002470035710357203573035740
3224000020734207322073220732207322073220732207321c7341c7321c7321c7321d7341d7321d7321d7321f7341f7321f7321f7321f7321f7321f7321f73220734207351d7001d70010b3010b4028a5010b60
44240000299502b950299502c950359503395033722337222e9502c9502b9502b7222b7122b7122b7122b712249502595027950277222771227712299502473124950247222471224712309502e9502c9502b950
8c240000293462533620326183161d31619326143360c3462b34627336223261f3161f3161b32616336133462b34627336243261f3161f3161b32618336133462c3462933624326203162b316273261833614346
c4240000144421444518432184351d4321d43519432194351844218445194321943515432154351943219435164421644519432194351d4321d43519432194351f4421f445204322043524432244351b4321b435
c42400001b525144321443518422184251d4221d42519422194251843218435194221942515422154251942219425164321643519422194251d4221d42519422194251f4321f435204222042524422244251b422
d02400000d1150d1250d1350d1450d1550d1450d1350d12505115051250513505145051550514505135051250a1150a1250a1350a1450a1550a1450a1350a1250311503125031350314503155031450313503125
d224000030014300123001230012300123001230012300122c0142c0122c0122c0122c0122c0122c0122c01229014290122901229012290122901229012290122e0142e0122e0122e0122e0122e0122e0122e012
c4240000145221452518522185251d5221d52519522195251852218525195221952515522155251952219525165221652519522195251d5221d52519522195251f5221f525205222052524522245251b5221b525
c424000000000145121451518512185151d5121d51519512195151851218515195121951515512155151951219515165121651519512195151d5121d51519512195151f5121f515205122051524512245151b512
c02400000d0150d0150d0150d0150d0250d0250d0250d02505015050150501505015050250502505025050250a0150a0150a0150a0150a0250a0250a0250a0250301503015030150301503025030250302503025
c0240000144121441518412184151d4121d41519412194151842218425194221942515422154251942219425164221642519422194251d4221d42519422194251f4321f43520432204351f4321f4351b4321b435
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
332400003f6253f6003e6453f6003f6003f6253e6453f6253f6003f6003e6453f6003f6003f6253e6453f6253f6253f6003e6453f6003f6003f6253e6453f6253f6003f6003e6453f6003f6003f6253e6453f625
34240000209501d930249531d930299531d930259531d930249501f930259531f930229531f930259531f930229501f930249531f930279531f930249531f93029950209302c953209302b953209302795320930
34240000209501d930249531d930299531d930299531d9302b9501f9302c9531f9302b9531f930279531f9302b9501f9302c9531f9302e9531f9302b9531f9302b950209302c9532093030953209302995320930
d424000000000209301d910249331d910299331d910259331d910249301f910259331f910229331f910259331f910229301f910249331f910279331f910249331f91029930209102c933209102b9332091027933
d424000020910209301d910249331d910299331d910299331d9102b9301f9102c9331f9102b9331f910279331f9102b9301f9102c9331f9102e9331f9102b9331f9102b930209102c93320910309332091029933
0024000020734207322073220732207322073220732207321d7341d7321d7321d7321d7321d7321d7321d7321f7341f7321f7321f7321f7321f7321f7321f7322073420732207322073220732207322073220732
302400002473424732247322473224732247322473224732257342573225732257322573225732257322573227734277322773227732277322773227732277322773427732277322773227732277322773227732
002400003075033700337002e75000000000002c7500000000000000000000000000000000000000000000003075000000000002e75000000000002c750000000000000000000000000000000000000000000000
9024000014040000002004000000140400000020040000000d0400000019040000000d0400000019040000000f040000001b040000000f040000001b040000001404000000200400000014040000002004000000
312400003074030720307102e7402e7202e7102c7402c7202c710000000000000000000000000000000000003074030720307102e7402e7202e7102c7402c7202c71000000000000000029714297222973229742
90240000140400000020040000001404000000200400000015040000002104000000160400000022040000000f040000001b040000000f040000001b04000000140400c000200000500005410054200543005440
0605000c166301864018630176401663015640166301864019630196401763016640196300b6400163001600126552e65501600226552a6550260002600016000060001600016000060001600026000160000000
0679010f016300164001630016400263000650126552e655036200163001620026300a650226552a65501600126552e65501600226552a6550260002600016000060001600016000060001600026000160000000
320400000202005030080400c05010050160501805003020080300d040140501a0501d050080100a0200b0200c0300e0301003013030170401b0401f040250502c05031050350503c0603c0503c0413c0313c021
000300001904314043100430b0430304315043110430b043050430a04305043030430004300003090030900309003090030900309003090030900309003090030900309003090030900309003090030900309003
22030000027510275102751027510475105751097510c7510f76114771187711b7711e771207712177121771207711f7711d7711a7711877115761127510f7510d7510b751087510775106751057510475103751
280400200705005051030310102101031000510005100051010310402105031070510a0510d05110031120211503117051180511805117031150211303111051100510e0510d0310b02109031070510605104051
000400003e06338655340552d64028045256532f0452b6432804326033226351e0531b64518043280352563322033206331a0351764316635220331c62516013116130e0130b6150701307015046100101501615
340200000f6400f6300c6200a6100a610076100761003610056100a6100f62013620166201b6201f63024630286302b6402d60001600016000160001600016000160000600006000060000600006000060000600
00030020017400174101741027410374105741087410b7410e7411075112751137511475115751157511575115751157511475114751137511275111741107410d7410c7410a7410874105741037410174100741
000300003b52436521315312c5312854125551225511f5411d5411a541185411553113531115310f5210d5210c5210a5110951108511065110551104511045010350103501025010250102501015010150101501
00020000007540075100751007510075100751017510175102751047510575107751087510a7510c7510d7410f741117411374115741187411a7411d7311f7312273125731277312b7312f72133721397213d721
000400101073610731127311373114731167311773118731187311873117731157311373112731107310f7310d7310d7310d7310d7310f7311073112731137311473116731167311573114731137311173111731
000b000013710167101871013720167301874013750187101b7101d7201f7301b7401d7501f71022720247201f7302274024740297502b7502e750267002e7401f7002e720347002e710300002b7003000030000
000100000254002540025400454006540095400b5400e5401054012540145401555016550175501755017550165501555013550115500e5500c5400b540095400854007540065400554004540035400254002540
000200000c5401054014550195501e55022560265602a56016540185401b5501f5502256026560295602c5402e5401e540215502455026550295502b5502d5502f560315603456037560395603c5703e5703f570
000200000904108031090210c0210e0311203115041190411c04123051270510a6000a601126011e60126601186001a6001c6001d6001c6001a60018600186001a6001c6001d6001c6001a600186001a6001c600
06ff0000136453a675396051d605396052d6052e6052a6052d6052c6052b60529605226051a605136050d60507605036050060517605126050d60506605026050060501605016000060001600026000160000600
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
03 192b4b4c
03 0a0a0b4c
03 24234b4c
03 2d234b4c
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

