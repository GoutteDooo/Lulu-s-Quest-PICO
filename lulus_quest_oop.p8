pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

-- Global variables
------------------

room = {x=0, y=0}
objects = {}
types = {}
freeze = 0
shake = 0
animation_timer = 0
delay_switch = 5
dflt_delay_switch = 5
sfx_timer = 0
music_object = {false, nil, true} -- {change_music, music_pattern, music_on}
sfx_enabled = true
game_state = 0 -- 0 = title, 1 = game, 2 = restart_level, 3 = end
pulsator_room = 17
finish_room = 25
clock = {0,0} -- {min, sec}
clock_timer = 0
deaths = 0
power_counter = 0
finish = ""
PI = 3.141592653589793
title_animation_frame = 0
title_animation_duration = 45
title_light_animation = false

-- Menu items
-------------

menuitem(3, "next lvl", function() next_room() end)

-- Game state management
----------------------

function _init()
    title_screen()
end

function title_screen()
    game_state = 0
    title_light_animation = false
    title_animation_frame = 0
    music(44)
end

function begin_game()
    game_state = 1
    frames = 0
    seconds = 0
    minutes = 0
    music(48)
    init_player()
    init_room()
    init_objects()
end

-- Player class
Player = {}
Player.__index = Player

function Player:new()
    local self = setmetatable({}, Player)
    self.x = 0
    self.y = 0
    self.x_g = 0
    self.y_g = 0
    self.h = 8
    self.w = 8
    self.dx = 0
    self.dy = 0
    self.g = false
    self.c_jump = false
    self.using_light = false
    self.flip = {x=false, y=false}
    self.spd = {x=0, y=0}
    self.hitbox = {x=1, y=3, w=6, h=5}
    self.spr_off = 0
    self.was_on_ground = false
    self.p_jump = false
    self.p_dash = false
    self.grace = 0
    self.jbuffer = 0
    self.djump = 1
    self.dash_time = 0
    self.dash_effect_time = 0
    self.dash_target = {x=0, y=0}
    self.dash_accel = {x=0, y=0}
    self.hair = {}
    return self
end

function Player:update()
    if freeze > 0 then return end
    local input = btn(1) and 1 or (btn(0) and -1 or 0)
    local on_ground = self:is_solid(0,1)
    local on_ice = self:is_ice(0,1)
    if on_ground then
        self.grace = 6
        if self.djump < 1 then
            psfx(54)
            self.djump = 1
        end
    elseif self.grace > 0 then
        self.grace -= 1
    end
    local jump = btn(4) and not self.p_jump
    self.p_jump = btn(4)
    if jump then
        self.jbuffer = 4
    elseif self.jbuffer > 0 then
        self.jbuffer -= 1
    end
    if self.dash_time > 0 then
        init_object(smoke, self.x, self.y)
        self.dash_time -= 1
        self.spd.x = appr(self.spd.x, self.dash_target.x, self.dash_accel.x)
        self.spd.y = appr(self.spd.y, self.dash_target.y, self.dash_accel.y)
    else
        local maxrun = 1
        local accel = 0.6
        local deccel = 0.15
        if not on_ground then
            accel = 0.4
        elseif on_ice then
            accel = 0.05
            if input == (self.flip.x and -1 or 1) then
                accel = 0.05
            end
        end
        if abs(self.spd.x) > maxrun then
            self.spd.x = appr(self.spd.x, sign(self.spd.x) * maxrun, deccel)
        else
            self.spd.x = appr(self.spd.x, input * maxrun, accel)
        end
        if self.spd.x != 0 then
            self.flip.x = (self.spd.x < 0)
        end
        local maxfall = 2
        local gravity = 0.21
        if abs(self.spd.y) <= 0.15 then
            gravity *= 0.5
        end
        self.spd.y = min(self.spd.y + gravity, maxfall)
        if on_ground then
            self.spd.y = 0
            self.djump = 1
        elseif self.jbuffer > 0 then
            self.spd.y = -2.5
            self.jbuffer = 0
        end
    end
    self.x += self.spd.x
    self.y += self.spd.y
    -- Check collisions
    if self:is_solid(0, self.spd.y) then
        self.y -= self.spd.y
        self.spd.y = 0
    end
    if self:is_solid(self.spd.x, 0) then
        self.x -= self.spd.x
        self.spd.x = 0
    end
end

function Player:draw()
    local spr_id = self.spr_off + (self.flip.x and 1 or 0)
    spr(spr_id, self.x, self.y)
    -- Draw hair
    for _, hair in pairs(self.hair) do
        spr(hair.spr, hair.x, hair.y)
    end
end

function Player:is_solid(dx, dy)
    -- Implement collision logic here or delegate to map/room
    return false
end

function Player:is_ice(dx, dy)
    -- Implement ice logic here or delegate to map/room
    return false
end

}

-- Room entity
------------

room = {
    init = function(this, x, y, w, h)
        this.x = x
        this.y = y
        this.w = w
        this.h = h
        this.lights = {}
        this.powers = {}
        this.butterflies = {}
        this.chests = {}
    end,
    
    update = function(this)
        if freeze > 0 then return end
        
        update_butterflies(this)
        update_pulsator(this)
        update_acristals(this)
        update_doors(this)
    end,
    
    draw = function(this)
        map(0, 0, this.x, this.y, this.w, this.h, 0)
        draw_dynamic_lights(this)
        draw_acristals(this)
        draw_doors(this)
    end
}

-- Object system
--------------

function init_object(type, x, y)
    local obj = {}
    obj.x = x
    obj.y = y
    obj.flip = {x=false, y=false}
    obj.spd = {x=0, y=0}
    
    if type.init then
        type.init(obj)
    end
    
    add(objects, obj)
    return obj
