-- GENERATED from sheets/*.json by tools/gen.ps1. Edit the sheets, not this file.
MAHORAGA_DEFENSES = {
  ["fields"] = { id = "fields", display_name = "projectile fields", perks = "PROJECTILE_REPULSION,PROJECTILE_REPULSION_SECTOR,PROJECTILE_SLOW_FIELD", immunity = false, counter = "untag", message = "Your fields no longer push or slow his attacks." },
  ["shield"] = { id = "shield", display_name = "energy shields", perks = "SHIELD", immunity = false, counter = "break_shield", message = "Every blow now shatters your shield." },
  ["protections"] = { id = "protections", display_name = "protections and immunities", perks = "PROTECTION_FIRE,PROTECTION_RADIOACTIVITY,PROTECTION_EXPLOSION,PROTECTION_MELEE,PROTECTION_ELECTRICITY,PROTECTION_FREEZE", immunity = true, counter = "pierce", message = "His attacks now pierce protections with cursed power." },
  ["invisibility"] = { id = "invisibility", display_name = "invisibility", perks = "INVISIBILITY", immunity = false, counter = "sense", message = "He no longer needs to see you." },
  ["evasion"] = { id = "evasion", display_name = "your evasion", perks = "", immunity = false, counter = "haste", message = "He strikes faster, and his attacks fly faster." },
}
MAHORAGA_DEFENSES_ORDER = { "fields", "shield", "protections", "invisibility", "evasion" }