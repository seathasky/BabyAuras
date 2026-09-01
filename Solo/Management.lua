local _, addon = ...

local Solo = addon.Solo
local Defaults = addon.Defaults
local IsSoloEnabled = addon.SoloUtilities.IsSoloEnabled

function Solo:GetViewer(item)
    if not item or type(item.GetViewerFrame) ~= "function" then return false end
    local ok, viewer = pcall(item.GetViewerFrame, item)
    return ok and viewer or nil
end

function Solo:IsSupportedItem(item)
    local viewer = self:GetViewer(item)
    return viewer == _G.EssentialCooldownViewer
        or viewer == _G.UtilityCooldownViewer
        or viewer == _G.BuffIconCooldownViewer
        or viewer == _G.BuffBarCooldownViewer
end

function Solo:IsTrackedBarItem(item)
    return self:GetViewer(item) == _G.BuffBarCooldownViewer
end

function Solo:IsEligible(entry)
    if not entry then return false end
    local item = addon.Runtime and addon.Runtime:GetLiveItem(entry.cooldownID)
    return item and self:IsSupportedItem(item) or false
end

function Solo:GetTexture(entry, display)
    if display and display.isSecondary then
        local settings = addon:GetEntrySettings(entry.cooldownID, false)
        local spellID = settings and tonumber(settings.secondaryCustomIconSpellID)
        if spellID and C_Spell and C_Spell.GetSpellTexture then
            local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
            if ok and texture then return texture end
        end
        return entry.originalIcon or entry.icon
    end
    local customIcon = entry and addon.Catalog:GetCustomIcon(entry)
    if customIcon then return customIcon end
    local item = entry and addon.Runtime and addon.Runtime:GetLiveItem(entry.cooldownID)
    if item and type(item.GetSpellTexture) == "function" then
        local ok, texture = pcall(item.GetSpellTexture, item)
        if ok and texture and not addon:IsSecret(texture) and (not canaccessvalue or canaccessvalue(texture)) then
            return texture
        end
    end
    if item and type(item.GetIconTexture) == "function" then
        local ok, region = pcall(item.GetIconTexture, item)
        if ok and region and type(region.GetTexture) == "function" then
            local ok2, texture = pcall(region.GetTexture, region)
            if ok2 and texture and not addon:IsSecret(texture) and (not canaccessvalue or canaccessvalue(texture)) then
                return texture
            end
        end
    end
    return addon.Catalog:GetDisplayIcon(entry)
end

function Solo:SetSourceHidden(item, hidden)
    if not item or not item.SetAlpha then return end
    if self:IsNativeHosted(item) then
        local display = self:GetNativeHostDisplay(item)
        if display then self:UpdateNativeVisibility(display) end
        return
    end
    item:SetAlpha(hidden and 0 or 1)
end

function Solo:EnsureDisplay(entry, item, deferRefresh)
    local display = self.displays[entry.cooldownID]
    local itemIsBar = item and self:IsTrackedBarItem(item) or false
    if display and item and display.isBar ~= itemIsBar then
        if display.isDragging then
            display:StopMovingOrSizing()
            display.isDragging = nil
            self:SaveDisplayPosition(display)
        end
        self:ClearSnap(display)
        if display.LiveCooldown or display.NativeItem then self:DetachLiveCooldown(display) end
        if addon.Effects then addon.Effects:HideGlow(item) end
        display:Hide()
        if display.EditOutline then display.EditOutline:Hide() end
        display:SetScript("OnDragStart", nil)
        display:SetScript("OnDragStop", nil)
        display:SetScript("OnUpdate", nil)
        display:SetScript("OnClick", nil)
        display:SetScript("OnEnter", nil)
        display:SetScript("OnLeave", nil)
        self.displays[entry.cooldownID] = nil
        display = self:CreateDisplay(entry, item)
    elseif not display then
        display = self:CreateDisplay(entry, item)
    end
    display.entry = entry
    self:ApplyDisplayScale(display)
    if item then
        self.sources[entry.cooldownID] = item
        if display.NativeItem ~= item or not self:IsNativeHosted(item) then
            self:InstallMirrors(item, display)
        end
    end
    if not deferRefresh then self:RefreshDisplay(display) end
    return display
