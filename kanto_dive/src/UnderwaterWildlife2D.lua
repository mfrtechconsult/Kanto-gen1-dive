local Game = require("src.core.Game")

local UnderwaterWildlife2D = {}
UnderwaterWildlife2D.__index = UnderwaterWildlife2D

local CELL = 16
local SPAWN_MIN_CELLS = 5
local SPAWN_MAX_CELLS = 16
local DESPAWN_CELLS = 27
local PLAYER_FLEE_PIXELS = 48
local CAP = 18

local function rand01()
  if love and love.math and love.math.random then return love.math.random() end
  return math.random()
end

local function randRange(a, b) return a + (b - a) * rand01() end

local function randInt(a, b)
  a, b = math.floor(a), math.floor(b)
  if b <= a then return a end
  if love and love.math and love.math.random then return love.math.random(a, b) end
  return math.random(a, b)
end

local function clamp(value, lo, hi) return math.max(lo, math.min(hi, value)) end

local function removeValue(list, value)
  for i = #(list or {}), 1, -1 do
    if list[i] == value then table.remove(list, i) end
  end
end

local function facingFor(vx, vy, previous)
  local ax, ay = math.abs(vx or 0), math.abs(vy or 0)
  if ax < 0.01 and ay < 0.01 then return previous or "right" end
  if ax >= ay then return vx < 0 and "left" or "right" end
  return vy < 0 and "up" or "down"
end

local function shortestTurn(current, wanted)
  return (wanted - current + math.pi) % (math.pi * 2) - math.pi
end

local function dexHeightFeet(species)
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[species]
  local dex = def and def.dexEntry or nil
  if not dex then return 2 end
  local feet = (tonumber(dex.heightFt) or 0) + (tonumber(dex.heightIn) or 0) / 12
  return feet > 0 and feet or 2
end

local function speciesVisualScale(species)
  local feet = math.max(0.5, dexHeightFeet(species))
  return clamp(0.78 + 0.38 * math.sqrt(feet), 0.85, 2.40)
end

local function speciesSpeedScale(species)
  local feet = dexHeightFeet(species)
  return clamp(0.92 + feet * 0.025, 0.92, 1.35)
end

local function baseLevel(profileName)
  return profileName == "marsh" and 16
    or profileName == "freshwater" and 18
    or profileName == "harbor" and 20
    or profileName == "cave" and 27
    or profileName == "volcanic" and 29
    or profileName == "ocean" and 25
    or 21
end

function UnderwaterWildlife2D.new(mod, service, registry, atlas, sprites, profileData)
  return setmetatable({
    mod = mod,
    service = service,
    registry = registry,
    atlas = atlas,
    sprites = sprites,
    profileData = profileData or {},
    swimmers = {},
    serial = 0,
    cooldown = 0,
    mapId = nil,
    spawned = 0,
    consumed = 0,
  }, UnderwaterWildlife2D)
end

function UnderwaterWildlife2D:wildsInstalled()
  if self.mod and self.mod.find then
    local ok, handle = pcall(self.mod.find, self.mod, "overworld_wild_spawns")
    if ok and handle then return true end
  end
  local exports = Game and Game.mods and Game.mods.exports
  return exports and exports.overworld_wild_spawns ~= nil or false
end

function UnderwaterWildlife2D:enabled()
  return self:wildsInstalled() and self.service and self.service:isUnderwater()
end

function UnderwaterWildlife2D:remove(swimmer, overworld)
  if not swimmer then return end
  swimmer.dead = true
  overworld = overworld or Game.overworld
  if overworld and overworld.entities then removeValue(overworld.entities, swimmer) end
  removeValue(self.swimmers, swimmer)
end

function UnderwaterWildlife2D:clear()
  local ow = Game.overworld
  for i = #self.swimmers, 1, -1 do
    local swimmer = self.swimmers[i]
    swimmer.dead = true
    if ow and ow.entities then removeValue(ow.entities, swimmer) end
    table.remove(self.swimmers, i)
  end
  self.mapId = nil
  self.cooldown = 0
end

function UnderwaterWildlife2D:bandFor(mapId, x, y)
  local entry = self.atlas:underwater(mapId)
  if not entry then return nil end
  local shore = self.atlas:shoreDistanceAtUnderwater(mapId, x, y) or 0
  local bandName = shore <= 1 and "shallow" or shore <= 4 and "mid" or "deep"
  local ecologyName = entry.profile.ecology or entry.profileName or "ocean"
  local ecology = self.profileData.ecology and self.profileData.ecology[ecologyName]
  if not ecology then ecology = self.profileData.ecology and self.profileData.ecology.ocean end
  return entry, bandName, ecology and ecology[bandName] or nil, shore
