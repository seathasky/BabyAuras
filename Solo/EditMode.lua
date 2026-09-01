local _, addon = ...

local Solo = addon.Solo
local IsSoloEnabled = addon.SoloUtilities.IsSoloEnabled

function Solo:IsPositioningMode()
    return BabyAurasDB.soloIconsLocked ~= true and (self.editMode or self.guiPositionMode)
end

function Solo:AreIconsLocked()
    return BabyAurasDB.soloIconsLocked == true
end

function Solo:SetIconsLocked(locked)
    if locked and addon.GUI and addon.GUI.previewMode and not addon.GUI.stoppingPreviewMode then
        return false
    end
    BabyAurasDB.soloIconsLocked = locked == true
    if locked then self:SetLinkMode(false) end
    if locked then self.textPreviewEnabled = false end
    -- Keep the runtime mode in sync with the visible GUI. This repairs stale
    -- sessions where the saved/button state says unlocked but no positioning
    -- mode was armed, leaving icons without outlines or mouse input.
    if not locked and addon.GUI and addon.GUI.frame and addon.GUI.frame:IsShown() then
        self.guiPositionMode = true
    end
    self:ClearSnap()
    for _, display in pairs(self.displays) do
        if display.isDragging then
            display:StopMovingOrSizing()
            display.isDragging = nil
            self:SaveDisplayPosition(display)
        end
        self:RefreshDisplay(display)
    end
    if not locked and (self.guiPositionMode or self.editMode) then
        self:CreateEditBar()
    end
    self:UpdateEditBarVisibility()
    if addon.GUI then
        addon.GUI:UpdateIconLockButton()
    end
    return true
end

function Solo:UpdateSnapButton()
    local button = self.snapButton
    if not button then return end
    local enabled = BabyAurasDB.snapEnabled ~= false
    button:SetText(enabled and "Snapping: ON" or "Snapping: OFF")
    button:GetFontString():SetTextColor(1, 1, 1)
    button:SetBackdropColor(0.06, 0.16, 0.25, 1)
    button:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    if self.snapSpacing then
        self.snapSpacing:SetEnabled(enabled)
        self.snapSpacingLabel:SetTextColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
        self.snapSpacingValue:SetTextColor(enabled and 1 or 0.45, enabled and 1 or 0.45, enabled and 1 or 0.45)
    end
end

function Solo:UpdateGUIVisibilityButton()
    if not self.hideGUIButton then return end
    local guiShown = addon.GUI and addon.GUI.frame and addon.GUI.frame:IsShown()
    self.hideGUIButton:SetText(guiShown and "Hide GUI" or "Show GUI")
    self.hideGUIButton:GetFontString():SetTextColor(1, 1, 1)
end

function Solo:UpdateTooltipButton()
    local button = self.tooltipButton
    if not button then return end
    local hidden = BabyAurasDB.hideSoloTooltips == true
    button:SetText(hidden and "Show TT" or "Hide TT")
    button:GetFontString():SetTextColor(1, 1, 1)
    button:SetBackdropColor(0.06, 0.16, 0.25, 1)
end

function Solo:UpdateLabelButton()
    local button = self.labelButton
    if not button then return end
    local hidden = BabyAurasDB.hideSoloLabels == true
    button:SetText(hidden and "Show B" or "Hide B")
    button:GetFontString():SetTextColor(1, 1, 1)
    button:SetBackdropColor(0.06, 0.16, 0.25, 1)
end

