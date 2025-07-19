pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

	
-- menuitem(3, "music on/off", function() 
-- 	music_object[3] = not music_object[3]
-- 	if not music_object[3] then music(-1) else music(music_object[2]) end
--  end)
-- menuitem(4, "sfxs on/off", function() sfx_enabled = not sfx_enabled end)
menuitem(1, "next lvl", function() next_room() end)
-- menuitem(2, "pass 5 lvls", function()
-- for i=1,5 do
-- 	next_room()
-- end
-- end)


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
	dflt_delay_switch = 5 --frames
	delay_switch = dflt_delay_switch
	sfx_timer = 0
	pulsator_state = false
	anim_timer = 0
	shake = 0
	music_object = {false, nil, true}-- {bool = change music, value = music pattern, bool = music on/off}
	sfx_enabled = true
	game_state = 0 -- 0 = title, 1 = game, 2 = restart_level, 3 = end
	pulsator_room = 17
	fountain_room = 25
	deaths = 0
	power_counter = 0
	finish = "" -- if easy or hard chosen
	--!! DEPLOIEMENT
	title_screen_dur = 60
	title_screen_anim = false
	end_on = false
	end_game_dark = 120
	sfx(10)
	-- !! FIN DEPLOIEMENT
	--!! TEST
	-- game_state = 1
	-- next_room(128 * 0, 128 * 0)
	-- super_lulu = true
		--!! FIN TEST
end

function _update()
	frames=((frames+1)%30)
	if game_state == 0 then
		if btnp(❎) and not title_screen_anim then
			title_screen_anim = true
			sfx(-1)
			sfx(46)
		end
		
		if title_screen_anim then
			title_screen_dur -= 1
			if title_screen_dur <= -30 then
				title_screen_anim = false
				game_state = 1
				create_room()
			end
		end
		return
	end

	if anim_timer > 0 then
		anim_timer -= 1
		return
	end

	if game_state == 2 then
		restart_level()
	else
		update_game()
	end
end

function _draw()
	if game_state == 0 then
		cls()
		print("lulu's quest", 40, 28, 10)
		print("   appuyez sur\n\n        ❎\n\npour lancer le jeu", 28, 54, 7)
		print("donovan goudal\n\n    flieen", 36, 96, 13)
		
		if title_screen_anim then
			fade_in(title_screen_dur, 30)
		end
		return
	end

	pal()
	cls()
	if game_state == 3 then 
		draw_end()
		if end_game_dark < -60 then
			cls(0)
			pal()
			draw_end_text()
			return
		end
	end
	camera(camx, camy)
	-- screenshake
	if shake>0 then
		shake-=1
		if shake>0 then
			camera(-2+rnd(5)+camx,-2+rnd(5)+camy)
		end
	end

	map(0, 0, 0, 0, 128, 64, 0)
	draw_lights()
	draw_objects()
	draw_walls()
	map(0, 0, 0, 0, 128, 64, 3)
	map(0, 0, 0, 0, 128, 64, 0x10)
	-- Doors
	draw_doors()
	draw_chars()
	map(0, 0, 0, 0, 128, 64, 0x80)
	foreach(butterflies, function(b)
		draw_butterfly(b)
	end)
	draw_acristals()
	-- draw outside of the screen for screenshake
	rectfill(-5+camx,-5+camy,-1+camx,133+camy,0)
	rectfill(-5+camx,-5+camy,133+camx,-1+camy,0)
	rectfill(-5+camx,128+camy,133+camx,133+camy,0)
	rectfill(128+camx,-5+camy,133+camx,133+camy,0)
	draw_ima_range()
	draw_ui()
	draw_messages()
	draw_display()
	debug_print()
end

function update_game() 
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
	if game_state == 3 then 
		end_screen()
	end
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
	has_cast_bl = false
	FRICTION = 0.8
	accel = 0.6
	JUMP_VELOCITY = -2.5
	MAX_DX = 2
	super_lulu = false
	chars = { lulu, hades }
end

function draw_chars()
	--anims
	pactual.sprite = pactual.default_sprite
	if not pactual.on_ground then
		pactual.sprite = pactual.default_sprite + 3
	elseif pactual.dx > 0.2 or pactual.dx < -0.2 then
		pactual.sprite = frames % 8 >= 4 and pactual.default_sprite + 1 or pactual.default_sprite
	end
	--if they already in current room
	if game_state == 2 then
		if not lulu.in_light then 
			lulu.sprite = 16
		end
		if hades.in_light then hades.sprite = 17 end
	else
		foreach(chars, function(c)
			if not (c.passed) then
				c.sprite = pactual == c and c.sprite or c.sprite_hide
			else c.sprite = 0
			end
		end)
	end
	if super_lulu then
		--hairs | 9 orange to pink 14
		--coat | 8 red to purple 2
		--eyes | 12 blue to green 3
		--feet | 4 brown to red 8
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
		if is_ending() then
			return
		end
		switch_characters(pactual)
		return
	end

	if casting_bl then
		using_light("orb",pactual)
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
		if not pactual.using_light and not has_cast_bl then move_characters(c) end
	end
	if has_cast_bl then has_cast_bl = false end
	
	if check_flag(1, pactual.x + 4, pactual.y) then
		game_state = 2
		sfx_timer = 45
		fsfx(53,3)
		return
	end

	--COLLISIONS LIGHTS--
	---------------------
	for i=1, #chars do
		local c = chars[i]
		local c_in_light = false
		for dl in all(dynamic_lights) do
			if collision_light(c, dl) then
				c_in_light = dl.type == "white"
			end
		end
		for l in all(lights) do
			if collision_light(c, l) then
				c_in_light = true
			end
		end
		
		if c == lulu and c.shield.active then c_in_light = true end
		
		for b in all(butterflies) do
			if b.light == "white" and collision_light(c, b) then
				c_in_light = true
			end
		end
		
		
		local c_shield = c == lulu and hades or lulu
		if c_shield.shield.active then
			c_shield.shield.timer -= 1
			if c_shield.shield.timer <= 0 then
				disable_shield(c_shield)
			end
			if collision_light(c, {x = c_shield.x or 0, y = c_shield.y or 0, r = c_shield.shield.r or 0}) then
				c_in_light = true
			end
		end

		if c == hades and c.shield.active then c_in_light = false end
		
		for bl in all(black_lights) do
			if collision_light(c, bl) then
				c_in_light = c == lulu
			end
		end

		for b in all(butterflies) do
			if (b.light == "grey" or b.light == "dark" or b.light == "black") and collision_light(c, b) then
				c_in_light = b.light == "grey" or (b.light == "dark" and c == hades) or (b.light == "black" and c == lulu)
			end
		end

		for gl in all(grey_lights) do
			if collision_light(c, gl) then
				c_in_light = true
			end
		end

		c.in_light = c_in_light
	end


	local condition_1 = not lulu.in_light and not lulu.passed
	local condition_2 = hades.in_light and not hades.passed
	if condition_1 or condition_2 or pactual.y >= room.h-1 then
		anim_timer, game_state, sfx_timer = 30, 2, 45
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
end

function move_characters(c)
	--handle input
	local move, jump = 0, btn(❎) and not pactual.c_jump
	pactual.c_jump = btn(❎)
	move = btn(⬅️) and -1 or btn(➡️) and 1 or 0
	if move ~= 0 then pactual.flipx = (move == -1) end
	if jump and pactual.on_ground then
		pactual.dy, pactual.on_ground, pactual.is_jumping = JUMP_VELOCITY, false, true
		psfx(62, 3)
	elseif (not btn(❎) or c.dy > 0) and c.is_jumping then
		c.dy += c == lulu and 0.05 or 0.1
	end
	if c.dy > 0 then c.on_ground = false end

  -- 2) apply horizontal acceleration & friction
	pactual.dx = mid(-MAX_DX, pactual.dx + move * accel, MAX_DX) * FRICTION
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
		c.dx, c.dy = 0, 0
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
		lulu.using_light, hades.using_light = false, false
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
		ima_light.y, ima_light.x = lulu.y_g, lulu.x_g
		lulu.using_light = true
		if super_lulu then psfx(52,3) else psfx(58,3) end
	end
	using_light("classic",lulu)
end

function update_light_hades()
	-- hades a une variable qui stocke temporairement la light selected
	if #lights > 0 and hades.powers_left > 0 then
		if not hades.using_light then
			psfx(55,3)
			hades.using_light = true
		end
		local index = hades.light_selected[2]
		hades.light_selected[1] = lights[index + 1]
		if (btnp(➡️)) hades.light_selected[2] = (hades.light_selected[2] + 1) % #lights
		if (btnp(⬅️)) hades.light_selected[2] = (hades.light_selected[2] - 1) % #lights
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
		local x,y = i_light.x, i_light.y
		if c == lulu and lulu.powers_left > 0 and magic_used != "orb" then
			create_light(x, y, ima_light.r,super_lulu and "black" or "white",10) 
			if super_lulu then psfx(51) else psfx(57) end
			shake = 6
			lulu.powers_left -= 1
		else
			create_light(x, y, i_light.r, "black")
			psfx(51)
		has_cast_bl = true
		casting_bl = false
			shake = 12
		end
	end
end

function choose_ima_light()
	local lulu_light = btn(🅾️) and lulu.select and lulu.powers_left > 0
	local i_light = lulu_light and ima_light or casting_bl and ima_light_bo or nil
	return i_light
end

function draw_imaginary_light()
	local i_light = choose_ima_light()
	if i_light then
		circfill(i_light.x, i_light.y, i_light.r, i_light.c+2)
		circ(i_light.x, i_light.y, i_light.r, i_light.c)
	end
end

function draw_ima_range()
	if choose_ima_light() then
		circ(pactual.x_g, pactual.y_g, pactual.ima_range, 8)
	end
end

function draw_lights()
	draw_dynamic_lights()
	--lights
	foreach(
		lights, function(l)
			circfill(l.x, l.y, l.r,l.color)
			circ(l.x, l.y, l.r, 7)
		end
	)
	draw_shield(lulu)
	--black lights
	pal(3,3+128,1)
	foreach(
		black_lights, function(bl)
			circfill(bl.x, bl.y, bl.r, 3)
			circ(bl.x, bl.y, bl.r, 13)
		end
	)
	--disable possibility to player to draw ima lights
	if game_state != 1 then return end
	if messages[1] then return end
	draw_hades_turnoff()
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

