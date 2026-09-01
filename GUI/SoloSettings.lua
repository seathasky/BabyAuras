local _, addon = ...

local GUI = addon.GUI
local Defaults = addon.Defaults
local SharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
local GetSavedColor = addon.GUIWidgets.GetSavedColor
local SetColorButtonColor = addon.GUIWidgets.SetColorButtonColor

function GUI:OnSoloClicked()
    if self.refreshing or not self.selected then return end
    local enabled = self.frame.Solo:GetChecked() == true
    local ok, message = addon.Solo:SetEnabled(self.selected, enabled)
    if not ok then
        self.refreshing = true
        self.frame.Solo:SetChecked(not enabled)
        self.refreshing = false
        self:SetStatus(message)
        return
    end
    self:UpdateSoloControls()
    self:UpdateGlowControls()
    addon.Navigation:Refresh(self.selected.cooldownID)
    self:SetStatus(enabled and "Solo display enabled. Use Edit Mode to position it." or "Solo display disabled.")
end

function GUI:OnSoloSizeChanged(value)
    if not self.frame or not self.frame.SoloSize then return end
    local percent = Clamp(math.floor((tonumber(value) or Defaults.soloScale) + 0.5), 50, 200)
    self.frame.SoloSizeValue:SetText(percent .. "%")
    if self.refreshing or not self.selected then return end
    addon.Solo:SetScale(self.selected, percent)
    self:SetStatus("Solo size saved automatically.")
end

function GUI:OnSoloCropClicked()
    if self.refreshing or not self.selected or self.frame.ActiveTrackedBar then return end
    local enabled = self.frame.SoloCrop:GetChecked() == true
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloCropEnabled = enabled

    for _, triggerSettings in pairs(settings.triggers or {}) do
        if enabled then
            if (triggerSettings.glowStyle or Defaults.trigger.glowStyle) == "blizzard" then
                triggerSettings.soloCropPreviousGlowStyle = "blizzard"
                triggerSettings.glowStyle = "pixel"
            end
        elseif triggerSettings.soloCropPreviousGlowStyle then
            if triggerSettings.glowStyle == "pixel" then
                triggerSettings.glowStyle = triggerSettings.soloCropPreviousGlowStyle
            end
            triggerSettings.soloCropPreviousGlowStyle = nil
        end
    end

    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    local current = self.selectedTrigger
        and addon:GetTriggerSettings(self.selected.cooldownID, self.selectedTrigger, false)
    self.selectedGlowStyle = current and current.glowStyle or Defaults.trigger.glowStyle
    self.frame.GlowStyle:GenerateMenu()
    self:RefreshGlowTuningControls(current)
    self:UpdateSoloControls()
    self:UpdateGlowControls()
    self:RefreshHeldTestGlow()
    self:SetStatus(enabled and "Solo icon bottom crop enabled; Blizzard Proc glow is unavailable."
        or "Solo icon crop disabled.")
end

function GUI:OnSoloCropChanged(value)
    if not self.frame or not self.frame.SoloCropAmount then return end
    local percent = Clamp(math.floor(((tonumber(value) or Defaults.soloAppearance.cropPercent) + 2.5) / 5) * 5, 0, 50)
    self.frame.SoloCropValue:SetText(percent .. "%")
    if self.refreshing or not self.selected or self.frame.ActiveTrackedBar then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloCropPercent = percent
    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    self:SetStatus("Solo icon bottom crop saved automatically.")
end

function GUI:OnSoloBarDimensionChanged(settingKey, value, valueElement, label)
    local limits = settingKey == "soloBarWidth" and { 80, 400 }
        or settingKey == "soloBarHeight" and { 4, 80 }
        or settingKey == "soloBarTextSize" and { 8, 32 } or { 16, 96 }
    local pixels = Clamp(math.floor((tonumber(value) or limits[1]) + 0.5), limits[1], limits[2])
    valueElement:SetText(pixels .. " px")
    if self.refreshing or not self.selected then return end
    addon.Solo:SetBarDimension(self.selected, settingKey, pixels)
    self:SetStatus(label .. " saved automatically.")
