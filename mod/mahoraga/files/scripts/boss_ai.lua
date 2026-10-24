dofile_once("mods/mahoraga/files/scripts/common.lua")

local me = GetUpdatedEntityID()
local now = GameGetFrameNum()
local x, y = EntityGetTransform( me )
local B = MAHORAGA_BOSS.mahoraga
local summon = mh_is_summon( me )   -- the Summon Mahoraga perk's ally: fights everything but the player

-- Wheel turning animation after an adaptation (boss_damage.lua sets wheel_spin).
do
	local spin = mh_get( me, "wheel_spin", -1000 )
	local t = now - spin
	local sprites = EntityGetComponent( me, "SpriteComponent", "mahoraga_wheel" )
	if sprites ~= nil and t >= 0 and t <= 40 then
		local img = B.wheel_sprite
		if t < 36 then img = "mods/mahoraga/files/gfx/wheel_" .. tostring( math.floor( t / 6 ) ) .. ".png" end
		ComponentSetValue2( sprites[1], "image_file", img )
		EntityRefreshSprite( me, sprites[1] )
	end
end

local dmc = EntityGetFirstComponent( me, "DamageModelComponent" )
local hp, max_hp = ComponentGetValue2( dmc, "hp" ), ComponentGetValue2( dmc, "max_hp" )
local phase = 1
if hp < max_hp * B.phase2_hp_frac then phase = 2 end
if phase == 2 and not summon and mh_get( me, "phase2_announced", 0 ) == 0 then
	mh_set( me, "phase2_announced", 1 )
	GamePrintImportant( "$animal_mahoraga", "The wheel spins faster..." )
	GamePlaySound( "data/audio/Desktop/event_cues.bank", "event_cues/angered_the_gods/create", x, y )
end

local player = mh_player()
if player == nil then return end
local px, py = EntityGetTransform( player )
py = py - 6

-- Your Mahoraga aims at the nearest enemy instead, keeps up with you and takes your adaptations.
if summon then
	if now % 30 == 0 then mh_summon_sync( me, player, "summon" ) end
	local target = mh_summon_target( me, x, y, 450 )
	if target ~= nil then
		px, py = EntityGetTransform( target )
		py = py - 6
	elseif mh_get( me, "attack", 0 ) ~= 0 then
		px, py = mh_get( me, "aim_x", px ), mh_get( me, "aim_y", py )
	else
		if ( px - x ) ^ 2 + ( py - y ) ^ 2 > 260 * 260 then
			EntityLoad( "data/entities/particles/poof_white_appear.xml", x, y - 20 )
			EntitySetTransform( me, px - 30, py )
			EntityLoad( "data/entities/particles/poof_white_appear.xml", px - 30, py - 20 )
		end
		return
	end
end

local ai = EntityGetFirstComponentIncludingDisabled( me, "AnimalAIComponent" )
local cdc = EntityGetFirstComponent( me, "CharacterDataComponent" )

local function set_ai( on ) if ai ~= nil then EntitySetComponentIsEnabled( me, ai, on ) end end
local function face( tx ) local _, _, _, sx = EntityGetTransform( me ); EntitySetTransform( me, x, y, 0, ( tx < x ) and -1 or 1, 1 ) end
local function sound( a ) GamePlaySound( a.sound_bank, a.sound_event, x, y ) end
-- Escape mode: the chaser runs straight at the player through everything (a dig component carves the way)
-- until he is within escape_fight_distance, then fights as usual.
if mh_get( me, "chaser", 0 ) == 1 then
	local dig = EntityGetFirstComponentIncludingDisabled( me, "CellEaterComponent", "mahoraga_dig" )
	local tx, ty = px, py + 6
	local d = math.sqrt( ( tx - x ) ^ 2 + ( ty - y ) ^ 2 ) + 0.01
	local traveling = mh_get( me, "traveling", 0 ) == 1
	local far = MAHORAGA_WORLD.escape_fight_distance
	if mh_get( me, "attack", 0 ) == 0 and ( d > far or ( traveling and d > far * 0.6 ) ) then
		if not traveling then
			mh_set( me, "traveling", 1 )
			set_ai( false )
		end
		if dig ~= nil then EntitySetComponentIsEnabled( me, dig, true ) end
		local sp = MAHORAGA_WORLD.escape_run_speed
		EntitySetTransform( me, x + ( tx - x ) / d * sp, y + ( ty - y ) / d * sp, 0, ( tx < x ) and -1 or 1, 1 )
		if cdc ~= nil then ComponentSetValue2( cdc, "mVelocity", 0, 0 ) end
		if now % 30 == 0 then GamePlayAnimation( me, "run", 10 ) end
		return
	elseif traveling then
		mh_set( me, "traveling", 0 )
		set_ai( true )
		if dig ~= nil then EntitySetComponentIsEnabled( me, dig, false ) end
	end
