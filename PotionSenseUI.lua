-- PotionSenseUI.lua
-- Contains all UI-related code for the settings panel

local statusText
local debugCheck
local classDropdown
local specDropdown
local potionTypeDropdown
local preferHQCheck
local currentSelectedClassID = nil
local currentSelectedSpecID = nil
local pendingRefresh = false
local pendingMacroUpdate = false

local function GetItemIconCompat(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if GetItemIcon then
        return GetItemIcon(itemID)
    end
    return nil
end

local function EnsureUIDropDownMenuAPI()
    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and
       UIDropDownMenu_SetWidth and UIDropDownMenu_SetSelectedValue then
        return true
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_UIDropDownMenu")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_UIDropDownMenu")
    end

    return UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton and
           UIDropDownMenu_SetWidth and UIDropDownMenu_SetSelectedValue
end

-- Create a timer frame for deferred execution
local timerFrame = CreateFrame("Frame")

local function UpdateStatusText()
    if not statusText then
        return
    end

    local classID = PotionSense.GetCurrentClassID()
    local specID = PotionSense.GetCurrentSpecID()
    local potionID = PotionSense.GetCurrentBestPotion()
    
    if potionID then
        local name = PotionSense.GetPotionNameByID(potionID)
        local count = C_Item.GetItemCount(potionID)

        statusText:SetText("Status: Using " .. name .. " (x" .. count .. ")")
        statusText:SetTextColor(0.4, 1, 0.4)
        PotionSense.DebugPrint("Status updated: Using " .. name .. " (x" .. count .. ")")
    else
        local config = classID and specID and PotionSenseDB.classSpecPotionMap[classID] and PotionSenseDB.classSpecPotionMap[classID][specID]
        local potionType = config and config.potionType or "unknown"
        statusText:SetText("Status: No " .. potionType .. " potion in bags")
        statusText:SetTextColor(1, 0.3, 0.3)
        PotionSense.DebugPrint("No potion found. Config: " .. (config and "potionType=" .. potionType .. ", preferHQ=" .. tostring(config.preferHQ) or "no config"))
    end
end

local function RefreshSpecDropdown()
    if not specDropdown or not currentSelectedClassID then
        return
    end

    -- Recalculate spec dropdown width for new class
    local newSpecs = PotionSense.GetSpecsForClass(currentSelectedClassID)
    UIDropDownMenu_SetWidth(specDropdown, 220)

    UIDropDownMenu_Initialize(specDropdown, function(self, level)
        local specs = PotionSense.GetSpecsForClass(currentSelectedClassID)
        if not specs or #specs == 0 then
            return
        end
        
        for _, specInfo in ipairs(specs) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = specInfo.name
            -- Try to get spec icon
            if specInfo.specIndex then
                local _, _, _, specIcon = GetSpecializationInfoForClassID(currentSelectedClassID, specInfo.specIndex)
                if specIcon then
                    info.icon = specIcon
                end
            end
            info.value = specInfo.specID
            info.checked = specInfo.specID == currentSelectedSpecID
            info.func = function()
                -- Ensure database structure exists before updating
                if not PotionSenseDB or not PotionSenseDB.classSpecPotionMap or not PotionSenseDB.classSpecPotionMap[currentSelectedClassID] then
                    PotionSense.InitializeDB()
                end
                currentSelectedSpecID = specInfo.specID
                UIDropDownMenu_SetSelectedValue(specDropdown, specInfo.specID)
                specDropdown.Text:SetText(specInfo.name)
                
                -- Flag for deferred refresh
                pendingRefresh = true
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    if currentSelectedSpecID then
        UIDropDownMenu_SetSelectedValue(specDropdown, currentSelectedSpecID)
        -- Find and display the spec name
        local specs = PotionSense.GetSpecsForClass(currentSelectedClassID)
        for _, specInfo in ipairs(specs) do
            if specInfo.specID == currentSelectedSpecID then
                specDropdown.Text:SetText(specInfo.name)
                break
            end
        end
    end
end

local function RefreshPotionConfigDisplay()
    if not currentSelectedClassID or not currentSelectedSpecID then
        return
    end

    -- Ensure database is initialized for this class/spec
    if not PotionSenseDB or not PotionSenseDB.classSpecPotionMap then
        return
    end
    
    if not PotionSenseDB.classSpecPotionMap[currentSelectedClassID] then
        PotionSense.InitializeDB()
    end

    local config = PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID]
    if not config then
        return
    end

    -- Ensure config has the right structure
    if type(config) == "table" and config[1] then
        -- Migrate old format
        config = {
            potionType = "recklessness",
            preferHQ = false,
            isCustomized = false,
        }
        PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID] = config
    end

    if not config.potionType then
        config.potionType = "recklessness"
    end
    if config.preferHQ == nil then
        config.preferHQ = false
    end
    if config.isCustomized == nil then
        config.isCustomized = false
    end

    -- Update potion type dropdown
    if potionTypeDropdown then
        -- Clear the dropdown state to ensure fresh initialization
        potionTypeDropdown.selectedValue = nil
        
        UIDropDownMenu_Initialize(potionTypeDropdown, function(self, level)
            for potionTypeKey, potionTypeData in pairs(PotionSense.POTION_TYPES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = potionTypeData.name
                -- Try to get potion icon from first variant
                if potionTypeData.variants and potionTypeData.variants[1] then
                    local itemIcon = GetItemIconCompat(potionTypeData.variants[1].itemID)
                    if itemIcon then
                        info.icon = itemIcon
                    end
                end
                info.value = potionTypeKey
                info.checked = potionTypeKey == config.potionType
                info.func = function()
                    -- Directly save to database to ensure persistence
                    if PotionSenseDB and PotionSenseDB.classSpecPotionMap and 
                       PotionSenseDB.classSpecPotionMap[currentSelectedClassID] and
                       PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID] then
                        PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID].potionType = potionTypeKey
                        PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID].isCustomized = true
                        UIDropDownMenu_SetSelectedValue(potionTypeDropdown, potionTypeKey)
                        potionTypeDropdown.Text:SetText(potionTypeData.name)
                        pendingMacroUpdate = true
                    end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        UIDropDownMenu_SetSelectedValue(potionTypeDropdown, config.potionType or "recklessness")
        -- Update button display for potion type
        for potionTypeKey, potionTypeData in pairs(PotionSense.POTION_TYPES) do
            if potionTypeKey == config.potionType then
                potionTypeDropdown.Text:SetText(potionTypeData.name)
                break
            end
        end
    end

    -- Update HQ checkbox
    if preferHQCheck then
        preferHQCheck:SetChecked(config.preferHQ or false)
        preferHQCheck:SetScript("OnClick", function(self)
            if PotionSenseDB and PotionSenseDB.classSpecPotionMap and 
               PotionSenseDB.classSpecPotionMap[currentSelectedClassID] and
               PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID] then
                PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID].preferHQ = self:GetChecked()
                PotionSenseDB.classSpecPotionMap[currentSelectedClassID][currentSelectedSpecID].isCustomized = true
                pendingMacroUpdate = true
            end
        end)
    end