end

function GUI:OnSoloBarMatchIconClicked()
    if self.refreshing or not self.selected then return end
    local enabled = self.frame.SoloBarMatchIcon:GetChecked() == true
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloBarMatchIconHeight = enabled
    addon.Solo:SetBarDimension(self.selected, "soloBarHeight", self.frame.SoloBarHeight:GetValue())
    self:UpdateSoloControls()
    self:SetStatus(enabled and "Tracked bar icon now matches bar height."
        or "Tracked bar icon uses its independent size again.")
end

function GUI:OnSoloOpacityChanged(value)
    if not self.frame or not self.frame.SoloOpacity then return end
    local percent = Clamp(math.floor((tonumber(value) or Defaults.soloAppearance.opacity) + 0.5), 0, 100)
    self.frame.SoloOpacityValue:SetText(percent .. "%")
    if self.refreshing or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloOpacity = percent
    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    self:SetStatus("Solo icon opacity saved automatically.")
end

function GUI:OnSoloTextSizeChanged(settingKey, value, valueElement, label)
    local size = Clamp(math.floor((tonumber(value) or 14) + 0.5), 8, 32)
    valueElement:SetText(size .. " px")
    if self.refreshing or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings[settingKey] = size
    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    self:SetStatus(label .. " size saved automatically.")
end

function GUI:OnSoloHotkeyChanged()
    if self.refreshing or not self.selected or not self.frame.SoloHotkey then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloHotkey = self.frame.SoloHotkey:GetText() or ""
    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    self:SetStatus("Solo hotkey text saved automatically.")
end

function GUI:CommitSoloTextPosition(positionKey, xBox, yBox, label)
    if self.refreshing or not self.selected then return end
    local x, y = tonumber(xBox:GetText()), tonumber(yBox:GetText())
    if not x or not y then
        self:SetStatus(label .. " position requires numeric X and Y values.")
        return
    end
    x, y = Clamp(math.floor(x + 0.5), -500, 500), Clamp(math.floor(y + 0.5), -500, 500)
    xBox:SetText(tostring(x))
    yBox:SetText(tostring(y))
    addon.Solo:SetTextPosition(self.selected, positionKey, x, y)
    self:SetStatus(label .. " position saved automatically.")
end

function GUI:OnAppearanceClicked(key, checkbox, message)
    if self.refreshing or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings[key] = checkbox:GetChecked() == true
    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    self:SetStatus(message .. " saved automatically.")
end

function GUI:OnSoloBorderSizeChanged(value)
    if not self.frame or not self.frame.SoloBorderSize then return end
    local pixels = Clamp(math.floor((tonumber(value) or Defaults.soloAppearance.borderPixels) + 0.5), 1, 3)
    self.frame.SoloBorderSizeValue:SetText(pixels .. " px")
    if self.refreshing or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloBorderPixels = pixels
    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    self:SetStatus("Solo border thickness saved automatically.")
end

function GUI:GetSoloFontName()
    if not SharedMedia then return "Default" end
    local settings = self.selected and addon:GetEntrySettings(self.selected.cooldownID, false)
    local name = (settings and settings.soloFont) or Defaults.soloAppearance.font
    if name and SharedMedia:IsValid("font", name) then return name end
    return SharedMedia.DefaultMedia and SharedMedia.DefaultMedia.font or "Default"
end

function GUI:RefreshFontMedia()
    if self.frame and self.frame.SoloFont then
        self.frame.SoloFont:GenerateMenu()
    end
end

