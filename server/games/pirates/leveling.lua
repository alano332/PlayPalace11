----Leveling System for Pirates of the Lost Seas
----Handles XP gain, level-ups, and skill unlocks

----Get the XP required to reach a specific level
----@param level number The target level
----@return number XP required
local function get_xp_for_level(level)
    return level * 20
end

----Give XP to a player and check for level-ups
----@param game table The game instance
----@param player table The player to give XP to
----@param xp_amount number Base XP amount
----@param multiplier number Optional multiplier (default 1)
local function give_xp(game, player, xp_amount, multiplier)
    multiplier = multiplier or 1
    xp_amount = xp_amount * multiplier
    player.xp = player.xp + xp_amount

    if player.user then
        player.user:speak("You gain " .. xp_amount .. " XP!")
    end
    game:broadcast(player.name .. " gains " .. xp_amount .. " XP!", player)

    -- Check for level ups
    local starting_level = player.level
    local skills_unlocked = {}

    while player.xp >= get_xp_for_level(player.level + 1) do
        player.level = player.level + 1

        -- Track new skills
        if player.level == 10 then
            table.insert(skills_unlocked, "Sailor's instinct")
        elseif player.level == 15 then
            table.insert(skills_unlocked, "Double masted boat")
        elseif player.level == 25 then
            table.insert(skills_unlocked, "Portal")
        elseif player.level == 40 then
            table.insert(skills_unlocked, "Gem seeker")
        elseif player.level == 60 then
            table.insert(skills_unlocked, "Sword fighter")
        elseif player.level == 75 then
            table.insert(skills_unlocked, "Push")
        elseif player.level == 90 then
            table.insert(skills_unlocked, "Skilled captain")
        elseif player.level == 125 then
            table.insert(skills_unlocked, "Battleship")
        elseif player.level == 150 then
            table.insert(skills_unlocked, "Ship of the future")
        elseif player.level == 200 then
            table.insert(skills_unlocked, "Double devastation")
        end
    end

    -- Announce level ups if any occurred
    if player.level > starting_level then
        game:play_sound("game_pig/win.ogg", 80)
        local levels_gained = player.level - starting_level

        -- Message to the player
        if player.user then
            local message = "You leveled up "
            if levels_gained == 1 then
                message = message .. "to level " .. player.level .. "!"
            else
                message = message .. levels_gained .. " times to level " .. player.level .. "!"
            end
            if #skills_unlocked > 0 then
                message = message .. " New skills: " .. table.concat(skills_unlocked, ", ") .. "!"
            end
            player.user:speak(message)
        end

        -- Message to others
        local message = player.name .. " leveled up "
        if levels_gained == 1 then
            message = message .. "to level " .. player.level .. "!"
        else
            message = message .. levels_gained .. " times to level " .. player.level .. "!"
        end
        if #skills_unlocked > 0 then
            message = message .. " New skills: " .. table.concat(skills_unlocked, ", ") .. "!"
        end
        game:broadcast(message, player)
    end
end

return {
    get_xp_for_level = get_xp_for_level,
    give_xp = give_xp
}
