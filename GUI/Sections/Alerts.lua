local _, addon = ...

addon.GUISections = addon.GUISections or {}
local Alerts = {}
addon.GUISections.Alerts = Alerts

local Widgets = addon.GUIWidgets

function Alerts:Build(editor, anchor, frame)
    local GUI = addon.GUI
    local title, line = Widgets.CreateSectionTitle(editor, "ALERT EFFECTS")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    frame.EffectsTitle = title

    local glow, glowLabel = Widgets.CreateCheckbox(editor, "Glow alert", 105)
    glow:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    glow:SetScript("OnClick", function() GUI:OnGlowClicked() end)
    frame.Glow = glow
    local styleLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("LEFT", glow, "LEFT", 115, 0)
    styleLabel:SetText("Style")
    frame.GlowStyleLabel = styleLabel
    local style = FrameUtil.CreateFrame(nil, editor, "WowStyle1DropdownTemplate")
    style:SetPoint("LEFT", styleLabel, "RIGHT", 7, 0)
    style:SetSize(180, 26)
    style:SetSelectionText(function() return addon.Glow:GetLabel(GUI:GetGlowStyle()) end)
    style:SetupMenu(function(_, rootDescription)
        for _, optionData in ipairs(addon.Glow.styles) do
            local option = rootDescription:CreateRadio(optionData.label, function(value)
                return GUI:GetGlowStyle() == value
            end, function(value)
                GUI:SetGlowStyle(value)
            end, optionData.key)
            local cropEnabled = not GUI.frame.ActiveTrackedBar and GUI.frame.SoloCrop
                and GUI.frame.SoloCrop:GetChecked() == true
            if optionData.key == "blizzard" and (GUI.frame.ActiveTrackedBar or cropEnabled) then
                option:SetEnabled(false)
                option:SetTitleAndTextTooltip("Blizzard Proc unavailable",
                    cropEnabled and "Cropped Solo icons support Pixel Glow and Extended Glow."
                        or "Tracked bars support Pixel Glow and Extended Glow. Other icon categories can use Blizzard Proc.")
            end
        end
    end)
    style:EnableRegenerateOnResponse()
    frame.GlowStyle = style

    local zoom, zoomLabel = Widgets.CreateCheckbox(editor, "Zoom icon", 105)
    zoom:SetScript("OnClick", function() GUI:OnZoomClicked() end)
    frame.Zoom = zoom
    frame.ZoomLabel = zoomLabel

    local bounce, bounceLabel = Widgets.CreateCheckbox(editor, "Bounce icon", 105)
    bounce:SetScript("OnClick", function() GUI:OnBounceClicked() end)
    frame.Bounce = bounce
    frame.BounceLabel = bounceLabel

    local durationLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    durationLabel:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 4, -7)
    durationLabel:SetText("Glow duration")
    frame.DurationLabel = durationLabel
    local duration = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    duration:SetPoint("LEFT", durationLabel, "RIGHT", 8, 0)
    duration:SetSize(55, 26)
    duration:SetAutoFocus(false)
    duration:SetScript("OnEscapePressed", duration.ClearFocus)
    duration:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GUI:CommitEditor() end)
    duration:SetScript("OnTextChanged", function() GUI:ScheduleAutoSave() end)
    frame.Duration = duration
    local durationHint = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    durationHint:SetPoint("TOP", duration, "BOTTOM", 0, -1)
    durationHint:SetText("0 = held")
    frame.DurationHint = durationHint

    local bounceDurationLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bounceDurationLabel:SetText("Duration")
    frame.BounceDurationLabel = bounceDurationLabel
    local bounceDuration = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    bounceDuration:SetPoint("LEFT", bounceDurationLabel, "RIGHT", 8, 0)
    bounceDuration:SetSize(55, 26)
    bounceDuration:SetAutoFocus(false)
    bounceDuration:SetScript("OnEscapePressed", bounceDuration.ClearFocus)
    bounceDuration:SetScript("OnEnterPressed", function(self) self:ClearFocus(); GUI:CommitEditor() end)
    bounceDuration:SetScript("OnTextChanged", function() GUI:ScheduleAutoSave() end)
    frame.BounceDuration = bounceDuration
    local bounceDurationHint = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    bounceDurationHint:SetPoint("TOP", bounceDuration, "BOTTOM", 0, -1)
    bounceDurationHint:SetText("0 = held")
    frame.BounceDurationHint = bounceDurationHint

    local actionBarGlow, actionBarGlowLabel = Widgets.CreateCheckbox(editor, "Action bar glow", 125)
    -- This is a full-width row. Anchor it from the left motion column; using
    -- Bounce's right-hand duration label pushes the picker beyond the editor.
    actionBarGlow:SetPoint("TOPLEFT", zoom, "BOTTOMLEFT", 0, -48)
    actionBarGlow:SetScript("OnClick", function() GUI:OnActionBarGlowClicked() end)
    frame.ActionBarGlow, frame.ActionBarGlowLabel = actionBarGlow, actionBarGlowLabel
    local actionBarPicker = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    actionBarPicker:SetSize(150, 24)
    actionBarPicker:SetPoint("LEFT", actionBarGlow, "LEFT", 174, 0)
    actionBarPicker:SetText("Pick buttons...")
    actionBarPicker:SetScript("OnClick", function() GUI:OpenActionBarGlowPicker() end)
    frame.ActionBarGlowPicker = actionBarPicker
    local actionBarSummary = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    actionBarSummary:SetPoint("TOPLEFT", actionBarGlow, "BOTTOMLEFT", 4, -3)
    actionBarSummary:SetText("No buttons selected")
    frame.ActionBarGlowSummary = actionBarSummary

    local color = Widgets.CreateColorButton(editor, "Glow color")
    color:SetPoint("LEFT", duration, "RIGHT", 24, 0)
    color:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    color:SetScript("OnClick", function(_, button)
        if button == "RightButton" then GUI:ResetGlowColor() else GUI:OpenGlowColor() end
    end)
    color:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Glow color")
        GameTooltip:AddLine("Left-click to choose a color. Right-click to reset it.", 0.75, 0.85, 1, true)
        GameTooltip:Show()
    end)
    color:SetScript("OnLeave", GameTooltip_Hide)
    frame.GlowColor = color

    local tuning = {}
    tuning.countLabel, tuning.count, tuning.countValue =
        Widgets.CreateGlowSlider(editor, "Pixel count", 2, 64, "glowCount", "")
    tuning.countLabel:SetPoint("TOPLEFT", durationLabel, "BOTTOMLEFT", 0, -24)
    tuning.count:SetPoint("TOPLEFT", tuning.countLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowCountLabel, frame.GlowCount, frame.GlowCountValue = tuning.countLabel, tuning.count, tuning.countValue

    tuning.speedLabel, tuning.speed, tuning.speedValue =
        Widgets.CreateGlowSlider(editor, "Speed", 1, 10, "glowSpeed", "")
    tuning.speedLabel:SetPoint("TOPLEFT", tuning.countLabel, "TOPLEFT", 175, 0)
    tuning.speed:SetPoint("TOPLEFT", tuning.speedLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowSpeedLabel, frame.GlowSpeed, frame.GlowSpeedValue = tuning.speedLabel, tuning.speed, tuning.speedValue

    tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue =
        Widgets.CreateGlowSlider(editor, "Thickness", 1, 8, "glowThickness", " px")
    tuning.thicknessLabel:SetPoint("TOPLEFT", tuning.count, "BOTTOMLEFT", -7, -28)
    tuning.thickness:SetPoint("TOPLEFT", tuning.thicknessLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowThicknessLabel, frame.GlowThickness, frame.GlowThicknessValue =
        tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue

    tuning.paddingLabel, tuning.padding, tuning.paddingValue =
        Widgets.CreateGlowSlider(editor, "Padding / size", 0, 20, "glowPadding", " px")
    tuning.paddingLabel:SetPoint("TOPLEFT", tuning.thicknessLabel, "TOPLEFT", 175, 0)
    tuning.padding:SetPoint("TOPLEFT", tuning.paddingLabel, "BOTTOMLEFT", 7, -5)
    frame.GlowPaddingLabel, frame.GlowPadding, frame.GlowPaddingValue =
        tuning.paddingLabel, tuning.padding, tuning.paddingValue

    frame.GlowTuningControls = {
        tuning.count, tuning.countValue, tuning.speed, tuning.speedValue,
        tuning.thickness, tuning.thicknessValue, tuning.padding, tuning.paddingValue,
    }
    frame.GlowTuningElements = {
        tuning.countLabel, tuning.count, tuning.countValue,
        tuning.speedLabel, tuning.speed, tuning.speedValue,
        tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue,
        tuning.paddingLabel, tuning.padding, tuning.paddingValue,
    }

    -- Keep motion controls together below the glow controls. Bounce duration
    -- sits directly beneath Bounce instead of being mixed into glow tuning.
    zoom:SetPoint("TOPLEFT", tuning.thickness, "BOTTOMLEFT", -7, -24)
    bounce:SetPoint("TOPLEFT", tuning.padding, "BOTTOMLEFT", -7, -24)
    bounceDurationLabel:SetPoint("TOPLEFT", bounce, "BOTTOMLEFT", 4, -7)

    local reset = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
    reset:SetSize(190, 24)
    reset:SetPoint("TOPLEFT", actionBarSummary, "BOTTOMLEFT", -4, -14)
    reset:SetText("Reset Alert Effects")
    reset:GetFontString():SetTextColor(1, 0.30, 0.30)
    reset:SetScript("OnClick", function() GUI:ResetAlertEffects() end)
    frame.ResetAlertEffects = reset

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "effects")
    return {
        title = title, line = line, toggle = toggle,
        glow = glow, glowLabel = glowLabel, styleLabel = styleLabel, style = style,
        zoom = zoom, zoomLabel = zoomLabel,
        bounce = bounce, bounceLabel = bounceLabel,
        durationLabel = durationLabel, duration = duration, durationHint = durationHint,
        bounceDurationLabel = bounceDurationLabel, bounceDuration = bounceDuration,
        bounceDurationHint = bounceDurationHint,
        actionBarGlow = actionBarGlow, actionBarGlowLabel = actionBarGlowLabel,
        actionBarPicker = actionBarPicker, actionBarSummary = actionBarSummary,
        color = color, tuning = tuning, reset = reset,
        descriptor = {
            key = "effects", title = title, toggle = toggle, bottom = reset,
            gap = -14, collapseHeight = 330,
            elements = {
                glow, glowLabel, styleLabel, style, zoom, zoomLabel, bounce, bounceLabel,
                durationLabel, duration, durationHint, color,
                bounceDurationLabel, bounceDuration, bounceDurationHint,
                actionBarGlow, actionBarGlowLabel, actionBarPicker, actionBarSummary,
                tuning.countLabel, tuning.count, tuning.countValue,
                tuning.speedLabel, tuning.speed, tuning.speedValue,
                tuning.thicknessLabel, tuning.thickness, tuning.thicknessValue,
                tuning.paddingLabel, tuning.padding, tuning.paddingValue, reset,
            },
        },
    }
end
