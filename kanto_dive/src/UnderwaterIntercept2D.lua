local Game = require("src.core.Game")

local UnderwaterIntercept2D = {}
UnderwaterIntercept2D.__index = UnderwaterIntercept2D

local CELL = 16
local PLAYER_INSET_X = 2
local PLAYER_INSET_TOP = 3
local PLAYER_INSET_BOTTOM = 1
local SWIMMER_INSET = 2
local PENDING_BATTLE_SECONDS = 4
local POST_BATTLE_REST = 4.0

local function overlap(a0, a1, b0, b1)
  return a0 <= b1 and a1 >= b0
end

local function playerBounds(player)
  local x = tonumber(player and player.px) or ((player and player.cellX or 0) * CELL)
  local y = tonumber(player and player.py) or ((player and player.cellY or 0) * CELL)
  return x + PLAYER_INSET_X,
    y + PLAYER_INSET_TOP,
    x + CELL - PLAYER_INSET_X,
    y + CELL - PLAYER_INSET_BOTTOM
end

local function swimmerBounds(swimmer)
  local scale = math.max(0.1, tonumber(swimmer and swimmer.visualScale) or 1)
  local px = tonumber(swimmer and swimmer.px) or ((swimmer and swimmer.cellX or 0) * CELL)
  local py = tonumber(swimmer and swimmer.py) or ((swimmer and swimmer.cellY or 0) * CELL)

  -- UnderwaterWildlife2D scales each 16x16 Pokemon sprite around its bottom
  -- centre (px + 8, py + 16). Mirror that exact presentation here so a battle
  -- begins when the player's body actually overlaps the visible Pokemon, not
  -- when the player merely enters a generous proximity radius.
  local anchorX = px + CELL / 2
  local anchorY = py + CELL
  local halfWidth = math.max(2, CELL * scale / 2 - SWIMMER_INSET)
  local height = math.max(4, CELL * scale - SWIMMER_INSET)
  return anchorX - halfWidth,
    anchorY - height,
    anchorX + halfWidth,
    anchorY - SWIMMER_INSET
end

local function touching(player, swimmer)
  local pl, pt, pr, pb = playerBounds(player)
  local sl, st, sr, sb = swimmerBounds(swimmer)
  return overlap(pl, pr, sl, sr) and overlap(pt, pb, st, sb)
end

function UnderwaterIntercept2D.new(mod, service, wildlife)
  return setmetatable({
    mod = mod,
    service = service,
    wildlife = wildlife,
    cooldown = 0,
    expectedBattle = 0,
    intercepted = 0,
  }, UnderwaterIntercept2D)
end

function UnderwaterIntercept2D:nearest(player)
  local px = (tonumber(player.px) or player.cellX * CELL) + 8
  local py = (tonumber(player.py) or player.cellY * CELL) + 8
  local best, bestDist2
  for _, swimmer in ipairs(self.wildlife.swimmers or {}) do
    if not swimmer.dead and swimmer.species and touching(player, swimmer) then
      local dx = ((tonumber(swimmer.px) or swimmer.cellX * CELL) + 8) - px
      local dy = ((tonumber(swimmer.py) or swimmer.cellY * CELL) + 8) - py
      local dist2 = dx * dx + dy * dy
      if not bestDist2 or dist2 < bestDist2 then
        best, bestDist2 = swimmer, dist2
      end
    end
  end
  return best
end

function UnderwaterIntercept2D:tryIntercept(game)
  if self.cooldown > 0 or self.expectedBattle > 0 then return false end
  if not (self.service and self.service:isUnderwater()) then return false end
  if not (self.wildlife and self.wildlife:wildsInstalled()) then return false end

  local ow = game and game.overworld
  local player = ow and ow.player
  if not (ow and player) then return false end
  local swimmer = self:nearest(player)
  if not swimmer then return false end

  local species, level = swimmer.species, tonumber(swimmer.level) or 5
  local ok, queued = pcall(function()
    return self.mod.world:queueScript({ { "start_battle", "wild", species, level } })
  end)
  if not ok or queued == false then
    if self.mod.log then self.mod.log:warn("visible underwater battle queue failed: %s", tostring(queued)) end
    return false
  end

  self.wildlife:remove(swimmer, ow)
  self.wildlife.consumed = (self.wildlife.consumed or 0) + 1
  self.intercepted = self.intercepted + 1
  self.cooldown = 1.1
  self.expectedBattle = PENDING_BATTLE_SECONDS

  self.mod.events:emit("mod.kanto_dive.wildlife_intercepted", {
    species = species,
    level = level,
    mapId = ow.map and ow.map.id,
    x = player.cellX,
    y = player.cellY,
  })
  if self.mod.log then
    self.mod.log:info("visible underwater contact intercept: %s Lv%d", tostring(species), level)
  end
  return true
end

function UnderwaterIntercept2D:install()
  local service = self
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    dt = tonumber(dt) or 1 / 60
    service.cooldown = math.max(0, service.cooldown - dt)
    service.expectedBattle = math.max(0, service.expectedBattle - dt)

    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if ow and (not stack or top == ow) then service:tryIntercept(game) end
    return result
  end, 60)

  self.mod.events:on("battle.started", function() service.expectedBattle = 0 end)
  self.mod.events:on("battle.ended", function()
    if service.service and service.service:isUnderwater() then service.cooldown = POST_BATTLE_REST end
    service.expectedBattle = 0
  end)
  self.mod.events:on("mod.kanto_dive.surfaced", function()
    service.cooldown = 0
    service.expectedBattle = 0
  end)
  return true
end

function UnderwaterIntercept2D:stats()
  return {
    intercepted = self.intercepted,
    cooldown = self.cooldown,
    contactOnly = true,
  }
end

return UnderwaterIntercept2D
