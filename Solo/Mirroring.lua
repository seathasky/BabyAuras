local _, addon = ...

local Solo = addon.Solo
local Utilities = addon.SoloUtilities
local IsSoloEnabled = Utilities.IsSoloEnabled

local function AccessibleNumber(value)
    if addon:IsSecret(value) then return nil end
    if canaccessvalue and not canaccessvalue(value) then return nil end
    return type(value) == "number" and value or nil
end

local function CopyPoints(frame)
    local points = {}
    local ok = pcall(function()
        for i = 1, frame:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
            points[#points + 1] = { point, relativeTo, relativePoint, x, y }
        end
    end)
    return ok and points or {}
end

local SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local CDM_MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local CDM_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local CDM_SWIPE_TEXTURE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"

local function ForEachNativeRegion(item, callback)
    if not item or type(item.GetRegions) ~= "function" then return end
    local regions = { item:GetRegions() }
    for _, region in ipairs(regions) do
        if region then callback(region) end
    end
end


local function RestoreSavedFontState(saved)
    if not saved or not saved.region then return end
    local region = saved.region
    pcall(function()
        if saved.parent and region:GetParent() ~= saved.parent then region:SetParent(saved.parent) end
        if saved.drawLayer and saved.drawLayer[1] then region:SetDrawLayer(unpack(saved.drawLayer)) end
        if saved.font and saved.font[1] then
            region:SetFont(saved.font[1], saved.font[2], saved.font[3] or "")
        end
        if saved.color then region:SetTextColor(unpack(saved.color)) end
        if saved.alpha ~= nil then region:SetAlpha(saved.alpha) end
        if saved.points then
            region:ClearAllPoints()
            for _, point in ipairs(saved.points) do region:SetPoint(unpack(point)) end
        end
    end)
end

function Solo:IsNativeHosted(item)
    local state = self.nativeHostStates and self.nativeHostStates[item]
    return state and state.display ~= nil
end

function Solo:GetNativeHostDisplay(item)
    local state = self.nativeHostStates and self.nativeHostStates[item]
    return state and state.display or nil
end

function Solo:RestoreNativeItem(item)
    if not item or not self.nativeHostStates then return end
    local state = self.nativeHostStates[item]
    if not state then return end
    self.nativeHostStates[item] = nil
    if state.textDefaults then
        RestoreSavedFontState(state.textDefaults.stack)
        RestoreSavedFontState(state.textDefaults.cooldown)
    end
    if state.display then
        state.display.NativeItem = nil
        state.display.nativeHosted = nil
    end
    pcall(function()
        item:ClearAllPoints()
        if state.scale ~= nil then item:SetScale(state.scale) end
        if state.width and state.height then item:SetSize(state.width, state.height) end
        for _, point in ipairs(state.points or {}) do
            item:SetPoint(unpack(point))
        end
        if state.alpha ~= nil then item:SetAlpha(state.alpha) end
        local icon = (type(item.GetIconTexture) == "function" and item:GetIconTexture()) or item.Icon
        if icon and state.iconTexCoord then icon:SetTexCoord(unpack(state.iconTexCoord)) end
        if icon and state.iconDesaturated ~= nil then icon:SetDesaturated(state.iconDesaturated) end
        -- Restore Blizzard's native rounded mask/overlay if this item stops being
        -- hosted by BabyAuras. During hosting we replace these presentation-only
        -- regions with a square surface so state refreshes cannot change the skin.
        ForEachNativeRegion(item, function(region)
            if region.IsObjectType and region:IsObjectType("MaskTexture") then
                pcall(region.SetAtlas, region, CDM_MASK_ATLAS)
            elseif region.IsObjectType and region:IsObjectType("Texture") then
                local okAtlas, atlas = pcall(region.GetAtlas, region)
                if okAtlas and atlas == CDM_OVERLAY_ATLAS then
                    pcall(region.SetAlpha, region, 1)
                end
            end
        end)
        if item.DebuffBorder then
            pcall(item.DebuffBorder.SetAlpha, item.DebuffBorder, state.debuffBorderAlpha or 1)
        end
        if item.Cooldown then
            pcall(item.Cooldown.SetSwipeTexture, item.Cooldown, CDM_SWIPE_TEXTURE)
            if state.cooldownDrawSwipe ~= nil then item.Cooldown:SetDrawSwipe(state.cooldownDrawSwipe) end
            if state.cooldownHideNumbers ~= nil then item.Cooldown:SetHideCountdownNumbers(state.cooldownHideNumbers) end
        end
    end)
end

function Solo:DetachLiveCooldown(display)
    if not display then return end
    if display.NativeItem then
        self:RestoreNativeItem(display.NativeItem)
    end
    display.LiveCooldown = nil
    display.nativeHosted = nil
    display.Icon:Show()
    display.Cooldown:Show()
    if display.Count then display.Count:Show() end
    if display.BarBackground then display.BarBackground:Show() end
    if display.BarTextOverlay then display.BarTextOverlay:Show() end
end

local function GetNativeHostGeometry(item, display)
    local dw = AccessibleNumber(display:GetWidth())
    local dh = AccessibleNumber(display:GetHeight())
    if not dw or not dh or dw <= 0 or dh <= 0 then return nil end

    -- The Blizzard item stays parented to its CDM viewer, while the BabyAuras
    -- shell is parented to UIParent and can also have its own Solo scale. Convert
    -- the BabyAuras bounds to the native item's parent coordinate space so the
    -- two frames occupy the exact same physical rectangle on screen. This is
    -- especially important for Crop Icon: fitting Blizzard's original square
    -- item into the shorter cropped shell leaves a small square inside a wide
    -- border. Resizing the native item makes its setAllPoints Icon/Cooldown/
    -- Applications children follow the cropped rectangle 1:1 instead.
    local displayEffective = AccessibleNumber(display:GetEffectiveScale()) or 1
    local parent = item:GetParent()
    local parentEffective = parent and AccessibleNumber(parent:GetEffectiveScale()) or 1
    if parentEffective <= 0 then parentEffective = 1 end

    return (dw * displayEffective) / parentEffective,
           (dh * displayEffective) / parentEffective
end

function Solo:PositionNativeItem(item, display)
    if not item or not display or self.suspended then return false end
    local state = self.nativeHostStates and self.nativeHostStates[item]
    if not state or state.display ~= display then return false end

    local width, height = GetNativeHostGeometry(item, display)
    if not width or not height then return false end

    local ok = pcall(function()
        item:ClearAllPoints()
        item:SetScale(1)
        item:SetSize(width, height)
        item:SetPoint("CENTER", display, "CENTER", 0, 0)
    end)
    return ok
end

function Solo:UpdateNativeVisibility(display)
    local item = display and display.NativeItem
    if not item then return end
    local settings = display.entry and addon:GetEntrySettings(display.entry.cooldownID, false)
    local positioning = self:IsPositioningMode()
    local alwaysShow = settings and settings.soloAlwaysShow == true

    -- Edit/positioning mode uses a BabyAuras-owned visual preview. Blizzard can
    -- hide its native CDM item while its settings/edit UI is open, which used to
    -- leave an empty BabyAuras mover because AttachNativeItem hides our texture.
    -- Keep the native item hosted but transparent while editing; outside edit
    -- mode Blizzard remains the sole renderer for the live icon/timer state.
    local shouldShow = IsSoloEnabled(display.entry)
        and not self.suspended
        and not positioning
        and (display.active or alwaysShow or (item.IsShown and item:IsShown()))
    local opacity = settings and Clamp(tonumber(settings.soloOpacity) or 100, 0, 100) / 100 or 1
    pcall(item.SetAlpha, item, shouldShow and opacity or 0)
    -- Hosted native text is intentionally parented to BabyAuras so it can sit
    -- above our border. Mirror the native item's effective alpha here so this
    -- layer still follows normal fade, hide, and positioning-mode behavior.
    if display.NativeTextOverlay then display.NativeTextOverlay:SetAlpha(shouldShow and opacity or 0) end

    -- If Blizzard has hidden the native item but BabyAuras is explicitly set to
    -- Always Show, use our local resolved-icon shell rather than leaving an empty
    -- border. This shell never receives cooldown/aura secret values.
    if display.Icon and not positioning then
        local nativeShown = false
        if item.IsShown then
            local ok, shown = pcall(item.IsShown, item)
            nativeShown = ok and shown == true
        end
        display.Icon:SetShown(alwaysShow and not nativeShown)
        if alwaysShow and not nativeShown then display.Icon:SetAlpha(opacity) end
    end
end


function Solo:ApplyNativeIconTexture(display)
    local item = display and display.NativeItem
    local entry = display and display.entry
    if not item or not entry then return end

    local texture = addon.Catalog:GetCustomIcon(entry)
    if not texture then
        -- Restore Blizzard's currently resolved texture without invoking any
        -- Blizzard refresh/mutation method. GetSpellTexture is read-only.
        if type(item.GetSpellTexture) == "function" then
            local ok, value = pcall(item.GetSpellTexture, item)
            if ok and value and not addon:IsSecret(value)
                and (not canaccessvalue or canaccessvalue(value)) then
                texture = value
            end
        end
    end

    local icon
    if type(item.GetIconTexture) == "function" then
        local ok, value = pcall(item.GetIconTexture, item)
        if ok then icon = value end
    end
    icon = icon or item.Icon
    if icon and texture and type(icon.SetTexture) == "function" then
        -- Texture-only visual customization. Never touch Blizzard cooldown,
        -- aura, charge, or cooldownInfo state here.
        pcall(icon.SetTexture, icon, texture)
    end
end

function Solo:ApplyNativeAppearance(display)
    local item = display and display.NativeItem
    local entry = display and display.entry
    if not item or not entry then return end
    local settings = addon:GetEntrySettings(entry.cooldownID, false) or {}
    local state = self.nativeHostStates and self.nativeHostStates[item]

    local icon
    if type(item.GetIconTexture) == "function" then
        local ok, value = pcall(item.GetIconTexture, item)
        if ok then icon = value end
    end
    icon = icon or item.Icon

    if icon then
        -- BabyAuras' icon skin is intentionally square and slightly zoomed. Do
        -- not restore Blizzard's 0..1 UVs here: Blizzard refreshes applications,
        -- borders and textures as state changes, and doing so made hosted icons
        -- visibly snap back to the stock CDM look when stacks appeared.
        local crop = settings.soloCropEnabled == true
            and Clamp(tonumber(settings.soloCropPercent) or 0, 0, 50) / 100 or 0
        local top, bottom = 0.08, 0.92
        if crop > 0 then
            pcall(icon.SetTexCoord, icon, 0.08, 0.92, top, top + ((bottom - top) * (1 - crop)))
        else
            pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
        end

        local desaturated
        if settings.soloDesaturateInactive == true and display.activeState ~= true then
            desaturated = true
        elseif settings.soloKeepColored == true then
            desaturated = false
        elseif state then
            desaturated = state.iconDesaturated
        end
        if desaturated ~= nil then pcall(icon.SetDesaturated, icon, desaturated) end
    end

    if not display.isBar then
        -- The native BuffIcon template has a rounded mask, a large stock overlay,
        -- and a debuff border that Blizzard may show again when applications
        -- change. Keep Blizzard's runtime state, but normalize only these visual
        -- regions to BabyAuras' square/thin-border presentation. This mirrors the
        -- safe presentation-only technique used by established CDM skin addons.
        ForEachNativeRegion(item, function(region)
            if region.IsObjectType and region:IsObjectType("MaskTexture") then
                pcall(region.SetTexture, region, SQUARE_TEXTURE)
            elseif region.IsObjectType and region:IsObjectType("Texture") then
                local okAtlas, atlas = pcall(region.GetAtlas, region)
                if okAtlas and atlas == CDM_OVERLAY_ATLAS then
                    pcall(region.SetAlpha, region, 0)
                end
            end
        end)
        if item.DebuffBorder then
            pcall(item.DebuffBorder.SetAlpha, item.DebuffBorder, 0)
        end
    end

    local cooldown = item.Cooldown
    if cooldown then
        if not display.isBar then
            pcall(cooldown.SetSwipeTexture, cooldown, SQUARE_TEXTURE)
        end
        pcall(cooldown.SetDrawSwipe, cooldown, settings.soloShowSwipe ~= false)
        pcall(cooldown.SetHideCountdownNumbers, cooldown, settings.soloShowNumbers == false)
        if settings.soloClassSwipe == true then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
            if color then pcall(cooldown.SetSwipeColor, cooldown, color.r, color.g, color.b, 0.82) end
        end
    end

    -- Native stack and cooldown FontStrings are presentation-only. Text.lua owns
    -- size/color/position; reapply it whenever any appearance setting changes.
    if self.ApplyTextLayout then self:ApplyTextLayout(display) end
    self:UpdateNativeVisibility(display)
end

function Solo:AttachNativeItem(item, display)
    if not item or not display or self.suspended then return false end
    self.nativeHostStates = self.nativeHostStates or setmetatable({}, { __mode = "k" })
    local state = self.nativeHostStates[item]
    if state and state.display ~= display then
        self:RestoreNativeItem(item)
        state = nil
    end
    if not state then
        state = {
            display = display,
            points = CopyPoints(item),
            scale = AccessibleNumber(item:GetScale()) or 1,
            width = AccessibleNumber(item:GetWidth()),
            height = AccessibleNumber(item:GetHeight()),
            alpha = AccessibleNumber(item:GetAlpha()) or 1,
        }
        local icon = (type(item.GetIconTexture) == "function" and select(2, pcall(item.GetIconTexture, item))) or item.Icon
        if icon then
            pcall(function() state.iconTexCoord = { icon:GetTexCoord() } end)
            pcall(function() state.iconDesaturated = icon:IsDesaturated() end)
        end
        if item.DebuffBorder then
            pcall(function() state.debuffBorderAlpha = item.DebuffBorder:GetAlpha() end)
        end
        if item.Cooldown then
            pcall(function() state.cooldownDrawSwipe = item.Cooldown:GetDrawSwipe() end)
            pcall(function() state.cooldownHideNumbers = item.Cooldown:GetHideCountdownNumbers() end)
        end
        self.nativeHostStates[item] = state
    else
        state.display = display
    end
    display.NativeItem = item
    display.nativeHosted = true
    display.LiveCooldown = nil

    -- BabyAuras becomes the positioning/alert shell only. Blizzard continues to
    -- draw the icon, cooldown wheel, countdown text, charges and applications.
    display.Icon:Hide()
    display.Cooldown:Hide()
    if display.Count then display.Count:Hide() end
    if display.BarBackground then display.BarBackground:Hide() end
    if display.BarTextOverlay then display.BarTextOverlay:Hide() end

    self:PositionNativeItem(item, display)
    self:ApplyNativeIconTexture(display)
    self:ApplyNativeAppearance(display)
    self:UpdateNativeVisibility(display)
    return true
end

function Solo:RepositionHostedViewer(viewer)
    if not viewer or not self.nativeHostStates then return end
    for item, state in pairs(self.nativeHostStates) do
        if state and state.display and self:GetViewer(item) == viewer then
            self:PositionNativeItem(item, state.display)
            self:UpdateNativeVisibility(state.display)
        end
    end
end

function Solo:UpdateActiveState(item, display)
    if not item or not display then return end
    local active
    if type(item.IsActive) == "function" then
        local ok, value = pcall(item.IsActive, item)
        if ok and not addon:IsSecret(value) and (not canaccessvalue or canaccessvalue(value)) then
            active = value == true
        end
    end
    if active ~= nil then
        display.active = active
        display.activeState = active
    elseif item.IsShown then
        local ok, shown = pcall(item.IsShown, item)
        if ok then
            display.active = shown == true
            display.activeState = shown == true
        end
    end
    self:UpdateNativeVisibility(display)
end

function Solo:SyncCooldown(item, display)
    -- Native-hosted solo icons deliberately do not copy cooldown data. In combat
    -- Blizzard's CDM can use secret values that a third-party CooldownFrame is
    -- forbidden to consume. Keeping Blizzard's whole item intact is the 1:1 path.
    if display and display.NativeItem == item then
        self:PositionNativeItem(item, display)
        self:ApplyNativeIconTexture(display)
        self:ApplyNativeAppearance(display)
        self:UpdateNativeVisibility(display)
        return true
    end
    return false
end

function Solo:InstallMirrors(item, display)
    if not item or not display then return end
    self:AttachNativeItem(item, display)
end