end

-- Adapted to drowning: in water he swims straight at his target instead of floundering.
if cdc ~= nil and mh_get( me, "adapted_drowning", 0 ) == 1 and mh_get( me, "attack", 0 ) == 0 then
	local cpc = EntityGetFirstComponent( me, "CharacterPlatformingComponent" )
	if cpc ~= nil and ComponentGetValue2( cpc, "mFramesSwimming" ) > 0 then
		local d = math.sqrt( ( px - x ) ^ 2 + ( py - y ) ^ 2 ) + 0.01
		ComponentSetValue2( cdc, "mVelocity", ( px - x ) / d * 140, ( py - y ) / d * 140 )
	end
end

-- attack animations (attacks sheet, animation column) go back to "stand" when they end, so the AI's walk/jump take over again
local function anim( name ) GamePlayAnimation( me, name, 10, "stand", 0 ) end
local power = mh_power( me )
local function shoot( pid, sx, sy, vx, vy )
	local p = MAHORAGA_PROJECTILES[ pid ]
	local e = shoot_projectile( me, p.file, sx, sy, vx, vy )
	mh_scale_projectile( e, power )
	if summon and e ~= nil then
		local pc = EntityGetFirstComponentIncludingDisabled( e, "ProjectileComponent" )
		if pc ~= nil then
			ComponentSetValue2( pc, "never_hit_player", true )
			-- explosions ignore herds and would hurt the player: the blast keeps its look and digging,
			-- and summon_blast.lua deals its damage to everyone else when the projectile ends
			local dmg = ComponentObjectGetValue2( pc, "config_explosion", "damage" ) or 0
			if dmg > 0 then
				ComponentObjectSetValue2( pc, "config_explosion", "damage", 0 )
				mh_set( e, "blast_damage", dmg )
				mh_set( e, "blast_radius", ComponentObjectGetValue2( pc, "config_explosion", "explosion_radius" ) or 0 )
				mh_set( e, "blast_owner", me )
				EntityAddComponent2( e, "LuaComponent", {
					script_source_file = "mods/mahoraga/files/scripts/summon_blast.lua",
					execute_every_n_frame = -1,
					execute_on_removed = true,
				} )
			end
		end
	end
	return e
end
local function unlocked( a ) return a.unlock == "" or mh_get( me, "adapted_" .. a.unlock, 0 ) == 1 end
-- Your Mahoraga's blasts can't hurt the player (summon_blast.lua), but fire burns anyone:
-- he holds back Giant Napalm while the player is inside its fire circle.
local function safe_for_player( a )
	if not summon then return true end
	local p = MAHORAGA_PROJECTILES[ a.projectile ]
	if not string.find( p.load_entities, "circle_fire", 1, true ) then return true end
	local ppx, ppy = EntityGetTransform( player )
	return ( ppx - px ) ^ 2 + ( ppy - py ) ^ 2 > 160 * 160
end

