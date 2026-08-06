local width, height = 50, 9 -- 100 x 18 movement cells, matching ROUTE_20
local decorative = { 0, 0, 0, 1, 3, 4, 8, 9, 11, 12, 13, 14 }
local blocks = {}
for by = 0, height - 1 do
  for bx = 0, width - 1 do
    local value = decorative[((bx * 7 + by * 11 + bx * by) % #decorative) + 1]
    -- Keep the open-water basins visually calmer than the outer shelf.
    if by >= 2 and by <= 6 and ((bx >= 2 and bx <= 18)
        or (bx >= 22 and bx <= 28) or (bx >= 31 and bx <= 47)) then
      value = ({ 0, 0, 1, 3, 4, 8, 11 })[((bx + by * 3) % 7) + 1]
    end
    blocks[#blocks + 1] = value
  end
end

-- Seafoam access: block 7's top-left cell is the warp tile.
local caveBlockX, caveBlockY = 25, 5
blocks[caveBlockY * width + caveBlockX + 1] = 7

return {
  id = "KD_ROUTE20_SEAFLOOR",
  label = "KantoDiveRoute20Seafloor",
  index = 1100,
  tileset = "KD_UNDERWATER",
  width = width,
  height = height,
  borderBlock = 15,
  outdoor = false,
  region = "KANTO_DIVE",
  blocks = blocks,
  warps = {
    { x = caveBlockX * 2, y = caveBlockY * 2,
      destMap = "KD_SEAFOAM_SUNKEN_CAVE", destWarp = 1 },
  },
  objects = {},
  signs = {},
}
