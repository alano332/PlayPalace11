----Gem System for Pirates of the Lost Seas
----Defines gem types, values, and placement logic

local gem_names = {
    [0] = "opal", "ruby", "garnet", "diamond", "sapphire", "emerald",
    "gem of the palace", "large plastic gem (what is this doing here!)",
    "awesome blue bastardstone", "amethyst", "golden ring",
    "awesome red ppulpstone", "awesome red gorestone", "moonstone",
    "lapis lazuli", "amber", "citrine", "definitely not cursed black pearl (tm)"
}

----Get the point value of a gem by its type index
----@param gem_type number The gem type (0-17)
----@return number The point value (1-3)
local function get_gem_value(gem_type)
    if gem_type == 6 or gem_type == 8 or gem_type == 11 or gem_type == 12 then
        return 2
    elseif gem_type == 17 then
        return 3
    else
        return 1
    end
end

----Calculate total score from a list of gems
----@param gems_list table Array of gem type indices
----@return number Total score
local function calculate_score_from_gems(gems_list)
    if not gems_list or #gems_list == 0 then return 0 end
    local total = 0
    for i, gem_idx in ipairs(gems_list) do
        total = total + get_gem_value(gem_idx)
    end
    return total
end

----Place gems randomly across the map
----@param map_size number Total number of tiles
----@return table gem_positions Array mapping position -> gem_type (-1 if no gem)
local function place_gems(map_size)
    local gem_positions = {}

    -- Initialize all positions with no gems
    for i = 1, map_size do
        gem_positions[i] = -1
    end

    -- Place all 18 gems randomly
    for gem_type = 0, 17 do
        local pos
        repeat
            pos = math.random(1, map_size)
        until gem_positions[pos] == -1
        gem_positions[pos] = gem_type
    end

    return gem_positions
end

return {
    gem_names = gem_names,
    get_gem_value = get_gem_value,
    calculate_score_from_gems = calculate_score_from_gems,
    place_gems = place_gems
}
