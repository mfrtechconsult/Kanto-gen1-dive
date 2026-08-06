local DiveService = {}
DiveService.__index = DiveService

local SESSION_KEY = "underwaterSession"

local function mapContains(set, mapId)
  return set and set[mapId] == true
end

local function targetFacing(target, fallback)
  if not target or target.facing == nil or target.facing == "same" then
    return fallback or "down"
  end
  return target.facing
end

function DiveService.new(mod, registry)
  return setmetatable({ mod = mod, registry = registry }, DiveService)
end

function DiveService:getSession()
  return self.mod.save:get(SESSION_KEY)
end

function DiveService:setSession(value)
  self.mod.save:set(SESSION_KEY, value)
end

function DiveService:knowsDive(mon)
  for _, move in ipairs(mon and mon.moves or {}) do
    if move.id == "DIVE" then return true end
  end
  return false
end

function DiveService:current(game)
  local ow = game and game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (player and map) then return nil end
  return {
    mapId = map.id,
    x = player.cellX,
    y = player.cellY,
    facing = player.facing or "down",
    surfing = player.surfing == true,
  }
end

function DiveService:hasBadge(game, badge)
  local inventory = game and game.save and game.save.inventory
  return inventory and inventory[badge] ~= nil and inventory[badge] ~= false
end

-- Link rectangles may intentionally cover coastline for easy authoring. DIVE
-- is already gated by the live Surf state; SURFACE additionally verifies that
-- the paired overworld cell is actually water, so an underwater traveler can
-- never emerge onto an island or beach hidden inside a broad mask.
function DiveService:surfaceTargetIsWater(game, target)
  if not (game and game.data and target) then return false end
  local loaded, Map = pcall(require, "src.world.Map")
  if not (loaded and Map and type(Map.defIsWaterCell) == "function") then
    return true -- test harness / older compatible engine: keep the link usable
  end
  local def = game.data.maps and game.data.maps[target.mapId]
  local tileset = def and game.data.tilesets and game.data.tilesets[def.tileset]
  return def ~= nil and tileset ~= nil
    and Map.defIsWaterCell(def, tileset, target.x, target.y) == true
end

function DiveService:closePartyMenu(game)
  local stack = game and game.stack
  local top = stack and stack.top and stack:top()
  if top and type(top.close) == "function" then
    top:close()
  elseif top and stack and stack.pop then
    stack:pop()
  end
end

-- `enabled` controls the music override, not the sprite. Underwater movement
-- deliberately keeps player.surfing=true so the Surf mount, bobbing and water
-- collision continue seamlessly, while the map's own underwater song plays.
function DiveService:refreshMovementPresentation(game, surfMusic)
  local ow = game and game.overworld
  if ow and type(ow.syncSurfingPikachu) == "function" then
    local ok, err = pcall(ow.syncSurfingPikachu, ow)
    if not ok then
      self.mod.log:warn("Could not refresh the Surf sprite: %s", tostring(err))
    end
  end

  local loaded, Music = pcall(require, "src.core.Music")
  if not (loaded and Music and game and game.data) then return end
  local mapId = ow and ow.map and ow.map.id
  if mapId and type(Music.playMap) == "function" then
    Music.playMap(game.data, mapId, false, surfMusic and true or false)
  elseif type(Music.setSurfing) == "function" then
    Music.setSurfing(game.data, surfMusic and true or false)
  end
end

function DiveService:setSurfing(game, enabled, refreshPresentation, surfMusic)
  local save = game and game.save
  local ow = game and game.overworld
  if save then
    save.onBike = false
    save.forcedBike = nil
    if save.player then save.player.surfing = enabled and true or false end
  end
  if ow and ow.player then ow.player.surfing = enabled and true or false end
  if refreshPresentation then
    self:refreshMovementPresentation(game,
      surfMusic == nil and enabled or surfMusic)
  end
end

