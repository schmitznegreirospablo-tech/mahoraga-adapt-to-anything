dofile_once("mods/mahoraga/files/scripts/common.lua")
dofile_once("data/scripts/perks/perk.lua")

function death( damage_type_bit_field, damage_message, entity_thats_responsible, drop_items )
	local me = GetUpdatedEntityID()
	local x, y = EntityGetTransform( me )
	local n = mh_get( me, "world", mh_world_index( x ) )
	GlobalsSetValue( "mahoraga_dead_" .. tostring( n ), "1" )

	local left, top, right, bottom = mh_arena_rect( n )
	local rx, ry = ( left + right ) * 0.5, bottom - 20
	-- escape mode: the chase is over, but the chaser drops no perks; Mahoraga returns to his arena,
	-- where he waits as usual and drops them when beaten there
	if mh_get( me, "chaser", 0 ) == 1 then
		GlobalsSetValue( "mahoraga_escape", "done" )
		GlobalsSetValue( "mahoraga_dead_" .. tostring( n ), "0" )
		local gold = MAHORAGA_BOSS.mahoraga.gold_drop
		for i = 1, math.floor( gold / 200 ) do
			EntityLoad( "data/entities/items/pickup/goldnugget_200.xml", x - 40 + i * 8, y - 20 )
		end
		GamePrintImportant( "The chase is over", "Mahoraga returns to his arena at the eastern edge of the world. Beat him there for his power." )
		GamePlaySound( "data/audio/Desktop/event_cues.bank", "event_cues/heart_fullhp/create", x, y )
		return
	end
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
