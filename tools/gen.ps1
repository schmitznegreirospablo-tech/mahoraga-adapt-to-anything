# Preflight + code generation: sheets/*.json -> mod/mahoraga/files/generated/*.lua and projectile XMLs.
# Usage: powershell -File gen.ps1 [-PreflightOnly]
param([switch]$PreflightOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$mod = Join-Path $root 'mod\mahoraga'
function Sheet($n) { Get-Content (Join-Path $root "sheets\$n.json") -Raw -Encoding UTF8 | ConvertFrom-Json }
$S = @{}
foreach ($n in 'boss','attacks','projectiles','adaptation','perks','world') { $S[$n] = Sheet $n }

# ---------- preflight ----------
$problems = New-Object System.Collections.Generic.List[string]
foreach ($n in $S.Keys) {
  $sh = $S[$n]
  foreach ($row in $sh.rows) {
    foreach ($col in $sh.columns) {
      $v = $row.$col
      if ($null -eq $v) { $problems.Add("$n/$($row.($sh.columns[0])): '$col' is empty") }
    }
    foreach ($p in $row.PSObject.Properties.Name) {
      if ($sh.columns -notcontains $p) { $problems.Add("$n/$($row.($sh.columns[0])): '$p' is not a column") }
    }
  }
}
# empty strings are allowed only where a column means "none"
$allowEmpty = @{ 'projectiles' = @('sprite','explosion_sprite','load_entities'); 'attacks' = @('unlock','warning') }
foreach ($n in $S.Keys) { foreach ($row in $S[$n].rows) { foreach ($col in $S[$n].columns) {
  if ($row.$col -is [string] -and $row.$col -eq '' -and -not ($allowEmpty[$n] -contains $col)) { $problems.Add("$n/$($row.($S[$n].columns[0])): '$col' is blank") }
}}}
$projIds = $S.projectiles.rows | ForEach-Object { $_.id }
foreach ($a in $S.attacks.rows) { if ($projIds -notcontains $a.projectile) { $problems.Add("attacks/$($a.id): projectile '$($a.projectile)' not in projectiles") } }
$perkIds = $S.perks.rows | ForEach-Object { $_.id }
foreach ($b in $S.boss.rows) { foreach ($rp in ($b.reward_perk -split ',')) { if ($perkIds -notcontains $rp) { $problems.Add("boss/$($b.id): reward_perk '$rp' not in perks") } } }
foreach ($p in $S.perks.rows) { if ($p.adaptation_source -ne 'adaptation.player') { $problems.Add("perks/$($p.id): adaptation_source must be adaptation.player") } }
$behaviors = 'fan_at_target','leap_then_blast','dash_digging','ring','lob_at_target','blast_at_self','rain','cut_storm'
foreach ($a in $S.attacks.rows) { if ($behaviors -notcontains $a.behavior) { $problems.Add("attacks/$($a.id): behavior '$($a.behavior)' has no implementation") } }
$fields = 'melee','projectile','explosion','electricity','fire','drill','slice','ice','healing','physics_hit','radioactive','poison','overeating','curse','holy','drowning'
$adaptTypes = $S.adaptation.rows | ForEach-Object { $_.type }
foreach ($a in $S.attacks.rows) { if ($a.unlock -and $adaptTypes -notcontains $a.unlock) { $problems.Add("attacks/$($a.id): unlock '$($a.unlock)' is not an adaptation type") } }
foreach ($r in $S.adaptation.rows) { if ($fields -notcontains $r.field) { $problems.Add("adaptation/$($r.type): '$($r.field)' is not a Noita damage multiplier") } }
foreach ($p in $S.projectiles.rows) { if ($fields -notcontains $p.damage_type) { $problems.Add("projectiles/$($p.id): damage_type '$($p.damage_type)' unknown") } }
# files the mod ships must exist; vanilla files are read from the player's game
function CheckFile($owner, $path) {
  if (-not $path) { return }
  if ($path.StartsWith('mods/mahoraga/')) {
    $local = Join-Path $mod ($path.Substring('mods/mahoraga/'.Length) -replace '/', '\')
    $generatedLater = $path -match '/entities/proj_|/gfx/mahoraga\.xml$|/scripts/perk_append\.lua$|/translations\.csv$'
    if (-not (Test-Path $local) -and -not $generatedLater -and -not ($path -match 'init\.lua$')) { $problems.Add("${owner}: missing file $path") }
  } elseif ($path.StartsWith('data/')) {
    $local = Join-Path $root ('vanilla\' + ($path -replace '/', '\'))
    if (-not (Test-Path $local)) { $problems.Add("${owner}: game file $path not found in Noita's data") }
  }
}
foreach ($b in $S.boss.rows) { CheckFile "boss/$($b.id)" $b.wheel_sprite }
foreach ($p in $S.projectiles.rows) { CheckFile "projectiles/$($p.id)" $p.sprite; CheckFile "projectiles/$($p.id)" $p.explosion_sprite; foreach ($le in ($p.load_entities -split ',')) { CheckFile "projectiles/$($p.id)" $le } }
foreach ($p in $S.perks.rows) { CheckFile "perks/$($p.id)" $p.ui_icon; CheckFile "perks/$($p.id)" $p.perk_icon }
foreach ($w in $S.world.rows) { if ($w.kind -eq 'pixel_scene') { CheckFile "world/$($w.id)" $w.target } }
if ($problems.Count) { "PREFLIGHT: $($problems.Count) problem(s)"; $problems; exit 1 }
"PREFLIGHT: clean ($(($S.Values | ForEach-Object { $_.rows.Count } | Measure-Object -Sum).Sum) rows)"
if ($PreflightOnly) { exit 0 }

# ---------- generation ----------
$gen = Join-Path $mod 'files\generated'; New-Item -ItemType Directory -Force $gen | Out-Null
$ent = Join-Path $mod 'files\entities'; New-Item -ItemType Directory -Force $ent | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Out($path, $text) { [IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"), $utf8) }
function LuaVal($v) {
  if ($v -is [bool]) { return $(if ($v) { 'true' } else { 'false' }) }
  if ($v -is [string]) { return '"' + ($v -replace '\\','\\' -replace '"','\"') + '"' }
  return ([string]$v).Replace(',', '.')
}
function LuaRow($row, $cols) { '{ ' + (($cols | ForEach-Object { "$_ = $(LuaVal $row.$_)" }) -join ', ') + ' }' }
function LuaTable($name, $sheet, $keyCol) {
  $lines = @("$name = {")
  foreach ($r in $sheet.rows) { $lines += "  [$(LuaVal $r.$keyCol)] = $(LuaRow $r $sheet.columns)," }
  $lines += '}'
  $lines += "$($name)_ORDER = { " + (($sheet.rows | ForEach-Object { LuaVal $_.$keyCol }) -join ', ') + ' }'
  $lines -join "`n"
}
$hdr = "-- GENERATED from sheets/*.json by tools/gen.ps1. Edit the sheets, not this file.`n"
Write-Out (Join-Path $gen 'boss_data.lua') ($hdr + (LuaTable 'MAHORAGA_BOSS' $S.boss 'id'))
Write-Out (Join-Path $gen 'attack_data.lua') ($hdr + (LuaTable 'MAHORAGA_ATTACKS' $S.attacks 'id'))
Write-Out (Join-Path $gen 'projectile_data.lua') ($hdr + (LuaTable 'MAHORAGA_PROJECTILES' $S.projectiles 'id'))
Write-Out (Join-Path $gen 'adaptation_data.lua') ($hdr + (LuaTable 'MAHORAGA_ADAPT' $S.adaptation 'type'))
$world = @{}; foreach ($w in $S.world.rows) { $world[$w.id] = $w }
$wl = @('MAHORAGA_WORLD = {')
foreach ($w in $S.world.rows) { if ($w.kind -eq 'number' -or $w.kind -eq 'pixel_scene') { $wl += "  $($w.id) = $(LuaVal $(if ($w.kind -eq 'number') { $w.value } else { $w.target }))," } }
$wl += '}'
Write-Out (Join-Path $gen 'world_data.lua') ($hdr + ($wl -join "`n"))

# perk rows -> perk_list append
$pl = @($hdr.Trim(), 'dofile_once("mods/mahoraga/files/scripts/perk_adaptation.lua")')
foreach ($p in $S.perks.rows) {
  $pl += @"
table.insert( perk_list, {
	id = $(LuaVal $p.id),
	ui_name = "`$perk_$($p.id.ToLower())",
	ui_description = "`$perkdesc_$($p.id.ToLower())",
	ui_icon = $(LuaVal $p.ui_icon),
	perk_icon = $(LuaVal $p.perk_icon),
	stackable = $(LuaVal $p.stackable),
	not_in_default_perk_pool = $(LuaVal $p.not_in_default_perk_pool),
	usable_by_enemies = $(LuaVal $p.usable_by_enemies),
	func = function( entity_perk_item, entity_who_picked, item_name )
		$($p.on_pickup_func)( entity_who_picked, $(LuaVal $p.on_pickup_message) )
	end,
	func_remove = function( entity_who_picked )
		$($p.on_remove_func)( entity_who_picked )
	end,
} )
"@
}
New-Item -ItemType Directory -Force (Join-Path $mod 'files\scripts') | Out-Null
Write-Out (Join-Path $mod 'files\scripts\perk_append.lua') ($pl -join "`n")

# translations: boss name + perk texts (Noita needs the full header row)
$tr = @()
$b0 = $S.boss.rows[0]
$tr += "animal_mahoraga,`"$($b0.name)`",,,,,,,,,,,,,"
$tr += "animal_mahoraga_summon,`"$($b0.name) (summoned)`",,,,,,,,,,,,,"
foreach ($p in $S.perks.rows) {
  $tr += "perk_$($p.id.ToLower()),`"$($p.ui_name)`",,,,,,,,,,,,,"
  $tr += "perkdesc_$($p.id.ToLower()),`"$($p.ui_description)`",,,,,,,,,,,,,"
}
Write-Out (Join-Path $mod 'files\translations.csv') (($tr -join "`n") + "`n")

# projectile rows -> entity XMLs
foreach ($p in $S.projectiles.rows) {
  $rgb = $p.light_rgb -split ','
  $explode = [int]($p.explosion_radius -gt 0)
  $dmgType = if ($p.damage_type -eq 'projectile') { '' } else { "<damage_by_type $($p.damage_type)=`"$($p.damage)`" />" }
  $baseDmg = if ($p.damage_type -eq 'projectile') { $p.damage } else { 0 }
  $scale = if ($p.sprite_scale -ne 1) { " has_special_scale=`"1`" special_scale_x=`"$($p.sprite_scale)`" special_scale_y=`"$($p.sprite_scale)`"" } else { '' }
  $sprite = if ($p.sprite) { @"
	<SpriteComponent image_file="$($p.sprite)" offset_x="$($p.sprite_offset)" offset_y="$($p.sprite_offset_y)" additive="$($p.additive)" emissive="$($p.additive)" update_transform_rotation="1"$scale />
"@ } else { '' }
  $dig = if ($p.cell_eater_radius -gt 0) { "	<CellEaterComponent radius=`"$($p.cell_eater_radius)`" eat_dynamic_physics_bodies=`"1`" ignored_material_tag=`"[indestructible]`" />" } else { '' }
  $loadEnt = if ($p.load_entities) { "`n			load_this_entity=`"$($p.load_entities)`"" } else { '' }
  $light = if ([int]$rgb[0] + [int]$rgb[1] + [int]$rgb[2] -gt 0) { "	<LightComponent radius=`"60`" r=`"$($rgb[0])`" g=`"$($rgb[1])`" b=`"$($rgb[2])`" />" } else { '' }
  $expSprite = if ($p.explosion_sprite) { $p.explosion_sprite } else { 'data/particles/explosion_032.xml' }
  $xml = @"
<!-- GENERATED from sheets/projectiles.json row '$($p.id)' by tools/gen.ps1 -->
<Entity name="`$projectile_default" tags="mahoraga_projectile">
	<Base file="data/entities/base_projectile.xml">
		<VelocityComponent gravity_y="$($p.gravity_y)" air_friction="0" mass="0.5" />
	</Base>
	<ProjectileComponent
		speed_min="$($p.speed)" speed_max="$($p.speed)"
		lifetime="$($p.lifetime)"
		collide_with_world="$($p.collide_with_world)"
		damage="$baseDmg"
		on_collision_die="$($p.on_collision_die)"
		die_on_low_velocity="0"
		on_death_explode="$explode"
		on_lifetime_out_explode="$explode"
		explosion_dont_damage_shooter="1"
		collide_with_shooter_frames="-1"
		friendly_fire="0"
		ground_penetration_coeff="$(if ($p.dig_radius -gt 0) { $p.dig_radius } else { 0 })"
		ground_penetration_max_durability_to_destroy="$($p.dig_max_durability)"
		penetrate_entities="$([int](1 - $p.on_collision_die))"
		velocity_sets_rotation="1"
		knockback_force="2"
		on_death_gfx_leave_sprite="0"
		ragdoll_fx_on_collision="BLOOD_EXPLOSION">
		$dmgType
		<config_explosion
			never_cache="1"
			explosion_radius="$($p.explosion_radius)"
			damage="$($p.explosion_damage)"
			explosion_sprite="$expSprite"
			explosion_sprite_lifetime="0"$loadEnt
			hole_enabled="1"
			hole_destroy_liquid="1"
			ray_energy="$($p.ray_energy)"
			max_durability_to_destroy="$($p.dig_max_durability)"
			create_cell_probability="0"
			camera_shake="$([int]($p.explosion_radius))"
			damage_mortals="1"
			physics_explosion_power.min="0.6" physics_explosion_power.max="1.0"
			physics_throw_enabled="1"
			shake_vegetation="1"
			sparks_enabled="1" sparks_count_min="10" sparks_count_max="30"
			stains_enabled="1"
			stains_image="data/temp/explosion_stain.png"
			hole_image="data/temp/explosion_hole.png"
			audio_event_name="$($p.explosion_audio)" />
	</ProjectileComponent>
$sprite
$dig
$light
	<AudioComponent file="data/audio/Desktop/projectiles.bank" event_root="$($p.sound_root)" />
	<VariableStorageComponent name="projectile_file" value_string="$($p.file)" />
</Entity>
"@
  Write-Out (Join-Path $ent ([IO.Path]::GetFileName($p.file))) $xml
}

# boss row -> sprite XML (sheet layout drawn by tools/makeart.cs: 40x44 frames, rows stand/walk/attack/jump)
$b = $S.boss.rows[0]
$fw = 40; $fh = 44
function Anim($name, $row, $count, $wait, $loop) { "	<RectAnimation name=`"$name`" pos_x=`"0`" pos_y=`"$($row * $fh)`" frame_count=`"$count`" frame_width=`"$fw`" frame_height=`"$fh`" frame_wait=`"$wait`" frames_per_row=`"4`" loop=`"$loop`" />" }
$sx = @(
  "<!-- GENERATED from sheets/boss.json by tools/gen.ps1 -->",
  "<Sprite filename=`"mods/mahoraga/files/gfx/mahoraga.png`" offset_x=`"16`" offset_y=`"43`" default_animation=`"stand`">",
  (Anim 'stand' 0 2 0.35 1), (Anim 'walk' 1 4 0.14 1), (Anim 'run' 1 4 0.10 1), (Anim 'burn' 1 4 0.10 1),
  (Anim 'attack' 2 4 0.08 0), (Anim 'attack_ranged' 2 4 0.08 0),
  (Anim 'jump_up' 3 1 0.2 0), (Anim 'jump_fall' 3 1 0.2 0), (Anim 'land' 3 2 0.1 0), (Anim 'fly_idle' 3 2 0.2 1), (Anim 'fly_move' 3 2 0.2 1),
  "</Sprite>")
Write-Out (Join-Path $mod 'files\gfx\mahoraga.xml') ($sx -join "`n")

# boss row -> entity XML
$hw = $b.hitbox_w / 2
$bx = @"
<!-- GENERATED from sheets/boss.json row '$($b.id)' by tools/gen.ps1 -->
<Entity name="`$animal_mahoraga" tags="enemy,mortal,hittable,homing_target,teleportable_NOT,boss,miniboss,polymorphable_NOT,necrobot_NOT,glue_NOT,touchmagic_immunity,mahoraga,$($b.music_tag)">
	<Base file="data/entities/base_enemy_basic.xml">
		<ItemChestComponent level="5" />
		<AnimalAIComponent
			preferred_job="JobDefault"
			escape_if_damaged_probability="0"
			creature_detection_range_x="500"
			creature_detection_range_y="300"
			needs_food="0"
			sense_creatures="1"
			attack_ranged_enabled="0"
			attack_melee_enabled="1"
			attack_melee_damage_min="$($b.contact_damage * $b.damage_scale)"
			attack_melee_damage_max="$($b.contact_damage * $b.damage_scale)"
			attack_melee_max_distance="22"
			attack_melee_frames_between="40"
			can_fly="0"
			aggressiveness_min="100"
			aggressiveness_max="100" />
		<DamageModelComponent
			hp="$($b.hp)"
			max_hp="$($b.hp)"
			air_needed="1"
			air_in_lungs_max="$($b.air_in_lungs_max)"
			air_lack_of_damage="$($b.air_lack_of_damage)"
			fire_probability_of_ignition="0.2"
			falling_damages="0"
			materials_damage="1"
			ragdoll_material="meat"
			ragdoll_filenames_file=""
			blood_material="blood"
			blood_multiplier="0.5"
			physics_objects_damage="0"
			critical_damage_resistance="1">
			<damage_multipliers drill="1" />
		</DamageModelComponent>
		<SpriteComponent image_file="$($b.sprite)" offset_x="0" offset_y="0" />
		<PathFindingComponent can_jump="1" can_fly="0" jump_speed="160" initial_jump_lob="1" initial_jump_max_distance_x="120" initial_jump_max_distance_y="80" />
		<GenomeDataComponent herd_id="$($b.herd_id)" food_chain_rank="1" is_predator="1" />
		<CharacterPlatformingComponent run_velocity="$($b.run_velocity)" jump_velocity_y="$($b.jump_velocity_y)" accel_x="0.4" velocity_min_x="-140" velocity_max_x="140" />
		<HitboxComponent aabb_min_x="-$hw" aabb_max_x="$hw" aabb_min_y="-$($b.hitbox_h)" aabb_max_y="2" />
		<CharacterDataComponent collision_aabb_min_x="-5" collision_aabb_max_x="5" collision_aabb_min_y="-36" collision_aabb_max_y="2" mass="6" climb_over_y="6" />
		<CameraBoundComponent enabled="0" />
	</Base>
	<HotspotComponent _tags="shoot_pos" offset.x="10" offset.y="-26" />
	<SpriteComponent _tags="health_bar_back,ui,no_hitbox" has_special_scale="1" image_file="data/ui_gfx/health_slider_back.png" offset_x="12" offset_y="-4" emissive="1" never_ragdollify_on_death="1" z_index="-9000" />
	<SpriteComponent _tags="health_bar,ui,no_hitbox" has_special_scale="1" image_file="data/ui_gfx/health_slider_front.png" offset_x="11" offset_y="-4" emissive="1" never_ragdollify_on_death="1" z_index="-9000" />
	<HealthBarComponent />
	<BossHealthBarComponent />
	<MusicEnergyAffectorComponent energy_target="1" />
	<LightComponent radius="90" r="255" g="220" b="150" offset_y="-30" />
	<SpriteComponent _tags="mahoraga_wheel,no_hitbox" image_file="$($b.wheel_sprite)" offset_x="12" offset_y="$(12 - $b.wheel_offset_y)" emissive="1" z_index="-1" update_transform_rotation="0" />
	<VariableStorageComponent _tags="mahoraga_state" name="mahoraga_state" value_string="" />
	<LuaComponent script_source_file="mods/mahoraga/files/scripts/boss_ai.lua" execute_every_n_frame="1" />
	<LuaComponent script_damage_received="mods/mahoraga/files/scripts/boss_damage.lua" execute_every_n_frame="-1" />
	<LuaComponent script_death="mods/mahoraga/files/scripts/boss_death.lua" execute_every_n_frame="-1" />
	<AudioComponent file="data/audio/Desktop/animals.bank" event_root="animals/giant" />
</Entity>
"@
Write-Out (Join-Path $ent 'mahoraga.xml') $bx
$sx2 = $bx -replace '<!-- GENERATED from sheets/boss.json row ''([^'']+)'' by tools/gen.ps1 -->', '<!-- GENERATED from sheets/boss.json row ''$1'' by tools/gen.ps1: the Summon Mahoraga perk''s ally -->'
$sx2 = $sx2 -replace 'name="\$animal_mahoraga" tags="[^"]*"', 'name="$animal_mahoraga_summon" tags="mortal,hittable,teleportable_NOT,polymorphable_NOT,necrobot_NOT,glue_NOT,touchmagic_immunity,mahoraga_summon"'
$sx2 = $sx2 -replace '\s*<ItemChestComponent level="5" />', ''
$sx2 = $sx2 -replace 'herd_id="[^"]*"', 'herd_id="player"'
$sx2 = $sx2 -replace '\s*<BossHealthBarComponent />', ''
$sx2 = $sx2 -replace '\s*<MusicEnergyAffectorComponent[^>]*/>', ''
$sx2 = $sx2 -replace '\s*<LuaComponent script_death="[^"]*" execute_every_n_frame="-1" />', ''
$sx2 = $sx2.Replace('<VariableStorageComponent _tags="mahoraga_state"', '<VariableStorageComponent name="summon" value_float="1" />
	<VariableStorageComponent _tags="mahoraga_state"')
Write-Out (Join-Path $ent 'mahoraga_summon.xml') $sx2
"GENERATED: boss, $($S.attacks.rows.Count) attacks, $($S.projectiles.rows.Count) projectiles, $($S.adaptation.rows.Count) adaptation types, $($S.perks.rows.Count) perk(s), world"


