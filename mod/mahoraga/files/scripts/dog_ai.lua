dofile_once("mods/mahoraga/files/scripts/common.lua")

-- A Divine Dog: the game's animal AI chases enemies; this script does the bite (forward, short range) and the
-- dash claw (any direction, longer range),
-- credits kills to the dogs' growth, and keeps the dog with the player when there is nothing to hunt.
local me = GetUpdatedEntityID()
local now = GameGetFrameNum()
local player = mh_player()
if player == nil or mh_get( me, "dismissed", 0 ) == 1 then return end
local x, y = EntityGetTransform( me )
if EntityHasTag( me, "enemy" ) then mh_make_ally( me ) end

local kind = "white"
for _, c in ipairs( EntityGetComponentIncludingDisabled( me, "VariableStorageComponent" ) or {} ) do
	if ComponentGetValue2( c, "name" ) == "dog_kind" then kind = ComponentGetValue2( c, "value_string" ) end
end
local D = MAHORAGA_DOGS[ kind ]
if D == nil then return end

-- kill credit: an enemy this dog bit in the last 1.5 s has died
for s = 1, 3 do
	local id = mh_get( me, "bit_" .. s, 0 )
	if id ~= 0 then
		local at = mh_get( me, "bit_at_" .. s, 0 )
		if not EntityGetIsAlive( id ) then
			mh_set( me, "bit_" .. s, 0 )
			if now - at <= 90 then
				mahoraga_dog_kill( player, mh_get( me, "bit_boss_" .. s, 0 ) == 1 )
				if mh_get( me, "dismissed", 0 ) == 1 then return end   -- grew into the next phase
			end
		elseif now - at > 90 then
			mh_set( me, "bit_" .. s, 0 )
		end
	end
end

-- every hit is remembered for kill credit (3 slots)
local mult = mh_get( me, "bite_mult", 1 )
local function strike( e, dmg, ix, iy )
	EntityInflictDamage( e, dmg, "DAMAGE_MELEE", "$damage_melee", "NORMAL", ix, iy, me )
	local slot = ( mh_get( me, "bit_slot", 0 ) % 3 ) + 1
	mh_set( me, "bit_slot", slot )
	mh_set( me, "bit_" .. slot, e )
	mh_set( me, "bit_at_" .. slot, now )
	mh_set( me, "bit_boss_" .. slot, ( EntityHasTag( e, "boss" ) or EntityHasTag( e, "miniboss" ) ) and 1 or 0 )
end

-- the dash claw: the dog leaps at an enemy farther away, in any direction, and claws it
-- (Totality: a bigger swipe, twice). While dashing nothing else runs.
local dash_until = mh_get( me, "dash_until", 0 )
if now < dash_until then
	local tid = mh_get( me, "dash_target", 0 )
	if tid == 0 or not EntityGetIsAlive( tid ) then
		mh_set( me, "dash_until", 0 )
		return
	end
	local tx, ty = EntityGetTransform( tid )
	ty = ty - 6
	local dx, dy = tx - x, ty - ( y - 6 )
	local d = math.sqrt( dx * dx + dy * dy ) + 0.01
	local cdc = EntityGetFirstComponent( me, "CharacterDataComponent" )
	if cdc ~= nil and d > D.bite_range then ComponentSetValue2( cdc, "mVelocity", dx / d * D.dash_speed, dy / d * D.dash_speed ) end
	local done = mh_get( me, "claw_done", 0 )
	if d <= D.bite_range + 10 and done < D.claw_hits and now >= mh_get( me, "next_claw", 0 ) then
		strike( tid, D.claw_damage * mult, dx / d * 40, dy / d * 40 )
		local cx, cy = x + dx / d * 8, y - 6 + dy / d * 8
		local fx = EntityLoad( "mods/mahoraga/files/entities/claw.xml", cx, cy )
		EntitySetTransform( fx, cx, cy, math.atan2( dy, dx ), D.claw_scale, D.claw_scale )
		GamePlayAnimation( me, "attack", 5, "stand", 0 )
		mh_set( me, "claw_done", done + 1 )
		mh_set( me, "next_claw", now + 8 )
		if done + 1 >= D.claw_hits then mh_set( me, "dash_until", now + 6 ) end
	end
	return
elseif now >= mh_get( me, "next_dash", 0 ) and now % 5 == 0 then
	local best, best_d = nil, 1e9
	for _, e in ipairs( EntityGetInRadiusWithTag( x, y - 6, D.dash_range, "enemy" ) or {} ) do
		if e ~= me and EntityGetIsAlive( e ) and not mh_is_ally( e, player ) then
			local ex, ey = EntityGetTransform( e )
			local d = math.sqrt( ( ex - x ) ^ 2 + ( ey - y ) ^ 2 )
			-- farther than a bite, nearer than a dash, and nothing solid in the way
			if d > D.bite_range + 10 and d < best_d and not RaytracePlatforms( x, y - 6, ex, ey - 6 ) then best, best_d = e, d end
		end
	end
	if best ~= nil then
		mh_set( me, "dash_target", best )
		mh_set( me, "dash_until", now + 40 )
		mh_set( me, "claw_done", 0 )
		mh_set( me, "next_dash", now + D.dash_cooldown_frames )
		GamePlayAnimation( me, "jump_up", 5, "stand", 0 )
		return
	end
end

-- the bite: the closest enemy in front, within reach
if now % 3 == 0 and now >= mh_get( me, "next_bite", 0 ) then
	local _, _, _, sx = EntityGetTransform( me )
	local facing = ( sx ~= nil and sx < 0 ) and -1 or 1
	local best, best_d = nil, 1e9
	for _, e in ipairs( EntityGetInRadiusWithTag( x, y - 6, D.bite_range + 12, "enemy" ) or {} ) do
		if e ~= me and EntityGetIsAlive( e ) and not mh_is_ally( e, player ) then
			local ex, ey = EntityGetTransform( e )
			local dx = ex - x
			if ( dx * facing > -4 or math.abs( dx ) < 6 ) and math.abs( ey - y ) < 20 + D.hitbox_h then
				if math.abs( dx ) < best_d then best, best_d = e, math.abs( dx ) end
			end
		end
	end
	if best ~= nil then
		strike( best, D.bite_damage * mult, facing * 30, -10 )
		GamePlayAnimation( me, "attack", 5, "stand", 0 )
		mh_set( me, "next_bite", now + D.bite_cooldown_frames )
	end
end

-- stay with the player: when nothing is near to hunt and the player is far, run back (or appear beside them)
if now % 20 == 0 then
	local px, py = EntityGetTransform( player )
	local d2 = ( px - x ) ^ 2 + ( py - y ) ^ 2
	local hunting = false
	for _, e in ipairs( EntityGetInRadiusWithTag( x, y, 220, "enemy" ) or {} ) do
		if e ~= me and not mh_is_ally( e, player ) then hunting = true break end
	end
	if d2 > 600 * 600 or ( not hunting and d2 > 260 * 260 ) then
		EntityLoad( "data/entities/particles/poof_white_appear.xml", x, y - 10 )
		EntitySetTransform( me, px + ( ( px < x ) and 24 or -24 ), py )
		EntityLoad( "data/entities/particles/poof_white_appear.xml", px, py - 10 )
	end
end
