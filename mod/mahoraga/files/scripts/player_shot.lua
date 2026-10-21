dofile_once("mods/mahoraga/files/scripts/common.lua")

-- Adapt to Anything: every projectile the player shoots carries their adaptation power
-- (x player_adapt_power_mult per kind of harm adapted to, compounding; see player_damage.lua).
function shot( projectile_id )
	local player = GetUpdatedEntityID()
	local power = mh_get( player, "padapt_power", 1 )
	if power ~= 1 then mh_scale_projectile( projectile_id, power ) end
end
