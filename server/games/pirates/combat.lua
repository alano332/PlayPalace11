----Combat System for Pirates of the Lost Seas
----Handles cannonball attacks and defenses

local gems = require_internal("games/pirates/gems.lua")
local leveling = require_internal("games/pirates/leveling.lua")

----Check if a player is within attack range
----@param attacker table The attacking player
----@param defender table The defending player
----@return boolean True if defender is within 5 squares (or 10 with double devastation)
local function is_in_attack_range(attacker, defender)
    local max_range = 5
    if attacker.devastation_active and attacker.devastation_active > 0 then
        max_range = 10
    end
    return math.abs(attacker.position - defender.position) <= max_range
end

----Execute an attack between two players
----@param game table The game instance
----@param attacker table The attacking player
----@param defender table The defending player
----@param golden_moon_active boolean Whether golden moon is active this turn
----@param global_xp_multiplier number Global XP multiplier from game options
----@param gem_stealing string Gem stealing mode ("with roll bonus", "no roll bonus", or "disabled")
local function do_attack(game, attacker, defender, golden_moon_active, global_xp_multiplier, gem_stealing)
    local sound_num = math.random(1, 3)
    game:play_sound("game_pirates/cannon" .. sound_num .. ".ogg", 60)

    -- Attack announcement
    if attacker.user then
        attacker.user:speak("You fire a cannonball at " .. defender.name .. "!")
    end
    if defender.user then
        defender.user:speak(attacker.name .. " fires a cannonball at you!")
    end
    game:broadcast(attacker.name .. " fires a cannonball at " .. defender.name .. "!", {attacker, defender})

    game:sleep(500)

    local attack_roll = math.random(1, 6)
    game:broadcast("Attack roll: " .. attack_roll .. "!")

    local attack_bonus = 0
    if attacker.captain_active > 0 then
        attack_bonus = attack_bonus + 2
    end
    if attacker.sword_active > 0 then
        attack_bonus = attack_bonus + 4
    end

    if attack_bonus > 0 then
        game:broadcast("Attack bonus: plus " .. attack_bonus .. "!")
        attack_roll = attack_roll + attack_bonus
    end

    local defense_roll = math.random(1, 6)
    if defender.user then
        defender.user:speak("Your defense roll: " .. defense_roll .. "!")
    end
    game:broadcast(defender.name .. "'s defense roll: " .. defense_roll .. "!", defender)

    local defense_bonus = 0
    if defender.captain_active > 0 then
        defense_bonus = defense_bonus + 2
    end
    if defender.push_active > 0 then
        defense_bonus = defense_bonus + 3
    end

    if defense_bonus > 0 then
        game:broadcast("Defense bonus: plus " .. defense_bonus .. "!")
        defense_roll = defense_roll + defense_bonus
    end

    -- Calculate total multiplier (golden moon stacks with global multiplier)
    local moon_mult = golden_moon_active and 3 or 1
    local total_mult = moon_mult * (global_xp_multiplier or 1)

    if attack_roll > defense_roll then
        local sound_num = math.random(1, 3)
        game:play_sound("game_pirates/cannonhit" .. sound_num .. ".ogg", 70)

        -- Hit announcement
        if attacker.user then
            attacker.user:speak("Hit! You board " .. defender.name .. "'s ship!")
        end
        if defender.user then
            defender.user:speak("Hit! " .. attacker.name .. " boards your ship!")
        end
        game:broadcast("Hit! " .. attacker.name .. " boards " .. defender.name .. "'s ship!", {attacker, defender})

        local xp_gain = math.random(50, 150)
        leveling.give_xp(game, attacker, xp_gain, total_mult)

        -- Attacker chooses: push or steal (if stealing enabled and defender has gems)
        local can_steal = gem_stealing ~= "disabled" and #defender.gems > 0
        local choice_made = false

        if attacker.user and can_steal then
            -- Human player chooses
            local options = {"Push left", "Push right", "Attempt to steal gem"}
            local choice = game:show_modal(attacker, "You've boarded " .. defender.name .. "'s ship! What will you do?", options, 30000, 1)

            if choice == 1 or choice == 2 then
                -- Push
                local direction = (choice == 1) and "left" or "right"
                local push_amount = math.random(3, 8)
                if direction == "left" then
                    push_amount = push_amount * -1
                end
                local old_pos = defender.position
                defender.position = math.max(1, math.min(40, defender.position + push_amount))

                if attacker.user then
                    attacker.user:speak("You push " .. defender.name .. " " .. direction .. " to position " .. defender.position .. "!")
                end
                if defender.user then
                    defender.user:speak(attacker.name .. " pushes you " .. direction .. " to position " .. defender.position .. "!")
                end
                game:broadcast(attacker.name .. " pushes " .. defender.name .. " " .. direction .. " from position " .. old_pos .. " to " .. defender.position .. "!", {attacker, defender})
                choice_made = true
            elseif choice == 3 then
                -- Attempt steal
                game:broadcast(attacker.name .. " attempts to steal a gem!")
                local steal_roll = math.random(1, 6)
                if gem_stealing == "with_roll_bonus" then
                    attack_steal_roll = attack_steal_roll + attack_bonus
                end
                local defend_steal_roll = math.random(1, 6)
                if gem_stealing == "with_roll_bonus" then
                    defend_steal_roll = defend_steal_roll + defend_bonus
                end

                game:broadcast("Steal roll: " .. steal_roll .. " vs defense: " .. defend_steal_roll .. "!")

                if steal_roll > defend_steal_roll then
                    local stolen_idx = math.random(1, #defender.gems)
                    local stolen_gem = defender.gems[stolen_idx]
                    table.remove(defender.gems, stolen_idx)
                    table.insert(attacker.gems, stolen_gem)

                    attacker.score = gems.calculate_score_from_gems(attacker.gems)
                    defender.score = gems.calculate_score_from_gems(defender.gems)

                    -- Play steal sound
                    local sound_num = math.random(1, 2)
                    game:play_sound("game_pirates/stealgem" .. sound_num .. ".ogg", 70)

                    if attacker.user then
                        attacker.user:speak("Success! You steal the " .. gems.gem_names[stolen_gem] .. " from " .. defender.name .. "!")
                    end
                    if defender.user then
                        defender.user:speak(attacker.name .. " steals the " .. gems.gem_names[stolen_gem] .. " from you!")
                    end
                    game:broadcast(attacker.name .. " steals the " .. gems.gem_names[stolen_gem] .. " from " .. defender.name .. "!", {attacker, defender})
                else
                    game:broadcast("The steal attempt fails!")
                end
                choice_made = true
            end
        end

        -- Bot or timeout/no stealing option - default to random push
        if not choice_made then
            local direction = math.random(0, 1) == 0 and "left" or "right"
                local push_amount = math.random(3, 8)
                if direction == "left" then
                    push_amount = push_amount * -1
                end
            local old_pos = defender.position
            defender.position = math.max(1, math.min(40, defender.position + push_amount))

            game:broadcast(attacker.name .. " pushes " .. defender.name .. " " .. direction .. " from position " .. old_pos .. " to " .. defender.position .. "!")
        end
    else
        -- Miss announcement
        if attacker.user then
            attacker.user:speak("Miss! " .. defender.name .. " defends successfully!")
        end
        if defender.user then
            defender.user:speak("Miss! You defend successfully!")
        end
        game:broadcast("Miss! " .. defender.name .. " defends successfully!", {attacker, defender})

        local xp_gain = math.random(30, 100)
        leveling.give_xp(game, defender, xp_gain, total_mult)
    end
end

return {
    do_attack = do_attack,
    is_in_attack_range = is_in_attack_range
}
