local ZoneRegistry = {}
ZoneRegistry.__index = ZoneRegistry

local MODE_DIVE = 1
local MODE_SURFACE = 2
local MODE_BOTH = MODE_DIVE + MODE_SURFACE

local function listToSet(list)
  local out = {}
  for _, value in ipairs(list or {}) do out[value] = true end
  return out
end

local function copyPoint(point)
  if not point then return nil end
  return {
    mapId = point.mapId,
    x = point.x,
    y = point.y,
    facing = point.facing or "same",
    zoneId = point.zoneId,
    linkId = point.linkId,
  }
end

local function validInteger(value)
  return type(value) == "number" and value % 1 == 0
end

local function validPoint(point)
  return type(point) == "table"
    and type(point.mapId) == "string"
    and validInteger(point.x)
    and validInteger(point.y)
end

local function key(x, y)
  return y * 100000 + x
end

local function modeBits(value)
  if value == nil or value == "both" or value == "B" or value == "X"
      or value == "*" or value == 1 then
    return MODE_BOTH
  elseif value == "dive" or value == "D" or value == "surface" or value == "S" then
    return nil
  elseif value == "none" or value == "." or value == " " or value == 0 then
    return 0
  end
  return nil
end

local function mapSize(mod, mapId)
  local def = mod.content.maps:get(mapId)
  if not def then return nil end
  return def, def.width * 2, def.height * 2
end

local function normalizedEndpoint(link, field, legacyMapField, legacyXField, legacyYField)
  local point = link[field]
  if point == nil and link[legacyMapField] then
    point = {
      mapId = link[legacyMapField],
      x = link[legacyXField] or 0,
      y = link[legacyYField] or 0,
    }
  end
  if type(point) ~= "table" then return nil end
  return {
    mapId = point.mapId,
    x = point.x or 0,
    y = point.y or 0,
  }
end

local function addMode(cells, x, y, bits)
  if bits == 0 then return end
  local cellKey = key(x, y)
  local current = cells[cellKey] or 0
  local hasDive = current % 2 == 1
  local hasSurface = current >= MODE_SURFACE
  if bits % 2 == 1 then hasDive = true end
  if bits >= MODE_SURFACE then hasSurface = true end
  cells[cellKey] = (hasDive and MODE_DIVE or 0)
    + (hasSurface and MODE_SURFACE or 0)
end

local function applyArea(cells, area, linkWidth, linkHeight, where)
  if type(area) ~= "table" then return nil, where .. " must be a table" end
  local x, y = area.x or 0, area.y or 0
  local width = area.width or area.w
  local height = area.height or area.h
  if not (validInteger(x) and validInteger(y) and validInteger(width)
      and validInteger(height) and width > 0 and height > 0) then
    return nil, where .. " needs integer x, y, width and height"
  end
  if x < 0 or y < 0 or x + width > linkWidth or y + height > linkHeight then
    return nil, where .. " lies outside the link rectangle"
  end
  local bits = modeBits(area.mode)
  if bits == nil then return nil, where .. ": one-way modes are not supported; expected bidirectional marker, got " .. tostring(area.mode) end
  for cy = y, y + height - 1 do
    for cx = x, x + width - 1 do addMode(cells, cx, cy, bits) end
  end
  return true
end

local function applyMask(cells, mask, linkWidth, linkHeight, where)
  if type(mask) == "table" and mask.rows == nil and type(mask[1]) == "string" then
    mask = { rows = mask }
  end
  if type(mask) ~= "table" or type(mask.rows) ~= "table" then
    return nil, where .. " must contain rows"
  end
  local offsetX, offsetY = mask.x or 0, mask.y or 0
  if not (validInteger(offsetX) and validInteger(offsetY)) then
    return nil, where .. " x/y must be integers"
  end
  for rowIndex, row in ipairs(mask.rows) do
    if type(row) ~= "string" then
      return nil, ("%s.rows[%d] must be a string"):format(where, rowIndex)
    end
    local cy = offsetY + rowIndex - 1
    for column = 1, #row do
      local cx = offsetX + column - 1
      local bits = modeBits(row:sub(column, column))
      if bits == nil then
        return nil, ("%s.rows[%d] contains unknown marker %q")
          :format(where, rowIndex, row:sub(column, column))
      end
      if bits ~= 0 then
        if cx < 0 or cy < 0 or cx >= linkWidth or cy >= linkHeight then
          return nil, where .. " marks a cell outside the link rectangle"
        end
        addMode(cells, cx, cy, bits)
      end
    end
  end
  return true
