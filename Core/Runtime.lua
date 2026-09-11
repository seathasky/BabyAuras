local _, addon = ...

addon.Runtime = {
    viewers = {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        "BuffIconCooldownViewer",
        "BuffBarCooldownViewer",
    },
    hookedItems = setmetatable({}, { __mode = "k" }),
    itemEntries = setmetatable({}, { __mode = "k" }),
    hookedViewers = setmetatable({}, { __mode = "k" }),
}
local Runtime = addon.Runtime

local function GetItemViewer(item)
    return addon.Solo and addon.Solo:GetViewer(item) or nil
end

local function GetSourcePriority(item, entry)
    local viewer = GetItemViewer(item)
    if entry and entry.category == Enum.CooldownViewerCategory.TrackedBuff then
        return viewer == _G.BuffIconCooldownViewer and 100 or 0
    elseif entry and entry.category == Enum.CooldownViewerCategory.TrackedBar then
        return viewer == _G.BuffBarCooldownViewer and 100 or 0
    end
    return item and item.IsShown and item:IsShown() and 10 or 1
end

Runtime.sectionDefinitions = {
    { key = "essential", name = "Essential Cooldowns", viewer = "EssentialCooldownViewer" },
    { key = "utility", name = "Utility Cooldowns", viewer = "UtilityCooldownViewer" },
    { key = "trackedBuffs", name = "Tracked Buffs", viewer = "BuffIconCooldownViewer" },
    { key = "trackedBars", name = "Tracked Bars", viewer = "BuffBarCooldownViewer" },
}

function Runtime:ResolveItem(item)
    local ok, cooldownID = addon:TryMethod(item, "GetCooldownID")
    if not ok or addon:IsSecret(cooldownID) or type(cooldownID) ~= "number" then return nil end
    return addon.Catalog:Get(cooldownID)
end

function Runtime:ApplyCustomIcon(item)
    addon.Solo:RefreshItem(item)
end

function Runtime:RefreshItem(item)
    self.itemEntries[item] = self:ResolveItem(item)
    self:ApplyCustomIcon(item)
end

function Runtime:QueueItemRefresh(item, syncOnly)
    if not item then return end
    self.pendingItemRefreshes = self.pendingItemRefreshes or setmetatable({}, { __mode = "k" })
    local pending = self.pendingItemRefreshes[item]
    if pending then
        if not syncOnly then pending.full = true end
        return
    end
    pending = { full = not syncOnly }
    self.pendingItemRefreshes[item] = pending
    C_Timer.After(0, function()
        Runtime.pendingItemRefreshes[item] = nil
        if pending.full then
            Runtime:HookItem(item)
        elseif Runtime.itemEntries[item] then
            addon.Solo:SyncFromItem(item)
        end
    end)
end

function Runtime:Dispatch(item, trigger)
    local entry = self.itemEntries[item]
    if not entry then return end
    if trigger ~= addon:GetPrimaryTrigger(entry) then return end
    if addon.NativeCooldownTriggers
        and addon.NativeCooldownTriggers:IsManagedTrigger(entry, trigger) then
        if trigger == Enum.CooldownViewerAlertEventType.ChargeGained then
            addon.NativeCooldownTriggers:HandleNativeChargeGained(entry)
        elseif trigger == Enum.CooldownViewerAlertEventType.OnCooldown then
            addon.NativeCooldownTriggers:HandleNativeStarted(entry)
        end
        return
    end
    addon.Solo:OnTrigger(item, trigger)
    if trigger == Enum.CooldownViewerAlertEventType.OnCooldown
        or trigger == Enum.CooldownViewerAlertEventType.OnAuraApplied
        or trigger == Enum.CooldownViewerAlertEventType.OnAuraRemoved then
        addon.Effects:HideGlow(item)
    end
    local settings = addon:GetTriggerSettings(entry.cooldownID, trigger, false)
    if not settings or not settings.enabled then return end
    addon.Effects:Fire(item, entry, trigger, settings)
end

