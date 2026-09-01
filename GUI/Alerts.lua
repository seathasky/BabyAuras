local _, addon = ...

local GUI = addon.GUI
local Defaults = addon.Defaults
local SetColorButtonColor = addon.GUIWidgets.SetColorButtonColor

function GUI:UpdateGlowControls()
    if not self.frame then return end
    local enabled = self.frame.Enabled:GetChecked() == true and self.selectedTrigger ~= nil
    local glowEnabled = enabled and self.frame.Glow:GetChecked() == true
    local style = self:GetGlowStyle()
    local colorEnabled = glowEnabled and (style == "pixel" or style == "extended")
    local motionEnabled = enabled and self.frame.ActiveTrackedBar ~= true
    local bounceEnabled = motionEnabled
    local bounceDurationEnabled = bounceEnabled and self.frame.Bounce:GetChecked() == true
    self.frame.Zoom:SetEnabled(motionEnabled)
    self.frame.Zoom:SetAlpha(motionEnabled and 1 or 0.32)
    self.frame.ZoomLabel:SetAlpha(motionEnabled and 1 or 0.32)
    self.frame.Bounce:SetEnabled(bounceEnabled)
    self.frame.Bounce:SetAlpha(bounceEnabled and 1 or 0.32)
    self.frame.BounceLabel:SetAlpha(bounceEnabled and 1 or 0.32)
    self.frame.BounceDuration:SetEnabled(bounceDurationEnabled)
    self.frame.BounceDuration:SetAlpha(bounceDurationEnabled and 1 or 0.32)
    self.frame.BounceDurationLabel:SetAlpha(bounceDurationEnabled and 1 or 0.32)
    self.frame.BounceDurationHint:SetAlpha(bounceDurationEnabled and 1 or 0.32)
    self.frame.GlowStyle:SetEnabled(glowEnabled)
    self.frame.Duration:SetEnabled(glowEnabled)
    self.frame.GlowColor:SetEnabled(colorEnabled)
    self.frame.GlowStyleLabel:SetAlpha(glowEnabled and 1 or 0.32)
    self.frame.DurationLabel:SetAlpha(glowEnabled and 1 or 0.32)
    self.frame.DurationHint:SetAlpha(glowEnabled and 1 or 0.32)
    self.frame.GlowColor:SetAlpha(colorEnabled and 1 or 0.32)
    for _, control in ipairs(self.frame.GlowTuningControls or {}) do control:SetEnabled(colorEnabled) end
    for _, element in ipairs(self.frame.GlowTuningElements or {}) do element:SetAlpha(colorEnabled and 1 or 0.32) end
    if self.RefreshActionBarGlowControls then self:RefreshActionBarGlowControls() end
end

function GUI:OnGlowTuningChanged(settingKey, value, valueLabel, suffix)
    value = math.floor((tonumber(value) or 0) + 0.5)
    valueLabel:SetText(value .. (suffix or ""))
    if self.refreshing or not self.selected or not self.selectedTrigger then return end
    local settings = addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, true)
    settings[settingKey] = value
    self:RefreshHeldTestGlow()
    self:SetStatus("Glow tuning saved automatically for this spell.")
end

function GUI:RefreshGlowTuningControls(settings)
    if not self.frame or not self.frame.GlowCount then return end
    local style = self:GetGlowStyle()
    local extended = style == "extended"
    local wasRefreshing = self.refreshing
    self.refreshing = true
    self.frame.GlowCount:SetMinMaxValues(extended and 1 or 2, extended and 8 or 64)
    self.frame.GlowCount.Low:SetText("")
    self.frame.GlowCount.High:SetText("")
    self.frame.GlowCountLabel:SetText(extended and "Glow layers" or "Pixel count")
    self.frame.GlowCount:SetValue(settings and settings.glowCount or (extended and 3 or 8))
    self.frame.GlowSpeed:SetValue(settings and settings.glowSpeed or Defaults.trigger.glowSpeed)
    self.frame.GlowThickness:SetValue(settings and settings.glowThickness or Defaults.trigger.glowThickness)
    self.frame.GlowPadding:SetValue(settings and settings.glowPadding or Defaults.trigger.glowPadding)
    self.refreshing = wasRefreshing
end

function GUI:OnGlowClicked()
    if self.refreshing then return end
    if self.frame.Glow:GetChecked() ~= true and self.testGlowTarget then
        addon.Effects:HideGlowTarget(self.testGlowTarget)
        self.testGlowTarget = nil
    end
    self:UpdateGlowControls()
    self:CommitEditor()
    if self.previewMode and self.frame.Glow:GetChecked() == true then self:RefreshHeldTestGlow() end
    self:UpdateTestAlertButton()
end

function GUI:GetGlowStyle()
    return self.selectedGlowStyle or Defaults.trigger.glowStyle
end

function GUI:SetGlowStyle(style)
    if not self.selected or not self.selectedTrigger then return end
    local cropEnabled = self.frame and self.frame.SoloCrop
        and self.frame.SoloCrop:GetChecked() == true and not self.frame.ActiveTrackedBar
    if cropEnabled and style == "blizzard" then
        self:SetStatus("Blizzard Proc glow is unavailable while Solo icon cropping is enabled.")
        return
    end
    self.selectedGlowStyle = style or Defaults.trigger.glowStyle
    if self.frame and self.frame.ActiveTrackedBar and self.selectedGlowStyle == "blizzard" then
        self.selectedGlowStyle = "pixel"
    end
    local settings = addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, true)
    settings.glowStyle = self.selectedGlowStyle
    if cropEnabled then settings.soloCropPreviousGlowStyle = nil end
    if self.frame and self.frame.GlowStyle then self.frame.GlowStyle:GenerateMenu() end
    self:RefreshGlowTuningControls(settings)
    self:UpdateGlowControls()
    self:RefreshHeldTestGlow()
    self:SetStatus(addon.Glow:GetLabel(self.selectedGlowStyle) .. " saved automatically.")