end

local function compileLink(mod, zoneId, link, index)
  if type(link) ~= "table" then
    return nil, ("%s: links[%d] must be a table"):format(zoneId, index)
  end
  local surface = normalizedEndpoint(link, "surface", "surfaceMap", "surfaceX", "surfaceY")
  local underwater = normalizedEndpoint(link, "underwater", "underwaterMap",
    "underwaterX", "underwaterY")
  if not validPoint(surface) then
    return nil, ("%s: links[%d].surface needs mapId, x and y"):format(zoneId, index)
  end
  if not validPoint(underwater) then
    return nil, ("%s: links[%d].underwater needs mapId, x and y"):format(zoneId, index)
  end

  local _, surfaceMapWidth, surfaceMapHeight = mapSize(mod, surface.mapId)
  if not surfaceMapWidth then
    return nil, zoneId .. ": unknown surface map " .. surface.mapId
  end
  local _, underwaterMapWidth, underwaterMapHeight = mapSize(mod, underwater.mapId)
  if not underwaterMapWidth then
    return nil, zoneId .. ": unknown underwater map " .. underwater.mapId
  end

  local width = link.width or math.min(surfaceMapWidth - surface.x,
    underwaterMapWidth - underwater.x)
  local height = link.height or math.min(surfaceMapHeight - surface.y,
    underwaterMapHeight - underwater.y)
  if not (validInteger(width) and validInteger(height) and width > 0 and height > 0) then
    return nil, ("%s: links[%d] needs positive integer width/height")
      :format(zoneId, index)
  end
  if surface.x < 0 or surface.y < 0
      or surface.x + width > surfaceMapWidth
      or surface.y + height > surfaceMapHeight then
    return nil, ("%s: links[%d] exceeds surface map bounds"):format(zoneId, index)
  end
  if underwater.x < 0 or underwater.y < 0
      or underwater.x + width > underwaterMapWidth
      or underwater.y + height > underwaterMapHeight then
    return nil, ("%s: links[%d] exceeds underwater map bounds"):format(zoneId, index)
  end

  local cells = {}
  local hasSelectors = type(link.areas) == "table"
    or link.mask ~= nil or type(link.masks) == "table"
  if not hasSelectors then
    for cy = 0, height - 1 do
      for cx = 0, width - 1 do addMode(cells, cx, cy, MODE_BOTH) end
    end
  end

  for areaIndex, area in ipairs(link.areas or {}) do
    local ok, err = applyArea(cells, area, width, height,
      ("%s.links[%d].areas[%d]"):format(zoneId, index, areaIndex))
    if not ok then return nil, err end
  end
  if link.mask ~= nil then
    local ok, err = applyMask(cells, link.mask, width, height,
      ("%s.links[%d].mask"):format(zoneId, index))
    if not ok then return nil, err end
  end
  for maskIndex, mask in ipairs(link.masks or {}) do
    local ok, err = applyMask(cells, mask, width, height,
      ("%s.links[%d].masks[%d]"):format(zoneId, index, maskIndex))
    if not ok then return nil, err end
  end
  if next(cells) == nil then
    return nil, ("%s: links[%d] does not expose any DIVE or SURFACE cell")
      :format(zoneId, index)
  end

  local diveFacing = link.diveFacing or "same"
  local surfaceFacing = link.surfaceFacing or "same"
  local linkId = link.id or (zoneId .. "_" .. index)
  local compiled = {
    id = linkId,
    surface = surface,
    underwater = underwater,
    width = width,
    height = height,
    dive = {},
    surfaceRows = {},
  }

  for localKey, bits in pairs(cells) do
    local cy = math.floor(localKey / 100000)
    local cx = localKey - cy * 100000
    local surfaceX, surfaceY = surface.x + cx, surface.y + cy
    local underwaterX, underwaterY = underwater.x + cx, underwater.y + cy
    if bits % 2 == 1 then
      compiled.dive[#compiled.dive + 1] = {
        sourceMap = surface.mapId,
        sourceX = surfaceX,
        sourceY = surfaceY,
        target = {
          mapId = underwater.mapId,
          x = underwaterX,
          y = underwaterY,
          facing = diveFacing,
          zoneId = zoneId,
          linkId = linkId,
        },
      }
    end
    if bits >= MODE_SURFACE then
      compiled.surfaceRows[#compiled.surfaceRows + 1] = {
        sourceMap = underwater.mapId,
        sourceX = underwaterX,
        sourceY = underwaterY,
        target = {
          mapId = surface.mapId,
          x = surfaceX,
          y = surfaceY,
          facing = surfaceFacing,
          zoneId = zoneId,
          linkId = linkId,
        },
      }
    end
  end
  return compiled
