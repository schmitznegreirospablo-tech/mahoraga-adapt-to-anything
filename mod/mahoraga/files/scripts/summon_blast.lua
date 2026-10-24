dofile_once("mods/mahoraga/files/scripts/common.lua")

-- Runs when one of your Mahoraga's projectiles ends. Its explosion was set to deal no damage (so it can never
-- hurt the player); this deals that damage here instead, to everything in the blast except him and his allies.
local me = GetUpdatedEntityID()
local x, y = EntityGetTransform( me )
local damage = mh_get( me, "blast_damage", 0 )
local radius = mh_get( me, "blast_radius", 0 )
if damage <= 0 or radius <= 0 then return end
local owner = mh_get( me, "blast_owner", 0 )
local player = mh_player()
for _, e in ipairs( EntityGetInRadiusWithTag( x, y, radius, "mortal" ) or {} ) do
	if e ~= owner and not mh_is_ally( e, player ) then
		EntityInflictDamage( e, damage, "DAMAGE_EXPLOSION", "$damage_explosion", "NORMAL", 0, 0, owner )
	end
end