end

function GUI:OpenGlowColor()
    if not self.selected or not self.selectedTrigger or not ColorPickerFrame then return end
    local settings = addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, true)
    local source = type(settings.color) == "table" and settings.color or Defaults.trigger.color
    local original = { source[1] or 1, source[2] or 0.82, source[3] or 0, 1 }
    local function Save(r, g, b)
        settings.color = { Clamp(r or 1, 0, 1), Clamp(g or 0.82, 0, 1), Clamp(b or 0, 0, 1), 1 }
        SetColorButtonColor(self.frame.GlowColor, settings.color)
        self:RefreshHeldTestGlow()
    end
    local function Changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        Save(r, g, b)
    end
    local function Cancelled(previous)
        previous = type(previous) == "table" and previous or original
        Save(previous.r or previous[1], previous.g or previous[2], previous.b or previous[3])
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = original[1], g = original[2], b = original[3], hasOpacity = false,
            swatchFunc = Changed, cancelFunc = Cancelled, previousValues = original,
        })
    else
        ColorPickerFrame.previousValues = original
        ColorPickerFrame.func = Changed
        ColorPickerFrame.cancelFunc = Cancelled
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(original[1], original[2], original[3])
        ColorPickerFrame:Show()
    end
    self:SetStatus("Glow color saves automatically for this spell.")
end

function GUI:ResetGlowColor()
    if not self.selected or not self.selectedTrigger then return end
    local settings = addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, true)
    settings.color = nil
    SetColorButtonColor(self.frame.GlowColor, Defaults.trigger.color)
    self:RefreshHeldTestGlow()
    self:SetStatus("Glow color reset to default.")
end

function GUI:ResetAlertEffects()
    if not self.selected or not self.selectedTrigger then return end
    StaticPopupDialogs.BABY_AURAS_RESET_ALERT_EFFECTS = {
        text = "|cFFFF3030ARE YOU SURE?|r\n\nReset Alert Effects for %s?\n\nThis turns Glow, Action Bar Glow, Zoom, and Bounce OFF and restores their duration, color, and tuning defaults.",
        button1 = "Reset Alert Effects",
        button2 = CANCEL,
        OnAccept = function(_, data)
            local settings = addon:GetTriggerSettings(data.cooldownID, data.trigger, true)
            settings.zoom = false
            settings.bounce = false
            settings.bounceDuration = Defaults.trigger.bounceDuration
            settings.glow = false
            settings.glowStyle = (data.isTrackedBar or data.isCropped) and "pixel" or Defaults.trigger.glowStyle
            settings.soloCropPreviousGlowStyle = data.isCropped and Defaults.trigger.glowStyle or nil
            settings.glowDuration = Defaults.trigger.glowDuration
            settings.glowCount = Defaults.trigger.glowCount
            settings.glowSpeed = Defaults.trigger.glowSpeed
            settings.glowThickness = Defaults.trigger.glowThickness
            settings.glowPadding = Defaults.trigger.glowPadding
            settings.color = {
                Defaults.trigger.color[1], Defaults.trigger.color[2],
                Defaults.trigger.color[3], Defaults.trigger.color[4],
            }
            local entrySettings = addon:GetEntrySettings(data.cooldownID, true)
            entrySettings.actionBarGlow = false
            if addon.ActionBarGlow then addon.ActionBarGlow:ClearEntry(data.cooldownID) end
            local item = addon.Runtime:GetLiveItem(data.cooldownID)
            if item then addon.Effects:HideGlow(item) end
            if GUI.testGlowTarget then
                addon.Effects:HideGlowTarget(GUI.testGlowTarget)
                GUI.testGlowTarget = nil
                GUI:UpdateTestAlertButton()
            end
            if GUI.selected and GUI.selected.cooldownID == data.cooldownID
                and GUI.selectedTrigger == data.trigger then
                GUI:RefreshEditor("Alert Effects reset to defaults and turned off.")
            else
                GUI:SetStatus("Alert Effects reset to defaults and turned off.")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("BABY_AURAS_RESET_ALERT_EFFECTS", self.selected.name, nil, {
        cooldownID = self.selected.cooldownID,
        trigger = self.selectedTrigger,
        isTrackedBar = self.frame.ActiveTrackedBar == true,
        isCropped = self.frame.ActiveTrackedBar ~= true and self.frame.SoloCrop
            and self.frame.SoloCrop:GetChecked() == true,
    })
end

function GUI:OnZoomClicked()
    if self.refreshing then return end
    self:CommitEditor()
    if self.selected then
        local item = addon.Runtime:GetLiveItem(self.selected.cooldownID)
        if item and self.frame.Zoom:GetChecked() == true then
            addon.Effects:PlayZoom(item)
            if self.previewMode then self.previewMotionItem = item end
        elseif item then
            addon.Effects:StopZoom(item)
        end
    end
end

function GUI:OnBounceClicked()
    if self.refreshing then return end
    self:UpdateGlowControls()
    self:CommitEditor()
    if self.selected then
        local item = addon.Runtime:GetLiveItem(self.selected.cooldownID)
        if item and self.frame.Bounce:GetChecked() == true then
            addon.Effects:PlayBounce(item, tonumber(self.frame.BounceDuration:GetText()))
            if self.previewMode then self.previewMotionItem = item end
        elseif item then
            addon.Effects:StopBounce(item)
        end
    end
end
