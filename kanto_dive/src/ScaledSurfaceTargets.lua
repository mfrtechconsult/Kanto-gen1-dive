local ScaledSurfaceTargets = {}

local function key(x, y)
  return y * 100000 + x
end

function ScaledSurfaceTargets.install(registry, atlas, zoneId)
  local zone = registry and registry:get(zoneId)
  if not zone then return nil, "generated Full-Kanto zone is missing" end

  local added = 0
  for _, surfaceId in ipairs(atlas:mapIds()) do
    local entry = atlas:surface(surfaceId)
    local scale = entry.underwaterScale or 1
    local mapRows = registry.surfaceTargets[entry.underwaterMapId] or {}
    registry.surfaceTargets[entry.underwaterMapId] = mapRows

    for cellKey in pairs(entry.surfaceWater or {}) do
      local sx, sy = cellKey:match("^(%-?%d+):(%-?%d+)$")
      sx, sy = tonumber(sx), tonumber(sy)
      local linkId = string.format("atlas_%s_%d_%d", surfaceId:lower(), sx, sy)
      for oy = 0, scale - 1 do
        for ox = 0, scale - 1 do
          local ux, uy = sx * scale + ox, sy * scale + oy
          mapRows[key(ux, uy)] = {
            mapId = surfaceId,
            x = sx,
            y = sy,
            facing = "same",
            zoneId = zoneId,
            linkId = linkId,
          }
          added = added + 1
        end
      end
    end
  end
  return added
end

return ScaledSurfaceTargets