end

function ZoneRegistry.new(mod)
  return setmetatable({
    mod = mod,
    zones = {},
    bySurfaceMap = {},
    bySubmergedMap = {},
    diveTargets = {},
    surfaceTargets = {},
    legacyBySurfaceMap = {},
  }, ZoneRegistry)
end

function ZoneRegistry:register(id, definition, owner)
  owner = owner or self.mod.id
  if type(id) ~= "string" or id == "" then
    return nil, "zone id must be a non-empty string"
  end
  if self.zones[id] then return nil, "duplicate zone id: " .. id end
  if type(definition) ~= "table" then return nil, "zone must be a table" end
  if type(definition.requiredBadge) ~= "string" then
    return nil, id .. ": requiredBadge must be an item id"
  end

  local zone = {
    id = id,
    owner = owner,
    requiredBadge = definition.requiredBadge,
    links = {},
    surfaceMaps = {},
    submergedMaps = listToSet(definition.submergedMaps),
    surfacingMaps = {},
    landingPoints = {},
  }
  local stagedDive, stagedSurface = {}, {}

  if type(definition.links) == "table" and #definition.links > 0 then
    for linkIndex, link in ipairs(definition.links) do
      local compiled, err = compileLink(self.mod, id, link, linkIndex)
      if not compiled then return nil, err end
      zone.links[#zone.links + 1] = compiled
      zone.surfaceMaps[compiled.surface.mapId] = true
      zone.submergedMaps[compiled.underwater.mapId] = true
      if #compiled.surfaceRows > 0 then
        zone.surfacingMaps[compiled.underwater.mapId] = true
      end
      for _, row in ipairs(compiled.dive) do stagedDive[#stagedDive + 1] = row end
      for _, row in ipairs(compiled.surfaceRows) do stagedSurface[#stagedSurface + 1] = row end
    end
  else
    -- Backward-compatible 1.0 zone shape. It remains useful for third-party
    -- mods, but new content should use coordinate links so movement below the
    -- surface can emerge at a different mapped cell.
    local surfaceMaps = definition.surfaceMaps
    local sourcePoints = definition.landingPoints
    if sourcePoints == nil and definition.entry ~= nil then sourcePoints = { definition.entry } end
    if type(surfaceMaps) ~= "table" or #surfaceMaps == 0 then
      return nil, id .. ": links or surfaceMaps must not be empty"
    end
    if type(sourcePoints) ~= "table" or #sourcePoints == 0 then
      return nil, id .. ": legacy landingPoints must not be empty"
    end
    for _, mapId in ipairs(surfaceMaps) do
      if not self.mod.content.maps:get(mapId) then
        return nil, id .. ": unknown surface map " .. tostring(mapId)
      end
      zone.surfaceMaps[mapId] = true
    end
    for index, point in ipairs(sourcePoints) do
      if not validPoint(point) then
        return nil, ("%s: landingPoints[%d] must contain mapId, integer x and y")
          :format(id, index)
      end
      if not self.mod.content.maps:get(point.mapId) then
        return nil, id .. ": unknown landing map " .. point.mapId
      end
      zone.submergedMaps[point.mapId] = true
      zone.surfacingMaps[point.mapId] = true
      zone.landingPoints[#zone.landingPoints + 1] = copyPoint(point)
    end
    for mapId in pairs(zone.surfaceMaps) do
      if self.legacyBySurfaceMap[mapId] then
        return nil, id .. ": legacy surface map already owned by "
          .. self.legacyBySurfaceMap[mapId].id
      end
    end
  end

  for mapId in pairs(zone.submergedMaps) do
    if not self.mod.content.maps:get(mapId) then
      return nil, id .. ": unknown submerged map " .. mapId
    end
    local existing = self.bySubmergedMap[mapId]
    if existing and existing.id ~= id then
      return nil, id .. ": submerged map already owned by " .. existing.id
    end
  end

  for _, row in ipairs(stagedDive) do
    local mapRows = self.diveTargets[row.sourceMap]
    local existing = mapRows and mapRows[key(row.sourceX, row.sourceY)]
    if existing then
      return nil, ("%s: DIVE cell %s (%d,%d) already belongs to %s")
        :format(id, row.sourceMap, row.sourceX, row.sourceY, existing.zoneId)
    end
  end
  for _, row in ipairs(stagedSurface) do
    local mapRows = self.surfaceTargets[row.sourceMap]
    local existing = mapRows and mapRows[key(row.sourceX, row.sourceY)]
    if existing then
      return nil, ("%s: SURFACE cell %s (%d,%d) already belongs to %s")
        :format(id, row.sourceMap, row.sourceX, row.sourceY, existing.zoneId)
    end
  end

  self.zones[id] = zone
  for mapId in pairs(zone.surfaceMaps) do
    self.bySurfaceMap[mapId] = self.bySurfaceMap[mapId] or {}
    self.bySurfaceMap[mapId][#self.bySurfaceMap[mapId] + 1] = zone
    if #zone.landingPoints > 0 then self.legacyBySurfaceMap[mapId] = zone end
  end
  for mapId in pairs(zone.submergedMaps) do self.bySubmergedMap[mapId] = zone end
  for _, row in ipairs(stagedDive) do
    self.diveTargets[row.sourceMap] = self.diveTargets[row.sourceMap] or {}
    self.diveTargets[row.sourceMap][key(row.sourceX, row.sourceY)] = row.target
  end
  for _, row in ipairs(stagedSurface) do
    self.surfaceTargets[row.sourceMap] = self.surfaceTargets[row.sourceMap] or {}
    self.surfaceTargets[row.sourceMap][key(row.sourceX, row.sourceY)] = row.target
  end
  return zone
end

function ZoneRegistry:landingFor(zone, surfaceX, surfaceY)
  if not (zone and zone.landingPoints and #zone.landingPoints > 0) then return nil end
  local x = tonumber(surfaceX) or 0
  local y = tonumber(surfaceY) or 0
  local index = ((x * 31 + y * 17) % #zone.landingPoints) + 1
  return copyPoint(zone.landingPoints[index])
end

function ZoneRegistry:diveTarget(mapId, x, y)
  local rows = self.diveTargets[mapId]
  local target = rows and rows[key(x, y)]
  if target then return copyPoint(target), self.zones[target.zoneId] end
  local legacy = self.legacyBySurfaceMap[mapId]
  if legacy then return self:landingFor(legacy, x, y), legacy end
  return nil
end

function ZoneRegistry:surfaceTarget(mapId, x, y)
  local rows = self.surfaceTargets[mapId]
  local target = rows and rows[key(x, y)]
  if target then return copyPoint(target), self.zones[target.zoneId] end
  return nil
end

function ZoneRegistry:surfaceZone(mapId)
  local zones = self.bySurfaceMap[mapId]
  return zones and zones[1] or nil
end

function ZoneRegistry:submergedZone(mapId)
  return self.bySubmergedMap[mapId]
end

function ZoneRegistry:get(id)
  return self.zones[id]
end

return ZoneRegistry
