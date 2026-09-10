-- Run from the addon directory with Lua 5.1.
local timers, active, assignments, log = {}, {}, {}, {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
Enum = { CooldownViewerCategory = { TrackedBuff = 3, TrackedBar = 4 },
    CooldownViewerAlertEventType = { Available = 1, ChargeGained = 2, OnAuraApplied = 3,
        OnAuraRemoved = 4, PandemicTime = 5 } }
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(self, ...) original(self, ...); callback(self, ...) end
end
local function flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end
local viewer = { itemFramePool = {
    IsActive = function(_, item) return active[item] == true end,
    EnumerateActive = function() return next, active, nil end,
} }
EssentialCooldownViewer = viewer
local addon = { Solo = { sources = {}, displays = {} }, Catalog = { Build = function() end } }
function addon:IsSecret() return false end
function addon:TryMethod(item, method) return true, item[method](item) end
function addon.Catalog:Get(id) return id and { cooldownID = id } end
function addon.Solo:GetViewer() return viewer end
function addon.Solo:ReleaseItem(item)
    log[#log + 1] = "release:" .. item.name
    assignments[item] = nil
end
function addon.Solo:RefreshItem(item)
    local entry = addon.Runtime.itemEntries[item]
    if entry then
        for other, id in pairs(assignments) do
            assert(other == item or id ~= entry.cooldownID, "new owner attached before old owner released")
        end
        assignments[item] = entry.cooldownID
        log[#log + 1] = "attach:" .. item.name
    end
end
function addon.Solo:SyncFromItem(item)
    assert(addon.Runtime.itemEntries[item].cooldownID == item.id, "sync used stale cooldown ID")
    self:RefreshItem(item)
end
function addon.Solo:ReconcileDisplays() end
assert(loadfile("Core/Runtime.lua"))("BabyAuras", addon)
local runtime = addon.Runtime
local function item(name, id)
    return { name = name, id = id, GetCooldownID = function(self) return self.id end,
        ResetCooldownData = function(self) self.id = nil end }
end
local a, b = item("a", 1), item("b", 2)
active[a], active[b] = true, true
runtime:HookItem(a)
runtime:HookItem(b)
-- The same active frames exchange IDs in place (no pool release).
a.id, b.id = 2, 1
log = {}
runtime:RebuildFromCDM()
assert(log[1]:match("release") and log[2]:match("release"))
assert(assignments[a] == 2 and assignments[b] == 1)
-- A queued refresh from the previous assignment must be invalidated at reset.
runtime:QueueItemRefresh(a, true)
a:ResetCooldownData()
assert(runtime.itemEntries[a] == nil and assignments[a] == nil)
active[a] = nil
flush()
assert(assignments[a] == nil, "released frame was reattached by an old callback")
-- A reused frame gets fresh identity even if only a sync request arrives.
active[a], a.id = true, 3
runtime:QueueItemRefresh(a, true)
flush()
assert(assignments[a] == 3)
a.id = 4
runtime:QueueItemRefresh(a, true)
flush()
assert(assignments[a] == 4)
-- RefreshAll/Install must perform the same two-phase release as CDM rebuilds.
addon.Solo.InstallEditorHooks = function() end
a.id, b.id = 1, 4
log = {}
runtime:Install()
assert(log[1]:match("release") and log[2]:match("release"))
assert(assignments[a] == 1 and assignments[b] == 4)
print("Frame lifecycle regression checks passed")
