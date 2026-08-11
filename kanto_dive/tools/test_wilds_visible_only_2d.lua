local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local game = {
  overworld = { map = { id = "KD_SEABED_ROUTE_TEST" } },
  mods = { exports = { overworld_wild_spawns = {} } },
}
package.preload["src.core.Game"] = function() return game end

local hooks = {}
local mod = {
  find = function(_, id)
    if id == "overworld_wild_spawns" then return { exports = {} } end
  end,
  hooks = {
    wrap = function(_, name, callback, priority)
      hooks[name] = { callback = callback, priority = priority }
      return function() end
    end,
  },
}
local registry = {
  submergedZone = function(_, mapId)
    if mapId == "KD_SEABED_ROUTE_TEST" then return { id = "full_kanto_generated" } end
  end,
}
local active = {
  KD_SEABED_ROUTE_TEST = {
    grass = { rate = 18, slots = { { species = "MAGIKARP", level = 5 } } },
  },
}

local Policy = dofile(root .. "/src/EncounterPolicy2D.lua")
local policy = Policy.new(mod, registry, active)
policy:install()
assert(hooks["encounter.roll"] and hooks["encounter.species"],
  "both public encounter gates must be installed")
assert(hooks["encounter.roll"].priority >= 1000000,
  "random encounter gate must use hard priority")

local nextCalls = 0
local roll = hooks["encounter.roll"].callback(function(def)
  nextCalls = nextCalls + 1
  return { species = def.grass.slots[1].species, level = 5 }
end, { grass = { rate = 255, slots = { { species = "ZUBAT", level = 3 } } } },
{ mapId = "KD_SEABED_ROUTE_TEST" })
assert(roll == nil and nextCalls == 0,
  "Wilds must suppress underwater encounter.roll without calling downstream")

local speciesCalls = 0
local species = hooks["encounter.species"].callback(function(enc)
  speciesCalls = speciesCalls + 1
  return enc
end, { species = "ZUBAT", level = 3 }, { mapId = "KD_SEABED_ROUTE_TEST" })
assert(species == nil and speciesCalls == 0,
  "Wilds must suppress forced underwater species too")

-- Remove Wilds: the policy should inject Kanto Dive's active standalone table.
mod.find = function() return nil end
game.mods.exports.overworld_wild_spawns = nil
local injectedRate
local standalone = hooks["encounter.roll"].callback(function(def)
  injectedRate = def.grass.rate
  return { species = def.grass.slots[1].species, level = 5 }
end, { grass = { rate = 0, slots = {} } }, { mapId = "KD_SEABED_ROUTE_TEST" })
assert(standalone and standalone.species == "MAGIKARP" and injectedRate == 18,
  "without Wilds, standalone underwater classic encounters must be restored")

-- Outside Kanto Dive underwater maps, normal encounter data must pass through.
local outsideRate
hooks["encounter.roll"].callback(function(def)
  outsideRate = def.grass.rate
  return nil
end, { grass = { rate = 77, slots = {} } }, { mapId = "ROUTE_TEST" })
assert(outsideRate == 77, "normal maps must retain their own encounter table")

print("Wilds visible-only 2D encounter policy OK")
