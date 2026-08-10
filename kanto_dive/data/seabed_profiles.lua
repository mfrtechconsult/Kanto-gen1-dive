-- Full-Kanto 2D underwater profiles. These mirror Dramatic Deep Dive's regional
-- identity and encounter ecology while keeping Kanto Dive completely flat/2D.
return {
  default = "coastal",

  profiles = {
    coastal = {
      spaceScale = 2,
      music = "Music_Dungeon2",
      ecology = "ocean",
      decor = { 0, 0, 1, 3, 4, 8, 11, 12, 13 },
      deepDecor = { 0, 1, 3, 8, 11, 13, 14 },
      encounterRate = 16,
    },
    ocean = {
      spaceScale = 3,
      music = "Music_Dungeon2",
      ecology = "ocean",
      decor = { 0, 0, 0, 1, 3, 4, 8, 11, 12, 13, 14 },
      deepDecor = { 0, 0, 1, 8, 11, 13, 14 },
      encounterRate = 14,
    },
    harbor = {
      spaceScale = 2,
      music = "Music_Dungeon2",
      ecology = "harbor",
      decor = { 0, 1, 3, 4, 8, 9, 11, 12 },
      deepDecor = { 0, 1, 8, 9, 11, 12 },
      encounterRate = 15,
    },
    volcanic = {
      spaceScale = 3,
      music = "Music_Dungeon2",
      ecology = "volcanic",
      decor = { 0, 2, 8, 9, 10, 11, 13, 14 },
      deepDecor = { 2, 8, 9, 10, 11, 14 },
      encounterRate = 14,
    },
    cave = {
      spaceScale = 2,
      music = "Music_Dungeon3",
      ecology = "cave",
      decor = { 0, 2, 5, 8, 9, 10, 11, 13, 14 },
      deepDecor = { 2, 5, 8, 9, 10, 11, 14 },
      encounterRate = 15,
    },
    freshwater = {
      spaceScale = 1,
      music = "Music_Dungeon2",
      ecology = "freshwater",
      decor = { 0, 0, 1, 3, 4, 8, 11, 12 },
      deepDecor = { 0, 1, 3, 8, 11, 12 },
      encounterRate = 18,
    },
    marsh = {
      spaceScale = 1,
      music = "Music_Dungeon2",
      ecology = "marsh",
      decor = { 0, 1, 3, 4, 8, 11, 12, 13 },
      deepDecor = { 0, 1, 8, 11, 12, 13 },
      encounterRate = 18,
    },
  },

  overrides = {
    PALLET_TOWN = "coastal",
    VIRIDIAN_CITY = "freshwater",
    PEWTER_CITY = "freshwater",
    CERULEAN_CITY = "freshwater",
    CELADON_CITY = "freshwater",
    SAFFRON_CITY = "freshwater",
    LAVENDER_TOWN = "freshwater",
    FUCHSIA_CITY = "marsh",
    VERMILION_CITY = "harbor",
    VERMILION_DOCK = "harbor",
    CINNABAR_ISLAND = "volcanic",

    ROUTE_1 = "freshwater", ROUTE_2 = "freshwater", ROUTE_3 = "freshwater",
    ROUTE_4 = "freshwater", ROUTE_5 = "freshwater", ROUTE_6 = "freshwater",
    ROUTE_7 = "freshwater", ROUTE_8 = "freshwater", ROUTE_9 = "freshwater",
    ROUTE_10 = "freshwater", ROUTE_11 = "coastal", ROUTE_12 = "coastal",
    ROUTE_13 = "coastal", ROUTE_14 = "coastal", ROUTE_15 = "coastal",
    ROUTE_16 = "freshwater", ROUTE_17 = "freshwater", ROUTE_18 = "marsh",
    ROUTE_19 = "ocean", ROUTE_20 = "ocean", ROUTE_21 = "ocean",
    ROUTE_22 = "freshwater", ROUTE_23 = "freshwater", ROUTE_24 = "freshwater",
    ROUTE_25 = "freshwater",
  },

  patterns = {
    { find = "SEAFOAM_ISLANDS", profile = "cave" },
    { find = "CERULEAN_CAVE", profile = "cave" },
    { find = "ROCK_TUNNEL", profile = "cave" },
    { find = "VICTORY_ROAD", profile = "cave" },
    { find = "SAFARI_ZONE", profile = "marsh" },
    { find = "VERMILION", profile = "harbor" },
    { find = "CINNABAR", profile = "volcanic" },
  },

  ecology = {
    ocean = {
      shallow = { "TENTACOOL", "HORSEA", "KRABBY", "STARYU", "SHELLDER" },
      mid = { "TENTACOOL", "HORSEA", "SEADRA", "STARYU", "SHELLDER", "KINGLER" },
      deep = { "SEADRA", "TENTACRUEL", "CLOYSTER", "STARMIE", "GYARADOS", "DEWGONG" },
    },
    harbor = {
      shallow = { "KRABBY", "TENTACOOL", "MAGIKARP", "SHELLDER", "STARYU" },
      mid = { "KRABBY", "KINGLER", "TENTACOOL", "SHELLDER", "STARYU" },
      deep = { "KINGLER", "TENTACRUEL", "CLOYSTER", "GYARADOS" },
    },
    volcanic = {
      shallow = { "TENTACOOL", "HORSEA", "MAGIKARP", "KRABBY" },
      mid = { "TENTACOOL", "SEADRA", "TENTACRUEL", "STARYU" },
      deep = { "TENTACRUEL", "SEADRA", "CLOYSTER", "GYARADOS" },
    },
    cave = {
      shallow = { "SEEL", "SHELLDER", "SLOWPOKE", "HORSEA" },
      mid = { "SEEL", "SHELLDER", "SLOWPOKE", "DEWGONG", "CLOYSTER" },
      deep = { "DEWGONG", "CLOYSTER", "SLOWBRO", "SEADRA", "GYARADOS" },
    },
    freshwater = {
      shallow = { "POLIWAG", "PSYDUCK", "GOLDEEN", "MAGIKARP", "SLOWPOKE" },
      mid = { "POLIWAG", "POLIWHIRL", "PSYDUCK", "GOLDEEN", "SLOWPOKE" },
      deep = { "POLIWHIRL", "GOLDUCK", "SEAKING", "SLOWBRO", "GYARADOS" },
    },
    marsh = {
      shallow = { "POLIWAG", "PSYDUCK", "SLOWPOKE", "MAGIKARP", "GOLDEEN" },
      mid = { "POLIWAG", "PSYDUCK", "SLOWPOKE", "GOLDEEN", "SEAKING" },
      deep = { "POLIWHIRL", "GOLDUCK", "SLOWBRO", "SEAKING" },
    },
  },
}
