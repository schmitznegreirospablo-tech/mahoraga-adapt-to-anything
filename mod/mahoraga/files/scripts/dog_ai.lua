dofile_once("mods/mahoraga/files/scripts/common.lua")

-- A Divine Dog: the game's animal AI chases enemies; this script does the bite (forward, short range),
-- credits kills to the dogs' growth, and keeps the dog with the player when there is nothing to hunt.
local me = GetUpdatedEntityID()
local now = GameGetFrameNum()
local player = mh_player()
if player == nil or mh_get( me, "dismissed", 0 ) == 1 then return end
local x, y = EntityGetTransform( me )

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

-- the bite: the closest enemy in front, within reach
if now % 3 == 0 and now >= mh_get( me, "next_bite", 0 ) then
	local _, _, _, sx = EntityGetTransform( me )
	local facing = ( sx ~= nil and sx < 0 ) and -1 or 1
	local best, best_d = nil, 1e9
	for _, e in ipairs( EntityGetInRadiusWithTag( x, y - 6, D.bite_range + 12, "enemy" ) or {} ) do
		if EntityGetIsAlive( e ) then
			local ex, ey = EntityGetTransform( e )
			local dx = ex - x
			if ( dx * facing > -4 or math.abs( dx ) < 6 ) and math.abs( ey - y ) < 20 + D.hitbox_h then
				if math.abs( dx ) < best_d then best, best_d = e, math.abs( dx ) end
			end
		end
	end
	if best ~= nil then
		local mult = mh_get( me, "bite_mult", 1 )
		EntityInflictDamage( best, D.bite_damage * mult, "DAMAGE_MELEE", "$damage_melee", "NORMAL", facing * 30, -10, me )
		GamePlayAnimation( me, "attack", 5, "stand", 0 )
		mh_set( me, "next_bite", now + D.bite_cooldown_frames )
		local slot = ( mh_get( me, "bit_slot", 0 ) % 3 ) + 1
		mh_set( me, "bit_slot", slot )
		mh_set( me, "bit_" .. slot, best )
		mh_set( me, "bit_at_" .. slot, now )
		mh_set( me, "bit_boss_" .. slot, ( EntityHasTag( best, "boss" ) or EntityHasTag( best, "miniboss" ) ) and 1 or 0 )
	end
end

-- stay with the player: when nothing is near to hunt and the player is far, run back (or appear beside them)
if now % 20 == 0 then
	local px, py = EntityGetTransform( player )
	local d2 = ( px - x ) ^ 2 + ( py - y ) ^ 2
	local hunting = #( EntityGetInRadiusWithTag( x, y, 220, "enemy" ) or {} ) > 0
	if d2 > 600 * 600 or ( not hunting and d2 > 260 * 260 ) then
		EntityLoad( "data/entities/particles/poof_white_appear.xml", x, y - 10 )
		EntitySetTransform( me, px + ( ( px < x ) and 24 or -24 ), py )
		EntityLoad( "data/entities/particles/poof_white_appear.xml", px, py - 10 )
	end
end
