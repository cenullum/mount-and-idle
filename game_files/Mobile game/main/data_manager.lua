-- Data Manager Module for Heroes and Contracts JSON System
-- Handles loading, parsing, and game logic for all game data

local M = {}

-- Storage for loaded data
M.heroes = {}
M.contracts = {}
M.heroes_by_id = {}
M.contracts_by_id = {}

-- Game constants
local CLAN_ADVANTAGES = {
    red = "green",
    green = "blue", 
    blue = "red"
}
local CLAN_ADVANTAGE_MULTIPLIER = 1.3

-- Initialize the data manager
function M.init()
    M.load_all_data()
    print("Data Manager initialized")
end

-- Load all JSON data files
function M.load_all_data()
    print("Loading game data...")
    
    -- Clear existing data
    M.heroes = {}
    M.contracts = {}
    M.heroes_by_id = {}
    M.contracts_by_id = {}
    
    -- Load heroes
    M.load_heroes()
    
    -- Load contracts
    M.load_contracts()
    
    print("Data loading complete. Heroes: " .. #M.heroes .. ", Contracts: " .. #M.contracts)
end

-- Load all hero JSON files
function M.load_heroes()
    local hero_files = {
        "hero_fire_wizard.json",
        "hero_forest_ranger.json", 
        "hero_ice_knight.json",
        "hero_golden_trader.json",
        "hero_shadow_assassin.json"
    }
    
    for _, filename in ipairs(hero_files) do
        local resource_path = "/main/data/heroes/" .. filename
        local json_data, error_msg = sys.load_resource(resource_path)
        
        if json_data then
            local ok, hero_data = pcall(json.decode, json_data)
            
            if ok and hero_data and hero_data.type == "hero" and hero_data.id and hero_data.name then
                table.insert(M.heroes, hero_data)
                M.heroes_by_id[hero_data.id] = hero_data
                print("Loaded hero: " .. hero_data.name)
            else
                print("ERROR: Failed to parse hero JSON: " .. filename)
                if not ok then
                    print("Parser error: " .. tostring(hero_data))
                end
            end
        else
            print("ERROR: Failed to load hero resource: " .. resource_path)
            print("System error: " .. tostring(error_msg))
        end
    end
end

-- Load all contract JSON files  
function M.load_contracts()
    local contract_files = {
        "contract_copper_mining.json",
        "contract_trade_spices.json",
        "contract_bandit_attack.json",
        "contract_magic_research.json",
        "contract_spy_mission.json",
        "contract_healing_plague.json",
        "contract_castle_construction.json",
        "contract_tax_rebellion.json",
        "contract_forest_logging.json",
        "contract_diplomatic_mission.json"
    }
    
    for _, filename in ipairs(contract_files) do
        local resource_path = "/main/data/contracts/" .. filename
        local json_data, error_msg = sys.load_resource(resource_path)
        
        if json_data then
            local ok, contract_data = pcall(json.decode, json_data)
            
            if ok and contract_data and contract_data.type == "contract" and contract_data.id and contract_data.name then
                table.insert(M.contracts, contract_data)
                M.contracts_by_id[contract_data.id] = contract_data
                print("Loaded contract: " .. contract_data.name)
            else
                print("ERROR: Failed to parse contract JSON: " .. filename)
                if not ok then
                    print("Parser error: " .. tostring(contract_data))
                end
            end
        else
            print("ERROR: Failed to load contract resource: " .. resource_path)
            print("System error: " .. tostring(error_msg))
        end
    end
end

-- Get hero by ID
function M.get_hero(id)
    return M.heroes_by_id[id]
end

-- Get contract by ID
function M.get_contract(id)
    return M.contracts_by_id[id]
end

-- Get all heroes
function M.get_all_heroes()
    return M.heroes
end

-- Get all contracts
function M.get_all_contracts()
    return M.contracts
end

-- Get heroes by clan
function M.get_heroes_by_clan(clan)
    local result = {}
    for _, hero in ipairs(M.heroes) do
        if hero.clan == clan then
            table.insert(result, hero)
        end
    end
    return result
end

-- Get contracts by category
function M.get_contracts_by_category(category)
    local result = {}
    for _, contract in ipairs(M.contracts) do
        if contract.contract and contract.contract.category == category then
            table.insert(result, contract)
        end
    end
    return result
end

-- Get mandatory contracts
function M.get_mandatory_contracts()
    local result = {}
    for _, contract in ipairs(M.contracts) do
        if contract.is_mandatory then
            table.insert(result, contract)
        end
    end
    return result
end

-- Spawn random contracts based on probabilities
function M.spawn_random_contracts(count)
    
    local spawned = {}
    local attempts = 0
    local max_attempts = count * 10 -- Prevent infinite loops
    
    while #spawned < count and attempts < max_attempts do
        attempts = attempts + 1
        
        for _, contract in ipairs(M.contracts) do
            if #spawned >= count then
                break
            end
            
            -- Skip mandatory contracts in random spawning
            if not contract.is_mandatory then
                local random_value = math.random()
                if random_value <= contract.contract.spawn_probability then
                    table.insert(spawned, contract)
                end
            end
        end
    end
    
    return spawned
end

-- Apply clan advantage multiplier
function M.apply_clan_advantage(attacker_clan, defender_clan)
    if not attacker_clan or not defender_clan then
        return 1.0
    end
    
    if CLAN_ADVANTAGES[attacker_clan] == defender_clan then
        return CLAN_ADVANTAGE_MULTIPLIER
    end
    
    return 1.0
end

-- Calculate success rate for hero doing contract
function M.calculate_success_rate(hero, contract)
    if not hero or not contract or not contract.contract then
        return 0
    end
    
    local base_success_rate = 0.5 -- 50% base success rate
    local contract_data = contract.contract
    
    -- Calculate hero stat bonus
    local stat_bonus = 0
    local stat_count = 0
    
    if contract_data.requirements and contract_data.requirements.hero_stats then
        for stat_name, required_value in pairs(contract_data.requirements.hero_stats) do
            if hero.hero and hero.hero.base_stats and hero.hero.base_stats[stat_name] then
                local hero_stat = hero.hero.base_stats[stat_name]
                local ratio = hero_stat / required_value
                stat_bonus = stat_bonus + ratio
                stat_count = stat_count + 1
            end
        end
    end
    
    if stat_count > 0 then
        stat_bonus = stat_bonus / stat_count
    else
        stat_bonus = 1.0
    end
    
    -- Apply clan advantage if applicable
    local clan_multiplier = 1.0
    if contract.clan then
        clan_multiplier = M.apply_clan_advantage(hero.clan, contract.clan)
    end
    
    -- Apply difficulty
    local difficulty_modifier = 1.0 / (contract_data.difficulty or 1.0)
    
    -- Calculate final success rate
    local final_rate = base_success_rate * stat_bonus * clan_multiplier * difficulty_modifier
    
    -- Clamp between 0.05 and 0.95
    final_rate = math.max(0.05, math.min(0.95, final_rate))
    
    return final_rate
end

-- Calculate contract duration for specific hero
function M.calculate_contract_duration(hero, contract)
    if not hero or not contract or not contract.contract then
        return contract.contract and contract.contract.base_duration_seconds or 30
    end
    
    local base_duration = contract.contract.base_duration_seconds
    local contract_data = contract.contract
    
    -- Calculate efficiency based on hero stats
    local efficiency = 1.0
    local stat_count = 0
    
    if contract_data.requirements and contract_data.requirements.hero_stats then
        for stat_name, required_value in pairs(contract_data.requirements.hero_stats) do
            if hero.hero and hero.hero.base_stats and hero.hero.base_stats[stat_name] then
                local hero_stat = hero.hero.base_stats[stat_name]
                local ratio = hero_stat / required_value
                efficiency = efficiency * ratio
                stat_count = stat_count + 1
            end
        end
    end
    
    if stat_count > 0 then
        efficiency = efficiency ^ (1.0 / stat_count) -- Geometric mean
    end
    
    -- Apply clan advantage
    if contract.clan then
        local clan_multiplier = M.apply_clan_advantage(hero.clan, contract.clan)
        efficiency = efficiency * clan_multiplier
    end
    
    -- Calculate final duration (higher efficiency = shorter duration)
    local final_duration = base_duration / math.max(0.5, efficiency)
    
    return math.floor(final_duration)
end

-- Process contract completion
function M.process_contract_completion(hero, contract, success)
    local results = {
        success = success,
        rewards = {},
        xp_gained = {},
        consequences = {}
    }
    
    if not contract.contract then
        return results
    end
    
    local contract_data = contract.contract
    
    if success then
        -- Process guaranteed rewards
        if contract_data.rewards and contract_data.rewards.guaranteed then
            local guaranteed = contract_data.rewards.guaranteed
            
            -- Gold reward
            if guaranteed.gold then
                results.rewards.gold = guaranteed.gold
            end
            
            -- Prestige reward
            if guaranteed.prestige then
                results.rewards.prestige = guaranteed.prestige
            end
            
            -- XP rewards
            if guaranteed.xp then
                for stat, amount in pairs(guaranteed.xp) do
                    results.xp_gained[stat] = amount
                end
            end
        end
        
        -- Process possible rewards (random drops)
        if contract_data.rewards and contract_data.rewards.possible then
            results.rewards.items = {}
            
            for _, item_reward in ipairs(contract_data.rewards.possible) do
                local random_value = math.random()
                if random_value <= item_reward.drop_chance then
                    table.insert(results.rewards.items, {
                        item = item_reward.item,
                        quantity = item_reward.quantity
                    })
                end
            end
        end
        
    else
        -- Process failure consequences
        if contract_data.failure_consequences then
            local consequences = contract_data.failure_consequences
            
            -- Check for death
            if consequences.death_chance then
                local death_roll = math.random()
                if death_roll <= consequences.death_chance then
                    results.consequences.death = true
                end
            end
            
            -- Check for injury
            if consequences.injury_chance and not results.consequences.death then
                local injury_roll = math.random()
                if injury_roll <= consequences.injury_chance then
                    results.consequences.injury = true
                end
            end
            
            -- Resource losses
            if consequences.resource_loss then
                results.consequences.resource_loss = consequences.resource_loss
            end
        end
    end
    
    return results
end

-- Check if hero meets contract requirements
function M.check_contract_requirements(hero, contract, city_level, player_resources)
    if not contract.contract or not contract.contract.requirements then
        return true
    end
    
    local requirements = contract.contract.requirements
    
    -- Check city level
    if requirements.city_level and city_level < requirements.city_level then
        return false
    end
    
    -- Check hero stats
    if requirements.hero_stats and hero and hero.hero and hero.hero.base_stats then
        for stat_name, required_value in pairs(requirements.hero_stats) do
            local hero_stat = hero.hero.base_stats[stat_name] or 0
            if hero_stat < required_value then
                return false
            end
        end
    end
    
    -- Check resources
    if requirements.resources and player_resources then
        for resource_name, required_amount in pairs(requirements.resources) do
            local available = player_resources[resource_name] or 0
            if available < required_amount then
                return false
            end
        end
    end
    
    return true
end

-- Get contract difficulty description
function M.get_difficulty_description(difficulty)
    if difficulty <= 1.0 then
        return "Easy"
    elseif difficulty <= 1.5 then
        return "Normal"
    elseif difficulty <= 2.0 then
        return "Hard"
    elseif difficulty <= 2.5 then
        return "Very Hard"
    else
        return "Extreme"
    end
end

-- Get formatted contract details for UI
function M.get_contract_details_for_ui(hero, contract)
    if not contract or not contract.contract then
        return nil
    end
    
    local details = {
        name = contract.name,
        category = contract.contract.category,
        difficulty = M.get_difficulty_description(contract.contract.difficulty),
        is_mandatory = contract.is_mandatory or false
    }
    
    if hero then
        details.success_rate = M.calculate_success_rate(hero, contract)
        details.duration = M.calculate_contract_duration(hero, contract)
        details.success_rate_percent = math.floor(details.success_rate * 100)
    end
    
    -- Requirements
    if contract.contract.requirements then
        details.requirements = contract.contract.requirements
    end
    
    -- Rewards
    if contract.contract.rewards then
        details.rewards = contract.contract.rewards
    end
    
    return details
end

return M