end

function UnderwaterWildlife2D:pick(mapId, x, y)
  local entry, bandName, speciesList = self:bandFor(mapId, x, y)
  if not (entry and speciesList and #speciesList > 0) then return nil end

  if #self.swimmers > 0 and rand01() < 0.40 then
    local leader = self.swimmers[randInt(1, #self.swimmers)]
    if leader and not leader.dead then
      for _, species in ipairs(speciesList) do
        if species == leader.species then
          local offset = bandName == "deep" and 6 or bandName == "mid" and 3 or 0
          return { species = species, level = baseLevel(entry.profileName) + offset + randInt(0, 2) }, leader
        end
      end
    end
  end

  local species = speciesList[randInt(1, #speciesList)]
  local offset = bandName == "deep" and 6 or bandName == "mid" and 3 or 0
  return { species = species, level = baseLevel(entry.profileName) + offset + randInt(0, 2) }, nil
end

function UnderwaterWildlife2D:spawnPosition(mapId, player, leader)
  for _ = 1, 40 do
    local cellX, cellY
    if leader and not leader.dead and rand01() < 0.70 then
      cellX = leader.cellX + randInt(-3, 3)
      cellY = leader.cellY + randInt(-3, 3)
    else
      local angle = randRange(0, math.pi * 2)
      local radius = randRange(SPAWN_MIN_CELLS, SPAWN_MAX_CELLS)
      cellX = math.floor(player.cellX + math.cos(angle) * radius + 0.5)
      cellY = math.floor(player.cellY + math.sin(angle) * radius + 0.5)
    end
    if self.atlas:isUnderwaterCell(mapId, cellX, cellY) then
      return cellX * CELL + randRange(2, CELL - 2),
        cellY * CELL + randRange(2, CELL - 2)
    end
  end
  return nil
end

function UnderwaterWildlife2D:makeEntity(pick, sprite, px, py)
  self.serial = self.serial + 1
  local visualScale = speciesVisualScale(pick.species)
  local swimmer = {
    id = "kanto_dive_wildlife_" .. tostring(self.serial),
    kantoDiveWildlife = true,
    passable = true,
    species = pick.species,
    level = pick.level,
    sprite = sprite,
    px = px,
    py = py,
    cellX = math.floor(px / CELL),
    cellY = math.floor(py / CELL),
    heading = randRange(0, math.pi * 2),
    visualScale = visualScale,
    speed = randRange(15, 27) * speciesSpeedScale(pick.species),
    t = randRange(0, 8),
    turnTimer = randRange(0.6, 2.2),
    facing = "right",
    dead = false,
  }

  function swimmer:phase()
    return math.floor((self.t or 0) * 4.5) % 2
  end

  function swimmer:pose()
    return self.sprite, self.px, self.py, self.facing, self:phase(), false, false
  end

  function swimmer:draw(camX, camY)
    if not (self.sprite and self.sprite.draw) then return end
    local scale = tonumber(self.visualScale) or 1
    if love and love.graphics and scale ~= 1 then
      local anchorX = self.px + 8 - (camX or 0)
      local anchorY = self.py + 16 - (camY or 0)
      love.graphics.push()
      love.graphics.translate(anchorX, anchorY)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-anchorX, -anchorY)
      self.sprite:draw(self.px, self.py, camX, camY, self.facing, self:phase(), false)
      love.graphics.pop()
      return
    end
    self.sprite:draw(self.px, self.py, camX, camY, self.facing, self:phase(), false)
  end

  return swimmer
end

function UnderwaterWildlife2D:spawn()
  local ow = Game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (self:enabled() and player and map and self.atlas:underwater(map.id)) then return false end

  local pick, leader = self:pick(map.id, player.cellX, player.cellY)
  if not pick then return false end
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[pick.species]
  local dex = def and tonumber(def.dex)
  if not dex then return false end
  local sprite = self.sprites and self.sprites:build(pick.species, dex) or nil
  if not sprite then return false end

  local px, py = self:spawnPosition(map.id, player, leader)
  if not px then return false end
  local swimmer = self:makeEntity(pick, sprite, px, py)
  self.swimmers[#self.swimmers + 1] = swimmer
  ow.entities = ow.entities or {}
  ow.entities[#ow.entities + 1] = swimmer
  self.spawned = self.spawned + 1
  return true
end

function UnderwaterWildlife2D:steer(swimmer, wanted, maxTurn)
  local diff = shortestTurn(swimmer.heading, wanted)
  diff = clamp(diff, -maxTurn, maxTurn)
  swimmer.heading = swimmer.heading + diff
end

function UnderwaterWildlife2D:tickSwimmer(swimmer, dt, mapId, player)
  swimmer.t = swimmer.t + dt
  swimmer.turnTimer = swimmer.turnTimer - dt

  local playerX = (player.px or player.cellX * CELL) + 8
  local playerY = (player.py or player.cellY * CELL) + 8
  local dxPlayer, dyPlayer = swimmer.px - playerX, swimmer.py - playerY
  local playerDistance = math.sqrt(dxPlayer * dxPlayer + dyPlayer * dyPlayer)
  local speedBoost = 1

  if playerDistance < PLAYER_FLEE_PIXELS and playerDistance > 0.1 then
    self:steer(swimmer, math.atan2(dyPlayer, dxPlayer), math.rad(145) * dt)
    speedBoost = 1.30
  elseif swimmer.turnTimer <= 0 then
    swimmer.turnTimer = randRange(0.7, 2.2)
    swimmer.heading = swimmer.heading + randRange(-0.75, 0.75)
  end

  local avgSin, avgCos, peers = 0, 0, 0
  for _, other in ipairs(self.swimmers) do
    if other ~= swimmer and not other.dead and other.species == swimmer.species then
      local dx, dy = other.px - swimmer.px, other.py - swimmer.py
      if math.abs(dx) + math.abs(dy) < 110 then
        avgSin = avgSin + math.sin(other.heading)
        avgCos = avgCos + math.cos(other.heading)
        peers = peers + 1
      end
    end
  end
  if peers > 0 then self:steer(swimmer, math.atan2(avgSin, avgCos), math.rad(24) * dt) end

  local step = swimmer.speed * speedBoost * dt
  local nx = swimmer.px + math.cos(swimmer.heading) * step
  local ny = swimmer.py + math.sin(swimmer.heading) * step
  local cellX = math.floor((nx + CELL / 2) / CELL)
  local cellY = math.floor((ny + CELL / 2) / CELL)

  if self.atlas:isUnderwaterCell(mapId, cellX, cellY) then
    swimmer.px, swimmer.py = nx, ny
    swimmer.cellX, swimmer.cellY = cellX, cellY
    swimmer.facing = facingFor(math.cos(swimmer.heading), math.sin(swimmer.heading), swimmer.facing)
  else
    swimmer.heading = swimmer.heading + math.pi + randRange(-0.35, 0.35)
    swimmer.turnTimer = randRange(0.4, 1.1)
  end
end

function UnderwaterWildlife2D:update(dt)
  dt = tonumber(dt) or 1 / 60
  local ow = Game.overworld
  local map = ow and ow.map
  local player = ow and ow.player
  if not (self:enabled() and map and player and self.atlas:underwater(map.id)) then
    if #self.swimmers > 0 then self:clear() end
    return
  end

  if self.mapId ~= map.id then
    self:clear()
    self.mapId = map.id
  end

  for i = #self.swimmers, 1, -1 do
    local swimmer = self.swimmers[i]
    local dx, dy = swimmer.cellX - player.cellX, swimmer.cellY - player.cellY
    if swimmer.dead or dx * dx + dy * dy > DESPAWN_CELLS * DESPAWN_CELLS then
      self:remove(swimmer, ow)
    else
      self:tickSwimmer(swimmer, dt, map.id, player)
    end
  end

  self.cooldown = math.max(0, self.cooldown - dt)
  if #self.swimmers < CAP and self.cooldown <= 0 then
    if self:spawn() then self.cooldown = 0.65 else self.cooldown = 1.1 end
  end
end

function UnderwaterWildlife2D:install()
  local service = self
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if ow and (not stack or top == ow) then service:update(dt) end
    return result
  end, 70)

  self.mod.events:on("map.exited", function() service:clear() end)
  self.mod.events:on("save.created", function() service:clear() end)
  return true
end

function UnderwaterWildlife2D:stats()
  return {
    enabled = self:enabled(),
    visible = #self.swimmers,
    spawned = self.spawned,
    consumed = self.consumed,
  }
end

return UnderwaterWildlife2D
