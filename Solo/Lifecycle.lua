local _, addon = ...

local Solo = addon.Solo
local IsSoloEnabled = addon.SoloUtilities.IsSoloEnabled

function Solo:Suspend(reason)
    self.suspensionReasons[reason or "unknown"] = true
    self.suspended = true
    for cooldownID, item in pairs(self.sources) do
        local display = self.displays[cooldownID]
        if display then self:DetachLiveCooldown(display) end
        self:SetSourceHidden(item, false)
    end
    for _, display in pairs(self.displays) do self:RefreshDisplay(display) end
end

function Solo:Resume(reason)
    self.suspensionReasons[reason or "unknown"] = nil
    if next(self.suspensionReasons) then return end
    self.suspended = false
    for cooldownID, display in pairs(self.displays) do
        local item = self.sources[cooldownID]
        if IsSoloEnabled(display.entry) then
            if item and not display.isSecondary then
                self:InstallMirrors(item, display)
                self:SetSourceHidden(item, true)
            end
        end
        self:RefreshDisplay(display)
    end
end

function Solo:InstallEditorHooks()
    local editMode = _G.EditModeManagerFrame
    if editMode and not self.editModeManagerHooked then
        self.editModeManagerHooked = true
        hooksecurefunc(editMode, "Show", function() Solo:Suspend("editMode") end)
        hooksecurefunc(editMode, "Hide", function()
            if Solo.combinedEditMode then
                Solo.combinedEditMode = nil
                Solo:SetEditMode(false, false)
            end
            C_Timer.After(0.1, function() Solo:Resume("editMode") end)
        end)
    end

    local cdmSettings = _G.CooldownViewerSettings
    if cdmSettings and not self.cdmSettingsHooked then
        self.cdmSettingsHooked = true
        cdmSettings:HookScript("OnShow", function() Solo:Suspend("cdmSettings") end)
        cdmSettings:HookScript("OnHide", function()
            C_Timer.After(0.1, function() Solo:Resume("cdmSettings") end)
        end)
    end
end
