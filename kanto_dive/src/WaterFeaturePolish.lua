local Game = require("src.core.Game")

local WaterFeaturePolish = {}
local CELL = 16

local function readyPlayer(player, dir, map)
  return player and player.surfing and dir == "down" and map and map.id
    and not player.moving and not player.inputLocked and player.facing == dir
    and not (player.turnTimer and player.turnTimer > 0)
end

local function restoreSurfing(game)
  local ow = game and game.overworld
  if game and game.save then
    game.save.onBike = false
    game.save.forcedBike = nil
    if game.save.player then game.save.player.surfing = true end
  end
  if ow and ow.player then ow.player.surfing = true end
  if ow and type(ow.syncSurfingPikachu) == "function" then
    pcall(ow.syncSurfingPikachu, ow)
  end
end

local function descend(service, player, map, feature)
  local targetY = feature.y + feature.height
  local ok, err = service.mod.world:warpTo(map.id, player.cellX, targetY, "down", {
    onDone = function()
      restoreSurfing(Game)
      service.mod.events:emit("mod.johto_water.waterfall_descended", {
        owner = service.mod.id,
        mapId = feature.mapId,
        id = feature.id,
      })
    end,
  })
  if not ok and service.mod.log then
    service.mod.log:error("WATERFALL descent failed: %s", tostring(err))
  end
  return ok == true
end

local function installPlayerPatch(service)
  local ok, Player = pcall(require, "src.world.Player")
  if not (ok and Player and type(Player.tryMove) == "function") then
    service.mod.log:error("Could not install automatic WATERFALL descent")
    return nil
  end

  Player.__kantoDiveWaterFeaturePolishService = service
  if Player.__kantoDiveWaterFeaturePolishPatched then return true end

  local original = Player.tryMove
  Player.tryMove = function(player, dir, map, entities)
    local active = Player.__kantoDiveWaterFeaturePolishService
    if active and readyPlayer(player, dir, map) then
      local feature = active:featureAt("WATERFALL", map.id, player.cellX, player.cellY + 1)
      if feature and player.cellY == feature.y - 1 then
        player.bumpFrames = player.stepFrames or 16
        if descend(active, player, map, feature) then
          return "blocked", "waterfall_descent"
        end
      end
    end
    return original(player, dir, map, entities)
  end
  Player.__kantoDiveWaterFeaturePolishPatched = true
  return true
end

local function graphicsAvailable()
  return love and love.graphics
    and type(love.graphics.rectangle) == "function"
    and type(love.graphics.setColor) == "function"
end

local function pulseAlpha()
  local t = love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
  return 0.70 + 0.20 * (0.5 + 0.5 * math.sin(t * 4.5))
end

local function projectedQuad(project, feature)
  local x0, y0 = feature.x * CELL, feature.y * CELL
  local x1, y1 = x0 + feature.width * CELL, y0 + feature.height * CELL
  local ax, ay = project(x0, y0)
  local bx, by = project(x1, y0)
  local cx, cy = project(x1, y1)
  local dx, dy = project(x0, y1)
  if type(ax) ~= "number" or type(ay) ~= "number"
      or type(bx) ~= "number" or type(by) ~= "number"
      or type(cx) ~= "number" or type(cy) ~= "number"
      or type(dx) ~= "number" or type(dy) ~= "number" then
    return nil
  end
  return { ax, ay, bx, by, cx, cy, dx, dy }
end

