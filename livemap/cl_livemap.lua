--[[
        SonoranCAD FiveM - A SonoranCAD integration for FiveM servers
              Copyright (C) 2020  Sonoran Software Systems LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program in the file "LICENSE".  If not, see <http://www.gnu.org/licenses/>.
]]

---------------------------------------------------------------------------
-- Client Data Processing for Live Map Blip
---------------------------------------------------------------------------
-- Default blip datafields to be initialized and updated
local pluginConfig = Config.GetPluginConfig("livemap")

if pluginConfig.enabled then
    local playerBlipData = {}
    local standalonePlayerBlipData = {
        ["pos"] = { x=0, y=0, z=0 },
        ["icon"] = 6, -- Curent player blip id
        ["iconcolor"] = 0, -- Blip Color
        ["name"] = "NOT SET"
    }
    local esxPlayerBlipData = {
        ["pos"] = { x=0, y=0, z=0 },
        ["icon"] = 6, -- Curent player blip id
        ["iconcolor"] = 0, -- Blip Color, Used to show job type
        ["name"] = "NOT SET",
        ["Unit Number"] = "0",
        ["Status"] = "UNAVALIABLE",
        ["Call Assignment"] = "UNASSIGNED"
    }

    -- Table to keep track of the updated data
    local beenUpdated =  {}
    -- Update the data and queue the key to be updated on the websocket server
    function updateData(name, value)
        table.insert(beenUpdated, name)
        playerBlipData[name] = value
    end

    -- Event to recieve requested IsTracked status
    local IsTracked = nil
    RegisterNetEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus")
    AddEventHandler("SonoranCAD::livemap:ReturnPlayerTrackStatus", function(status)
        IsTracked = status
    end)

    -- Function to check if player's framwork job type is to be tracked on the live map
    local LastTrackedResult = false
    function IsTrackedUnit()
        TriggerServerEvent("SonoranCAD::livemap:IsPlayerTracked")
        while IsTracked == nil do
            Wait(500)
        end
        if LastTrackedResult ~= IsTracked then
            TriggerServerEvent('sonorancad:livemap:RemovePlayer')
        end
        return IsTracked
    end

    -- Listener event to update data on the websocket server with data from SonoranCAD
    RegisterNetEvent('SonoranCAD::pushevents:UnitUpdate')
    AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(unit)
        -- check for changes in the data from the last set value and update changes
        local unitDetail = unit.data
        if playerBlipData['Unit Number'] ~= unitDetail.unitNum then
            updateData('Unit Number', unitDetail.unitNum)
        end
        if playerBlipData['Status'] ~= unit.status then
            local label = Config.statusLabels[unit.status + 1]
            print("label is "..tostring(label))
            updateData('Status', label)
        end
        if playerBlipData['name'] ~= unitDetail.name then
            updateData('name', unitDetail.name)
        end

        -- As mentioned in the API documentation data.callStatus is not always sent, only when it is changed. This will only update when it is sent
        if unit.callStatus ~= '' then
            if playerBlipData['Call Assignment'] ~= unit.callStatus then
                updateData('Call Assignment', unit.callStatus)
            end
        end
    end)

    --[[
        When the player spawns, make sure we set their ID in the data that is going
        to be sent via sockets. Wait for the server to send framwork integration data
        and configuration necessary to initialize the livemap integration.
    ]]
    local firstSpawn = true
    function TriggerFirstSpawn(jobTriggered)
        -- only run when first spawned into the world or when job is changed in the framework integration
        if firstSpawn then
            -- Checks Config.serverType framework integrated or standalone and sets the default data set based on option set
            if Config.serverType == 'standalone' then
                playerBlipData = standalonePlayerBlipData
            elseif Config.serverType == 'esx' then
                playerBlipData = esxPlayerBlipData
                -- waits to see if framework data is initialized before moving on
                while PlayerData == {} do
                    Citizen.SetTimeout(10)
                end
            end
            -- In framwork integration mode, check if player is a tracked job type as configured in config.json
            -- This limits only tracked jobs to be displayed on the livemap when in framework integrated mode
            if IsTrackedUnit() then
                TriggerServerEvent("sonorancad:livemap:playerSpawned") -- Set's the ID in "playerData" so it will get sent via sockets
                -- Now send the default data set
                for key,val in pairs(playerBlipData) do
                    TriggerServerEvent("sonorancad:livemap:AddPlayerData", key, val)
                end
            end
            -- Set inital name if steamHex is not defined in SonoranCAD
            if Config.serverType == 'esx' then
                GetIdentity(function(esxIdentity)
                    updateData("name", esxIdentity.firstname .. ' ' .. esxIdentity.lastname)
                end)
            elseif Config.serverType == 'standalone' then
                updateData("name", GetPlayerName(PlayerId()))
            end

            firstSpawn = false
            Citizen.Wait(100)
        else
            -- Allow framework job changes to reset player's blip and recheck if they should be checked, useful for duty scripts and character changes
            if jobTriggered then
                TriggerServerEvent('sonorancad:livemap:RemovePlayer')
                firstSpawn = true
                TriggerFirstSpawn(jobTriggered)
            end
        end
    end

    RegisterNetEvent("SonoranCAD::livemap::UnitAdd")
    AddEventHandler("SonoranCAD::livemap::UnitAdd", function(data)
        TriggerServerEvent("sonorancad:livemap:playerSpawned")
        local unitDetail = data.data
        if playerBlipData['Unit Number'] ~= unitDetail.unitNum then
            updateData('Unit Number', unitDetail.unitNum)
        end
        if playerBlipData['Status'] ~= data.status then
            local label = Config.statusLabels[data.status + 1]
            updateData('Status', label)
        end
        if playerBlipData['name'] ~= unitDetail.name then
            updateData('name', unitDetail.name)
        end
        if playerBlipData['department'] ~= unitDetail.department then
            updateData('Department', unitDetail.department)
        end
        if playerBlipData['subdivision'] ~= unitDetail.subdivision then
            updateData('subdivision', unitDetail.subdivision)
        end

        -- As mentioned in the API documentation data.callStatus is not always sent, only when it is changed. This will only update when it is sent
        if unitDetail.callStatus ~= '' then
            if playerBlipData['Call Assignment'] ~= unitDetail.callStatus then
                updateData('Call Assignment', unitDetail.callStatus)
            end
        end

        for key,val in pairs(playerBlipData) do
            TriggerServerEvent("sonorancad:livemap:AddPlayerData", key, val)
        end
        firstSpawn = true
        TriggerFirstSpawn(false)
    end)

    -- Listener event for inital player spawn
    RegisterNetEvent("playerSpawned")
    AddEventHandler("playerSpawned", function(spawn)
        TriggerFirstSpawn(false)
    end)
    -- Listener event to allow for framwork jobs to refresh player blip
    RegisterNetEvent("sonorancad:livemap:firstSpawn")
    AddEventHandler("sonorancad:livemap:firstSpawn", function(jobTriggered)
        TriggerFirstSpawn(jobTriggered)
    end)

    -- Function to change live map icons based on type of vehicle player is in, does not take in account addon/dlc vehicles
    function doIconUpdate()
        local ped = PlayerPedId()
        local newSprite = 6 -- Default to the player one

        if IsEntityDead(ped) then
            newSprite = 163 -- Using GtaOPassive since I don't have a "death" icon :(
        else
            if IsPedSittingInAnyVehicle(ped) then
                -- Change icon to vehicle
                -- our temp table should still have the latest vehicle
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), 0)
                local vehicleModel = GetEntityModel(vehicle)
                local h = GetHashKey

                if vehicleModel == h("rhino") then
                    newSprite = 421
                elseif (vehicleModel == h("lazer") or vehicleModel == h("besra") or vehicleModel == h("hydra")) then
                    newSprite = 16 -- Jet
                elseif IsThisModelAPlane(vehicleModel) then
                    newSprite = 90 -- Airport (plane icon)
                elseif IsThisModelAHeli(vehicleModel) then
                    newSprite = 64 -- Helicopter
                elseif (vehicleModel == h("dinghy") or vehicleModel == h("dinghy2") or vehicleModel == h("dinghy3")) then
                    newSprite = 404 -- Dinghy
                elseif (vehicleModel == h("submersible") or vehicleModel == h("submersible2")) then
                    newSprite = 308 -- Sub
                elseif IsThisModelABoat(vehicleModel) then
                    newSprite = 410
                elseif (IsThisModelABike(vehicleModel) or IsThisModelABicycle(vehicleModel)) then
                    newSprite = 226
                elseif (vehicleModel == h("policeold2") or vehicleModel == h("policeold1") or vehicleModel == h("policet") or vehicleModel == h("police") or vehicleModel == h("police2") or vehicleModel == h("police3") or vehicleModel == h("policeb") or vehicleModel == h("riot") or vehicleModel == h("sheriff") or vehicleModel == h("sheriff2") or vehicleModel == h("pranger")) then
                    newSprite = 56 -- PoliceCar
                elseif vehicleModel == h("taxi") then
                    newSprite = 198
                elseif (vehicleModel == h("brickade") or vehicleModel == h("stockade") or vehicleModel == h("stockade2")) then
                    newSprite = 66 -- ArmoredTruck
                elseif (vehicleModel == h("towtruck") or vehicleModel == h("towtruck")) then
                    newSprite = 68
                elseif (vehicleModel == h("trash") or vehicleModel == h("trash2")) then
                    newSprite = 318
                else
                    newSprite = 225 -- PersonalVehicleCar
                end
            end
        end
        -- Only update icon if there is a change
        if playerBlipData["icon"] ~= newSprite then
            updateData("icon", newSprite)
        end
    end

    ---------------------------------------------------------------------------
    -- Main thread that checks for data updates and updates server
    ---------------------------------------------------------------------------
    Citizen.CreateThread(function()
        while not Config.serverType do
            Wait(10)
        end
        while true do
            Citizen.Wait(1000)
            -- Only run if firstSpawn is not running
            if NetworkIsPlayerActive(PlayerId()) and not firstSpawn then
                -- Only run if player is in a framwork tracked job, track all players if in standalone mode
                if IsTrackedUnit() then
                    -- Update position, if it has changed
                    local x,y,z = table.unpack(GetEntityCoords(PlayerPedId()))
                    local x1,y1,z1 = playerBlipData["pos"].x, playerBlipData["pos"].y, playerBlipData["pos"].z
    
                    local dist = Vdist(x, y, z, x1, y1, z1)
    
                    if (dist >= 5) then
                        -- Update every 5 meters.. Let's reduce the amount of spam
                        updateData("pos", {x = x, y=y, z=z})
                    end
    
                    doIconUpdate()
    
                    -- Make sure the updated data is up-to-date on socket server as well
                    for i,k in pairs(beenUpdated) do
                        --Citizen.Trace("Updating " .. k)
                        TriggerServerEvent("sonorancad:livemap:UpdatePlayerData", k, playerBlipData[k])
                        table.remove(beenUpdated, i)
                    end
                end
            end
        end
    end)
end