local addonName, IC = ...

IC.name = addonName

-- Which ring each R3 combo opens. "native" leaves the game's own R3 action.
IC.COMBOS = { "R3", "L1", "L2", "R1", "R2" }
IC.COMBO_LABELS = { R3 = "R3", L1 = "L1 + R3", L2 = "L2 + R3", R1 = "R1 + R3", R2 = "R2 + R3" }
IC.RINGS = { "native", "buffs", "consumables", "emotes" }
IC.RING_LABELS = { native = "Native (Look Here)", buffs = "Buffs", consumables = "Consumables", emotes = "Emotes" }

local DEFAULTS = {
    combos = { R3 = "native", L1 = "buffs", L2 = "emotes", R1 = "consumables", R2 = "native" },
}

function IC.Print(msg)
    print("|cff33ccffImprovedController|r: " .. tostring(msg))
end

function IC.InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

-- Called after anything that changes what the rings hold.
function IC.RefreshRings()
    if IC.QueueRingRebuild then
        IC.QueueRingRebuild()
    end
end

local loginCallbacks = {}

-- Runs after saved variables are ready.
function IC.OnLogin(fn)
    table.insert(loginCallbacks, fn)
end

function IC.GetComboRing(combo)
    return IC.db.combos[combo] or "native"
end

function IC.SetComboRing(combo, ring)
    IC.db.combos[combo] = ring
    if IC.ApplyRingBindings then
        IC.ApplyRingBindings()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    ImprovedControllerDB = ImprovedControllerDB or {}
    local db = ImprovedControllerDB
    db.combos = db.combos or {}
    for combo, ring in pairs(DEFAULTS.combos) do
        if db.combos[combo] == nil then
            db.combos[combo] = ring
        end
    end
    IC.db = db
    ImprovedControllerCharDB = ImprovedControllerCharDB or {}
    IC.charDB = ImprovedControllerCharDB
    for _, fn in ipairs(loginCallbacks) do
        fn()
    end
end)