end

function update_objects()
    for _, obj in pairs(objects) do
        if obj.update then
            obj.update(obj)
        end
    end
end

function draw_objects()
    for _, obj in pairs(objects) do
        if obj.draw then
            obj.draw(obj)
        end
    end
end

-- Game loop
----------

function _update()
    if game_state == 0 then
        if btnp(4) then
            title_light_animation = true
            title_animation_frame = 0
            music(48)
        end
        
        if title_light_animation then
            title_animation_frame += 1
            
            if title_animation_frame >= title_animation_duration then
                title_light_animation = false
                game_state = 1
                begin_game()
            end
        end
        
        return
    end
    
    if game_state != 2 then
        update_game()
    else
        restart_level()
    end
end

function _draw()
    if game_state == 0 then
        cls()
        print("lulu's quest", 40, 32, 7)
        print("press ❎ to start", 32, 64, 7)
        
        if title_light_animation then
            local progress = title_animation_frame / title_animation_duration
            local pulse = sin(progress * PI * 2) * 0.5 + 0.5
            
            for i = 1, 15 do
                local base = 15
                local wave = sin((i + progress * 10) * PI) * 2
                local final_color = (base + wave) * pulse
                if final_color > 15 then final_color = 15 end
                if final_color < 8 then final_color = 8 end
                pal(i, final_color)
            end
        end
        return
    end
    
    pal()
    cls()
    camera(room.x, room.y)
    
    if shake > 0 then
        shake -= 1
        if shake > 0 then
            camera(-2 + rnd(5) + room.x, -2 + rnd(5) + room.y)
        end
    end
    
    room.draw(room)
    draw_chars()
    draw_ui()
    draw_messages()
    draw_display()
    debug_print()
    
    if game_state == 3 then
        draw_end()
    end
end

function update_game()
    frames = (frames + 1) % 30
    clock_timer -= clock_timer > 0 and 1 or 0
    
    if sfx_timer > 0 then
        sfx_timer -= 1
    end
    
    if music_object[1] and music_object[3] then
        music_object[1] = false
        music(music_object[2])
    end
    
    room.update(room)
    update_chars()
    update_objects()
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
	--animations
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
	draw_hades_turnoff()
end

