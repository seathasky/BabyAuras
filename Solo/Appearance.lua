local _, addon = ...

local Solo = addon.Solo
local Defaults = addon.Defaults
local SharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
local Utilities = addon.SoloUtilities
local GetEntryAppearance = Utilities.GetEntryAppearance
local GetTextColor = Utilities.GetTextColor
local GetClassColor = Utilities.GetClassColor
local GetPhysicalPixelSize = Utilities.GetPhysicalPixelSize
local GetSoloBaseDimensions = Utilities.GetSoloBaseDimensions
local IsSoloEnabled = Utilities.IsSoloEnabled
local EDIT_SELECTION_COLOR = { r = 0.20, g = 1, b = 0.35 }

local function IsBlackBorderEnabled(display, settings)
    if settings.soloBlackBorder ~= nil then return settings.soloBlackBorder == true end
    return not display.isBar
end

local function SetPixelBorderThickness(display, pixels)
    local thickness = GetPhysicalPixelSize(display, pixels)
    local top, bottom, left, right = unpack(display.PixelBorder.edges)
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(thickness)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(thickness)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
    left:SetWidth(thickness)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
    right:SetWidth(thickness)
end

function Solo:ApplyAppearance(display)
    if not display or display.applyingAppearance then return end
    display.applyingAppearance = true
    local settings = GetEntryAppearance(display.entry)
    if not display.isBar then
        local cropPercent = settings.soloCropEnabled == true
            and Clamp(tonumber(settings.soloCropPercent) or Defaults.soloAppearance.cropPercent, 0, 50) or 0
        local cropFraction = cropPercent / 100
        local baseWidth, baseHeight = GetSoloBaseDimensions(display.entry, nil, false)
        display:SetSize(baseWidth, baseHeight * (1 - cropFraction))
        local textureTop, textureBottom = 0.08, 0.92
        display.Icon:SetTexCoord(0.08, 0.92, textureTop,
            textureTop + ((textureBottom - textureTop) * (1 - cropFraction)))
    end
    local opacity = Clamp(tonumber(settings.soloOpacity) or Defaults.soloAppearance.opacity, 0, 100) / 100
    display.Icon:SetAlpha(opacity)
    display.PixelBorder:SetAlpha(opacity)
    if display.isBar then
        local barTextSize = Clamp(math.floor(tonumber(settings.soloBarTextSize)
            or Defaults.soloBarAppearance.textSize), 8, 32)
        local fontName = settings.soloFont or Defaults.soloAppearance.font
        local fontPath = SharedMedia and SharedMedia:Fetch("font", fontName) or STANDARD_TEXT_FONT
        local r, g, b, a = GetTextColor(settings, "soloBarTextColor", "barTextColor")
        if display.BarName then
            display.BarName:SetFont(fontPath or STANDARD_TEXT_FONT, barTextSize, "OUTLINE")
            display.BarName:SetTextColor(r, g, b, a)
        end
        if display.BarDuration then
            display.BarDuration:SetFont(fontPath or STANDARD_TEXT_FONT, barTextSize, "OUTLINE")
            display.BarDuration:SetTextColor(r, g, b, a)
        end
    end
    display.Count:SetShown(settings.soloShowStacks ~= false)
    self:ApplyTextLayout(display)
    local cooldown = display.LiveCooldown or display.Cooldown
    if settings.soloShowSwipe == false then
        pcall(cooldown.SetDrawSwipe, cooldown, false)
    elseif display.sourceDrawSwipe ~= nil then
        -- CDM deliberately hides the radial swipe while certain charge/use
        -- counters recharge. Preserve that native state instead of drawing a
        -- conflicting wheel over the timer it supplied.
        pcall(cooldown.SetDrawSwipe, cooldown, display.sourceDrawSwipe)
    else
        pcall(cooldown.SetDrawSwipe, cooldown, true)
    end
    if settings.soloShowNumbers == false then
        pcall(cooldown.SetHideCountdownNumbers, cooldown, true)
    else
        pcall(cooldown.SetHideCountdownNumbers, cooldown, false)
    end
    if settings.soloClassSwipe == true then
        local color = GetClassColor()
        pcall(cooldown.SetSwipeColor, cooldown, color.r, color.g, color.b, 0.82)
    elseif display.sourceSwipeColor then
        pcall(cooldown.SetSwipeColor, cooldown, unpack(display.sourceSwipeColor))
    end
    if settings.soloDesaturateInactive == true and display.activeState ~= true then
        display.Icon:SetDesaturated(true)
    elseif settings.soloKeepColored == true then
        display.Icon:SetDesaturated(false)
    elseif display.sourceDesaturated ~= nil then
        pcall(display.Icon.SetDesaturated, display.Icon, display.sourceDesaturated)
    end

    local frameLevel = settings.soloOnTop == true and 100 or 1
    display:SetFrameLevel(frameLevel)
    pcall(cooldown.SetFrameLevel, cooldown, frameLevel + 2)
    display.VisualOverlay:SetFrameLevel(frameLevel + 5)
    if display.BarBackground then display.BarBackground:SetFrameLevel(frameLevel + 1) end
    if display.BarTextOverlay then display.BarTextOverlay:SetFrameLevel(frameLevel + 6) end
    display.PixelBorder:SetFrameLevel(frameLevel + 7)
    if display.SpellActivationAlert then display.SpellActivationAlert:SetFrameLevel(frameLevel + 8) end
    if display.NativeTextOverlay then display.NativeTextOverlay:SetFrameLevel(frameLevel + 10) end
    for _, mover in ipairs(display.TextMovers or {}) do mover:SetFrameLevel(frameLevel + 10) end
    if display.BadgeFrame then display.BadgeFrame:SetFrameLevel(frameLevel + 12) end
    display.EditOutline:SetFrameLevel(math.max(0, frameLevel - 1))

    local borderPixels = Clamp(math.floor(tonumber(settings.soloBorderPixels) or Defaults.soloAppearance.borderPixels), 1, 3)
    SetPixelBorderThickness(display, borderPixels)
    local borderEnabled = IsBlackBorderEnabled(display, settings)
    display.PixelBorder:SetShown(borderEnabled)
    if display.BarBase then
        local r, g, b, a = GetTextColor(settings, "soloBarFillColor", "barFillColor")
        display.BarBase:SetColorTexture(r, g, b, a)
    end
    if display.BarProgress then
        local r, g, b, a = GetTextColor(settings, "soloBarProgressColor", "barProgressColor")
        display.BarProgress:SetStatusBarColor(r, g, b, a)
    end
    display.applyingAppearance = nil
