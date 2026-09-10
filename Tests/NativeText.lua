-- Run from the addon directory with Lua 5.1: lua Tests/NativeText.lua
unpack = unpack or table.unpack
STANDARD_TEXT_FONT = "default"
local timers = {}
C_Timer = { After = function(delay, callback)
    timers[#timers + 1] = { delay = delay, callback = callback }
end }
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
local function flush()
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do timer.callback() end
end
local function region(parent)
    local value = { parent = parent, font = { "native", 12, "" }, color = { 1, 1, 1, 1 }, alpha = 1, points = {} }
    function value:GetParent() return self.parent end
    function value:SetParent(p) self.parent = p end
    function value:GetDrawLayer() return "ARTWORK", 0 end
    function value:SetDrawLayer(...) self.layer = { ... } end
    function value:GetFont() return unpack(self.font) end
    function value:SetFont(...) self.font = { ... } end
    function value:SetFontObject() self.font = { "reset", 9, "" } end
    function value:GetTextColor() return unpack(self.color) end
    function value:SetTextColor(...) self.color = { ... } end
    function value:GetAlpha() return self.alpha end
    function value:SetAlpha(a) self.alpha = a end
    function value:GetNumPoints() return #self.points end
    function value:GetPoint(i) return unpack(self.points[i]) end
    function value:ClearAllPoints() self.points = {} end
    function value:SetPoint(...) self.points[#self.points + 1] = { ... } end
    return value
end
local function fixture(lazy)
    local item = region({})
    item.Applications = { Applications = region(item) }
    item.Cooldown = { hidden = false }
    local cooldown = item.Cooldown
    if not lazy then cooldown.text = region(cooldown) end
    function cooldown:GetCountdownFontString() return self.text end
    function cooldown:SetHideCountdownNumbers(hidden) self.hidden = hidden end
    function cooldown:SetCooldown() self.text = self.text or region(self) end
    function cooldown:SetCountdownFont() if self.text then self.text:SetFontObject() end end
    local display = { NativeItem = item, NativeTextOverlay = {}, entry = {
        soloShowStacks = true, soloShowNumbers = true,
        soloStackPosition = { x = 4, y = 5 }, soloCooldownPosition = { x = 6, y = 7 },
    } }
    return item, display
end
local addon = { Solo = { nativeHostStates = {} }, Defaults = {}, SoloUtilities = {
    GetEntryAppearance = function(entry) return entry end,
} }
local Solo = addon.Solo
function addon:IsSecret() return false end
assert(loadfile("Solo/Text.lua"))("BabyAuras", addon)
local layouts = 0
function Solo:ApplyTextLayout(display)
    layouts = layouts + 1
    self:ApplyNativeTextLayout(display, 18, 24, "custom", 1, 0, 0, 1, 0, 1, 0, 1)
end
local item, display = fixture()
Solo.nativeHostStates[item] = { display = display }
Solo:ApplyTextLayout(display)
assert(#timers == 0, "styling must not queue itself")
local stack, cooldown = item.Applications.Applications, item.Cooldown
stack:SetFontObject()
stack:SetTextColor(0, 0, 0, 0)
stack:SetAlpha(0)
stack:SetParent(item)
stack:ClearAllPoints()
cooldown:SetCountdownFont()
cooldown:SetHideCountdownNumbers(true)
assert(#timers == 1, "external changes must coalesce")
flush()
assert(stack.font[1] == "custom" and stack.font[2] == 18)
assert(stack.color[1] == 1 and stack.alpha == 1)
assert(stack.parent == item and stack.points[1][4] == 4)
assert(cooldown.text.parent == cooldown, "countdown must retain native lifecycle ownership")
assert(cooldown.text.font[2] == 24 and not cooldown.hidden)
assert(#timers == 0, "repair must not create a refresh loop")
display.entry.soloShowStacks, display.entry.soloShowNumbers = false, false
stack:SetAlpha(1)
cooldown:SetHideCountdownNumbers(false)
flush()
assert(stack.alpha == 0 and cooldown.text.alpha == 0 and cooldown.hidden)
stack:SetFontObject()
cooldown:SetCooldown()
local before = layouts
Solo.nativeHostStates[item] = { display = display }
flush()
assert(layouts == before, "old host callback must not touch a new host")
Solo.suspended = true
stack:SetAlpha(1)
assert(#timers == 0, "suspended styling must not queue")
Solo.suspended = nil
local lazyItem, lazyDisplay = fixture(true)
Solo.nativeHostStates[lazyItem] = { display = lazyDisplay }
Solo:ApplyTextLayout(lazyDisplay)
flush()
assert(#timers == 0, "missing countdown retries must be bounded")
lazyItem.Cooldown:SetCooldown()
flush()
assert(lazyItem.Cooldown.text.font[2] == 24, "late countdown must receive saved styling")
assert(#timers == 0)

assert(loadfile("Solo/Mirroring.lua"))("BabyAuras", addon)
Solo.PositionNativeItem = function() end
Solo.ApplyNativeIconTexture = function() end
Solo.ApplyNativeAppearance = function() end
Solo.UpdateNativeVisibility = function() end
local oldItem, shell = fixture()
local newItem = fixture()
oldItem.SetScale = function() end
oldItem.SetSize = function() end
newItem.GetScale = function() return 1 end
newItem.GetWidth = function() return 40 end
newItem.GetHeight = function() return 40 end
shell.Icon = { Hide = function() end }
shell.Cooldown = { Hide = function() end }
Solo.nativeHostStates[oldItem] = { display = shell }
Solo:AttachNativeItem(newItem, shell)
assert(Solo.nativeHostStates[oldItem] == nil and shell.NativeItem == newItem,
    "replacing a frame must release its previous host")
Solo.nativeHostStates[oldItem] = { display = shell }
Solo:RestoreNativeItem(oldItem)
assert(shell.NativeItem == newItem, "stale restoration must not detach the replacement")
print("Native text regression checks passed")
