local addonName, addon = ...

_G.BabyAuras = addon

addon.name = addonName
addon.version = C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata(addonName, "Version")
    or GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")
    or "dev"

addon.TriggerOrder = {
    Enum.CooldownViewerAlertEventType.Available,
    Enum.CooldownViewerAlertEventType.OnCooldown,
    Enum.CooldownViewerAlertEventType.ChargeGained,
    Enum.CooldownViewerAlertEventType.OnAuraApplied,
    Enum.CooldownViewerAlertEventType.OnAuraRemoved,
    Enum.CooldownViewerAlertEventType.PandemicTime,
}

addon.TriggerNames = {
    [Enum.CooldownViewerAlertEventType.Available] = "Cooldown Ready",
    [Enum.CooldownViewerAlertEventType.OnCooldown] = "Cooldown Started",
    [Enum.CooldownViewerAlertEventType.ChargeGained] = "Charge Gained",
    [Enum.CooldownViewerAlertEventType.OnAuraApplied] = "Aura Gained",
    [Enum.CooldownViewerAlertEventType.OnAuraRemoved] = "Aura Lost",
    [Enum.CooldownViewerAlertEventType.PandemicTime] = "Pandemic Window",
}

-- One configuration page per Cooldown Manager element. Blizzard still exposes
-- several alert event variants internally; Baby Auras deterministically uses
-- the same first supported event older versions selected by default.
function addon:GetPrimaryTrigger(entry)
    if not entry or type(entry.validTriggers) ~= "table" then return nil end
    for _, trigger in ipairs(self.TriggerOrder) do
        if entry.validTriggers[trigger] then return trigger end
    end
    return nil
end

function addon:IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

function addon:TryMethod(object, methodName)
    if not object or type(object[methodName]) ~= "function" then
        return false, nil
    end
    return pcall(object[methodName], object)
end

function addon:GetCurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex) or nil
end

function addon:GetProfile()
    local classID = select(3, UnitClass("player")) or 0
    local specID = self:GetCurrentSpecID() or 0
    local classKey = tostring(classID)

    if not BabyAurasDB.profiles[classKey] then
        local classProfile = { entries = {} }
        local currentSpecKey = classID .. ":" .. specID
        local currentSpecProfile = BabyAurasDB.profiles[currentSpecKey]

        -- Migrate the active spec first so it wins conflicts, then fill in
        -- entries unique to the class's other legacy spec profiles.
        if type(currentSpecProfile) == "table" and type(currentSpecProfile.entries) == "table" then
            for cooldownID, settings in pairs(currentSpecProfile.entries) do
                classProfile.entries[cooldownID] = settings
            end
        end
        for profileKey, profile in pairs(BabyAurasDB.profiles) do
            local legacyClassID = type(profileKey) == "string" and profileKey:match("^(%d+):")
            if tonumber(legacyClassID) == classID
                and type(profile) == "table" and type(profile.entries) == "table" then
                for cooldownID, settings in pairs(profile.entries) do
                    if classProfile.entries[cooldownID] == nil then
                        classProfile.entries[cooldownID] = settings
                    end
                end
            end
        end
        BabyAurasDB.profiles[classKey] = classProfile
    end

    BabyAurasDB.profiles[classKey].entries = type(BabyAurasDB.profiles[classKey].entries) == "table"
        and BabyAurasDB.profiles[classKey].entries or {}
    return BabyAurasDB.profiles[classKey]
end

function addon:GetEntrySettings(cooldownID, create)
    local entries = self:GetProfile().entries
    local key = tostring(cooldownID)
    if create and not entries[key] then
        entries[key] = { triggers = {}, customIconSpellID = nil }
    end
    return entries[key]
end

function addon:GetTriggerSettings(cooldownID, trigger, create)
    local entry = self:GetEntrySettings(cooldownID, create)
    if not entry then return nil end
    local key = tostring(trigger)
    if create and not entry.triggers[key] then
        entry.triggers[key] = self.Defaults:CreateTrigger()
    end
    return entry.triggers[key]
end

function addon:InitializeDB()
    BabyAurasDB = self.Defaults:InitializeDatabase(BabyAurasDB)
end

function addon:RefreshAll()
    self.Catalog:Build()
    self.Runtime:Install()
    if self.ActionBarGlow then self.ActionBarGlow:RefreshAll() end
    if self.GUI then self.GUI:Refresh() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
events:RegisterEvent("COOLDOWN_VIEWER_TABLE_HOTFIXED")
events:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        addon:InitializeDB()
        addon.GUI:Create()
        addon.Minimap:Initialize()
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(1, function() addon:RefreshAll() end)
        print("|cFF66FF66Baby Auras loaded.|r Type /ba")
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then
        return
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if addon.GUI and addon.GUI.ResetSpecIconPreviews then addon.GUI:ResetSpecIconPreviews() end
        C_Timer.After(0.2, function() addon:RefreshAll() end)
        C_Timer.After(1.0, function() addon:RefreshAll() end)
    elseif event ~= "ADDON_LOADED" then
        if addon.Runtime and addon.Runtime.ScheduleCDMRefresh then
            addon.Runtime:ScheduleCDMRefresh()
        else
            C_Timer.After(0.5, function() addon:RefreshAll() end)
        end
    end
end)

SLASH_BABYAURAS1 = "/ba"
SLASH_BABYAURAS2 = "/babyauras"
SlashCmdList.BABYAURAS = function(message)
    if strtrim(message or ""):lower() == "rescan" then
        addon:RefreshAll()
        print("|cFF66FF66Baby Auras:|r catalog and live frames rescanned.")
        return
    end
    addon.GUI:Toggle()
end