function draw_shield(c)
	if c.shield.active then
	local r = c.shield.r
	local color_circle = c == hades and 3 or 10
	local cx = c.x + c.w / 2
	local cy = c.y + c.h / 2
	if c == hades then pal(3,3+128,1) end
	circfill(cx, cy, r, color_circle)
	circ(cx, cy, r, 7)
	end
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
	-- chests = { { locked (boolean), check_lock (boolean), content = { name (string), r (number)}, x, y } }
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
				{"tutorial","bienvenue dans lulu's quest!"},
				{"tutorial","maintiens 🅾️ et appuies sur\n⬆️⬅️➡️ou⬇️ pour..."},
				{"tutorial","...preparer une lumiere."},
				{"tutorial","pendant le lancement du sort,\nappuies sur ❎ pour..."},
				{"tutorial","...creer une lumiere."},
				{"tutorial","lulu (gauche) peut vivre\nseulement dans..."},
				{"tutorial","...des lumieres."},
				{"tutorial","hades (droite) peut vivre\nseulement en dehors..."},
				{"tutorial","...des lumieres."},
				{"tutorial","avec hades, maintiens\n🅾️+⬅️➡️ pour preparer..."},
				{"tutorial","...une anti-lumiere."},
				{"tutorial","maintiens ❎ en meme temps\nque 🅾️ pour..."},
				{"tutorial","...annuler une lumiere."},
				{"tutorial","la quantite de pouvoirs\nrestants est affichee..."},
				{"tutorial","...en haut a gauche."}, 
				{"tutorial","l'objectif est de ramener\nlulu et hades..."}, 
				{"tutorial","...a leur porte\nrespective."},
				{"tutorial","bonne chance!"},
			},
			display = {
				{60,5, "❎  sauter"},
				{60,12,"🅾️  pouvoir"},
				{60,19,"⬇️  changer"},
				{60,26,"⬅️➡️ deplacer"},
				{60,33,"🅾️❎ lancer"},
			},
			sound = 5
		},
    --2
    {
			lights = {{19,13,20},{28,13,24}},
			powers = {1,1},
			music = 0
    },
    --3
    {
        lights = {{45,  9, 24},{37,  8}},
        powers = {3,1},
				messages={
					{"indice","il est possible de lancer une\nlumiere dans une autre."}
				},
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
            {true,false,{"black_orb",27,30,36,},28,30}},
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
        chests = {{true,false,{ "turnoff" },74,21}},
    },
    --14
    {
        lights = {{84, 29}},
        shield_cristals = {{88,18,60,36,1}},
        butterflies = {{86,17,86,17,85, 27,2, 0.5,24,"white"}}
    },
    --15
    {
        lights = {{98, 24,8},{102,22,16}},
        powers = {1,1},
        shield_cristals = {{101,24,3,15,1}},
        butterflies = {{102,15,102,15,102,30,2,0.7,18,"black"}}
    },
    --16
    {
        lights = {{119, 17}},
        powers = {1,0},
        shield_cristals = {{117,17,10,10,1},{116,28,10,10,1},{122,17,10,10,1}},
        butterflies = {
            { 113,30, 113,30, 113,16, 2, 1,12,"white"},
            { 115,28, 115,28,123,28, 2, 0.7,12,"white"},
            {119,19, 115,19,125,19, 2,0.5,18,"black"},
            { 114,23, 114,23,122,23, 2,0.5,24,"black"},
        },
    },
    --17 PULSATOR
    {
			lights = {{8, 34, 20,"black"}},
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
			p_data = {6,47,112,"white",0},
    },
    --18
    {
			lights = {{22.5, 40, 24, "black"}},
			powers = {2,0},
			p_data = {30,46,256,"white",180},
			music = 21
	},
	--19
	{
		lights = {{41,33,8,"black"},{46,43,16,"black"}},
		powers = {4,2},
		butterflies = {{39,46,39,46,47,46,2,0.6,12,"white"}},
		chests = {{true, false, {"wkey"},32,37}},
		p_data = {38.5,37.5,46,"white",180,12}
	},
	--20
	{
		lights = {
			{51,33,8,"grey"},
			{61,33,12,"black"},
			{56,39,10,"grey"},
			{56,46,10,"white"},
		},
		
		messages = {{"indice","les lumieres blanches\nont la priorite sur..."},
		{"indice","...toutes les autres\nlumieres."}},
		shield_cristals = {{59,40,7,26,1}},
		butterflies = {
			{52,43,49,43,63,43,2,0.4,12,"black"},
			{52,46,49,46,63,46,2,0.4,12,"black"},
		},
		p_data = {54,30,108,"white",190,14,3}
	},
	--21
	{
		lights = {
			{73,34,8},
			{66,34,12, "grey"},
			-- {67,38,10,"black"},
			{72,41.5,10,"grey"},
		},
		powers = {1,0},
		shield_cristals = {{69,39,30,28,1}},
		p_data = {70.25,46,128,"white",0,14,2}
	},
	--22 super lulu
	{
		lights = {
			{89,35,8},
			{82,42,16,"black"},
			{95,39},
			{93,42,12,"grey"},
			{87,39,16,"grey"},
		},
		powers = {3,1},
		p_data = false,
		music = -1,
		sound = 2
	},
	--23
	{
		lights = {
			{97,44,12,"black"},
			{104,38,28},
			{106,33},
		},
		powers = {1,1},
		chests = {{true, false, {"black_orb",102,43,20},101,43}},
		p_data = {110.5,29.5,240,"white",200,16,1.5},
	},
	--24
	{
		lights = {
			--lulu
			{115,43},
			{123,43},
			{123,36},
			{115,36},
			--hades
			{114,46,12,"black"},
			{127,46,12,"black"},
			--lvl
			{119,33},
			{119,45,20},
		},
		powers = {3,1},
		butterflies = {
			{128,33,110,33,130,33,2,1,12,"black"},
			{118,46,113,46,126,46,1,0.6,12,"black"},
			{119,33,119,33,119,46,2,1,16,"dark"},
			{113,40,113,40,128,40,2,1,20,"dark"},
		},
		p_data = {117.5,38,128,"white",200,13},
		messages = {
			{"hint","red lights kill anyone\nwho enters them"}
		}
	},
	--25
	{
		lights = {{7,55,55,"black"}},
		powers = {1,0},
		messages = {
			{"a voice","you did a good job."},
			{"a voice","congratulations for all\nthese steps you reached."},
			{"a voice","you now have the choice."},
			{"a voice","go right, but it will\nbe hard."},
			{"a voice","frankly, i wouldn't\nrecommend it."},
			{"a voice","or go left, and finish\nyour mission."},
			{"a voice","it's much safer."},
		},
		sound = 2,
		display = {
			{4,412,"   <-finish"},
			{40,402,"   continue->"},
		}
	},
	--26 HARD
	{
		lights = {{25,50}},
		messages = {
			{"terrible voice","you will regret it!!\n gha ha ha ha!!!"}
		},
		butterflies = {
			{31,50,31,50,18,50,2,0.4,15,"dark"},
			{18,52,18,52,34,52,2,0.6,8,"dark"},
			{29.5,60,29.5,48,29.5,64,1,0.4,12,"dark"},
			{24,56,24,56,34,56,2,0.3,20,"dark"},
			{22,56,22,56,13,56,2,0.3,20,"dark"},
			{16,61,16,61,30,61,2,0.4,15,"dark"},
		},
		chests = {{false, false, {"light"},27,62}},
		shield_cristals = {
			{19,50,8,10,1}
		},
		music = 36
	},
	--27
	{
		lights = {{44,51,26},{44,55,26},{44,60,28,"black"}},
		chests = {
			{true, false, {"wkey"},46,62}
		},
		butterflies = {
			{33,47,33,47,33,63,2,0.4,14,"dark"},
			{37,63,37,63,37,47,2,0.4,16,"dark"},
			{40.5,47,40.5,47,40.5,63,2,0.4,14,"dark"},
			{44,63,44,63,44,47,2,0.4,14,"dark"},
			{47.5,47,47.5,47,47.5,63,2,0.4,12,"dark"},
		}
	},

	--28
	{
		lights = {
			{60,49,16},
		},
		powers = {10,1},
		butterflies = {
			{66,49,66,49,46,49,2,0.6,16,"dark"},
			{45,62,47,62,63,62,2,0.6,16,"dark"},
			{63,53,63,53,48,53,2,1,12,"dark"},
			{62,68,62,68,62,51,2,0.1,12,"dark"},
			{59,68,59,68,59,53,2,0.15,16,"dark"},
		},
		p_data = {54,54,180,"white",0,12},
		messages = {
			{"terrible voice","you'll never pass this!!\n just give up!!!"}
		}
	}
}
end

function update_room()
	--if they have finished the lvl
	if room_transition_pending then
		next_room()
		room_transition_pending = false
		lulu.passed, hades.passed = false, false
	end

	-- Update pulsator pulse timer
	if pulsator and pulsator.pulse_timer > 0 then
		pulsator.pulse_timer -= 1
	end
end

function next_room(argx, argy)
	local x, y = argx or room.x + 128, argy or room.y
	if x >= 1024 then x, y = 0, y + 128 end
	if y >= 512 then y = 0 end -- We are at the end of the map
	local w, h = x + 128, y + 128
	local id = room.id + 1
	--adding powers left into counter before loading next room
	power_counter += lulu.powers_left + hades.powers_left
	room = new_room(id, x, y, w, h)
	i_room = index_room(room.x, room.y)
	create_room()
	sfx_timer = 30
	fsfx(61,3)
	-- !!  TEST !!
	-- if music_object[2] != 27 then reset_music(27) end
	-- gkeys = 2
	-- wkeys = 2
	-- lulu.shield.active = true
	-- lulu.shield.timer = 60
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
		pulsator = rooms_data[pulsator_room].pulsator
	end

	delete_objects()
	create_objects()

	--characters
	local room = rooms_data[i_room]
	foreach(chars, function(c) 
		c.passed = false
		c.in_light = c == lulu and true or false
		disable_shield(c)
	end)
	--powers
	lulu.powers_left = room.powers and room.powers[1] or 0
	hades.powers_left = room.powers and room.powers[2] or 0
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
		c = 11
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
	mushroom = {}
	display = {}
end