function GUI:SetSoloFont(fontName)
    if not self.selected or not SharedMedia or not SharedMedia:IsValid("font", fontName) then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloFont = fontName
    local cooldownID = self.selected.cooldownID
    local display = addon.Solo.displays[cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    if self.frame and self.frame.SoloFont then self.frame.SoloFont:GenerateMenu() end
    C_Timer.After(0, function()
        local refreshedDisplay = addon.Solo.displays[cooldownID]
        if refreshedDisplay then addon.Solo:RefreshDisplay(refreshedDisplay) end
    end)
    self:SetStatus("Solo text font saved automatically.")
end

function GUI:OpenSoloTextColor(settingKey, defaultKey, button, label, allowOpacity)
    if not self.selected or not ColorPickerFrame then return end
    local cooldownID = self.selected.cooldownID
    local settings = addon:GetEntrySettings(cooldownID, true)
    local original = GetSavedColor(settings, settingKey, defaultKey)

    local function SaveColor(r, g, b, a)
        settings[settingKey] = {
            Clamp(tonumber(r) or 1, 0, 1),
            Clamp(tonumber(g) or 1, 0, 1),
            Clamp(tonumber(b) or 1, 0, 1),
            Clamp(tonumber(a) or 1, 0, 1),
        }
        SetColorButtonColor(button, settings[settingKey])
        local display = addon.Solo.displays[cooldownID]
        if display then addon.Solo:RefreshDisplay(display) end
    end

    local function Changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = allowOpacity and ColorPickerFrame.GetColorAlpha
            and ColorPickerFrame:GetColorAlpha() or original[4]
        SaveColor(r, g, b, allowOpacity and a or 1)
    end

    local function Cancelled(previous)
        previous = type(previous) == "table" and previous or original
        SaveColor(previous.r or previous[1], previous.g or previous[2], previous.b or previous[3],
            allowOpacity and (previous.a or previous[4] or 1) or 1)
    end

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = original[1], g = original[2], b = original[3],
            opacity = original[4],
            hasOpacity = allowOpacity == true,
            swatchFunc = Changed,
            opacityFunc = Changed,
            cancelFunc = Cancelled,
            previousValues = original,
        })
    else
        ColorPickerFrame.previousValues = original
        ColorPickerFrame.func = Changed
        ColorPickerFrame.cancelFunc = Cancelled
        ColorPickerFrame.hasOpacity = allowOpacity == true
        ColorPickerFrame.opacityFunc = Changed
        if allowOpacity and ColorPickerFrame.SetColorAlpha then
            ColorPickerFrame:SetColorAlpha(original[4])
        end
        ColorPickerFrame:SetColorRGB(original[1], original[2], original[3])
        ColorPickerFrame:Show()
    end
    self:SetStatus(label .. " color saves automatically for this icon.")
end

function GUI:ResetSoloTextColors()
    if not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.soloStackColor = nil
    settings.soloCooldownColor = nil
    settings.soloHotkeyColor = nil
    settings.soloBarTextColor = nil
    SetColorButtonColor(self.frame.SoloStackColor, GetSavedColor(nil, "soloStackColor", "stackColor"))
    SetColorButtonColor(self.frame.SoloCooldownColor, GetSavedColor(nil, "soloCooldownColor", "cooldownColor"))
    SetColorButtonColor(self.frame.SoloHotkeyColor, GetSavedColor(nil, "soloHotkeyColor", "hotkeyColor"))
    SetColorButtonColor(self.frame.SoloBarTextColor, GetSavedColor(nil, "soloBarTextColor", "barTextColor"))
    local display = addon.Solo.displays[self.selected.cooldownID]
    if display then addon.Solo:RefreshDisplay(display) end
    self:SetStatus("Icon and tracked-bar text colors reset for this element.")
end

