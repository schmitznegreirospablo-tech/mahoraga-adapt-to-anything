dofile_once("mods/mahoraga/files/scripts/common.lua")

-- Called from the perk's func (perk_append.lua, generated from sheets/perks.json).
function mahoraga_give_player_adaptation( player, message )
	EntityAddComponent2( player, "LuaComponent", {
		_tags = "mahoraga_adaptation,perk_component",
		script_damage_received = "mods/mahoraga/files/scripts/player_damage.lua",
		execute_every_n_frame = -1,
	} )
	-- a tiny wheel floats above the player's head
	local wheel = EntityCreateNew( "mahoraga_player_wheel" )
	EntityAddTag( wheel, "perk_entity" )
	EntityAddComponent2( wheel, "InheritTransformComponent", { only_position = true } )
	EntityAddComponent2( wheel, "SpriteComponent", {
		_tags = "mahoraga_player_wheel",
		image_file = "mods/mahoraga/files/gfx/wheel.png",
		offset_x = 12, offset_y = 72, emissive = true, alpha = 0.7,
		has_special_scale = true, special_scale_x = 0.3, special_scale_y = 0.3,
	} )
	EntityAddComponent2( wheel, "LuaComponent", {
		script_source_file = "mods/mahoraga/files/scripts/player_wheel.lua",
		execute_every_n_frame = 2,
	} )
	EntityAddChild( player, wheel )
	GamePrint( message )
end

function mahoraga_remove_player_adaptation( player )
	local comps = EntityGetComponentIncludingDisabled( player, "LuaComponent", "mahoraga_adaptation" ) or {}
	for _, c in ipairs( comps ) do EntityRemoveComponent( player, c ) end
	for _, child in ipairs( EntityGetAllChildren( player ) or {} ) do
		if EntityGetName( child ) == "mahoraga_player_wheel" then EntityKill( child ) end
	end
end

-- Summon Mahoraga: the player can call and dismiss their own Mahoraga with the key from Mod settings (init.lua).
function mahoraga_give_summon( player, message )
	mh_set( player, "mahoraga_summoner", 1 )
	GamePrint( message )
	local key = mahoraga_summon_key_name ~= nil and mahoraga_summon_key_name() or "your summon key"
	GamePrint( "Press " .. key .. " to call or dismiss Mahoraga (change it in Options > Mod settings)." )
end

function mahoraga_remove_summon( player )
	mh_set( player, "mahoraga_summoner", 0 )
	for _, e in ipairs( EntityGetWithTag( "mahoraga_summon" ) or {} ) do EntityKill( e ) end
end