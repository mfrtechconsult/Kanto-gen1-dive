local HMShowcase = {}

local SAVE_KEY = "hmShowcaseHintsSeen"

local function copySeen(value)
  local out = {}
  for key, seen in pairs(type(value) == "table" and value or {}) do
    if seen then out[key] = true end
  end
  return out
end

local function showText(mod, text)
  local ok, Game = pcall(require, "src.core.Game")
  if not (ok and Game and Game.stack and mod.ui and mod.ui.TextBox) then
    return false
  end
  Game.stack:push(mod.ui.TextBox.new(Game, text))
  return true
end

function HMShowcase.install(mod, definitions)
  definitions = definitions or {}

  mod.events:on("map.entered", function(event)
    local mapId = event and event.mapId
    local definition = mapId and definitions[mapId]
    if not definition then return end

    local id = definition.id or mapId
    local seen = copySeen(mod.save:get(SAVE_KEY))
    if seen[id] then return end

    if showText(mod, definition.text) then
      seen[id] = true
      mod.save:set(SAVE_KEY, seen)
      mod.events:emit("mod.kanto_dive.hm_showcase_seen", {
        id = id,
        mapId = mapId,
        move = definition.move,
      })
    end
  end)
end

return HMShowcase
