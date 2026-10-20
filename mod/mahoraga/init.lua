dofile_once("mods/mahoraga/files/scripts/common.lua")

ModLuaFileAppend( "data/scripts/perks/perk_list.lua", "mods/mahoraga/files/scripts/perk_append.lua" )

do
	local csv = ModTextFileGetContent( "data/translations/common.csv" )
	local add = ModTextFileGetContent( "mods/mahoraga/files/translations.csv" )
	if csv ~= nil and add ~= nil then
		if csv:sub( -1 ) ~= "\n" then csv = csv .. "\n" end
		ModTextFileSetContent( "data/translations/common.csv", csv .. add )
	end
end

local function arena_key( n ) return "mahoraga_arena_" .. tostring( n ) end
local function dead_key( n ) return "mahoraga_dead_" .. tostring( n ) end

function mahoraga_stamp_arena( n )
	if GlobalsGetValue( arena_key( n ), "0" ) == "1" then return end
	local left, top = mh_arena_rect( n )
	LoadPixelScene( MAHORAGA_WORLD.arena_scene, "", left, top, MAHORAGA_WORLD.arena_background, true, false, {}, 50, true )
	GlobalsSetValue( arena_key( n ), "1" )
	print( "[mahoraga] arena stamped in world " .. n .. " at " .. left .. "," .. top )
end

local function boss_present( cx, cy )
	local found = EntityGetInRadiusWithTag( cx, cy, 600, "mahoraga" )
	return found ~= nil and #found > 0
end

function mahoraga_spawn_boss( n )
	local left, top, right, bottom = mh_arena_rect( n )
	local x, y = right - 70, bottom - 14
	local boss = EntityLoad( "mods/mahoraga/files/entities/mahoraga.xml", x, y )
	mh_set( boss, "world", n )
	-- stronger in every parallel world further from the main one
	local extra = math.abs( n ) * MAHORAGA_BOSS.mahoraga.hp_per_extra_world
	if extra > 0 then
		local dmc = EntityGetFirstComponent( boss, "DamageModelComponent" )
		local hp = MAHORAGA_BOSS.mahoraga.hp * ( 1 + extra )
		ComponentSetValue2( dmc, "max_hp", hp )
		ComponentSetValue2( dmc, "hp", hp )
	end
	GamePrintImportant( "$animal_mahoraga", MAHORAGA_BOSS.mahoraga.intro_message )
	GamePlaySound( "data/audio/Desktop/event_cues.bank", "event_cues/orb_distant_monster/create", x, y )
	return boss
end

function OnWorldPostUpdate()
	local frame = GameGetFrameNum()
	if frame % 15 ~= 0 then return end
	local player = mh_player()
	if player == nil then return end
	local px, py = EntityGetTransform( player )
	local n = mh_world_index( px )
	local left, top, right, bottom = mh_arena_rect( n )
	local cx, cy = ( left + right ) * 0.5, ( top + bottom ) * 0.5
	local dx, dy = px - cx, py - cy
	if dx * dx + dy * dy < MAHORAGA_WORLD.arena_load_range ^ 2 then
		mahoraga_stamp_arena( n )
	end
	local inset = MAHORAGA_WORLD.boss_trigger_inset
	if px > left + inset and px < right and py > top and py < bottom then
		if GlobalsGetValue( dead_key( n ), "0" ) ~= "1" and not boss_present( cx, cy ) then
			mahoraga_spawn_boss( n )
		end
	end
end
