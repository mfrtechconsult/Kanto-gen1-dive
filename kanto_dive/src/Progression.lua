local Progression = {}

local MAP_ID = "CINNABAR_LAB_METRONOME_ROOM"
local TEXT_ID = "TEXT_CINNABARLABMETRONOMEROOM_SCIENTIST1"
local RECEIVED_FLAG = "MOD_KANTO_DIVE_HM06_RECEIVED"
local BASE_COMMAND = "kanto_dive:base_metronome_scientist"

function Progression.install(mod)
  local MapScripts = require("src.script.MapScripts")

  mod.content.commands:register(BASE_COMMAND, {
    foreground = true,
    fn = function(ctx)
      local base = MapScripts.baseTalk(MAP_ID, TEXT_ID)
      if not base then
        mod.log:error("The vanilla Cinnabar scientist handler is unavailable")
        return
      end
      local runner = ctx.runner
      base(ctx.game, ctx.overworld, ctx.npc, function() runner:resume() end)
      runner:yield()
    end,
  })

  mod.content.map_scripts:register(MAP_ID, {
    talk = {
      [TEXT_ID] = {
        { "face_player" },

        { "check_flag", RECEIVED_FLAG },
        { "jump_if_true", "after_hm" },
        { "check_item", "VOLCANOBADGE" },
        { "jump_if_true", "give_hm" },

        -- Before Blaine, preserve the scientist's original TM35 gift.  Once
        -- TM35 is collected, he hints at the later Dive research instead.
        { "check_flag", "EVENT_GOT_TM35" },
        { "jump_if_false", "vanilla" },
        { "show_text", "I am studying deep\nocean currents.\fReturn after proving\nyourself at the GYM." },
        { "jump", "finish" },

        { "label", "give_hm" },
        { "show_text", "The VOLCANO BADGE\nproves your skill.\fTake the result of\nmy ocean research!" },
        { "give_item", "HM_DIVE", 1, false },
        { "set_flag", RECEIVED_FLAG },
        { "show_text", "{PLAYER} received\nHM06!\fHM06 contains DIVE.\fUse it while SURFing\non ROUTE 20 or 21." },
        { "jump", "finish" },

        -- If the player received HM06 before taking TM35, the next talk still
        -- replays the complete vanilla handler so no original reward is lost.
        { "label", "after_hm" },
        { "check_flag", "EVENT_GOT_TM35" },
        { "jump_if_false", "vanilla" },
        { "show_text", "DIVE reaches the sea\nfloor below KANTO.\fUse SURFACE there to\nreturn to your spot." },
        { "jump", "finish" },

        { "label", "vanilla" },
        { BASE_COMMAND },
        { "label", "finish" },
      },
    },
  })
end

return Progression
