dofile_once("mods/mahoraga/files/scripts/common.lua")

local me = GetUpdatedEntityID()
local t = GameGetFrameNum() - mh_get( me, "wheel_spin", -1000 )
if t < 0 or t > 40 then return end
local s = EntityGetFirstComponent( me, "SpriteComponent", "mahoraga_player_wheel" )
if s == nil then return end
local img = "mods/mahoraga/files/gfx/wheel.png"
if t < 36 then img = "mods/mahoraga/files/gfx/wheel_" .. tostring( math.floor( t / 6 ) ) .. ".png" end
ComponentSetValue2( s, "image_file", img )
EntityRefreshSprite( me, s )
