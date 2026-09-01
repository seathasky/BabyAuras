local _, addon = ...

local GUI = addon.GUI
local Defaults = addon.Defaults
local SetButtonTextWhite = addon.GUIWidgets.SetButtonTextWhite

function GUI:GetAvailableTriggers(entry)
    local trigger = addon:GetPrimaryTrigger(entry)
    return trigger and { trigger } or {}
end

function GUI:SetStatus(message)
    if self.frame and self.frame.Message then self.frame.Message:SetText(message or "") end
end

function GUI:UpdateIconLockButton()
    if not self.frame or not self.frame.IconLock then return end
    local locked = addon.Solo:AreIconsLocked()
    local button = self.frame.IconLock
    button:SetText("BABY EDIT MODE")
    SetButtonTextWhite(button)
    if locked then
        button:SetBackdropColor(0.025, 0.28, 0.10, 0.95)
        button:SetBackdropBorderColor(0.16, 0.72, 0.32, 0.9)
    else
        button:SetBackdropColor(0.38, 0.035, 0.055, 0.95)
        button:SetBackdropBorderColor(0.82, 0.16, 0.22, 0.9)
    end
end

function GUI:ToggleIconLock()
    local locked = not addon.Solo:AreIconsLocked()
    if locked and self.previewMode then
        self:SetStatus("Turn off Preview Mode before leaving Baby Edit Mode.")
        return
    end
    -- The options frame may already be visible when this is clicked (notably
    -- after a reload or UI rebuild), so its OnShow cannot be relied on to arm
    -- positioning mode. Explicitly arm it before unlocking the displays.
    if not locked and self.frame and self.frame:IsShown() then
        addon.Solo:SetGUIPositionMode(true)
    end
    addon.Solo:SetIconsLocked(locked)
    self:SetStatus(locked and "Baby Edit Mode closed." or "Baby Edit Mode opened; Solo icons are movable.")
end

