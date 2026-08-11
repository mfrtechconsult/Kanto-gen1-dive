local Game = require("src.core.Game")

local UnderwaterIntercept2D = {}
UnderwaterIntercept2D.__index = UnderwaterIntercept2D

local CELL = 16
local INTERCEPT_RADIUS = 2.5 * CELL
local SIZE_RADIUS_BONUS = 9
local PENDING_BATTLE_SECONDS = 4
local POST_BATTLE_REST = 4.0

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
  local px = (player.px or player.cellX * CELL) + 8
  local py = (player.py or player.cellY * CELL) + 8
  local best, bestScore
  for _, swimmer in ipairs(self.wildlife.swimmers or {}) do
    if not swimmer.dead and swimmer.species then
      local scale = tonumber(swimmer.visualScale) or 1
      local radius = INTERCEPT_RADIUS + math.max(0, scale - 1) * SIZE_RADIUS_BONUS
      local dx, dy = (swimmer.px + 8) - px, (swimmer.py + 8) - py
      local dist2 = dx * dx + dy * dy
      if dist2 <= radius * radius then
        local score = dist2 / (radius * radius)
        if not bestScore or score < bestScore then
          best, bestScore = swimmer, score
        end
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
    self.mod.log:info("visible underwater intercept: %s Lv%d", tostring(species), level)
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
    radiusCells = INTERCEPT_RADIUS / CELL,
  }
end

return UnderwaterIntercept2D
