local width, height = 10, 45 -- 20 x 90 movement cells, matching ROUTE_21
local blocks = {}
for by = 0, height - 1 do
  for bx = 0, width - 1 do
    local center = bx >= 3 and bx <= 6
    local value
    if center then
      value = ({ 13, 13, 14, 13, 12, 13, 8, 13 })[((by + bx) % 8) + 1]
    else
      value = ({ 0, 0, 1, 3, 4, 8, 9, 11 })[((bx * 5 + by * 3) % 8) + 1]
    end
    blocks[#blocks + 1] = value
  end
end

return {
  id = "KD_ROUTE21_TRENCH",
  label = "KantoDiveRoute21Trench",
  index = 1102,
  tileset = "KD_UNDERWATER",
  width = width,
  height = height,
  borderBlock = 15,
  outdoor = false,
  region = "KANTO_DIVE",
  blocks = blocks,
  warps = {},
  objects = {},
  signs = {},
}