function GUI:CommitEditor()
    if self.refreshing or not self.selected then return false end
    local triggerSupported = self.selectedTrigger ~= nil
    local triggerEnabled = triggerSupported and self.frame.Enabled:GetChecked() == true
    local speechRate = tonumber(self.frame.SpeechRate:GetText())
    local ttsEnabled = self.frame.TTS:GetChecked() == true
    if triggerEnabled and ttsEnabled and (not speechRate or speechRate < -10 or speechRate > 10) then
        self:SetStatus("Speech speed must be between -10 and 10.")
        return false
    end

    local durationText = strtrim(self.frame.Duration:GetText() or "")
    local duration = tonumber(durationText)
    if triggerEnabled and durationText ~= "" and (not duration or duration < 0) then
        self:SetStatus("Glow duration must be 0 or a positive number.")
        return false
    end
    local bounceDurationText = strtrim(self.frame.BounceDuration:GetText() or "")
    local bounceDuration = tonumber(bounceDurationText)
    if triggerEnabled and self.frame.Bounce:GetChecked() == true
        and bounceDurationText ~= "" and (not bounceDuration or bounceDuration < 0) then
        self:SetStatus("Bounce duration must be 0 or a positive number.")
        return false
    end

    local customIconSpellID = tonumber(self.frame.IconSpellID:GetText())
    if customIconSpellID and not C_Spell.GetSpellTexture(customIconSpellID) then
        self:SetStatus("That custom icon spell ID is not valid.")
        return false
    end
    local secondaryCustomIconSpellID = tonumber(self.frame.SecondaryIconSpellID:GetText())
    if secondaryCustomIconSpellID and not C_Spell.GetSpellTexture(secondaryCustomIconSpellID) then
        self:SetStatus("That second icon spell ID is not valid.")
        return false
    end

    local settings = triggerSupported
        and addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, true) or nil
    if settings then settings.enabled = triggerEnabled end

    -- Icon customization belongs to the Solo element, not to whether this
    -- alert trigger is enabled. Save it on every editor commit so the live Solo
    -- icon updates immediately even when the current trigger is disabled.
    local entrySettings = addon:GetEntrySettings(self.selected.cooldownID, true)
    entrySettings.customIconSpellID = customIconSpellID
    entrySettings.secondaryCustomIconSpellID = secondaryCustomIconSpellID

    -- Apply icon customization to the currently hosted Solo element immediately
    -- instead of waiting for Blizzard to emit another CDM refresh.
    if addon.Solo then
        local display = addon.Solo.displays and addon.Solo.displays[self.selected.cooldownID]
        if display then
            addon.Solo:RefreshDisplay(display)
        end
        if addon.Solo.RefreshSecondaryDisplay then
            addon.Solo:RefreshSecondaryDisplay(self.selected,
                addon.Runtime:GetLiveItem(self.selected.cooldownID), display)
        end
    end

    if triggerEnabled and settings then
        settings.zoom = self.frame.Zoom:GetChecked() == true
        settings.bounce = self.frame.Bounce:GetChecked() == true
        settings.bounceDuration = bounceDuration or Defaults.trigger.bounceDuration
        settings.glow = self.frame.Glow:GetChecked() == true
        settings.glowStyle = self.selectedGlowStyle or Defaults.trigger.glowStyle
        settings.glowDuration = duration or Defaults.trigger.glowDuration
        settings.glowCount = math.floor(self.frame.GlowCount:GetValue() + 0.5)
        settings.glowSpeed = math.floor(self.frame.GlowSpeed:GetValue() + 0.5)
        settings.glowThickness = math.floor(self.frame.GlowThickness:GetValue() + 0.5)
        settings.glowPadding = math.floor(self.frame.GlowPadding:GetValue() + 0.5)
        settings.ttsEnabled = ttsEnabled
        settings.text = self.frame.TextBox:GetText() or ""
        settings.speechRate = speechRate and Clamp(speechRate, -10, 10) or settings.speechRate or Defaults.trigger.speechRate
        settings.ttsVolume = Clamp(math.floor(self.frame.TTSVolume:GetValue() + 0.5), 0, 100)
        settings.audioEnabled = self.frame.Audio:GetChecked() == true
        settings.audioSound = self.selectedAudio
        settings.audioChannel = self.selectedAudioChannel or Defaults.trigger.audioChannel

    end
    addon.Runtime:RefreshAppearances()
    addon.Navigation:Refresh(self.selected.cooldownID)
    if self.frame and self.frame.SelectedIcon then
        self.frame.SelectedIcon:SetTexture(addon.Catalog:GetDisplayIcon(self.selected))
    end
    if not triggerEnabled or not settings or settings.glow ~= true then
        local item = addon.Runtime:GetLiveItem(self.selected.cooldownID)
        if item then addon.Effects:HideGlow(item) end
    end
    self:SetStatus("Saved automatically.")
    return true
end

function GUI:ScheduleAutoSave()
    if self.refreshing or not self.selected then return end
    self.saveGeneration = self.saveGeneration + 1
    local generation = self.saveGeneration
    local cooldownID = self.selected.cooldownID
    local trigger = self.selectedTrigger
    C_Timer.After(0.35, function()
        if generation == GUI.saveGeneration and GUI.selected
            and GUI.selected.cooldownID == cooldownID and GUI.selectedTrigger == trigger then
            GUI:CommitEditor()
        end
    end)
end

function GUI:Select(entry)
    local previewActive = self.previewMode == true
    local editorScroll = self.frame and self.frame.EditorScroll
    local scrollOffset = editorScroll and editorScroll:GetVerticalScroll() or 0
    if previewActive then self:ClearPreviewSelection() else self:StopTestGlow(true) end
    self:CommitEditor()
    self.selected = entry
    self.selectedTrigger = addon:GetPrimaryTrigger(entry)
    self:RefreshEditor()
    if editorScroll then
        editorScroll:SetVerticalScroll(Clamp(scrollOffset, 0, editorScroll:GetVerticalScrollRange()))
    end
    addon.Navigation:Refresh(entry.cooldownID)
    addon.Solo:RefreshEditSelection()
    if previewActive then self:RefreshPreviewSelection() end
end

function GUI:OpenEntry(entry)
    if not entry or InCombatLockdown() then return false end
    self:Create()
    local manager = _G.EditModeManagerFrame
    if manager and manager:IsShown() then
        self.pendingEntry = entry
        self.returnFromBlizzardEditMode = true
        HideUIPanel(manager)
        return true
    end
    self.frame:Show()
    self:Select(entry)
    return true
end

