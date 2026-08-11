-- Headless contract for the unconditional exterior HM08 giver.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

package.preload["src.world.Map"] = function()
  return {
    defIsWalkableCell = function(_, _, x, y) return x == 4 and y == 10 end,
    defIsWaterCell = function() return false end,
  }
end

local Progression = dofile(root .. "/src/Progression.lua")

local mapDef = {
  id = "CINNABAR_ISLAND",
  width = 10,
  height = 9,
  tileset = "OVERWORLD",
  warps = {
    { x = 6, y = 9, destMap = "CINNABAR_LAB", destWarp = 1 },
  },
  objects = {
    { index = 1, x = 12, y = 5, sprite = "SPRITE_GIRL", movement = "WALK", range = "LEFT_RIGHT", text = "A" },
    { index = 2, x = 14, y = 6, sprite = "SPRITE_GAMBLER", movement = "STAY", range = "NONE", text = "B" },
  },
}

local patchPayload, registeredMap, registeredScript
local mod = {
  content = {
    maps = {
      get = function(_, id) if id == "CINNABAR_ISLAND" then return mapDef end end,
      patch = function(_, id, payload) patchPayload = payload; return payload end,
    },
    tilesets = { get = function() return { id = "OVERWORLD" } end },
    map_scripts = {
      register = function(_, id, payload)
        registeredMap, registeredScript = id, payload
        return payload
      end,
    },
  },
  log = { info = function() end, error = function() end },
}

assert(Progression.install(mod) == true, "Progression.install must succeed")
assert(patchPayload and patchPayload.objects and patchPayload.objects.__append,
  "Cinnabar map must receive an appended NPC")
local npc = patchPayload.objects.__append[1]
assert(npc, "HM08 researcher object is missing")
assert(npc.x == 4 and npc.y == 10,
  "researcher should prefer the walkable cell immediately left of the lab")
assert(npc.sprite == "SPRITE_SCIENTIST", "researcher should use the scientist sprite")
assert(npc.movement == "STAY", "researcher must be fixed in place")
assert(npc.text == "TEXT_HM08_DIVE_RESEARCHER", "researcher text id mismatch")
assert(npc.index == 3, "researcher object index must follow vanilla objects")

assert(registeredMap == "CINNABAR_ISLAND", "talk script must be registered outdoors")
local rows = registeredScript and registeredScript.talk
  and registeredScript.talk.TEXT_HM08_DIVE_RESEARCHER
assert(rows, "researcher talk script is missing")

local givesDive, badgeGate, storyGate, itemCheck = false, false, false, false
for _, row in ipairs(rows) do
  if row[1] == "give_item" and row[2] == "HM_DIVE" then givesDive = true end
  if row[1] == "check_item" and row[2] == "HM_DIVE" then itemCheck = true end
  if row[1] == "check_item" and row[2] == "VOLCANOBADGE" then badgeGate = true end
  if row[1] == "check_flag" then storyGate = true end
end

assert(givesDive, "researcher must give HM_DIVE")
assert(itemCheck, "researcher must only use HM_DIVE ownership for idempotency")
assert(not badgeGate, "researcher must not require the Volcano Badge")
assert(not storyGate, "researcher must not require any story flag")

print("HM08 researcher OK: fixed exterior NPC, no badge/story requirement")
