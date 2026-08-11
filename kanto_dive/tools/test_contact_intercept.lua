package.path = "kanto_dive/?.lua;kanto_dive/?/init.lua;" .. package.path

package.preload["src.core.Game"] = function() return {} end

local Intercept = dofile("kanto_dive/src/UnderwaterIntercept2D.lua")

local wildlife = { swimmers = {} }
local service = Intercept.new({}, {}, wildlife)
local player = { px = 0, py = 0, cellX = 0, cellY = 0 }

local function swimmer(px, py, scale)
  return {
    species = "MAGIKARP",
    level = 10,
    px = px,
    py = py,
    cellX = math.floor(px / 16),
    cellY = math.floor(py / 16),
    visualScale = scale or 1,
    dead = false,
  }
end

-- This was inside the old 2.5-cell proximity radius and must no longer battle.
wildlife.swimmers = { swimmer(39, 0, 1) }
assert(service:nearest(player) == nil,
  "a Pokemon almost 2.5 cells away must not trigger a battle")

-- A normal 16x16 sprite touching the player's body should trigger.
local normalContact = swimmer(12, 0, 1)
wildlife.swimmers = { normalContact }
assert(service:nearest(player) == normalContact,
  "normal sprite contact should trigger")

-- One pixel farther must no longer count as contact.
wildlife.swimmers = { swimmer(13, 0, 1) }
assert(service:nearest(player) == nil,
  "nearby but non-overlapping normal sprite must not trigger")

-- Large Pokédex-scaled sprites use their actual visible footprint.
local largeContact = swimmer(23, 0, 2.4)
wildlife.swimmers = { largeContact }
assert(service:nearest(player) == largeContact,
  "touching the visible edge of a large Pokemon should trigger")

wildlife.swimmers = { swimmer(29, 0, 2.4) }
assert(service:nearest(player) == nil,
  "large Pokemon must still not trigger before its visible body is touched")

print("Kanto Dive contact-only underwater interception OK")
