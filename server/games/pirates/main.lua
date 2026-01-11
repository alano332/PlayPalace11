----Pirates of the Lost Seas for Play Palace v9
----A complex RPG adventure with sailing, combat, and leveling

require_internal("advanced_game/main.lua")
local gems = require_internal("games/pirates/gems.lua")
local leveling = require_internal("games/pirates/leveling.lua")
local combat = require_internal("games/pirates/combat.lua")
local skills = require_internal("games/pirates/skills.lua")

PiratesGame = class('PiratesGame', AdvancedGame)

-- Load module files

local ocean_names = {
    "Rory's Ocean", "Developer's Deep", "Programmer's Paradise Sea", "The Palace Waters",
    "Silva's Strait", "Kai's Current", "Gamer's Gulf", "Server Room Sea",
    "Battle Bay", "Code Compilation Channel"
}

function PiratesGame:initialize(table_id, game_type, game_name, host_user, min_players, max_players)
    AdvancedGame.initialize(self, table_id, game_type or "pirates", game_name or "Pirates Of The Lost Seas", host_user, min_players or 2, max_players or 5)

    -- Add player state
    self:add_player_state("position", 0)
    self:add_player_state("level", 0)
    self:add_player_state("xp", 0)
    self:add_player_state("score", 0)
    self:add_player_state("gems", {})
    self:add_player_state("captain_cooldown", 0)
    self:add_player_state("captain_active", 0)
    self:add_player_state("sword_cooldown", 0)
    self:add_player_state("sword_active", 0)
    self:add_player_state("push_cooldown", 0)
    self:add_player_state("push_active", 0)
    self:add_player_state("battleship_cooldown", 0)
    self:add_player_state("portal_cooldown", 0)
    self:add_player_state("gem_seeker_uses", 3)
    self:add_player_state("devastation_cooldown", 0)
    self:add_player_state("devastation_active", 0)

    -- Game state
    self.selected_oceans = {}
    self.charted_tiles = {}
    self.gem_positions = {}
    self.gems_collected = 0
    self.total_gems = 18
    self.golden_moon_active = false
    self.round = 0

    -- Game options
    self.game_option_defs = {
        {
            type = "list",
            key = "xp_multiplier",
            name = "XP Multiplier",
            description = "Global XP multiplier (stacks with Golden Moon)",
            default = "Normal (1x)",
            options = {"Quarter (0.25x)", "Half (0.5x)", "Normal (1x)", "One and a Half (1.5x)", "Double (2x)", "Triple (3x)"}
        },
        {
            type = "list",
            key = "gem_stealing",
            name = "Gem Stealing",
            description = "Cannonballs steal gems when they hit",
            default = "with roll bonus",
            options = {"with roll bonus", "no roll bonus", "disabled"}
        }
    }

    self.game_options = {
        xp_multiplier = "Normal (1x)",
        gem_stealing = "with roll bonus"
    }
end