function GUI:CycleTrigger()
    -- Event sub-pages were removed; each spell has one settings page.
end

function GUI:SelectTrigger()
    -- Compatibility no-op for stale callbacks from older UI instances.
end

function GUI:OnPrismaticIconClicked()
    if self.refreshing or not self.selected or self.selected.cooldownID ~= 198408 then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.showPrismaticBoltIcon = self.frame.PrismaticIcon:GetChecked() == true
    addon.Runtime:RefreshAppearances()
    addon.Navigation:Refresh(self.selected.cooldownID)
    self.frame.SelectedIcon:SetTexture(addon.Catalog:GetDisplayIcon(self.selected))
    self:SetStatus("Prismatic Bolt icon preference saved automatically.")
end

function GUI:UpdateTriggerGate()
    if not self.frame then return end
    local supported = self.selectedTrigger ~= nil
    local enabled = supported and self.frame.Enabled:GetChecked() == true
    for _, control in ipairs(self.frame.TriggerGateControls or {}) do
        control:SetEnabled(enabled)
    end
    for _, element in ipairs(self.frame.TriggerGateElements or {}) do
        element:SetAlpha(enabled and 1 or 0.32)
    end
    self.frame.Enabled:SetShown(supported)
    if not supported then
        self.frame.EnabledLabel:ClearAllPoints()
        self.frame.EnabledLabel:SetPoint("TOP", self.frame.EnablePanel, "TOP", 0, -4)
        self.frame.EnabledLabel:SetText("NOT SUPPORTED")
        self.frame.EnabledLabel:SetTextColor(1, 0.28, 0.32, 1)
        self.frame.EnablePanel:SetBackdropColor(0.18, 0.025, 0.04, 0.98)
        self.frame.EnablePanel:SetBackdropBorderColor(0.9, 0.12, 0.2, 1)
        self.frame.UnsupportedReason:Show()
    else
        self.frame.EnabledLabel:ClearAllPoints()
        self.frame.EnabledLabel:SetPoint("LEFT", self.frame.Enabled, "RIGHT", 2, 0)
        self.frame.EnabledLabel:SetText("ENABLE ALERTS")
        self.frame.EnabledLabel:SetTextColor(enabled and 0.25 or 1, enabled and 1 or 0.82, enabled and 0.3 or 0.05, 1)
        self.frame.EnablePanel:SetBackdropBorderColor(enabled and 0.2 or 1, enabled and 0.8 or 0.72, enabled and 0.25 or 0.05, 1)
        self.frame.EnablePanel:SetBackdropColor(enabled and 0.03 or 0.12, enabled and 0.12 or 0.07, enabled and 0.04 or 0.01, 0.95)
        self.frame.UnsupportedReason:Hide()
    end
    self:UpdateSoloControls()
    self:UpdateSoundControls()
    self:UpdateGlowControls()
end

function GUI:OnEnabledClicked()
    if self.refreshing then return end
    local disabling = self.frame.Enabled:GetChecked() ~= true
    local entry = self.selected
    local soloEnabled = entry and addon.SoloUtilities.IsSoloEnabled(entry)
    if not self:CommitEditor() then return end
    self:UpdateTriggerGate()
    if disabling and soloEnabled then
        StaticPopupDialogs.BABY_AURAS_REMOVE_SOLO_AFTER_TRIGGER_DISABLE = {
            text = "This trigger has a Solo icon enabled.\n\nDo you also want to remove the Solo icon for %s?",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, data)
                local ok, message = addon.Solo:SetEnabled(data.entry, false)
                if not ok then
                    GUI:SetStatus(message)
                    return
                end
                if GUI.selected and GUI.selected.cooldownID == data.entry.cooldownID then
                    GUI.refreshing = true
                    GUI.frame.Solo:SetChecked(false)
                    GUI.refreshing = false
                    GUI:UpdateSoloControls()
                end
                addon.Navigation:Refresh(data.entry.cooldownID)
                GUI:SetStatus("Trigger and Solo display disabled.")
            end,
            OnCancel = function()
                GUI:SetStatus("Trigger disabled. Solo display kept.")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("BABY_AURAS_REMOVE_SOLO_AFTER_TRIGGER_DISABLE", entry.name, nil, { entry = entry })
    end
end