function DiveService:displayName(game, mon)
  if mon and mon.nickname and mon.nickname ~= "" then return mon.nickname end
  local species = mon and game and game.data and game.data.pokemon
    and game.data.pokemon[mon.species]
  return species and species.name or "POKEMON"
end

function DiveService:showText(game, text, onDone)
  if not (game and game.stack and self.mod.ui and self.mod.ui.TextBox) then
    if onDone then onDone() end
    return
  end
  game.stack:push(self.mod.ui.TextBox.new(game, text, onDone))
end

function DiveService:recover(game, menu)
  self:closePartyMenu(game)
  local heal = game and game.save and game.save.lastHeal
  if not (heal and heal.map and heal.x and heal.y) then
    self.mod.log:error("Cannot recover an orphaned dive session: no healing point is available")
    return
  end
  self:showText(game,
    "The surface record is\nlost. Returning to\nthe last healing point.",
    function()
      self:setSurfing(game, false, false)
      local ok, err = self.mod.world:warpTo(heal.map, heal.x, heal.y,
        heal.facing or "down", { onDone = function()
          self:setSession(nil)
          self:refreshMovementPresentation(game, false)
        end })
      if not ok then
        self:setSurfing(game, false, true, false)
        self.mod.log:error("Dive recovery warp failed: %s", tostring(err))
      end
    end)
end

function DiveService:beginDive(mon, game, menu, zone, position, target)
  self:closePartyMenu(game)
  local name = self:displayName(game, mon)
  self:showText(game, name .. " used DIVE!", function()
    if not target then
      self.mod.log:error("DIVE has no coordinate link for zone %s", tostring(zone.id))
      return
    end
    self:setSession({
      active = true,
      zoneId = zone.id,
      linkId = target.linkId,
      initialSurfaceOrigin = {
        mapId = position.mapId,
        x = position.x,
        y = position.y,
        facing = position.facing,
      },
    })
    -- Keep the Surf mount active across the warp. The underwater tileset is
    -- water-collision-only, so the engine never auto-dismounts on the floor.
    self:setSurfing(game, true, false)
    local ok, err = self.mod.world:warpTo(
      target.mapId, target.x, target.y, targetFacing(target, position.facing),
      { onDone = function()
          -- Preserve the Surf sprite but restore the underwater map song.
          self:refreshMovementPresentation(game, false)
          self.mod.events:emit("mod.kanto_dive.entered", {
            zoneId = zone.id,
            linkId = target.linkId,
            mapId = target.mapId,
            x = target.x,
            y = target.y,
          })
        end })
    if not ok then
      self:setSession(nil)
      self:setSurfing(game, true, true, true)
      self.mod.log:error("DIVE warp failed: %s", tostring(err))
    end
  end)
end

function DiveService:beginSurface(mon, game, menu, zone, position, target, state)
  if not target then
    if state and state.orphaned then self:recover(game, menu) end
    return
  end
  self:closePartyMenu(game)
  local name = self:displayName(game, mon)
  self:showText(game, name .. " returned to\nthe surface!", function()
    self:setSurfing(game, true, false)
    local ok, err = self.mod.world:warpTo(
      target.mapId, target.x, target.y, targetFacing(target, position.facing),
      { onDone = function()
          self:setSession(nil)
          self:refreshMovementPresentation(game, true)
          self.mod.events:emit("mod.kanto_dive.surfaced", {
            zoneId = zone.id,
            linkId = target.linkId,
            mapId = target.mapId,
            x = target.x,
            y = target.y,
          })
        end })
    if not ok then
      self:setSurfing(game, true, true, false)
      self.mod.log:error("SURFACE warp failed: %s", tostring(err))
    end
  end)
end

local function alreadyHas(items, label)
  for _, item in ipairs(items) do
    if item.label == label then return true end
  end
  return false
end

local function removeLabel(items, label)
  for index = #items, 1, -1 do
    if items[index] and items[index].label == label then
      table.remove(items, index)
    end
  end
