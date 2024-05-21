-- Global variables initialization
LatestGameState = LatestGameState or {}
Game = Game or "YourGameID" -- Replace with your actual game ID
InAction = InAction or false
Logs = Logs or {}

-- Utility functions
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function getNextPosition(x, y, direction)
    local moveOffsets = {
        Up = {x = 0, y = -1},
        Down = {x = 0, y = 1},
        Left = {x = -1, y = 0},
        Right = {x = 1, y = 0},
        UpRight = {x = 1, y = -1},
        UpLeft = {x = -1, y = -1},
        DownRight = {x = 1, y = 1},
        DownLeft = {x = -1, y = 1}
    }
    local move = moveOffsets[direction]
    return x + move.x, y + move.y
end

-- Core game logic functions
function selectBestTarget(player, players, range)
    local bestTarget = nil
    local minHealth = math.huge
    for target, state in pairs(players) do
        if target ~= player.id and inRange(player.x, player.y, state.x, state.y, range) then
            if state.health < minHealth then
                minHealth = state.health
                bestTarget = target
            end
        end
    end
    return bestTarget
end

function determineStrategicMove(player, players, powerUps)
    local bestMove = nil
    local highestScore = -math.huge
    local directions = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
    for _, direction in ipairs(directions) do
        local score = 0
        local newX, newY = getNextPosition(player.x, player.y, direction)
        for _, powerUp in ipairs(powerUps) do
            if inRange(newX, newY, powerUp.x, powerUp.y, 3) then
                score = score + 10
            end
        end
        for enemy, state in pairs(players) do
            if enemy ~= player.id and state.energy > player.energy and inRange(newX, newY, state.x, state.y, 1) then
                score = score - 20
            end
        end
        if score > highestScore then
            highestScore = score
            bestMove = direction
        end
    end
    return bestMove or "Stay"
end

function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local target = selectBestTarget(player, LatestGameState.Players, 1)
    local powerUps = {} -- Define and update this list based on the game state.
    if player.energy > 5 and target then
        print("Target with lowest health in range. Attacking.")
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy), Target = target})
    else
        local move = determineStrategicMove(player, LatestGameState.Players, powerUps)
        ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = move})
    end
end

-- Handlers for game events
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function (msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        print("Game state updated. Print 'LatestGameState' for detailed view.")
    end
)

Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function ()
        print("Getting game state...")
        ao.send({Target = Game, Action = "GetGameState"})
    end
)

Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function (msg)
        print(msg.Event .. ": " .. msg.Data)
    end
)

Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function (msg)
        print("Auto-paying confirmation fees.")
        ao.send({Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1"})
    end
)

Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function ()
        decideNextAction()
    end
)

Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function (msg)
        if not InAction then
            InAction = true
            local playerEnergy = LatestGameState.Players[ao.id].energy
            if playerEnergy == nil then
                print("Unable to read energy. Attack failed.")
            elseif playerEnergy == 0 then
                print("Player has insufficient energy. Attack failed.")
            else
                print("Returning attack.")
                ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
            end
            InAction = false
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)