end

local settingsCategory

local function CreateSettingsPanel()
    local categoryName = "PotionSense"

    if not EnsureUIDropDownMenuAPI() then
        error("PotionSense: UIDropDownMenu API is unavailable.")
    end

    local canvas = CreateFrame("Frame")
    canvas.name = categoryName

    -- Logo
    local logo = canvas:CreateTexture(nil, "ARTWORK")
    logo:SetSize(64, 64)
    logo:SetPoint("TOPLEFT", 16, -16)
    logo:SetTexture("Interface\\AddOns\\PotionSense\\Media\\PotionSenseIcon.tga")

    local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 16, 0)
    title:SetText(categoryName)

    local subtitle = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure potion priorities for each class and specialization.")

    local note = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    note:SetText("Select your class and specialization below, then choose your preferred potion.")
    note:SetTextColor(1, 0.82, 0)

    debugCheck = CreateFrame("CheckButton", nil, canvas, "InterfaceOptionsCheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -24)
    debugCheck.Text:SetText("Enable debug output (to chat console). Only enable when troubleshooting.")
    debugCheck:SetChecked(PotionSenseDB.debug)
    debugCheck:SetScript("OnClick", function(self)
        PotionSenseDB.debug = self:GetChecked()
    end)
    PotionSense.debugCheck = debugCheck

    local classLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    classLabel:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 0, -24)
    classLabel:SetText("Select Class:")

    classDropdown = CreateFrame("Frame", nil, canvas, "UIDropDownMenuTemplate")
    classDropdown:SetPoint("TOPLEFT", classLabel, "BOTTOMLEFT", -16, -4)
    classDropdown.Text:SetJustifyH("LEFT")
    UIDropDownMenu_SetWidth(classDropdown, 220)

    local specLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    specLabel:SetPoint("TOPLEFT", classDropdown, "BOTTOMLEFT", 16, -18)
    specLabel:SetText("Select Specialization:")

    specDropdown = CreateFrame("Frame", nil, canvas, "UIDropDownMenuTemplate")
    specDropdown:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", -16, -4)
    specDropdown.Text:SetJustifyH("LEFT")
    UIDropDownMenu_SetWidth(specDropdown, 220)

    local potionTypeLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    potionTypeLabel:SetPoint("TOPLEFT", specDropdown, "BOTTOMLEFT", 16, -18)
    potionTypeLabel:SetText("Potion Type:")

    potionTypeDropdown = CreateFrame("Frame", nil, canvas, "UIDropDownMenuTemplate")
    potionTypeDropdown:SetPoint("TOPLEFT", potionTypeLabel, "BOTTOMLEFT", -16, -4)
    UIDropDownMenu_SetWidth(potionTypeDropdown, 220)
    potionTypeDropdown.Text:SetJustifyH("LEFT")

    preferHQCheck = CreateFrame("CheckButton", nil, canvas, "InterfaceOptionsCheckButtonTemplate")
    preferHQCheck:SetPoint("TOPLEFT", potionTypeDropdown, "BOTTOMLEFT", 16, -12)
    preferHQCheck.Text:SetText("Prefer High Quality over Standard")
    preferHQCheck:SetChecked(false)

    local saveButton = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    saveButton:SetSize(140, 24)
    saveButton:SetPoint("TOPLEFT", preferHQCheck, "BOTTOMLEFT", 0, -12)
    saveButton:SetText("Update Macro Now")
    saveButton:SetScript("OnClick", function()
        PotionSense.UpdatePotionMacro("settings button")
        UpdateStatusText()
    end)

    statusText = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", saveButton, "BOTTOMLEFT", 0, -16)
    statusText:SetText("Status: Loading...")

    -- Populate class dropdown
    UIDropDownMenu_Initialize(classDropdown, function(self, level)
        local allClasses = PotionSense.GetAllClasses()
        for _, classInfo in ipairs(allClasses) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = classInfo.name
            info.value = classInfo.classID
            info.checked = classInfo.classID == currentSelectedClassID
            info.func = function()
                currentSelectedClassID = classInfo.classID
                UIDropDownMenu_SetSelectedValue(classDropdown, classInfo.classID)
                classDropdown.Text:SetText(classInfo.name)

                -- Reset spec dropdown and refresh it
                currentSelectedSpecID = nil
                RefreshSpecDropdown()

                -- Auto-select first spec
                local specs = PotionSense.GetSpecsForClass(classInfo.classID)
                if #specs > 0 then
                    currentSelectedSpecID = specs[1].specID
                    UIDropDownMenu_SetSelectedValue(specDropdown, specs[1].specID)
                    RefreshPotionConfigDisplay()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Set initial class (always use current player's class)
    currentSelectedClassID = PotionSense.GetCurrentClassID()
    if currentSelectedClassID then
        UIDropDownMenu_SetSelectedValue(classDropdown, currentSelectedClassID)
        -- Update button text for initial class
        local allClasses = PotionSense.GetAllClasses()
        for _, classInfo in ipairs(allClasses) do
            if classInfo.classID == currentSelectedClassID then
                classDropdown.Text:SetText(classInfo.name)
                break
            end
        end

        -- Set initial spec (always use current player's spec)
        local specs = PotionSense.GetSpecsForClass(currentSelectedClassID)
        local currentSpecID = PotionSense.GetCurrentSpecID()
        if currentSpecID and #specs > 0 then
            currentSelectedSpecID = currentSpecID
        elseif #specs > 0 then
            currentSelectedSpecID = specs[1].specID
        end
        if currentSelectedSpecID then
            UIDropDownMenu_SetSelectedValue(specDropdown, currentSelectedSpecID)
        end
    end

    -- Populate initial spec dropdown
    RefreshSpecDropdown()

    RefreshPotionConfigDisplay()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(canvas, categoryName, categoryName)
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
        settingsCategory = category
        PotionSense.settingsCategory = category
    end

    -- Creator and contact info at the bottom
    local creatorInfo = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    creatorInfo:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 16, 16)
    creatorInfo:SetText("Made by PatyYe")

    UpdateStatusText()
end

-- Timer frame for deferred UI refresh
timerFrame:SetScript("OnUpdate", function()
    if pendingMacroUpdate then
        pendingMacroUpdate = false
        PotionSense.UpdatePotionMacro("settings changed")
        UpdateStatusText()
    end
    
    if pendingRefresh then
        pendingRefresh = false
        RefreshPotionConfigDisplay()
    end
end)

-- Export to global namespace
PotionSense.UpdateStatusText = UpdateStatusText
PotionSense.RefreshSpecDropdown = RefreshSpecDropdown
PotionSense.RefreshPotionConfigDisplay = RefreshPotionConfigDisplay
PotionSense.CreateSettingsPanel = CreateSettingsPanel