end

local function insertBeforeStats(items, item)
  local index = #items + 1
  for i, existing in ipairs(items) do
    if existing.label == "STATS" then index = i break end
  end
  table.insert(items, index, item)
end

function DiveService:install()
  local mod = self.mod
  mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" then return out end
    if ctx and ctx.battle then return out end

    local position = self:current(game)
    local state = self:getSession()
    local submerged = position and self.registry:submergedZone(position.mapId)

    -- Underwater movement already uses the Surf state and Surf sprite. The
    -- vanilla SURF action would try to dismount or mount again, so remove it
    -- for every party member, including Pokemon that do not know DIVE.
    if submerged or (state and state.active) then removeLabel(out, "SURF") end

    if not position or not mon or not self:knowsDive(mon) then return out end

    if state and state.active then
      local target, linkedZone = self.registry:surfaceTarget(
        position.mapId, position.x, position.y)
      local zone = linkedZone or self.registry:get(state.zoneId)
        or self.registry:submergedZone(position.mapId)
      if target and not self:surfaceTargetIsWater(game, target) then target = nil end
      local orphanRecovery = state.orphaned and zone
        and mapContains(zone.surfacingMaps, position.mapId)
      if zone and zone.id == state.zoneId and (target or orphanRecovery)
          and not alreadyHas(out, "SURFACE") then
        insertBeforeStats(out, {
          label = "SURFACE",
          onSelect = function(selected, activeGame)
            self:beginSurface(selected, activeGame, nil, zone, position,
              target, state)
          end,
        })
      end
      return out
    end

    local target, zone = self.registry:diveTarget(position.mapId, position.x, position.y)
    if zone and target and position.surfing and self:hasBadge(game, zone.requiredBadge)
        and not alreadyHas(out, "DIVE") then
      insertBeforeStats(out, {
        label = "DIVE",
        onSelect = function(selected, activeGame)
          self:beginDive(selected, activeGame, nil, zone, position, target)
        end,
      })
    end
    return out
  end)

  mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local state = self:getSession()
    if moveId == "SURF" and state and state.active then
      return nil
    end
    return next(moveId, ctx)
  end)

  mod.events:on("map.entered", function(event)
    if not (event and event.mapId) then return end
    local submerged = self.registry:submergedZone(event.mapId)
    local state = self:getSession()

    if submerged then
      if not (state and state.active and state.zoneId == submerged.id) then
        self:setSession({ active = true, zoneId = submerged.id, orphaned = true })
      end
      -- A save/load or an ordinary underwater warp must preserve the mount.
      local loaded, game = pcall(require, "src.core.Game")
      if loaded and game then
        self:setSurfing(game, true, false)
        self:refreshMovementPresentation(game, false)
      end
      return
    end

    if state and state.active then self:setSession(nil) end
  end)
end

function DiveService:isUnderwater()
  local state = self:getSession()
  return state and state.active == true or false
end

function DiveService:currentZone()
  local state = self:getSession()
  return state and state.zoneId or nil
end

function DiveService:canDiveHere(game)
  local position = self:current(game)
  if not (position and position.surfing) then return false end
  local target, zone = self.registry:diveTarget(position.mapId, position.x, position.y)
  return target ~= nil and zone ~= nil and self:hasBadge(game, zone.requiredBadge)
end

function DiveService:canSurfaceHere(game)
  local position = self:current(game)
  local state = self:getSession()
  if not (position and state and state.active) then return false end
  local target, zone = self.registry:surfaceTarget(position.mapId, position.x, position.y)
  if target and zone and zone.id == state.zoneId
      and self:surfaceTargetIsWater(game, target) then return true end
  zone = zone or self.registry:get(state.zoneId)
  return state.orphaned == true and zone ~= nil
    and mapContains(zone.surfacingMaps, position.mapId)
end

return DiveService
