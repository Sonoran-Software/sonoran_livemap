---------------------------------------------------------------------------
-- SonoranCAD Listener Event Handling (Recieves data from SonoranCAD)
---------------------------------------------------------------------------
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
-- Listener Event to recieve data from the API listener
RegisterServerEvent('SonoranCAD::pushevents:UnitUpdate')
AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(unit)
    -- Strip the secret SonoranCAD API Key before passing data to clients
    unit.key = nil
    debugLog("Got a unit: "..tostring(json.encode(unit)))
    if unit.type == "EVENT_UNIT_STATUS" then
        if unit.data.apiId1 ~= nil then
            targetPlayer = getPlayerSource(unit.data.apiId1)
            TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, unit)
            debugLog(("Fired to %s with unit data %s"):format(targetPlayer, json.encode(unit)))
        end
    end
end)

registerApiType("GET_ACTIVE_UNITS", "emergency")
AddEventHandler("onServerResourceStart", function(resource)
    if GetCurrentResourceName() ~= resource then
        return
    end
    local payload = { serverId = Config.serverId}
    performApiRequest({payload}, "GET_ACTIVE_UNITS", function(units)
        local allUnits = json.decode(units)
        for k, v in pairs(allUnits) do
            print(json.encode(v))
            local id = getPlayerSource(v.data.apidId1)
            if id ~= nil then
                TriggerClientEvent('SonoranCAD::livemap::UnitAdd', id, v)
            end
        end
    end)
end)