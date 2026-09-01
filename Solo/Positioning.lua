local _, addon = ...

local Solo = addon.Solo
local Utilities = addon.SoloUtilities
local GetSoloBaseDimensions = Utilities.GetSoloBaseDimensions
local IsSoloEnabled = Utilities.IsSoloEnabled

local function IsPositioningVisible(entry)
    return Solo.IsVisibleForPositioning and Solo:IsVisibleForPositioning(entry) or IsSoloEnabled(entry)
end
local GetScreenCenter = Utilities.GetScreenCenter
local ScreenToUIParent = Utilities.ScreenToUIParent

function Solo:GetPosition(entry, create, copyIndex)
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, create)
    if not settings then return nil end
    local key = copyIndex == 2 and "secondarySoloPosition" or "soloPosition"
    if create and not settings[key] then
        settings[key] = { x = 0, y = 0 }
    end
    return settings[key]
end

function Solo:GetDefaultPosition(entry, item, copyIndex)
    if copyIndex == 2 then
        local primary = self:GetPosition(entry, false, 1)
        if primary then
            local isBar = item and self:IsTrackedBarItem(item) or false
            local width = GetSoloBaseDimensions(entry, item, isBar)
            local primaryScale = self:GetScale(entry, 1)
            local secondaryScale = self:GetScale(entry, 2)
            return {
                x = (primary.x or 0) + ((width * primaryScale + width * secondaryScale) / 2) + 8,
                y = primary.y or 0,
            }
        end
    end
    self:CreateEditBar()
    local barPosition = BabyAurasDB.editBarPosition or { x = 0, y = 0 }
    local barHeight = self.editBar:GetHeight() * self.editBar:GetScale()
    local occupiedWidth = 0
    for cooldownID, display in pairs(self.displays) do
        if cooldownID ~= entry.cooldownID and IsPositioningVisible(display.entry) then
            occupiedWidth = occupiedWidth + (display:GetWidth() * display:GetScale()) + 6
        end
    end
    local isBar = item and self:IsTrackedBarItem(item) or false
    local width, height = GetSoloBaseDimensions(entry, item, isBar)
    local scale = self:GetScale(entry)
    local x = (barPosition.x or 0) - 270 + occupiedWidth + (width * scale / 2)
    local y = (barPosition.y or 0) - (barHeight / 2) - 14 - (height * scale / 2)
    return { x = x, y = y }
end

function Solo:SaveDisplayPosition(display)
    local screenX, screenY = GetScreenCenter(display)
    local centerX, centerY = ScreenToUIParent(screenX, screenY)
    local rootX, rootY = UIParent:GetCenter()
    if not centerX or not centerY or not rootX or not rootY then return end
    local position = self:GetPosition(display.entry, true, display.copyIndex)
    position.x = centerX - rootX
    position.y = centerY - rootY
end

function Solo:ApplyDisplayPosition(display)
    local position = self:GetPosition(display.entry, true, display.copyIndex)
    local scale = display:GetScale()
    if not scale or scale == 0 then scale = 1 end
    display:ClearAllPoints()
    display:SetPoint("CENTER", UIParent, "CENTER", (position.x or 0) / scale, (position.y or 0) / scale)
end

function Solo:CreateSnapVisuals()
    if self.snapVisuals then return end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetAllPoints()
    frame:SetFrameStrata("TOOLTIP")
    frame:EnableMouse(false)

    local vertical = frame:CreateTexture(nil, "OVERLAY")
    vertical:SetColorTexture(0.25, 1, 0.45, 0.9)
    vertical:SetSize(2, UIParent:GetHeight())
    vertical:Hide()

    local horizontal = frame:CreateTexture(nil, "OVERLAY")
    horizontal:SetColorTexture(0.25, 1, 0.45, 0.9)
    horizontal:SetSize(UIParent:GetWidth(), 2)
    horizontal:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetText("SNAP")
    text:SetTextColor(0.25, 1, 0.45)
    text:Hide()
    self.snapVisuals = { vertical = vertical, horizontal = horizontal, text = text }
