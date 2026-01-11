----Skills System for Pirates of the Lost Seas
----Handles all player skills and abilities

local combat = require_internal("games/pirates/combat.lua")
local leveling = require_internal("games/pirates/leveling.lua")
local gems = require_internal("games/pirates/gems.lua")

----Sailor's Instinct - Show map sector information
local function use_sailors_instinct(game, player, selected_oceans, charted_tiles)
    local sound_num = math.random(1, 2)
    game:play_sound("game_pirates/instinct" .. sound_num .. ".ogg", 60)

    local ocean_name = selected_oceans[math.ceil(player.position / 10)]

    -- Build status items
    local status_items = {
        "Your position: " .. player.position .. " in " .. ocean_name,
        "",
        "Map Sectors:"
    }

    for sector = 1, 8 do
        local sector_start = (sector - 1) * 5 + 1
        local sector_end = sector * 5
        local charted_count = 0
        for i = sector_start, sector_end do
            if charted_tiles[i] then
                charted_count = charted_count + 1
            end
        end

        local status_text = "Sector " .. sector .. " (" .. sector_start .. "-" .. sector_end .. "): "
        if charted_count == 5 then
            status_text = status_text .. "Fully charted"
        elseif charted_count > 0 then
            status_text = status_text .. "Partially charted (" .. charted_count .. "/5)"
        else
            status_text = status_text .. "Uncharted"
        end
        table.insert(status_items, status_text)
    end

    -- Show status box
    game:status_box(player, status_items)
end

