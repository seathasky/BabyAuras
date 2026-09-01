local _, addon = ...

local ActionBarGlow = {
    activeEntries = {},
    buttonClaims = {},
    glowHosts = setmetatable({}, { __mode = "k" }),
}
addon.ActionBarGlow = ActionBarGlow

local BUTTON_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
}

local function GetButtonNames()
    local names = {}
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for index = 1, 12 do
            local name = prefix .. index
            local button = _G[name]
            if button and button.IsObjectType and button:IsObjectType("Button") then
                names[#names + 1] = name
            end
        end
    end
    return names
end

local function GetSavedTargets(entry, create)
    if not entry then return nil end
    local settings = addon:GetEntrySettings(entry.cooldownID, create)
    if not settings then return nil end
    if create and type(settings.actionBarGlowButtons) ~= "table" then
        settings.actionBarGlowButtons = {}
    end
    return settings.actionBarGlowButtons, settings
end

local function EnsureGlowHost(button)
    local host = ActionBarGlow.glowHosts[button]
    if host then return host end
    host = CreateFrame("Frame", nil, button)
    host:SetAllPoints(button)
    host:SetFrameLevel(math.min(10000, (button:GetFrameLevel() or 1) + 20))
    host:EnableMouse(false)
    ActionBarGlow.glowHosts[button] = host
    return host
end

local function ShowButtonGlow(button)
    if not button then return end
    local host = EnsureGlowHost(button)
    if ActionButtonSpellAlertManager then
        ActionButtonSpellAlertManager:ShowAlert(host)
    elseif DoesTemplateExist and DoesTemplateExist("ActionBarButtonSpellActivationAlert") then
        if not host.SpellActivationAlert then
            host.SpellActivationAlert = CreateFrame(
                "Frame", nil, host, "ActionBarButtonSpellActivationAlert")
            host.SpellActivationAlert:SetAllPoints(host)
        end
        host.SpellActivationAlert:Show()
        if host.SpellActivationAlert.ProcStartAnim then
            host.SpellActivationAlert.ProcStartAnim:Play()
        end
    end
end

local function HideButtonGlow(button)
    local host = button and ActionBarGlow.glowHosts[button]
    if not host then return end
    if ActionButtonSpellAlertManager then
        ActionButtonSpellAlertManager:HideAlert(host)
    elseif host.SpellActivationAlert then
        if host.SpellActivationAlert.ProcStartAnim then
            host.SpellActivationAlert.ProcStartAnim:Stop()
        end
        host.SpellActivationAlert:Hide()
    end
end

function ActionBarGlow:RefreshButton(buttonName)
    local button = _G[buttonName]
    if not button then return end
    if self.buttonClaims[buttonName] and next(self.buttonClaims[buttonName]) then
        ShowButtonGlow(button)
    else
        HideButtonGlow(button)
    end
end

function ActionBarGlow:ClearEntry(cooldownID)
    cooldownID = tonumber(cooldownID) or cooldownID
    local previous = self.activeEntries[cooldownID]
    if not previous then return end
    self.activeEntries[cooldownID] = nil
    for buttonName in pairs(previous) do
        local claims = self.buttonClaims[buttonName]
        if claims then
            claims[cooldownID] = nil
            if not next(claims) then self.buttonClaims[buttonName] = nil end
        end
        self:RefreshButton(buttonName)
    end
end

function ActionBarGlow:UpdateEntry(entry, active)
    if not entry then return end
    local cooldownID = entry.cooldownID
    local targets, settings = GetSavedTargets(entry, false)
    local trigger = addon:GetPrimaryTrigger(entry)
    local triggerSettings = trigger and addon:GetTriggerSettings(cooldownID, trigger, false)
    local previous = self.activeEntries[cooldownID] or {}
    local desired = {}
    if active == true and triggerSettings and triggerSettings.enabled == true
        and settings and settings.actionBarGlow == true
        and type(targets) == "table" then
        for buttonName, selected in pairs(targets) do
            if selected == true and _G[buttonName] then desired[buttonName] = true end
        end
    end

    for buttonName in pairs(previous) do
        if not desired[buttonName] then
            local claims = self.buttonClaims[buttonName]
            if claims then
                claims[cooldownID] = nil
                if not next(claims) then self.buttonClaims[buttonName] = nil end
            end
            self:RefreshButton(buttonName)
        end
    end
    for buttonName in pairs(desired) do
        if not previous[buttonName] then
            self.buttonClaims[buttonName] = self.buttonClaims[buttonName] or {}
            self.buttonClaims[buttonName][cooldownID] = true
            self:RefreshButton(buttonName)
        end
    end
    self.activeEntries[cooldownID] = next(desired) and desired or nil
end

function ActionBarGlow:RefreshAll()
    local seen = {}
    if addon.Solo then
        for cooldownID, display in pairs(addon.Solo.displays or {}) do
            local entry = display and display.entry
            if entry and not display.isSecondary then
                seen[cooldownID] = true
                local settings = addon:GetEntrySettings(cooldownID, false)
                local active = addon.SoloUtilities.IsSoloEnabled(entry)
                    and display.activeState == true
                    and not addon.Solo.suspended
                    and not addon.Solo:IsPositioningMode()
                    and not (display.specPreviewOnly == true)
                    and settings and settings.actionBarGlow == true
                self:UpdateEntry(entry, active)
            end
        end
    end
    local stale = {}
    for cooldownID in pairs(self.activeEntries) do
        if not seen[cooldownID] then stale[#stale + 1] = cooldownID end
    end
    for _, cooldownID in ipairs(stale) do self:ClearEntry(cooldownID) end
end

function ActionBarGlow:GetSelectionCount(entry)
    local targets = GetSavedTargets(entry, false)
    local count = 0
    for _, selected in pairs(type(targets) == "table" and targets or {}) do
        if selected == true then count = count + 1 end
    end
    return count
end

function ActionBarGlow:SetTargetSelected(entry, buttonName, selected)
    local targets = GetSavedTargets(entry, true)
    if not targets then return end
    targets[buttonName] = selected == true or nil
    self:RefreshAll()
end

function ActionBarGlow:ClearTargets(entry)
    local _, settings = GetSavedTargets(entry, true)
    if not settings then return end
    wipe(settings.actionBarGlowButtons)
    self:RefreshAll()
end

local function ApplyPickerBackdrop(frame, selected)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(selected and 0.08 or 0.02, selected and 0.45 or 0.18,
        selected and 0.12 or 0.35, 0.55)
    frame:SetBackdropBorderColor(selected and 0.25 or 0.30, selected and 1 or 0.80,
        selected and 0.35 or 1, 1)
end

function ActionBarGlow:RefreshPicker()
    local picker = self.picker
    if not picker or not picker.entry then return end
    local targets = GetSavedTargets(picker.entry, false) or {}
    for _, overlay in ipairs(picker.overlays or {}) do
        local selected = targets[overlay.buttonName] == true
        ApplyPickerBackdrop(overlay, selected)
        overlay.Mark:SetText(selected and "|cFF44FF66OK|r" or "+")
    end
    local count = self:GetSelectionCount(picker.entry)
    picker.Count:SetText(count == 1 and "1 button selected" or (count .. " buttons selected"))
    if addon.GUI and addon.GUI.RefreshActionBarGlowControls then
        addon.GUI:RefreshActionBarGlowControls()
    end
end

function ActionBarGlow:FinishPicker()
    local picker = self.picker
    if not picker or not picker:IsShown() then return end
    picker:Hide()
end

function ActionBarGlow:EnsurePicker()
    if self.picker then return self.picker end
    local picker = CreateFrame("Frame", "BabyAurasActionBarGlowPicker", UIParent, "BackdropTemplate")
    picker:SetSize(390, 92)
    picker:SetPoint("TOP", UIParent, "TOP", 0, -90)
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel(500)
    picker:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    picker:SetBackdropColor(0.02, 0.08, 0.12, 0.98)
    picker:SetBackdropBorderColor(0.25, 0.80, 1, 1)
    local title = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Select action buttons to glow")
    local hint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -3)
    hint:SetText("Click any number of highlighted buttons, then choose Done.")
    local count = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("BOTTOMLEFT", 14, 13)
    picker.Count = count
    local clear = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    clear:SetSize(86, 24)
    clear:SetPoint("BOTTOMRIGHT", -102, 9)
    clear:SetText("Clear All")
    clear:SetScript("OnClick", function()
        if picker.entry then ActionBarGlow:ClearTargets(picker.entry) end
        ActionBarGlow:RefreshPicker()
    end)
    local done = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    done:SetSize(80, 24)
    done:SetPoint("BOTTOMRIGHT", -14, 9)
    done:SetText("Done")
    done:SetScript("OnClick", function() ActionBarGlow:FinishPicker() end)
    picker.overlays = {}
    picker:Hide()
    tinsert(UISpecialFrames, picker:GetName())
    picker:SetScript("OnHide", function()
        for _, overlay in ipairs(picker.overlays or {}) do overlay:Hide() end
        picker.entry = nil
        if picker.restoreGUI and addon.GUI and addon.GUI.frame then
            addon.GUI.frame:Show()
            addon.GUI:RefreshEditor("Action bar glow buttons saved.")
        end
        picker.restoreGUI = nil
    end)
    self.picker = picker
    return picker
end

function ActionBarGlow:StartPicker(entry)
    if not entry then return false end
    if InCombatLockdown() then
        if addon.GUI then addon.GUI:SetStatus("Action buttons cannot be selected during combat.") end
        return false
    end
    self:FinishPicker()
    local picker = self:EnsurePicker()
    picker.entry = entry
    picker.restoreGUI = addon.GUI and addon.GUI.frame and addon.GUI.frame:IsShown() or false
    if picker.restoreGUI then addon.GUI.frame:Hide() end

    for _, overlay in ipairs(picker.overlays) do overlay:Hide() end
    wipe(picker.overlays)
    for _, buttonName in ipairs(GetButtonNames()) do
        local button = _G[buttonName]
        if button and button:IsShown() then
            local overlay = button.__babyAurasPickerOverlay
            if not overlay then
                overlay = CreateFrame("Button", nil, button, "BackdropTemplate")
                overlay:SetAllPoints(button)
                overlay:SetFrameStrata("DIALOG")
                overlay:SetFrameLevel(math.min(10000, (button:GetFrameLevel() or 1) + 50))
                overlay:RegisterForClicks("LeftButtonUp")
                local mark = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                mark:SetPoint("CENTER")
                mark:SetTextColor(1, 1, 1, 1)
                overlay.Mark = mark
                button.__babyAurasPickerOverlay = overlay
            end
            overlay.buttonName = buttonName
            overlay:SetScript("OnClick", function(self)
                local targets = GetSavedTargets(picker.entry, true)
                ActionBarGlow:SetTargetSelected(picker.entry, self.buttonName,
                    not (targets and targets[self.buttonName] == true))
                ActionBarGlow:RefreshPicker()
            end)
            overlay:Show()
            picker.overlays[#picker.overlays + 1] = overlay
        end
    end
    picker:Show()
    self:RefreshPicker()
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then ActionBarGlow:FinishPicker() end
    C_Timer.After(0, function() ActionBarGlow:RefreshAll() end)
end)

local GUI = addon.GUI

function GUI:RefreshActionBarGlowControls()
    if not self.frame or not self.frame.ActionBarGlow or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, false)
    local enabled = settings and settings.actionBarGlow == true or false
    local count = ActionBarGlow:GetSelectionCount(self.selected)
    local available = self.frame.Enabled:GetChecked() == true
        and self.frame.Solo:IsShown() and self.frame.Solo:GetChecked() == true
    self.frame.ActionBarGlow:SetChecked(enabled)
    self.frame.ActionBarGlow:SetEnabled(available)
    self.frame.ActionBarGlow:SetAlpha(available and 1 or 0.32)
    self.frame.ActionBarGlowLabel:SetAlpha(available and 1 or 0.32)
    self.frame.ActionBarGlowPicker:SetEnabled(available and enabled)
    self.frame.ActionBarGlowPicker:SetAlpha(available and enabled and 1 or 0.32)
    self.frame.ActionBarGlowSummary:SetAlpha(available and 1 or 0.32)
    self.frame.ActionBarGlowSummary:SetText(count == 0 and "No buttons selected"
        or (count == 1 and "1 button selected" or (count .. " buttons selected")))
end

function GUI:OnActionBarGlowClicked()
    if self.refreshing or not self.selected then return end
    local settings = addon:GetEntrySettings(self.selected.cooldownID, true)
    settings.actionBarGlow = self.frame.ActionBarGlow:GetChecked() == true
    ActionBarGlow:RefreshAll()
    self:RefreshActionBarGlowControls()
    if settings.actionBarGlow and ActionBarGlow:GetSelectionCount(self.selected) == 0 then
        ActionBarGlow:StartPicker(self.selected)
    else
        self:SetStatus(settings.actionBarGlow and "Action bar proc glow enabled."
            or "Action bar proc glow disabled.")
    end
end

function GUI:OpenActionBarGlowPicker()
    if self.selected then ActionBarGlow:StartPicker(self.selected) end
end