function Solo:ResetPositionsToBar()
    if InCombatLockdown() then
        print("|cFFFFCC00Baby Auras:|r Solo positions cannot be reset during combat.")
        return
    end
    self:CreateEditBar()
    local barX, barY = self.editBar:GetCenter()
    local rootX, rootY = UIParent:GetCenter()
    if not barX or not barY or not rootX or not rootY then return end

    local ordered = {}
    for _, display in pairs(self.displays) do
        if IsSoloEnabled(display.entry)
            and (not display.isSecondary or self:IsSecondaryEnabled(display.entry)) then
            ordered[#ordered + 1] = display
        end
    end
    table.sort(ordered, function(left, right)
        local leftID = tonumber(left.entry.cooldownID) or 0
        local rightID = tonumber(right.entry.cooldownID) or 0
        if leftID == rightID then
            return (left.copyIndex or 1) < (right.copyIndex or 1)
        end
        return leftID < rightID
    end)

    local left = barX - (self.editBar:GetWidth() / 2) + 14
    local right = barX + (self.editBar:GetWidth() / 2) - 14
    local cursorX = left
    local rowTop = barY - (self.editBar:GetHeight() * self.editBar:GetScale() / 2) - 14
    local rowHeight = 0
    for _, display in ipairs(ordered) do
        local width = display:GetWidth() * display:GetScale()
        local height = display:GetHeight() * display:GetScale()
        if cursorX > left and cursorX + width > right then
            cursorX = left
            rowTop = rowTop - rowHeight - 8
            rowHeight = 0
        end
        local settings = addon:GetEntrySettings(display.entry.cooldownID, true)
        if not display.isSecondary then
            settings.soloStackPosition = nil
            settings.soloCooldownPosition = nil
            settings.soloHotkeyPosition = nil
        end
        local positionKey = display.isSecondary and "secondarySoloPosition" or "soloPosition"
        settings[positionKey] = {
            x = cursorX + (width / 2) - rootX,
            y = rowTop - (height / 2) - rootY,
        }
        self:ApplyDisplayPosition(display)
        self:ApplyTextLayout(display)
        cursorX = cursorX + width + 8
        rowHeight = math.max(rowHeight, height)
    end
    print("|cFF66CCFFBaby Auras:|r Solo positions reset beneath the Edit Mode banner.")
end

function Solo:ConfirmResetPositions()
    if InCombatLockdown() then
        print("|cFFFFCC00Baby Auras:|r Solo positions cannot be reset during combat.")
        return
    end
    StaticPopupDialogs.BABY_AURAS_RESET_SOLO_POSITIONS = {
        text = "Reset all Solo element positions?\n\nIcons will be placed beneath the Baby Auras Edit Mode banner, and their stack, cooldown, and hotkey text will return to default positions. Sizes and trigger settings will be preserved.",
        button1 = "Reset Positions",
        button2 = CANCEL,
        OnAccept = function() Solo:ResetPositionsToBar() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("BABY_AURAS_RESET_SOLO_POSITIONS")
end

function Solo:CreateEditBar()
    if self.editBar then return end
    local bar = CreateFrame("Frame", "BabyAurasSoloEditBar", UIParent, "BackdropTemplate")
    bar:SetSize(650, 144)
    local saved = BabyAurasDB.editBarPosition or { x = 0, y = 0 }
    bar:SetPoint("CENTER", UIParent, "CENTER", saved.x or 0, saved.y or 0)
    bar:SetFrameStrata("TOOLTIP")
    bar:SetFrameLevel(500)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local centerX, centerY = self:GetCenter()
        local rootX, rootY = UIParent:GetCenter()
        if centerX and centerY and rootX and rootY then
            BabyAurasDB.editBarPosition.x = centerX - rootX
            BabyAurasDB.editBarPosition.y = centerY - rootY
        end
    end)
    bar:SetScript("OnShow", function(self)
        self:SetFrameStrata("TOOLTIP")
        self:SetFrameLevel(500)
    end)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
    })
    bar:SetBackdropColor(0.105, 0.105, 0.125, 1)
    bar:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)

    local headerBackgroundArt = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBackgroundArt:SetPoint("TOPLEFT")
    headerBackgroundArt:SetPoint("TOPRIGHT")
    headerBackgroundArt:SetHeight(44)
    headerBackgroundArt:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\bg.png")
    headerBackgroundArt:SetTexCoord(0, 1, 0.34, 0.44)
    headerBackgroundArt:SetAlpha(0.18)

    local logo = bar:CreateTexture(nil, "ARTWORK")
    logo:SetSize(36, 40)
    logo:SetPoint("TOPLEFT", 9, -7)
    logo:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\BALogoTIconCentered.png")

    local title = bar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 8)
    title:SetText("BABY AURAS EDIT MODE")
    title:SetTextColor(166/255, 172/255, 248/255, 252/255)
    local subtitle = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Arrange and align your Solo icons")

    local headerDivider = bar:CreateTexture(nil, "ARTWORK")
    headerDivider:SetPoint("TOPLEFT", 10, -44)
    headerDivider:SetPoint("TOPRIGHT", -10, -44)
    headerDivider:SetHeight(1)
    headerDivider:SetColorTexture(0.28, 0.62, 0.88, 0.65)

    local function CreateControlPanel(width, height)
        local panel = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        panel:SetSize(width, height)
        panel:SetFrameLevel(bar:GetFrameLevel() + 2)
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        panel:SetBackdropColor(0.025, 0.025, 0.035, 1)
        panel:SetBackdropBorderColor(0.16, 0.38, 0.55, 0.5)
        return panel
    end

    local movementPanel = CreateControlPanel(494, 39)
    movementPanel:SetPoint("TOPLEFT", 10, -50)

    local visibilityPanel = CreateControlPanel(494, 39)
    visibilityPanel:SetPoint("TOPLEFT", movementPanel, "BOTTOMLEFT", 0, -6)

    local actionsPanel = CreateControlPanel(128, 84)
    actionsPanel:SetPoint("TOPRIGHT", -10, -50)

    local movementHeader = movementPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    movementHeader:SetPoint("LEFT", 10, 0)
    movementHeader:SetText("MOVEMENT")
    movementHeader:SetTextColor(166/255, 172/255, 248/255, 252/255)

    local visibilityHeader = visibilityPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    visibilityHeader:SetPoint("LEFT", 10, 0)
    visibilityHeader:SetText("VISIBILITY")
    visibilityHeader:SetTextColor(166/255, 172/255, 248/255, 252/255)

    local actionsHeader = actionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    actionsHeader:SetPoint("TOP", 0, -7)
    actionsHeader:SetText("ACTIONS")
    actionsHeader:SetTextColor(166/255, 172/255, 248/255, 252/255)

    local linkButton = CreateFrame("Button", nil, bar, "BackdropTemplate")
    linkButton:SetFrameLevel(bar:GetFrameLevel() + 10)
    linkButton:EnableMouse(true)
    linkButton:RegisterForClicks("LeftButtonUp")
    linkButton:SetSize(104, 23)
    linkButton:SetPoint("LEFT", movementPanel, "LEFT", 91, 0)
    linkButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    linkButton:SetBackdropColor(0.06, 0.16, 0.25, 1)
    linkButton:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    local linkText = linkButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    linkText:SetPoint("CENTER")
    linkButton:SetFontString(linkText)
    linkButton:SetScript("OnClick", function() Solo:ToggleLinkMode() end)
    self.linkButton = linkButton
    self:CreateLinkModePopup(bar)
    self:UpdateLinkButton()

    local snapButton = CreateFrame("Button", nil, bar, "BackdropTemplate")
    snapButton:SetFrameLevel(bar:GetFrameLevel() + 10)
    snapButton:EnableMouse(true)
    snapButton:RegisterForClicks("LeftButtonUp")
    snapButton:SetSize(88, 23)
    snapButton:SetPoint("LEFT", linkButton, "RIGHT", 6, 0)
    snapButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    snapButton:SetBackdropColor(0.06, 0.16, 0.25, 1)
    snapButton:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    local snapText = snapButton:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    snapText:SetPoint("CENTER")
    snapButton:SetFontString(snapText)
    snapText:SetTextColor(1, 1, 1)
    snapButton:SetScript("OnClick", function()
        BabyAurasDB.snapEnabled = not (BabyAurasDB.snapEnabled ~= false)
        Solo:ClearSnap()
        Solo:UpdateSnapButton()
    end)
    self.snapButton = snapButton
    self:UpdateSnapButton()

    local spacingLabel = movementPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    spacingLabel:SetPoint("TOPLEFT", movementPanel, "TOPLEFT", 304, -4)
    spacingLabel:SetText("Icon spacing")

    local spacing = CreateFrame("Slider", nil, movementPanel, "OptionsSliderTemplate")
    spacing:SetPoint("BOTTOMLEFT", movementPanel, "BOTTOMLEFT", 304, 3)
    spacing:SetSize(125, 16)
    spacing:SetMinMaxValues(0, 10)
    spacing:SetValueStep(1)
    spacing:SetObeyStepOnDrag(true)
    spacing.Low:SetText("")
    spacing.High:SetText("")
    local spacingValue
    spacing:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        BabyAurasDB.snapSpacing = value
        spacingValue:SetText(value .. " px")
    end)
    spacingValue = addon.GUIWidgets.AttachSliderInput(movementPanel, spacing, { suffix = " px", width = 46 })
    spacing:SetValue(BabyAurasDB.snapSpacing or 1)
    self.snapSpacing = spacing
    self.snapSpacingLabel = spacingLabel
    self.snapSpacingValue = spacingValue
    self:UpdateSnapButton()

    local reset = CreateFrame("Button", nil, bar, "BackdropTemplate")
    reset:SetFrameLevel(bar:GetFrameLevel() + 10)
    reset:EnableMouse(true)
    reset:RegisterForClicks("LeftButtonUp")
    reset:SetSize(108, 23)
    reset:SetPoint("TOP", actionsHeader, "BOTTOM", 0, -5)
    reset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    reset:SetBackdropColor(0.06, 0.16, 0.25, 1)
    reset:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    local resetText = reset:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    resetText:SetPoint("CENTER")
    reset:SetFontString(resetText)
    reset:SetText("Reset Positions")
    resetText:SetTextColor(1, 1, 1)
    reset:SetScript("OnEnter", function(self) self:SetBackdropColor(0.10, 0.28, 0.42, 1) end)
    reset:SetScript("OnLeave", function(self) self:SetBackdropColor(0.06, 0.16, 0.25, 1) end)
    reset:SetScript("OnClick", function() Solo:ConfirmResetPositions() end)

    local hideGUI = CreateFrame("Button", nil, bar, "BackdropTemplate")
    hideGUI:SetFrameLevel(bar:GetFrameLevel() + 10)
    hideGUI:EnableMouse(true)
    hideGUI:RegisterForClicks("LeftButtonUp")
    hideGUI:SetSize(86, 23)
    hideGUI:SetPoint("LEFT", visibilityPanel, "LEFT", 91, 0)
    hideGUI:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    hideGUI:SetBackdropColor(0.06, 0.16, 0.25, 1)
    hideGUI:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    local hideGUIText = hideGUI:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hideGUIText:SetPoint("CENTER")
    hideGUI:SetFontString(hideGUIText)
    hideGUI:SetText("Hide GUI")
    hideGUIText:SetTextColor(1, 1, 1)
    hideGUI:SetScript("OnEnter", function(self) self:SetBackdropColor(0.10, 0.28, 0.42, 1) end)
    hideGUI:SetScript("OnLeave", function(self) self:SetBackdropColor(0.06, 0.16, 0.25, 1) end)
    hideGUI:SetScript("OnClick", function()
        if not addon.GUI or not addon.GUI.frame then return end
        if addon.GUI.frame:IsShown() then
            Solo:SetEditMode(true, false)
        else
            addon.GUI.frame:Show()
            addon.GUI:Refresh()
        end
        Solo:UpdateGUIVisibilityButton()
    end)

    local hideLabels = CreateFrame("Button", nil, bar, "BackdropTemplate")
    hideLabels:SetFrameLevel(bar:GetFrameLevel() + 10)
    hideLabels:EnableMouse(true)
    hideLabels:RegisterForClicks("LeftButtonUp")
    hideLabels:SetSize(86, 23)
    hideLabels:SetPoint("LEFT", hideGUI, "RIGHT", 6, 0)
    hideLabels:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    hideLabels:SetBackdropColor(0.06, 0.16, 0.25, 1)
    hideLabels:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    local hideLabelsText = hideLabels:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hideLabelsText:SetPoint("CENTER")
    hideLabels:SetFontString(hideLabelsText)
    hideLabels:SetScript("OnClick", function()
        BabyAurasDB.hideSoloLabels = not (BabyAurasDB.hideSoloLabels == true)
        for _, display in pairs(Solo.displays) do Solo:RefreshDisplay(display) end
        Solo:UpdateLabelButton()
    end)
    self.labelButton = hideLabels
    self:UpdateLabelButton()

    local hideTooltips = CreateFrame("Button", nil, bar, "BackdropTemplate")
    hideTooltips:SetFrameLevel(bar:GetFrameLevel() + 10)
    hideTooltips:EnableMouse(true)
    hideTooltips:RegisterForClicks("LeftButtonUp")
    hideTooltips:SetSize(86, 23)
    hideTooltips:SetPoint("LEFT", hideLabels, "RIGHT", 6, 0)
    hideTooltips:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    hideTooltips:SetBackdropColor(0.06, 0.16, 0.25, 1)
    hideTooltips:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    local hideTooltipsText = hideTooltips:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hideTooltipsText:SetPoint("CENTER")
    hideTooltips:SetFontString(hideTooltipsText)
    hideTooltips:SetScript("OnClick", function()
        BabyAurasDB.hideSoloTooltips = not (BabyAurasDB.hideSoloTooltips == true)
        GameTooltip_Hide()
        Solo:UpdateTooltipButton()
    end)
    self.tooltipButton = hideTooltips
    self:UpdateTooltipButton()

    local done = CreateFrame("Button", nil, bar, "BackdropTemplate")
    done:SetFrameLevel(bar:GetFrameLevel() + 10)
    done:EnableMouse(true)
    done:RegisterForClicks("LeftButtonUp")
    done:SetSize(108, 23)
    done:SetPoint("TOP", reset, "BOTTOM", 0, -6)
    done:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
    })
    done:SetBackdropColor(0.06, 0.16, 0.25, 1)
    done:SetBackdropBorderColor(137 / 255, 147 / 255, 210 / 255, 1)
    local doneText = done:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    doneText:SetPoint("CENTER")
    done:SetFontString(doneText)
    done:SetText("Return")
    doneText:SetTextColor(1, 1, 1)
    done:SetScript("OnEnter", function(self) self:SetBackdropColor(0.10, 0.28, 0.42, 1) end)
    done:SetScript("OnLeave", function(self) self:SetBackdropColor(0.06, 0.16, 0.25, 1) end)
    done:SetScript("OnClick", function()
        -- Return is an unconditional exit from Baby Edit Mode. Preview Mode
        -- must never be able to trap the user in positioning mode.
        if addon.GUI and addon.GUI.previewMode then
            addon.GUI:StopTestGlow(true)
        end
        local manager = _G.EditModeManagerFrame
        if Solo.combinedEditMode and manager and manager:IsShown() then
            if manager.HasActiveChanges and manager:HasActiveChanges() then
                print("|cFFFFCC00Baby Auras:|r Click Blizzard's Save Layout button before returning.")
                return
            end
            HideUIPanel(manager)
            return
        end
        if Solo.guiPositionMode then
            Solo:SetIconsLocked(true)
            Solo:SetGUIPositionMode(false)
            if addon.GUI then addon.GUI:SetStatus("Baby Edit Mode closed.") end
            return
        end
        Solo:SetEditMode(false, true)
    end)
    bar:Hide()
    self.editBar = bar
    self.hideGUIButton = hideGUI
    self:UpdateGUIVisibilityButton()