function Runtime:HookItem(item)
    if not item then return end
    self:RefreshItem(item)
    if self.hookedItems[item] then return end
    self.hookedItems[item] = true

    if type(item.SetCooldownID) == "function" then
        hooksecurefunc(item, "SetCooldownID", function(frame)
            addon.Runtime:QueueItemRefresh(frame, false)
        end)
    end

    if type(item.RefreshSpellTexture) == "function" then
        hooksecurefunc(item, "RefreshSpellTexture", function(frame)
            addon.Runtime:QueueItemRefresh(frame, true)
        end)
    end

    -- Blizzard refreshes these regions independently and may clear or replace
    -- cooldown presentation after BabyAuras has styled the item. Reapply on the
    -- next frame so the native timer remains the source of truth, including when
    -- its values are secret in combat.
    for _, method in ipairs({
        "RefreshIconBorder",
        "RefreshApplications",
        "RefreshSpellChargeInfo",
        "RefreshSpellCooldownInfo",
        "SetTimerShown",
    }) do
        if type(item[method]) == "function" then
            hooksecurefunc(item, method, function(frame)
                addon.Runtime:QueueItemRefresh(frame, true)
            end)
        end
    end

    -- Buff icons use this method for their aura timer. Buff bars also define it,
    -- but call it from OnUpdate, so only hook items that own a Cooldown widget.
    if item.Cooldown and type(item.RefreshCooldownInfo) == "function" then
        hooksecurefunc(item, "RefreshCooldownInfo", function(frame)
            addon.Runtime:QueueItemRefresh(frame, true)
        end)
    end

    if type(item.OnActiveStateChanged) == "function" then
        hooksecurefunc(item, "OnActiveStateChanged", function(frame)
            addon.Runtime:QueueItemRefresh(frame, true)
        end)
    end

    if type(item.OnAuraInstanceInfoSet) == "function" then
        hooksecurefunc(item, "OnAuraInstanceInfoSet", function(frame)
            addon.Runtime:QueueItemRefresh(frame, true)
        end)
    end

    if type(item.OnAuraInstanceInfoCleared) == "function" then
        hooksecurefunc(item, "OnAuraInstanceInfoCleared", function(frame)
            -- Aura-backed cooldown abilities need to switch immediately from
            -- the aura duration to the underlying spell cooldown.
            addon.Runtime:QueueItemRefresh(frame, true)
        end)
    end

    local hooks = {
        TriggerAvailableAlert = Enum.CooldownViewerAlertEventType.Available,
        TriggerChargeGainedAlert = Enum.CooldownViewerAlertEventType.ChargeGained,
        TriggerAuraAppliedAlert = Enum.CooldownViewerAlertEventType.OnAuraApplied,
        TriggerAuraRemovedAlert = Enum.CooldownViewerAlertEventType.OnAuraRemoved,
        TriggerPandemicAlert = Enum.CooldownViewerAlertEventType.PandemicTime,
    }
    for method, trigger in pairs(hooks) do
        local capturedTrigger = trigger
        if type(item[method]) == "function" then
            hooksecurefunc(item, method, function(frame)
                C_Timer.After(0, function()
                    if addon.Runtime.itemEntries[frame] then
                        addon.Runtime:Dispatch(frame, capturedTrigger)
                    end
                end)
            end)
        end
    end

    if type(item.TriggerAlertEvent) == "function" then
        hooksecurefunc(item, "TriggerAlertEvent", function(frame, trigger)
            if not addon:IsSecret(trigger)
                and trigger == Enum.CooldownViewerAlertEventType.OnCooldown then
                C_Timer.After(0, function()
                    if addon.Runtime.itemEntries[frame] then
                        addon.Runtime:Dispatch(frame, Enum.CooldownViewerAlertEventType.OnCooldown)
                    end
                end)
            end
        end)
    end
end

function Runtime:RefreshAppearances()
    for _, display in pairs(addon.Solo.displays) do addon.Solo:RefreshDisplay(display) end
end

function Runtime:ScanViewer(viewer)
    if not viewer or not viewer.itemFramePool then return end
    for item in viewer.itemFramePool:EnumerateActive() do self:HookItem(item) end
end

function Runtime:GetActiveItems()
    local activeItems = {}
    for _, globalName in ipairs(self.viewers) do
        local viewer = _G[globalName]
        if viewer and viewer.itemFramePool then
            for item in viewer.itemFramePool:EnumerateActive() do
                activeItems[item] = true
            end
        end
    end
    return activeItems
end

