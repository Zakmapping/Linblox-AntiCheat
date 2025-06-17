local Linblox = {Security = {}, Core = {}, Modules = {}}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

Linblox.Security.Config = {
    toolThreshold = 5,
    speedThreshold = 26,
    jumpThreshold = 50,
    whitelistedIDs = {123456789},
    webhookConfig = {
        active = true,
        URL = "https://discord.com/api/webhooks/your_webhook_here",
        Notifications = {
            tools = true,
            speed = true,
            jump = true,
            fly = true
        }
    }
}

function Linblox.Core.Init()
    Linblox.Security.toolMonitor = Linblox.Modules.toolProtection.new()
    Linblox.Security.movementMonitor = Linblox.Modules.movementProtection.new()
    Linblox.Core.webhookSystem = Linblox.Modules.webhookHandler.new()
end

Linblox.Modules.toolProtection = {}
function Linblox.Modules.toolProtection.new()
    local self = {}
    local backpackCache = {}
    
    function self.Scan(player)
        local backpack = player:FindFirstChildOfClass("Backpack")
        if not backpack then return end
        
        local toolCount = 0
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then toolCount += 1 end
        end
        
        if toolCount > Linblox.Security.Config.toolThreshold then
            self.Enforce(player, "reaching tools limit", "Tool")
        end
    end
    
    function self.Enforce(player, reason, category)
        player:Kick("Linblox AC: you has been banned (reason: "..reason..")")
        Linblox.Core.webhookSystem:Report(player, reason, category)
    end
    
    Players.PlayerAdded:Connect(function(player)
        local backpack = player:WaitForChild("Backpack", 3)
        if backpack then
            table.insert(backpackCache, backpack)
            backpack.ChildAdded:Connect(function()
                task.wait(0.1)
                self.Scan(player)
            end)
            self.Scan(player)
        end
    end)
    
    return self
end

Linblox.Modules.movementProtection = {}
function Linblox.Modules.movementProtection.new()
    local self = {}
    local monitoredPlayers = {}
    
    local function isWhitelisted(player)
        return table.find(Linblox.Security.Config.whitelistedIDs, player.UserId) ~= nil
    end
    
    function self.monitorCharacter(player)
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        
        humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if humanoid.WalkSpeed > Linblox.Security.Config.speedThreshold then
                self.Enforce(player, "reached speed limit", "Speed")
            end
        end)
        
        humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
            if humanoid.JumpPower > Linblox.Security.Config.jumpThreshold then
                self.Enforce(player, "reached jump limit", "Jump")
            end
        end)
        
        character.ChildAdded:Connect(function(child)
            if child:IsA("BodyGyro") and not isWhitelisted(player) then
                child:Destroy()
                self.Enforce(player, "tried to fly or get bodygyro", "Fly")
            end
        end)
    end
    
    function self.Enforce(player, reason, category)
        player:Kick("Linblox AC: you has been banned (reason: "..reason..")")
        Linblox.Core.webhookSystem:Report(player, reason, category)
    end
    
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            self.monitorCharacter(player)
        end)
    end)
    
    return self
end

Linblox.Modules.webhookHandler = {}
function Linblox.Modules.webhookHandler.new()
    local self = {}
    local banHistory = {}
    
    function self:Report(player, reason, category)
        if not Linblox.Security.Config.webhookConfig.Active then return end
        if not Linblox.Security.Config.webhookConfig.Notifications[category] then return end
        
        local payload = {
            embeds = {{
                title = "🚨 Linblox AC Detection",
                color = 16711680,
                fields = {
                    {name = "Player", value = string.format("[%s](https://www.roblox.com/users/%d/profile)", player.Name, player.UserId), inline = true},
                    {name = "ID", value = tostring(player.UserId), inline = true},
                    {name = "Reason", value = reason, inline = false},
                    {name = "Category", value = category, inline = true},
                    {name = "Banned Before", value = banHistory[player.UserId] and "Yes" or "No", inline = true}
                },
                thumbnail = {
                    url = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", player.UserId)
                },
                footer = {text = "Linblox Security • "..os.date("%Y-%m-%d %H:%M:%S")}
            }}
        }
        
        task.spawn(function()
            local success, response = pcall(function()
                HttpService:PostAsync(
                    Linblox.Security.Config.webhookConfig.URL,
                    HttpService:JSONEncode(payload),
                    Enum.HttpContentType.ApplicationJson
                )
            end)
            if not success then warn("Linblox AC: Webhook Error") end
        end)
        
        banHistory[player.UserId] = true
    end
    
    return self
end

Linblox.Core.Init()