end

function Solo:RefreshDisplay(display)
    local entry = display.entry
    local specPreview = self.IsSpecPreviewEnabled and self:IsSpecPreviewEnabled(entry) or false
    local enabled = IsSoloEnabled(entry) or specPreview
    if display.isSecondary then
        local settings = addon:GetEntrySettings(entry.cooldownID, false)
        enabled = enabled and settings and settings.secondaryIconEnabled == true
        specPreview = false
    end
    local positioning = self:IsPositioningMode()
    display.Icon:SetTexture(self:GetTexture(entry, display))
    if display.BarName then display.BarName:SetText(entry.name) end
    local showEditorBadge = positioning and BabyAurasDB.hideSoloLabels ~= true
    -- Tracked bars have a much smaller icon footprint, so the image badge
    -- obscures the spell art. Keep only the blue B on bars while positioning.
    display.Badge:SetShown(showEditorBadge and not display.isBar)
    display.BadgeLetter:SetShown(showEditorBadge)
    local appearance = GetEntryAppearance(entry)
    local activeBorder = appearance.soloActiveBorder == true and display.activeState == true
    local selectedEntry = addon.GUI and addon.GUI.selected
    local editSelected = positioning and selectedEntry
        and selectedEntry.cooldownID == entry.cooldownID
    if positioning then
        display:SetBackdropBorderColor(0.55, 0.9, 1, 0)
    elseif activeBorder then
        local color = GetClassColor()
        display:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    else
        display:SetBackdropBorderColor(0.55, 0.9, 1, 0)
    end
    self:ApplyAppearance(display)
    -- Live mode is rendered by Blizzard's native CDM item. Edit mode must not
    -- depend on Blizzard keeping that item visible, so render a local preview
    -- shell from the same resolved texture while positioning. This preview never
    -- receives secret cooldown/aura values and therefore cannot taint CDM.
    if display.NativeItem then
        self:ApplyNativeAppearance(display)
        -- Live mode uses Blizzard's native CDM item. Edit mode and cross-spec
        -- previews use BabyAuras-owned artwork so they remain visible even when
        -- Blizzard hides or recycles the native item for the inactive spec.
        display.Icon:SetShown(positioning or specPreview)
        self:ApplyNativeIconTexture(display)
        display.Cooldown:Hide()
        display.Count:Hide()
        if display.BarBackground then display.BarBackground:SetShown(positioning or specPreview) end
        if display.BarTextOverlay then display.BarTextOverlay:SetShown(positioning or specPreview) end
    elseif specPreview then
        -- A preview-only display must always expose its local texture. A display
        -- object may have previously been native-hosted before a spec switch.
        display.Icon:Show()
    end

    local textPreview = positioning and self.textPreviewEnabled == true
    display.StackPreview:SetShown(textPreview and appearance.soloShowStacks ~= false)
    display.Count:SetShown(not display.NativeItem and not display.isSecondary
        and not textPreview and appearance.soloShowStacks ~= false)
    display.CooldownPreview:SetShown(textPreview and appearance.soloShowNumbers ~= false)
    if textPreview and appearance.soloShowNumbers ~= false then
        pcall((display.LiveCooldown or display.Cooldown).SetHideCountdownNumbers,
            display.LiveCooldown or display.Cooldown, true)
    end
    if editSelected then
        SetPixelBorderThickness(display, 2)
        display.PixelBorder:SetAlpha(1)
    end
    local pixelColor = editSelected and EDIT_SELECTION_COLOR
        or activeBorder and GetClassColor()
        or { r = 0, g = 0, b = 0 }
    for _, edge in ipairs(display.PixelBorder.edges) do
        edge:SetColorTexture(pixelColor.r, pixelColor.g, pixelColor.b, 1)
    end
    local borderEnabled = IsBlackBorderEnabled(display, appearance)
    display.PixelBorder:SetShown(borderEnabled or activeBorder or editSelected)
    if display.BarBase then
        local r, g, b, a = GetTextColor(appearance, "soloBarFillColor", "barFillColor")
        display.BarBase:SetColorTexture(r, g, b, a)
    end
    if display.BarProgress then
        local r, g, b, a = GetTextColor(appearance, "soloBarProgressColor", "barProgressColor")
        display.BarProgress:SetStatusBarColor(r, g, b, a)
    end
    -- The compact B badge and selected-icon border are the edit markers. Keep
    -- the draggable hit area without drawing a large box around every icon.
    display.EditOutline:Hide()
    self:UpdateLinkVisual(display)
    display:EnableMouse(positioning)
    local alwaysShow = appearance.soloAlwaysShow == true
    display:SetShown(enabled and (specPreview or positioning or (not self.suspended and (display.active or alwaysShow))))
    if display.NativeItem then
        self:PositionNativeItem(display.NativeItem, display)
        self:UpdateNativeVisibility(display)
    end
    if addon.ActionBarGlow and not display.isSecondary then
        addon.ActionBarGlow:UpdateEntry(entry, enabled and display.activeState == true
            and not specPreview and not positioning and not self.suspended)
    end
end

function Solo:RefreshEditSelection()
    for _, display in pairs(self.displays) do self:RefreshDisplay(display) end
end
