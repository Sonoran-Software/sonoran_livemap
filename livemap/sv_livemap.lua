---------------------------------------------------------------------------
-- SonoranCAD Listener Event Handling (Recieves data from SonoranCAD)
---------------------------------------------------------------------------
-- Tracking of Active Units via SonoranCAD
Active_Units = {}

-- Function to figure out the player server id from their steamHex
function getPlayerSource(identifier)
    local activePlayers = GetPlayers();
    for i,player in pairs(activePlayers) do
        local identifiers = GetIdentifiers(player)
        local primary = identifiers[Config.primaryIdentifier]
        debugLog(("Check %s has identifier %s"):format(player, primary))
        if primary == string.lower(primary) then
            return player
        end
    end
end

-- Function to remove variable from Active_Units array
local function removeTrackedApiId(apiId)
    for k, v in pairs(Active_Units) do
        if v == apiId then
            Active_Units[k] = nil
            debugLog(("Removed player: %s - %s to Active_Units"):format(targetPlayer,unit.data.apidId1))
            break
        end
    end
    debugLog(("Failed to find apiID (%s) in Active_Unit list, this might be fine."):format(unit.data.apidId1))
end

-- Server Event to allow clients to check tracked status
RegisterServerEvent("SonoranCAD::livemap:IsPlayerTracked")
AddEventHandler("SonoranCAD::livemap:IsPlayerTracked", function()
    local identifiers = GetIdentifiers(source)
    local primary = identifiers[Config.primaryIdentifier]
    for k, v in pairs(Active_Units) do
        if v == primary then
            TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", source, true)
            debugLog(("Player is tracked: %s - %s returning TRUE"):format(targetPlayer,primary))
            break
        end
    end
    TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", source, false)
    debugLog(("Player is NOT tracked: %s - %s returning FALSE"):format(targetPlayer,primary))
end
)

-- Listener Event to recieve data from the API listener
RegisterServerEvent('SonoranCAD::pushevents:UnitUpdate')
AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(unit)
    -- Strip the secret SonoranCAD API Key before passing data to clients
    unit.key = nil
    debugLog("Got a unit: "..tostring(json.encode(unit)))
    if unit.type == "EVENT_UNIT_STATUS" then
        if unit.data.apiId1 ~= nil then
            targetPlayer = getPlayerSource(unit.data.apiId1)
            if targetPlayer ~= nil then
                TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, unit)
                debugLog(("Fired to %s with unit data %s"):format(targetPlayer, json.encode(unit)))
            else
                debugLog("Failed to get player source for apiID: " .. unit.data.apidId1)
            end
        end
    end
end)

-- Listener Event to recieve data from the API listener
RegisterServerEvent('SonoranCAD::pushevents:UnitListUpdate')
AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(unit)
    -- Strip the secret SonoranCAD API Key before processing
    unit.key = nil
    debugLog("Got a unit: "..tostring(json.encode(unit)))
    if unit.type == "EVENT_UNIT_LOGIN" then
        if unit.data.apiId1 ~= nil then
            targetPlayer = getPlayerSource(unit.data.apiId1)
            if targetPlayer ~= nil then
                if Config.serverType == "esx" then
                    if isTrackedEmployee(targetPlayer) then
                        table.insert( Active_Units,unit.data.apiId1 )
                        debugLog(("Added player: %s - %s to Active_Units"):format(targetPlayer,unit.data.apidId1))
                    else
                        debugLog("player source: " .. id .. "not a tracked employee.")
                    end
                else
                    table.insert( Active_Units,unit.data.apiId1 )
                    debugLog(("Added player: %s - %s to Active_Units"):format(targetPlayer,unit.data.apidId1))
                end
            else
                debugLog("Failed to get player source for apiID: " .. unit.data.apidId1)
            end
        end
    elseif unit.type == "EVENT_UNIT_LOGOUT" then
        if unit.data.apiId1 ~= nil then
            targetPlayer = getPlayerSource(unit.data.apiId1)
            if targetPlayer ~= nil then
                if Config.serverType == "esx" then
                    if isTrackedEmployee(targetPlayer) then
                        removeTrackedApiId(unit.data.apidId1)
                    else
                        debugLog("player source: " .. id .. "not a tracked employee. No need to remove them.")
                    end
                else
                    removeTrackedApiId(unit.data.apidId1)
                end
                TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
            else
                debugLog("Failed to get player source for apiID: " .. unit.data.apidId1)
            end
        end
    end
end)

registerApiType("GET_ACTIVE_UNITS", "emergency")
Citizen.CreateThread(function()
    while true do
        local units = {}
        local payload = { serverId = Config.serverId}
        performApiRequest({payload}, "GET_ACTIVE_UNITS", function(units)
            local allUnits = json.decode(units)
            for k, v in pairs(allUnits) do
                print(json.encode(v))
                local id = getPlayerSource(v.data.apidId1)
                if id ~= nil then
                    if Config.serverType == "esx" then
                        if isTrackedEmployee(id) then
                            TriggerClientEvent('SonoranCAD::livemap::UnitAdd', id, v)
                            table.insert( units,id )
                        else
                            debugLog("player source: " .. id .. "not a tracked employee. Not tracking on livemap.")
                        end
                    else
                        TriggerClientEvent('SonoranCAD::livemap::UnitAdd', id, v)
                        table.insert( units,id )
                    end
                end
            end
            Active_Units = units
        end)
        Citizen.Wait(60000)
    end
end)
