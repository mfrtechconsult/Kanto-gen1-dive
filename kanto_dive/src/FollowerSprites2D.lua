local Assets = require("src.render.Assets")
local SpriteRenderer = require("src.render.SpriteRenderer")
local Game = require("src.core.Game")

local FollowerSprites2D = {}
FollowerSprites2D.__index = FollowerSprites2D

local WILDS_MOD_ID = "overworld_wild_spawns"
local PUBLIC_PROVIDER_IDS = {
  WILDS_MOD_ID,
  "PokePCFollowers_VoxelMerge",
  "pokepcfollowers",
  "FOLLOWERS_EX",
  "followers_ex",
}

local FILE_PROVIDER_IDS = {
  PokePCFollowers_VoxelMerge = true,
  pokepcfollowers = true,
  FOLLOWERS_EX = true,
  followers_ex = true,
}

local function fileExists(path)
  return love and love.filesystem and love.filesystem.getInfo
    and love.filesystem.getInfo(path) ~= nil
end

local function manifestId(raw)
  if type(raw) ~= "string" then return nil end
  return raw:match('"id"%s*:%s*"([^"\\]+)"')
end

local function setNearest(image)
  if image and image.setFilter then image:setFilter("nearest", "nearest") end
end

function FollowerSprites2D.new(mod)
  return setmetatable({ mod = mod, cache = {}, providerByKey = {} }, FollowerSprites2D)
end

function FollowerSprites2D:_exports(id)
  if not self.mod.find then return nil end
  local ok, handle = pcall(self.mod.find, self.mod, id)
  return ok and handle and handle.exports or nil
end

function FollowerSprites2D:_publicDefinition(species)
  for _, id in ipairs(PUBLIC_PROVIDER_IDS) do
    local ex = self:_exports(id)
    if ex and type(ex.resolveFollowerSprite) == "function" then
      local requests = {
        { surface = "water" },
        { surface = "land" },
      }
      if id == WILDS_MOD_ID then
        requests[#requests + 1] = { surface = "land", style = "followers" }
      end
      for _, request in ipairs(requests) do
        local opts = {
          species = species,
          surface = request.surface,
          role = "wild",
          game = Game,
        }
        if request.style then opts.style = request.style end
        local okDef, def = pcall(ex.resolveFollowerSprite, opts)
        local frames = def and tonumber(def.frames) or 0
        if okDef and def and def.image and frames >= 6 then
          local okImage, image = pcall(Assets.image, def.image)
          if okImage and image then
            setNearest(image)
            local width, height = image:getDimensions()
            if width >= 16 and height >= 96 then
              return def, image, def.providerId or id
            end
          end
        end
      end
    end
  end
  return nil
end

function FollowerSprites2D:pathForDex(dex)
  dex = tonumber(dex)
  if not dex then return nil end
  local filename = string.format("follower_%03d.png", dex)

  if love and love.filesystem and love.filesystem.getDirectoryItems then
    local ok, names = pcall(love.filesystem.getDirectoryItems, "mods")
    if ok and type(names) == "table" then
      local fallback = nil
      for _, name in ipairs(names) do
        local root = "mods/" .. name
        local asset = root .. "/assets/sprites/" .. filename
        if fileExists(asset) then
          local raw = love.filesystem.read(root .. "/manifest.json")
          local id = manifestId(raw)
          if id and FILE_PROVIDER_IDS[id] then return asset end
          fallback = fallback or asset
        end
      end
      if fallback then return fallback end
    end
  end

  local roots = {
    "mods/PokePCFollowers_VoxelMerge/assets/sprites/",
    "mods/pokepcfollowers/assets/sprites/",
    "mods/PokePCFollowers/assets/sprites/",
  }
  for _, root in ipairs(roots) do
    local candidate = root .. filename
    if fileExists(candidate) then return candidate end
  end
  return nil
end

function FollowerSprites2D:build(species, dex)
  local key = tostring(species) .. ":" .. tostring(dex)
  if self.cache[key] then return self.cache[key] end

  local provided, providedImage, provider = self:_publicDefinition(species)
  if provided then
    local def = {
      id = "KANTO_DIVE_WILD_" .. tostring(species),
      image = provided.image,
      frames = 6,
      walker = true,
      trueColor = provided.trueColor ~= false,
      kantoDiveSpriteProvider = provider,
    }
    local sprite = SpriteRenderer.new(def, "kanto_dive_wild_" .. tostring(species))
    sprite.image = providedImage
    self.cache[key] = sprite
    self.providerByKey[key] = provider
    return sprite
  end

  local path = self:pathForDex(dex)
  if not path then return nil, "missing compatible follower sprite provider" end
  local ok, image = pcall(Assets.image, path)
  if not ok or not image then return nil, "failed to load follower asset" end
  setNearest(image)

  local width, height = image:getDimensions()
  if width < 16 or height < 96 then return nil, "unexpected follower sheet size" end

  local def = {
    id = "KANTO_DIVE_WILD_" .. tostring(species),
    image = path,
    frames = 6,
    walker = true,
    trueColor = true,
    kantoDiveSpriteProvider = "legacy-file",
  }
  local sprite = SpriteRenderer.new(def, "kanto_dive_wild_" .. tostring(species))
  sprite.image = image
  self.cache[key] = sprite
  self.providerByKey[key] = "legacy-file"
  return sprite
end

function FollowerSprites2D:providerFor(species, dex)
  return self.providerByKey[tostring(species) .. ":" .. tostring(dex)]
end

return FollowerSprites2D
