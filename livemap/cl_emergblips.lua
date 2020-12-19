local pluginConfig = Config.GetPluginConfig("livemap")

if pluginConfig.enableCallerBlips and pluginConfig.enabled then
    if not isPluginLoaded("callcommands") then
        warnLog("[livemap] The callcommands plugin is required for the blips feature.")
        return
    end
    local isCallerForEmergency = false

    RegisterNetEvent("SonoranCAD::livemap:Emergency")
    AddEventHandler("SonoranCAD::livemap:Emergency", function(caller, useBlip, useColor, type, description)
        local x,y,z = table.unpack(GetEntityCoords(PlayerPedId()))
        local playerBlipData = {
            caller = caller,
            icon = 56,
            iconcolor = useColor,
            type = type,
            ['Description'] = description,
            ['pos'] = { x = x, y = y, z = z }
        }
        debugLog("Registered emergency")
        for key,val in pairs(playerBlipData) do
            TriggerServerEvent("sonorancad:livemap:AddPlayerData", key, val)
        end
        TriggerServerEvent("sonorancad:livemap:playerSpawned") 
        isCallerForEmergency = true
    end)

    RegisterNetEvent("SonoranCAD::livemap:ClosedCall")
    AddEventHandler("SonoranCAD::livemap:ClosedCall", function()
        TriggerServerEvent('sonorancad:livemap:RemovePlayer')
        debugLog("Got ClosedCall, removing my data")
    end)

    local callBlips = {}

    RegisterNetEvent("SonoranCAD::livemap:GetCurrentLocation")
    AddEventHandler("SonoranCAD::livemap:GetCurrentLocation", function(description)
        debugLog("got location request")
        TriggerServerEvent("SonoranCAD::livemap:CurrentLocation", GetEntityCoords(PlayerPedId()), description)
    end)

    RegisterNetEvent("SonoranCAD::livemap:AddCallBlip")
    AddEventHandler("SonoranCAD::livemap:AddCallBlip", function(coords, useBlip, useColor, description, src)
        debugLog(("got blip request %s - %s - %s - %s"):format(json.encode(coords), useBlip, useColor, description))
        local x,y,z = table.unpack(coords)
        local callBlip = {}
        callBlip.blip = AddBlipForCoord(x, y, z)
        callBlip.sprite = useBlip
        callBlip.color = useColor
        callBlip.desc = description
        SetBlipSprite(callBlip.blip, useBlip)
        SetBlipDisplay(callBlip.blip, 4)
        SetBlipScale(callBlip.blip, 1.0)
        SetBlipColour(callBlip.blip, useColor)
        SetBlipAsShortRange(callBlip.blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Emergency Call")
        EndTextCommandSetBlipName(callBlip.blip)
        infoLog("Set call blip!")
        callBlips[src] = callBlip
    end)

    RegisterNetEvent("SonoranCAD::livemap:RemoveCallBlip")
    AddEventHandler("SonoranCAD::livemap:RemoveCallBlip", function(src)
        if callBlips[src] ~= nil then
            RemoveBlip(callBlips[src].blip)
            debugLog(("Removed blip from %s"):format(src))
        else
            warnLog(("Unable to find a blip for %s - currentBlips: %s"):format(src, json.encode(callBlips)))
        end
    end)
else
    warnLog("not loading emergblips")
end