-- Holy Shower keeps falling for its whole duration, alongside his other attacks.
do
	local until_f = mh_get( me, "rain_until", 0 )
	if now < until_f then
		local a = MAHORAGA_ATTACKS[ MAHORAGA_ATTACKS_ORDER[ mh_get( me, "rain_attack", 1 ) ] ]
		if ( until_f - now ) % a.repeat_gap_frames == 0 then
			local p = MAHORAGA_PROJECTILES[ a.projectile ]
			SetRandomSeed( now, x + me )
			for i = 1, a.count do
				local lx = px + Random( -a.area, a.area )
				-- start just under the ceiling so the lance falls through open air
				local hit, hx, hy = RaytracePlatforms( lx, py, lx, py - 240 )
				local ly = hit and ( hy + 8 ) or ( py - 240 )
				shoot( a.projectile, lx, ly, Random( -10, 10 ), p.speed )
			end
		end
	end
end

-- Current attack state
local cur = mh_get( me, "attack", 0 )          -- index into MAHORAGA_ATTACKS_ORDER, 0 = none
local started = mh_get( me, "attack_start", 0 )

local function start_attack( pick )
	local a = MAHORAGA_ATTACKS[ MAHORAGA_ATTACKS_ORDER[ pick ] ]
	local cd = a.cooldown_frames
	if phase == 2 then cd = cd * B.phase2_cooldown_mult end
	mh_set( me, "ready_" .. a.id, now + cd )
	mh_set( me, "attack", pick )
	mh_set( me, "attack_start", now )
	mh_set( me, "aim_x", px )
	mh_set( me, "aim_y", py )
	set_ai( false )
	face( px )
	GamePlayAnimation( me, "windup", 10 )   -- holds the sword pulled back until the attack goes off
	if a.warning ~= "" and not summon then GamePrint( a.warning ) end
end