function Runtime:ReconcileActiveItems()
    local activeItems = self:GetActiveItems()
    for item in pairs(self.itemEntries) do
        if not activeItems[item] then
            addon.Solo:ReleaseItem(item)
            self.itemEntries[item] = nil
        end
    end
    local bestSources, priorities = {}, {}
    for item in pairs(activeItems) do
        local entry = self.itemEntries[item]
        if entry then
            local priority = GetSourcePriority(item, entry)
            if not priorities[entry.cooldownID] or priority > priorities[entry.cooldownID] then
                priorities[entry.cooldownID] = priority
                bestSources[entry.cooldownID] = item
            end
        end
    end
    for _, item in pairs(bestSources) do addon.Solo:RefreshItem(item) end
    addon.Solo:ReconcileDisplays()
end

function Runtime:RebuildFromCDM()
    addon.Catalog:Build()
    for _, globalName in ipairs(self.viewers) do self:ScanViewer(_G[globalName]) end
    self:ReconcileActiveItems()
    if addon.GUI and addon.GUI.frame and addon.GUI.frame:IsShown() then addon.GUI:Refresh() end
end

function Runtime:ScheduleCDMRefresh()
    self.cdmRefreshGeneration = (self.cdmRefreshGeneration or 0) + 1
    local generation = self.cdmRefreshGeneration
    for _, delay in ipairs({ 0, 0.08, 0.30 }) do
        C_Timer.After(delay, function()
            if Runtime.cdmRefreshGeneration == generation then Runtime:RebuildFromCDM() end
        end)
    end
end

function Runtime:Install()
    addon.Solo:InstallEditorHooks()
    if not self.layoutDataHooked and C_CooldownViewer and type(C_CooldownViewer.SetLayoutData) == "function" then
        self.layoutDataHooked = true
        hooksecurefunc(C_CooldownViewer, "SetLayoutData", function()
            addon.Runtime:ScheduleCDMRefresh()
        end)
    end
    for _, globalName in ipairs(self.viewers) do
        local viewer = _G[globalName]
        if viewer then
            self:ScanViewer(viewer)
            if not self.hookedViewers[viewer] then
                self.hookedViewers[viewer] = true
                if type(viewer.OnAcquireItemFrame) == "function" then
                    hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, item)
                        addon.Runtime:QueueItemRefresh(item, false)
                        addon.Runtime:ScheduleCDMRefresh()
                    end)
                end
                if type(viewer.RefreshData) == "function" then
                    hooksecurefunc(viewer, "RefreshData", function()
                        addon.Runtime:ScheduleCDMRefresh()
                    end)
                end
                if type(viewer.RefreshLayout) == "function" then
                    hooksecurefunc(viewer, "RefreshLayout", function()
                        addon.Runtime:ScheduleCDMRefresh()
                    end)
                end
                if type(viewer.Layout) == "function" then
                    hooksecurefunc(viewer, "Layout", function(frame)
                        if addon.Solo then addon.Solo:RepositionHostedViewer(frame) end
                    end)
                end
            end
        end
    end
    self:ReconcileActiveItems()
end

function Runtime:GetLiveItem(cooldownID)
    local source = addon.Solo.sources[cooldownID]
    if source and self.itemEntries[source] then return source end
    for item, entry in pairs(self.itemEntries) do
        if entry and entry.cooldownID == cooldownID then return item end
    end
end

function Runtime:GetTrackedBuffs()
    local tracked = {}
    local viewer = _G.BuffIconCooldownViewer
    if not viewer or not viewer.itemFramePool then return tracked end
    for item in viewer.itemFramePool:EnumerateActive() do
        local entry = self.itemEntries[item]
        if entry then
            tracked[#tracked + 1] = { item = item, entry = entry }
        end
    end
    table.sort(tracked, function(left, right)
        return (left.item.layoutIndex or 0) < (right.item.layoutIndex or 0)
    end)
    return tracked
end

function Runtime:GetCDMSections()
    local sections = {}
    for _, definition in ipairs(self.sectionDefinitions) do
        local section = {
            key = definition.key,
            name = definition.name,
            viewer = definition.viewer,
            entries = {},
        }
        local viewer = _G[definition.viewer]
        if viewer and viewer.itemFramePool then
            local seen = {}
            for item in viewer.itemFramePool:EnumerateActive() do
                local entry = self.itemEntries[item]
                if entry and not seen[entry.cooldownID] then
                    seen[entry.cooldownID] = true
                    section.entries[#section.entries + 1] = { item = item, entry = entry }
                end
            end
            table.sort(section.entries, function(left, right)
                return (left.item.layoutIndex or 0) < (right.item.layoutIndex or 0)
            end)
        end
        sections[#sections + 1] = section
    end
    return sections
end
