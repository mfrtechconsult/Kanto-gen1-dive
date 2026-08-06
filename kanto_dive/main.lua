local function loadModule(mod, relativePath)
  local source, readError = mod:read(relativePath)
  if not source then
    mod.log:error("Could not read %s: %s", relativePath, tostring(readError))
    return nil
  end
  local compiler = loadstring or load
  local chunk, loadError = compiler(source, "@" .. mod.path .. "/" .. relativePath)
  if not chunk then
    mod.log:error("Could not compile %s: %s", relativePath, tostring(loadError))
    return nil
  end
  local ok, value = pcall(chunk)
  if not ok then
    mod.log:error("Could not initialize %s: %s", relativePath, tostring(value))
    return nil
  end
  return value
end

local function appendLinks(target, payload)
  if type(payload) ~= "table" then return nil, "link file did not return a table" end
  if payload.surface or payload.surfaceMap then
    target[#target + 1] = payload
    return true
  end
  local links = payload.links or payload
  for index, link in ipairs(links) do
    if type(link) ~= "table" then
      return nil, ("link file entry %d is not a table"):format(index)
    end
    target[#target + 1] = link
  end
  return true
end

return function(mod)
  local Content = loadModule(mod, "src/Content.lua")
  local ZoneRegistry = loadModule(mod, "src/ZoneRegistry.lua")
  local DiveService = loadModule(mod, "src/DiveService.lua")
  local Progression = loadModule(mod, "src/Progression.lua")
  local SurfaceDarkService = loadModule(mod, "src/SurfaceDarkService.lua")
  local zoneDefinitions = loadModule(mod, "data/zones.lua")
  if not (Content and ZoneRegistry and DiveService and Progression and SurfaceDarkService and zoneDefinitions) then
    return
  end

  if not Content.register(mod) then return end

  local registry = ZoneRegistry.new(mod)
  for id, definition in pairs(zoneDefinitions) do
    definition.links = definition.links or {}
    for _, relativePath in ipairs(definition.linkFiles or {}) do
      local payload = loadModule(mod, relativePath)
      if not payload then return end
      local ok, err = appendLinks(definition.links, payload)
      if not ok then
        mod.log:error("Could not load links for zone %s from %s: %s",
          tostring(id), relativePath, tostring(err))
        return
      end
    end
    local zone, err = registry:register(id, definition, mod.id)
    if not zone then
      mod.log:error("Could not register dive zone %s: %s", tostring(id), tostring(err))
      return
    end
  end

  local surfaceDarkService = SurfaceDarkService.new(mod, registry)
  if not surfaceDarkService:install() then return end

  local service = DiveService.new(mod, registry)
  service:install()
  Progression.install(mod)

  mod.exports.isUnderwater = function()
    return service:isUnderwater()
  end
  mod.exports.getCurrentZone = function()
    return service:currentZone()
  end
  mod.exports.canDiveHere = function(game)
    return service:canDiveHere(game)
  end
  mod.exports.canSurfaceHere = function(game)
    return service:canSurfaceHere(game)
  end
  mod.exports.getDiveTarget = function(mapId, x, y)
    return registry:diveTarget(mapId, x, y)
  end
  mod.exports.getSurfaceTarget = function(mapId, x, y)
    return registry:surfaceTarget(mapId, x, y)
  end
  mod.exports.getDiveMarkers = function(mapId)
    return surfaceDarkService:cellsFor(mapId)
  end
  mod.exports.getVisualDiveMarkers = function(mapId)
    return surfaceDarkService:cellsFor(mapId)
  end
  mod.exports.getDiveMarkerAt = function(mapId, x, y)
    return surfaceDarkService:cellAt(mapId, x, y)
  end
  mod.exports.registerZone = function(id, definition, owner)
    return registry:register(id, definition, owner or "external")
  end
end
