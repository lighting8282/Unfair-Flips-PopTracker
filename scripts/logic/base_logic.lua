
-- Add custom logic rules here.
-- All locations are logically accessible by default.
-- Use HAS(), ALL(), ANY() from logic_helper.lua to define access rules.

-- Accessibility for a "N Heads in a Row" streak check, mirroring the apworld:
--   * region gate: Progressive Fairness >= floor(N/2) AND Heads+ >= floor(N/2)
--   * practicality: heads_chance ^ N > 0.0075
--   * streaks at/after RequiredHeads are not checks in this seed
-- Heads+/Progressive Fairness are toggle items here, so the real received counts
-- come from PROG_COUNT (maintained in scripts/autotracking/archipelago.lua).
function streakReachable(n)
    n = tonumber(n)
    local sd = SLOT_DATA or {}
    local required_heads = tonumber(sd.RequiredHeads) or 30
    local start_chance = tonumber(sd.StartingHeadsChance) or 15

    -- streaks at or beyond the goal aren't real checks in this seed
    if n >= required_heads then
        return AccessibilityLevel.None
    end

    -- region gate
    local gate_index = math.floor(n / 2)
    local progfair = (PROG_COUNT and PROG_COUNT["progressivefairness"]) or 0
    local headsplus = (PROG_COUNT and PROG_COUNT["headsplus"]) or 0
    if progfair < gate_index or headsplus < gate_index then
        return AccessibilityLevel.None
    end

    -- streak 1 has no practicality requirement
    if n <= 1 then
        return AccessibilityLevel.Normal
    end

    -- can_practically_get_heads_in_a_row
    local total_heads_items = math.floor(required_heads / 2)
    if total_heads_items < 1 then
        total_heads_items = 1
    end
    local min_chance = start_chance / 100
    local heads_chance = min_chance + ((0.95 - min_chance) / total_heads_items) * headsplus
    if heads_chance ^ n > 0.0075 then
        return AccessibilityLevel.Normal
    end
    return AccessibilityLevel.None
end

-- Coin+ requirement for a shop gate: number of distinct value-upgrade-gate
-- thresholds (round((i+1)*(gate_count-1)/4) for i=0..3) that are <= gate_index.
local function bankers_round(x)
    local f = math.floor(x)
    local diff = x - f
    if diff < 0.5 then
        return f
    elseif diff > 0.5 then
        return f + 1
    elseif f % 2 == 0 then
        return f
    else
        return f + 1
    end
end

local function coinValueRequirement(gate_index, gate_count)
    local seen = {}
    local count = 0
    for i = 0, 3 do
        local threshold = bankers_round((i + 1) * (gate_count - 1) / 4)
        if not seen[threshold] then
            seen[threshold] = true
            if threshold <= gate_index then
                count = count + 1
            end
        end
    end
    return count
end

-- Accessibility for a shop "Purchase P" check. All four categories share a gate.
--   * purchase must exist this seed (P <= gate_count * 2)
--   * reach Fairness Gate: Progressive Fairness >= floor((P-1)/2) AND Heads+ >= same
--   * shop entrance: Combo+ >= gate_index AND Flip+ >= gate_index AND Coin+ >= coinReq
function shopReachable(p)
    p = tonumber(p)
    local sd = SLOT_DATA or {}
    local required_heads = tonumber(sd.RequiredHeads) or 30
    local gate_count = math.ceil((required_heads + 1) / 2)

    -- purchases beyond gate_count * 2 don't exist in this seed
    if p > gate_count * 2 then
        return AccessibilityLevel.None
    end

    local gate_index = math.floor((p - 1) / 2)
    local progfair = (PROG_COUNT and PROG_COUNT["progressivefairness"]) or 0
    local headsplus = (PROG_COUNT and PROG_COUNT["headsplus"]) or 0
    local combo = (PROG_COUNT and PROG_COUNT["comboplus"]) or 0
    local flip = (PROG_COUNT and PROG_COUNT["flipplus"]) or 0
    local coin = (PROG_COUNT and PROG_COUNT["coinplus"]) or 0

    if progfair < gate_index or headsplus < gate_index then
        return AccessibilityLevel.None
    end
    if combo < gate_index or flip < gate_index then
        return AccessibilityLevel.None
    end
    if coin < coinValueRequirement(gate_index, gate_count) then
        return AccessibilityLevel.None
    end
    return AccessibilityLevel.Normal
end
