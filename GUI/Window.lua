local _, addon = ...

-- Main window construction. The public toggle/combat entry point remains in GUI/Controller.lua.

local GUI = addon.GUI
local Defaults = addon.Defaults
local Widgets = addon.GUIWidgets
local ApplyBackdrop = Widgets.ApplyBackdrop
local SetButtonTextWhite = Widgets.SetButtonTextWhite
local CreateCheckbox = Widgets.CreateCheckbox
local CreateSectionBackground = Widgets.CreateSectionBackground











function GUI:Create()
    self:InstallCDMReturnHook()
    self:InstallBlizzardEditReturnHook()
    if self.frame then return end

    -- Main window frame, sizing, movement, and visibility behavior.
    local frame = CreateFrame("Frame", "BabyAurasConfigFrame", UIParent, "BackdropTemplate")
    local maximumHeight = 2000
    local minimumHeight = 420
    local savedHeight = Clamp(tonumber(BabyAurasDB.guiHeight) or Defaults.database.guiHeight, minimumHeight, maximumHeight)
    local frameWidth = 760
    frame:SetSize(frameWidth, savedHeight)
    frame:SetScale((BabyAurasDB.guiScale or Defaults.database.guiScale) / 100)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(frameWidth, minimumHeight, frameWidth, maximumHeight)
    frame:SetClampedToScreen(false)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", function(self)
        self:SetAlpha(1)
        addon.Solo:SetGUIPositionMode(true)
        addon.Solo:UpdateGUIVisibilityButton()
    end)
    frame:SetScript("OnHide", function(self)
        self:SetAlpha(1)
        GUI:StopTestGlow(true)
        addon.Solo:SetGUIPositionMode(false)
        addon.Solo:UpdateGUIVisibilityButton()
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.fadeUpdateElapsed = (self.fadeUpdateElapsed or 0) + elapsed
        if self.fadeUpdateElapsed < 0.03 then return end
        local step = self.fadeUpdateElapsed * 3.5
        self.fadeUpdateElapsed = 0
        local mouseOver = self:IsMouseOver()
            or (self.SettingsPopup and self.SettingsPopup:IsShown() and self.SettingsPopup:IsMouseOver())
        local fadedAlpha = Clamp(tonumber(BabyAurasDB.fadeOpacity) or Defaults.database.fadeOpacity, 10, 90) / 100
        local tutorialActive = addon.Tutorial and addon.Tutorial.active
        if addon.Tutorial and not tutorialActive then
            addon.Tutorial:EnsureInactiveCleanup()
        end
        local target = (not tutorialActive and BabyAurasDB.fadeWhenUnfocused and not mouseOver) and fadedAlpha or 1
        local alpha = self:GetAlpha()
        if math.abs(target - alpha) < 0.01 then
            self:SetAlpha(target)
        elseif alpha < target then
            self:SetAlpha(math.min(target, alpha + step))
        else
            self:SetAlpha(math.max(target, alpha - step))
        end
    end)
    ApplyBackdrop(frame)

    -- Window artwork, panel backgrounds, and structural dividers.
    local backgroundArt = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    backgroundArt:SetPoint("TOPLEFT", 5, -5)
    backgroundArt:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 305, -55)
    backgroundArt:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\bg.png")
    backgroundArt:SetAlpha(0.18)
    frame.BackgroundArt = backgroundArt

    local leftPanelTint = frame:CreateTexture(nil, "BACKGROUND", nil, 6)
    leftPanelTint:SetPoint("TOPLEFT", 5, -5)
    leftPanelTint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 305, 5)
    leftPanelTint:SetColorTexture(0.105, 0.105, 0.125, 0.72)
    frame.LeftPanelTint = leftPanelTint

    local function CropBackgroundToPanel(_, _, frameHeight)
        local panelWidth = 300
        local panelHeight = 50
        local imageAspect = 1536 / 1024
        local panelAspect = panelWidth / panelHeight
        if panelAspect < imageAspect then
            local visibleWidth = panelAspect / imageAspect
            local left = (1 - visibleWidth) / 2
            backgroundArt:SetTexCoord(left, 1 - left, 0, 1)
        else
            local visibleHeight = imageAspect / panelAspect
            -- Pull the header crop toward the top of the source image so the
            -- center paw decoration stays clear of the Baby Auras lettering.
            local top = Clamp(((1 - visibleHeight) / 2) - 0.28, 0, 1 - visibleHeight)
            backgroundArt:SetTexCoord(0, 1, top, top + visibleHeight)
        end
    end
    frame:HookScript("OnSizeChanged", CropBackgroundToPanel)
    CropBackgroundToPanel(frame, frame:GetWidth(), frame:GetHeight())

    local titleDivider = frame:CreateTexture(nil, "ARTWORK")
    titleDivider:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 5, -55)
    titleDivider:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 305, -55)
    titleDivider:SetHeight(addon.Theme:Pixel(frame, 1))
    titleDivider:SetColorTexture(0.34, 0.58, 0.86, 0.9)
    frame.TitleDivider = titleDivider

    local editorBackground = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    editorBackground:SetPoint("TOPLEFT", 306, -5)
    editorBackground:SetPoint("BOTTOMRIGHT", -5, 5)
    editorBackground:SetColorTexture(0.025, 0.025, 0.035, 0.97)
    frame.EditorBackground = editorBackground

    local footerBackgroundArt = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    footerBackgroundArt:SetPoint("BOTTOMLEFT", 5, 2)
    footerBackgroundArt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 305, 2)
    footerBackgroundArt:SetHeight(31)
    footerBackgroundArt:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\bg.png")
    footerBackgroundArt:SetAlpha(0.28)
    frame.FooterBackgroundArt = footerBackgroundArt

    local footerDivider = frame:CreateTexture(nil, "ARTWORK")
    footerDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 5, 33)
    footerDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 33)
    footerDivider:SetHeight(addon.Theme:Pixel(frame, 1))
    footerDivider:SetColorTexture(0.34, 0.58, 0.86, 0.9)
    frame.FooterDivider = footerDivider

    local function CropFooterBackground()
        local footerWidth = math.max(1, footerBackgroundArt:GetWidth())
        local footerHeight = math.max(1, footerBackgroundArt:GetHeight())
        local imageAspect = 1536 / 1024
        local footerAspect = footerWidth / footerHeight
        local visibleHeight = math.min(1, imageAspect / footerAspect)
        -- Use the very bottom of the artwork, whose decoration arrangement is
        -- distinct from the top-edge crop used by the title header.
        local top = 1 - visibleHeight
        footerBackgroundArt:SetTexCoord(0, 1, top, 1)
    end
    frame:HookScript("OnSizeChanged", CropFooterBackground)
    C_Timer.After(0, CropFooterBackground)

    frame:Hide()
    self.frame = frame

    -- Logo and About interaction.
    local titleGroup = CreateFrame("Frame", nil, frame)

    -- Keep the title texture-based. The former custom-font title could expose
    -- corrupted glyph-atlas fragments at the edge of the screen.
    local titleLogo = titleGroup:CreateTexture(nil, "ARTWORK")
    titleLogo:SetSize(56, 40)
    titleLogo:SetPoint("LEFT", titleGroup, "LEFT")
    titleLogo:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\BALogoTHeader.png")
    -- BALogoTHeader is padded to a WoW-safe 512x256 texture. Sample only the
    -- transparent 384x256 logo region so the header mark keeps its proportions.
    titleLogo:SetTexCoord(64 / 512, 448 / 512, 0, 1)

    local version = addon.version
    local versionText = frame:CreateFontString(nil, "ARTWORK")
    versionText:SetFont(STANDARD_TEXT_FONT, 9, "")
    versionText:SetSize(56, 12)
    versionText:SetPoint("CENTER", frame, "BOTTOMRIGHT", -35, 17)
    versionText:SetJustifyH("CENTER")
    versionText:SetJustifyV("MIDDLE")
    versionText:SetText(version and ("v" .. version) or "")
    versionText:SetTextColor(0.72, 0.72, 0.76)

    titleGroup:SetSize(titleLogo:GetWidth(), titleLogo:GetHeight())
    titleGroup:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)

    local titleAboutButton = CreateFrame("Button", nil, frame)
    titleAboutButton:SetAllPoints(titleGroup)
    titleAboutButton:SetFrameLevel(frame:GetFrameLevel() + 10)
    titleAboutButton:SetScript("OnClick", function()
        local now = GetTime()
        if GUI.lastTitleClick and now - GUI.lastTitleClick <= 0.4 then
            GUI.lastTitleClick = nil
            GUI:ToggleAbout()
        else
            GUI.lastTitleClick = now
        end
    end)
    titleAboutButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, 8)
        GameTooltip:SetText("Double-click for About Me")
        GameTooltip:Show()
    end)
    titleAboutButton:SetScript("OnLeave", GameTooltip_Hide)

    frame.TitleLogo = titleLogo
    frame.VersionText = versionText
    frame.TitleGroup = titleGroup
    frame.TitleAboutButton = titleAboutButton

    -- Top-right close, Blizzard Edit Mode, and icon-lock controls.
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    local soloEdit = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    soloEdit:SetSize(142, 24)
    soloEdit:SetPoint("TOPRIGHT", -38, -10)
    soloEdit:SetText("Blizzard Edit Mode")
    SetButtonTextWhite(soloEdit)
    soloEdit:SetScript("OnClick", function() GUI:StartSoloEditMode() end)
    frame.SoloEdit = soloEdit

    local iconLock = CreateFrame("Button", nil, frame, "BackdropTemplate")
    iconLock:SetSize(126, 24)
    iconLock:SetPoint("RIGHT", soloEdit, "LEFT", -6, 0)
    iconLock:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 18,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local lockText = iconLock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockText:SetPoint("CENTER")
    iconLock:SetFontString(lockText)
    local lockHighlight = iconLock:CreateTexture(nil, "HIGHLIGHT")
    lockHighlight:SetPoint("TOPLEFT", 5, -5)
    lockHighlight:SetPoint("BOTTOMRIGHT", -5, 5)
    lockHighlight:SetColorTexture(1, 1, 1, 0.14)
    iconLock:SetScript("OnMouseDown", function(self) self:GetFontString():SetPoint("CENTER", 0, -1) end)
    iconLock:SetScript("OnMouseUp", function(self) self:GetFontString():SetPoint("CENTER", 0, 0) end)
    iconLock:SetScript("OnClick", function() GUI:ToggleIconLock() end)
    iconLock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(addon.Solo:AreIconsLocked() and "Open Baby Edit Mode" or "Close Baby Edit Mode")
        GameTooltip:AddLine("Baby Edit Mode lets you position and arrange Solo icons.", 0.75, 0.85, 1, true)
        GameTooltip:Show()
    end)
    iconLock:SetScript("OnLeave", GameTooltip_Hide)
    frame.IconLock = iconLock
    SetButtonTextWhite(iconLock)
    self:UpdateIconLockButton()

    -- Footer tutorial, preview, section-layout, and class-status controls.
    local tutorialButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tutorialButton:SetSize(86, 24)
    tutorialButton:SetPoint("BOTTOMLEFT", 40, 5)
    tutorialButton:SetText("Tutorial")
    tutorialButton:GetFontString():SetTextColor(1, 1, 1)

    local tutorialArrow = frame:CreateTexture(nil, "OVERLAY")
    tutorialArrow:SetSize(24, 68)
    tutorialArrow:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\redarrowdown.png")
    tutorialArrow:Hide()
    frame.TutorialAttentionArrow = tutorialArrow

    tutorialButton:SetScript("OnClick", function()
        BabyAurasDB.tutorialRainbowSeen = true
        tutorialButton:GetFontString():SetTextColor(1, 1, 1)
        tutorialArrow:Hide()
        if addon.Tutorial then addon.Tutorial:Start() end
    end)
    tutorialButton:SetScript("OnUpdate", function(self)
        self:GetFontString():SetTextColor(1, 1, 1)
        if BabyAurasDB.tutorialRainbowSeen then
            tutorialArrow:Hide()
            return
        end
        local bounce = math.sin(GetTime() * 4.5) * 3
        tutorialArrow:ClearAllPoints()
        tutorialArrow:SetPoint("BOTTOM", self, "TOP", 0, 3 + bounce)
        tutorialArrow:Show()
    end)
    tutorialButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Baby Auras guided tutorial")
        GameTooltip:AddLine("Walk through every major section of the addon.", 0.75, 0.85, 1, true)
        GameTooltip:Show()
    end)
    tutorialButton:SetScript("OnLeave", GameTooltip_Hide)
    frame.TutorialButton = tutorialButton

    local allSectionsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    allSectionsButton:SetSize(102, 24)
    allSectionsButton:SetPoint("BOTTOM", editorBackground, "BOTTOM", -78, 2)
    allSectionsButton:SetText("Expand All")
    SetButtonTextWhite(allSectionsButton)
    allSectionsButton:SetScript("OnClick", function() GUI:ToggleAllEditorSections() end)
    allSectionsButton:SetScript("OnEnter", function(self)
        local expanding = GUI:AreAllEditorSectionsCollapsed()
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(expanding and "Expand all sections" or "Collapse all sections")
        GameTooltip:AddLine("Changes the shared section layout used for every icon.", 0.75, 0.85, 1, true)
        GameTooltip:AddLine("Your alert and display settings are not changed.", 0.55, 1, 0.65, true)
        GameTooltip:Show()
    end)
    allSectionsButton:SetScript("OnLeave", GameTooltip_Hide)
    frame.AllSectionsButton = allSectionsButton
    self:UpdateAllSectionsButton()

    frame.Test = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.Test:SetPoint("LEFT", allSectionsButton, "RIGHT", 10, 0)
    frame.Test:SetSize(145, 24)
    local previewActiveBackground = frame.Test:CreateTexture(nil, "BACKGROUND", nil, 7)
    previewActiveBackground:SetPoint("TOPLEFT", 4, -4)
    previewActiveBackground:SetPoint("BOTTOMRIGHT", -4, 4)
    previewActiveBackground:SetColorTexture(0.035, 0.48, 0.12, 0.95)
    previewActiveBackground:Hide()
    frame.Test.ActiveBackground = previewActiveBackground
    frame.Test:SetScript("OnClick", function() GUI:TestEditor() end)
    self:UpdateTestAlertButton()

    addon.Navigation:Create(frame, function(entry) GUI:Select(entry) end, function() GUI:OpenBlizzardCDM() end)

    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    separator:SetPoint("TOPLEFT", frame, "TOPLEFT", 305, -5)
    separator:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 305, 5)
    separator:SetWidth(1)

    local classStatusGroup = CreateFrame("Frame", nil, frame)
    -- Current specialization/class identity lives inside the left title header,
    -- aligned to the far-right side of the same header strip as the Baby Auras logo.
    classStatusGroup:SetPoint("RIGHT", frame, "TOPLEFT", 291, -30)
    classStatusGroup:SetHeight(23)

    local classStatusIcon = classStatusGroup:CreateTexture(nil, "ARTWORK")
    classStatusIcon:SetSize(21, 21)
    classStatusIcon:SetPoint("RIGHT", 0, 0)
    frame.ClassStatusIcon = classStatusIcon
    self:UpdateClassStatusIcon(classStatusIcon)

    local classStatus = classStatusGroup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    classStatus:SetPoint("RIGHT", classStatusIcon, "LEFT", -7, 2)
    classStatus:SetJustifyH("RIGHT")
    classStatus:SetText(self:GetClassStatusText())
    classStatus:SetWidth(classStatus:GetStringWidth() + 2)
    frame.ClassStatus = classStatus
    classStatusGroup:SetWidth(21 + 7 + classStatus:GetStringWidth())
    frame.ClassStatusGroup = classStatusGroup

    -- Session-only cross-spec Solo layout preview. The button occupies the
    -- former class/spec footer slot at the right edge of the left footer.
    self:CreateSpecIconPanel(frame)

    -- Settings cogwheel, dimmer, popup, and destructive-action prompts.
    -- Keep the settings popup's many construction locals out of the editor
    -- scope below. WoW Lua has a strict active-local/register ceiling.
    do
    local settingsButton = CreateFrame("Button", nil, frame)
    settingsButton:SetSize(24, 24)
    settingsButton:SetPoint("BOTTOMLEFT", 10, 5)
    local settingsIcon = settingsButton:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetSize(20, 20)
    settingsIcon:SetPoint("CENTER")
    settingsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    settingsButton:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Baby Auras Settings")
        GameTooltip:Show()
    end)
    settingsButton:SetScript("OnLeave", GameTooltip_Hide)

    local settingsPopup
    local settingsDimmer = CreateFrame("Button", nil, frame)
    settingsDimmer:SetAllPoints()
    settingsDimmer:SetFrameLevel(frame:GetFrameLevel() + 25)
    settingsDimmer:EnableMouse(true)
    local dimTexture = settingsDimmer:CreateTexture(nil, "BACKGROUND")
    dimTexture:SetAllPoints()
    dimTexture:SetColorTexture(0.035, 0.035, 0.04, 0.88)
    settingsDimmer:SetScript("OnClick", function() settingsPopup:Hide() end)
    settingsDimmer:Hide()

    settingsPopup = CreateFrame("Frame", "BabyAurasSettingsPopup", frame, "BackdropTemplate")
    settingsPopup:SetSize(250, 312)
    settingsPopup:SetPoint("BOTTOMLEFT", settingsButton, "TOPLEFT", 0, 6)
    settingsPopup:SetFrameLevel(frame:GetFrameLevel() + 30)
    ApplyBackdrop(settingsPopup)
    settingsPopup:SetBackdropColor(0.025, 0.025, 0.04, 1)
    settingsPopup:SetBackdropBorderColor(0.54, 0.58, 0.88, 1)
    settingsPopup:EnableMouse(true)

    local settingsHeader = settingsPopup:CreateTexture(nil, "BORDER")
    settingsHeader:SetPoint("TOPLEFT", 5, -5)
    settingsHeader:SetPoint("TOPRIGHT", -5, -5)
    settingsHeader:SetHeight(31)
    settingsHeader:SetColorTexture(0.10, 0.11, 0.20, 0.96)

    local settingsHeaderLine = settingsPopup:CreateTexture(nil, "ARTWORK")
    settingsHeaderLine:SetPoint("TOPLEFT", 6, -35)
    settingsHeaderLine:SetPoint("TOPRIGHT", -6, -35)
    settingsHeaderLine:SetHeight(1)
    settingsHeaderLine:SetColorTexture(0.54, 0.58, 0.88, 0.9)

    local settingsTitle = settingsPopup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    settingsTitle:SetPoint("TOPLEFT", 14, -12)
    settingsTitle:SetText("Baby Auras Settings")
    settingsTitle:SetTextColor(0.72, 0.76, 1)

    local settingsClose = CreateFrame("Button", nil, settingsPopup, "UIPanelCloseButton")
    settingsClose:SetSize(24, 24)
    settingsClose:SetPoint("TOPRIGHT", 1, 1)

    local fadeOption, fadeOptionLabel = CreateCheckbox(settingsPopup, "Fade when unfocused", 130)
    fadeOption:SetSize(20, 20)
    fadeOption:SetPoint("TOPLEFT", 12, -38)
    fadeOptionLabel:SetFontObject(GameFontHighlightSmall)
    fadeOption:SetChecked(BabyAurasDB.fadeWhenUnfocused)
    fadeOption:SetScript("OnClick", function(self) GUI:SetFadeEnabled(self:GetChecked()) end)
    frame.FadeWhenUnfocused = fadeOption

    local fadeOpacityLabel = settingsPopup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fadeOpacityLabel:SetPoint("TOPLEFT", fadeOption, "BOTTOMLEFT", 4, -8)
    fadeOpacityLabel:SetText("Faded opacity")

    local fadeOpacity = CreateFrame("Slider", nil, settingsPopup, "OptionsSliderTemplate")
    fadeOpacity:SetPoint("TOPLEFT", fadeOpacityLabel, "BOTTOMLEFT", 7, -8)
    fadeOpacity:SetSize(145, 16)
    fadeOpacity:SetMinMaxValues(10, 90)
    fadeOpacity:SetValueStep(5)
    fadeOpacity:SetObeyStepOnDrag(true)
    fadeOpacity.Low:SetText("10")
    fadeOpacity.High:SetText("90")
    fadeOpacity.Text:SetText("")
    fadeOpacity:SetValue(BabyAurasDB.fadeOpacity or Defaults.database.fadeOpacity)
    fadeOpacity:SetScript("OnValueChanged", function(_, value) GUI:SetFadeOpacity(value) end)
    local fadeOpacityValue = Widgets.AttachSliderInput(settingsPopup, fadeOpacity, { suffix = "%" })
    frame.FadeOpacity = fadeOpacity
    frame.FadeOpacityValue = fadeOpacityValue

    local guiScaleLabel = settingsPopup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    guiScaleLabel:SetPoint("TOPLEFT", fadeOpacity, "BOTTOMLEFT", -7, -13)
    guiScaleLabel:SetText("GUI scale")

    local guiScale = CreateFrame("Slider", nil, settingsPopup, "OptionsSliderTemplate")
    guiScale:SetPoint("TOPLEFT", guiScaleLabel, "BOTTOMLEFT", 7, -8)
    guiScale:SetSize(145, 16)
    guiScale:SetMinMaxValues(70, 130)
    guiScale:SetValueStep(5)
    guiScale:SetObeyStepOnDrag(true)
    guiScale.Low:SetText("70")
    guiScale.High:SetText("130")
    guiScale.Text:SetText("")
    guiScale:SetValue(BabyAurasDB.guiScale or Defaults.database.guiScale)
    -- Scaling the parent while this slider is being dragged changes the
    -- slider's screen-space bounds and can make the thumb jump to an endpoint.
    -- Show/save the stepped value during the drag, then resize on release.
    guiScale:SetScript("OnValueChanged", function(_, value) GUI:SetGUIScale(value, false) end)
    guiScale:HookScript("OnMouseUp", function(self)
        local scale = GUI:SetGUIScale(self:GetValue())
        if self:GetValue() ~= scale then self:SetValue(scale) end
    end)
    local guiScaleValue = Widgets.AttachSliderInput(settingsPopup, guiScale, {
        suffix = "%",
        onCommit = function(value) GUI:SetGUIScale(value) end,
    })
    frame.GUIScale = guiScale
    frame.GUIScaleValue = guiScaleValue

    local minimapOption, minimapOptionLabel = CreateCheckbox(settingsPopup, "Hide minimap button", 125)
    minimapOption:SetSize(20, 20)
    minimapOption:SetPoint("TOPLEFT", guiScale, "BOTTOMLEFT", -7, -13)
    minimapOptionLabel:SetFontObject(GameFontHighlightSmall)
    minimapOption:SetChecked(BabyAurasDB.minimap.hide)
    minimapOption:SetScript("OnClick", function(self) GUI:SetMinimapHidden(self:GetChecked()) end)
    frame.HideMinimap = minimapOption

    local muteOption, muteOptionLabel = CreateCheckbox(settingsPopup, "Mute all audio", 125)
    muteOption:SetSize(20, 20)
    muteOption:SetPoint("TOPLEFT", minimapOption, "BOTTOMLEFT", 0, -7)
    muteOptionLabel:SetFontObject(GameFontHighlightSmall)
    muteOption:SetChecked(BabyAurasDB.muteAllAudio == true)
    muteOption:SetScript("OnClick", function(self) GUI:SetMuteAllAudio(self:GetChecked()) end)
    frame.MuteAllAudio = muteOption

    local resetTutorialArrow = CreateFrame("Button", nil, settingsPopup, "UIPanelButtonTemplate")
    resetTutorialArrow:SetSize(190, 24)
    resetTutorialArrow:SetPoint("TOPLEFT", muteOption, "BOTTOMLEFT", 0, -12)
    resetTutorialArrow:SetText("Reset Tutorial Arrow")
    SetButtonTextWhite(resetTutorialArrow)
    resetTutorialArrow:SetScript("OnClick", function()
        BabyAurasDB.tutorialRainbowSeen = false
        if frame.TutorialAttentionArrow then
            frame.TutorialAttentionArrow:Show()
        end
        GUI:SetStatus("Tutorial arrow restored.")
    end)
    frame.ResetTutorialArrow = resetTutorialArrow

    frame.ResetAllSettings = CreateFrame("Button", nil, settingsPopup, "UIPanelButtonTemplate")
    frame.ResetAllSettings:SetSize(190, 24)
    frame.ResetAllSettings:SetPoint("TOPLEFT", resetTutorialArrow, "BOTTOMLEFT", 0, -10)
    frame.ResetAllSettings:SetText("Reset All Settings")
    frame.ResetAllSettings:GetFontString():SetTextColor(1, 0.25, 0.25)
    frame.ResetAllSettings:SetScript("OnClick", function() GUI:ConfirmResetAllSettings() end)

    settingsButton:SetScript("OnClick", function()
        settingsPopup:SetShown(not settingsPopup:IsShown())
    end)
    settingsPopup:SetScript("OnShow", function() settingsDimmer:Show() end)
    settingsPopup:SetScript("OnHide", function() settingsDimmer:Hide() end)
    settingsPopup:Hide()
    frame.SettingsButton = settingsButton
    frame.SettingsPopup = settingsPopup
    frame.SettingsDimmer = settingsDimmer
    end

    -- Window resize grip and empty-selection message.
    local resizeGrip = CreateFrame("Button", nil, frame)
    -- Keep a forgiving invisible drag target, but make the striped artwork subtle.
    resizeGrip:SetSize(32, 26)
    resizeGrip:SetPoint("BOTTOMRIGHT", -1, 1)
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 20)
    resizeGrip:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    local grip = resizeGrip:CreateTexture(nil, "ARTWORK")
    grip:SetSize(12, 12)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    local gripHighlight = resizeGrip:CreateTexture(nil, "HIGHLIGHT")
    gripHighlight:SetAllPoints(grip)
    gripHighlight:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    local gripPushed = resizeGrip:CreateTexture(nil, "OVERLAY")
    gripPushed:SetAllPoints(grip)
    gripPushed:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    gripPushed:Hide()
    local function StopHeightResize()
        if not resizeGrip.resizing then return end
        resizeGrip.resizing = nil
        gripPushed:Hide()
        resizeGrip:SetScript("OnUpdate", nil)
        BabyAurasDB.guiHeight = math.floor(frame:GetHeight() + 0.5)
    end
    resizeGrip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        gripPushed:Show()
        local left, top = frame:GetLeft(), frame:GetTop()
        if not left or not top then return end
        local _, cursorY = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        resizeGrip.startCursorY = cursorY / uiScale
        resizeGrip.startHeight = frame:GetHeight()
        resizeGrip.resizing = true

        -- Anchor the top edge before resizing so only the bottom edge moves.
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        resizeGrip:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                StopHeightResize()
                return
            end
            local _, currentCursorY = GetCursorPosition()
            local height = resizeGrip.startHeight + resizeGrip.startCursorY - (currentCursorY / uiScale)
            frame:SetHeight(Clamp(height, minimumHeight, maximumHeight))
        end)
    end)
    resizeGrip:SetScript("OnMouseUp", StopHeightResize)
    resizeGrip:SetScript("OnHide", StopHeightResize)
    resizeGrip:HookScript("OnMouseUp", function() gripPushed:Hide() end)
    resizeGrip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Drag vertically to resize Baby Auras")
        GameTooltip:Show()
    end)
    resizeGrip:SetScript("OnLeave", GameTooltip_Hide)
    frame.ResizeGrip = resizeGrip

    local empty = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    empty:SetPoint("CENTER", 155, 0)
    empty:SetWidth(270)
    frame.Empty = empty

    -- Scrollable editor viewport and its content canvas.
    local editorScroll = CreateFrame("ScrollFrame", "BabyAurasEditorScrollFrame", frame, "UIPanelScrollFrameTemplate")
    editorScroll:SetPoint("TOPLEFT", 325, -60)
    editorScroll:SetPoint("BOTTOMRIGHT", -42, 42)
    editorScroll:EnableMouseWheel(true)
    editorScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(Clamp(self:GetVerticalScroll() - delta * 40, 0, range))
    end)
    frame.EditorScroll = editorScroll

    local editor = CreateFrame("Frame", nil, editorScroll)
    editor:SetSize(395, 1160)
    editorScroll:SetScrollChild(editor)
    frame.Editor = editor

    -- Sticky identity header for the currently selected spell or aura.
    -- Keep the selected spell identity visible while its settings scroll.
    -- The content begins beneath this at its existing -60 offset, while the
    -- opaque overlay prevents scrolled controls from bleeding through it.
    frame.SelectedHeader = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.SelectedHeader:SetPoint("TOPLEFT", editorScroll, "TOPLEFT", 0, 0)
    frame.SelectedHeader:SetSize(395, 58)
    frame.SelectedHeader:SetFrameLevel(editorScroll:GetFrameLevel() + 20)
    frame.SelectedHeader:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    frame.SelectedHeader:SetBackdropColor(0.025, 0.025, 0.035, 1)
    frame.SelectedHeader:EnableMouse(false)
    frame.SelectedHeader.Divider = frame.SelectedHeader:CreateTexture(nil, "OVERLAY")
    frame.SelectedHeader.Divider:SetPoint("BOTTOMLEFT")
    frame.SelectedHeader.Divider:SetPoint("BOTTOMRIGHT")
    frame.SelectedHeader.Divider:SetHeight(addon.Theme:Pixel(frame.SelectedHeader, 1))
    frame.SelectedHeader.Divider:SetColorTexture(0.20, 0.55, 0.78, 0.8)

    local selectedIcon = frame.SelectedHeader:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetSize(42, 42)
    selectedIcon:SetPoint("TOPLEFT")
    frame.SelectedIcon = selectedIcon
    local selectedName = frame.SelectedHeader:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    selectedName:SetPoint("TOPLEFT", selectedIcon, "TOPRIGHT", 10, -3)
    selectedName:SetWidth(340)
    selectedName:SetJustifyH("LEFT")
    if selectedName.SetWordWrap then selectedName:SetWordWrap(false) end
    if selectedName.SetNonSpaceWrap then selectedName:SetNonSpaceWrap(false) end
    frame.SelectedName = selectedName
    local selectedNameFont, selectedNameSize, selectedNameFlags = selectedName:GetFont()
    frame.SelectedNameFont = {
        path = selectedNameFont,
        size = selectedNameSize,
        flags = selectedNameFlags,
    }
    local selectedID = frame.SelectedHeader:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    selectedID:SetPoint("TOPLEFT", selectedIcon, "TOPRIGHT", 10, -25)
    selectedID:SetWidth(305)
    selectedID:SetJustifyH("LEFT")
    frame.SelectedID = selectedID
    local selectedTimer = frame.SelectedHeader:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    selectedTimer:SetPoint("TOPLEFT", selectedID, "BOTTOMLEFT", 0, -1)
    selectedTimer:SetWidth(305)
    selectedTimer:SetJustifyH("LEFT")
    frame.SelectedTimer = selectedTimer

    -- Trigger enable gate and unsupported-state message.
    local enablePanel = CreateFrame("Frame", nil, editor, "BackdropTemplate")
    enablePanel:SetPoint("TOPLEFT", 0, -60)
    enablePanel:SetSize(395, 42)
    ApplyBackdrop(enablePanel)
    frame.EnablePanel = enablePanel
    local enabled, enabledLabel = CreateCheckbox(enablePanel, "ENABLE ALERTS", 245)
    enabled:SetPoint("LEFT", 8, 0)
    enabled:SetSize(30, 30)
    enabledLabel:SetFontObject(GameFontNormalLarge)
    enabled:SetScript("OnClick", function() GUI:OnEnabledClicked() end)
    frame.Enabled, frame.EnabledLabel = enabled, enabledLabel

    local unsupportedReason = enablePanel:CreateFontString(nil, "OVERLAY")
    unsupportedReason:SetPoint("BOTTOM", 0, 5)
    unsupportedReason:SetFontObject(GameFontHighlightSmall)
    unsupportedReason:SetText("No Blizzard CDM alert events")
    unsupportedReason:SetTextColor(1, 0.78, 0.80, 1)
    unsupportedReason:Hide()
    frame.UnsupportedReason = unsupportedReason

    -- Display and theme section construction and local control references.
    local displaySection = addon.GUISections.Display:Build(editor, frame)
    local displayTitle, displayLine, displayToggle = displaySection.title, displaySection.line, displaySection.toggle
    local soloPanel, solo, soloLabel = displaySection.panel, displaySection.solo, displaySection.soloLabel
    local soloOnTop, soloOnTopLabel = displaySection.onTop, displaySection.onTopLabel
    local soloSize, soloSizeLabel, soloSizeValue = displaySection.size, displaySection.sizeLabel, displaySection.sizeValue
    local soloCrop, soloCropLabel = displaySection.crop, displaySection.cropLabel
    local soloCropAmount, soloCropValue = displaySection.cropAmount, displaySection.cropValue
    local soloBar = displaySection.bar
    local soloShowSwipe, soloShowSwipeLabel = displaySection.showSwipe, displaySection.showSwipeLabel
    local soloShowNumbers, soloShowNumbersLabel = displaySection.showNumbers, displaySection.showNumbersLabel
    local soloKeepColored, soloKeepColoredLabel = displaySection.keepColored, displaySection.keepColoredLabel
    local soloClassSwipe, soloClassSwipeLabel = displaySection.classSwipe, displaySection.classSwipeLabel
    local soloActiveBorder, soloActiveBorderLabel = displaySection.activeBorder, displaySection.activeBorderLabel
    local soloAlwaysShow, soloAlwaysShowLabel = displaySection.alwaysShow, displaySection.alwaysShowLabel
    local soloDesaturateInactive, soloDesaturateInactiveLabel = displaySection.desaturate, displaySection.desaturateLabel
    local soloShowStacks, soloShowStacksLabel = displaySection.showStacks, displaySection.showStacksLabel
    local soloOpacity, soloOpacityLabel, soloOpacityValue =
        displaySection.opacity, displaySection.opacityLabel, displaySection.opacityValue
    local soloStackSizeLabel, soloStackSize, soloStackSizeValue =
        displaySection.stackSizeLabel, displaySection.stackSize, displaySection.stackSizeValue
    local soloCooldownSizeLabel, soloCooldownSize, soloCooldownSizeValue =
        displaySection.cooldownSizeLabel, displaySection.cooldownSize, displaySection.cooldownSizeValue
    local stackPositionLabel, stackXLabel, stackX, stackXValue =
        displaySection.stackPositionLabel, displaySection.stackXLabel, displaySection.stackX, displaySection.stackXValue
    local stackYLabel, stackY, stackYValue = displaySection.stackYLabel, displaySection.stackY, displaySection.stackYValue
    local cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownXValue =
        displaySection.cooldownPositionLabel, displaySection.cooldownXLabel, displaySection.cooldownX, displaySection.cooldownXValue
    local cooldownYLabel, cooldownY, cooldownYValue =
        displaySection.cooldownYLabel, displaySection.cooldownY, displaySection.cooldownYValue
    local soloHotkeyLabel, soloHotkey, soloHotkeySizeLabel =
        displaySection.hotkeyLabel, displaySection.hotkey, displaySection.hotkeySizeLabel
    local soloHotkeySize, soloHotkeySizeValue = displaySection.hotkeySize, displaySection.hotkeySizeValue
    local hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyXValue =
        displaySection.hotkeyPositionLabel, displaySection.hotkeyXLabel,
        displaySection.hotkeyX, displaySection.hotkeyXValue
    local hotkeyYLabel, hotkeyY, hotkeyYValue =
        displaySection.hotkeyYLabel, displaySection.hotkeyY, displaySection.hotkeyYValue

    local themeSection = addon.GUISections.Theme:Build(editor, hotkeyYLabel, frame)
    local themeTitle, themeLine, themeToggle = themeSection.title, themeSection.line, themeSection.toggle
    local soloBlackBorder, soloBlackBorderLabel = themeSection.border, themeSection.borderLabel
    local soloBorderSize, soloBorderSizeValue = themeSection.borderSize, themeSection.borderSizeValue
    local soloBarTheme = themeSection.bar
    local soloFontLabel, soloFont = themeSection.fontLabel, themeSection.font
    local soloTextColorsLabel = themeSection.colorsLabel
    local soloStackColor, soloCooldownColor = themeSection.stackColor, themeSection.cooldownColor
    local soloHotkeyColor, soloBarTextColor = themeSection.hotkeyColor, themeSection.barTextColor
    local resetSoloTextColors = themeSection.reset

    -- One page per spell: alert effects are configured directly, without
    -- event-selector sub-pages.
    local alertsSection = addon.GUISections.Alerts:Build(editor, enablePanel, frame)
    local effectsTitle, effectsLine, effectsToggle = alertsSection.title, alertsSection.line, alertsSection.toggle
    local glow, glowLabel = alertsSection.glow, alertsSection.glowLabel
    local zoom, zoomLabel = alertsSection.zoom, alertsSection.zoomLabel
    local bounce, bounceLabel = alertsSection.bounce, alertsSection.bounceLabel
    local glowStyleLabel, glowStyle = alertsSection.styleLabel, alertsSection.style
    local durationLabel, duration, durationHint = alertsSection.durationLabel, alertsSection.duration, alertsSection.durationHint
    local bounceDurationLabel, bounceDuration, bounceDurationHint = alertsSection.bounceDurationLabel,
        alertsSection.bounceDuration, alertsSection.bounceDurationHint
    local glowColor, glowTuning = alertsSection.color, alertsSection.tuning

    local audioSection = addon.GUISections.Audio:Build(editor, frame.ResetAlertEffects, frame)
    local voiceTitle, voiceLine, voiceToggle = audioSection.title, audioSection.line, audioSection.toggle
    local tts, ttsLabel = audioSection.tts, audioSection.ttsLabel
    local textLabel, textBox = audioSection.textLabel, audioSection.textBox
    local speechRateLabel, speechRate, rateHint = audioSection.speechRateLabel, audioSection.speechRate, audioSection.rateHint
    local ttsVolume, ttsVolumeValue = audioSection.volume, audioSection.volumeValue
    local audio, audioLabel = audioSection.audio, audioSection.audioLabel
    local audioDropdown, audioPreview, audioChannel = audioSection.dropdown, audioSection.preview, audioSection.channel

    local iconSection = addon.GUISections.Icon:Build(editor, audioChannel, frame)
    local iconTitle, iconLine = iconSection.title, iconSection.line
    local iconLabel, iconSpellID = iconSection.label, iconSection.spellID
    local prismaticIcon, prismaticIconLabel = iconSection.prismatic, iconSection.prismaticLabel
    local autoSave, message = iconSection.autoSave, iconSection.message

    local iconToggle = iconSection.toggle

    -- Shared section descriptors, backgrounds, and collapse controls.
    frame.EditorSections = {
        displaySection.descriptor,
        themeSection.descriptor,
        alertsSection.descriptor,
        audioSection.descriptor,
        iconSection.descriptor,
    }
    for index = 1, #frame.EditorSections do
        frame.EditorSections[index].background = CreateSectionBackground(editor)
    end
    frame.SectionToggles = { displayToggle, themeToggle, effectsToggle, voiceToggle, iconToggle }

    -- Enable Alerts affects only alert effects and voice/audio. Solo display,
    -- theme, positioning, and icon customization remain independent.
    frame.TriggerGateControls = {
        glow, zoom, bounce, glowStyle, duration, bounceDuration, glowColor, frame.ResetAlertEffects,
        frame.ActionBarGlow, frame.ActionBarGlowPicker,
        tts, textBox, speechRate, ttsVolume, ttsVolumeValue, audio, audioDropdown, audioPreview, audioChannel,
    }
    frame.TriggerGateElements = {
        effectsTitle, effectsLine, glow, glowLabel, zoom, zoomLabel, bounce, bounceLabel,
        glowStyleLabel, glowStyle, durationLabel, duration, durationHint,
        bounceDurationLabel, bounceDuration, bounceDurationHint, glowColor, frame.ResetAlertEffects,
        frame.ActionBarGlow, frame.ActionBarGlowLabel, frame.ActionBarGlowPicker, frame.ActionBarGlowSummary,
        voiceTitle, voiceLine, tts, ttsLabel, textLabel, textBox, speechRateLabel, speechRate, rateHint,
        ttsVolume, ttsVolumeValue, audio, audioLabel, audioDropdown, audioPreview, audioChannel,
    }
    for _, control in ipairs(frame.GlowTuningControls) do
        frame.TriggerGateControls[#frame.TriggerGateControls + 1] = control
    end
    for _, element in ipairs(frame.GlowTuningElements) do
        frame.TriggerGateElements[#frame.TriggerGateElements + 1] = element
    end

    -- Controls and labels whose availability depends on Solo-icon support.
    frame.SoloOptionControls = {
        soloOnTop, soloSize, soloSizeValue, soloCrop, soloCropAmount, soloCropValue,
        soloBar.icon, soloBar.iconValue, soloBar.width, soloBar.widthValue,
        soloBar.height, soloBar.heightValue, soloBar.text, soloBar.textValue, soloBar.match,
        soloShowSwipe, soloShowNumbers, soloKeepColored, soloClassSwipe,
        soloActiveBorder, soloAlwaysShow, soloDesaturateInactive, soloShowStacks,
        soloOpacity, soloOpacityValue, soloStackSize, soloStackSizeValue,
        soloCooldownSize, soloCooldownSizeValue,
        stackX, stackXValue, stackY, stackYValue,
        cooldownX, cooldownXValue, cooldownY, cooldownYValue,
        soloHotkey, soloHotkeySize, soloHotkeySizeValue,
        hotkeyX, hotkeyXValue, hotkeyY, hotkeyYValue,
        soloBlackBorder, soloBorderSize, soloBorderSizeValue, soloBarTheme.color, soloBarTheme.progress,
        soloFont, soloStackColor, soloCooldownColor, soloHotkeyColor, soloBarTextColor,
        resetSoloTextColors,
    }
    frame.SoloOptionElements = {
        soloOnTop, soloOnTopLabel, soloSize, soloSizeLabel, soloSizeValue,
        soloCrop, soloCropLabel, soloCropAmount, soloCropValue,
        soloBar.iconLabel, soloBar.icon, soloBar.iconValue,
        soloBar.widthLabel, soloBar.width, soloBar.widthValue,
        soloBar.heightLabel, soloBar.height, soloBar.heightValue,
        soloBar.textLabel, soloBar.text, soloBar.textValue,
        soloBar.match, soloBar.matchLabel,
        soloShowSwipe, soloShowSwipeLabel, soloShowNumbers, soloShowNumbersLabel,
        soloKeepColored, soloKeepColoredLabel, soloClassSwipe, soloClassSwipeLabel,
        soloActiveBorder, soloActiveBorderLabel, soloAlwaysShow, soloAlwaysShowLabel,
        soloDesaturateInactive, soloDesaturateInactiveLabel, soloShowStacks, soloShowStacksLabel,
        soloOpacity, soloOpacityLabel, soloOpacityValue,
        soloStackSizeLabel, soloStackSize, soloStackSizeValue,
        soloCooldownSizeLabel, soloCooldownSize, soloCooldownSizeValue,
        stackPositionLabel, stackXLabel, stackX, stackXValue, stackYLabel, stackY, stackYValue,
        cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownXValue, cooldownYLabel, cooldownY, cooldownYValue,
        soloHotkeyLabel, soloHotkey, soloHotkeySizeLabel, soloHotkeySize, soloHotkeySizeValue,
        hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyXValue,
        hotkeyYLabel, hotkeyY, hotkeyYValue,
        themeTitle, themeLine,
        soloBlackBorder, soloBlackBorderLabel, soloBorderSize, soloBorderSizeValue,
        soloBarTheme.color, soloBarTheme.progress, soloFontLabel, soloFont,
        soloTextColorsLabel, soloStackColor, soloCooldownColor, soloHotkeyColor, soloBarTextColor,
        resetSoloTextColors,
    }
    frame.SoloThemeElements = {
        themeTitle, themeLine, soloBlackBorder, soloBlackBorderLabel, soloBorderSize, soloBorderSizeValue,
        soloFontLabel, soloFont, soloTextColorsLabel, soloStackColor, soloCooldownColor, soloHotkeyColor,
        resetSoloTextColors,
    }
    frame.SoloEligibilityElements = {
        soloPanel, soloOnTop, soloOnTopLabel, soloSize, soloSizeLabel, soloSizeValue,
        soloCrop, soloCropLabel, soloCropAmount, soloCropValue,
        soloBar.iconLabel, soloBar.icon, soloBar.iconValue,
        soloBar.widthLabel, soloBar.width, soloBar.widthValue,
        soloBar.heightLabel, soloBar.height, soloBar.heightValue,
        soloBar.textLabel, soloBar.text, soloBar.textValue,
        soloBar.match, soloBar.matchLabel,
        soloShowSwipe, soloShowSwipeLabel, soloShowNumbers, soloShowNumbersLabel,
        soloKeepColored, soloKeepColoredLabel, soloClassSwipe, soloClassSwipeLabel,
        soloActiveBorder, soloActiveBorderLabel, soloAlwaysShow, soloAlwaysShowLabel,
        soloDesaturateInactive, soloDesaturateInactiveLabel, soloShowStacks, soloShowStacksLabel,
        soloOpacity, soloOpacityLabel, soloOpacityValue,
        soloStackSizeLabel, soloStackSize, soloStackSizeValue,
        soloCooldownSizeLabel, soloCooldownSize, soloCooldownSizeValue,
        stackPositionLabel, stackXLabel, stackX, stackXValue, stackYLabel, stackY, stackYValue,
        cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownXValue, cooldownYLabel, cooldownY, cooldownYValue,
        soloHotkeyLabel, soloHotkey, soloHotkeySizeLabel, soloHotkeySize, soloHotkeySizeValue,
        hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyXValue,
        hotkeyYLabel, hotkeyY, hotkeyYValue,
        frame.SecondaryIcon, frame.SecondaryIconLabel, frame.SecondaryIconSpellLabel,
        frame.SecondaryIconSpellID, frame.SecondaryIconSizeLabel,
        frame.SecondaryIconSize, frame.SecondaryIconSizeValue,
    }
    frame.SoloStackPositionControls = { stackX, stackXValue, stackY, stackYValue }
    frame.SoloStackPositionElements = {
        stackPositionLabel, stackXLabel, stackX, stackXValue, stackYLabel, stackY, stackYValue,
    }
    frame.SoloCooldownPositionControls = { cooldownX, cooldownXValue, cooldownY, cooldownYValue }
    frame.SoloCooldownPositionElements = {
        cooldownPositionLabel, cooldownXLabel, cooldownX, cooldownXValue, cooldownYLabel, cooldownY, cooldownYValue,
    }
    frame.SoloHotkeyPositionControls = { hotkeyX, hotkeyXValue, hotkeyY, hotkeyYValue }
    frame.SoloHotkeyPositionElements = {
        hotkeyPositionLabel, hotkeyXLabel, hotkeyX, hotkeyXValue, hotkeyYLabel, hotkeyY, hotkeyYValue,
    }

    -- Final widget styling, initial layout, and first data refresh.
    frame.BabyAurasReady = true
    local function WhitenButtonTree(parent)
        for _, child in ipairs({ parent:GetChildren() }) do
            if child.GetObjectType and child:GetObjectType() == "Button" then
                SetButtonTextWhite(child)
            end
            if child.GetChildren then WhitenButtonTree(child) end
        end
    end
    WhitenButtonTree(frame)
    self:ApplyEditorSectionLayout()
    self:Refresh()
end
