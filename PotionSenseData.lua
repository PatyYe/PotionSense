-- PotionSenseData.lua
-- Contains all hardcoded potion types and configuration defaults

local ADDON_NAME = ...

-- Hardcoded potion types with variants
local POTION_TYPES = {
    lightsPotential = {
        name = "Light's Potential",
        variants = {
            { itemID = 245898, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 245897, name = "Fleeting", quality = "normal" },
            { itemID = 241308, name = "Standard (HQ)", quality = "hq" },
            { itemID = 241309, name = "Standard", quality = "normal" },
        }
    },

    recklessness = {
        name = "Potion of Recklessness",
        variants = {
            { itemID = 245902, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 245903, name = "Fleeting", quality = "normal" },
            { itemID = 241288, name = "Standard (HQ)", quality = "hq" },
            { itemID = 241289, name = "Standard", quality = "normal" },
        }
    },

    zealotry = {
        name = "Potion of Zealotry",
        variants = {
            { itemID = 245901, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 245900, name = "Fleeting", quality = "normal" },
            { itemID = 241296, name = "Standard (HQ)", quality = "hq" },
            { itemID = 241297, name = "Standard", quality = "normal" },
        }
    },

    rampantAbandon = {
        name = "Draught of Rampant Abandon",
        variants = {
            { itemID = 245910, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 245911, name = "Fleeting", quality = "normal" },
            { itemID = 241292, name = "Standard (HQ)", quality = "hq" },
            { itemID = 241293, name = "Standard", quality = "normal" },
        }
    },

    liquidLuster = {
        name = "Liquid Luster",
        variants = {
            { itemID = 274764, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 274763, name = "Fleeting", quality = "normal" },
            { itemID = 271887, name = "Standard (HQ)", quality = "hq" },
            { itemID = 271886, name = "Standard", quality = "normal" },
        }
    },

    alluringNostrum = {
        name = "Alluring Nostrum",
        variants = {
            { itemID = 274765, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 274766, name = "Fleeting", quality = "normal" },
            { itemID = 271890, name = "Standard (HQ)", quality = "hq" },
            { itemID = 271889, name = "Standard", quality = "normal" },
        }
    },

    lightfusedMana = {
        name = "Lightfused Mana Potion",
        variants = {
            { itemID = 245916, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 245917, name = "Fleeting", quality = "normal" },
            { itemID = 241300, name = "Standard (HQ)", quality = "hq" },
            { itemID = 241301, name = "Standard", quality = "normal" },
        }
    },

    devouredDreams = {
        name = "Potion of Devoured Dreams",
        variants = {
            { itemID = 245904, name = "Fleeting (HQ)", quality = "hq" },
            { itemID = 245905, name = "Fleeting", quality = "normal" },
            { itemID = 241294, name = "Standard (HQ)", quality = "hq" },
            { itemID = 241295, name = "Standard", quality = "normal" },
        }
    }
}

-- Generate potion name to key mapping automatically from POTION_TYPES
local function GeneratePotionNameToKey()
    local mapping = {}
    for key, potionData in pairs(POTION_TYPES) do
        mapping[potionData.name] = key
    end
    return mapping
end

local PotionNameToKey = GeneratePotionNameToKey()

-- Helper function to get potion key by display name
local function GetPotionKeyByName(potionName)
    return PotionNameToKey[potionName]
end

-- Ideal potion recommendations by spec (organized by class)
local IdealPotionsBySpec = {
    -- Death Knight
    Blood = "recklessness",
    Frost = "recklessness",
    Unholy = "recklessness",

    -- Demon Hunter
    Havoc = "recklessness",
    Vengeance = "lightsPotential",
    Devourer = "recklessness",

    -- Druid
    Balance = "lightsPotential",
    Feral = "rampantAbandon",
    Guardian = "rampantAbandon",
    Restoration = "devouredDreams",

    -- Evoker
    Devastation = "recklessness",
    Augmentation = "recklessness",
    Preservation = "devouredDreams",

    -- Hunter
    ["Beast Mastery"] = "lightsPotential",
    Marksmanship = "recklessness",
    Survival = "recklessness",

    -- Mage
    Arcane = "lightsPotential",
    Fire = "lightsPotential",
    Frost = "recklessness",

    -- Monk
    Brewmaster = "liquidLuster",
    Mistweaver = "devouredDreams",
    Windwalker = "recklessness",

    -- Paladin
    Holy = "devouredDreams",
    Protection = "rampantAbandon",
    Retribution = "recklessness",

    -- Priest
    Discipline = "devouredDreams",
    Holy = "devouredDreams",
    Shadow = "recklessness",

    -- Rogue
    Assassination = "liquidLuster",
    Outlaw = "recklessness",
    Subtlety = "lightsPotential",

    -- Shaman
    Elemental = "lightsPotential",
    Enhancement = "liquidLuster",
    Restoration = "devouredDreams",

    -- Warlock
    Affliction = "lightsPotential",
    Demonology = "lightsPotential",
    Destruction = "lightsPotential",

    -- Warrior
    Arms = "lightsPotential",
    Fury = "lightsPotential",
    Protection = "rampantAbandon",
}

local defaults = {
    debug = false,
    macroName = "PotionSense",
    useGeneralMacro = true,
    noPotionBehavior = "leave",
    classSpecPotionMap = {},
}

local MACRO_ICON = "INV_Misc_QuestionMark"

-- Export to global namespace
PotionSense = {
    POTION_TYPES = POTION_TYPES,
    defaults = defaults,
    MACRO_ICON = MACRO_ICON,
    ADDON_NAME = ADDON_NAME,
    IdealPotionsBySpec = IdealPotionsBySpec,
    PotionNameToKey = PotionNameToKey,
    GetPotionKeyByName = GetPotionKeyByName,
}
