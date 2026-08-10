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

local function cellKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

return function(mod)
  local Content = loadModule(mod, "src/Content.lua")
  local ZoneRegistry = loadModule(mod, "src/ZoneRegistry.lua")
  local DiveService = loadModule(mod, "src/DiveService.lua")
  local Progression = loadModule(mod, "src/Progression.lua")
  local JohtoWaterMoves = loadModule(mod, "src/JohtoWaterMoves.lua")
  local WaterFeaturePolish = loadModule(mod, "src/WaterFeaturePolish.lua")
  local HMForgetGuard = loadModule(mod, "src/HMForgetGuard.lua")
  local HMShowcase = loadModule(mod, "src/HMShowcase.lua")

  local KantoWaterAtlas = loadModule(mod, "src/KantoWaterAtlas.lua")
  local Seabed2DGenerator = loadModule(mod, "src/Seabed2DGenerator.lua")
  local ScaledSurfaceTargets = loadModule(mod, "src/ScaledSurfaceTargets.lua")
  local EncounterPolicy2D = loadModule(mod, "src/EncounterPolicy2D.lua")
  local FollowerSprites2D = loadModule(mod, "src/FollowerSprites2D.lua")
  local UnderwaterWildlife2D = loadModule(mod, "src/UnderwaterWildlife2D.lua")
  local UnderwaterIntercept2D = loadModule(mod, "src/UnderwaterIntercept2D.lua")
  local SubmergedWarpLinks2D = loadModule(mod, "src/SubmergedWarpLinks2D.lua")
  local seabedProfiles = loadModule(mod, "data/seabed_profiles.lua")

  if not (Content and ZoneRegistry and DiveService and Progression
      and JohtoWaterMoves and WaterFeaturePolish and HMForgetGuard and HMShowcase
      and KantoWaterAtlas and Seabed2DGenerator and ScaledSurfaceTargets
      and EncounterPolicy2D and FollowerSprites2D and UnderwaterWildlife2D
      and UnderwaterIntercept2D and SubmergedWarpLinks2D and seabedProfiles) then
    return
  end

  if not Content.register(mod) then return end

  -- Full-Kanto 2D generation. Surface water remains the only DIVE/SURFACE
  -- entry mask, while hydrology may continue beneath bridges, docks/pontoons.
  local atlas = KantoWaterAtlas.new(mod, seabedProfiles):build()
  local generator = Seabed2DGenerator.new(mod, atlas, seabedProfiles)
  local generated = generator:build()

  local johtoWater = JohtoWaterMoves.install(mod, {
    whirlpoolBadge = "VOLCANOBADGE",
    waterfallBadge = "EARTHBADGE",
    whirlpools = {
      { id = "route20_seafoam_whirlpool", mapId = "ROUTE_20", x = 49, y = 12, width = 2, height = 4 },
    },
    waterfalls = {
      { id = "route21_central_waterfall", mapId = "ROUTE_21", x = 3, y = 50, width = 14, height = 2 },
    },
  })
  if not johtoWater or not HMForgetGuard.install(mod) then return end
  if not WaterFeaturePolish.install(mod, johtoWater) then return end

  HMShowcase.install(mod, {
    ROUTE_20 = {
      id = "hm06_whirlpool_route20", move = "WHIRLPOOL",
      text = "HM06 WHIRLPOOL TEST\nA whirlpool blocks the\nSeafoam channel.\fFace it while SURFing\nand use WHIRLPOOL.",
    },
    ROUTE_21 = {
      id = "hm07_waterfall_route21", move = "WATERFALL",
      text = "HM07 WATERFALL TEST\nA waterfall blocks the\ncentral current.\fDescend freely, then\nuse WATERFALL to climb.",
    },
  })

  local registry = ZoneRegistry.new(mod)
  local fullZone = generated.zones.full_kanto_generated
  local zone, zoneError = registry:register("full_kanto_generated", fullZone, mod.id)
  if not zone then
    mod.log:error("Could not register generated Full-Kanto DIVE zone: %s", tostring(zoneError))
    return
  end

  local expandedSurfaceTargets, scaledError = ScaledSurfaceTargets.install(
    registry, atlas, "full_kanto_generated")
  if not expandedSurfaceTargets then
    mod.log:error("Could not expand Full-Kanto SURFACE mapping: %s", tostring(scaledError))
    return
  end

  local service = DiveService.new(mod, registry)
  service:install()
  Progression.install(mod)

  local encounterPolicy = EncounterPolicy2D.new(mod, registry, generated.activeEncounters)
  encounterPolicy:install()

  local sprites = FollowerSprites2D.new(mod)
  local wildlife = UnderwaterWildlife2D.new(mod, service, registry, atlas, sprites, seabedProfiles)
  local intercept = UnderwaterIntercept2D.new(mod, service, wildlife)
  wildlife:install()
  intercept:install()

  local submergedWarpLinks = SubmergedWarpLinks2D.new(mod, atlas, service)
  submergedWarpLinks:install()

  local stats = generator:stats(generated)
  if mod.log then
    mod.log:info(
      "Full-Kanto 2D atlas: %d maps, %d surface-water cells, %d hydrology cells, %d expanded swim cells, %d seams, max scale x%d, %d scaled SURFACE cells, %d submerged portals",
      stats.maps or 0, stats.surfaceWaterCells or 0, stats.seabedCells or 0,
      stats.expandedSeabedCells or 0, stats.seams or 0, stats.maxScale or 1,
      expandedSurfaceTargets or 0, submergedWarpLinks.count or 0)
  end

  local function markerAt(mapId, x, y)
    local entry = atlas:surface(mapId)
    if not (entry and entry.surfaceWater[cellKey(x, y)]) then return nil end
    return {
      mapId = mapId, x = x, y = y,
      zoneId = "full_kanto_generated",
      linkId = string.format("atlas_%s_%d_%d", mapId:lower(), x, y),
    }
  end

  local function markersFor(mapId)
    local out = {}
    local entry = atlas:surface(mapId)
    if not entry then return out end
    for key in pairs(entry.surfaceWater or {}) do
      local x, y = key:match("^(%-?%d+):(%-?%d+)$")
      local cell = markerAt(mapId, tonumber(x), tonumber(y))
      if cell then out[#out + 1] = cell end
    end
    table.sort(out, function(a, b)
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    return out
  end

  mod.exports.isUnderwater = function() return service:isUnderwater() end
  mod.exports.getCurrentZone = function() return service:currentZone() end
  mod.exports.canDiveHere = function(game) return service:canDiveHere(game) end
  mod.exports.canSurfaceHere = function(game) return service:canSurfaceHere(game) end
  mod.exports.getDiveTarget = function(mapId, x, y) return registry:diveTarget(mapId, x, y) end
  mod.exports.getSurfaceTarget = function(mapId, x, y) return registry:surfaceTarget(mapId, x, y) end
  mod.exports.registerZone = function(id, definition, owner)
    return registry:register(id, definition, owner or "external")
  end

  -- Full-Kanto mode: every real water cell is intended to be diveable, so the
  -- old dark DIVE marker has no purpose and is deliberately not rendered.
  mod.exports.allWaterDiveable = function() return true end
  mod.exports.surfaceDiveMaskEnabled = function() return false end
  mod.exports.getDiveMarkers = markersFor
  mod.exports.getVisualDiveMarkers = function() return {} end
  mod.exports.getDiveMarkerAt = markerAt

  mod.exports.underwaterMapFor = function(surfaceMapId) return atlas:underwaterMapId(surfaceMapId) end
  mod.exports.surfaceMapFor = function(underwaterMapId) return atlas:surfaceMapId(underwaterMapId) end
  mod.exports.canSwimAt = function(mapId, x, y) return atlas:isUnderwaterCell(mapId, x, y) end
  mod.exports.waterAtlasStats = function()
    local portalStats = submergedWarpLinks:stats()
    return {
      maps = atlas.stats.maps,
      surfaceWaterCells = atlas.stats.surfaceWaterCells,
      underStructureCells = atlas.stats.underStructureCells,
      seabedCells = atlas.stats.seabedCells,
      expandedSeabedCells = atlas.stats.expandedSeabedCells,
      components = atlas.stats.components,
      seams = atlas.stats.seams,
      maxScale = atlas.stats.maxUnderwaterScale,
      submergedPortals = portalStats.portals,
      submergedPortalTransitions = portalStats.transitions,
    }
  end
  mod.exports.oceanLifeStats = function() return wildlife:stats() end
  mod.exports.oceanInterceptStats = function() return intercept:stats() end
  mod.exports.encounterPolicyStats = function() return encounterPolicy:stats() end
  mod.exports.submergedWarpStats = function() return submergedWarpLinks:stats() end

  mod.exports.canWhirlpoolHere = function(game) return johtoWater:canWhirlpool(game) end
  mod.exports.canWaterfallHere = function(game) return johtoWater:canWaterfall(game) end
  mod.exports.registerWhirlpool = function(definition) return johtoWater:registerWhirlpool(definition) end
  mod.exports.registerWaterfall = function(definition) return johtoWater:registerWaterfall(definition) end
end
