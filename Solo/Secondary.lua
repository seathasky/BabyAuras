local _, addon = ...

local Solo = addon.Solo
local IsSoloEnabled = addon.SoloUtilities.IsSoloEnabled

local function Accessible(value)
    if addon:IsSecret(value) then return false end
    return not canaccessvalue or canaccessvalue(value)
end

function Solo:GetDisplayKey(cooldownID, copyIndex)
    if copyIndex == 2 then return tostring(cooldownID) .. ":secondary" end
    return cooldownID
end

function Solo:IsSecondaryEnabled(entry)
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    return IsSoloEnabled(entry) and settings and settings.secondaryIconEnabled == true or false
end

local function AddSpellID(ids, seen, spellID)
    if Accessible(spellID) and type(spellID) == "number" and not seen[spellID] then
        seen[spellID] = true
        ids[#ids + 1] = spellID
    end
end

local function GetAuraDuration(entry)
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID
        or not C_UnitAuras.GetAuraDuration then
        return nil
    end
    local ids, seen = {}, {}
    local info = entry and entry.info or {}
    AddSpellID(ids, seen, info.linkedSpellID)
    if type(info.linkedSpellIDs) == "table" then
        for _, spellID in ipairs(info.linkedSpellIDs) do AddSpellID(ids, seen, spellID) end
    end
    AddSpellID(ids, seen, info.overrideTooltipSpellID)
    AddSpellID(ids, seen, info.overrideSpellID)
    AddSpellID(ids, seen, info.spellID)
    AddSpellID(ids, seen, entry and entry.spellID)
    for _, spellID in ipairs(ids) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        local instanceID = ok and aura and aura.auraInstanceID
        if Accessible(instanceID) and type(instanceID) == "number" then
            local durationOK, duration = pcall(C_UnitAuras.GetAuraDuration, "player", instanceID)
            if durationOK and duration then return duration end
        end
    end
end

local function GetSpellDuration(entry)
    if not C_Spell or not C_Spell.GetSpellCooldownDuration then return nil end
    local info = entry and entry.info or {}
    local spellID = info.overrideSpellID or info.spellID or (entry and entry.spellID)
    if not Accessible(spellID) or type(spellID) ~= "number" then return nil end
    local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    return ok and duration or nil
end

function Solo:SyncSecondaryTimer(display)
    if not display or not display.isSecondary or not display.Cooldown then return end
    local cooldown = display.Cooldown
    local duration = GetAuraDuration(display.entry)
    local reverse = duration ~= nil
    duration = duration or GetSpellDuration(display.entry)
    if duration and type(cooldown.SetCooldownFromDurationObject) == "function" then
        pcall(cooldown.SetUseAuraDisplayTime, cooldown, reverse)
        pcall(cooldown.SetReverse, cooldown, reverse)
        local ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)
        if ok then
            cooldown:Show()
            return
        end
    end
    if type(cooldown.Clear) == "function" then pcall(cooldown.Clear, cooldown) end
end

function Solo:ReleaseSecondaryDisplay(cooldownID)
    local key = self:GetDisplayKey(cooldownID, 2)
    local display = self.displays[key]
    self.sources[key] = nil
    if not display then return end
    display.active = false
    display.activeState = false
    if display.Cooldown and type(display.Cooldown.Clear) == "function" then
        pcall(display.Cooldown.Clear, display.Cooldown)
    end
    display:Hide()
end

function Solo:RefreshSecondaryDisplay(entry, item, primary)
    if not entry or not self:IsSecondaryEnabled(entry) then
        if entry then self:ReleaseSecondaryDisplay(entry.cooldownID) end
        return nil
    end
    if not item then item = addon.Runtime and addon.Runtime:GetLiveItem(entry.cooldownID) end
    if not primary then primary = self.displays[entry.cooldownID] end
    if not primary then return nil end

    local key = self:GetDisplayKey(entry.cooldownID, 2)
    local display = self.displays[key]
    local isBar = item and self:IsTrackedBarItem(item) or false
    if display and display.isBar ~= isBar then
        display:Hide()
        self.displays[key] = nil
        display = nil
    end
    if not display then
        local settings = addon:GetEntrySettings(entry.cooldownID, true)
        if not settings.secondarySoloPosition then
            settings.secondarySoloPosition = self:GetDefaultPosition(entry, item, 2)
        end
        display = self:CreateDisplay(entry, item, 2)
    end
    display.entry = entry
    display.active = primary.active == true
    display.activeState = primary.activeState == true
    self.sources[key] = item
    self:ApplyDisplayScale(display)
    self:SyncSecondaryTimer(display)
    self:RefreshDisplay(display)
    return display
end
