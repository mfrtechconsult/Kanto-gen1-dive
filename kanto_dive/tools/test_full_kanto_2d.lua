local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

package.preload["src.world.Map"] = function()
  return {
    defIsWaterCell = function(def, _tileset, x, y)
      return def._water and def._water[key(x, y)] == true or false
    end,
    defIsWalkableCell = function(def, _tileset, x, y)
      return def._walkable and def._walkable[key(x, y)] == true or false
    end,
    defCellTile = function(def, _tileset, x, y)
      return def._tiles and def._tiles[key(x, y)] or 0
    end,
  }
end

local function registry(base)
  local added = {}
  return {
    get = function(_, id) return added[id] or base[id] end,
    register = function(_, id, value) assert(not added[id]); added[id] = value; return value end,
    each = function()
      local ids = {}
      for id in pairs(base) do ids[#ids + 1] = id end
      table.sort(ids)
      local i = 0
      return function()
        i = i + 1
        local id = ids[i]
        if not id then return nil end
        return id, base[id]
      end
    end,
    _added = added,
  }
end

local function waterRect(width, height)
  local out = {}
  for y = 0, height - 1 do
    for x = 0, width - 1 do out[key(x, y)] = true end
  end
  return out
end

local route19 = {
  id = "ROUTE_19", index = 19, tileset = "OVERWORLD", width = 2, height = 2,
  connections = { east = { map = "ROUTE_20", offset = 0 } },
  _water = waterRect(4, 4), _walkable = {},
}
local route20 = {
  id = "ROUTE_20", index = 20, tileset = "OVERWORLD", width = 2, height = 2,
  connections = { west = { map = "ROUTE_19", offset = 0 } },
  _water = waterRect(4, 4), _walkable = {},
}
-- Keep a little coast while retaining a 3-cell reciprocal seam.
route19._water[key(0, 0)] = nil
route20._water[key(0, 0)] = nil
route20._water[key(3, 3)] = nil

local bridge = {
  id = "ROUTE_11", index = 11, tileset = "OVERWORLD", width = 3, height = 1,
  connections = {}, _water = {}, _walkable = {},
}
-- Water -- two-cell walkable bridge -- water. Underwater hydrology must join it.
for y = 0, 1 do
  bridge._water[key(0, y)] = true
  bridge._water[key(1, y)] = true
  bridge._water[key(4, y)] = true
  bridge._water[key(5, y)] = true
  bridge._walkable[key(2, y)] = true
  bridge._walkable[key(3, y)] = true
end

local mapsBase = { ROUTE_19 = route19, ROUTE_20 = route20, ROUTE_11 = bridge }
local maps = registry(mapsBase)
local tilesets = registry({ OVERWORLD = { id = "OVERWORLD", waterTiles = { 0x14 } } })
local songs = { register = function() return true end }
local encounters = registry({})
local field = { get = function(_, id) if id == "waterTilesets" then return { "OVERWORLD" } end end }
local mod = { content = { maps = maps, tilesets = tilesets, map_songs = songs, encounters = encounters, field = field } }

local profiles = dofile(root .. "/data/seabed_profiles.lua")
local Atlas = dofile(root .. "/src/KantoWaterAtlas.lua")
local Generator = dofile(root .. "/src/Seabed2DGenerator.lua")
local ZoneRegistry = dofile(root .. "/src/ZoneRegistry.lua")
local ScaledSurfaceTargets = dofile(root .. "/src/ScaledSurfaceTargets.lua")

local atlas = Atlas.new(mod, profiles):build()
assert(atlas.stats.maps == 3, "all synthetic water maps should be scanned")
assert(atlas:surface("ROUTE_19").underwaterScale == 3, "open ocean should use x3 scale")
assert(atlas:surface("ROUTE_20").underwaterScale == 3, "connected open ocean should use x3 scale")
assert(atlas.stats.maxUnderwaterScale == 3, "maximum scale should be x3")
assert(atlas.stats.expandedSeabedCells > atlas.stats.seabedCells,
  "expanded underwater world must contain more swim cells than surface hydrology")

local bridgeEntry = atlas:surface("ROUTE_11")
assert(bridgeEntry.underStructure[key(2, 0)] ~= nil, "bridge cell must become underwater hydrology")
assert(bridgeEntry.underStructure[key(3, 1)] ~= nil, "bridge span must remain continuous underwater")
assert(not bridgeEntry.surfaceWater[key(2, 0)], "bridge must remain non-DIVE surface land")

local generated = Generator.new(mod, atlas, profiles):build()
local underwater19 = maps._added.KD_SEABED_ROUTE_19
assert(underwater19, "ROUTE_19 underwater map must be generated")
assert(underwater19.width == route19.width * 3 and underwater19.height == route19.height * 3,
  "x3 ocean scale must enlarge map block dimensions")
assert(#underwater19.blocks == underwater19.width * underwater19.height,
  "generated block count must match enlarged dimensions")
assert(generated.encounters[underwater19.id].grass.rate == 0,
  "engine-facing underwater encounter table must remain inert")
assert(generated.activeEncounters[underwater19.id].grass.rate > 0,
  "standalone Kanto Dive must retain classic encounters through policy injection")

local zoneRegistry = ZoneRegistry.new(mod)
local zone, err = zoneRegistry:register("full_kanto_generated", generated.zones.full_kanto_generated, "test")
assert(zone, err)
local expanded, expandErr = ScaledSurfaceTargets.install(zoneRegistry, atlas, "full_kanto_generated")
assert(expanded, expandErr)

local target = zoneRegistry:diveTarget("ROUTE_19", 1, 1)
assert(target and target.mapId == "KD_SEABED_ROUTE_19", "DIVE should target generated underwater map")
assert(target.x == 4 and target.y == 4, "surface (1,1) should land at center of its x3 footprint")

for uy = 3, 5 do
  for ux = 3, 5 do
    local surface = zoneRegistry:surfaceTarget("KD_SEABED_ROUTE_19", ux, uy)
    assert(surface and surface.mapId == "ROUTE_19" and surface.x == 1 and surface.y == 1,
      "every cell in x3 footprint must SURFACE to the original surface cell")
  end
end

assert(atlas:isUnderwaterCell("KD_SEABED_ROUTE_11", 2, 0),
  "water underneath inferred bridge must be swimmable")

print(string.format(
  "Full-Kanto 2D contract OK: %d maps, %d -> %d hydrology cells, max scale x%d",
  atlas.stats.maps, atlas.stats.seabedCells, atlas.stats.expandedSeabedCells,
  atlas.stats.maxUnderwaterScale))
