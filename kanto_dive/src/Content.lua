local Content = {}

local function uniform(tile)
  local row = {}
  for i = 1, 16 do row[i] = tile end
  return row
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

local function appendUnique(list, value)
  local out, found = {}, false
  for _, entry in ipairs(list or {}) do
    out[#out + 1] = entry
    if entry == value then found = true end
  end
  if not found then out[#out + 1] = value end
  return out
end

function Content.register(mod)
  -- Surface DIVE indicators are drawn directly over the map water by
  -- SurfaceDarkService. No decorative NPC objects are registered.

  local surf = mod.content.moves:get("SURF")
  local dive = {
    id = "DIVE",
    name = "DIVE",
    type = "WATER",
    power = 60,
    accuracy = 100,
    pp = 10,
    effect = "NO_ADDITIONAL_EFFECT",
    category = "special",
  }
  if surf and surf.anim ~= nil then dive.anim = surf.anim end
  mod.content.moves:register("DIVE", dive)

  mod.content.items:register("HM_DIVE", {
    id = "HM_DIVE",
    name = "HM06",
    price = 0,
    machine = { kind = "HM", move = "DIVE", number = 6 },
    tossable = false,
    keyItem = true,
  })

  local hmMoves = mod.content.constants:get("hmMoves") or {}
  mod.content.constants:override("hmMoves", appendUnique(hmMoves, "DIVE"))

  local compatibility, compatibilityError = loadLua(mod, "data/compatibility.lua")
  if not compatibility then
    mod.log:error("Could not load DIVE compatibility: %s", tostring(compatibilityError))
    return nil
  end
  for _, speciesId in ipairs(compatibility) do
    local species = mod.content.pokemon:get(speciesId)
    if species then
      mod.content.pokemon:patch(speciesId, {
        tmhm = appendUnique(species.tmhm or {}, "DIVE"),
      })
    else
      mod.log:warn("Skipping DIVE compatibility for unknown species %s", speciesId)
    end
  end

  local blocks = {
    uniform(0),
    uniform(1),
    uniform(2),
    { 0,3,0,0, 0,0,0,3, 3,0,0,0, 0,0,3,0 },
    { 0,7,0,0, 0,0,7,0, 0,0,0,7, 0,0,0,0 },
    uniform(4),
    uniform(5),
    { 2,2,2,2, 6,6,2,2, 0,0,0,0, 0,0,0,0 },
    uniform(8),
    uniform(9),
    uniform(10),
    uniform(11),
    uniform(12),
    uniform(13),
    uniform(14),
    uniform(15),
  }

  -- Traversable underwater cells are water-only, not ordinary walkable
  -- floor. This keeps the engine's Surf state and sprite active after every
  -- step instead of triggering the normal automatic dismount-on-land rule.
  mod.content.tilesets:register("KD_UNDERWATER", {
    id = "KD_UNDERWATER",
    image = mod.assets:path("assets/tilesets/kanto_dive_underwater.png"),
    imageWidth = 64,
    imageHeight = 32,
    tilesPerRow = 8,
    blocks = blocks,
    walkable = {},
    warpTiles = { 6 },
    waterTiles = { 0, 1, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14 },
    shoreTiles = {},
    grassTile = 8,
    trueColor = true,
  })

  local catalog, catalogError = loadLua(mod, "data/maps.lua")
  if not catalog then
    mod.log:error("Could not load the underwater map catalog: %s", tostring(catalogError))
    return nil
  end
  for index, entry in ipairs(catalog) do
    local map, mapError = loadLua(mod, entry.file)
    if not map then
      mod.log:error("Could not load map catalog entry %d (%s): %s",
        index, tostring(entry.file), tostring(mapError))
      return nil
    end
    mod.content.maps:register(map.id, map)
    if entry.song then mod.content.map_songs:register(map.id, entry.song) end
    if entry.encounters then mod.content.encounters:register(map.id, entry.encounters) end
  end

  return true
end

return Content