end

function Solo:SyncFromItem(item)
    local entry = addon.Runtime.itemEntries[item]
    if not entry or not IsSoloEnabled(entry) or not self:IsSupportedItem(item) then return end
    local display = self:EnsureDisplay(entry, item, true)
    if type(item.IsActive) == "function" then
        local ok, active = pcall(item.IsActive, item)
        if ok and not addon:IsSecret(active) then display.active = active == true end
    end
    self:UpdateActiveState(item, display)
    self:RefreshDisplay(display)
    if self.RefreshSecondaryDisplay then self:RefreshSecondaryDisplay(entry, item, display) end
end

function Solo:OnTrigger(item, trigger)
    local entry = addon.Runtime.itemEntries[item]
    if not entry or not IsSoloEnabled(entry) then return end
    local display = self:EnsureDisplay(entry, item, true)
    if trigger == Enum.CooldownViewerAlertEventType.OnAuraApplied then
        display.active = true
        display.activeState = true
    elseif trigger == Enum.CooldownViewerAlertEventType.OnAuraRemoved then
        display.active = false
        display.activeState = false
    end
    self:RefreshDisplay(display)
    if self.RefreshSecondaryDisplay then self:RefreshSecondaryDisplay(entry, item, display) end
end

function Solo:RefreshItem(item)
    local entry = addon.Runtime.itemEntries[item]
    local oldCooldownID = self.itemCooldownIDs[item]
    if oldCooldownID and (not entry or oldCooldownID ~= entry.cooldownID) then
        local oldDisplay = self.displays[oldCooldownID]
        if self.sources[oldCooldownID] == item then
            if oldDisplay and (oldDisplay.LiveCooldown or oldDisplay.NativeItem) then
                self:DetachLiveCooldown(oldDisplay)
            end
            if addon.Effects then addon.Effects:HideGlow(item) end
            self.sources[oldCooldownID] = nil
            if oldDisplay then
                oldDisplay.active = false
                oldDisplay.activeState = false
                oldDisplay:Hide()
            end
            if addon.ActionBarGlow then addon.ActionBarGlow:ClearEntry(oldCooldownID) end
            if self.ReleaseSecondaryDisplay then self:ReleaseSecondaryDisplay(oldCooldownID) end
        end
        self:SetSourceHidden(item, false)
    end
    self.itemCooldownIDs[item] = entry and entry.cooldownID or nil

    if not entry or not self:IsSupportedItem(item) then return end
    if IsSoloEnabled(entry) then
        local previousSource = self.sources[entry.cooldownID]
        if previousSource and previousSource ~= item then
            local display = self.displays[entry.cooldownID]
            if display and (display.LiveCooldown or display.NativeItem) then self:DetachLiveCooldown(display) end
            if addon.Effects then addon.Effects:HideGlow(previousSource) end
            self:SetSourceHidden(previousSource, false)
        end
        self.sources[entry.cooldownID] = item
        self:SetSourceHidden(item, not self.suspended)
        self:SyncFromItem(item)
    else
        self:SetSourceHidden(item, false)
        if self.ReleaseSecondaryDisplay then self:ReleaseSecondaryDisplay(entry.cooldownID) end
    end
end

function Solo:ReleaseItem(item)
    local cooldownID = self.itemCooldownIDs[item]
    local display = cooldownID and self.displays[cooldownID]
    if cooldownID and self.sources[cooldownID] == item then
        if display and (display.LiveCooldown or display.NativeItem) then self:DetachLiveCooldown(display) end
        if addon.Effects then addon.Effects:HideGlow(item) end
        self.sources[cooldownID] = nil
        if display then
            display.active = false
            display.activeState = false
            display:Hide()
        end
        if addon.ActionBarGlow then addon.ActionBarGlow:ClearEntry(cooldownID) end
        if self.ReleaseSecondaryDisplay then self:ReleaseSecondaryDisplay(cooldownID) end
    end
    self.itemCooldownIDs[item] = nil
    self:SetSourceHidden(item, false)