if cur == 0 then
	if now < mh_get( me, "next_think", 0 ) then return end
	mh_set( me, "next_think", now + B.attack_think_frames )
	local dist = math.sqrt( ( px - x ) ^ 2 + ( py - y ) ^ 2 )
	if dist > 450 then return end
	local choices = {}
	for i, id in ipairs( MAHORAGA_ATTACKS_ORDER ) do
		local a = MAHORAGA_ATTACKS[ id ]
		if a.phase <= phase and unlocked( a ) and safe_for_player( a ) and dist >= a.range_min and dist <= a.range_max and now >= mh_get( me, "ready_" .. id, 0 ) then
			table.insert( choices, i )
		end
	end
	if #choices == 0 then return end
	SetRandomSeed( now + x, y + me )
	start_attack( choices[ Random( 1, #choices ) ] )
	return
end

local a = MAHORAGA_ATTACKS[ MAHORAGA_ATTACKS_ORDER[ cur ] ]
local t = now - started
local ax, ay = mh_get( me, "aim_x", px ), mh_get( me, "aim_y", py )
local sx, sy = x, y - 26

local function finish()
	mh_set( me, "attack", 0 )
	set_ai( true )
end

if t < a.windup_frames then
	-- telegraph: stand still and glow
	if cdc ~= nil then local vx, vy = ComponentGetValue2( cdc, "mVelocity" ); ComponentSetValue2( cdc, "mVelocity", vx * 0.8, vy ) end
	return
end
local at = t - a.windup_frames

if a.behavior == "fan_at_target" then
	if at == 0 then
		sound( a )
		anim( a.animation )
		local base = math.atan2( ay - sy, ax - sx )
		local spd = MAHORAGA_PROJECTILES[ a.projectile ].speed
		for i = 1, a.count do
			local off = 0
			if a.count > 1 then off = ( ( i - 1 ) / ( a.count - 1 ) - 0.5 ) * math.rad( a.spread_deg ) end
			shoot( a.projectile, sx, sy, math.cos( base + off ) * spd, math.sin( base + off ) * spd )
		end
	end
	if at > 12 then finish() end

elseif a.behavior == "leap_then_blast" then
	if at == 0 and cdc ~= nil then
		local dx = math.max( -220, math.min( 220, ( ax - x ) * 1.6 ) )
		ComponentSetValue2( cdc, "mVelocity", dx, -260 )
		GamePlayAnimation( me, "jump_up", 10 )
	end
	local grounded = cdc ~= nil and ComponentGetValue2( cdc, "is_on_ground" )
	if ( at > 8 and grounded ) or at > 100 then
		sound( a )
		anim( a.animation )
		shoot( "slam_blast", x, y - 2, 0, 0 )
		local spd = MAHORAGA_PROJECTILES[ a.projectile ].speed
		for i = 1, a.count do
			local ang = -math.pi * 0.5 + ( ( i - 1 ) / ( a.count - 1 ) - 0.5 ) * math.rad( a.spread_deg )
			shoot( a.projectile, x, y - 8, math.cos( ang ) * spd, math.sin( ang ) * spd )
		end
		GameScreenshake( 40, x, y )
		finish()
	end

elseif a.behavior == "dash_digging" then
	local dir = mh_get( me, "dash_dir", 0 )
	if at == 0 then
		dir = math.atan2( ay - sy, ax - x )
		mh_set( me, "dash_dir", dir )
		sound( a )
	end
	if at % 16 == 0 then anim( a.animation ) end   -- the 4-frame charge loop lasts ~17 frames
	if cdc ~= nil then ComponentSetValue2( cdc, "mVelocity", math.cos( dir ) * 320, math.sin( dir ) * 320 - 20 ) end
	if at % a.repeat_gap_frames == 0 then
		shoot( a.projectile, x + math.cos( dir ) * 14, y - 16 + math.sin( dir ) * 14, 0, 0 )
	end
	if at >= a.repeats * a.repeat_gap_frames then finish() end

elseif a.behavior == "ring" then
	if at % a.repeat_gap_frames == 0 and at < a.repeats * a.repeat_gap_frames then
		sound( a )
		anim( a.animation )
		local spd = MAHORAGA_PROJECTILES[ a.projectile ].speed
		local rot = ( at / a.repeat_gap_frames ) * math.pi / a.count
		for i = 1, a.count do
			local ang = rot + ( i - 1 ) * math.rad( a.spread_deg ) / a.count
			shoot( a.projectile, x, y - 26, math.cos( ang ) * spd, math.sin( ang ) * spd )
		end
	end
	if at >= a.repeats * a.repeat_gap_frames then finish() end
elseif a.behavior == "lob_at_target" then
	-- thrown in an arc that lands on where the player stood
	if at == 0 then
		sound( a )
		anim( a.animation )
		local p = MAHORAGA_PROJECTILES[ a.projectile ]
		local T = 0.9
		local vx = ( ax - sx ) / T
		local vy = ( ay - sy ) / T - 0.5 * p.gravity_y * T
		shoot( a.projectile, sx, sy, vx, vy )
	end
	if at > 12 then finish() end

elseif a.behavior == "blast_at_self" then
	-- one blast at Mahoraga (or offset_x in front of him); damage types other than
	-- explosion are dealt to everything caught in the blast
	if at == 0 then
		sound( a )
		anim( a.animation )
		local dir = ( ax < x ) and -1 or 1
		local bx, by = x + dir * a.offset_x, y - 20
		shoot( a.projectile, bx, by, 0, 0 )
		local p = MAHORAGA_PROJECTILES[ a.projectile ]
		if p.damage_type ~= "explosion" and p.damage > 0 then
			local dtype = "DAMAGE_" .. string.upper( p.damage_type )
			for _, e in ipairs( EntityGetInRadiusWithTag( bx, by, p.explosion_radius, "mortal" ) or {} ) do
				if e ~= me and not ( summon and mh_is_ally( e, player ) ) then
					EntityInflictDamage( e, p.damage * power, dtype, MAHORAGA_ADAPT[ p.damage_type ].message_key, "NORMAL", dir * 40, -30, me )
					if p.damage_type == "electricity" then LoadGameEffectEntityTo( e, "data/entities/misc/effect_electricity.xml" ) end
				end
			end
		end
		GameScreenshake( math.min( 100, p.explosion_radius ), bx, by )
	end
	if at > 20 then finish() end

elseif a.behavior == "cut_storm" then
	-- World Cutting Slash: waves of huge white cuts crossing the area around the target at random angles
	if at % a.repeat_gap_frames == 0 and at < a.repeats * a.repeat_gap_frames then
		sound( a )
		anim( a.animation )
		local p = MAHORAGA_PROJECTILES[ a.projectile ]
		local reach = p.speed * p.lifetime / 60
		SetRandomSeed( now + me, x - at )
		for i = 1, a.count do
			local cx, cy = ax + Random( -a.area, a.area ), ay + Random( -a.area, a.area ) * 0.6
			local ang = Random( 0, 359 ) * math.pi / 180
			local dx, dy = math.cos( ang ), math.sin( ang )
			shoot( a.projectile, cx - dx * reach * 0.5, cy - dy * reach * 0.5, dx * p.speed, dy * p.speed )
		end
		GameScreenshake( 25, ax, ay )
	end
	if at >= a.repeats * a.repeat_gap_frames then finish() end

elseif a.behavior == "hold_above" then
	-- Omega Black Hole: a giant black hole hangs still above his head for its lifetime
	if at == 0 then
		sound( a )
		anim( a.animation )
		local p = MAHORAGA_PROJECTILES[ a.projectile ]
		local e = shoot( a.projectile, x, y - a.offset_x, 0, 0 )
		if e ~= nil then
			local pc = EntityGetFirstComponentIncludingDisabled( e, "ProjectileComponent" )
			if pc ~= nil then ComponentSetValue2( pc, "lifetime", p.lifetime ) end
			local vc = EntityGetFirstComponentIncludingDisabled( e, "VelocityComponent" )
			if vc ~= nil then
				ComponentSetValue2( vc, "mVelocity", 0, 0 )
				ComponentSetValue2( vc, "gravity_y", 0 )
				ComponentSetValue2( vc, "air_friction", 20 )
			end
			for _, ad in ipairs( EntityGetComponent( e, "AreaDamageComponent" ) or {} ) do
				ComponentSetValue2( ad, "damage_per_frame", p.damage * power )
				if summon then ComponentSetValue2( ad, "entities_with_tag", "enemy" ) end
			end
		end
	end
	if at > 20 then finish() end

elseif a.behavior == "earthquake" then
	-- Earthquake: waves that shake the screen, crack the ground and hit everything standing in the area
	if at % a.repeat_gap_frames == 0 and at < a.repeats * a.repeat_gap_frames then
		sound( a )
		anim( a.animation )
		local p = MAHORAGA_PROJECTILES[ a.projectile ]
		GameScreenshake( 80, x, y )
		if at == 0 then EntityLoad( "data/entities/projectiles/deck/crumbling_earth_effect.xml", x, y - 60 ) end
		SetRandomSeed( now + me, y + at )
		for i = 1, a.count do
			local cx = x + Random( -a.area, a.area )
			local hit, hx, hy = RaytracePlatforms( cx, y - 30, cx, y + 120 )
			if hit then EntityLoad( "mods/mahoraga/files/entities/crack.xml", cx, hy ) end
		end
		for _, e in ipairs( EntityGetInRadiusWithTag( x, y, a.area, "mortal" ) or {} ) do
			if e ~= me and not ( summon and mh_is_ally( e, player ) ) then
				local ex, ey = EntityGetTransform( e )
				if math.abs( ey - y ) < 60 then
					EntityInflictDamage( e, p.damage * power, "DAMAGE_PHYSICS_HIT", MAHORAGA_ADAPT.physics_hit.message_key, "NORMAL", 0, -60, me )
				end
			end
		end
	end
	if at >= a.repeats * a.repeat_gap_frames then finish() end

elseif a.behavior == "rain" then
	if at == 0 then
		sound( a )
		anim( a.animation )
		mh_set( me, "rain_attack", cur )
		mh_set( me, "rain_until", now + a.repeats * a.repeat_gap_frames )
	end
	if at > 10 then finish() end
else
	finish()
end
