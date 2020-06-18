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

local pluginConfig = Config.GetPluginConfig("livemap")

if pluginConfig.enabled then
    ---------------------------------------------------------------------------
    -- ESX Framework Integration
    ---------------------------------------------------------------------------
    -- Request framework object to allow for requests for data
    ESX = nil

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
        RegisterNetEvent('sonorancad:getIdentity')
        AddEventHandler('sonorancad:getIdentity', function()
            local source = source
            local returnData = GetIdentity(source)
            if returnData ~= nil then
                TriggerClientEvent('sonorancad:returnIdentity', source, returnData)
            else
                TriggerClientEvent('sonorancad:returnIdentity', source, {})
            end
        end)
    end
end