----Portal - Teleport to a chosen ocean (must have other ships)
local function use_portal(game, player, charted_tiles, selected_oceans)
    -- Find which oceans have other players
    local occupied_oceans = {}
    for _, p in ipairs(game.players) do
        if p ~= player then
            local ocean_num = math.ceil(p.position / 10)
            if not occupied_oceans[ocean_num] then
                occupied_oceans[ocean_num] = true
            end
        end
    end

    -- Build menu of available oceans
    local ocean_options = {}
    local ocean_numbers = {}
    for ocean_num = 1, 4 do
        if occupied_oceans[ocean_num] then
            table.insert(ocean_options, selected_oceans[ocean_num])
            table.insert(ocean_numbers, ocean_num)
        end
    end

    if #ocean_options == 0 then
        if player.user then
            player.user:speak("Portal failed! No other ships detected in any ocean!")
        end
        game:broadcast(player.name .. "'s portal fizzles - no ships to lock onto!")
        return "continue"
    end

    table.insert(ocean_options, "cancel")

    local chosen_ocean = nil
    if player.user then
        -- Human player chooses
        local choice = game:show_modal(player, "Portal: Choose which ocean to teleport to", ocean_options, 30000, #ocean_options)
        if choice <= #ocean_numbers then
            chosen_ocean = ocean_numbers[choice]
        else
            return "continue"  -- Cancelled
        end
    else
        -- Bot chooses randomly
        chosen_ocean = ocean_numbers[math.random(1, #ocean_numbers)]
    end

    -- Teleport to random position in chosen ocean
    local ocean_start = (chosen_ocean - 1) * 10 + 1
    local ocean_end = chosen_ocean * 10
    local new_pos = math.random(ocean_start, ocean_end)

    player.position = new_pos
    player.portal_cooldown = 3
    local sound_num = math.random(1, 2)
    game:play_sound("game_pirates/portal" .. sound_num .. ".ogg", 60)
    game:broadcast("Portal activated! " .. player.name .. " teleports to " .. selected_oceans[chosen_ocean] .. " (position " .. new_pos .. ")!")
    charted_tiles[new_pos] = true
    return "end_turn"
end

----Skilled Captain - Activate buff
local function use_skilled_captain(game, player)
    player.captain_active = 4
    player.captain_cooldown = 8
    game:play_sound("game_pirates/skilledcaptain.ogg", 60)

    if player.user then
        player.user:speak("Skilled captain activated! Plus 2 attack and defense for " .. player.captain_active .. " turns!")
    end
    game:broadcast(player.name .. " activates skilled captain!", player)
    -- The current turn subtracts a use, so inflate it by 1
    player.captain_active = player.captain_active + 1
    player._cooldown = player.captain_cooldown + 1
    return "end_turn"
end

----Sword Fighter - Activate buff
local function use_sword_fighter(game, player)
    player.sword_active = 3
    player.sword_cooldown = 8
    game:play_sound("game_pirates/swordfighter.ogg", 60)

    if player.user then
        player.user:speak("Sword fighter activated! Plus 4 attack for " .. player.sword_active .. " turns!")
    end
    game:broadcast(player.name .. " activates sword fighter!", player)
    -- The current turn subtracts a use, so inflate it by 1
    player.sword_active = player.sword_active + 1
    player.sword_cooldown = player.sword_cooldown + 1
    return "end_turn"
end

----Push - Activate buff
local function use_push(game, player)
    player.push_active = 4
    player.push_cooldown = 8
    local sound_num = math.random(1, 2)
    game:play_sound("game_pirates/push" .. sound_num .. ".ogg", 60)

    if player.user then
        player.user:speak("Push activated! Plus 3 defense for " .. player.push_active .. " turns!")
    end
    game:broadcast(player.name .. " activates push!", player)
    -- The current turn subtracts a use, so inflate it by 1
    player.push_active = player.push_active + 1
    player.push_cooldown = player.push_cooldown + 1
    return "end_turn"
end

----Double Devastation - Activate buff (level 200+)
local function use_double_devastation(game, player)
    player.devastation_active = 3
    player.devastation_cooldown = 10
    game:play_sound("game_pirates/doubledevastation.ogg", 60)

    if player.user then
        player.user:speak("Double devastation activated! Attack range increased to 10 squares for " .. player.devastation_active .. " turns!")
    end
    game:broadcast(player.name .. " activates double devastation!", player)
    -- The current turn subtracts a use, so inflate it by 1
    player.devastation_active = player.devastation_active + 1
    player.devastation_cooldown = player.devastation_cooldown + 1
    return "end_turn"
end

----Gem Seeker - Reveal location of one gem (limited to 3 uses per game)
local function use_gem_seeker(game, player, gem_positions)
    -- Decrement uses
    player.gem_seeker_uses = player.gem_seeker_uses - 1

    local sound_num = math.random(1, 2)
    game:play_sound("game_pirates/gemseeker" .. sound_num .. ".ogg", 60)
    for i = 1, 40 do
        if gem_positions[i] ~= -1 then
            if player.user then
                player.user:speak("Gem seeker reveals: The " .. gems.gem_names[gem_positions[i]] .. " is at position " .. i .. "! (" .. player.gem_seeker_uses .. " uses remaining)")
            end
            break
        end
    end
end

----Battleship - Fire two cannonballs
local function use_battleship(game, player, golden_moon_active, global_xp_multiplier, gem_stealing)
    if player.devastation_active > 0 then
        player.user:speak("You can not use the Battleship skill while double devastation is active.")
        return "continue_turn"
    end

    -- If no targets in range, cancel the skill. Copied code because it was the fastest solution.
    local valid_targets = 0
    for _, t in ipairs(game.players) do
        if t ~= player and combat.is_in_attack_range(player, t) then
            valid_targets= valid_targets + 1
        end
    end

    if valid_targets == 0 then
        if player.user then
            player.user:speak("Could not activate skill Battleship because No targets are within range.")
        end
        return "continue_turn"
    end

    player.battleship_cooldown = 2
    -- The current turn subtracts a use, so inflate it by 1
    player.battleship_cooldown = player.battleship_cooldown + 1
    game:play_sound("game_pirates/battleship.ogg", 60)

    if player.user then
        player.user:speak("Battleship skill activated! You can fire cannonballs twice this turn!")
    end
    game:broadcast(player.name .. " activates battleship skill!", player)

    for shot = 1, 2 do
        if player.user then
            player.user:speak("Cannonball shot " .. shot .. " of 2.")
        end

        -- Build target menu (only players within 5 squares)
        local target_options = {}
        local target_players = {}
        for _, t in ipairs(game.players) do
            if t ~= player and combat.is_in_attack_range(player, t) then
                local distance = math.abs(player.position - t.position)
                table.insert(target_options, t.name .. " (position " .. t.position .. ", " .. distance .. " squares away)")
                table.insert(target_players, t)
            end
        end

        if #target_players == 0 then
            if player.user then
                player.user:speak("No targets within range for shot " .. shot .. "!")
            end
        else
            table.insert(target_options, "skip this shot")

            -- Show modal for target selection
            if not game:is_bot(player) then
                local choice = game:show_modal(player, "Who do you want to attack?", target_options, 30000, #target_options)

                if choice <= #target_players then
                    local target = target_players[choice]
                    combat.do_attack(game, player, target, golden_moon_active, global_xp_multiplier, gem_stealing)
                else
                    if player.user then
                        player.user:speak("Skipping shot " .. shot .. ".")
                    end
                end
            end
        end
    end
    return "end_turn"
end

----Update buff and cooldown timers at start of turn
local function update_timers(game, player)
    -- Decrease buff timers
    if player.captain_active > 0 then
        player.captain_active = player.captain_active - 1
        if player.captain_active == 0 then
            game:broadcast(player.name .. "'s skilled captain buff has worn off.")
        end
    end
    if player.sword_active > 0 then
        player.sword_active = player.sword_active - 1
        if player.sword_active == 0 then
            game:broadcast(player.name .. "'s sword fighter buff has worn off.")
        end
    end
    if player.push_active > 0 then
        player.push_active = player.push_active - 1
        if player.push_active == 0 then
            game:broadcast(player.name .. "'s push buff has worn off.")
        end
    end
    if player.devastation_active > 0 then
        player.devastation_active = player.devastation_active - 1
        if player.devastation_active == 0 then
            game:broadcast(player.name .. "'s double devastation buff has worn off.")
        end
    end

    -- Decrease cooldowns
    if player.captain_cooldown > 0 then player.captain_cooldown = player.captain_cooldown - 1 end
    if player.sword_cooldown > 0 then player.sword_cooldown = player.sword_cooldown - 1 end
    if player.push_cooldown > 0 then player.push_cooldown = player.push_cooldown - 1 end
    if player.battleship_cooldown > 0 then player.battleship_cooldown = player.battleship_cooldown - 1 end
    if player.portal_cooldown > 0 then player.portal_cooldown = player.portal_cooldown - 1 end
    if player.devastation_cooldown > 0 then player.devastation_cooldown = player.devastation_cooldown - 1 end
end

return {
    use_sailors_instinct = use_sailors_instinct,
    use_portal = use_portal,
    use_skilled_captain = use_skilled_captain,
    use_sword_fighter = use_sword_fighter,
    use_push = use_push,
    use_double_devastation = use_double_devastation,
    use_gem_seeker = use_gem_seeker,
    use_battleship = use_battleship,
    update_timers = update_timers
}