function draw_imaginary_light()
	local lulu_light = btn(🅾️) and lulu.select and lulu.powers_left > 0
	local i_light = lulu_light and ima_light or casting_bl and ima_light_bo or nil
	if i_light then
		circ(i_light.x, i_light.y, i_light.r, i_light.c)
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
			circ(l.x, l.y, l.r, 7)
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
        shield_cristals = {{88,18,60,32,1}},
        butterflies = {{86,17,86,17,85, 27,2, 0.5,24,"white"}}
    },
    --15
    {
        lights = {{98, 24,8}},
        powers = {1,1},
        shield_cristals = {{100,24,5,17,1}},
        butterflies = {{101,15,101,15,101.5,30,2,0.7,18,"black"}}
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
    --17 HEART
    {
			lights = {{8, 33.5, 20,"black"}},
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
			p_data = {6,47,120,"white",0},
    },
    --18
    {
			lights = {{22.5, 40, 24, "black"}},
			powers = {2,0},
			p_data = {30,46,256,"white",180},
			music = 27
	},
	--19
	{
		lights = {{41,33,8,"black"},{46,43,16,"black"}},
		powers = {3,1},
		butterflies = {{39,46,39,46,47,46,2,0.6,12,"white"},},
		chests = {{false, true, false, {"wkey"},32,37}},
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
		powers = {0,0},
		messages = {{"hint","white lights take priority\n over any light"}},
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
			{67,38,10,"black"},
			{72,41.5,10,"grey"},
		},
		powers = {1,0},
		shield_cristals = {{69,39,60,20,1},{64,45,12,12,1}},
		p_data = {70.25,46,128,"white",0,14,2}
	},
	--22
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
		music = 46
	},
	--23
	{
		lights = {
			{97,44,12,"black"},
			{104,38,28},
			{106,33},
		},
		powers = {1,1},
		chests = {{false, true, false, {"black_orb",102,43,20},101,43}},
		p_data = {110.5,29.5,240,"white",200,16,1.5},
		music = 27
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
			{119,45},
			{119,33},
		},
		powers = {3,1},
		butterflies = {
			{128,33,110,33,130,33,2,1,12,"black"},
			{116,46,113,46,126,46,1,0.6,12,"black"},
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
		powers = {7,0},
		messages = {
			{"a voice","you made a good job."},
			{"a voice","congratulations for all\nthese steps you reached."},
			{"a voice","you have now the choice,\nboth of you."},
			{"a voice","go right, but it will\nbe hard."},
			{"a voice","frankly, i wouldn't\nrecommend it."},
			{"a voice","or go left, and finish\nyour mission."},
			{"a voice","it's much safer."},
		},
		music = 47,
		display = {
			{4,412,"   <-finish"},
			{40,402,"   continue->"},
		}
	},
	--26
	{
		lights = {{24,49}},
		powers = {1,1},
		messages = {
			{"terrible voice","you will regret it !!\n gha ha ha ha !!!"}
		},
		butterflies = {
			{30,50,17,50,29,50,1,0.3,12,"dark"},
			{28,53,17,53,30,53,1,0.6,8,"dark"},
			{28,58,17,58,30,58,1,0.5,16,"dark"},
			{17,62,17,62,30,62,2,0.4,12,"dark"},
		},
		black_orbs = {{23,52,16}}
	},
	--27
	{
		lights = {{37,57}},
		powers = {0,0},
		--p_data = {x,y,r_max,type (string = "white" ou "anti"), timer (frames), acristals (number), spr_r (number), spd (float)}
	},
	--28 (idk if i keep it)
	{
		lights = {
			{50,49,16},
			{50,49,16,"anti"},
			{50,54,16,"black"},
		},
		powers = {4,1},
		butterflies = {
			{55,54,55,54,63,54,2,0.6,12,"black"},
		},
		p_data = {54.25,62,140,"white",0,14,8}
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
	--32
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
	if id == 33 then id = 1 end
	--adding powers left into counter before loading next room
	power_counter += lulu.powers_left + hades.powers_left
	room = new_room(id, x, y, w, h)
	i_room = index_room(room.x, room.y)
	create_room()
	sfx_timer = 30
	fsfx(61,3)
	clock_timer = 90
	-- !!  TEST !!
	-- if music_object[2] != 27 then reset_music(27) end
	gkeys = 2
	wkeys = 2
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
	anti_lights = {}
	mushroom = {}
	display = {}
end

function update_objects()
	-- Door collision and passing logic
	if not pactual.passed and collision(pactual, pactual == lulu and doors.lulu or doors.hades) then
		pactual.passed = true
		-- cas particulier : end choice
		if i_room == finish_room then
			if pactual == hades then 
				finish = "easy"
				end_finish()
			else
				finish = "hard"
				next_room()
			end
		end
		foreach(chars, function(c) if c.passed and c.shield.active then disable_shield(c) end end)
		if not door_sound_played then psfx(60); door_sound_played = true end
	end

	-- Room transition
	if lulu.passed and hades.passed and not room_transition_pending then
		room_transition_pending = true
		door_sound_played = false
		reinit_characters()
		delay_switch = dflt_delay_switch * 3
	end

	-- Chests
	foreach(chests, function(c)
		if collision(pactual, c) and not c.opened then
			if c.locked then
				if gkeys > 0 then
					gkeys -= 1
					open_chest(c)
				elseif c.check_lock then
					c.check_lock = false
					psfx(50)
				end
			else
				open_chest(c)
			end
		end
		if not collision(pactual, c) and c.locked and not c.check_lock then
			c.check_lock = true
		end
	end)

	-- Keys
	foreach(keys, function(k)
		if not k.collected and collision(pactual, k) then
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
		if collision_gate(pactual, g) and wkeys > 0 and not g.opened then
			psfx(54)
			wkeys -= 1
			mset(g.x/8, g.y/8, g.tile+1)
			g.opened = true
		end
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
		fsfx(59,3)
		del(mushroom, m)
		mset(m.x/8, m.y/8, 0)
		animation_timer = 75
		reset_music(27)
	end
end

--animations
function draw_objects()
	local function draw_spr(sprite_id, x, y, flip_x, flip_y)
		spr(sprite_id, x, y, 1, 1, flip_x or false, flip_y or false)
	end

	foreach(black_orbs, function(bo)
		draw_spr(frames > 20 and 23 or 22, bo.x, bo.y)
	end)

	foreach(butterflies, draw_butterfly_light)
	draw_shields()
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
	rectfill(room.x+108-offset,room.y+2,room.x+126,room.y+10,0)
	print(clock[1],room.x+110-offset,room.y+4,7)
	print(":"..clock[2],room.x+114,room.y+4,7)
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

	-- Randomly change light type if broken, otherwise alternate type
	if not broken then
		-- local types = {"white", "black", "anti"}
		-- repeat
		-- 	pulsator.light_data.type = types[flr(rnd(1) * #types) + 1]
		-- until pulsator.light_data.type != ptype
	-- else
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

function draw_end()
	rectfill(784, 400, 872, 440, 15)
	print("congrats!", 788, 404,1)
	print("you died: "..deaths.." times.")
	print("powers economy: "..power_counter, 788, 416,1)
	print("your end choice: "..finish, 788, 428,1)
end

-->8
--helper functions

function debug_print()
	print("power_counter: "..power_counter)
	print("lvl:"..i_room)
	-- print("delay_switch: "..delay_switch)
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
08888880c888888c0002e000ccc0cccc0000000000000000000000000000000000000000000000004444444440000004001155dd33dddddd33dd33dddd551100
88888888888888880022ee00cc030ccc000000000000000000000000000000000004000000040000454545455000000501115dddd33dddddd33333ddddd51110
8888888888888888022eeee0c03630cc0088e0000000000000000000000000000004000000464000454545455000000501155ddddd3dddddddddd3ddddd55110
88888888c889889822eeeeee0366630c08888e000000000000088000000880000004000000040000444444444000000401155ddddd3dddddddddd3ddddd55110
88898898c888888800094000c03630cc0088e00000000000008838000088b800000400000004000000000000000000001115dddddd3ddd11111d33dddddd5111
08888880c88888c800094000cc030ccc000e0000000000000838888008b88880000400000004400000000000000000001155dddddd3dd111111133dddddd5511
00888800c88888cc00094000ccc0cccc00000000000000000004400000044000000400000004000000000000000000001155dddddd3d1111111113ddddddd511
00800800c88cc8cc00094000cccccccc00000000000000000004400000044000000000000000000000000000000000001155dddddd311111111113ddddddd511
66666666c0c00000c0c000000005500008800880000000000000000000000000000000000000000000000000000000001155ddddd3311111111133ddddddd511
6555555600000444000000000055550088888888000000000000000000000000000a0000000a0000000000000000000011555ddd33d33111111131dddddd5511
655555560aaa44400aaa44440558855088888888080800000007000000080000000a000000a9a000888888880000000011555ddd3dd13333311131dddddd3311
655555560aaaaaa00aaaaaaa5588885588888788888880000076700000828000000a0000000a0000888888880000000011155ddd3ddd11113111333333333111
655555560000000000000000588998858888778888888000076a6700082a2800000a0000000a0000888888880000000001155ddd3dddd11133113ddddd555110
6555555600000000000000005899998508888880088800000076700000828000000a0000000aa000888888880000000001155ddd333ddd111313dddddd555110
6555555600000000000000005899798500888800008000000007000000080000000a0000000a00008888888800000000011155dd3d33ddddd3333ddddd551110
666666660000000000000000589779850008800000000000000000000000000000000000000000008888888800000000001155333dd33ddddddd3dddd5551100
00000000ccc0ccccccc8cccc0005500000444400004554000000000000000000000aa000ccc0cccc88888888888888880011153555dd3ddddddd33d555511100
c0c00099cc0a0ccccc808ccc005555000045540000000000000000000999999004444440cc0a0ccc88888888888888880001113355dd333dddddd33555111000
00000444c0a7a0ccc80008cc055dd5500044440000000000000b00009974449946665554c0a9a0cc88888888888888880000113555555d33dddddd3351110000
0aaa44400a777a0c8000008c55dddd55004554000000000000b3b0009744444946655554cc0a0ccc888888888888888800000111555555533555555511100000
0aaaaaa0c0a7a0ccc80008cc5dd22dd500444400000000000b3a3b009999999997444449cc0a0ccc888888888888888800000011115555553555551111000000
00000000cc0a0ccccc808ccc5d2222d5004554000000000000b3b000974aa44997444449cc0aa0cc888888888888888800000001111115553351111110000000
00000000ccc0ccccccc8cccc5d2272d50044440000000000000b00009744444997444449cc0a0ccc888888888888888800000000011111111311111000000000
00000000cccccccccccccccc5d2772d50045540000455400000000009999999999999999ccc0cccc888888888888888800000000000011111111000000000000
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
272704461504141050164607170675339696969696f5959596959596969696f5363536b6005000000010b5757575750094a4545464b500002436250000005085
f4969696969696f596969696969696f5959696969696959595969596969695950043000000000000000200000000b00000000000000000000000000000000000
62174606000515d5e5001646063575005474061646d695a654d6a6543754548536b43600007500001787b6757575876795a5100000b500002436250000849495
a5000005140000b61000003716753285a600360024366596552474000000d695a102000000000000000200620000000000009100000000000000000000000000
94949494a40414d6e60017468494d4d4910507174615b500000024250000918536869774a77500041536257475640024f595e50000b5000024362500006595f5
a5918494a71400d5e526260017750085000036002436000000242500000044d66202020000020202020202020000000002757575757575757575757575000000
f59595f5a506164607174657969595f5946767677700b57400002425876797f5362536b67575757500362500746200249595a50004b654545454643500006595
f56796a6000514d6e646467475755796500036262436000047242526000000000200000000000000000000020200000000000000000000000000000075000075
95959696e60000164646464646869696a55454545454b5747400041400876785a775b475757575757574250000b4072495955504461500002436253600000085
a575750000047406002727167575d59494946767677400007467949494a464440000000000000010000000000000000000000000107575757500000075000000
96a67575000000001646464646070000a50024d56767976767e50515004362853625b57575757400000075644485772495a50446150000002436252700000085
a533750017b4360000000000758495f595a51405142500000016d695f5a50000000002020000027575020000000000020000000075a0a0a0a075000075000000
32757575757500001774460616740762a50057e60415b50514b6041400d594956767a6171500a0b0b0b0000074b60024f5a54615001707912436252600000085
a500755016b63600000000008796969595a61607161400000017068695a50000000000000002023233020200000002000000007500a00000a000750075750000
00757575757575758494a40717849494a50000041500b600051405150085f595460617060000a00000a000000035008795a61500174646d5e536253600007585
a5747574001646072635261746461485a6000005140514211706001685a50000000000000202020000020202000000000000007532a00000a033750075000000
e4d494d494e4d494959595e494f59595957704150000750000051447b4659595060415000074a0a0a0a0750017461400a5757562164674d6e674253662757485
956797a7a167a41516846767676767950700000016148494a454545486a60000020000000002020202020200000000000000007500a00000a000750075000000
95f5959696969695f5959696969595f5a50415000010755000d5d4a4b54465950457a735000075000075001775846767a57575576797676767976797976767f5
95e646150005b50000b5000446159185061000000084959695a4350000003233000200000000020202020000000200000000000074a0a0a0a074000075000075
f5955504464614659655003625659595a5150057676797676795f5a5b644006506430074000000000000005797a63233a5757575004300750036750016061685
e6461500b400867700b604b41500d59507171426849555006595a426000000000000000000000002020000000002000000000000007575757500000075000000
955517461516460700000036251465f59577470005157533328595e61607003767a43562740026000000007575430000a5747575477475757536747517071785
46150700b5000043000446b5004785f5676797679655000000659667676767a40000000000000002020000910202009274740000000000000000000075000000
55174646141746060000003625051465a500b4002425750000d6a6000016070000866767676777545484679767679767959767676797676797679767a7757585
1500879767676767676767a600d59595a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a250000002a202020202a2a2020200000275757474747474a17475757575740000
00164646464646140000003625000514a55485a42425879767a7000026001607002425361607000000b6164646063600a5323300753600757500750514747585
4100001607a000044606a0000085a3a39595b38696969595959696969696969602020202a3a3a30202a3a3a30200020200000000000000000000000000000000
00001646464646060000003625140005a5008595a414004362b500353600001691242536001607750000174646073692a5000074753675757475757505147585
a4000062160717460600a0006285a30295f5b30000008696a600000000000000a3a3a3a3a3a3a30202020202020002a300506200000000740000000000000062
000000054646460700000036250514009594f5f595e4e4e494a5003636260000e4d494e4d494d4e4d494e494d494e494959494949494949494949494949494f5
95949494a40446060000a0d59495a3029595b3a2a2a2a2a2a2a2a28494949494b3b3b3b3b3b3b30291910000430002a302020202020202020202020202020202
02020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202
02020202020202020202020202020202940202020202020202020202020202029595959595959555659595959595959595959595959595556595959595959595
02020202000000000000000000000032020000000000000000000233000000020200000000000000000000000000000202000000000000000000000000000002
02020202020002020202020202020202020000000000000000000000000000029595959595955504146595959595959595959595959555041465959595959595
02020200000000000000000000000000020000000000020010000200000000020200000000000000000000000000000202100000000000000000000000000002
02020202020002020202020202020202020000000000000000000000000000029595959595550005150065959595959595959595955500051500659595959595
02330000000000000000001000020202020000000000020202020202020200020200000000000000000000000000000202020202000000020275000000005002
0202020202b002020202020202020202020000000000000000000000000000029595959555000414041400659595959595959595550004140414006595959595
02005000000000000000020200454545029100000000000002000000000000020200000000000000000000000000000202757500000000000075757502020202
0202020202b002020202020202020202020000000000000000000000000000029595955500000515051500006595959595959555000005150515000065959595
02020200000000000002020000450202020202020002020202000000000202020200000000000000000000000000000202757575000000000075757500000002
0202020202000202020202020202020202000000c4c4c4c400000000000000029595550000041404140414000065959595955500000414041404140000659595
0200000000000000000000000045020202000000000200000000a102020202020200000000000000000000000000000202757575020202000002020200000002
0202020200000000000000000000000202000000c40000c4c4000000000000029555000000051505150515000000659595550000000515051505150000006595
02000000000202020202020000450202020002020202610000000000000000020200000000000000000000000000000202027575000000000000000000000202
0233000200000000000000000000320202000000c40000c4c4000000000000025500000004140414041404140000006555000000041404140414041400000065
02000000000000000000000000450202020000000002020202020202020200020200000000000000000000000000000202006275750000000000000000620002
0200104100000000000000000050000202000000c4c4c4c400000000000000020000000005150515051505150000000056000000051505150515051500000066
02000000000000000000000002450202020000000000000000020000000000020200000000000000000000000000000202000202757502020202000002020002
0202020202000202020202020202020202000000c40000c4c4000000000000020000000414041404140414041400000095560004140414041404140414006695
020200000000000000000000004502020202020202020202000202020000a1020200000000000000000000000000000202000000000000000000000000000002
0202020202000202020202020202020202000000c4000000c4000000000000021000000515051505150515051500005095955605150515051505150515669595
02020202020276767676767676450202020000000000000000020000000000020200000000000000000000000000000202027500000000000000000000750202
0202020202000202020202020202020202000000c4c4c4c4c4000000000000026767677774767476747476576767676745454545454545454545454545454545
02020202020245454545454545450202020002020202020202020202020200020200000000000000000000000000000202757502020202000002020202757502
02020202020002020202020202020202020000000000000000000000000000024545454545454545454545454545454545454545454545454545454545454545
02020202024545454545454545450202020000000232020000000200000000020200000000000000000000000000000202757575330000000000003275757502
02020202020002020202020202020202020000000000000000000000000000024545454545454545454545454545454545454545454545454545454545454545
02020202024545454545454545450202020002004300020050000000000000020200000000000000000000000000000202027575000000000000000075750202
0202020202b002020202020202020202020000000000000000000000000000024545454545454545454545454545454545454545454545454545454545454545
02020202454545454545454545450202020202020202020202020202020202020202020202020202020202020202020202020202020000000000000202020202
0202020202b002020202020202020202020202020202020202020202020202024545454545454545454545454545454545454545454545454545454545454545
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
0000000000000000000001020202020200009000000000000000919002020202818585000000808000000200020202028500000091908004000002010202020280808002808080010101010100010101808080800101018901010101000101018080808080010101010101010001018080808080800101010101018080808000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
565959595a6859655669595959595f595959595f5959595965665959595969695f594f4f69695959596969694f4f4f4f596556696969555655404140585955564f4f696969696969696969694f4f4f4f595959593a59595959595959593a5959595f593a3a5a00000058593a3a5959595f5959595959595959593a5959596666
665556595f4a58596547685959595959565959595969695959595f595955006f594f4f5500005659556300006d4f4f4f59596500000000004478767a585f65664f5a00004252234064606133584f5556585f59593a3a3a3a5959593a3a3a59593a3a3a3a3a5a00000068593a3a3a3a593a3a3a59595955565f593a5959593a59
59656659595a5859596547685959596e005859696a425268596959595a6262484f4f6a000000005b0063004064684f4f59595965757649496547474758595a595f5a00004252006464707100585f6566595959595959593a3a3a3a3a59595959595f59593a5a01620000585f3a3a3a3a59593a3a5959656659593a3a59593a59
58595959595a585f5959654758596e6600586a52004252616b6358596a6464584f5572000053006b0073406464646d4f565959596500564f5949494959595a48696a006f425247506464647869595f5959555659595959595959593a3a3a3a595f593a593a59494a700068696969593a5959593a59595f5959593a3a3a3a3a59
58595959595a5859595f5965566a6659006b4252004041000063585a606148695a000000006300720000506464606158665f5959596562565f59595959595a586451004742520000614751004068595f59656659695969595959696959593a59593a3a593a3a3a5a61700000006368595959593a3a59593a3a3a3a593a595959
5959595f595a58595959594f6566595900004252006160000063585a70716b005a41000000630000404100506470715859595959595949655659595959595a58510000007170006f47720040646056596859595a005b4268595a000058593a3a593a3a3a3a3a3a5a0561700000630058595959593a3a3a3a595959593a3a5959
59595959596e585959595959595f595900004252000000000073586a505100005a51000000637f40645100006164645859695969695959596556695959696a68000000005051004700534064600000687158695a006b4041685a000068695959593a5f596969697679767700006300583a3a3a3a3a59595959595959593a3a3a
5f5959596e00565959686969695959596f0540410000000000006b00000000005a6200000063487a51000000006164585a006b6464686969697a63586a520000000000004b6200005340646000000071645b006b00005051006b000063006859593a596a00626f4252007200007300585959595959596959695959595f595959
6869596e004041565a007164646d595949494a510000000000000000000000005a47000000486a5100006f53000050586a000050646061645100636b4252002370000000584a74004064647000007164606b7000000000000063000063000058593a5a00007576797676494a005300585f5969595955005b5158596969696959
00005b00005051005b71606164516d6969595a000000000000000000000000335a230000405b510000004b6300003358337000005070715100007300424746006470000068697a71646464647071646000006170000000000063006f7300005b593a5a00006300404100586a00630058596a73565500406b716d6e5100003358
00006b00004252005b6170715100720063685a41000000000000006200006f005a000540486a00000000684a0001005800647001006160006f0053004252054b646470017f7f7164646464646464600500000072620000000063004b0000335b5f3a597f0063005051006b52006300585a007300007160716040510000000058
0000630000425200470061510000000063006b51000000530000405100005d49594949496a000000000000684d4d4d594949494a00787a0048494a00484d4e594d4d4e4d76767976767679764d4d4e4e7a7f0000630100000073005b000000583a3a594a00630040410042520048495f5a05737f405171604051005347474859
000063000042520047000000000000007300630000000063004051000075695f5f5959592a2a2a2a2a2a2a2a595959595959595a0071707458595a6f585959595f59696a000000000000000068595f59007876797679767a000000584d4976593a3a5f594a63005051004252485f2a2a597676767976767676797679797a6859
0000636f004252234b330000000000050000630000627463405100530000235859593a3a3a3a3a3a3a3a3a3a3a3a59593a3a5959494949495959594959593a3a59592a2a2a2a2a2a2a2a2a2a2a2a595900000000630078797a007869696a23583a3a59595a63000000004248593a3a3a5a014060716040510000006300002358
0100635d5e4252006b000062006f757600006301004d4d4e5100006300000058593a3a3a3a3a3a3a3a3a3a3a3a3a3a59593a3a3a3a3a3a3a3a3a3a3a3a3a3a59593a3a3a3a3a3a3a3a3a3a3a3a3a3a5905000000630074720000000000610058593a3a3a5a234b2a2a4b33583a3a3a595a40517160405d495e007463006f0058
4d4e4a6d6e484d4e474d4d4e4d4d494d4d4d4e4e4d4f4f4f594e4d4d4e4d4d595f5959595959595959595959595959595959593a59595f3a5f3a5959593a59593b3b3b3b3b3b3b3b3b3b3b3b3b3a3a3a594e4d4d4e4d4e4d4e4d4d4d4e4d4d59595f3b3b5a005b3b3b5b00583b3b59595f494949494959595f49494949494959
5a00405161645b000063000042586a2a59596a600071600000000040646061585a5200004041000063000071606d69595f596969696959595969695959596959596a600000007160005041006d593a3a593a59595969696969696969595f59652020202020002020202020202020202000405161700a0000335b470000406061
5a40510000615b000063000042583a3a596a60007160010040410550647071585a52000050510000630071600061645859550040606168696a63616d696e42586e6000000071600000005041006d593a3a3a59596a4100004252000068595959202020202000202020202020202020204051000061700001005b000071647071
5a517f0500005b000063010047593a3a5a60005d4d494d4e76797676767976795a524b004252000073716000050061585a0140647071510000630061700042586000740171604b00004b00504105583a3a595f5a0050417f4252000019585f5920202020200020202020202020202020510048767679767676797a40604b6460
5949494a00005b410048494959593a3a5a00716d6969696e42520000000072005a52584a4252010071600000754949595a40646464517f0000635305617042584976767676765a45455b005d767669695959595a004051754977444675593a3a2020202020002020202020202020202000005b000000340000007160475b5178
5f59595a00005b504158595f593a3a3a6a7160000000006342520000000000005f79696976767679770000000068595f594e4d4e4d4e5e46445d4e4e4d4e4d596a00716000475b00005b005b23330063595f595a405100005b52000000583a592020202020002020202020202020202047005b000048767976767976795b0000
6969696a00006b005068696959593a3a767676767976767679767676797a00005a520000006300007200000000406859593a3a3a3a3a5a0000585f5959593a3a007160536f475b00005b005b007f006359595959774545455b45454545583a592020202020002020202020202020202070005b7a445b454545454545455b4600
47006352000053000050410058593a3a405142520000007164700000004445455a4545454563454600006200405119585f595959593a5a70005859593a3a3a597160007876766e4545687969764a0047595f595a520000005b52006f75593a3a2020202020000000000000000000002061705b63005b007876764977005b7a00
474763526f0063000000504158593a3a510042520000716061600000000000405a524b00005300000000634048494959593a3a3a3a3a5a617058593a3a593a59600000630000000000000000005b45455659595a525300755a5200757659593a2033000000000000000000000000232000785b63785b00197f635b00005b0000
4949494949494949494a005058595f3a460042527f487676764a0000000000615a525b1a484979767676767969696959593a59595f595a0061583a3a3a593a5f7a454663006274000040417f00587a006659595a526300005b5200007158595f2000010000000000000000000005002000005b63006876767a635b00785b0019
2a2a2a5959595f59595a00005859593a29004252756a00616058492a2a2a4d495a525b00686e00000063000040512358593a3a3a3a3a5a0071583a593a593a592a2a4d4976764a000048797a005b635359595f5977636200584a007160585f59202020202000002020202020202020206f005b470000426352635b00425b4578
59593a3a59595959595a00005859593a47454545454653000068593a3a3a3a595a525b006300000000630040517f0058593a5959593a5a7160583a593a593a3a3a3a3a5a60475b00005b7261415b63473a3a595500636300585a71600058595520202020000000002020202020202020470058767679767976766977425b0000
595f3a3a3a3a5f59596a00006859593a630042526200636f0000583a3a3a3a3a5a52584a63000000004b40515d4949593a3a5f593a3a5a6000583a593a595f595f3a3a5a70735b00625b6244475b63735f3a5a0000636347595a4700535859652020200000000000002020202020202000005b617000000042520000425b5300
593a3a595f3a59596a4445454568593a2a2a2a78794a63787a00686969593a3a5a525859492a472a2a6b2a75595f5959595959593a595a0000583a593a3a59596969696e60295b00635b4719485f7a70593a5a00007579765f597705635859592020200000000000000020202020202000006b476170007f42520000486b4700
593a5959593a595a330000000023583a3a3a3a3a3a5b63233340510000583a3a5a3358593a3b3b3b3b3a3b3b59595959595f3a3a3a595a2333583a59593a3a3a6061604445756e00636d7976696e6061593a5a74013400335b23347147583a3a20200000000000000000002020202020707879797a61705d767976766a000040
3a3a5f59593a595a007f00620000583a3a3a3a3a3a5a63000051000044583a3a5a00583b3b3b3b3a3b3b3b3b3b3a5f593a3a3a593a595a0000583a59593a595f70717000000074006300006f347200475f3a594d4d4a19005b005d4d49593a5f20200b0b0b0b0b0b0b0b0b0b20202020617034005300615b23056f0053004064
59595959593b59594949494949495f593b3b3b3b3b59494949494949495f3b3b5949593b3b3b3b3b3b3b3b3b3b3b3b593b593b593b59594949593b5f593b3b594d4e4d4e4e4d4e4d4d4d4d4e4d4e4d49593b59595f5949495949595f593b3b59000000000000000000000000202020204e4d4e4d4d4e4d6b004e4d4e4d4d4e4d
__sfx__
010300001827018260182501825018242182421823218232182321822218222182221823218232182321822218222182221822218222182221821218212182121821218212182121821218212182121821218212
a1011c2034670290701e07017070130700f0700c070090700c4100c4200c4300c4400c4500c4600c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c4700c470
33031c203f6703f6603f6503f6403f6403f6303f6303f6303f6203f6203f6203f6203f6303f6303f6303f6303f6303f6203f6203f6203f6203f6203f6203f6203f6103f6103f6103f6103f6103f6103f6103f610
010110202456024550245402453018730187401875018760187601876018760187501875018750187501875018742187421874218742187421874218742187421875218752187521875218752187521875218752
d148000014810188101d810198201882019820158201983016830198301d830198401f840208401f8401b85014850188501d850198501885019850158501986016860198601d860198601f86020860248601b860
d12400200d1150d1250d1350d1450d1550d1450d1350d12505115051250513505145051550514505135051250a1150a1250a1350a1450a1550a1450a1350a1250311503125031350314503155031450313503125
8d240000248502485022850228502485024850228502285024850248502285022850258502585024850248502485324850228502285024850248502285022860228632286020860208601f8601f8602086020860
d324000030014300123001230012300223002230022300222c0142c0122c0122c0122c0222c0222c0222c02229014290122901229012290222902229022290222e0142e0122e0122e0122e0222e0222e0222e022
45240000208501d850248502085029850248502b8502c8502b85025850298502285024850258502485021850228501d850258502285029850258502e850308603186031860308602e8602c8602c8602b8602b860
a12400200d9700d9750d46501465149750d465014650d97503970039750f465034650a9750f46503455034750c9700c9750c46500465139750c465004650c975059700597511465059650c975114650596511975
c5240020294462543620426184161da5019a10144260c4362b44627436224261f4161fa501ba1016426134362b44627436244261f4161fa501ba1018426134362c44629436244262041620a501da101842614436
3124000030b503072231b5030b50307222cb5030b5031b5030b5030722307122eb502e7222e7122e7122e71230b5031b5030b5031b5033b5033722337222c7312cb502c7222c7122c7122cb502bb5029b5027b50
d52400200d1150d1250d1350d1450d1550d1550d1650d17505115051250513505145051550515505165051750a1150a1250a1350a1450a1550a1550a1650a1750f1440f1400f1400f1400f145031000310003100
3124000029b502bb5029b502cb5035b5033b5033722337222eb502cb502bb502b7222b7122b7122b7122b71224b5025b5027b5027722277122771229b502473124b5024722247122471230b502eb502cb502bb50
4524000030b503072231b5030b50307222cb5030b5031b5030b5030722307122eb502e7222e7122e7122e71230b5031b5030b5031b502bb502eb502e7222c7312cb502c7222c7122c7122cb502bb5029b5027b50
4524000029b502bb5029b502cb5035b5033b5033722337222eb502cb502bb502b7222b7122b7122b7122b71224b5025b5027b5027722277122771229b502473124b5024722247122471224b40247222471224712
4548000014545185451d545195441854519545165451954516545185451b545185441d545205451f5451b54514545185451d5451d5431f545205451f5451b5451f54520545225451f5441f54520545245451d545
3124000020717247272073724737207372473720727247171d717257271d737257371d737257371d727257171f717277271f737277371f737277371f727277172071727727207372773720737277372072727717
312400003074030720307102e7402e7202e7102c7402c7202c710000000000000000000000000000000000003074030720307102e7402e7202e7102c7402c7202c71000000000000000000000000000000000000
9124000014040000002004000000140400000020040000000d0400000019040000000d0400000019040000000f040000001b040000000f040000001b040000001404000000200400000014040000002004000000
91240000140400000020040000001404000000200400000015040000002104000000160400000022040000000f040000001b040000000f040000001b040000001404000000200000000011910119231193311943
3124000020717247272073724737207372473720727247171c717257271c737257371d737267371d727267171f717277271f737277371f737277371f72727717207172472720700247001d2241d2252ba502ba10
a12400200d9700d9750196501465149750d465019650d47503970039750f965034650a9750f46503955034750c9700c9750096500465139750c465009650c475059700597511965054650c975114650596511475
c5240020294462542620a45184161d4161942620a450c4362b4462742622a451f4161f4161b42622a45134362b4462742624a451f4161f4161b42618a45134362c4462942624a4520416204161d42618a4514436
3911000017565005051e56517535235651e535255652353519565255351e56519535235651e535255652353515565255351e56515535215651e53525565215351a565255351e5651a535215651e5352556521535
bd1100000b9500b950129650b9500b9500b95012965179250b9500b950129650b9500b9500b950129653f6250b9500b950129650b9500b9500b95012965179250b9500b950129650b9500b9500b950129653f625
8d110000172561a2361ea7025216172561a2361ea7025216172561a2361ea7025216192551725519a701e2551a2561e23621a70252161a2561e23621a70252161a2561e23621a7025216192551a25519a701c255
8d110000192561c23621a7025216192561c23621a7025216192561c23621a7025216192551a25519a701a2551c2561f23623a70262161c2561f23623a70262161c2561f23623a70262161a255192551aa7017255
bd1100000995009950129650995009950099501296515925099500995012965099500995009950129653f6250795007950129650795007950079501296513925079500795012965079500795007950129653f625
3911000015565255351c56515535215651c535255652153519565255351c56519535215651c535255652153513565255351c56513535235651c53528565235351c56528535235651c53526565235352a56526535
3b0400002a5202a5202a5102a510265102651026510265102a5102a5102a5002a500265102650026500265003f6003f6003f6143f6103f6103f6103f6103f6103f6203f6203f6303f6303f6403f6503f6603f600
8d110000172561a2561ea7025256172561a2561ea7025256172561a2561ea7025256252552325519a702a2551a2561e25621a70252561a2561e25621a70252561a2561e25621a7025256252552625519a7028255
8d110000192561c25621a7025256192561c25621a7025256192561c25621a7025256252552625519a70262551c2561f25623a70262561c2561f25623a70262561c2561f25623a7026256262551925526a7023255
331100003f6703f6303f6203f6103f6153f6003f6003f6003f6003e4233f6003c4233f6003b4133f600394133a3003930031300393003b0143b0123b0123b0123b5123b5123b5223b5323f6403f6203f6103f615
451100003f6103f6153f600264002a4512a4322a4322a432284302843228432284322643025430254352643026432264322643226432264322643223430234302643026430264302a4302a4302a4302d4302d430
451100002a4302a4302a4302b4302b4302b4302d4302d4302a4302d4302a430254302a43028430284352a430264361f436264361f436264361f436264361f4362143021432214322a4302a4322a4322a4322a432
45110000264302643026435264002a436264362a43626436284362543628436254362643025430254352643026436214362643621436264322643223430234302643026430264302a4302a4302a4302d4302d430
45110000314362d436314362d4362d436284362d436284362843625436284362543628430264302643525430264361f436264361f43626432264322643026430214302143221432214302a4322a4322a4302a430
45110000264302643226432264322a4512a4322a4322a432284302843228432284322643025430254352643026432264322643226432264322643223430234302643026430264302a4302a4302a4302d4302d430
451100002a4302a4302a4302b4302b4302b4302d4302d4302a4302d4302a4302a4302a4322a4322a4322a4322a4222a4222a4222a4222a4222a4222a4222a4222a42129421284212742126421254212442123421
451100003f6103f6153f600264002a436264362a43626436284362543628436254362643025430254352643026436214362643621436264322643223430234302643026430264302a4302a4302a4302d4302d430
45110000314303143231432314322d4312d4322d4322d43228430284322843228432284302643026435254302643226432264322643226432264322643026430214302143221432214302a4322a4322a4302a430
111100003f6103f6151ea450b4450b4000b4451ea450b4000b4450b4451ea450b4450b4000b4451ea450b4000b4450b4451ea450b4450b4000b4451ea450b4000b4450a4451ea450d4450e4450d4451ea450a445
311100000e2220e2220e2220e2220e2120e2120e2120e212122221222212222122221221212212122121221211222112221122211222112121121211212112121622216222162221622216212162121621216212
314400002ab452cb4533b452cb452ab452eb4531b4535b45000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
151100000b8450b8450b8450b8450b8450b8450a8450a8450a8450a8450a8450a8450884508845088450884508845088450881508815088150881508815088150b8000b8000b8000b8000b8000b8000b8000b800
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
000200000904108031090210c0210e0311203115041190411c04123051270510a6000a601126011e601266011800018000180001a0001a0001a0001c0001c0001c0001800018000180001a0001a0001a0001c000
06ff0000136453a675396051d605396052d6052e6052a6050f0001c000226051a605136050d60507605036050060517605126050d605066050260500605016050160000600016000260001600006000000000000
__music__
01 04054344
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