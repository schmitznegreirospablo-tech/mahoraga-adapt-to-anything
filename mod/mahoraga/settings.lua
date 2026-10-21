dofile("data/scripts/lib/mod_settings.lua")

-- Mod settings (Options > Mod settings). Settings can't load this mod's other files, so the key list lives here too
-- (same codes as data/scripts/debug/keycodes.lua and MAHORAGA_KEY_NAMES in files/scripts/common.lua).

local mod_id = "mahoraga"
local KEYS = {
	{4,"A"},{5,"B"},{6,"C"},{7,"D"},{8,"E"},{9,"F"},{10,"G"},{11,"H"},{12,"I"},{13,"J"},{14,"K"},{15,"L"},{16,"M"},
	{17,"N"},{18,"O"},{19,"P"},{20,"Q"},{21,"R"},{22,"S"},{23,"T"},{24,"U"},{25,"V"},{26,"W"},{27,"X"},{28,"Y"},{29,"Z"},
	{30,"1"},{31,"2"},{32,"3"},{33,"4"},{34,"5"},{35,"6"},{36,"7"},{37,"8"},{38,"9"},{39,"0"},
	{58,"F1"},{59,"F2"},{60,"F3"},{61,"F4"},{62,"F5"},{63,"F6"},{64,"F7"},{65,"F8"},{66,"F9"},{67,"F10"},{68,"F11"},{69,"F12"},
}
local KEY_ESCAPE = 41

local function key_name( code )
	for _, k in ipairs( KEYS ) do if k[1] == code then return k[2] end end
	return "key " .. tostring( code )
end

-- A keybind widget: click it, then press the key you want (Esc cancels).
local listening = false
function mahoraga_setting_key( mod_id, gui, in_main_menu, im_id, setting )
	local id = mod_setting_get_id( mod_id, setting )
	local value = math.floor( tonumber( ModSettingGetNextValue( id ) ) or setting.value_default )
	if listening then
		GuiText( gui, mod_setting_group_x_offset, 0, setting.ui_name .. ": press a key... (Esc to cancel)" )
		if InputIsKeyJustDown( KEY_ESCAPE ) then
			listening = false
		else
			for _, k in ipairs( KEYS ) do
				if InputIsKeyJustDown( k[1] ) then
					ModSettingSetNextValue( id, k[1], false )
					listening = false
					break
				end
			end
		end
	elseif GuiButton( gui, im_id, mod_setting_group_x_offset, 0, setting.ui_name .. ": [" .. key_name( value ) .. "]  (click to change)" ) then
		listening = true
	end
	mod_setting_tooltip( mod_id, gui, in_main_menu, setting )
end

mod_settings_version = 1
mod_settings =
{
	{
		id = "summon_key",
		ui_name = "Summon Mahoraga key",
		ui_description = "With the Summon Mahoraga perk, press this key to call your Mahoraga, and again to dismiss him.",
		value_default = 10,
		scope = MOD_SETTING_SCOPE_RUNTIME,
		ui_fn = mahoraga_setting_key,
	},
}

function ModSettingsUpdate( init_scope )
	local old_version = mod_settings_get_version( mod_id )
	mod_settings_update( mod_id, mod_settings, init_scope )
end

function ModSettingsGuiCount()
	return mod_settings_gui_count( mod_id, mod_settings )
end

function ModSettingsGui( gui, in_main_menu )
	mod_settings_gui( mod_id, mod_settings, gui, in_main_menu )
end
