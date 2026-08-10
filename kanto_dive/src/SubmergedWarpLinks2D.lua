local SubmergedWarpLinks2D = {}
SubmergedWarpLinks2D.__index = SubmergedWarpLinks2D

local PORTAL_RADIUS = 3
local PORTAL_COOLDOWN = 1.0

local function key(mapId, x, y)
  return tostring(mapId) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

local function dist2(x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  return dx * dx + dy * dy
end

local function nearestWater(entry, x, y, radius)
  if not (entry and x and y) then return nil end
  local best, bestD2 = nil, math.huge
  local limit = (radius or PORTAL_RADIUS) ^ 2
  for cellKey in pairs(entry.water or {}) do
    local wx, wy = cellKey:match("^(%-?%d+):(%-?%d+)$")
    wx, wy = tonumber(wx), tonumber(wy)
    local d2 = dist2(x, y, wx, wy)
    if d2 <= limit and d2 < bestD2 then
      bestD2 = d2
      best = { x = wx, y = wy }
    end
  end
  return best
end

local function eligible(a, b)
  if not (a and b) then return false end
  if a.profileName == "cave" and b.profileName == "cave" then return true end
  if a.profileName == "harbor" and b.profileName == "harbor" then return true end
  return false
end

local function scaledCenter(entry, cell)
  local scale = entry.underwaterScale or 1
  local offset = math.floor(scale / 2)
  return cell.x * scale + offset, cell.y * scale + offset
end

function SubmergedWarpLinks2D.new(mod, atlas, service)
  local self = setmetatable({
    mod = mod,
    atlas = atlas,
    service = service,
    portals = {},
    count = 0,
    cooldown = 0,
    lastCellKey = nil,
    transitions = 0,
  }, SubmergedWarpLinks2D)
  self:build()
  return self
end

function SubmergedWarpLinks2D:addPortal(sourceEntry, sourceCell, destEntry, destCell, warpIndex)
  local sx, sy = scaledCenter(sourceEntry, sourceCell)
  local dx, dy = scaledCenter(destEntry, destCell)
  local portalKey = key(sourceEntry.underwaterMapId, sx, sy)
  if self.portals[portalKey] then return false end
  self.portals[portalKey] = {
    sourceMap = sourceEntry.underwaterMapId,
    sourceX = sx, sourceY = sy,
    destMap = destEntry.underwaterMapId,
    destX = dx, destY = dy,
    surfaceSource = sourceEntry.id,
    surfaceDest = destEntry.id,
    warpIndex = warpIndex,
  }
  self.count = self.count + 1
  return true
end

function SubmergedWarpLinks2D:build()
  self.portals = {}
  self.count = 0
  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    for warpIndex, warp in ipairs(entry.def.warps or {}) do
      local destEntry = warp.destMap and self.atlas:surface(warp.destMap) or nil
      if destEntry and eligible(entry, destEntry) then
        local destWarp = destEntry.def.warps and destEntry.def.warps[tonumber(warp.destWarp) or -1]
        if destWarp then
          local sourceCell = nearestWater(entry, tonumber(warp.x), tonumber(warp.y), PORTAL_RADIUS)
          local destCell = nearestWater(destEntry, tonumber(destWarp.x), tonumber(destWarp.y), PORTAL_RADIUS)
          if sourceCell and destCell then
            self:addPortal(entry, sourceCell, destEntry, destCell, warpIndex)
          end
        end
      end
    end
  end
  if self.mod.log then self.mod.log:info("Generated %d submerged 2D cave/harbor portals", self.count) end
  return self.count
end

function SubmergedWarpLinks2D:tryPortal(game)
  if self.cooldown > 0 or not (self.service and self.service:isUnderwater()) then return false end
  local ow = game and game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (player and map) then return false end

  local currentKey = key(map.id, player.cellX, player.cellY)
  if self.lastCellKey == currentKey then return false end
  self.lastCellKey = currentKey
  local portal = self.portals[currentKey]
  if not portal then return false end

  self.cooldown = PORTAL_COOLDOWN
  local ok, err = self.mod.world:warpTo(
    portal.destMap, portal.destX, portal.destY, player.facing or "down", {
      onDone = function()
        self.lastCellKey = key(portal.destMap, portal.destX, portal.destY)
        self.transitions = self.transitions + 1
        if self.mod.log then
          self.mod.log:info("submerged 2D portal %s -> %s", portal.surfaceSource, portal.surfaceDest)
        end
      end,
    })
  if not ok then
    self.cooldown = 0
    if self.mod.log then self.mod.log:warn("submerged 2D portal warp failed: %s", tostring(err)) end
    return false
  end
  return true
end

function SubmergedWarpLinks2D:install()
  local service = self
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    service.cooldown = math.max(0, service.cooldown - (tonumber(dt) or 1 / 60))
    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if ow and (not stack or top == ow) then service:tryPortal(game) end
    return result
  end, 55)
  self.mod.events:on("mod.kanto_dive.surfaced", function()
    service.cooldown = 0
    service.lastCellKey = nil
  end)
  return true
end

function SubmergedWarpLinks2D:stats()
  return { portals = self.count, transitions = self.transitions }
end

return SubmergedWarpLinks2D
