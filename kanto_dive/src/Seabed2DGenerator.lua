local Seabed2DGenerator = {}
Seabed2DGenerator.__index = Seabed2DGenerator

local function cellKey(x, y) return tostring(x) .. ":" .. tostring(y) end

local function stableHash(mapId, x, y, salt)
  local value = tonumber(salt) or 0
  local text = tostring(mapId or "")
  for i = 1, #text do value = (value * 33 + text:byte(i)) % 2147483647 end
  value = (value + (x + 17) * 73856093 + (y + 29) * 19349663) % 2147483647
  return value
end

local function sourceCell(entry, ux, uy)
  local scale = entry.underwaterScale or 1
  return math.floor(ux / scale), math.floor(uy / scale)
end

local function sourceWater(entry, ux, uy)
  local sx, sy = sourceCell(entry, ux, uy)
  return entry.water[cellKey(sx, sy)] == true, sx, sy
end

local function maskAtBlock(entry, bx, by)
  local mask = 0
  local cells = {
    { bx * 2,     by * 2,     1 },
    { bx * 2 + 1, by * 2,     2 },
    { bx * 2,     by * 2 + 1, 4 },
    { bx * 2 + 1, by * 2 + 1, 8 },
  }
  for _, c in ipairs(cells) do
    if sourceWater(entry, c[1], c[2]) then mask = mask + c[3] end
  end
  return mask
end