function GUI:UpdateSoloControls()
    if not self.frame or not self.frame.SoloSize then return end
    local soloSelected = self.frame.Solo:IsShown() and self.frame.Solo:GetChecked() == true
    local available = soloSelected and self.frame.Enabled:GetChecked() == true
    self.frame.SoloSize:SetEnabled(available)
    self.frame.SoloSizeValue:SetEnabled(available)
    self.frame.SoloSize:SetAlpha(available and 1 or 0.32)
    self.frame.SoloSizeLabel:SetAlpha(available and 1 or 0.32)
    self.frame.SoloSizeValue:SetAlpha(available and 1 or 0.32)
    for _, control in ipairs(self.frame.SoloOptionControls or {}) do control:SetEnabled(available) end
    for _, element in ipairs(self.frame.SoloOptionElements or {}) do element:SetAlpha(available and 1 or 0.32) end
    local cropAvailable = available and self.frame.ActiveTrackedBar ~= true
    local cropAmountEnabled = cropAvailable and self.frame.SoloCrop:GetChecked() == true
    self.frame.SoloCrop:SetEnabled(cropAvailable)
    self.frame.SoloCrop:SetAlpha(cropAvailable and 1 or 0.32)
    self.frame.SoloCropLabel:SetAlpha(cropAvailable and 1 or 0.32)
    self.frame.SoloCropAmount:SetEnabled(cropAmountEnabled)
    self.frame.SoloCropValue:SetEnabled(cropAmountEnabled)
    self.frame.SoloCropAmount:SetAlpha(cropAmountEnabled and 1 or 0.32)
    self.frame.SoloCropValue:SetAlpha(cropAmountEnabled and 1 or 0.32)
    for _, control in ipairs(self.frame.SoloBarControls or {}) do control:SetEnabled(available) end
    local independentBarIcon = available and self.frame.ActiveTrackedBar == true
        and self.frame.SoloBarMatchIcon:GetChecked() ~= true
    self.frame.SoloBarIconSize:SetEnabled(independentBarIcon)
    self.frame.SoloBarIconSizeValue:SetEnabled(independentBarIcon)
    self.frame.SoloBarIconSize:SetAlpha(independentBarIcon and 1 or 0.32)
    self.frame.SoloBarIconSizeLabel:SetAlpha(independentBarIcon and 1 or 0.32)
    self.frame.SoloBarIconSizeValue:SetAlpha(independentBarIcon and 1 or 0.32)
    local stackTextEnabled = available and self.frame.SoloShowStacks:GetChecked() == true
    self.frame.SoloStackSize:SetEnabled(stackTextEnabled)
    self.frame.SoloStackSizeValue:SetEnabled(stackTextEnabled)
    self.frame.SoloStackSize:SetAlpha(stackTextEnabled and 1 or 0.32)
    self.frame.SoloStackSizeLabel:SetAlpha(stackTextEnabled and 1 or 0.32)
    self.frame.SoloStackSizeValue:SetAlpha(stackTextEnabled and 1 or 0.32)
    for _, control in ipairs(self.frame.SoloStackPositionControls or {}) do control:SetEnabled(stackTextEnabled) end
    for _, element in ipairs(self.frame.SoloStackPositionElements or {}) do element:SetAlpha(stackTextEnabled and 1 or 0.32) end
    local cooldownTextEnabled = available and self.frame.SoloShowNumbers:GetChecked() == true
    self.frame.SoloCooldownSize:SetEnabled(cooldownTextEnabled)
    self.frame.SoloCooldownSizeValue:SetEnabled(cooldownTextEnabled)
    self.frame.SoloCooldownSize:SetAlpha(cooldownTextEnabled and 1 or 0.32)
    self.frame.SoloCooldownSizeLabel:SetAlpha(cooldownTextEnabled and 1 or 0.32)
    self.frame.SoloCooldownSizeValue:SetAlpha(cooldownTextEnabled and 1 or 0.32)
    for _, control in ipairs(self.frame.SoloCooldownPositionControls or {}) do control:SetEnabled(cooldownTextEnabled) end
    for _, element in ipairs(self.frame.SoloCooldownPositionElements or {}) do element:SetAlpha(cooldownTextEnabled and 1 or 0.32) end
    -- Keep Theme discoverable even before Solo is enabled. Its controls are part
    -- of SoloOptionControls/Elements, so they remain disabled and dimmed until
    -- the selected spell has an enabled Solo display.
    for _, element in ipairs(self.frame.SoloThemeElements or {}) do element:Show() end
    local showBarTheme = self.frame.ActiveTrackedBar == true
        and not self:IsEditorSectionCollapsed("theme")
    for _, element in ipairs(self.frame.SoloBarThemeElements or {}) do
        element:SetShown(showBarTheme)
    end
    if self.frame.SoloBarTextColor then self.frame.SoloBarTextColor:SetShown(showBarTheme) end
    local borderSizeEnabled = available and self.frame.SoloBlackBorder:GetChecked() == true
    self.frame.SoloBorderSize:SetEnabled(borderSizeEnabled)
    self.frame.SoloBorderSizeValue:SetEnabled(borderSizeEnabled)
    self.frame.SoloBorderSize:SetAlpha(borderSizeEnabled and 1 or 0.32)
    self.frame.SoloBorderSizeValue:SetAlpha(borderSizeEnabled and 1 or 0.32)
    if self.frame.SoloBarFillColor then
        self.frame.SoloBarFillColor:SetEnabled(available and self.frame.ActiveTrackedBar == true)
        self.frame.SoloBarFillColor:SetAlpha(available and self.frame.ActiveTrackedBar == true and 1 or 0.32)
    end
    if self.frame.SoloBarProgressColor then
        self.frame.SoloBarProgressColor:SetEnabled(available and self.frame.ActiveTrackedBar == true)
        self.frame.SoloBarProgressColor:SetAlpha(available and self.frame.ActiveTrackedBar == true and 1 or 0.32)
    end
    local inactiveEnabled = available and self.frame.SoloAlwaysShow:GetChecked() == true
    self.frame.SoloDesaturateInactive:SetEnabled(inactiveEnabled)
    self.frame.SoloDesaturateInactive:SetAlpha(inactiveEnabled and 1 or 0.32)
    self.frame.SoloDesaturateInactiveLabel:SetAlpha(inactiveEnabled and 1 or 0.32)
    if self.RefreshActionBarGlowControls then self:RefreshActionBarGlowControls() end
    if self.RefreshSecondaryIconControls then self:RefreshSecondaryIconControls() end
    self:ApplyEditorSectionLayout()
