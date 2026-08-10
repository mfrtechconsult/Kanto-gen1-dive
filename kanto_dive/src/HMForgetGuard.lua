local HMForgetGuard = {}

local function contains(list, value)
  for _, entry in ipairs(list or {}) do
    local id = type(entry) == "table" and entry.id or entry
    if id == value then return true end
  end
  return false
end

function HMForgetGuard.install(mod)
  local ok, MoveLearnMenu = pcall(require, "src.ui.MoveLearnMenu")
  if not (ok and MoveLearnMenu and type(MoveLearnMenu.new) == "function") then
    mod.log:error("Could not install extended HM forget protection")
    return nil
  end
  if MoveLearnMenu.__extendedHMForgetGuard then return true end

  local originalNew = MoveLearnMenu.new
  MoveLearnMenu.new = function(game, mon, newMoveId, onDone)
    local screen = originalNew(game, mon, newMoveId, onDone)
    local originalUpdate = screen.update
    screen.update = function(self, dt)
      local input = self.game and self.game.input
      if self.selecting and input and input:wasPressed("a")
          and self.index <= #self.mon.moves then
        local selected = self.mon.moves[self.index]
        local moveId = selected and selected.id
        if moveId and contains(self.game.data.constants.hmMoves, moveId) then
          local TextBox = require("src.render.TextBox")
          self.game.stack:push(TextBox.new(self.game,
            "HM techniques\ncan't be deleted!"))
          return
        end
      end
      return originalUpdate(self, dt)
    end
    return screen
  end

  MoveLearnMenu.__extendedHMForgetGuard = true
  return true
end

return HMForgetGuard
