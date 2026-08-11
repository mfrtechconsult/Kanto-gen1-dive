local Game = require("src.core.Game")

local EncounterPolicy2D = {}
EncounterPolicy2D.__index = EncounterPolicy2D

local HARD_PRIORITY = 1000000

function EncounterPolicy2D.new(mod, registry, activeDefinitions)
  return setmetatable({
    mod = mod,
    registry = registry,
    activeDefinitions = activeDefinitions or {},
  }, EncounterPolicy2D)
end

function EncounterPolicy2D:currentMapId()
  local ow = Game and Game.overworld
  local map = ow and ow.map
  return map and map.id or nil
end

function EncounterPolicy2D:isManagedUnderwaterMap(mapId)
  if type(mapId) ~= "string" then return false end
  return self.registry and self.registry:submergedZone(mapId) ~= nil or false
end

function EncounterPolicy2D:wildsInstalled()
  if self.mod and self.mod.find then
    local ok, handle = pcall(self.mod.find, self.mod, "overworld_wild_spawns")
    if ok and handle then return true end
  end
  local exports = Game and Game.mods and Game.mods.exports
  return exports and exports.overworld_wild_spawns ~= nil or false
end

function EncounterPolicy2D:install()
  local service = self

  self.mod.hooks:wrap("encounter.roll", function(nextFn, encounterDef, ctx)
    local mapId = ctx and ctx.mapId or service:currentMapId()
    if service:isManagedUnderwaterMap(mapId) then
      if service:wildsInstalled() then
        return nil
      end
      local active = service.activeDefinitions[mapId]
      if active then return nextFn(active, ctx) end
    end
    return nextFn(encounterDef, ctx)
  end, HARD_PRIORITY)

  -- Second hard gate. If another very-high-priority encounter.roll wrapper
  -- forces a Pokemon without calling next(), OverworldState still sends that
  -- result through encounter.species. Suppress it here in Wilds mode.
  self.mod.hooks:wrap("encounter.species", function(nextFn, encounter, ctx)
    local mapId = ctx and ctx.mapId or service:currentMapId()
    if service:wildsInstalled() and service:isManagedUnderwaterMap(mapId) then
      return nil
    end
    return nextFn(encounter, ctx)
  end, HARD_PRIORITY)

  return true
end

function EncounterPolicy2D:stats()
  return {
    wilds = self:wildsInstalled(),
    managedMap = self:isManagedUnderwaterMap(self:currentMapId()),
  }
end

return EncounterPolicy2D