local function decorativeBlock(entry, bx, by)
  local scale = entry.underwaterScale or 1
  local sourceX = math.floor((bx * 2 + 1) / scale)
  local sourceY = math.floor((by * 2 + 1) / scale)
  local shore = entry.shoreDistance[cellKey(sourceX, sourceY)] or 0
  local profile = entry.profile or {}
  local pool = shore >= 4 and profile.deepDecor or profile.decor
  if not pool or #pool == 0 then return 0 end
  local index = (stableHash(entry.id, bx, by, 701) % #pool) + 1
  return pool[index]
end

local function safeLabel(id)
  return ("KantoDiveSeabed_" .. tostring(id)):gsub("[^%w_]", "_")
end

local function appendSpecies(slots, list, level, count)
  if not list or #list == 0 then return end
  for i = 1, count do
    slots[#slots + 1] = {
      species = list[((i - 1) % #list) + 1],
      level = level + math.floor((i - 1) / math.max(1, #list)),
    }
  end
end

local function encounterFor(entry, profileData)
  local profile = entry.profile or {}
  local ecologyName = profile.ecology or entry.profileName or "ocean"
  local ecology = profileData.ecology and profileData.ecology[ecologyName]
  if not ecology then ecology = profileData.ecology and profileData.ecology.ocean end
  if not ecology then return { grass = { rate = 0, slots = {} } }, { grass = { rate = 0, slots = {} } } end

  local base = entry.profileName == "marsh" and 16
    or entry.profileName == "freshwater" and 18
    or entry.profileName == "harbor" and 20
    or entry.profileName == "cave" and 27
    or entry.profileName == "volcanic" and 29
    or entry.profileName == "ocean" and 25
    or 21

  local slots = {}
  appendSpecies(slots, ecology.shallow, base, 4)
  appendSpecies(slots, ecology.mid, base + 3, 3)
  appendSpecies(slots, ecology.deep, base + 6, 3)
  while #slots > 10 do table.remove(slots) end

  local inert = { grass = { rate = 0, slots = slots } }
  local active = { grass = { rate = tonumber(profile.encounterRate) or 16, slots = slots } }
  return inert, active
end

function Seabed2DGenerator.new(mod, atlas, profileData)
  return setmetatable({ mod = mod, atlas = atlas, profileData = profileData or {} }, Seabed2DGenerator)
end

function Seabed2DGenerator:mapDefinition(entry, index)
  local scale = entry.underwaterScale or 1
  local width = entry.def.width * scale
  local height = entry.def.height * scale
  local blocks = {}
  for by = 0, height - 1 do
    for bx = 0, width - 1 do
      local mask = maskAtBlock(entry, bx, by)
      if mask == 15 then blocks[#blocks + 1] = decorativeBlock(entry, bx, by)
      else blocks[#blocks + 1] = 16 + mask end
    end
  end

  local connections = {}
  for direction, seam in pairs(entry.seams or {}) do
    connections[direction] = {
      map = seam.underwaterMap,
      offset = (tonumber(seam.offset) or 0) * scale,
    }
  end

  return {
    id = entry.underwaterMapId,
    label = safeLabel(entry.id),
    index = 1600 + index,
    tileset = "KD_UNDERWATER",
    width = width,
    height = height,
    borderBlock = 16,
    outdoor = false,
    region = "KANTO_DIVE",
    blocks = blocks,
    connections = connections,
    warps = {}, objects = {}, signs = {},
    kantoDiveSurfaceMap = entry.id,
    kantoDiveBiome = entry.profileName,
    kantoDiveScale = scale,
  }
end

-- ZoneRegistry's historical public API remains 1:1. Generated Full-Kanto
-- links therefore use one link per actual surface-water cell and target the
-- centre of that cell's enlarged underwater footprint. ScaledSurfaceTargets
-- expands the reverse SURFACE map across the whole footprint after registration.
function Seabed2DGenerator:zoneDefinition()
  local zone = {
    requiredBadge = "VOLCANOBADGE",
    links = {}, submergedMaps = {}, generated = true,
  }

  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    local scale = entry.underwaterScale or 1
    local offset = math.floor(scale / 2)
    zone.submergedMaps[#zone.submergedMaps + 1] = entry.underwaterMapId
    for key in pairs(entry.surfaceWater or {}) do
      local x, y = key:match("^(%-?%d+):(%-?%d+)$")
      x, y = tonumber(x), tonumber(y)
      zone.links[#zone.links + 1] = {
        id = string.format("atlas_%s_%d_%d", surfaceId:lower(), x, y),
        surface = { mapId = surfaceId, x = x, y = y },
        underwater = {
          mapId = entry.underwaterMapId,
          x = x * scale + offset,
          y = y * scale + offset,
        },
        width = 1, height = 1,
        kantoDiveScale = scale,
      }
    end
  end

  table.sort(zone.links, function(a, b)
    if a.surface.mapId ~= b.surface.mapId then return a.surface.mapId < b.surface.mapId end
    if a.surface.y ~= b.surface.y then return a.surface.y < b.surface.y end
    return a.surface.x < b.surface.x
  end)
  table.sort(zone.submergedMaps)
  return zone
end

function Seabed2DGenerator:build()
  local generated = { maps = {}, encounters = {}, activeEncounters = {}, zones = {} }

  for index, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    local map = self:mapDefinition(entry, index)
    if not self.mod.content.maps:get(map.id) then self.mod.content.maps:register(map.id, map) end
    if entry.profile and entry.profile.music then
      self.mod.content.map_songs:register(map.id, entry.profile.music)
    end

    local inert, active = encounterFor(entry, self.profileData)
    if not self.mod.content.encounters:get(map.id) then
      self.mod.content.encounters:register(map.id, inert)
    end
    generated.encounters[map.id] = inert
    generated.activeEncounters[map.id] = active
    generated.maps[#generated.maps + 1] = map
  end

  generated.zones.full_kanto_generated = self:zoneDefinition()
  return generated
end

function Seabed2DGenerator:stats(generated)
  return {
    maps = #(generated and generated.maps or {}),
    surfaceWaterCells = self.atlas.stats.surfaceWaterCells or 0,
    seabedCells = self.atlas.stats.seabedCells or 0,
    expandedSeabedCells = self.atlas.stats.expandedSeabedCells or 0,
    maxScale = self.atlas.stats.maxUnderwaterScale or 1,
    seams = self.atlas.stats.seams or 0,
  }
end

return Seabed2DGenerator
