dofile_once("mods/mahoraga/files/scripts/common.lua")

-- Adapt to Anything: each kind of harm the player keeps suffering hurts less, in steps,
-- and every new kind adapted to makes the player stronger.

-- +50% max HP (healing the added part) and +50% damage on every shot, compounding (x1.5, x2.25, x3.375...).
function mahoraga_player_power_up( me )
	local mult = MAHORAGA_BOSS.mahoraga.player_adapt_power_mult
	local power = mh_get( me, "padapt_power", 1 ) * mult
	mh_set( me, "padapt_power", power )
	local dmc = EntityGetFirstComponent( me, "DamageModelComponent" )
	if dmc ~= nil then
		local max_hp, hp = ComponentGetValue2( dmc, "max_hp" ), ComponentGetValue2( dmc, "hp" )
		ComponentSetValue2( dmc, "max_hp", max_hp * mult )
		ComponentSetValue2( dmc, "hp", hp + max_hp * ( mult - 1 ) )
	end
	-- player_shot.lua scales every projectile the player fires (removed with the perk)
	if EntityGetFirstComponentIncludingDisabled( me, "LuaComponent", "mahoraga_power" ) == nil then
		EntityAddComponent2( me, "LuaComponent", {
			_tags = "mahoraga_adaptation,mahoraga_power,perk_component",
			script_shot = "mods/mahoraga/files/scripts/player_shot.lua",
			execute_every_n_frame = -1,
		} )
	end
	GamePrint( string.format( "Your power grows: x%.2f health and damage.", power ) )
end

function damage_received( damage, message, entity_thats_responsible, is_fatal, projectile_thats_responsible )
	if damage <= 0 then return end
	local me = GetUpdatedEntityID()
	local t = mh_damage_type( message, projectile_thats_responsible, me )
	if t == nil then return end
	local row = MAHORAGA_ADAPT[ t ]
	local steps = mh_get( me, "padapt_steps_" .. t, 0 )
	if steps >= row.player_max_steps then return end
	-- rapid ticks (burning, drowning) count as one hit per player_hit_cooldown_frames
	local now = GameGetFrameNum()
	if row.player_hit_cooldown_frames > 0 then
		if now - mh_get( me, "padapt_last_" .. t, -100000 ) < row.player_hit_cooldown_frames then return end
		mh_set( me, "padapt_last_" .. t, now )
	end
	local hits = mh_get( me, "padapt_hits_" .. t, 0 ) + 1
	if hits < row.player_hits_per_step then
		mh_set( me, "padapt_hits_" .. t, hits )
		return
	end
	mh_set( me, "padapt_hits_" .. t, 0 )
	mh_set( me, "padapt_steps_" .. t, steps + 1 )
	if steps == 0 then mahoraga_player_power_up( me ) end
	-- the last step (player_max_steps) adapts the player completely: immune, like Mahoraga
	local full = ( steps + 1 ) >= row.player_max_steps
	local dmc = EntityGetFirstComponent( me, "DamageModelComponent" )
	if dmc ~= nil then
		if full and t == "drowning" then
			ComponentSetValue2( dmc, "air_needed", false )
		elseif full and t == "material" then
			ComponentSetValue2( dmc, "materials_damage", false )
		elseif t == "material" then
			-- every harmful material hurts less (materials_how_much_damage is a comma list)
			local amounts = {}
			for v in string.gmatch( ComponentGetValue2( dmc, "materials_how_much_damage" ) or "", "[^,]+" ) do
				table.insert( amounts, tostring( ( tonumber( v ) or 0 ) * row.player_step_mult ) )
			end
			ComponentSetValue2( dmc, "materials_how_much_damage", table.concat( amounts, "," ) )
		elseif full then
			ComponentObjectSetValue2( dmc, "damage_multipliers", row.field, 0 )
		elseif t == "drowning" then
			-- less harm when out of air, and the lungs hold more of it
			ComponentSetValue2( dmc, "air_lack_of_damage", ComponentGetValue2( dmc, "air_lack_of_damage" ) * row.player_step_mult )
			local lungs = ComponentGetValue2( dmc, "air_in_lungs_max" ) / row.player_step_mult
			ComponentSetValue2( dmc, "air_in_lungs_max", lungs )
			ComponentSetValue2( dmc, "air_in_lungs", lungs )
		else
			local cur = ComponentObjectGetValue2( dmc, "damage_multipliers", row.field ) or 1
			ComponentObjectSetValue2( dmc, "damage_multipliers", row.field, cur * row.player_step_mult )
		end
	end
	-- spin the player's wheel (player_wheel.lua reads this)
	for _, child in ipairs( EntityGetAllChildren( me ) or {} ) do
		if EntityGetName( child ) == "mahoraga_player_wheel" then mh_set( child, "wheel_spin", now ) end
	end
	local x, y = EntityGetTransform( me )
	GamePlaySound( "data/audio/Desktop/animals.bank", "animals/statue/appear", x, y )
	if full then
		GamePrintImportant( "The wheel turns", "You have fully adapted to " .. row.display_name .. ": it can no longer harm you." )
	else
		local pct = math.floor( 100 * ( 1 - row.player_step_mult ^ ( steps + 1 ) ) + 0.5 )
		GamePrint( "The wheel turns: you have adapted to " .. row.display_name .. " (" .. pct .. "% less harm)" )
	end
end
