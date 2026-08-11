local Progression = {}

local MAP_ID = "CINNABAR_ISLAND"
local LAB_MAP_ID = "CINNABAR_LAB"
local TEXT_ID = "TEXT_HM08_DIVE_RESEARCHER"
local OBJECT_NAME = "MOD_HM08_DIVE_RESEARCHER"

local function sameCell(a, x, y)
  return a and tonumber(a.x) == x and tonumber(a.y) == y
end

local function occupied(def, x, y)
  for _, warp in ipairs(def.warps or {}) do
    if sameCell(warp, x, y) then return true end
  end
  for _, object in ipairs(def.objects or {}) do
    if sameCell(object, x, y) then return true end
  end
  return false
end

local function existingResearcher(def)
  for _, object in ipairs(def.objects or {}) do
    if object.name == OBJECT_NAME or object.text == TEXT_ID then
      return object
    end
  end
  return nil
end

local function labWarp(def)
  for _, warp in ipairs(def.warps or {}) do
    if warp.destMap == LAB_MAP_ID then return warp end
  end
  -- Vanilla Red/Blue/Yellow Cinnabar: the lab entrance is at (6,9).
  return { x = 6, y = 9 }
end

local function nextObjectIndex(def)
  local highest = 0
  for index, object in ipairs(def.objects or {}) do
    highest = math.max(highest, tonumber(object.index) or index)
  end
  return highest + 1
end

local function choosePosition(mod, def, warp)
  local okMap, Map = pcall(require, "src.world.Map")
  local tileset = mod.content.tilesets:get(def.tileset)

  -- Prefer a position immediately to the lower-left of the lab entrance,
  -- then fan out only to nearby cells on the lab's left side. This keeps the
  -- researcher visually beside the lab without ever blocking its doorway.
  local candidates = {
    { warp.x - 2, warp.y + 1 },
    { warp.x - 1, warp.y + 1 },
    { warp.x - 2, warp.y + 2 },
    { warp.x - 1, warp.y + 2 },
    { warp.x - 3, warp.y + 1 },
    { warp.x - 2, warp.y },
    { warp.x - 1, warp.y },
  }

  for _, point in ipairs(candidates) do
    local x, y = point[1], point[2]
    local inBounds = x >= 0 and y >= 0 and x < def.width * 2 and y < def.height * 2
    if inBounds and not occupied(def, x, y) then
      if okMap and Map and type(Map.defIsWalkableCell) == "function" and tileset then
        if Map.defIsWalkableCell(def, tileset, x, y)
            and not Map.defIsWaterCell(def, tileset, x, y) then
          return x, y
        end
      else
        return x, y
      end
    end
  end

  -- Defensive fallback for unusual imported datasets. The vanilla lab warp
  -- remains the anchor, and the NPC still stays off the doorway itself.
  return math.max(0, warp.x - 2), math.min(def.height * 2 - 1, warp.y + 1)
end

local function installResearcher(mod)
  local def = mod.content.maps:get(MAP_ID)
  if not def then
    mod.log:error("HM08 researcher: %s is unavailable", MAP_ID)
    return nil
  end

  local existing = existingResearcher(def)
  if existing then return existing end

  local warp = labWarp(def)
  local x, y = choosePosition(mod, def, warp)
  local object = {
    index = nextObjectIndex(def),
    name = OBJECT_NAME,
    x = x,
    y = y,
    sprite = "SPRITE_SCIENTIST",
    movement = "STAY",
    range = "DOWN",
    text = TEXT_ID,
  }

  mod.content.maps:patch(MAP_ID, {
    objects = { __append = { object } },
  })

  if mod.log then
    mod.log:info("Installed unconditional HM08 researcher on %s at (%d,%d)", MAP_ID, x, y)
  end
  return object
end

function Progression.install(mod)
  local researcher = installResearcher(mod)
  if not researcher then return nil end

  -- No badge, story flag, gym clear or TM35 requirement. Ownership of HM08
  -- itself is the only idempotency check, so old saves and either Dive mod's
  -- previous acquisition path are handled naturally.
  mod.content.map_scripts:register(MAP_ID, {
    talk = {
      [TEXT_ID] = {
        { "face_player" },
        { "check_item", "HM_DIVE" },
        { "jump_if_true", "already" },
        { "show_text", "I study the seas\naround KANTO.\fIf you're heading out\non the water, take this!" },
        { "give_item", "HM_DIVE", 1, false },
        { "show_text", "{PLAYER} received\nHM08!\fHM08 contains DIVE.\fTeach it to a compatible\nPOKEMON and use it\nwhile SURFing." },
        { "jump", "finish" },
        { "label", "already" },
        { "show_text", "HM08 DIVE works on\nKANTO's waters.\fUse DIVE while SURFing\nto explore below." },
        { "label", "finish" },
      },
    },
  })

  return true
end

return Progression
