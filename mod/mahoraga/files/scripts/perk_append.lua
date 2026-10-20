-- GENERATED from sheets/*.json by tools/gen.ps1. Edit the sheets, not this file.
dofile_once("mods/mahoraga/files/scripts/perk_adaptation.lua")
table.insert( perk_list, {
	id = "MAHORAGA_ADAPTATION",
	ui_name = "$perk_mahoraga_adaptation",
	ui_description = "$perkdesc_mahoraga_adaptation",
	ui_icon = "mods/mahoraga/files/gfx/perk_ui.png",
	perk_icon = "mods/mahoraga/files/gfx/perk_item.png",
	stackable = false,
	not_in_default_perk_pool = true,
	usable_by_enemies = false,
	func = function( entity_perk_item, entity_who_picked, item_name )
		mahoraga_give_player_adaptation( entity_who_picked, "The Wheel of Mahoraga now turns above you." )
	end,
	func_remove = function( entity_who_picked )
		mahoraga_remove_player_adaptation( entity_who_picked )
	end,
} )