end

function Solo:ReconcileDisplays()
    for cooldownID, display in pairs(self.displays) do
        local item = self.sources[cooldownID]
        local entry = item and addon.Runtime.itemEntries[item]
        local specPreview = display.specPreviewOnly and self.IsSpecPreviewEnabled and self:IsSpecPreviewEnabled(display.entry)
        if specPreview then
            display.active = false
            display.activeState = false
            self:RefreshDisplay(display)
        elseif not entry or entry.cooldownID ~= display.entry.cooldownID then
            if display.LiveCooldown or display.NativeItem then self:DetachLiveCooldown(display) end
            if addon.Effects then
                if item then
                    addon.Effects:HideGlow(item)
                else
                    addon.Effects:HideGlowTarget(display)
                    if display.ProcGlowTarget then
                        addon.Effects:HideGlowTarget(display.ProcGlowTarget)
                    end
                end
            end
            self.sources[cooldownID] = nil
            display.active = false
            display.activeState = false
            display:Hide()
            if not display.isSecondary and addon.ActionBarGlow then
                addon.ActionBarGlow:ClearEntry(cooldownID)
            end
        else
            display.specPreviewOnly = nil
            display.specPreviewSpecID = nil
            display.entry = entry
            self:RefreshDisplay(display)
            if not display.isSecondary and self.RefreshSecondaryDisplay then
                self:RefreshSecondaryDisplay(entry, item, display)
            end
        end
    end
    if self.RefreshSpecPreviewDisplays then self:RefreshSpecPreviewDisplays() end
end

function Solo:SetEnabled(entry, enabled)
    if InCombatLockdown() then return false, "Solo icons cannot be changed during combat." end
    if enabled and not self:IsEligible(entry) then
        return false, "Solo is available only for live Blizzard Cooldown Manager elements."
    end

    local settings = addon:GetEntrySettings(entry.cooldownID, true)
    local item = addon.Runtime:GetLiveItem(entry.cooldownID)
    local currentSpecID = addon:GetCurrentSpecID()
    if not currentSpecID then return false, "Solo requires an active specialization." end
    local specKey = tostring(currentSpecID)
    if type(settings.soloSpecs) ~= "table" then
        settings.soloSpecs = {}
        if settings.soloSpecID ~= nil then
            settings.soloSpecs[tostring(settings.soloSpecID)] = true
            settings.soloSpecID = nil
        end
    end
    if enabled then
        settings.soloSpecs[specKey] = true
        settings.solo = true
        if settings.soloBlackBorder == nil then
            settings.soloBlackBorder = item and self:IsTrackedBarItem(item)
                and false or Defaults.soloAppearance.blackBorder
        end
        if settings.soloBorderPixels == nil then
            settings.soloBorderPixels = Defaults.soloAppearance.borderPixels
        end
    end
    if enabled then
        if not settings.soloPosition then
            settings.soloPosition = self:GetDefaultPosition(entry, item)
        end
        self:GetPosition(entry, true)
        self:EnsureDisplay(entry, item)
        if item then
            self:SetSourceHidden(item, not self.suspended)
            self:SyncFromItem(item)
        end
    else
        settings.soloSpecs[specKey] = nil
        settings.solo = next(settings.soloSpecs) ~= nil
        self:RemoveFromLinkGroup(entry)
        local display = self.displays[entry.cooldownID]
        local source = item or self.sources[entry.cooldownID]
        if addon.Effects and source then addon.Effects:HideGlow(source) end
        if display then
            self:DetachLiveCooldown(display)
            display:Hide()
        end
        if addon.ActionBarGlow then addon.ActionBarGlow:ClearEntry(entry.cooldownID) end
        if self.ReleaseSecondaryDisplay then self:ReleaseSecondaryDisplay(entry.cooldownID) end
        self:SetSourceHidden(source, false)
    end
    return true
end
