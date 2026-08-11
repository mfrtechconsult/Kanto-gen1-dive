local Content = {}

local function uniform(tile)
  local row = {}
  for i = 1, 16 do row[i] = tile end
  return row
end

-- Blocks 16..31 encode the exact 2x2 movement-cell underwater mask for one
-- 32x32 block. Tile 0 is swimmable underwater water; tile 15 is solid seabed
-- boundary. Full-water blocks may later be replaced by decorative all-water
-- blocks by the 2D seabed generator without changing collision.
local function collisionMaskBlock(mask)
  local block = {}
  for ty = 0, 3 do
    for tx = 0, 3 do
      local cellX, cellY = math.floor(tx / 2), math.floor(ty / 2)
      local bit = cellY == 0 and (cellX == 0 and 1 or 2)
        or (cellX == 0 and 4 or 8)
      block[#block + 1] = (mask % (bit * 2) >= bit) and 0 or 15
    end
  end
  return block
end

local function loadLua(mod, relativePath)
  local source, readError = mod:read(relativePath)
  if not source then return nil, readError end
  local compiler = loadstring or load
  local chunk, compileError = compiler(source, "@" .. mod.path .. "/" .. relativePath)
  if not chunk then return nil, compileError end
  local ok, value = pcall(chunk)
  if not ok then return nil, value end
  return value
end

local function contains(list, value)
  for _, entry in ipairs(list or {}) do
    local id = type(entry) == "table" and entry.id or entry
    if id == value then return true end
  end
  return false
end

local function appendUnique(list, value)
  local out = {}
  for _, entry in ipairs(list or {}) do out[#out + 1] = entry end
  if not contains(out, value) then out[#out + 1] = value end
  return out
end

local function findOptionalMod(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, handle = pcall(function() return mod.find(id) end)
  if ok and handle then return handle end
  ok, handle = pcall(function() return mod:find(id) end)
  if ok then return handle end
  return nil
end

local function crystal251Ready(mod)
  return findOptionalMod(mod, "CRYSTAL_251") ~= nil
    and mod.content.pokemon:get("TOTODILE") ~= nil
    and mod.content.pokemon:get("LUGIA") ~= nil
end

local function addDiveCompatibility(mod, speciesIds, sourceName)
  local added = 0
  for _, speciesId in ipairs(speciesIds or {}) do
    local species = mod.content.pokemon:get(speciesId)
    if species then
      if not contains(species.tmhm, "DIVE") then
        mod.content.pokemon:patch(speciesId, { tmhm = { __append = { "DIVE" } } })
        added = added + 1
      end
    elseif sourceName ~= "Crystal 251" then
      mod.log:warn("Skipping DIVE compatibility for unknown species %s", speciesId)
    end
  end
  return added
end

function Content.register(mod)
  local existingDive = mod.content.moves:get("DIVE")
  if not existingDive then
    local surf = mod.content.moves:get("SURF")
    local dive = {
      id = "DIVE", name = "DIVE", type = "WATER",
      power = 60, accuracy = 100, pp = 10,
      effect = "NO_ADDITIONAL_EFFECT", category = "special",
    }
    if surf and surf.anim ~= nil then dive.anim = surf.anim end
    mod.content.moves:register("DIVE", dive)
  end

  local existingItem = mod.content.items:get("HM_DIVE")
  if existingItem then
    local machine = existingItem.machine
    if not (machine and machine.kind == "HM" and machine.move == "DIVE") then
      mod.log:error("HM_DIVE exists but does not teach DIVE")
      return nil
    end
    if existingItem.name ~= "HM08" or tonumber(machine.number) ~= 8 then
      mod.content.items:patch("HM_DIVE", { name = "HM08", machine = { number = 8 } })
    end
  else
    mod.content.items:register("HM_DIVE", {
      id = "HM_DIVE", name = "HM08", price = 0,
      machine = { kind = "HM", move = "DIVE", number = 8 },
      tossable = false, keyItem = true,
    })
  end

  local hmMoves = mod.content.constants:get("hmMoves") or {}
  mod.content.constants:override("hmMoves", appendUnique(hmMoves, "DIVE"))

  local compatibility, compatibilityError = loadLua(mod, "data/compatibility.lua")
  if not compatibility then
    mod.log:error("Could not load DIVE compatibility: %s", tostring(compatibilityError))
    return nil
  end
  addDiveCompatibility(mod, compatibility, "Kanto Dive")

  if crystal251Ready(mod) then
    local crystalCompatibility, crystalError = loadLua(mod, "data/compatibility_crystal251.lua")
    if not crystalCompatibility then
      mod.log:error("Could not load Crystal 251 DIVE compatibility: %s", tostring(crystalError))
      return nil
    end
    local added = addDiveCompatibility(mod, crystalCompatibility, "Crystal 251")
    mod.log:info("Crystal 251 integration enabled; added DIVE compatibility to %d Gen II species", added)
  end

  local blocks = {
    uniform(0), uniform(1), uniform(2),
    { 0,3,0,0, 0,0,0,3, 3,0,0,0, 0,0,3,0 },
    { 0,7,0,0, 0,0,7,0, 0,0,0,7, 0,0,0,0 },
    uniform(4), uniform(5),
    { 2,2,2,2, 6,6,2,2, 0,0,0,0, 0,0,0,0 },
    uniform(8), uniform(9), uniform(10), uniform(11),
    uniform(12), uniform(13), uniform(14), uniform(15),
  }
  for mask = 0, 15 do blocks[#blocks + 1] = collisionMaskBlock(mask) end

  if not mod.content.tilesets:get("KD_UNDERWATER") then
    mod.content.tilesets:register("KD_UNDERWATER", {
      id = "KD_UNDERWATER",
      image = mod.assets:path("assets/tilesets/kanto_dive_underwater.png"),
      imageWidth = 64, imageHeight = 32, tilesPerRow = 8,
      blocks = blocks,
      walkable = {},
      warpTiles = { 6 },
      waterTiles = { 0, 1, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14 },
      shoreTiles = {}, grassTile = 0, trueColor = true,
    })
  end

  -- Static KD_ROUTE19/20/21/SEAFOAM maps are no longer registered here.
  -- The Full-Kanto 2D generator owns underwater map creation at runtime.
  return true
end

return Content