end

function Solo:SetGUIPositionMode(enabled)
    self.guiPositionMode = enabled == true and not InCombatLockdown()
    if not self.guiPositionMode then
        self:SetLinkMode(false)
        self:ClearSnap()
        self.textPreviewEnabled = false
    end
    if self.guiPositionMode and not self:AreIconsLocked() then self:CreateEditBar() end
    self:UpdateEditBarVisibility()
    for _, display in pairs(self.displays) do self:RefreshDisplay(display) end
end

function Solo:UpdateEditBarVisibility()
    if not self.editBar then return end
    self.editBar:SetFrameStrata("TOOLTIP")
    self.editBar:SetFrameLevel(500)
    self.editBar:SetShown(self:IsPositioningMode())
end

function Solo:SetEditMode(enabled, reopenGUI)
    if enabled and InCombatLockdown() then return false, "Edit Mode is unavailable during combat." end
    self.editMode = enabled == true
    if not self.editMode then self:SetLinkMode(false) end
    self:CreateEditBar()
    self:UpdateEditBarVisibility()
    for cooldownID, display in pairs(self.displays) do
        if self.editMode and self.combinedEditMode and IsSoloEnabled(display.entry) then
            -- Blizzard has already completed its protected Edit Mode setup at
            -- this point. Alpha-only suppression avoids touching its layout.
            self:SetSourceHidden(self.sources[cooldownID], true)
        end
        self:RefreshDisplay(display)
    end

    if self.editMode and addon.GUI and addon.GUI.frame then
        addon.GUI.frame:Hide()
    elseif reopenGUI and addon.GUI and addon.GUI.frame then
        addon.GUI.frame:Show()
        addon.GUI:Refresh()
    end
    return true
end
