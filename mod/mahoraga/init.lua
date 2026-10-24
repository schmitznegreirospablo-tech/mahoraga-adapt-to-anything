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

-- Escape mode (Mod settings, new games): Mahoraga leaves his arena at the start and digs his way to the player,
-- who starts with only the Divine Dogs perk. His chase is a point moving toward the player (globals) until it
-- gets close; then the real Mahoraga breaks out of the ground near them (boss_ai.lua takes over).
function OnPlayerSpawned( player )
	if ModSettingGet( "mahoraga.escape_mode" ) ~= true then return end
	if GlobalsGetValue( "mahoraga_escape", "" ) ~= "" then return end
	GlobalsSetValue( "mahoraga_escape", "chasing" )
	GlobalsSetValue( "mahoraga_dead_0", "1" )   -- his arena in this world stays empty: he is the one chasing
	local px, py = EntityGetTransform( player )
	dofile_once( "data/scripts/perks/perk.lua" )
	local perk = perk_spawn( px, py - 10, "MAHORAGA_DIVINE_DOGS", true )
	if perk ~= nil then perk_pickup( perk, player, "", false, false ) end
	local left, top, right, bottom = mh_arena_rect( 0 )
	local cx, cy = ( left + right ) * 0.5, bottom - 20
	GlobalsSetValue( "mahoraga_chase_x", tostring( cx ) )
	GlobalsSetValue( "mahoraga_chase_y", tostring( cy ) )
	local d = math.sqrt( ( cx - px ) ^ 2 + ( cy - py ) ^ 2 )
	GlobalsSetValue( "mahoraga_chase_speed", tostring( d / ( MAHORAGA_WORLD.escape_chase_seconds * 60 ) ) )
	GamePrintImportant( "Mahoraga has left his arena", "He is digging his way to you. Run!" )
end

-- every 15 frames: move the chase toward the player, and bring Mahoraga out once it is close
local function mahoraga_escape_update( player )
	local state = GlobalsGetValue( "mahoraga_escape", "" )
	local px, py = EntityGetTransform( player )
	if state == "chasing" then
		local cx, cy = tonumber( GlobalsGetValue( "mahoraga_chase_x", "0" ) ), tonumber( GlobalsGetValue( "mahoraga_chase_y", "0" ) )
		local step = tonumber( GlobalsGetValue( "mahoraga_chase_speed", "1" ) ) * 15
		local dx, dy = px - cx, py - cy
		local d = math.sqrt( dx * dx + dy * dy ) + 0.01
		local near = MAHORAGA_WORLD.escape_spawn_distance
		if d - step <= near then
			local sx, sy = px - dx / d * near, py - dy / d * near
			local boss = EntityLoad( "mods/mahoraga/files/entities/mahoraga.xml", sx, sy )
			mh_set( boss, "chaser", 1 )
			mh_set( boss, "world", 0 )
			EntityAddComponent2( boss, "CellEaterComponent", { _tags = "mahoraga_dig", radius = 22, eat_dynamic_physics_bodies = true, ignored_material_tag = "[indestructible]" } )
			GlobalsSetValue( "mahoraga_escape", "hunting" )
			GlobalsSetValue( "mahoraga_escape_missing", "0" )
			GamePrintImportant( "$animal_mahoraga", "He has found you." )
			GamePlaySound( "data/audio/Desktop/event_cues.bank", "event_cues/orb_distant_monster/create", sx, sy )
		else
			GlobalsSetValue( "mahoraga_chase_x", tostring( cx + dx / d * step ) )
			GlobalsSetValue( "mahoraga_chase_y", tostring( cy + dy / d * step ) )
			if GameGetFrameNum() % 1800 < 15 then
				GamePrint( string.format( "Mahoraga is %d m away and closing in...", math.floor( d / 10 ) ) )
			end
		end
	elseif state == "hunting" then
		for _, e in ipairs( EntityGetWithTag( "mahoraga" ) or {} ) do
			if mh_get( e, "chaser", 0 ) == 1 then GlobalsSetValue( "mahoraga_escape_missing", "0" ) return end
		end
		-- he is gone without dying (left behind in an unloaded part of the world): the chase resumes nearby
		local missing = tonumber( GlobalsGetValue( "mahoraga_escape_missing", "0" ) ) + 1
		GlobalsSetValue( "mahoraga_escape_missing", tostring( missing ) )
		if missing >= 20 then
			GlobalsSetValue( "mahoraga_chase_x", tostring( px + 1500 ) )
			GlobalsSetValue( "mahoraga_chase_y", tostring( py ) )
			GlobalsSetValue( "mahoraga_escape", "chasing" )
			GamePrint( "Mahoraga lost sight of you... but he is still coming." )
		end
	end
