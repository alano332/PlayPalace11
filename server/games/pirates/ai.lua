----AI Logic for Pirates of the Lost Seas
----Bot decision making and skill usage

local combat = require_internal("games/pirates/combat.lua")

----Execute a bot's turn
----@param game table The game instance
----@param player table The bot player
----@param gem_positions table Map of gem positions
----@param charted_tiles table Map of charted tiles
----@param golden_moon_active boolean Whether golden moon is active
----@param global_xp_multiplier number Global XP multiplier
----@param gem_stealing string Gem stealing mode ("with roll bonus", "no roll bonus", or "disabled")
local function execute_bot_turn(game, player, gem_positions, charted_tiles, golden_moon_active, global_xp_multiplier, gem_stealing)
    game:sleep(math.random(4000, 6000))

    -- Find closest gem
    local closest_gem_pos = -1
    local closest_distance = 999
    for i = 1, 40 do
        if gem_positions[i] ~= -1 then
            local distance = math.abs(player.position - i)
            if distance < closest_distance then
                closest_distance = distance
                closest_gem_pos = i
            end
        end
    end

    -- Simple AI: move towards closest gem or attack randomly
    if closest_gem_pos ~= -1 and math.random(1, 10) <= 7 then
        -- Move towards gem
        local move_amount = 1
        if player.level and player.level >= 150 then
            move_amount = math.min(3, closest_distance)
        elseif player.level and player.level >= 15 then
            move_amount = math.min(2, closest_distance)
        end

        if player.position < closest_gem_pos then
            game:move_player(player, move_amount)
        elseif player.position > closest_gem_pos then
            game:move_player(player, -move_amount)
        else
            -- At gem position, move randomly
            if math.random(0, 1) == 0 then
                game:move_player(player, 1)
            else
                game:move_player(player, -1)
            end
        end
    else
        -- Attack someone within range
        local targets = {}
        for _, t in ipairs(game.players) do
            if t ~= player and combat.is_in_attack_range(player, t) then
                table.insert(targets, t)
            end
        end

        if #targets > 0 then
            local target = targets[math.random(1, #targets)]
            combat.do_attack(game, player, target, golden_moon_active, global_xp_multiplier, gem_stealing)
        else
            -- No targets in range, just move
            if math.random(0, 1) == 0 then
                game:move_player(player, 1)
            else
                game:move_player(player, -1)
            end
        end
    end

    -- AI might activate skills
    if player.level and player.level >= 90 and player.captain_cooldown == 0 and player.captain_active == 0 and math.random(1, 5) == 1 then
        player.captain_active = 5
        player.captain_cooldown = 8
        game:broadcast(player.name .. " activates skilled captain!")
        game:sleep(math.random(4000, 6000))
    end
end

return {
    execute_bot_turn = execute_bot_turn
}
