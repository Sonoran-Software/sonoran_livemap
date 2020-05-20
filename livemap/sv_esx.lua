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
-- ESX Framework Integration
---------------------------------------------------------------------------
-- Request framework object to allow for requests for data
ESX = nil

local pluginConfig = Config.plugins['livemap']

if Config.serverType == "esx" then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

    -- Helper function to get the ESX Identity object from your database
    function GetIdentity(target)
        local identifier = GetPlayerIdentifiers(target)[1]
        local result = MySQL.Sync.fetchAll("SELECT firstname, lastname, sex, dateofbirth, height, job FROM users WHERE identifier = @identifier", {
                ['@identifier'] = identifier
        })
        local returnData = nil
        if result[1] ~= nil then
            local user = result[1]
        
            return {
                firstname = user['firstname'],
                lastname = user['lastname'],
                dateofbirth = user['dateofbirth'],
                sex = user['sex'],
                height = user['height'],
                job = user['job']
            }
        else
            return nil
        end
    end

    -- Event for clients to request esx_identity information from the server
    RegisterServerEvent('sonorancad:getIdentity')
    AddEventHandler('sonorancad:getIdentity', function()
        local returnData = GetIdentity(source)
        TriggerClientEvent('sonorancad:returnIdentity', source, returnData)
    end)

    function isTrackedEmployee(target)
        local Identity = GetIdentity(target)
        print("Got " .. Identity.job .. " for player " .. target)
        for i,job in pairs(pluginConfig.jobsTracked) do
            print(Identity.job .. " - " .. job)
            if Identity.job == job then
                return true
            end
        end
        return false
    end
end