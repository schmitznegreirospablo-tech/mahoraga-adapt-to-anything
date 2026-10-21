dofile_once("mods/mahoraga/files/scripts/common.lua")
dofile_once("data/scripts/perks/perk.lua")

function death( damage_type_bit_field, damage_message, entity_thats_responsible, drop_items )
	local me = GetUpdatedEntityID()
	local x, y = EntityGetTransform( me )
	local n = mh_get( me, "world", mh_world_index( x ) )
	GlobalsSetValue( "mahoraga_dead_" .. tostring( n ), "1" )

	local left, top, right, bottom = mh_arena_rect( n )
	local rx, ry = ( left + right ) * 0.5, bottom - 20
	-- every reward perk side by side; taking one leaves the others (reward_perk is a comma list)
	local perks = {}
	for id in string.gmatch( MAHORAGA_BOSS.mahoraga.reward_perk, "[^,]+" ) do table.insert( perks, id ) end
	for i, id in ipairs( perks ) do
		perk_spawn( rx + ( i - ( #perks + 1 ) * 0.5 ) * 30, ry, id, true )
	end

	local gold = MAHORAGA_BOSS.mahoraga.gold_drop
	for i = 1, math.floor( gold / 200 ) do
		EntityLoad( "data/entities/items/pickup/goldnugget_200.xml", rx - 40 + i * 8, ry - 10 )
	end
	GamePrintImportant( "Mahoraga has fallen", "The wheel stops. Its power is yours to take." )
	GamePlaySound( "data/audio/Desktop/event_cues.bank", "event_cues/heart_fullhp/create", rx, ry )
end