end

-- Divine Dogs perk: the dog key calls the dogs of the current phase, or sends them back.
function mahoraga_toggle_dogs( player )
	if #mh_dogs() > 0 then
		mahoraga_dismiss_dogs()
		GamePrint( "The Divine Dogs return to your shadow." )
		return
	end
	local wait = mh_get( player, "dog_ready_at", 0 ) - GameGetFrameNum()
	if wait > 0 then
		GamePrint( "The Divine Dogs are still recovering (" .. math.ceil( wait / 60 ) .. " s)." )
		return
	end
	mahoraga_spawn_dogs( player )
	local phase = mh_get( player, "dog_phase", 1 )
	local names = { "the white Divine Dog", "both Divine Dogs", "Divine Dog: Totality" }
	local left = MAHORAGA_WORLD.dog_kills_per_phase - mh_get( player, "dog_kills", 0 )
	GamePrint( "You call " .. names[ math.min( phase, 3 ) ] .. "." .. ( phase < 3 and ( " (" .. left .. " kills or a boss to grow)" ) or "" ) )
end

-- Summon Mahoraga perk: the summon key calls your own Mahoraga next to you, or sends him away.
function mahoraga_toggle_summon( player )
	local px, py = EntityGetTransform( player )
	local existing = EntityGetWithTag( "mahoraga_summon" ) or {}
	if #existing > 0 then
		for _, e in ipairs( existing ) do
			local ex, ey = EntityGetTransform( e )
			EntityLoad( "data/entities/particles/poof_white_appear.xml", ex, ey - 20 )
			EntityKill( e )
		end
		GamePrint( "Mahoraga returns to the shadows." )
		return
	end
	local _, _, _, sx = EntityGetTransform( player )
	local x = px + ( ( sx ~= nil and sx < 0 ) and -30 or 30 )
	local e = EntityLoad( "mods/mahoraga/files/entities/mahoraga_summon.xml", x, py )
	-- as many adaptations (and the upgrades and techniques they bring) as the player has
	local n = mh_summon_sync( e, player, "quiet" )
	EntityLoad( "data/entities/particles/poof_white_appear.xml", x, py - 20 )
	GamePlaySound( "data/audio/Desktop/event_cues.bank", "event_cues/orb_distant_monster/create", x, py )
	local learned = {}
	for _, id in ipairs( MAHORAGA_ATTACKS_ORDER ) do
		local a = MAHORAGA_ATTACKS[ id ]
		if a.unlock ~= "" and mh_get( e, "adapted_" .. a.unlock, 0 ) == 1 then table.insert( learned, a.name ) end
	end
	GamePrintImportant( "With this treasure, I summon...", "Mahoraga fights for you (" .. n .. " adaptations" .. ( #learned > 0 and ( ": " .. table.concat( learned, ", " ) ) or "" ) .. ")." )
end

function OnWorldPostUpdate()
	local frame = GameGetFrameNum()
	local player = mh_player()
	if player ~= nil and mh_get( player, "mahoraga_summoner", 0 ) == 1
		and InputIsKeyJustDown( mahoraga_summon_key() ) and not GameIsInventoryOpen() then
		mahoraga_toggle_summon( player )
	end
	if player ~= nil and mh_get( player, "dog_summoner", 0 ) == 1
		and InputIsKeyJustDown( mahoraga_dog_key() ) and not GameIsInventoryOpen() then
		mahoraga_toggle_dogs( player )
	end
	if frame % 15 ~= 0 then return end
	if player == nil then return end
	if GlobalsGetValue( "mahoraga_escape", "" ) ~= "" then mahoraga_escape_update( player ) end
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