end

function GUI:RefreshSecondaryIconControls()
    if not self.frame or not self.frame.SecondaryIcon or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, false)
    local enabled = settings and settings.secondaryIconEnabled == true or false
    local available = self.frame.Solo:IsShown() and self.frame.Solo:GetChecked() == true
    self.frame.SecondaryIcon:SetChecked(enabled)
    self.frame.SecondaryIcon:SetEnabled(available)
    self.frame.SecondaryIcon:SetAlpha(available and 1 or 0.32)
    self.frame.SecondaryIconLabel:SetAlpha(available and 1 or 0.32)
    local detailsEnabled = available and enabled
    for _, control in ipairs({
        self.frame.SecondaryIconSpellID,
        self.frame.SecondaryIconSize,
        self.frame.SecondaryIconSizeValue,
    }) do control:SetEnabled(detailsEnabled) end
    for _, element in ipairs({
        self.frame.SecondaryIconSpellLabel,
        self.frame.SecondaryIconSpellID,
        self.frame.SecondaryIconSizeLabel,
        self.frame.SecondaryIconSize,
        self.frame.SecondaryIconSizeValue,
    }) do element:SetAlpha(detailsEnabled and 1 or 0.32) end
end

function GUI:OnSecondaryIconClicked()
    if self.refreshing or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.secondaryIconEnabled = self.frame.SecondaryIcon:GetChecked() == true
    if settings.secondaryIconEnabled then
        addon.Solo:RefreshSecondaryDisplay(self.selected,
            addon.Runtime:GetLiveItem(self.selected.cooldownID),
            addon.Solo.displays[self.selected.cooldownID])
    else
        addon.Solo:ReleaseSecondaryDisplay(self.selected.cooldownID)
    end
    self:RefreshSecondaryIconControls()
    self:SetStatus(settings.secondaryIconEnabled
        and "Second Solo icon enabled; move it in Baby Edit Mode."
        or "Second Solo icon disabled.")
end

function GUI:OnSecondaryIconSizeChanged(value)
    if self.refreshing or not self.selected then return end
    addon.Solo:SetSecondaryScale(self.selected, value)
    self:SetStatus("Second icon size saved automatically.")
end
