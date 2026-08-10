local Game = require("src.core.Game")
local OverworldState = require("src.world.OverworldController")
local Bag = require("src.inventory.Bag")
local Font = require("src.render.Font")

local Salvage2D = {}
Salvage2D.__index = Salvage2D

local SAVE_KEY = "salvageTaken2D"
local SIGNAL_RADIUS = 26
local COLLECT_RADIUS = 13
local CELL = 16

local ITEM_POOLS = {
  ocean = { "NUGGET", "RARE_CANDY", "MAX_REVIVE" },
  coastal = { "NUGGET", "MAX_POTION" },
  harbor = { "NUGGET", "PP_UP", "MAX_POTION" },
  volcanic = { "FULL_RESTORE", "RARE_CANDY", "NUGGET" },
  cave = { "RARE_CANDY", "MAX_REVIVE", "PP_UP" },
  freshwater = { "MAX_POTION", "FULL_HEAL" },
  marsh = { "FULL_HEAL", "MAX_POTION" },
}

local function stableHash(mapId, x, y, salt)
  local value = tonumber(salt) or 0
  local text = tostring(mapId or "")
  for i = 1, #text do value = (value * 33 + text:byte(i)) % 2147483647 end
  return (value + (x + 17) * 73856093 + (y + 29) * 19349663) % 2147483647
end