local function drawFlat(service, mapId, camX, camY)
  if not graphicsAvailable() then return end
  local ox, oy = math.floor(camX or 0), math.floor(camY or 0)
  local alpha = pulseAlpha()
  love.graphics.push("all")
  if type(love.graphics.setLineWidth) == "function" then love.graphics.setLineWidth(2) end

  for _, feature in ipairs(service.features.WHIRLPOOL or {}) do
    if feature.mapId == mapId and not service:isCleared(feature) then
      local x, y = feature.x * CELL - ox, feature.y * CELL - oy
      local w, h = feature.width * CELL, feature.height * CELL
      love.graphics.setColor(0.86, 0.97, 1.0, alpha)
      love.graphics.rectangle("line", x + 1, y + 1, math.max(1, w - 2), math.max(1, h - 2))
      if type(love.graphics.ellipse) == "function" then
        local cx, cy = x + w / 2, y + h / 2
        love.graphics.ellipse("line", cx, cy, math.max(5, w * 0.42), math.max(4, h * 0.34))
      end
    end
  end

  for _, feature in ipairs(service.features.WATERFALL or {}) do
    if feature.mapId == mapId then
      local x, y = feature.x * CELL - ox, feature.y * CELL - oy
      local w, h = feature.width * CELL, feature.height * CELL
      love.graphics.setColor(0.96, 1.0, 1.0, alpha)
      love.graphics.rectangle("line", x + 1, y + 1, math.max(1, w - 2), math.max(1, h - 2))
      if type(love.graphics.line) == "function" then
        local cx = x + w / 2
        love.graphics.line(cx, y + 3, cx, y + h - 4)
        love.graphics.line(cx - 4, y + h - 9, cx, y + h - 4, cx + 4, y + h - 9)
      end
    end
  end
  love.graphics.pop()
end

local function drawProjected(service, ctx, project)
  if not (ctx and ctx.state and ctx.state.map and graphicsAvailable()
      and type(project) == "function" and type(love.graphics.polygon) == "function") then
    return
  end
  local mapId = ctx.state.map.id
  local alpha = pulseAlpha()
  love.graphics.push("all")
  if type(love.graphics.setLineWidth) == "function" then love.graphics.setLineWidth(2) end

  for _, feature in ipairs(service.features.WHIRLPOOL or {}) do
    if feature.mapId == mapId and not service:isCleared(feature) then
      local q = projectedQuad(project, feature)
      if q then
        love.graphics.setColor(0.86, 0.97, 1.0, alpha)
        love.graphics.polygon("line", q)
      end
    end
  end
  for _, feature in ipairs(service.features.WATERFALL or {}) do
    if feature.mapId == mapId then
      local q = projectedQuad(project, feature)
      if q then
        love.graphics.setColor(0.96, 1.0, 1.0, alpha)
        love.graphics.polygon("line", q)
      end
    end
  end
  love.graphics.pop()
end

local function installRenderPatch(service)
  local okTiles, TileRenderer = pcall(require, "src.render.TileRenderer")
  if okTiles and TileRenderer and type(TileRenderer.drawWindow) == "function" then
    TileRenderer.__kantoDiveWaterFeaturePolishService = service
    if not TileRenderer.__kantoDiveWaterFeaturePolishPatched then
      local original = TileRenderer.drawWindow
      TileRenderer.drawWindow = function(renderer, camX, camY, viewWidth, viewHeight)
        local result = original(renderer, camX, camY, viewWidth, viewHeight)
        local active = TileRenderer.__kantoDiveWaterFeaturePolishService
        local mapId = renderer and renderer.map and renderer.map.id
        if active and mapId then drawFlat(active, mapId, camX, camY) end
        return result
      end
      TileRenderer.__kantoDiveWaterFeaturePolishPatched = true
    end
  end

  local okPipes, Pipelines = pcall(require, "src.render.Pipelines")
  if okPipes and Pipelines and type(Pipelines.drawWorld) == "function" then
    Pipelines.__kantoDiveWaterFeaturePolishService = service
    if not Pipelines.__kantoDiveWaterFeaturePolishPatched then
      local original = Pipelines.drawWorld
      Pipelines.drawWorld = function(id, ctx)
        local active = Pipelines.__kantoDiveWaterFeaturePolishService
        if active and ctx and type(ctx.drawFx) == "function" then
          local baseDrawFx = ctx.drawFx
          ctx.drawFx = function(project, scale)
            drawProjected(active, ctx, project)
            return baseDrawFx(project, scale)
          end
        end
        return original(id, ctx)
      end
      Pipelines.__kantoDiveWaterFeaturePolishPatched = true
    end
  end
  return true
end

function WaterFeaturePolish.install(mod, service)
  if not service then return nil end
  if not installPlayerPatch(service) then return nil end
  installRenderPatch(service)
  if mod.log then
    mod.log:info("Water feature polish ready: stronger markers and automatic WATERFALL descent")
  end
  return true
end

return WaterFeaturePolish