end

function Solo:ClearSnap(display)
    if self.snapVisuals then
        self.snapVisuals.vertical:Hide()
        self.snapVisuals.horizontal:Hide()
        self.snapVisuals.text:Hide()
    end
    if self.snapTarget then self:RefreshDisplay(self.snapTarget) end
    self.snapTarget = nil
    if display then
        display.snapX = nil
        display.snapY = nil
        self:RefreshDisplay(display)
    end
end

function Solo:UpdateSnap(display)
    if BabyAurasDB.snapEnabled == false then
        self:ClearSnap(display)
        return
    end
    local centerX, centerY = GetScreenCenter(display)
    if not centerX or not centerY then return end
    local rootScale = UIParent:GetEffectiveScale()
    local threshold = 12 * rootScale
    local gap = (BabyAurasDB.snapSpacing or 1) * rootScale
    local displayWidth = display:GetWidth() * display:GetEffectiveScale()
    local displayHeight = display:GetHeight() * display:GetEffectiveScale()
    local displayLinkGroup = not display.isSecondary and self:GetLinkGroupID(display.entry) or nil
    local bestX, bestY, bestXDistance, bestYDistance, target

    local function ConsiderX(value, other)
        local distance = math.abs(centerX - value)
        if distance <= threshold and (not bestXDistance or distance < bestXDistance) then
            bestX, bestXDistance, target = value, distance, other
        end
    end
    local function ConsiderY(value, other)
        local distance = math.abs(centerY - value)
        if distance <= threshold and (not bestYDistance or distance < bestYDistance) then
            bestY, bestYDistance, target = value, distance, other
        end
    end

    for _, other in pairs(self.displays) do
        local sameLinkGroup = displayLinkGroup and not other.isSecondary
            and self:GetLinkGroupID(other.entry) == displayLinkGroup
        if other ~= display and not sameLinkGroup and other:IsShown() and IsPositioningVisible(other.entry) then
            local otherX, otherY = GetScreenCenter(other)
            if otherX and otherY then
                local otherWidth = other:GetWidth() * other:GetEffectiveScale()
                local otherHeight = other:GetHeight() * other:GetEffectiveScale()
                ConsiderX(otherX, other)
                ConsiderX(otherX - ((otherWidth + displayWidth) / 2) - gap, other)
                ConsiderX(otherX + ((otherWidth + displayWidth) / 2) + gap, other)
                ConsiderY(otherY, other)
                ConsiderY(otherY - ((otherHeight + displayHeight) / 2) - gap, other)
                ConsiderY(otherY + ((otherHeight + displayHeight) / 2) + gap, other)
            end
        end
    end

    if self.snapTarget and self.snapTarget ~= target then self:RefreshDisplay(self.snapTarget) end
    self.snapTarget = target
    display.snapX, display.snapY = bestX, bestY
    self:CreateSnapVisuals()
    local visuals = self.snapVisuals
    local bestUIX, bestUIY = ScreenToUIParent(bestX, bestY)
    local rootX, rootY = UIParent:GetCenter()
    if bestUIX and rootX then
        visuals.vertical:ClearAllPoints()
        visuals.vertical:SetPoint("CENTER", UIParent, "CENTER", bestUIX - rootX, 0)
        visuals.vertical:Show()
    else
        visuals.vertical:Hide()
    end
    if bestUIY and rootY then
        visuals.horizontal:ClearAllPoints()
        visuals.horizontal:SetPoint("CENTER", UIParent, "CENTER", 0, bestUIY - rootY)
        visuals.horizontal:Show()
    else
        visuals.horizontal:Hide()
    end
    if target and (bestX or bestY) then
        target:SetBackdropBorderColor(0.25, 1, 0.45, 1)
        display:SetBackdropBorderColor(0.25, 1, 0.45, 1)
        visuals.text:ClearAllPoints()
        visuals.text:SetPoint("BOTTOM", display, "TOP", 0, 20)
        visuals.text:Show()
    else
        visuals.text:Hide()
        self:RefreshDisplay(display)
    end
end