local function distance(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return math.sqrt(dx * dx + dy * dy)
end

function Salvage2D.new(mod, service, atlas)
  local self = setmetatable({
    mod = mod,
    service = service,
    atlas = atlas,
    definitions = {},
    currentSignal = nil,
  }, Salvage2D)
  self:generate()
  return self
end

function Salvage2D:generate()
  self.definitions = {}
  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    if entry.waterCount >= 36 then
      local desired = math.min(4, math.max(1, math.floor(entry.waterCount / 220) + 1))
      if entry.profileName == "freshwater" or entry.profileName == "marsh" then
        desired = math.min(desired, 2)
      end
      local candidates = {}
      for key in pairs(entry.water) do
        local x, y = key:match("^(%-?%d+):(%-?%d+)$")
        x, y = tonumber(x), tonumber(y)
        candidates[#candidates + 1] = {
          x = x, y = y,
          shore = entry.shoreDistance[key] or 0,
          hash = stableHash(entry.id, x, y, 1701),
        }
      end
      table.sort(candidates, function(a, b)
        if a.shore ~= b.shore then return a.shore > b.shore end
        return a.hash < b.hash
      end)

      local chosen = {}
      for _, c in ipairs(candidates) do
        local clear = c.shore >= 1
        if clear then
          for _, other in ipairs(chosen) do
            local dx, dy = c.x - other.x, c.y - other.y
            if dx * dx + dy * dy < 25 then clear = false break end
          end
        end
        if clear then
          chosen[#chosen + 1] = c
          if #chosen >= desired then break end
        end
      end
      if #chosen == 0 and candidates[1] then chosen[1] = candidates[1] end

      local nodes = {}
      local pool = ITEM_POOLS[entry.profileName] or ITEM_POOLS.coastal
      local scale = entry.underwaterScale or 1
      local offset = math.floor(scale / 2)
      for i, c in ipairs(chosen) do
        local item = pool[((stableHash(entry.id, c.x, c.y, 1901) + i) % #pool) + 1]
        nodes[#nodes + 1] = {
          id = string.format("atlas_salvage_2d_%s_%d", entry.id:lower(), i),
          x = (c.x * scale + offset) * CELL + CELL / 2,
          y = (c.y * scale + offset) * CELL + CELL / 2,
          item = item,
          qty = 1,
          label = entry.profileName == "harbor" and "DEBRIS SIGNAL"
            or entry.profileName == "cave" and "CAVE SIGNAL"
            or entry.profileName == "volcanic" and "THERMAL SIGNAL"
            or "SALVAGE SIGNAL",
        }
      end
      self.definitions[entry.underwaterMapId] = nodes
    end
  end
end

function Salvage2D:takenTable()
  local taken = self.mod.save:get(SAVE_KEY)
  if type(taken) ~= "table" then taken = {} end
  return taken
end

function Salvage2D:isTaken(id) return self:takenTable()[id] == true end

function Salvage2D:markTaken(id)
  local taken = self:takenTable()
  taken[id] = true
  self.mod.save:set(SAVE_KEY, taken)
end

function Salvage2D:nearestSignal()
  if not (self.service and self.service:isUnderwater()) then return nil end
  local ow = Game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (player and map) then return nil end
  local px = (player.px or player.cellX * CELL) + CELL / 2
  local py = (player.py or player.cellY * CELL) + CELL / 2
  local best, bestDistance
  for _, node in ipairs(self.definitions[map.id] or {}) do
    if not self:isTaken(node.id) then
      local d = distance(px, py, node.x, node.y)
      if d <= SIGNAL_RADIUS and (not bestDistance or d < bestDistance) then
        best, bestDistance = node, d
      end
    end
  end
  return best, bestDistance
end

function Salvage2D:showText(text)
  if not (Game.stack and self.mod.ui and self.mod.ui.TextBox) then return end
  Game.stack:push(self.mod.ui.TextBox.new(Game, text))
end

function Salvage2D:itemName(itemId)
  local item = Game.data and Game.data.items and Game.data.items[itemId]
  return item and item.name or itemId
end

function Salvage2D:collect(node)
  if not (node and Game.save and Game.data and Game.data.items and Game.data.items[node.item]) then
    return false
  end
  local qty = tonumber(node.qty) or 1
  if not Bag.add(Game.save, node.item, qty, Game.data) then
    self:showText("No more room for\nthis salvage.")
    return false
  end
  self:markTaken(node.id)
  self:showText("Recovered " .. self:itemName(node.item) .. "!")
  self.mod.events:emit("mod.kanto_dive.salvage", {
    id = node.id, item = node.item, qty = qty,
    mapId = Game.overworld and Game.overworld.map and Game.overworld.map.id,
  })
  return true
end

function Salvage2D:tryInteract()
  local node, d = self:nearestSignal()
  if not node or d > COLLECT_RADIUS then return false end
  return self:collect(node)
end

function Salvage2D:update()
  local node, d = self:nearestSignal()
  self.currentSignal = node and { node = node, distance = d } or nil
end

function Salvage2D:drawHint()
  local signal = self.currentSignal
  if not signal or not (love and love.graphics) then return end
  local message = signal.distance <= COLLECT_RADIUS and "A  SALVAGE"
    or signal.node.label or "SALVAGE SIGNAL"
  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, 1)
  Font.drawBox(1, 6, 18, 4)
  Font.draw(message, math.floor((160 - Font.width(message)) / 2), 56)
  love.graphics.pop()
end

function Salvage2D:install()
  local salvage = self
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if salvage.service:isUnderwater() and ow and (not stack or top == ow) then
      salvage:update()
      if game.input and game.input.wasPressed and game.input:wasPressed("a") then
        salvage:tryInteract()
      end
    else
      salvage.currentSignal = nil
    end
    return result
  end, 90)

  local drawUI = OverworldState.drawUI
  if type(drawUI) == "function" and not OverworldState.__kantoDiveSalvageUiPatched then
    OverworldState.drawUI = function(state, ...)
      local result = drawUI(state, ...)
      if Game.overworld == state then salvage:drawHint() end
      return result
    end
    OverworldState.__kantoDiveSalvageUiPatched = true
  end

  self.mod.events:on("save.created", function() salvage.mod.save:set(SAVE_KEY, {}) end)
  return true
end

function Salvage2D:remaining(mapId)
  local count = 0
  for _, node in ipairs(self.definitions[mapId] or {}) do
    if not self:isTaken(node.id) then count = count + 1 end
  end
  return count
end

return Salvage2D