function update_objects()
	-- Door collision and passing logic
	foreach(chars, function(ch)
		if not ch.passed and collision(ch, ch == lulu and doors.lulu or doors.hades) then
			ch.passed = true
			-- cas particulier : end choice
			if i_room == fountain_room then
				if ch == hades then 
					finish = "easy"
					game_state = 3
				else
					finish = "hard"
					next_room()
				end
			end
			disable_shield(ch)
			if not door_sound_played then 
				psfx(60)
				door_sound_played = true 
			end
		end
	end)

	-- Room transition
	if lulu.passed and hades.passed and not room_transition_pending then
		if is_ending() then --si level de fin
			game_state = 3
			return 
		end 
		room_transition_pending = true
		reinit_characters()
		delay_switch = dflt_delay_switch * 3
	end

	-- Chests
	foreach(chars, function(ch)
		foreach(chests, function(c)
			if not c.opened and collision(ch, c) then
				if not c.locked then
					open_chest(c)
				elseif gkeys > 0 then
					gkeys -= 1
					open_chest(c)
				elseif c.check_lock then
					c.check_lock = false
					psfx(50)
				end
				c.cl_timer = 30
			end
			if c.cl_timer > 0 then
				c.cl_timer -= 1
			else
				c.check_lock = true
			end
		end)
		
		-- Keys
		foreach(keys, function(k)
			if not k.collected and collision(ch, k) then
				psfx(60)
				if k.style == "door" then wkeys += 1 else gkeys += 1 end
				k.collected = true
			end
		end)
		
		-- Shield crystals
		foreach(shield_cristals, function(sc)
			foreach(chars, function(c)
				if collision(c, sc) and (not c.shield.active or c.shield.timer < (sc.timer*30)/2) then
					psfx(57)
					if sc.lives then sc.lives -= 1 end
					if sc.lives and sc.lives <= 0 then del(shield_cristals, sc) end
					c.shield = {
						active = true,
						timer = sc.timer * 30,
						def_r = sc.r,
						r = sc.r
					}
				end
			end)
		end)
		
		-- Gates
		foreach(gates, function(g)
			if collision_gate(ch, g) and wkeys > 0 and not g.opened then
				psfx(54)
				wkeys -= 1
				mset(g.x/8, g.y/8, g.tile+1)
				g.opened = true
			end
		end)
	end)

	-- Update various game objects
	foreach(butterflies, update_butterfly)
	update_pulsator()
	update_acristals()

	-- Mushroom powerup
	if mushroom[1] and collision(lulu, mushroom[1]) then
		local m = mushroom[1]
		super_lulu = true
		ima_light.c = 11
		sfx_timer = 30
		music(-1)
		sfx(-1)
		fsfx(59,3)
		del(mushroom, m)
		mset(m.x/8, m.y/8, 0)
		anim_timer = 75
		reset_music(21)
	end
end

--anims
function draw_objects()
	local function draw_spr(sprite_id, x, y, flip_x, flip_y)
		spr(sprite_id, x, y, 1, 1, flip_x or false, flip_y or false)
	end

	foreach(black_orbs, function(bo)
		draw_spr(frames > 20 and 23 or 22, bo.x, bo.y)
	end)

	foreach(butterflies, function(b)
		if b.light == "white" then draw_butterfly_light(b) end
	end)
	draw_shield(hades)
	draw_imaginary_light()
	foreach(butterflies, function(b)
		if b.light != "white" then draw_butterfly_light(b) end
	end)
	draw_grey_lights()

	foreach(chests, function(c)
		draw_spr(c.opened and 56 or 55, c.x, c.y)
	end)

	foreach(keys, draw_keys)

	foreach(shield_cristals, function(sc)
		local move = frames % 15 < 7
		if sc.lives then print(sc.lives, sc.x + 8, sc.y - 2, 11) end
		draw_spr(20, sc.x, sc.y + (move and 1 or 0))
	end)

	draw_pulsator()
end

function draw_door(d,s, flip)
	spr(s, d.x, d.y, 1, 1, flip, false)
	spr(s, d.x, d.y + 8, 1, 1, not flip, true)
end

function draw_doors()
	local flip = frames % 10 >= 5
	draw_door(doors.lulu, 35, flip)
	draw_door(doors.hades, 51, flip)
end

function create_black_orb(x, y,r)
	add(black_orbs, {x = x, y = y, r = r})
end

