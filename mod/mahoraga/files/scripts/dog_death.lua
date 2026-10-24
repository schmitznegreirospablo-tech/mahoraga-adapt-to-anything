dofile_once("mods/mahoraga/files/scripts/common.lua")

-- When the last Divine Dog falls, they need a while (world.dog_respawn_frames) before they can be called again.
-- Their phase is kept.
function death( damage_type_bit_field, damage_message, entity_thats_responsible, drop_items )
	local me = GetUpdatedEntityID()
	if mh_get( me, "dismissed", 0 ) == 1 then return end
	local player = mh_player()
	if player == nil then return end
	for _, e in ipairs( mh_dogs() ) do
		if e ~= me then return end
	end
	local frames = MAHORAGA_WORLD.dog_respawn_frames
	mh_set( player, "dog_ready_at", GameGetFrameNum() + frames )
	GamePrint( "The Divine Dogs have fallen. You can call them again in " .. math.floor( frames / 60 ) .. " seconds." )
end
