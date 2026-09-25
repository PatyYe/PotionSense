-- PotionSenseEvents.lua
-- Handles all event registration and processing

local function OnPlayerLogin()
    PotionSense.InitializeDB()
    
    local success, err = pcall(PotionSense.CreateSettingsPanel)
    if not success then
        print("|cffff4444" .. PotionSense.ADDON_NAME .. "|r: Error creating settings panel: " .. tostring(err))
    end
    
    PotionSense.UpdatePotionMacro("PLAYER_LOGIN")
    PotionSense.UpdateStatusText()
end

local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
        return
    end

    PotionSense.UpdatePotionMacro(event)
    PotionSense.UpdateStatusText()
end)

-- Slash commands
SLASH_POTIONSENSE1 = "/potionsense"
SLASH_POTIONSENSE2 = "/ps"

SlashCmdList.POTIONSENSE = function(msg)
    msg = msg and msg:lower() or ""

    if msg == "debug" then
        if not PotionSenseDB then
            print("|cffff4444" .. PotionSense.ADDON_NAME .. "|r: Database not initialized yet.")
            return
        end
        PotionSenseDB.debug = not PotionSenseDB.debug
        print("|cff66ccff" .. PotionSense.ADDON_NAME .. "|r: Debug " .. (PotionSenseDB.debug and "enabled." or "disabled."))
        
        -- Update checkbox if it exists
        if PotionSense.debugCheck then
            PotionSense.debugCheck:SetChecked(PotionSenseDB.debug)
        end
    elseif msg == "update" then
        PotionSense.UpdatePotionMacro("manual slash command")
        PotionSense.UpdateStatusText()
    elseif msg == "" then
        if PotionSense.settingsCategory then
            Settings.OpenToCategory(PotionSense.settingsCategory:GetID(), PotionSense.settingsCategory:GetID())
        else
            print("|cff66ccff" .. PotionSense.ADDON_NAME .. "|r: Settings panel not available yet. Try again in a moment.")
        end
    else
        print("|cff66ccff" .. PotionSense.ADDON_NAME .. "|r commands:")
        print("  /potionsense or /ps      - Open settings")
        print("  /potionsense update      - Force macro update")
        print("  /potionsense debug       - Toggle debug output")
    end
end