function PiratesGame:game_intro()
    self:play_music("game_pirates/mus.ogg")
    self:play_ambience("game_pirates/am_intro.ogg", "game_pirates/amloop.ogg", "game_pirates/am_outro.ogg")
    self:broadcast("Welcome to Pirates Of The Lost Seas! Sail the oceans, collect gems, and battle other pirates!")

    -- Select 4 random oceans
    local available = {}
    for i, name in ipairs(ocean_names) do
        table.insert(available, name)
    end
    for i = 1, 4 do
        local idx = math.random(1, #available)
        table.insert(self.selected_oceans, available[idx])
        table.remove(available, idx)
    end

    self:broadcast("The four oceans are: " .. table.concat(self.selected_oceans, ", ") .. ".")

    -- Initialize player positions randomly
    for _, player in ipairs(self.players) do
        player.position = math.random(1, 40)
    end

    -- Initialize charted tiles
    for i = 1, 40 do
        self.charted_tiles[i] = false
    end

    -- Place gems
    self.gem_positions = gems.place_gems(40)

    self:broadcast("18 gems have been scattered across the 40 tile map! Collect them all!")
end

function PiratesGame:setup_actions()
    -- Movement actions
    self:define_action("move_left", {
        label = "Move left",
        handler = function(game, player)
            return game:move_player(player, -1)
        end,
        requires_turn = true,
        mutable = true
    })

    self:define_action("move_right", {
        label = "Move right",
        handler = function(game, player)
            return game:move_player(player, 1)
        end,
        requires_turn = true,
        mutable = true
    })

    self:define_action("move_2_left", {
        label = "Move 2 left",
        handler = function(game, player)
            return game:move_player(player, -2)
        end,
        available_when = function(game, player)
            return player.level and player.level >= 15
        end,
        hidden_when = function(game, player)
            return not player.level or player.level < 15
        end,
        requires_turn = true,
        mutable = true
    })

    self:define_action("move_2_right", {
        label = "Move 2 right",
        handler = function(game, player)
            return game:move_player(player, 2)
        end,
        available_when = function(game, player)
            return player.level and player.level >= 15
        end,
        hidden_when = function(game, player)
            return not player.level or player.level < 15
        end,
        requires_turn = true,
        mutable = true
    })

    self:define_action("move_3_left", {
        label = "Move 3 left",
        handler = function(game, player)
            return game:move_player(player, -3)
        end,
        available_when = function(game, player)
            return player.level and player.level >= 150
        end,
        hidden_when = function(game, player)
            return not player.level or player.level < 150
        end,
        requires_turn = true,
        mutable = true
    })

    self:define_action("move_3_right", {
        label = "Move 3 right",
        handler = function(game, player)
            return game:move_player(player, 3)
        end,
        available_when = function(game, player)
            return player.level and player.level >= 150
        end,
        hidden_when = function(game, player)
            return not player.level or player.level < 150
        end,
        requires_turn = true,
        mutable = true
    })

    -- Use skill action
    self:define_action("use_skill", {
        label = "Use skill",
        handler = function(game, player)
            return game:handle_skill_menu(player)
        end,
        requires_turn = true,
        mutable = true
    })

    -- Check moon brightness (M key - only during Golden Moon)
    self:define_action("check_moon_brightness", {
        label = "Check moon brightness",
        handler = function(game, player)
            return game:check_moon_brightness(player)
        end,
        available_when = function(game, player)
            return game.golden_moon_active
        end,
        hidden_when = function(game, player)
            return not game.golden_moon_active
        end,
        requires_turn = false,
        keybind = "m",
        mutable = false,
        show_in_action_menu = true
    })
    -- Check status action (S key)

    self:define_action("check_status", {
        label = "Check status",
        handler = function(game, player)
            return game:check_status(player)
        end,
        requires_turn = false,
        keybind = "s",
        mutable = false,
        show_in_action_menu = true
    })

    -- Check position (P key)
    self:define_action("check_position", {
        label = "Check position",
        handler = function(game, player)
            if player.user then
                local ocean_name = game.selected_oceans[math.ceil(player.position / 10)]
                player.user:speak("You are at position " .. player.position .. " in " .. ocean_name .. ".")
            end
        end,
        hidden_when = function(game, player)
            return true
        end,
        requires_turn = false,
        keybind = "p",
        mutable = false,
        show_in_action_menu = true
    })
end

function PiratesGame:run_game()
    -- Main game loop
    while self.game_active and self.total_gems > 0 do
        self.round = self.round + 1

        -- Check for Golden Moon (every 3rd round)
        self.golden_moon_active = (self.round % 3 == 0)
        if self.golden_moon_active then
            self:play_sound("game_pirates/goldenmoon.ogg")
            self:sleep(1000)
            self:broadcast("The Golden Moon rises! All XP rewards are tripled for this round!")
        end

        -- Play turns for each player
        for _, player in ipairs(self.players) do
            if not self.game_active or self.total_gems == 0 then
                break
            end

            -- Reset turn state (update buffs/cooldowns)
            skills.update_timers(self, player)

            -- Play the turn
            self:play_turn(player)

            -- Check for gem at current position after turn
            self:check_gem_collection(player)

            -- Check for winner
            if self.total_gems == 0 then
                self:announce_winner()
                return
            end
        end
    end

    -- If we exit the loop, find and announce winner
    if self.total_gems == 0 then
        self:announce_winner()
    end
end

----Play a turn for a player
function PiratesGame:play_turn(player)
    self.current_player = player
    self:broadcast(player.name .. "'s turn; position " .. player.position .. ".")

    -- Rebuild menus for all players
    for _, p in ipairs(self.players) do
        self:rebuild_player_menu(p)
    end

    -- Check if player is a bot
    if self:is_bot(player) then
        -- Bot turn
        local bot_ai = require_internal("games/pirates/ai.lua")
        bot_ai.execute_bot_turn(self, player, self.gem_positions, self.charted_tiles, self.golden_moon_active, self:get_xp_multiplier(), self.game_options.gem_stealing)
        self.current_player = nil
        return
    end

    -- Human player turn
    local turn_active = true
    while turn_active do
        local event = self:poll()

        if event and event.type == "action_emit" then
            local result = self:execute_game_action(event.player, event.action_id)

            -- Handle action results
            -- execute_game_action returns false to end turn, true/"continue" to continue
            if result == false then
                turn_active = false
            end
        end
    end

    self.current_player = nil
end

----Check for gem collection at player's position
function PiratesGame:check_gem_collection(player)
    if self.gem_positions[player.position] ~= -1 then
        local gem_type = self.gem_positions[player.position]
        local gem_value = gems.get_gem_value(gem_type)

        local sound_num = math.random(1, 3)
        self:play_sound("game_pirates/grabgem" .. sound_num .. ".ogg", 70)

        if player.user then
            player.user:speak("You found the " .. gems.gem_names[gem_type] .. "! Worth " .. gem_value .. " points!")
        end
        self:broadcast(player.name .. " found the " .. gems.gem_names[gem_type] .. "! Worth " .. gem_value .. " points!", player)

        table.insert(player.gems, gem_type)
        player.score = player.score + gem_value

        local xp_gain = math.random(150, 300)
        local moon_mult = self.golden_moon_active and 3 or 1
        leveling.give_xp(self, player, xp_gain, moon_mult)

        self.gem_positions[player.position] = -1
        self.total_gems = self.total_gems - 1
        self.gems_collected = self.gems_collected + 1
        self.charted_tiles[player.position] = true
    end
end

----Move player
function PiratesGame:move_player(player, amount)
    local old_position = player.position
    local new_position

    -- Calculate new position with bounds checking
    if amount > 0 then
        new_position = math.min(40, player.position + amount)
    else
        new_position = math.max(1, player.position + amount)
    end

    -- Check if movement would actually change position
    if new_position == old_position then
        -- Player tried to sail off the edge of the map
        if player.user then
            player.user:speak("You cannot sail any further in that direction! The edge of the map is at position " .. old_position .. ".")
        end
        return "continue"  -- Don't end turn, let them choose again
    end

    player.position = new_position

    -- Play appropriate movement sound based on distance
    local abs_amount = math.abs(amount)
    if abs_amount == 1 then
        -- Normal movement
        local sound_num = math.random(1, 3)
        self:play_sound("game_pirates/move" .. sound_num .. ".ogg", 60)
    elseif abs_amount == 2 then
        -- Double masted boat
        local sound_num = math.random(1, 3)
        self:play_sound("game_pirates/boat" .. sound_num .. ".ogg", 60)
    elseif abs_amount == 3 then
        -- Ship of the future
        local sound_num = math.random(1, 2)
        self:play_sound("game_pirates/future" .. sound_num .. ".ogg", 60)
    end

    local direction = amount > 0 and "right" or "left"
    if abs_amount == 1 then
        if player.user then
            player.user:speak("You sail " .. direction .. " to position " .. player.position .. ".")
        end
        self:broadcast(player.name .. " sails " .. direction .. " to position " .. player.position .. ".", player)
    else
        if player.user then
            player.user:speak("You sail " .. abs_amount .. " tiles " .. direction .. " to position " .. player.position .. ".")
        end
        self:broadcast(player.name .. " sails " .. abs_amount .. " tiles " .. direction .. " to position " .. player.position .. ".", player)
    end

    self.charted_tiles[player.position] = true
    return "end_turn"
end

----Skill descriptions
local skill_descriptions = {
    cannonball = "Cannonball shot is available from the start and allows attacking players within 5 tiles.",
    instinct = "Sailor's instinct unlocks at level 10 and shows map sector information and charted status.",
    portal = "Portal unlocks at level 25 and teleports the player to a random position in an ocean occupied by another player, with a 3-turn cooldown.",
    portal_cd = "Portal unlocks at level 25 and teleports the player to a random position in an ocean occupied by another player, with a 3-turn cooldown.",
    seeker = "Gem seeker unlocks at level 40 and reveals the location of one uncollected gem, limited to 3 uses per game.",
    seeker_exhausted = "Gem seeker unlocks at level 40 and reveals the location of one uncollected gem, limited to 3 uses per game.",
    sword = "Sword fighter unlocks at level 60 and grants a plus 5 attack bonus for 3 turns, with an 8-turn cooldown.",
    sword_cd = "Sword fighter unlocks at level 60 and grants a plus 5 attack bonus for 3 turns, with an 8-turn cooldown.",
    push = "Push unlocks at level 75 and grants a plus 3 defense bonus for 4 turns, with an 8-turn cooldown.",
    push_cd = "Push unlocks at level 75 and grants a plus 3 defense bonus for 4 turns, with an 8-turn cooldown.",
    captain = "Skilled captain unlocks at level 90 and grants plus 2 attack and plus 2 defense for 4 turns, with an 8-turn cooldown.",
    captain_cd = "Skilled captain unlocks at level 90 and grants plus 2 attack and plus 2 defense for 4 turns, with an 8-turn cooldown.",
    battleship = "Battleship unlocks at level 125 and allows firing two cannonballs in one turn, with a 2-turn cooldown.",
    battleship_cd = "Battleship unlocks at level 125 and allows firing two cannonballs in one turn, with a 2-turn cooldown.",
    future = "Ship of the future unlocks at level 150 and allows moving 3 tiles per turn.",
    double_devastation = "Double devastation unlocks at level 200 and grants a plus 5 cannon range bonus for 3 turns, with a 10-turn cooldown.",
    double_devastation_cd = "Double devastation unlocks at level 200 and grants a plus 5 cannon range bonus for 3 turns, with a 10-turn cooldown."
}

----Show skill modal with space key support for descriptions
function PiratesGame:show_skill_modal(player, title, options, skill_actions, timeout, default_index)
    -- Block mutable actions if this is a turn-based game
    local was_blocking = false
    if self.mutable_action_in_progress ~= nil then
        was_blocking = self.mutable_action_in_progress
        self.mutable_action_in_progress = true
    end

    -- Build menu items: title first, then options
    local menu_items = {title}
    for _, option in ipairs(options) do
        table.insert(menu_items, option)
    end

    -- Speak the title first, then show menu (position on first option, not title)
    if player.user then
        player.user:speak(title)
        player.user:add_menu("game_modal", menu_items, false, 2)  -- Position 2 = first option (title is 1)
    end

    local start_time = elapsed()
    local result = default_index

    -- Loop until valid selection or timeout
    while true do
        -- Calculate remaining timeout
        local remaining_timeout = nil
        if timeout then
            local time_elapsed = elapsed() - start_time
            remaining_timeout = timeout - time_elapsed
            if remaining_timeout <= 0 then
                -- Timeout occurred
                break
            end
        end

        -- Poll for selection or key events
        local event = self:poll(player, remaining_timeout, function(e)
            -- Accept menu events for the modal or space key events
            return (e.type == "menu" and e.menu_id == "game_modal") or
                   (e.type == "keybind" and e.key == "space")
        end)

        if event then
            if event.type == "menu" then
                -- User made a selection
                if event.selection == 1 then
                    -- Selected the title, do nothing and loop again
                else
                    -- Selected an option (subtract 1 because title is index 1)
                    result = event.selection - 1
                    break
                end
            elseif event.type == "keybind" and event.key == "space" then
                -- Space key pressed - check if we have menu context
                if event.menu_id == "game_modal" and event.menu_index then
                    -- menu_index is 1-based, where 1 = title
                    -- Subtract 1 to get the skill index (title is position 1)
                    local skill_index = event.menu_index - 1
                    if skill_index > 0 and skill_index <= #skill_actions then
                        local skill_action = skill_actions[skill_index]
                        local description = skill_descriptions[skill_action]
                        if description then
                            player.user:speak(description)
                        end
                    end
                end
                -- Don't break the loop, let them continue browsing
            end
        else
            -- Timeout
            break
        end
    end

    -- Clean up menu (check if player is still valid)
    if player and player.user then
        player.user:remove_menu("game_modal")
    end

    -- Restore mutable action flag
    if self.mutable_action_in_progress ~= nil then
        self.mutable_action_in_progress = was_blocking
    end

    return result
end

----Handle skill menu
function PiratesGame:handle_skill_menu(player)
    if self:is_bot(player) then
        return "continue"
    end

    local skill_options = {}
    local skill_actions = {}

    -- Cannonball shot (always available)
    table.insert(skill_options, "cannonball shot")
    table.insert(skill_actions, "cannonball")

    -- Sailor's instinct (level 10+)
    if player.level and player.level >= 10 then
        table.insert(skill_options, "sailor's instinct")
        table.insert(skill_actions, "instinct")
    end

    -- Portal (level 25+)
    if player.level and player.level >= 25 then
        if player.portal_cooldown == 0 then
            table.insert(skill_options, "portal (teleport to occupied ocean)")
            table.insert(skill_actions, "portal")
        else
            table.insert(skill_options, "portal (on cooldown: " .. player.portal_cooldown .. " turns)")
            table.insert(skill_actions, "portal_cd")
        end
    end

    -- Gem seeker (level 40+)
    if player.level and player.level >= 40 then
        if player.gem_seeker_uses > 0 then
            table.insert(skill_options, "gem seeker (" .. player.gem_seeker_uses .. " uses left)")
            table.insert(skill_actions, "seeker")
        else
            table.insert(skill_options, "gem seeker (no uses remaining)")
            table.insert(skill_actions, "seeker_exhausted")
        end
    end

    -- Sword fighter (level 60+)
    if player.level and player.level >= 60 then
        if player.sword_cooldown == 0 and player.sword_active == 0 then
            table.insert(skill_options, "sword fighter (activate)")
            table.insert(skill_actions, "sword")
        elseif player.sword_active > 0 then
            table.insert(skill_options, "sword fighter (active: " .. player.sword_active .. " turns)")
            table.insert(skill_actions, "sword_cd")
        else
            table.insert(skill_options, "sword fighter (on cooldown: " .. player.sword_cooldown .. " turns)")
            table.insert(skill_actions, "sword_cd")
        end
    end

    -- Push (level 75+)
    if player.level and player.level >= 75 then
        if player.push_cooldown == 0 and player.push_active == 0 then
            table.insert(skill_options, "push (activate)")
            table.insert(skill_actions, "push")
        elseif player.push_active > 0 then
            table.insert(skill_options, "push (active: " .. player.push_active .. " turns)")
            table.insert(skill_actions, "push_cd")
        else
            table.insert(skill_options, "push (on cooldown: " .. player.push_cooldown .. " turns)")
            table.insert(skill_actions, "push_cd")
        end
    end

    -- Skilled captain (level 90+)
    if player.level and player.level >= 90 then
        if player.captain_cooldown == 0 and player.captain_active == 0 then
            table.insert(skill_options, "skilled captain (activate)")
            table.insert(skill_actions, "captain")
        elseif player.captain_active > 0 then
            table.insert(skill_options, "skilled captain (active: " .. player.captain_active .. " turns)")
            table.insert(skill_actions, "captain_cd")
        else
            table.insert(skill_options, "skilled captain (on cooldown: " .. player.captain_cooldown .. " turns)")
            table.insert(skill_actions, "captain_cd")
        end
    end

    -- Battleship (level 125+)
    if player.level and player.level >= 125 then
        if player.battleship_cooldown == 0 then
            table.insert(skill_options, "battleship (fire extra shot)")
            table.insert(skill_actions, "battleship")
        else
            table.insert(skill_options, "battleship (on cooldown: " .. player.battleship_cooldown .. " turns)")
            table.insert(skill_actions, "battleship_cd")
        end
    end

    -- Double Devastation (level 200+)
    if player.level and player.level >= 200 then
        if player.devastation_cooldown == 0 and player.devastation_active == 0 then
            table.insert(skill_options, "double devastation (activate)")
            table.insert(skill_actions, "double_devastation")
        elseif player.devastation_active > 0 then
            table.insert(skill_options, "double devastation (active: " .. player.devastation_active .. " turns)")
            table.insert(skill_actions, "double_devastation_cd")
        else
            table.insert(skill_options, "double devastation (on cooldown: " .. player.devastation_cooldown .. " turns)")
            table.insert(skill_actions, "double_devastation_cd")
        end
    end

    table.insert(skill_options, "back")
    table.insert(skill_actions, "back")

    -- Show modal with skill options (back is the default if timeout/cancelled)
    local choice = self:show_skill_modal(player, "Choose your action:", skill_options, skill_actions, 30000, #skill_options)

    if choice == #skill_options then
        -- User selected "back" or timed out
        return nil
    end

    local chosen_skill = skill_actions[choice]

    -- Check if it's a cooldown skill or exhausted skill - close menu and don't end turn
    if chosen_skill == "portal_cd" or chosen_skill == "captain_cd" or chosen_skill == "sword_cd" or chosen_skill == "push_cd" or chosen_skill == "battleship_cd" or chosen_skill == "double_devastation_cd" then
        player.user:speak("This skill is on cooldown!")
        return nil
    elseif chosen_skill == "seeker_exhausted" then
        player.user:speak("You have no gem seeker uses remaining!")
        return nil
    elseif chosen_skill == "cannonball" then
        return self:handle_cannonball_attack(player)
    elseif chosen_skill == "instinct" then
        skills.use_sailors_instinct(self, player, self.selected_oceans, self.charted_tiles)
        return "continue"
    elseif chosen_skill == "portal" then
        return skills.use_portal(self, player, self.charted_tiles, self.selected_oceans)
    elseif chosen_skill == "captain" then
        return skills.use_skilled_captain(self, player)
    elseif chosen_skill == "sword" then
        return skills.use_sword_fighter(self, player)
    elseif chosen_skill == "push" then
        return skills.use_push(self, player)
    elseif chosen_skill == "double_devastation" then
        return skills.use_double_devastation(self, player)
    elseif chosen_skill == "seeker" then
        skills.use_gem_seeker(self, player, self.gem_positions)
        return "continue"
    elseif chosen_skill == "battleship" then
        return skills.use_battleship(self, player, self.golden_moon_active, self:get_xp_multiplier(), self.game_options.gem_stealing)
    end

    return nil
end

----Handle cannonball attack
function PiratesGame:handle_cannonball_attack(player)
    -- Build target menu (only players within attack range)
    local max_range = 5
    if player.devastation_active and player.devastation_active > 0 then
        max_range = 10
    end

    local target_options = {}
    local target_players = {}
    for _, t in ipairs(self.players) do
        if t ~= player and combat.is_in_attack_range(player, t) then
            local distance = math.abs(player.position - t.position)
            table.insert(target_options, t.name .. " (position " .. t.position .. ", " .. distance .. " squares away)")
            table.insert(target_players, t)
        end
    end

    if #target_players == 0 then
        if player.user then
            player.user:speak("No targets within range! You can only attack players within " .. max_range .. " squares.")
        end
        return "continue"
    end

    table.insert(target_options, "cancel")

    if not self:is_bot(player) then
        -- Show modal for target selection (cancel is the default)
        local choice = self:show_modal(player, "Who do you want to attack?", target_options, 30000, #target_options)

        if choice <= #target_players then
            local target = target_players[choice]
            combat.do_attack(self, player, target, self.golden_moon_active, self:get_xp_multiplier(), self.game_options.gem_stealing)
            return "end_turn"
        end
    end

    return "continue"
end

----Get XP multiplier from game options
function PiratesGame:get_xp_multiplier()
    local xp_mult_str = self.game_options.xp_multiplier
    if xp_mult_str:find("0.25") then
        return 0.25
    elseif xp_mult_str:find("0.5") then
        return 0.5
    elseif xp_mult_str:find("1.5") then
        return 1.5
    elseif xp_mult_str:find("2") then
        return 2
    elseif xp_mult_str:find("3") then
        return 3
    else
        return 1
    end
end

----Check status
function PiratesGame:check_status(player)
    local status_items = {}
    for _, p in ipairs(self.players) do
        local gem_string = ""
        if #p.gems > 0 then
            local gem_name_list = {}
            for _, gem_idx in ipairs(p.gems) do
                table.insert(gem_name_list, gems.gem_names[gem_idx])
            end
            gem_string = ", gems: " .. table.concat(gem_name_list, ", ")
        else
            gem_string = ", no gems"
        end
        table.insert(status_items, p.name .. ": Level " .. p.level .. ", " .. p.xp .. " XP, " .. p.score .. " points" .. gem_string)
    end

    -- Show status box
    self:status_box(player, status_items)
    return "continue"
end

----Check moon brightness
function PiratesGame:check_moon_brightness(player)
    local brightness = math.floor((self.gems_collected * 100) / 18)
    if player.user then
        player.user:speak("The moon is " .. brightness .. "% bright! " .. self.gems_collected .. " out of 18 gems have been collected.")
    end
    return "continue"
end

----Announce winner
function PiratesGame:announce_winner()
    self:broadcast("All gems have been collected! The game is over!")

    -- Find winner by highest score
    local winner = nil
    local highest_score = 0
    for _, p in ipairs(self.players) do
        if p.score > highest_score or (p.score == highest_score and math.random(0, 1) == 0) then
            highest_score = p.score
            winner = p
        end
    end

    self:play_sound("game_pig/win.ogg", 80)
    self:broadcast("The winner is " .. winner.name .. " with " .. winner.score .. " points!")

    self:broadcast("Final scores:")
    for _, p in ipairs(self.players) do
        self:broadcast(p.name .. ": " .. p.score .. " points, level " .. p.level .. ".")
    end

    self.game_active = false
end

----Register this game
register_game({
    name = "Pirates Of The Lost Seas",
    type = "pirates",
    class_name = "PiratesGame",
    require_file = "games/pirates/main.lua",
    min_players = 2,
    max_players = 5,
    category = "Other Games"
})