function delete_objects()
	local lists_to_clear = {
		lights,
		black_lights,
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
	sfx(-2,3)
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
		add(chests, {opened = false,locked = c[1],check_lock = c[2],content = c[3],x = c[4] * 8,y = c[5] * 8,cl_timer = 0})
	end
	--shield cristals
	foreach(c_room.shield_cristals, function(sc)
		add(shield_cristals, {x = sc[1] * 8, y = sc[2] * 8, timer = sc[3], r = sc[4], lives = sc[5]})
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
	if c_room.messages then
		while (#c_room.messages > 0) do
			add(messages, c_room.messages[1])
			del(c_room.messages,c_room.messages[1])
		end
	end
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
	if c_room.music and music_object[2] != c_room.music and not c_room.sound then
		sfx(-1) --for any sound
		reset_music(c_room.music)
	end
	-- si son on prれたfれそre le jouer
	if c_room.sound then
		-- cas particulier pour super lulu
		if i_room == 22 and super_lulu then
			return
		end
		music(-1)
		fsfx(c_room.sound,0)
	end
end

-->8
--butterflies

function update_butterfly(b)
	if lulu.using_light or hades.using_light or casting_bl then return end
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
	spr(frames % 10 >= 5 and 33 or 34, b.x-4, b.y-4, 1,1, b.spr_flip)
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
	--create the content of the chest above
	content = c.content[1]
	if content == "black_orb" then
		create_black_orb(c.content[2] * 8, c.content[3] * 8, c.content[4])
	elseif content == "turnoff" then
		hades.powers_left += 1
	elseif content == "light" then
		lulu.powers_left += 1
	elseif content == "wkey" then
		wkeys += 1
	end
end

-->8
--keys

function draw_keys(k)
	if k.collected then return end
	local sprite, flip = nil, frames % 30 >= 14
	if k.style == "chest" then
		sprite = frames % 30 < 7 and 41 or (frames % 30 < 14 or frames % 30 > 23) and 40 or 41
	else
		sprite = frames % 30 < 7 and 25 or (frames % 30 < 14 or frames % 30 > 23) and 24 or 25
	end
	spr(sprite, k.x, k.y, 1, 1, flip)
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
		if messages[2] then print("❎->",x2-16,y2-6,13)
		else print("❎end",x2-20,y2-6,13) end
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

-->8
--pulsator

function draw_pulsator()
	if not pulsator_state or not pulsator then return end
	-- osciller uniquement si pulse_timer actif
	local pr = pulsator.spr_r
	local pulse_ratio = pulsator.pulse_timer / pulsator.pulse_dur
	local scale = pr / 10 + 0.5 * pulse_ratio -- grossit chaque battement
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

	local broken = pulsator.is_broken
		--A less before the next pulsation, prevent the player
	local beat_delay = broken and pulsator.beat_delay / 2 or pulsator.beat_delay
	local ptype = pulsator.light_data.type

	-- Play warning sound before the next pulsation
	if pulsator.timer == beat_delay - 30 and i_room != pulsator_room then 
		fsfx(48, 3, ptype == "white" and 6 or 13, 1) 
	end

	pulsator.timer += 1
	if pulsator.timer < beat_delay then return end

	-- Trigger pulse
	pulsator.pulse_timer = pulsator.pulse_dur
	pulsator.timer = 0
	shake = 10

	-- Play pulse sound effect
	if sfx_timer == 0 and i_room != pulsator_room then
		fsfx(48, -1)
		sfx_timer = 30
		fsfx(48, 3, ceil(rnd(1) * 2) * 7, 1)
	end

	-- Update dynamic light from pulsator
	local pr = pulsator.spr_r
	local new_dyna_light = create_dynamic_light(
		pulsator.x + pr, pulsator.y + pr, ptype, 
		pulsator.light_data.spd, pulsator.light_data.r_max, pr
	)
	add(dynamic_lights, new_dyna_light)

	-- Alternate type
	if not broken then
		pulsator.light_data.type = (ptype == "anti") and "white" or "anti"
	end
	
	-- Gradually reduce the pulse timer
	if pulsator.pulse_timer > 0 then
		pulsator.pulse_timer -= 1
	end
end

function break_pulsator()
	--if we are here, then all acristals are activated
	if not pulsator.is_broken then
		-- timer of pulsator reset to 0
		pulsator.timer = 0
		-- wait 1 sec
		anim_timer = 60
		-- screenshake
		shake = 60
		-- wait 2 sec and delete acristals
		pulsator.is_broken = true
		fsfx(47, -2)
		sfx_timer = 120
		fsfx(63)
	end
		--when anim is finished, delete the acristals and destroy walls
	if anim_timer == 0 then 
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
	return ((lulu.using_light or hades.using_light) and i_room > pulsator_room) or not pulsator_state or pulsator.is_broken or casting_bl or not pulsator
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
	--timer shield
	foreach(chars, function(c)
		if c.shield.active then
			print(flr(c.shield.timer / 30), c.x + 4, c.y - 5, 12)
		end
	end)

	local x, ry = room.x + 12, {room.y + 4, room.y + 12, room.y + 20, room.y + 28, room.y + 36}
	local ui = {
		{lulu.powers_left, super_lulu and 19 or 49, ry[1]},
		{hades.powers_left, 50, ry[2]},
		{gkeys, 57, ry[3]},
		{wkeys, 9, ry[4]},
		{deaths, 48, ry[5]}
	}

	palt(0, false)
	palt(12, true)

	for i, p in pairs(ui) do
		if p[1] > 0 then
			spr(p[2], room.x + 4, p[3])
			for dx = -1, 1, 2 do
				print(p[1], x + dx, p[3], 0)
				print(p[1], x, p[3] + dx, 0)
			end
			print(p[1], x, p[3], 11)
		end
	end
	palt()
end

-->8 end

function is_ending()
	return lulu.passed and hades.passed and i_room == 28
end

function draw_end()
	fade_in(end_game_dark, 60)
end

function fade_in(counter, start_count)
	local c=10
	if counter>start_count then
		if frames%10<5 then
			c=7
		else
			if end_on then return end
			c= 2
		end
	elseif counter>start_count/2 then
		c=2
	elseif counter>0 then
		c=1
	else 
		c=0
	end
	for i=0,15 do
		pal(i,c)
	end
end

function draw_end_text()
	next_dialog(-120, "congratulations!!", 30, 8, 7)
	next_dialog(-240, "you died : "..deaths.." times", 26, 30, 8)
	if end_game_dark < -320 then
		if finish == "easy" then
			print("           the voice:\n\n    you made the good choice.", room.x + 0, room.y+50,12)
		else
			print("the voice: you're very reckless.", room.x + 0, room.y+50, 12)
			next_dialog(-440, "it was risky,\nbut you went through with it.", 0, 60,12)
			next_dialog(-570, "\nfor that, bravo.", 0, 70,10)
		end
	end
	if end_game_dark < -780 then
		cls()
	end
	next_dialog(-900, "thank you for playing with\n\n    hades and lulu!!", 12, 40, 7)
	next_dialog(-1200, "to be continued", 34, 90, 2)
end

function next_dialog(count, dialog, x, y, c)
	if end_game_dark < count then
		print(dialog, room.x + x, room.y + y, c or 7)
	end
end

function end_screen()
	if not end_on then
		-- assombrir progressivement
		music(-1)
		fsfx(-1)
		fsfx(44)
		end_on = true
	end
	end_game_dark -= 1
end

-->8
--helper functions

function debug_print()
	print("lv:"..i_room, room.x + 80, room.y+4, 11)
	-- print(hades.dy, hades.x, hades.y-10)
	-- print("frame:"..frames)
	-- print("lulu_dx:"..lulu.dx)
	-- print("hades_dx:"..hades.dx)
	-- print("lulu_og:")
	-- print(lulu.on_ground and "true" or "false")
	-- print("hades_og:")
	-- print(hades.on_ground and "true" or "false")
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
	local lx,ly = l.x, l.y
	local rx = max(p.x, min(lx, p.x + p.w))
	local ry = max(p.y, min(ly, p.y + p.h))
	local dx = lx - rx
	local dy = ly - ry
	local dist = sqrt(dx*dx + dy*dy)
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
08888880c888888c0002e000ccc0cccc0000000000566500000000000000000000000000000000004444444440000004001155dd33dddddd33dd33dddd551100
88888888888888880022ee00cc030ccc000000000056750000000000000000000004000000040000454545455000000501115dddd33dddddd33333ddddd51110
8888888888888888022eeee0c03630cc0088e0000056750000000000000000000004000000464000454545455000000501155ddddd3dddddddddd3ddddd55110
88888888c889889822eeeeee0366630c08888e000056550000088000000880000004000000040000444444444000000401155ddddd3dddddddddd3ddddd55110
88898898c888888800094000c03630cc0088e00000055000008838000088b800000400000004000000000000000000001115dddddd3ddd11111d33dddddd5111
08888880c88888c800094000cc030ccc000e0000000500000838888008b88880000400000004400000000000000000001155dddddd3dd111111133dddddd5511
00888800c88888cc00094000ccc0cccc00000000000000000004400000044000000400000004000000000000000000001155dddddd3d1111111113ddddddd511
00800800c88cc8cc00094000cccccccc00000000000000000004400000044000000000000000000000000000000000001155dddddd311111111113ddddddd511
66666666c0c00000c0c000000005500000566500056656500000000000000000000000000000000000000000000000001155ddddd3311111111133ddddddd511
6555555600000444000000000055550000567500055505000000000000000000000a0000000a0000000000000000000011555ddd33d33111111131dddddd5511
655555560aaa44400aaa44440558855000057500000500000007000000080000000a000000a9a000888888880000000011555ddd3dd13333311131dddddd3311
655555560aaaaaa00aaaaaaa5588885500005000000000000076700000828000000a0000000a0000888888880000000011155ddd3ddd11113111333333333111
655555560000000000000000588998850000000000000000076a6700082a2800000a0000000a0000888888880000000001155ddd3dddd11133113ddddd555110
6555555600000000000000005899998500000000000000000076700000828000000a0000000aa000888888880000000001155ddd333ddd111313dddddd555110
6555555600000000000000005899798500000000000000000007000000080000000a0000000a00008888888800000000011155dd3d33ddddd3333ddddd551110
666666660000000000000000589779850000000000000000000000000000000000000000000000008888888800000000001155333dd33ddddddd3dddd5551100
50000005ccc0ccccccc8cccc0005500000444400004554000000000000000000000aa000ccc0cccc88888888888888880011153555dd3ddddddd33d555511100
05666650cc0a0ccccc808ccc005555000045540000000000000000000999999004444440cc0a0ccc88888888888888880001113355dd333dddddd33555111000
06066060c0a7a0ccc80008cc055dd5500044440000000000000b00009974449946665554c0a9a0cc88888888888888880000113555555d33dddddd3351110000
066666600a777a0c8000008c55dddd55004554000000000000b3b0009744444946655554cc0a0ccc888888888888888800000111555555533555555511100000
c060060cc0a7a0ccc80008cc5dd22dd500444400000000000b3a3b009999999997444449cc0a0ccc888888888888888800000011115555553555551111000000
c056650ccc0a0ccccc808ccc5d2222d5004554000000000000b3b000974aa44997444449cc0aa0cc888888888888888800000001111115553351111110000000
05000050ccc0ccccccc8cccc5d2272d50044440000000000000b00009744444997444449cc0a0ccc888888888888888800000000011111111311111000000000
c0cccc0ccccccccccccccccc5d2772d50045540000455400000000009999999999999999ccc0cccc888888888888888800000000000011111111000000000000
00000111111000000000001100000000000111000000000000111000055555500555555555505505555555500555555000000000505555055055055566666666
00001111111100000000001100000000001111100000010001111100555555555555555555555555555555555555555500000000555655555555555566666666
000111111111100000000011cccccccc011111111111111101111110555665555555556655555555565665555556655500000000655666665655655566666666
001111111111110000000011cccccccc111111111111111111111111556666555555566665566566666665555556665500000000666666666665665666666666
011111111111111000000011cccccccc111111111111111111111111556665555556666666666666666666555566655500000000666666666666666666666666
111111111111111100000111cccccccc011111101111111111111110555655555556666666666666666666555566665506600000666666666666666666666666
111111111111111100000011cccccccc00111110010000000111110055555555555666dd66666666666666655556655506606000666666666666666666666666
111111111111111100000011cccccccc00011100000000000011100005555550555666dd66666666d66666555556665555505505666666666666666666666666
11111111111111111100000000011000ccccccccd666655555556666055555505556666666666666666665555556665500000000055555005005555066666666
11111111111111111110000000111100cccccccc6665555005556666556766555555666666666666666655555566666500000000555555555555555566666666
11111111111111111100000001111110cccccccc6665550000555666567766650556666666666666666665505556655500000000555555555566555566d66666
01111111111111101100000011111111cccccccc6655500000055556577666755556666666666666666665555566665500000000555666556666655566666d66
00111111111111001100000011111111cccccccc5555000000005556567777755555666666666666666655555666655500088000556666666666655566666666
00011111111110001100000011111111cccccccc55500000000005555667666505556666666666666666655055566665008888000566dd666666655566666666
00001111111100001100000001111110cccccccc55000000000000555567665555566666666666666666555555666555088888800556dd666d66555066d666d6
00000111111000001100000000011100cccccccc5000000000000005055555505556666666666666666665555556665500044000555666666666555066666666
1111111111111111000000000011110011111111500000000000000500dddd005566666d66666666dd6666555566655500000000055566666666655500000000
111111101111111100000000011111001111111155000000000000550dddddd05556666666666666dd6666555556655500000000055566d666dd655000000000
11111000001111110011100000111100111111115550000000000555dddddddd55666666666666666666655555666655000000005556666666dd665000055000
11110000000111110011110000111100111111116555000000005555cddddddc5556666666566666666655555556665500000000555666666666665500555500
11110000000001110111110000111100111111116555500000055566ccc6cccc5556666666566665666655555566655500099000555666665566655505555550
11100000000000110111111000111110111111116665550000555666cc6c6ccc5555665655555555656555555556655500999900555566555555555500022000
11000000000000111111111100111100111111116666555005555666c6ccc6cc5555555555555555555555555555555500055000555555555555555500022000
1100000000000001111111110011110011111111666655555556666dcccccccc0555555550550555555555500555555000055000055550050055555000022000
10000000000000111111111100111100000000000555555555555555555555500555555555555555555555500555555000000000000000000000000000000000
11000000000000111111111101111110000000005555555555565555555555555555555555555555555555555567665500000050000000000000000000000000
11000000000001110111111011111111000000005556565656566565556655555556665555555555566665555677066555500565000000000000000000000000
11100000000011110011111011111111000000005566666666666666666666555566666556555566666666555770067550050005000000000000000000000000
11111000000011110011110011111111000000005566666666666666666666555566666666555565566666555600007550000075500000750000000000000000
11111100000111110001110001111110000440005555665566666666656565555556666555555555556665555660666556005065565550650000000000500050
11111111011111110000000000111100004444005555555565666565555555555555555555555555555555555567665556600655565005555050000505550555
11111111111111110000000000011000000550000555555555555555555555500555555555555555555555500555555055656655556565665555550500400040
272704461504141050164607170675339696969696f5959596959596969696f5363536b6005000000010b5757575750094a4545464b500002436250000005085
f4969696969696f596969696969696f595969696969695959596959696969595004300170600008595e600000000b00065969655000000000000174646060005
62174606000515d5e5001646067575005474061646d695a654d6a6543754548536b43600007500001787b6757575876795a5100000b500002436250000849495
a5000005140000b61000003716753285a600360024366596552474000000d695a1b4170600000085a50000620000000056359135000000000017464606000000
9494e507001714d6e60017068494d4d4910507174615b50000512425c4c6918537869774a77500041536257475640024f595e50000b5000024362500006595f5
a5918494a71400d5e526260017750085000036002436000000242500000044d662b5060000576796966767a4000000009594676767a7757575757584a4000044
f5959594a406161451174657969595f5946767677700b574c4002425876797f5757575b67575757500362500746200249595a50004b654545454643500006595
f56796a6000514d6e6464674757557965000362624360000472425260000000017b500000000044646461486a700000095a500370000001746460665a5000075
95959696e60000161446464646869696a55454545454b57474f6041400876785a775b475757575757574250000b4072495955504461500002436253600000085
a575750000047406002727167575d59494946767677400007467949494a464440685e500000446104646461400000000955500001075757575060024b5000024
96a67575420000001646464646070052a50024d56767976767e50515004362853675b57575757400000075644485772495a50446150000002436252700000085
a53375001774360000000000758495f595a51405142500000016d695f5a500000085e6000446757575b41646140000b4a500000075a0a0a0a0750024b6000024
32757575757500001774460616b40762a50057e60415b50514b6041400d594956767a6171500a0b0b0b0000074b60024f5a54615001707912436252600000085
a500755016143600000000008796969595a61607161400000017068695a5000000b60004467575333285e51646148755a500007500a00000a000752475750024
00757575757575758494a40717859494a5f652041500b600051405150085f595460617060000a00000a000000035008795a61500174646d5e536253600007585
a5747574001646072635261746461485a6000005140514211706001685a500000000044674757500008595a746466400a500007532a00000a033752475000024
e4d494d494e4d494959595e494f59595957704150000750000051447b4659595060415000074a0a0a0a0750017461400a5757562164674d6e674a73662757485
956797a7a167a41516846767676767950700000016148494a454545486a6000000044646075794949495e61746150000a500177500a00000a000752475000024
95f5959696969695f5959696969595f5a50415000010755000d5d4a4b54465950457a735005275000075001775846767a57575576797676767976797976767f5
95e646150005b50000b6000446159185061000000084959695a435000000323397a7a7464607869595e6174615b40000a517464674a0a0a0a074362475000075
f5955504464614659655003625659595a5150057676797676795f5a5b644006506430074000000000000005797a63233a5757575004300750036750016061685
e6461500b4008677000004b41500d59507171426849555006595a426000000000000000546460785a546461500b5000095a44606007575757536362475000000
955517461516460700000036251465f59577470005157533328595e61607003767a435627400260000c6007575430000a5747575477475757536747517071785
46150700b5000043000446b5004785f5676797679655000000659667676767a40000000005464685a5461591d5e60092f5a50600c60000000036362475000000
55174646141746060000003625051465a500b4002425750000d6a6510016070065866767676777545484679767679767959767676797676797679767a7757585
1500879767676767676767a600d5959534343434343434343434343434343434500000849494e495a5a2a284a50000d596a68767976777a18797a75767775454
00164646464646140000003625000514a55485a42425879767a7000026001607002425361607520000b6164646063600a5323300753600757500750514747585
0000001607a000044606a0000085a3a395954586969695959596969696969696676767a6a3a3a39595a3a395a500d595a4620036000000002604460616060000
00001646464646060000003625140005a5008595a414004362b500353600001691242536471607750000174646073692a5000074753675757475757505147585
a400006216b017460600a0006285a30295f5450000008696a600000000000000a3a3a3a3a3a3a39596969696e60085a395e550360000d594e505460717070062
000000054646460700000036250514009594f5f595e4e4e494a5003636260000e4d494e4d494d4e4d494e494d494e494959494949494949494949494949494f5
95949494a40446060000a0d59495a30295954534343434343434348494949494b3b3b3b3b3b3b3a691910000430085a395f59494d4a48595a5849494e494d494
f5959595550000000000000016070000a39596969696b59696969696a606a3a39596969696969655b465969696969595a6000000000446464646141000000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a00000000000000000000000000000000000
95f59555000000000000000000160732a3a546150546b614271646461500a3f4a5000000c5430000b50036000515659500c557676767676767676767676767a6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
95965500000000000000000000c51600a3a50600b416461574101687a7c4a3f4a544644487a40000b41436041400048500b400044606c5164606c51614000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a5330000000000000000f7f700879767a3a500d5956767676777576767676795a50000002485a700b5545454b400468500b60484676767676767676767a40000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a5f7f700000000000047847700454545a3a500d6a5002700c40027c516460785a5a1000024b62500b5a73646b500058500b546b4164646464646460616b51400
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9594a400000000000057a60000459595a3a50717b5005767676794e500164685a535355454b52500b5463646b400879504b546b5178467676767a40717b64614
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
95f555000047f6c6c6f7f600004595959596a716b50032003304d6a500001685a500000024b52587a5463687b526008546b546b646b500000000b5a746b54687
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
95550000005767679797770000459595a5460717b5c40074044646b51400c585a5000000a1b52500b5063616b5a7008546b646b532b500000000b54646b51500
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a5105000000000000000000047459595a546879767679767a74606b516145767a500001707b61400b5a73600b6001085057446b500b600000000b54687b60000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a5d5e500000000000000000057459595a546061614000546464607b517150085a55017061685a764b5073617b400879500b4468667676767a733b54646b4a700
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a5d6e6c6c5f6c5c647f647c5f645959595a4071715c50005464684a515000085a5a1160717b51500b6063687b526008500b64646063737373700b5a715b50000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
95949476767676767676767676459595a3a367676767676767679696a7000085a500001646b51492b5913616b5a7008500005767676757676767a62700b400c5
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4545454545454545454545454545454595a3000000a00000000515000000c585a500000016b6158496a73600b500c685e5c5000005464646460600c584a500b4
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4545454545454545454545454545454595a3000000c5000000041400d594949555000000a1b514b633323617b6008795e6576767576767676777576796a600b5
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4545454545454545454545454545454595a3a38494e5500004d5e51485a2a2a200b0b0b0b0b51543000036d5b52600850000000050270027000000000000c5b6
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
454545454545454545454545454545459595a39595959494a4d6e68495a3a3a300b0b0b0b085e494e494e4d6b5d4e495000000669494949494e5d5949494a4b4
__label__
0111111111111111111111111111111111111111111111111115555555555555ddddddddddddd555555555555111111111111111111111111111111111111111
011111111111111111111111111111111111111111111111155555555555dddddddddddddddddddd555555555511111111111111111111111111111111111111
011111111111111111111111111111111111111111111111555555555dddddddddddddddddddddddddd555555555111111111111111111111111111111111111
0111111111111111111111111111111111111111111111555555555dddddddddddddddddddddddddddddd5555555511111111111111111111111111111111111
01111111111111111111111111111111111111111111155555555dddddddddddd6666666666dddddddddddd55555551111111111111111111111111111111111
011111111111111111111111111111111111111111155555555dddddddddd666666666666666666ddddddddd5555555511111111111111111111111111111111
01111111111111111111111111111111111111111155555555dddddddd666666fff777777ff666666ddddddddd55555551111111111111111111111111111111
011111111111111111111111111111111122222225555555dddddddd6666fff77777777777777ff6666dddddddd5555555111111111111111111111111111111
011111111111111111111111111112228888888884444455dddddd6666ff777777fffffffff77777f6666ddddddd555555511111111111111111111111111111
011111111111111111111111112d8888888888844444999444ddd666ff7777ffffffffffffffff7777ff66ddddddd55555551111111111111111111111111111
011111111111111111111111dee888888888884444499999999aa6ff7777ffffffffffffffffffff7777f666dddddd5555551111111111111111111111111111
0111111111111111111111dee88888888888884444999999999aaaf777ffffffffaaaaaaaaffffffff777f666ddddd5555555111111111111111111111111111
011111111111111111112eee88888888888884444999999999aaaf77ffffffaaaaaaaaaaaaaaaaffffff77ff66ddddd555555511111111111111111111111111
0111111111111111115eee488888888888884444999999999aaaf77fafffaaaaaaaaaaaaaaaaaaaafffff77ff66ddddd55555511111111111111111111111111
01111111111111111deee288888888888884444499999999aaaf77faaaaaaaaaaaaaaaaaaaaaaaaaaaffff77ff6ddddd55555551111111111111111111111111
0111111111111111deee228888888888888444499999999aaaf77faaaaaaaaaaaaaaaaffffaaaaaaaaaffff77ff6ddddd5555551111111111111111111111111
011111111111111eeee228888888888888444499999999aaaf77faaaaaaaaaaaaaaaa777777ffaaaaaaaffff77ff6dddd5555555111111111111111111111111
01111111111111eeee222888888888888444449999999aaaa77faaaaaaaaaaaaaaaa7777777777faaaaaaffff77f66dddd555555111111111111111111111111
0111111111111deee4222888888888888444499999999aaaf77faaaaaaaaaaaaaaaa777777777777aaaaaafff77ff6dddd555555511111111111111111111111
011111111111deee4222888888888888444499999999aaaf77faaaaaaaaaaaaaaaaf7777777777777aaaaaafff77f66dddd55555511111111111111111111111
051111111111eeee2222888888888888444449999999aaaf7faaaaaaaaaaaaaaaaa77777777777777faaaaaafff7ff6dddd55555551511111111111111111111
05111111111deee42222888888888844444449999999aaa77faaaaaaaaaaaaaaaaa777777777777777faaaaaaff77ffdddd55555555511111111111111111111
05111111115eeee2222288888884444444499999999aaaf77aaaaaaaaaaaaaaaaaf7777777777777777aaaaaaff77ff6ddd55555555511111111111111111111
0551111111deee4222228888822488844449999999aaaaf7faaaaaaaaaaaaaaaaaf7777777777777777faaaaaaff77f6dddd5555555511111111111111111111
0551111111eeee2222228882288888844499999999aaaf77faaaaaaaaaaaaaaaaaf77777777777777777faaaaaff77ffdddd5555555551111111111111111111
055111111deeee222222882488888844444499999aaaaf77aaaaaaaaaaaaaaaaaaf77777777777777777faaaaaff77ffad445555555551111111111111111111
055511111eeee42222222288884444499499aaaaaaaaaf7faaaaaaaaaaaaaaaaaa7777777777777777777faaaaaff7ffad445555555551111111111111111111
055511115eeee222222228882249999999aaaaaaaaaaaf7faaaaaaaaaaaaaaaaaa77777777777777777777aaaaaff7fffd445555555555111111111111111111
055511115eeee2222222282599999999949aaaaaaaaaaf7aaaaaaaaaaaaaaaaaaf777ff777777777777777faaaaff77ffd445555555555111111111111111111
05551111deee422222222049999999999f49aaaaaaaaa77aaaaaaaaaafffaaaaa777777ff77777777777777aaaaff77ffd444555555555111111111111111111
05555111deee22222222049999999999aff4aaaaaaaaa77aaaaaaaaaa777faaaf77777777ff777777777777faaaff77ffa444555555555111111111111111111
05555111eeee22222220499999999999ffff9aaaaaaaa77aaaaaaaaaaf777faf7777777777ff77777777777faaaff77ffa444555555555511111111111111111
05555111eeee22222225999999999999ffff4a9aaaaaa77aaaaaa9aaaa777777777777777777f7777777777aaaaff77faa444455555555511111111111111111
05555111eeee22222204999999999999fffff9aaaaaaaf7aaaaaaa9aaa7777777777777777777f77777777faaaaff77fa4444455555555511111111111111111
05555111eee422222049999999999999fffffaaaaaaaaf7faaaaaaaaaaf7777777777777777777f7777777aaaaaff7ffa4444455555555511111111111111111
05555511eee422245549999999999999dfffff9aaaaaaf7faaaaaaaaaaa77777777777777777777777777faaaaaff7ffa4444455555555511111111111111111
05555511eee422440449999999999499ffffffaafaaaaa7faaaaaaaaaaaf7777777777777fff77777777faaaaaaf77ffa4444455555555511111111111111111
05555511eeee04445449999999999499ffffffa9ffaaaa77aaaaaaaaaaaa77777777777fff777777777faaaaaaaf77faa4444555555555111111111111111111
05555551dee254454449999999999499fffffff9aa9aaaf7aaaaafaaaaaaf77777777faf7777777777faaaaaaaaf77fa44444555555555111111111111111111
055555515ee544444999999999999499ffffff9999999af77faaafaaaaafa77777777af7777777777faaaaaaaaff7ffa44444555555555111111111111111111
055555511ed444444999999499999499ffff444affffaaa7777ffffaaaafff777777ff7777777777faaaaaaaaaf77faa44444555555555111111111111111111
055555551d5444444999999449999949fff44df66fffffaf77777ffaaaa7fff7777ff7777777777faaaaaaaaaff7ffa444445555555555111111111111111111
05555555155444444999999449999944ff4566dd66ff77fa77777ffaaaa77ffaf7777777777777faaaaaaaaaaf77faa444445555555551111111111111111111
0555555551d444444999999959999944fd5d6ddd66f77fff777777faaaaf7ffffaf7777777777faaaaaaaaaaff7ffa4444445555555551111111111111111111
0555555551d444444999999959999455f5566ddd66f77aff777777faaaaa77ffffaf777777777aaaaaaaaaaaf77faa4444455555555511111111111111111111
0555555551e444444999999944945d6df5666dddd66ffaff777777faaaaaf777ffffafff777faaaaaaaaaaaf77faa44444455555555511111111111111111111
0555555551e44444499999994545dffffd677d6666666af7777777faaaaaa7777fffffffffffaaaaaaaaaaf77faaa44444555555555511111111111111111111
0555555551644444499999945dd6fffff667766666666f77777777faaaaaaaf77777ffffffffaaaaaaaaaf77ffaa444444555555555511111111111111111111
055555555164444444999945dddfffffff77776666666f777f77777aaaaaaa9af7777777777aaaaaaaaaf777faa44f4444455445555111111111111111111111
05555555516444444499945dddd6ffffff777776666ffff7fff7ff77faaaaaaa9aaf77777faaaaaaaaaf777fffafff4444444442225551111111111111111111
0555555511644444459945ddddd6fffffff7777777ffffffff7faaf77ffaaaaaaaaaaafaaaaaaaaaaff77ffffaafe44444455522225255111111111111111111
055551111064454440445ddd5dddfffffffffffffffffffffffaaaaa777ffaaaaaaaaaaaaaaaaaaff777ffffa4ff444444554522225d21101511111111111111
0551111110de4544555555015dddfffffffffffffffffffffaaaaaaaaf777fffaaaaaaaaaaaaaff777fffffa4ff4444445542522222d52510151111111111111
01111111115f454405d500151ddd6ffffffffffffffffffaaaaaaaaaaaff7777fffffaffffff7777fffffff44fe44455555425222222d2251111111111111111
011111111116444400500dddddddfffffffffffffffffffa9aaaaaaa9aaaff7777777777777777ffffffff44fee44555555222222222d5225111111111111111
01111111110df45450005dddddd6fffffffffffffffffffffaa999999aaaaaaffff777777ffffaaffffff444ee4445555552222222222d222511111111151111
01111111111164405501dddddddd6ffff6d56fffffffffffffff99999a9aaaaaaaaaaaaaaaaaaaffffff444eed4445555122222222222d222551511111151111
051111111110df4055d1ddddddddd6ffd5225ffffffffffffff499999a9999aaaaaaaaaaaaaaaafafff4444edd44555555222222222222522251151111151111
0511111111110de051d5dddddddddd65222256ffffffffffff444999aa999999999999aa9999444ff44444de4444555511222222222222222251155111151111
05111111111111d5155d5ddddddddd5122222dfffffff66f6444499aaa999999999994994444444fe44444dd4444551555225112222222222225115555551111
055111111111155555165ddddddddd5224444d666666666644444499aa9999999499994444444444d44444d4444455d66622dd65222222222215515555555555
0551111111111555551ddd6dddddddd522224dddddd666d544444499a99999999999994444444444444444d44445dd666625dd6d222222221212515555555555
05511151111115515555e166dddddddddd55ddddddd6655444444449944449944999994444444444d44554444445dd666d2ddd6d222222221121555555555555
01111551111115555555f5566ddddddddddddddddddd52444444444444444444444499444444444d445554444425d6666d2dd66d212222222121255555555555
01115551111111155555f455666ddddddddddddddd522444444444444444444444444444445544dd445665422425d666655dd66d212222222121255555555555
01155511111111155555f44505d666ddddddddd5522222224444444444444444444444445444ddd444dfd5222225d666655d666d212222122121155555555555
0115555511111115555de444400155ddddd5511222222222224424444444444444444444554dffdd44d6d5222225d6dd55d5d66d212222122111155555555555
0155555551111115551d4444515111101222222222222484222224448884244444444444555dffe452d66d222225d100001dd56d112221022011125555555555
0555555551111115555e44451511155511222222222228224824448888424888888884425555eded52d66d521225d11555005dd5552221121015125555555555
0555555551111115515450155555555511122222222221528224888882288888888848455555d44222566dd25125d55444451565552215121011125555555555
0555555555111115511015555555555551140222222222dd22888888228888888888482151555222222566622525dd49a94d6565d52115110115115555555555
0555555555511115555555555555555551222222222222225d422221dd4488888884882111552222222115d52d21dd6faad666d5d52055010111515555555555
0555555555551115555555555555555102222222222222222152228225dd288888888201111221222222100d2dd1dd66666666dd6521d5011115511555555555
055555555555511555555555555111155222220222220022002888888825d288888881001111022222122215d5655d666d6666d6651dd1515515551155555555
055555555555511555555555551ddd1512222220220228888222228888825d2828882000111111222222222066d65dd666666666655dd5505555555515555555
05555555555551155555555551d6d65512222222002888888888222288882d528882000011111112122222215666dd66666666666dd6d5505555555555555555
055555555555511115555555556ddd11122222202288888888888882222222d28220000011111112222221110d666666666666666666d5115555555555555555
055555555555551115555555515d5551502200012288888822222228888888d5225000011111111211221011115d6666666666666666dd111555555555555555
055555555555511555555555551515d55500150d22888820000000021122211005d5001111111112111111111101555dd6666666666dd5011555555555555555
055555555555555555555155555115d51515512e2888200111111114500011111112111111111511551111111111111111d66ddd66ddd1111115555555555555
05555555555555555555555555555111115550d4228201111111111420111111111111111555551555111111111111111111d66ddddd51551115555555555555
05555555555555555555555555555555555550d422201111111111142011111111111111551555555511111111111111111115ddddd515555515555555555555
055555555555555555555555555555555555512e220111111111115421111111111111155555555551011111111111111111105ddd1155555555555555555555
055555555555555555555555555555555555551d2111111111111144221111111111155555555555501111111111111111111111015555555555555555555555
05555555555555555555555555555555555555512551111111111544242111111115555555555551111111111111111111111110055555555555555555555555
055555555555555555555555555555555555555510d5111111111444244111111155555555555511111111111111111111001110015555555555555555555555
0555555555555555555555555555555555555555551d51111111444254421111155555555551111111111111111111111015dd55100555555555555555555555
02555555555555555555555555555555555555555551dd111114442244441555555555511111111111111111111111110055d555102255555555555555555555
02555555555555555555555555555555555555555555551005555024444425555551111111111111111111111111111101555555102205555555555555555555
0225555555555555555555555555555555554255555555d455200244444441101111111111111111111111111111111011155155100005555555555555555555
02222555555555555555555555555555555544555555511111105444444441111111111111111111111111111111111111115115510000155555555555555555
02222225555555555555555555555555555555511110011102d55444444441111111111111111111111111111111110111111151551111555555555555555555
02222222555555555555555555555555551111011111111111d554444444411111111111111111111111111111111011111111d0155551555555555555555555
022222222552225255555555555555511111111111111111112455444444411111111111111111111111111111110111111111d1015555555555555555555555
022222222255222222225555551111111111111111111111110d4544444441111111111111111111111111111110111111111111001555011555555555555555
02242222222222222222555111111111111111111111111111026455444411111111111111111111111111111011111111111111010110111111115555555555
04444422222222222225551111111111111111111111111111112d44542111111111111111111111111111110011111111111111011111111111151011555555
0444444442222222555551511111115111111111111111111111012dd21111111111111111111111111111001511111111111115111111111111551111111115
0444444444444455551111155111111151111111111111111111111111111111111111111111111111111015555555111111555d111111115115511111111111
0444444444455551111111115551111115111551111111111111111111111111111111111111111111111055555555555555555d111111551155111111111111
0444445555551111111111111155511111155511111111111111111111111111111111111111111111110155555555555555555d111155115551111111111111
0455555551111111111111111111555511111111111111111111111111111111111111111111111111101155555555555555ddd5101511155511111111111111
055555511151111555511111111111555511111111111111111111111111111111111111111111111101115555555555555ddd55155115551111111111111555
05551155555555555555555555555551155511111115555555555111111111111111111111111111101111555555555555dddd55111155555555551111555555
05555555555555555555555555555555511555555555511111115111111111111111111111111111011111555555555555dddd55111551111115555555555555
0555555555555555555555555555555511111555511111111111111111111111111111111111111111111155555115555dddd555055511111111115555555555
0555555555555555555555555555555551111111111111151111111111111111111111111111115155551155555501555ddd5555555111111111155555555555
055555555555555555555555555555555555555555555555111511111111111111111111111111505555515555511115555555d1551111111115555555555111
05555555555555555555555555555555555555555555555551151111111111111111111111111515555501555551110155555551511111111155555555555555
05555555555555555555555555555555555555555555555555551111111111111111111111111d15555501555511555155555515511111111555555555555555
05555555555555555555555555555555555555555555555555551111111111111111111111111d15555500111111555115555515111111155555555555555555
05555555555555555555555555555555555555555555555555551111111111111111111111111555555500000111111015555515111111555555555555555555
05555555555555555555555555555555555555555555555555551111111111111111111111111d55555500000511111015555115551115555555555555555555
05555555555555555555555555555555555555555555555555555111111111111111111111111d55555500000511111101110015555555555555555555555555
05555555555555555555555555555555555555555555555555555511111111111111111111111d55555500000111155500000111115555555555555555555555
05555555555555555555555555555555555555555555555555555511111111111111111111111155555500000115555500000101115555555555555555555555
05555555555555555555555555555555555555555555555555555551111111111111115555555515555510000055555500000511555555555555555555555555
05555555555555555555555555555555555555555555555555555555111111111111555555555551555555101555555500000005555555115555555555555555
05555555555555555555555555555555555555555555555555555555551111115555555555555555555555555555555500000015555551115555555555555555
05555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555510000055555511155555555555555555
70000000000005555555555555555555555555551555555555555555555555555555555555555555555555555555555555101555555111555555555555555555
07000000000005555555555555555555555555551111555555555555555555555555555555555555555555555555555555555555555111555555555555555555
00700000000005555555555555555555555555555551111555555555555555555555555555555555555555555555555555555555551115555555555555555555
07000000000005555555555555555555555555555555511111155555555555555555555555555555555555555555555555555555511155555555555555555555
70000000000005555555555555555555555555555555555115555555555555555555555555555555555555555555555555555555111555555555555555555555
00000000000005555555555555555555555555555555555555555555555555555555555555555555555555555555555555555551115555555555555555555555
05555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555515155555555555555555555555
05555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555155555555555555555555555

__gff__
0000000000000000000001020202020200009000008080800000919002020202818585008080808000000200020202020000000091908004000002010202020200000002000000010101010180010101000000000101018901010101800101010000000000010101010101018001018000000000800101010101018080808080
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
565959595a6859655669595959595f595959595f5959595965665959595969695f594f4f69695959596969694f4f4f4f596549494949555655404140585955564f4f596969696969696969694f4f4f4f595959593a59595959595959593a5959595f593a3a5a00000058593a3a5959595f5959595959595959593a5959596666
665556595f4a58596547685959595959565959595969695959595f595955006f594f4f5500245659556300006d4f4f4f59596500240000004478767a585f65664f5955004224234064606133584f5556585f59593a3a3a3a5959593a3a3a59593a3a3a3a3a5a00000068593a3a3a3a593a3a3a59595955565f593a5959593a59
59656659595a5859596547685959596e005859696a425268596959595a6262484f4f6a000000005b0063004064684f4f59595965757649496547474758595a595f5a00004252006464707100585f6566595959595959593a3a3a3a3a59595959595f59593a5a01620000585f3a3a3a3a59593a3a5959656659593a3a59593a59
58595959595a585f5959654758596e6600586a52244252616b6358596a6464584f5572000053006b0073406464646d4f565959596500564f5949494959595a48595a006f425247506464647869595f5959555659595959595959593a3a3a3a595f593a593a59494a700068696969593a5959593a59595f5959593a3a3a3a3a59
58595959595a5859595f5965566a6659006b4252004041000063585a606148695a000000006300720000506464606158665f5959596562565f59595959595a585959494a42520000614b51004068595f59656659695969595959696959593a59593a3a593a3a3a5a61700000246368595959593a3a59593a3a3a3a593a595959
5959595f595a58595959594f6566595900004252006160000063585a70716b005a41000000630000404100506470715859595959595949655659595959595a58555b565a7170006f485a0040646056596859595a245b4268595a002458593a3a593a3a3a3a3a3a5a0561700000630058595959593a3a3a3a595959593a3a5959
59595959596e585959595959595f595900004252000000000073586a505100005a51000000637f40645100006164645859695969695959596556695959696a68656b005b5051007869554064600000687158695a006b4041685a000068695959593a5f596969697679767700006300583a3a3a3a3a59595959595959593a3a3a
5f5959596e00565959686969695959596f0540410000000000006b00000000005a6200000063487a51000000006164585a246b6464686969697a63586a5200005a0000684a6200005340646000000071645b006b00005051006b000063006859593a596a00626f4252007200007300585959595959596959695959595f595959
6869596e004041565a247164646d595949494a510000000000000000000000005a47000000486a5100006f53000050586a000050646061645100636b4252002355000000584a74004064647000007164606b7000000000000063000063000058593a5a00007576797676494a005300585f5969595955245b5158596969696959
00245b00005051005b71606164516d6969595a000000000000000000000000335a230000405b510000754a63000033583370000050707151006c7300425246006470000068697a71646464510071646000006170000000000063006f7300005b593a5a00006300404124586a00630058596a73565500406b716d6e5124003358
00006b00004252005b6170715100720063685a41000000000000006200006f005a000540486a00000000684a00010058006470010061600048494a004252054b646470017f7f7164646451006c50600500000072620000000063004b0000335b5f3a597f0063005051006b5200636f585a007300007160716040510000000058
0000630000425200470061510000000063006b51000000530000405100005d49594949766a00000000000068764d4d594d494e494d4d5e0068696a00484d4e594d4d4e4d76767949497679764d4d4e4e7a7f000063014c000073005b000000583a3a594a00630040410042520048495f5a05737f405171604051005347474859
000063000042520047000000000000007300630000000063004051000075695f5f59592a2a2a2a2a2a2a2a2a2a5959595959595a6d696e747164706f585959596969696a000000565500000068696969007876797679767a000000584d4976593a3a5f594a63005051004252485f2a2a597676767976767676797679797a6859
0000636f004252234b3300000000000500006300006274634051005300002358593a3a3a3a3a3a3a3a3a3a3a3a3a59593a3a5959494949495959594959593a3a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a00000000630078797a007869696a23583a3a59595a6300744c004248593a3a3a5a727272716040516f00006324002358
0100635d5e4252006b000062006f757600006301004d4d4e51000063000000583a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a593a3a3a3a3a3a3a3a3a3a3a3a3a3a593a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a05000000634c74720000004c00610058593a3a3a5a234849494a33583a3a3a595a01627160405d495e740063006f0058
4d4e4a6d6e484d4e474d4d4e4d4d494d4d4d4e4e4d4f4f4f594e4d4d4e4d4d593b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b5959593a59595f3a5f3a5959593a59593b3b3b3b3b3b3b3b3b3b3b3b3b3a3a3a594e4d4d4e4d4e4d4e4d4d4d4e4d4d59595f3b3b5a005b3b3b5b00583b3b59595f494949494959595f49494949494959
5a00405161645b000063000042586a2a59596a600071600000000040646061585a5200004041000063000071606d69595f596969696959595969695959596959596a600000007160005041006d593a3a593a59595969696969696969695f595f595a4768595a425859596561700056590040516170000000335b550000406061
5a40510000615b000063000042583a3a596a60007160010040410550647071585a52000050510000630071600061645859550040606168696a63616d696e42586e6000000071600000005041006d593a3a3a59596a4100004252240050565959595a4747585a42585f595965617000564051000061700001005b000071647071
5a517f0500005b000063010047593a3a5a60005d4d494d4e76797676767976795a524b004252000073716000050061585a0140647071512400630061700042586000740171604b00004b00504105583a3a595f5a0050417f425200001947585959594949595a42585959595965617066510048767679767676797a40604b6460
5949494a00005b410048494959593a3a5a00716d6969696e42520000000072245a52584a4252010071600040405d49595a40646464517f0000635305617042584976767676765a45456b005d767669695959595a004051754977444675763a3a5959595959554268595959595949495f00005b0024003400000071605d5b5178
5f59595a00005b504158595f593a3a3a6a7160000000006342520000000000005f7969697676764a600000757a6d6959594e4d4e4d4e5e46445d4e4e4d4e4d595500716024475b00004b005b23332463595f595a405100005b52000000583a595959596955004252565f59696959595947005b000048767976767976795b0000
6969696a00006b005068696959593a3a767676767976767679767676797a00005a5200006163716877000000244075593a595955565f5a000058593a3a3a3a3a007160536f475b00005b005b007f006359595959774545455b45454545583a5959596a464646425200566a454568695970005b7a445b454545454545455b4600
47246352000053000050412458593a3a405142520024007164700000004445455a4545454563454600006200405119583a59554041565a7000583a3a596969697160007876766e4545687969764a0047595f595a520000005b52006f75593a3a596a244600004252000053425200005861705b63005b007876764977005b7a00
474763526f0063000000504158593a3a510042520000716061600000000000405a524b000053617000006340484949593a59655051665a6170583a5955000000600000630000000000000000005b45455659595a525300755a5200757659593a5a33000000004041000073425200235800785b63785b00197f635b00005b0000
4949494949494949494a005058595f3a460042527f487676764a0000000000615a525b1a4849797676767679696969593a59594949595a0061583a5a004849497a454663006274000040417f00587a006659595a526300005b5200007158595f5a00010000716464416253425205005800005b63006876767a635b00785b0019
2a2a2a5959595f59595a00005859593a29004252756a00616058494a2a2a48495a525b00686e000000630000405123583a3a3a3a3a3a5a0071583a5a00583a592a2a4d4976764a000048797a005b635359595f5977636200584a007160585f5959494a62714b606175494949494949596f005b470000426352635b00425b4578
59593a3a59595959595a00005859593a47454545454653000068593a3a3a3a595a525b006300000000630040517f00583a3a5959593a5a7160583a5a00583a3a3a3a3a5a60475b00005b7261416b63473a3a595500636300585a71600058595559595976766a7071605659595f595959470058767679767976766977425b0000
595f3a3a3a3a5f59596a00006859593a630042526200636f0000583a3a3a3a3a5a52584a63000000004b40515d4949593a3a5f593a3a5a6000583a5a00585f3a3a3a3a5a70735b00625b6244474b63735f3a5a0000636347595a470053585965595f6a6464646451000056595959595500005b617000002442520000425b5300
593a3a595f3a59596a4445454568593a2a2a2a78794a63787a00686969593a3a5a525859492a472a2a6b2a75595f59593a5959593a595a0000583a5a0056593a6969696e60295b00635b4719485f7a70593a5a00007579765f59770563585959595a7250646451000000005659595f65000068776170007f42520000486a4700
593a5959593a595a330000000023583a3a3a3a3a3a5b63233340510000583a3a5a3358593a3b3b3b3b3a3b3b595959593a5f3a3a3a595a2333583a596500583a6061604445756e00636d7976696e6061593a5a74013400335b23347147583a3a59550000505100000000000058595959707879797a61705d767976766a240040
3a3a5f59593a595a007f00620000583a3a3a3a3a3a5a63000051000044583a3a5a00583b3b3b3b3a3b3b3b3b3b3a5f593a3a3a593a59596566593a595a00585f70717000000074006300006f347200475f3a594d4d4a19005b005d4d49593a5f550b0b0b0b0b0b0b0b0b0b0b5659595f617034005300615b23056f0053004047
59595959593b59594949494949495f593b3b3b3b3b59494949494949495f3b3b5949593b3b3b3b3b3b3b3b3b3b3b3b593b593b593b59595959593b595a0058594d4e4d4e4e4d4e4d4d4d4d4e4d4e4d49593b59595f5949495949595f593b3b59000000000000000000000000005859594e4d4e4d4d4e4d6b004e4d4e4d4d4e4d
__sfx__
010300001827018260182501825018242182421823218232182321822218222182221823218232182321822218222182221822218222182221821218212182121821218212182121821218212182121821218212
a1011c2034670290701e07017070130700f0700c070090700c4100c4200c4300c4400c4500c4600c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c470
32031c203f6703f6603f6503f6403f6403f6303f6303f6303f6203f6203f6203f6203f6303f6303f6303f6303f6303f6203f6203f6203f6203f6203f6203f6203f6103f6103f6103f6103f6103f6103f6103f610
000110202456024550245402453018730187401875018760187601876018760187501875018750187501875018742187421874218742187421874218742187421875218752187521875218752187521875218752
d048000014810188101d810198201882019820158201983016830198301d830198401f840208401f8401b85014850188501d850198501885019850158501986016860198601d860198601f86020860248601b860
d02400200d1150d1250d1350d1450d1550d1450d1350d12505115051250513505145051550514505135051250a1150a1250a1350a1450a1550a1450a1350a1250311503125031350314503155031450313503125
8d240000248502485022850228502485024850228502285024850248502285022850258502585024850248502485324850228502285024850248502285022860228632286020860208601f8601f8602086020860
d324000030014300123001230012300223002230022300222c0142c0122c0122c0122c0222c0222c0222c02229014290122901229012290222902229022290222e0142e0122e0122e0122e0222e0222e0222e022
8d240000208501d850248502085029850248502b8502c8502b85025850298502285024850258502485021850228501d850258502285029850258502e850308603186031860308602e8602c8602c8602b8602b860
a02400200d9700d9750d46501465149750d465014650d97503970039750f465034650a9750f46503455034750c9700c9750c46500465139750c465004650c975059700597511465059650c975114650596511975
c4240020294462543620426184161da5019a10144260c4362b44627436224261f4161fa501ba1016426134362b44627436244261f4161fa501ba1018426134362c44629436244262041620a501da101842614436
3024000030b503072231b5030b50307222cb5030b5031b5030b5030722307122eb502e7222e7122e7122e71230b5031b5030b5031b5033b5033722337222c7312cb502c7222c7122c7122cb502bb5029b5027b50
d42400200d1150d1250d1350d1450d1550d1550d1650d17505115051250513505145051550515505165051750a1150a1250a1350a1450a1550a1550a1650a1750f1440f1400f1400f1400f145031000310003100
3024000029b502bb5029b502cb5035b5033b5033722337222eb502cb502bb502b7222b7122b7122b7122b71224b5025b5027b5027722277122771229b502473124b5024722247122471230b502eb502cb502bb50
4424000030b503072231b5030b50307222cb5030b5031b5030b5030722307122eb502e7222e7122e7122e71230b5031b5030b5031b502bb502eb502e7222c7312cb502c7222c7122c7122cb502bb5029b5027b50
4424000029b502bb5029b502cb5035b5033b5033722337222eb502cb502bb502b7222b7122b7122b7122b71224b5025b5027b5027722277122771229b502473124b5024722247122471224b40247222471224712
4548000014545185451d545195441854519545165451954516545185451b545185441d545205451f5451b54514545185451d5451d5431f545205451f5451b5451f54520545225451f5441f54520545245451d545
3124000020717247272073724737207372473720727247171d717257271d737257371d737257371d727257171f717277271f737277371f737277371f727277172071727727207372773720737277372072727717
302400003074030720307102e7402e7202e7102c7402c7202c710000000000000000000000000000000000003074030720307102e7402e7202e7102c7402c7202c71000000000000000000000000000000000000
9024000014040000002004000000140400000020040000000d0400000019040000000d0400000019040000000f040000001b040000000f040000001b040000001404000000200400000014040000002004000000
90240000140400000020040000001404000000200400000015040000002104000000160400000022040000000f040000001b040000000f040000001b040000001404000000200000000011910119231193311943
3024000020717247272073724737207372473720727247171c717257271c737257371d737267371d727267171f717277271f737277371f737277371f72727717207172472720700247001d2241d2252ba502ba10
a02400200d9700d9750196501465149750d465019650d47503970039750f965034650a9750f46503955034750c9700c9750096500465139750c465009650c475059700597511965054650c975114650596511475
c4240020294462542620a45184161d4161942620a450c4362b4462742622a451f4161f4161b42622a45134362b4462742624a451f4161f4161b42618a45134362c4462942624a4520416204161d42618a4514436
3811000017565005051e56517535235651e535255652353519565255351e56519535235651e535255652353515565255351e56515535215651e53525565215351a565255351e5651a535215651e5352556521535
bc1100000b9500b950129650b9500b9500b95012965179250b9500b950129650b9500b9500b950129653f6250b9500b950129650b9500b9500b95012965179250b9500b950129650b9500b9500b950129653f625
8c110000172561a2361ea7025216172561a2361ea7025216172561a2361ea7025216192551725519a701e2551a2561e23621a70252161a2561e23621a70252161a2561e23621a7025216192551a25519a701c255
8c110000192561c23621a7025216192561c23621a7025216192561c23621a7025216192551a25519a701a2551c2561f23623a70262161c2561f23623a70262161c2561f23623a70262161a255192551aa7017255
bc1100000995009950129650995009950099501296515925099500995012965099500995009950129653f6250795007950129650795007950079501296513925079500795012965079500795007950129653f625
3811000015565255351c56515535215651c535255652153519565255351c56519535215651c535255652153513565255351c56513535235651c53528565235351c56528535235651c53526565235352a56526535
3a0400002a5202a5202a5102a510265102651026510265102a5102a5102a5002a500265102650026500265003f6003f6003f6143f6103f6103f6103f6103f6103f6203f6203f6303f6303f6403f6503f6603f600
8c110000172561a2561ea7025256172561a2561ea7025256172561a2561ea7025256252552325519a702a2551a2561e25621a70252561a2561e25621a70252561a2561e25621a7025256252552625519a7028255
8c110000192561c25621a7025256192561c25621a7025256192561c25621a7025256252552625519a70262551c2561f25623a70262561c2561f25623a70262561c2561f25623a7026256262551925526a7023255
321100003f6703f6303f6203f6103f6153f6003f6003f6003f6003e4233f6003c4233f6003b4133f600394133a3003930031300393003b0143b0123b0123b0123b5123b5123b5223b5323f6403f6203f6103f615
441100003f6103f6153f600264002a4512a4322a4322a432284302843228432284322643025430254352643026432264322643226432264322643223430234302643026430264302a4302a4302a4302d4302d430
441100002a4302a4302a4302b4302b4302b4302d4302d4302a4302d4302a430254302a43028430284352a430264361f436264361f436264361f436264361f4362143021432214322a4302a4322a4322a4322a432
44110000264302643026435264002a436264362a43626436284362543628436254362643025430254352643026436214362643621436264322643223430234302643026430264302a4302a4302a4302d4302d430
44110000314362d436314362d4362d436284362d436284362843625436284362543628430264302643525430264361f436264361f43626432264322643026430214302143221432214302a4322a4322a4302a430
44110000264302643226432264322a4512a4322a4322a432284302843228432284322643025430254352643026432264322643226432264322643223430234302643026430264302a4302a4302a4302d4302d430
441100002a4302a4302a4302b4302b4302b4302d4302d4302a4302d4302a4302a4302a4322a4322a4322a4322a4222a4222a4222a4222a4222a4222a4222a4222a42129421284212742126421254212442123421
441100003f6103f6153f600264002a436264362a43626436284362543628436254362643025430254352643026436214362643621436264322643223430234302643026430264302a4302a4302a4302d4302d430
44110000314303143231432314322d4312d4322d4322d43228430284322843228432284302643026435254302643226432264322643226432264322643026430214302143221432214302a4322a4322a4302a430
101100003f6103f6151ea450b4450b4000b4451ea450b4000b4450b4451ea450b4450b4000b4451ea450b4000b4450b4451ea450b4450b4000b4451ea450b4000b4450a4451ea450d4450e4450d4451ea450a445
301100000e2220e2220e2220e2220e2120e2120e2120e212122221222212222122221221212212122121221211222112221122211222112121121211212112121622216222162221622216212162121621216212
304400202ab452cb4533b452cb452ab452eb4531b4535b4536b452fb4533b452cb452bb4531b452eb4534b4532b452db452ab4526b4525b4528b4526b452fb452bb462eb3631b2635b162bb462cb362eb2633b16
141100000b8450b8450b8450b8450b8450b8450a8450a8450a8450a8450a8450a8450884508845088450884508845088450881508815088150881508815088150b8000b8000b8000b8000b8000b8000b8000b800
010c00201da4224e511de4124e511da4224e511de4124e511da3224e511de3124e511da2224e411de2124e411da1224e311de1124e311da1224e311de1124e311da1224e111de0124e011da0224e011de0124e01
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
000b000013710167101871013720167301874013750187101b7101d7201f7301b7401d7501f71022720247201f7302274024740297502b7502e750267002e7401f7002e720347002e7102e7002b7003000030000
000100000254002540025400454006540095400b5400e5401054012540145401555016550175501755017550165501555013550115500e5500c5400b540095400854007540065400554004540035400254002540
000200000c5401054014550195501e55022560265602a56016540185401b5501f5502256026560295602c5402e5401e540215502455026550295502b5502d5502f560315603456037560395603c5703e5703f570
000200000904108031090210c0210e0311203115041190411c04123051270510a6000a601126011e601266011800018000180001a0001a0001a0001c0001c0001c0001800018000180001a0001a0001a0001c000
06ff0000136453a675396051d605396052d6052e6052a6050f0001c000226051a605136050d60507605036050060517605126050d605066050260500605016050160000600016000260001600006000000000000
__music__
01 04054545
00 06050744
00 080c0744
00 41090a44
00 0b090a44
00 0d090a44
00 0e090a44
00 0f090a44
00 10094a44
00 10090a44
00 41114344
00 12114344
00 12111344
00 12151444
00 0b090a44
00 0d090a44
00 0e090a44
02 0f090a44
01 04054344
00 06050744
00 080c0744
00 41161744
00 0b161744
00 0d161744
00 0e161744
00 0f161744
00 10164a44
00 10161744
00 41114344
00 12114344
00 12111344
00 12151444
00 0b161744
00 0d161744
00 0e161744
02 0f161744
01 181a5944
00 1d1b5c44
00 581a1944
00 5d1b1c44
00 181a1944
00 1d1b1c44
00 411e4344
00 211f1944
00 21201c44
00 211f1918
00 21201c1d
00 221a1944
00 291b1c44
00 261a1958
00 271b1c5d
00 281a1918
00 251b1c1d
00 241a1918
00 231b1c1d
00 2a5b195d
00 2a5b195d
00 2a2b195d
00 2a2b195d
00 2d2c4344
00 281f1918
00 25201c1d
00 241f1918
02 23201c1d

