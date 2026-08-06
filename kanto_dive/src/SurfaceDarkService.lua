local SurfaceDarkService = {}
SurfaceDarkService.__index = SurfaceDarkService

-- A neutral black tint keeps the animated water visible while shifting every
-- colour mode toward its own darkest shade. It therefore works in monochrome,
-- SGB palettes, RED++ true colour and Tilt without shipping ROM art.
local SHADE_ALPHA = 0.34
local CELL_SIZE = 16

local function key(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function copyCell(cell)
  return {
    mapId = cell.mapId,
    x = cell.x,
    y = cell.y,
    zoneId = cell.zoneId,
    linkId = cell.linkId,
  }
end

local function mapCellIsWater(mod, Map, mapId, x, y)
  local def = mod.content.maps:get(mapId)
  if not def then return false end
  if x < 0 or y < 0 or x >= def.width * 2 or y >= def.height * 2 then
    return false
  end
  local tileset = mod.content.tilesets:get(def.tileset)
  if not tileset then return false end
  if Map and type(Map.defIsWaterCell) == "function" then
    return Map.defIsWaterCell(def, tileset, x, y) == true
  end
  -- The official engine exposes defIsWaterCell. This fallback is only for
  -- lightweight authoring/test harnesses where the map helper is absent.
  return true
end

local function graphicsAvailable()
  return love and love.graphics
    and type(love.graphics.rectangle) == "function"
    and type(love.graphics.setColor) == "function"
end

function SurfaceDarkService.new(mod, registry)
  return setmetatable({
    mod = mod,
    registry = registry,
    byMap = {},
    runsByMap = {},
    lookup = {},
  }, SurfaceDarkService)
end

function SurfaceDarkService:addCell(cell)
  local seen = self.lookup[cell.mapId]
  if not seen then
    seen = {}
    self.lookup[cell.mapId] = seen
  end
  local cellKey = key(cell.x, cell.y)
  if seen[cellKey] then return end
  seen[cellKey] = cell

  local list = self.byMap[cell.mapId]
  if not list then
    list = {}
    self.byMap[cell.mapId] = list
  end
  list[#list + 1] = cell
end

function SurfaceDarkService:build()
  self.byMap = {}
  self.runsByMap = {}
  self.lookup = {}

  local mapLoaded, Map = pcall(require, "src.world.Map")
  if not mapLoaded then Map = nil end

  for _, zone in pairs(self.registry.zones or {}) do
    for _, link in ipairs(zone.links or {}) do
      for _, row in ipairs(link.dive or {}) do
        if mapCellIsWater(self.mod, Map, row.sourceMap, row.sourceX, row.sourceY) then
          self:addCell({
            mapId = row.sourceMap,
            x = row.sourceX,
            y = row.sourceY,
            zoneId = zone.id,
            linkId = row.target and row.target.linkId or link.id,
          })
        end
      end
    end
  end

  for mapId, cells in pairs(self.byMap) do
    table.sort(cells, function(a, b)
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    local runs = {}
    for _, cell in ipairs(cells) do
      local run = runs[#runs]
      if run and run.y == cell.y and run.x + run.width == cell.x then
        run.width = run.width + 1
      else
        runs[#runs + 1] = { x = cell.x, y = cell.y, width = 1 }
      end
    end
    self.runsByMap[mapId] = runs
  end
end

function SurfaceDarkService:cellsFor(mapId)
  local out = {}
  for _, cell in ipairs(self.byMap[mapId] or {}) do
    out[#out + 1] = copyCell(cell)
  end
  return out
end

function SurfaceDarkService:cellAt(mapId, x, y)
  local rows = self.lookup[mapId]
  local cell = rows and rows[key(x, y)]
  return cell and copyCell(cell) or nil
end

function SurfaceDarkService:drawFlat(mapId, camX, camY, viewWidth, viewHeight)
  local runs = self.runsByMap[mapId]
  if not (runs and graphicsAvailable()) then return end

  local floorX = math.floor(camX or 0)
  local floorY = math.floor(camY or 0)
  local vw = viewWidth or math.huge
  local vh = viewHeight or math.huge

  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, SHADE_ALPHA)
  for _, run in ipairs(runs) do
    local x = run.x * CELL_SIZE - floorX
    local y = run.y * CELL_SIZE - floorY
    local width = run.width * CELL_SIZE
    if x + width > 0 and y + CELL_SIZE > 0 and x < vw and y < vh then
      love.graphics.rectangle("fill", x, y, width, CELL_SIZE)
    end
  end
  love.graphics.pop()
end

-- World-pipeline renderers such as Voxel own their terrain, depth buffer and
-- character pass. Drawing a projected translucent polygon through drawFx
-- happens after that scene and creates a screen-space shadow instead of a
-- real material change. Kanto Dive therefore leaves world-pipeline terrain
-- untouched until Gen1Recomp exposes a cell-material hook. DIVE itself and
-- coordinate links remain fully functional in those modes.

local function disableLegacyPipelineProjection()
  local loaded, Pipelines = pcall(require, "src.render.Pipelines")
  if loaded and Pipelines then
    -- Version 1.4.0 wrapped Pipelines.drawWorld and read the active service
    -- through this field. Clearing it makes that wrapper inert after an F5
    -- hot reload; a normal restart loads no wrapper at all.
    Pipelines.__kantoDiveSurfaceDarkService = nil
  end
end

local function installTileRenderer(service)
  local loaded, TileRenderer = pcall(require, "src.render.TileRenderer")
  if not (loaded and TileRenderer) then
    return nil, "src.render.TileRenderer is unavailable"
  end

  TileRenderer.__kantoDiveSurfaceDarkService = service
  if TileRenderer.__kantoDiveSurfaceDarkPatched then return true end

  local originalDrawWindow = TileRenderer.drawWindow
  if type(originalDrawWindow) ~= "function" then
    return nil, "TileRenderer.drawWindow is unavailable"
  end

  TileRenderer.drawWindow = function(renderer, camX, camY, viewWidth, viewHeight)
    originalDrawWindow(renderer, camX, camY, viewWidth, viewHeight)
    local active = TileRenderer.__kantoDiveSurfaceDarkService
    local mapId = renderer and renderer.map and renderer.map.id
    if active and mapId then
      active:drawFlat(mapId, camX, camY, viewWidth, viewHeight)
    end
  end
  TileRenderer.__kantoDiveSurfaceDarkPatched = true
  return true
end

function SurfaceDarkService:install()
  self:build()
  disableLegacyPipelineProjection()

  local ok, err = installTileRenderer(self)
  if not ok then
    self.mod.log:error("Could not install surface DIVE tint in 2D: %s", tostring(err))
    return nil
  end

  local total = 0
  for _, cells in pairs(self.byMap) do total = total + #cells end
  self.mod.log:info("Installed 2D/Tilt dark-water tint on %d surface DIVE cells", total)
  return true
end

return SurfaceDarkService
