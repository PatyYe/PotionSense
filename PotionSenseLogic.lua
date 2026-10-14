-- PotionSenseLogic.lua
-- Contains all core logic for potion selection and macro management

local function DebugPrint(message)
    if not PotionSenseDB or not PotionSenseDB.debug then
        return
    end

    print("|cff66ccff" .. PotionSense.ADDON_NAME .. "|r: " .. message)
end

local function GetItemIconCompat(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if GetItemIcon then
        return GetItemIcon(itemID)
    end
    return nil
end

local function GetMacroName()
    if PotionSenseDB and PotionSenseDB.macroName then
        return PotionSenseDB.macroName
    end

    return PotionSense.defaults.macroName
end

local function InitializeDB()
    if not PotionSenseDB then
        PotionSenseDB = {}
    end

    for key, value in pairs(PotionSense.defaults) do
        if value ~= nil and type(value) == "table" then
            if PotionSenseDB[key] == nil then
                PotionSenseDB[key] = CopyTable(value)
            end
        elseif PotionSenseDB[key] == nil then
            PotionSenseDB[key] = value
        end
    end

    if type(PotionSenseDB.classSpecPotionMap) ~= "table" then
        PotionSenseDB.classSpecPotionMap = {}
    end
    
    -- Initialize default potion order for all classes/specs on first load
    local classCount = GetNumClasses()
    for classIdx = 1, classCount do
        local classID = select(3, GetClassInfo(classIdx))
        if classID then
            if not PotionSenseDB.classSpecPotionMap[classID] then
                PotionSenseDB.classSpecPotionMap[classID] = {}
            end
            
            local specCount = GetNumSpecializationsForClassID(classID)
            for specIdx = 1, specCount do
                local specID, specName = GetSpecializationInfoForClassID(classID, specIdx)
                if specID then
                    local config = PotionSenseDB.classSpecPotionMap[classID][specID]
                    if not config then
                        -- New spec - initialize with ideal potion and mark as not customized
                        local idealPotion = PotionSense.IdealPotionsBySpec[specName] or "recklessness"
                        PotionSenseDB.classSpecPotionMap[classID][specID] = {
                            potionType = idealPotion,
                            preferHQ = false,
                            isCustomized = false,
                        }
                    elseif type(config) == "table" and config[1] then
                        -- Migrate old array-based config to new format
                        local idealPotion = PotionSense.IdealPotionsBySpec[specName] or "recklessness"
                        PotionSenseDB.classSpecPotionMap[classID][specID] = {
                            potionType = idealPotion,
                            preferHQ = false,
                            isCustomized = false,
                        }
                    elseif type(config) == "table" then
                        -- Ensure all fields are set
                        config.potionType = config.potionType or "recklessness"
                        config.preferHQ = config.preferHQ or false
                        
                        -- If not customized (isCustomized is false or nil), apply ideal potion
                        if not config.isCustomized then
                            local idealPotion = PotionSense.IdealPotionsBySpec[specName] or "recklessness"
                            config.potionType = idealPotion
                            config.isCustomized = false
                        end
                    end
                end
            end
        end
    end
end

local function GetCurrentClassID()
    return select(3, UnitClass("player"))
end

local function GetCurrentSpecID()
    local specIndex = GetSpecialization()
    if not specIndex or specIndex == 0 then
        return nil
    end
    return select(1, GetSpecializationInfo(specIndex))
end

local function GetAllClasses()
    local classes = {}
    local classCount = GetNumClasses()
    for classIdx = 1, classCount do
        local classLocalizedName, classToken, classID = GetClassInfo(classIdx)
        if classID then
            classes[#classes + 1] = {
                classID = classID,
                classToken = classToken,
                name = classLocalizedName,
            }
        end
    end
    return classes
end

local function GetSpecsForClass(classID)
    local specs = {}
    local specCount = GetNumSpecializationsForClassID(classID)
    for specIdx = 1, specCount do
        local specID, specName = GetSpecializationInfoForClassID(classID, specIdx)
        if specID and specName then
            specs[#specs + 1] = {
                specID = specID,
                name = specName,
                specIndex = specIdx,
            }
        end
    end
    return specs
end

local function GetPotionNameByID(itemID)
    for potionTypeKey, potionTypeData in pairs(PotionSense.POTION_TYPES) do
        for _, variant in ipairs(potionTypeData.variants) do
            if variant.itemID == itemID then
                return potionTypeData.name .. " - " .. variant.name
            end
        end
    end
    return "Unknown Potion"
end

local function GetBestAvailablePotionForSpec(classID, specID)
    if not classID or not specID then
        return nil
    end

    if not PotionSenseDB or not PotionSenseDB.classSpecPotionMap then
        return nil
    end

    if not PotionSenseDB.classSpecPotionMap[classID] then
        return nil
    end

    local config = PotionSenseDB.classSpecPotionMap[classID][specID]
    if not config then
        return nil
    end

    -- Handle old array format (migrate on the fly)
    if type(config) == "table" and config[1] then
        config = {
            potionType = "recklessness",
            preferHQ = false,
        }
        PotionSenseDB.classSpecPotionMap[classID][specID] = config
    end

    if not config.potionType then
        config.potionType = "recklessness"
    end
    if config.preferHQ == nil then
        config.preferHQ = false
    end

    local potionTypeData = PotionSense.POTION_TYPES[config.potionType]
    if not potionTypeData then
        return nil
    end

    -- Sort variants: if preferHQ, check HQ first, then normal
    local priorityOrder = {}
    if config.preferHQ then
        for _, variant in ipairs(potionTypeData.variants) do
            if variant.quality == "hq" then
                table.insert(priorityOrder, variant.itemID)
            end
        end
        for _, variant in ipairs(potionTypeData.variants) do
            if variant.quality == "normal" then
                table.insert(priorityOrder, variant.itemID)
            end
        end
    else
        for _, variant in ipairs(potionTypeData.variants) do
            table.insert(priorityOrder, variant.itemID)
        end
    end

    -- Return first available
    for _, itemID in ipairs(priorityOrder) do
        if C_Item.GetItemCount(itemID) > 0 then
            return itemID
        end
    end

    return nil
end

local function GetCurrentBestPotion()
    local classID = GetCurrentClassID()
    local specID = GetCurrentSpecID()
    return GetBestAvailablePotionForSpec(classID, specID)
end

local function BuildMacroBody(itemID)
    return "#showtooltip item:" .. itemID .. "\n/use [combat] item:" .. itemID
end

local function EnsureMacro(body, icon)
    local macroName = GetMacroName()
    if not macroName or macroName == "" then
        return nil, false
    end

    local macroIcon = icon or PotionSense.MACRO_ICON
    local macroIndex = GetMacroIndexByName(macroName)

    if macroIndex == 0 then
        local createdIndex = CreateMacro(macroName, macroIcon, body, not PotionSenseDB.useGeneralMacro)
        if createdIndex then
            DebugPrint("Created macro '" .. macroName .. "'.")
            return createdIndex, true
        end
        return nil, false
    end

    local _, existingIcon, existingBody = GetMacroInfo(macroIndex)

    if existingBody == body and existingIcon == macroIcon then
        DebugPrint("Macro already up to date.")
        return macroIndex, false
    end

    local editedIndex = EditMacro(macroIndex, nil, macroIcon, body)
    if editedIndex then
        DebugPrint("Updated macro '" .. macroName .. "'.")
        return editedIndex, true
    end

    return editedIndex, false
end

local function SetMacroToPlaceholder()
    local behavior = PotionSenseDB.noPotionBehavior

    if behavior == "clear" then
        EnsureMacro("#showtooltip", "INV_Misc_QuestionMark")
        return
    end

    if behavior == "placeholder" then
        EnsureMacro("#showtooltip\n/run print('PotionSense: No potion available in bags')", "Inv_Potion_Empty")
        print("|cffff4444PotionSense: No potion available in bags for this spec.|r")
        return
    end

    EnsureMacro("#showtooltip", "INV_Misc_QuestionMark")
end

local function UpdatePotionMacro(reason)
    if InCombatLockdown() then
        DebugPrint("Skipped update during combat" .. (reason and " (" .. reason .. ")" or "") .. ".")
        return
    end

    local potionItemID = GetCurrentBestPotion()

    if not potionItemID then
        DebugPrint("No potion available for the active spec.")
        SetMacroToPlaceholder()
        return
    end

    local macroBody = BuildMacroBody(potionItemID)
    local itemName = GetPotionNameByID(potionItemID)
    local _, wasUpdated = EnsureMacro(macroBody, GetItemIconCompat(potionItemID) or PotionSense.MACRO_ICON)
    
    -- Only show message if macro was actually updated and it's not just initialization
    if wasUpdated and reason ~= "PLAYER_LOGIN" then
        print("|cff66ccffPotionSense:|r Macro updated to " .. itemName .. ".")
    end

    local count = C_Item.GetItemCount(potionItemID)
    DebugPrint("Updated macro with: " .. itemName .. " (ID: " .. potionItemID .. ", x" .. count .. ")" .. (reason and " - " .. reason or "") .. ".")
end

-- Export to global namespace
PotionSense.DebugPrint = DebugPrint
PotionSense.GetMacroName = GetMacroName
PotionSense.InitializeDB = InitializeDB
PotionSense.GetCurrentClassID = GetCurrentClassID
PotionSense.GetCurrentSpecID = GetCurrentSpecID
PotionSense.GetAllClasses = GetAllClasses
PotionSense.GetSpecsForClass = GetSpecsForClass
PotionSense.GetPotionNameByID = GetPotionNameByID
PotionSense.GetBestAvailablePotionForSpec = GetBestAvailablePotionForSpec
PotionSense.GetCurrentBestPotion = GetCurrentBestPotion
PotionSense.BuildMacroBody = BuildMacroBody
PotionSense.EnsureMacro = EnsureMacro
PotionSense.SetMacroToPlaceholder = SetMacroToPlaceholder
PotionSense.UpdatePotionMacro = UpdatePotionMacro
