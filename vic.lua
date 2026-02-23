-- Vicious Bee Stinger Hunter Script v3.7 - SECURED WITH WEBHOOK TOKEN + WHITELIST
-- Detects "Thorn" parts (Size: 3×2×1.5) that spawn near fields (ONCE per spawn event)
-- NEW: Whitelist system - Auto marks as NOT ACTIVE after 50 seconds for whitelisted players

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local request = request or http_request or syn.request
local player = Players.LocalPlayer

-- ANTI-IDLE SYSTEM (SINGLETON-SAFE VERSION)

-- Disconnect old anti-idle connection if it exists
if _G._AntiIdleConn then
    pcall(function()
        _G._AntiIdleConn:Disconnect()
    end)
    _G._AntiIdleConn = nil
end

-- Stop old anti-idle loop
if _G._AntiIdleRunning then
    _G._AntiIdleRunning = false
end

-- Small delay to ensure old loop exits
wait(0.1)

-- Create new anti-idle connection
_G._AntiIdleConn = player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Create new anti-idle loop
_G._AntiIdleRunning = true
local function antiIdleTick()
    if not _G._AntiIdleRunning then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    task.delay(600, antiIdleTick)
end

task.delay(600, antiIdleTick)

-- Singleton check
if _G.ViciousBeeHunterActive then
    warn("⚠️ Script already running! Stopping old instance...")
    
    if _G.ViciousBeeConfig then
        _G.ViciousBeeConfig._monitoringActive = false
        _G.ViciousBeeConfig.isRunning = false
        
        if _G.ViciousBeeConfig._descendantConnection then
            _G.ViciousBeeConfig._descendantConnection:Disconnect()
            _G.ViciousBeeConfig._descendantConnection = nil
        end
        if _G.ViciousBeeConfig._playerMonitorConnection then
            _G.ViciousBeeConfig._playerMonitorConnection:Disconnect()
        end
        if _G.ViciousBeeConfig._playerRemovingConnection then
            _G.ViciousBeeConfig._playerRemovingConnection:Disconnect()
        end
        if _G.ViciousBeeConfig._activeStatusTimer then
            pcall(function()
                task.cancel(_G.ViciousBeeConfig._activeStatusTimer)
            end)
        end
    end
    
    wait(0.5)
end

_G.ViciousBeeHunterActive = true

-- Initialize global config if it doesn't exist
if not _G.ViciousBeeConfig then
    _G.ViciousBeeConfig = {}
end

local config = _G.ViciousBeeConfig

-- ✅ RESET HOPPING LOCK ON SCRIPT START (prevents lock persistence after teleport)
config._isCurrentlyHopping = false

config.WEBHOOK_URL = config.WEBHOOK_URL or "https://discord.com/api/webhooks/1456640369801429155/whXmluN3paYc-mMltkKNNJObdzOue1hZvUC72fnCR7x_KTaw4CM2fdSVZZOp6Nvv9ZVu"
config.PC_SERVER_URL = config.PC_SERVER_URL or "https://antral-contemplatingly-logan.ngrok-free.dev/log"
config.WEBHOOK_SECRET = config.WEBHOOK_SECRET or "uupcRwDaCaz0kzxPnibqIbMdNNd1r753oUdS8H8akx8"
config._lastStingerDetectionTime = config._lastStingerDetectionTime or 0
config._stingerSpawnCooldown = config._stingerSpawnCooldown or 2
config._monitoringActive = config._monitoringActive or false
config.playerCountThreshold = config.playerCountThreshold or 6
config.webhookUrl = config.webhookUrl or ""
config.pcServerUrl = config.pcServerUrl or ""
config.webhookSecret = config.webhookSecret or ""
config.isRunning = config.isRunning or false
config.stingerDetected = config.stingerDetected or false
config.currentField = config.currentField or "None"
config._descendantConnection = config._descendantConnection or nil
config._detectedStingers = config._detectedStingers or {}
config.detectionCount = config.detectionCount or 0
config.serverType = config.serverType or "Public"
config.privateServerLink = config.privateServerLink or ""
config.expectedSize = config.expectedSize or Vector3.new(3.0, 2.0, 1.5)
config.sizeTolerance = config.sizeTolerance or 0.1
config.stingerActiveTime = config.stingerActiveTime or 240
config._activeStatusTimer = config._activeStatusTimer or nil
config._renderConnection = config._renderConnection or nil

-- Set the webhook URLs from constants
config.webhookUrl = config.WEBHOOK_URL
config.pcServerUrl = config.PC_SERVER_URL
config.webhookSecret = config.WEBHOOK_SECRET

config._propertyConnections = config._propertyConnections or {}
config._isCurrentlyHopping = config._isCurrentlyHopping or false

-- ✅ BOT ID SYSTEM (prevents collisions)
local function generateBotID()
    local name = player.Name
    local hash = 0
    for i = 1, #name do
        hash = (hash * 31 + string.byte(name, i)) % 1000
    end
    return hash
end

config._botID = config._botID or generateBotID()
config._staggerDelay = (config._botID % 30)  -- 0-30 second spread
print(string.format("🤖 Bot ID: %d | Stagger Delay: %ds", config._botID, config._staggerDelay))

local function periodicCleanup()
    local now = tick()
    local cleaned = 0

    -- Clean detected stingers
    for obj, status in pairs(config._detectedStingers) do
        if typeof(obj) ~= "Instance" or not obj.Parent or status == "defeated" then
            config._detectedStingers[obj] = nil
            cleaned = cleaned + 1
        end
    end

    -- 🔧 Clean up dead property connections
    if config._propertyConnections then
        local active = {}
        for _, conn in pairs(config._propertyConnections) do
            if conn and conn.Connected then
                table.insert(active, conn)
            else
                cleaned = cleaned + 1
            end
        end
        config._propertyConnections = active
    end

    -- ✅ NEW: Clean ancestry connections
    if config._stingerAncestryConnections then
        for obj, conn in pairs(config._stingerAncestryConnections) do
            if typeof(obj) ~= "Instance" or not obj.Parent then
                if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
                    pcall(function() conn:Disconnect() end)
                end
                config._stingerAncestryConnections[obj] = nil
                cleaned = cleaned + 1
            end
        end
    end

    -- Clean webhook cache
    if config._lastWebhooks then
        for k, t in pairs(config._lastWebhooks) do
            if now - t > 5 then
                config._lastWebhooks[k] = nil
            end
        end
    end
    
    -- Clean log cache
    if config._lastLogSend then
        for k, t in pairs(config._lastLogSend) do
            if now - t > 30 then
                config._lastLogSend[k] = nil
            end
        end
    end
    
    task.delay(300, periodicCleanup)  -- Run every 2 minutes
end

task.delay(300, periodicCleanup)

-- Load saved webhook
if isfile and readfile and isfile("vicious_bee_webhook.txt") then
    local saved = readfile("vicious_bee_webhook.txt")
    if saved and saved ~= "" then
        config.webhookUrl = saved
    end
end

-- Load saved PC server URL
if isfile and readfile and isfile("vicious_bee_pcserver.txt") then
    local saved = readfile("vicious_bee_pcserver.txt")
    if saved and saved ~= "" then
        config.pcServerUrl = saved
    end
end

-- Load saved webhook secret
if isfile and readfile and isfile("vicious_bee_secret.txt") then
    local saved = readfile("vicious_bee_secret.txt")
    if saved and saved ~= "" then
        config.webhookSecret = saved
    end
end

-- Load saved server type and private link
if isfile and readfile and isfile("vicious_bee_serverconfig.txt") then
    local success, result = pcall(function()
        local saved = readfile("vicious_bee_serverconfig.txt")
        if saved and saved ~= "" then
            return HttpService:JSONDecode(saved)
        end
    end)
    if success and result then
        config.serverType = result.serverType or "Public"
        config.privateServerLink = result.privateServerLink or ""
    end
end

local fields = {
    ["Sunflower Field"] = Vector3.new(183, 4, 165),
    ["Mushroom Field"] = Vector3.new(-253, 4, 299),
    ["Dandelion Field"] = Vector3.new(-30, 4, 225),
    ["Blue Flower Field"] = Vector3.new(113, 4, 88),
    ["Clover Field"] = Vector3.new(174, 34, 189),
    ["Strawberry Field"] = Vector3.new(-169, 20, 165),
    ["Spider Field"] = Vector3.new(-57, 20, 4),
    ["Bamboo Field"] = Vector3.new(93, 20, -25),
    ["Pineapple Patch"] = Vector3.new(262, 68, -201),
    ["Pumpkin Patch"] = Vector3.new(-194, 68, -182),
    ["Cactus Field"] = Vector3.new(-194, 68, -107),
    ["Rose Field"] = Vector3.new(-322, 20, 124),
    ["Pine Tree Forest"] = Vector3.new(-318, 68, -150),
    ["Stump Field"] = Vector3.new(439, 96, -179),
    ["Coconut Field"] = Vector3.new(-255, 72, 459),
    ["Pepper Patch"] = Vector3.new(-486, 124, 517),
    ["Mountain Top Field"] = Vector3.new(76, 176, -191)
}

local function sendWebhook(title, description, color, webhookFields)
    if config.webhookUrl == "" then return end
    
    -- 🔒 WEBHOOK DEBOUNCE: Prevent same webhook within 2 seconds
    local webhookKey = title .. description
    local now = tick()
    
    if not config._lastWebhooks then
        config._lastWebhooks = {}
    end
    
    if config._lastWebhooks[webhookKey] and now - config._lastWebhooks[webhookKey] < 2 then
        return
    end
    
    config._lastWebhooks[webhookKey] = now
    
    local embed = {
        ["title"] = title,
        ["description"] = description,
        ["color"] = color,
        ["fields"] = webhookFields or {},
        ["timestamp"] = DateTime.now():ToIsoDate(),
        ["footer"] = {["text"] = "Vicious Bee Hunter | " .. player.Name}
    }
    
    local success, err = pcall(function()
        request({
            Url = config.webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["embeds"] = {embed}, ["content"] = "@everyone"})
        })
    end)
    
    if not success then
        warn("Webhook failed:", err)
    end
end

local function getActiveField()
    return config.currentField or "None"
end

local function getClosestField(position)
    local closestField = "Unknown"
    local closestDistance = math.huge
    
    for fieldName, fieldPos in pairs(fields) do
        local dist = (position - fieldPos).Magnitude
        if dist < closestDistance then
            closestDistance = dist
            closestField = fieldName
        end
    end
    
    return closestField, closestDistance
end

local function verifySizeMatch(objSize)
    return math.abs(objSize.X - config.expectedSize.X) <= config.sizeTolerance and
           math.abs(objSize.Y - config.expectedSize.Y) <= config.sizeTolerance and
           math.abs(objSize.Z - config.expectedSize.Z) <= config.sizeTolerance
end

local function generateJoinLink()
    if config.serverType == "Private" and config.privateServerLink ~= "" then
        return config.privateServerLink
    else
        local placeId = game.PlaceId
        local jobId = game.JobId
        return string.format("roblox://experiences/start?placeId=%d&gameInstanceId=%s", placeId, jobId)
    end
end

local function getPlayerCount()
    return #Players:GetPlayers()
end

-- ✅ BOT MARKER SYSTEM
local function identifyAsBot()
    -- Add hidden marker to our player
    if not player:FindFirstChild("_VBBOT") then
        local marker = Instance.new("Folder")
        marker.Name = "_VBBOT"
        marker.Parent = player
        print("✅ Bot marker created")
    end
end

local function detectOtherBots()
    local botCount = 0
    local botNames = {}
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr:FindFirstChild("_VBBOT") then
            botCount = botCount + 1
            table.insert(botNames, plr.Name)
        end
    end
    
    return botCount, botNames
end

local function serverHopDueToBot(botName)
    print(string.format("🤖 DETECTED BOT: %s - Hopping immediately!", botName))
    
    sendWebhook(
        "🤖 Bot Collision Detected",
        string.format("Found bot **%s** in server!\n\nHopping immediately to avoid collision...", botName),
        0xFF6B6B,
        {
            { name = "🤖 Detected Bot", value = botName, inline = true },
            { name = "🤖 My Bot", value = player.Name, inline = true }
        }
    )
    
    task.wait(1)
    
    -- Force immediate hop
    config._isCurrentlyHopping = false  -- Reset lock
    config._totalHopAttempts = 0  -- Reset attempts
    serverHopIfCrowded()  -- Use existing hop function
end

local function identifyAsBot()
    if not player:FindFirstChild("_VBBOT") then
        local marker = Instance.new("Folder")
        marker.Name = "_VBBOT"
        marker.Parent = player
        print("✅ Bot marker created")
    end
end

local function detectOtherBots()
    local botCount = 0
    local botNames = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr:FindFirstChild("_VBBOT") then
            botCount += 1
            table.insert(botNames, plr.Name)
        end
    end

    return botCount, botNames
end

local function updateStingerLog(playerName, field, status, joinLink)
    -- 🔒 PC SERVER DEBOUNCE (prevents duplicate ngrok requests)
    config._lastLogSend = config._lastLogSend or {}
    local key = playerName .. "|" .. field .. "|" .. status
    local now = os.time()

    if config._lastLogSend[key] and now - config._lastLogSend[key] < 2 then
        return
    end

    config._lastLogSend[key] = now
    if config.pcServerUrl ~= "" then
        local logData = {
            player = playerName,
            field = field,
            status = status,
            timestamp = os.time(),
            detectionTime = os.time(),
            serverLink = joinLink or "N/A"
        }
        
        local success, err = pcall(function()
            request({
                Url = config.pcServerUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-Webhook-Token"] = config.webhookSecret
                },
                Body = HttpService:JSONEncode(logData)
            })
        end)
        
        if not success then
            warn("❌ Failed to send log to PC:", err)
        end
    end
end

local function startPlayerCountMonitoring(field, joinLink)
    config._monitoringSessionId = tick()
    local sessionId = config._monitoringSessionId
    -- 🔧 ENHANCED CLEANUP: Stop any existing monitoring COMPLETELY
    
    -- Force stop monitoring flag
    config._monitoringActive = false
    
    -- Disconnect PlayerAdded connection
    if config._playerMonitorConnection then
        pcall(function()
            config._playerMonitorConnection:Disconnect()
        end)
        config._playerMonitorConnection = nil
    end
    
    -- Disconnect PlayerRemoving connection
    if config._playerRemovingConnection then
        pcall(function()
            config._playerRemovingConnection:Disconnect()
        end)
        config._playerRemovingConnection = nil
    end
    
    -- Cancel 4-minute timer
    if config._activeStatusTimer then
        pcall(function()
            task.cancel(config._activeStatusTimer)
        end)
        config._activeStatusTimer = nil
    end
    
    -- Small delay to ensure cleanup completes
    task.wait(0.1)
    
    config._monitoringActive = true
    local monitorStartTime = tick()
    local lastPlayerCount = getPlayerCount()
    local lastStatus = lastPlayerCount < config.playerCountThreshold and "ACTIVE" or "NOT ACTIVE"
    
    -- Set initial status based on player count
    updateStingerLog(player.Name, getActiveField(), lastStatus, joinLink)
    
    -- Monitor player joins/leaves
    local function onPlayerCountChange()
        if sessionId ~= config._monitoringSessionId then return end

    if not config._monitoringActive then
        return
    end
    
    local currentPlayerCount = getPlayerCount()
        local newStatus = currentPlayerCount < config.playerCountThreshold and "ACTIVE" or "NOT ACTIVE"

        
        -- Only update if status changed
        if newStatus ~= lastStatus then
            updateStingerLog(player.Name, getActiveField(), newStatus, joinLink)
            
            local changeType = currentPlayerCount > lastPlayerCount and "joined" or "left"
            
            sendWebhook(
                "👥 Player Count Changed",
                string.format("Player count changed from **%d** to **%d**\n\nStatus updated to: **%s**", lastPlayerCount, currentPlayerCount, newStatus),
                newStatus == "ACTIVE" and 0x00FF00 or 0xFF5252,
                {
                    { name = "📊 Player Count", value = tostring(currentPlayerCount), inline = true },
                    { name = "📊 Status", value = newStatus, inline = true },
                    { name = "📍 Field", value = getActiveField(), inline = true },
                    { name = "🤖 Bot", value = player.Name, inline = true }
                }
            )
            
            lastStatus = newStatus
        end
        
        lastPlayerCount = currentPlayerCount
    end
    
    -- Connect to player events WITH DEBOUNCE
    config._playerMonitorConnection = Players.PlayerAdded:Connect(function()
        task.delay(0.5, onPlayerCountChange) -- Delay to batch rapid joins
    end)
    
    -- 🔧 STORE THIS CONNECTION GLOBALLY (NOT LOCAL!)
    config._playerRemovingConnection = Players.PlayerRemoving:Connect(function()
        task.delay(0.5, onPlayerCountChange) -- Delay to batch rapid leaves
    end)
    
    -- 4-minute timer
config._activeStatusTimer = task.delay(config.stingerActiveTime, function()
    if sessionId ~= config._monitoringSessionId then return end
    
    if not config._monitoringActive then
        return
    end
    
    -- Stop monitoring completely
    config._monitoringActive = false
    
    -- 🔧 DISCONNECT BOTH CONNECTIONS (was missing _playerRemovingConnection)
    if config._playerMonitorConnection then
        pcall(function()
            config._playerMonitorConnection:Disconnect()
        end)
        config._playerMonitorConnection = nil
    end
    
    if config._playerRemovingConnection then  -- ← ADD THIS ENTIRE BLOCK
        pcall(function()
            config._playerRemovingConnection:Disconnect()
        end)
        config._playerRemovingConnection = nil
    end
    
    -- Set final status to NOT ACTIVE
    updateStingerLog(player.Name, getActiveField(), "NOT ACTIVE", joinLink)
    
    sendWebhook(
        "⏰ Monitoring Period Ended",
        "4-minute window has expired.\n\nStatus set to: **NOT ACTIVE**",
        0xFFA500,
        {
            { name = "📍 Field", value = getActiveField(), inline = true },
            { name = "🤖 Bot", value = player.Name, inline = true },
            { name = "⏱️ Duration", value = "4 minutes", inline = true }
        }
    )
end)
    
    sendWebhook(
        "🎯 Player Count Monitoring Started",
        string.format("Monitoring player count for **4 minutes**\n\nCurrent players: **%d**\nThreshold: **%d players**\nInitial status: **%s**", lastPlayerCount, config.playerCountThreshold, lastStatus),
        0x2196F3,
        {
            { name = "📊 Current Players", value = tostring(lastPlayerCount), inline = true },
            { name = "📊 Threshold", value = tostring(config.playerCountThreshold), inline = true },
            { name = "📊 Initial Status", value = lastStatus, inline = true },
            { name = "📍 Field", value = getActiveField(), inline = true },
            { name = "⏱️ Duration", value = "4 minutes", inline = true }
        }
    )
end

-- SMART DETECTION: Only alert ONCE per spawn event with size verification
local function onNewObject(obj)
    if config.stingerDetected then
        return
    end

    local now = tick()
    if now - config._lastStingerDetectionTime < config._stingerSpawnCooldown then
        return
    end

    if not config.isRunning then return end

    if not obj or not obj.Parent then return end
    if not obj:IsA("BasePart") then return end
    
    if obj.Name ~= "Thorn" then return end
    
    if not verifySizeMatch(obj.Size) then
        return
    end

    local field, distance = getClosestField(obj.Position)

    if field == "Unknown" or distance > 150 then
        return
    end

    -- per-object dedupe
    if config._detectedStingers[obj] then return end
    config._detectedStingers[obj] = true

    config.stingerDetected = true
    task.delay(300, function()
        if config.stingerDetected and not config._defeatReported then
            config.stingerDetected = false
            config._defeatReported = false
        end
    end)
    config._defeatReported = false
    config._lastStingerDetectionTime = now
    config.currentField = field
    config.detectionCount = config.detectionCount + 1

    local joinLink = generateJoinLink()
    local serverTypeText = config.serverType == "Private" and "🔒 Private Server" or "🌐 Public Server"
    
    -- Start player count monitoring for 4 minutes
    startPlayerCountMonitoring(field, joinLink)
    
    local playerDistance = "Unknown"
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            playerDistance = math.floor((hrp.Position - obj.Position).Magnitude) .. " studs"
        end
    end

    local currentPlayerCount = getPlayerCount()
    local webhookFields = {
        { name = "📦 Object Name", value = obj.Name, inline = true },
        { name = "🔧 Type", value = obj.ClassName, inline = true },
        { name = "📍 Field", value = config.currentField, inline = true },
        { name = "📏 Field Distance", value = math.floor(distance) .. " studs", inline = true },
        { name = "👤 Player Distance", value = playerDistance, inline = true },
        { name = "🖥️ Server Type", value = serverTypeText, inline = true },
        { name = "📐 Size", value = string.format("%.1f×%.1f×%.1f", obj.Size.X, obj.Size.Y, obj.Size.Z), inline = true },
        { name = "✅ Size Verified", value = "Matches stinger (3×2×1.5)", inline = true },
        { name = "🧭 Position", value = string.format("(%.1f, %.1f, %.1f)", obj.Position.X, obj.Position.Y, obj.Position.Z), inline = false },
        { name = "🔢 Detection #", value = tostring(config.detectionCount), inline = true }
    }
    
    sendWebhook(
    "🎯 VICIOUS BEE STINGER DETECTED!",
    "🚨 A stinger was found!\n\n**🔗 [CLICK HERE TO JOIN THIS SERVER](" .. joinLink .. ")**\n\n**👥 Player Count Monitoring: ACTIVE (4 minutes)**",
    0xFF0000,
    webhookFields
    )

    -- Store connection to prevent duplicates
    if not config._stingerAncestryConnections then
        config._stingerAncestryConnections = {}
    end
    
    -- Don't create duplicate connections for same object
    if config._stingerAncestryConnections[obj] then
        return
    end

    local ancestryConn
    ancestryConn = obj.AncestryChanged:Connect(function()
        if not obj.Parent then
            -- IMMEDIATELY disconnect and remove from tracking
            if ancestryConn and ancestryConn.Connected then
                ancestryConn:Disconnect()
            end
            config._stingerAncestryConnections[obj] = nil
            
            -- 🔒 Per-object dedupe
            if config._detectedStingers[obj] == "defeated" then
                return
            end
    
            -- 🔒 Global dedupe
            if config._defeatReported then
                return
            end
    
            config._defeatReported = true
            config._detectedStingers[obj] = "defeated"
    
            config.stingerDetected = false

            local joinLink = generateJoinLink()
    
            local defeatedField = getActiveField()
    
            updateStingerLog(player.Name, defeatedField, "NOT ACTIVE", joinLink)
            
            -- Reset AFTER sending
            config.currentField = "None"
    
            sendWebhook(
                "🏆 Vicious Bee Defeated!",
                "The stinger at **"..defeatedField.."** has been removed from the workspace!\n\nStatus set to **NOT ACTIVE**",
                0x00FF00,
                {
                    { name = "🤖 Bot", value = player.Name, inline = true },
                    { name = "📍 Field", value = defeatedField, inline = true },
                    { name = "🔗 Join Link", value = joinLink, inline = false },
                    { name = "⏱️ Time", value = os.date("%X"), inline = true }
                }
            )
            config._defeatReported = false
    
            -- 🔹 Stop monitoring
            config._defeatCheckActive = false
            if config._monitoringActive then
                config._monitoringActive = false
                
                -- Disconnect PlayerAdded
                if config._playerMonitorConnection then
                    pcall(function() 
                        config._playerMonitorConnection:Disconnect() 
                    end)
                    config._playerMonitorConnection = nil
                end
                
                -- Disconnect PlayerRemoving
                if config._playerRemovingConnection then
                    pcall(function() 
                        config._playerRemovingConnection:Disconnect() 
                    end)
                    config._playerRemovingConnection = nil
                end
                
                -- Cancel 4-minute timer
                if config._activeStatusTimer then
                    pcall(function()
                        task.cancel(config._activeStatusTimer)
                    end)
                    config._activeStatusTimer = nil
                end    
            end
        end
    end)
    config._stingerAncestryConnections[obj] = ancestryConn
end

local TeleportService = game:GetService("TeleportService")

local function setupAutoReconnect()
    -- Store current server info
    local currentPlaceId = game.PlaceId
    local currentJobId = game.JobId
    
    -- Track if we're attempting to reconnect
    local isReconnecting = false
    
    local function attemptRejoin(reason)
        if isReconnecting then return end
        isReconnecting = true
        
        print(string.format("🔄 Reconnecting due to: %s", reason))
        
        sendWebhook(
            "🔄 Auto-Reconnect Triggered",
            string.format("**Reason:** %s\n\nAttempting to rejoin server...", reason),
            0xFFA500,
            {
                { name = "🤖 Bot", value = player.Name, inline = true },
                { name = "📍 Reason", value = reason, inline = true },
                { name = "🆔 Job ID", value = currentJobId:sub(1, 12) .. "...", inline = true }
            }
        )
        
        task.wait(2)
        
        -- Try to rejoin the same server
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(currentPlaceId, currentJobId, player)
        end)
        
        if not success then
            -- If rejoin fails, find a new low-pop server
            config._totalHopAttempts = 0
            task.wait(4)
              -- This will find a new server
        end
    end
    
    -- Handle teleport failures
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        local reason = "Teleport Init Failed"
        if teleportResult == Enum.TeleportResult.Failure then
            reason = "Teleport Failure: " .. tostring(errorMessage)
        elseif teleportResult == Enum.TeleportResult.GameNotFound then
            reason = "Game Not Found"
        elseif teleportResult == Enum.TeleportResult.GameEnded then
            reason = "Game Ended"
        elseif teleportResult == Enum.TeleportResult.GameFull then
            reason = "Server Full"
        elseif teleportResult == Enum.TeleportResult.Unauthorized then
            reason = "Unauthorized"
        elseif teleportResult == Enum.TeleportResult.Flooded then
            reason = "Flooded (Too Many Requests)"
        elseif teleportResult == Enum.TeleportResult.IsTeleporting then
            reason = "Already Teleporting"
        end
        
        warn(string.format("❌ %s - Attempting reconnect...", reason))
        attemptRejoin(reason)
    end)
    
    -- Handle network disconnections
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        local message = game:GetService("GuiService"):GetErrorMessage()
        if message and message ~= "" then
            -- Common disconnect messages
            if string.find(message:lower(), "disconnected") or
               string.find(message:lower(), "connection") or
               string.find(message:lower(), "internet") or
               string.find(message:lower(), "lost") or
               string.find(message:lower(), "kick") then
                
                warn(string.format("❌ Network Error: %s", message))
                attemptRejoin("Network Error: " .. message)
            end
        end
    end)
    
    -- Handle game shutdown
    game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(prompt)
        if prompt.Name == "ErrorPrompt" then
            local messageLabel = prompt:FindFirstChild("MessageArea")
            if messageLabel then
                local textLabel = messageLabel:FindFirstChild("ErrorFrame")
                if textLabel and textLabel:FindFirstChild("ErrorMessage") then
                    local errorText = textLabel.ErrorMessage.Text
                    if string.find(errorText:lower(), "shut") or
                       string.find(errorText:lower(), "disconnect") or
                       string.find(errorText:lower(), "error") then
                        
                        warn(string.format("❌ Server Error: %s", errorText))
                        attemptRejoin("Server Error: " .. errorText)
                    end
                end
            end
        end
    end)
    
    -- Backup: Monitor Players.LocalPlayer for removal
    local lastPlayerCheck = tick()
    RunService.Heartbeat:Connect(function()
        if tick() - lastPlayerCheck > 5 then  -- Check every 5 seconds
            lastPlayerCheck = tick()
            
            if not player or not player.Parent then
                warn("❌ Player removed from game")
                attemptRejoin("Player Removed From Game")
            end
        end
    end)
    
    print("✅ Auto-reconnect system enabled")
end

-- Start the reconnect system
task.delay(5, setupAutoReconnect)  -- Wait 5 seconds after script start

config.MAX_HOP_ATTEMPTS = 30
config._hopAttempts = config._hopAttempts or 0
config._totalHopAttempts = config._totalHopAttempts or 0

local hopping = false
local lastHopAttempt = 0

local function serverHopIfCrowded()
    local now = tick()
    
    -- CRITICAL: Only one hop at a time per bot
    if config._isCurrentlyHopping then
        print("⏳ Already hopping - skipping duplicate request")
        return
    end
    
    -- Prevent spam
    if hopping or (now - lastHopAttempt < 5) then
        return
    end
    
    config._isCurrentlyHopping = true
    
    local currentPlayers = getPlayerCount()
    
    if currentPlayers <= 3 then
        print(string.format("✅ Server OK: %d players", currentPlayers))
        config._isCurrentlyHopping = false
        return
    end
    
    lastHopAttempt = now
    hopping = true
    
    print(string.format("🔄 CROWDED (%d players) - Bot %d initiating hop...", currentPlayers, config._botID))
    
    task.spawn(function()
        -- ✅ STAGGERED START: Each bot waits its turn
        local myDelay = config._staggerDelay + math.random(0, 5)  -- Add 0-5s randomness
        print(string.format("⏳ Waiting %ds before scanning (Bot %d)...", myDelay, config._botID))
        task.wait(myDelay)
        
        local attempts = 0
        local maxAttempts = 20
        
        while attempts < maxAttempts do
            attempts = attempts + 1
            config._totalHopAttempts = config._totalHopAttempts + 1
            
            if config._totalHopAttempts >= config.MAX_HOP_ATTEMPTS then
                warn("🛑 Max hop attempts reached")
                config._isCurrentlyHopping = false
                hopping = false
                return
            end
            
            -- Recheck player count
            currentPlayers = getPlayerCount()
            if currentPlayers <= 3 then
                print("✅ Player count acceptable!")
                hopping = false
                config._isCurrentlyHopping = false
                return
            end
            
            print(string.format("🎯 Bot %d: Attempt %d/%d", config._botID, attempts, maxAttempts))
            
            -- ✅ BUILD OWN SERVER POOL
            local success, matchingServers = pcall(function()
                local placeId = game.PlaceId
                local myServers = {}
                
                -- ✅ Each bot scans different pages based on Bot ID
                local startPage = (config._botID % 5) + 1  -- Bot spreads across pages 1-5
                local cursor = ""
                local pagesScanned = 0
                local maxPages = 3  -- Each bot only scans 3 pages (faster)
                
                -- Skip to our starting page
                for skip = 1, startPage - 1 do
                    local skipUrl = string.format(
                        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100",
                        placeId
                    )
                    
                    local skipResp = request({Url = skipUrl, Method = "GET"})
                    if skipResp.StatusCode == 200 then
                        local skipData = HttpService:JSONDecode(skipResp.Body)
                        cursor = skipData.nextPageCursor or ""
                    end
                    task.wait(2.5)  -- Rate limit
                end
                
                -- Now scan OUR pages
                while pagesScanned < maxPages do
                    pagesScanned = pagesScanned + 1
                    
                    local url = string.format(
                        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100",
                        placeId
                    )
                    if cursor ~= "" then
                        url = url .. "&cursor=" .. cursor
                    end
                    
                    local response = request({Url = url, Method = "GET"})
                    
                    if response.StatusCode ~= 200 then
                        warn("❌ API error:", response.StatusCode)
                        break
                    end
                    
                    local data = HttpService:JSONDecode(response.Body)
                    
                    for _, server in ipairs(data.data) do
                        local playing = server.playing
                        local jobId = server.id
                        
                        if playing >= 1 and playing <= 2 and jobId ~= game.JobId then
                            table.insert(myServers, {jobId = jobId, players = playing})
                        end
                    end
                    
                    cursor = data.nextPageCursor or ""
                    if cursor == "" then break end
                    
                    task.wait(2.5)
                end
                
                return myServers
            end)
            
            if success and matchingServers and #matchingServers > 0 then
                -- ✅ Pick random from MY pool
                local randomServer = matchingServers[math.random(1, #matchingServers)]
                print(string.format("✅ Bot %d found %d servers, picked: %s (%d players)", 
                    config._botID, #matchingServers, randomServer.jobId:sub(1, 12), randomServer.players))
                
                sendWebhook(
                    "🔄 Server Hopping",
                    string.format("Bot %d hopping to server with **%d players**", config._botID, randomServer.players),
                    0xFFA500,
                    {
                        { name = "👥 Target Players", value = tostring(randomServer.players), inline = true },
                        { name = "🤖 Bot ID", value = tostring(config._botID), inline = true }
                    }
                )
                
                task.wait(2)
                
                -- ✅ SINGLE TELEPORT METHOD (most reliable)
                local tpSuccess = pcall(function()
                    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, randomServer.jobId)
                end)
                
                if tpSuccess then
                    print("✅ Teleport initiated!")
                    task.wait(20)  -- Wait for teleport
                    
                    -- If still here after 20s, try next
                    if player and player.Parent then
                        warn("⚠️ Teleport didn't work - trying next")
                        task.wait(3)
                    else
                        return  -- Success!
                    end
                else
                    warn("❌ Teleport failed")
                    task.wait(5)
                end
            else
                warn("❌ No servers found in my pool")
                task.wait(5)
            end
        end
        
        warn(string.format("⚠️ Bot %d exhausted attempts", config._botID))
        hopping = false
        config._isCurrentlyHopping = false
    end)
end

local function createGUI()
    if CoreGui:FindFirstChild("ViciousBeeHunterGUI") then
        CoreGui:FindFirstChild("ViciousBeeHunterGUI"):Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    local MainFrame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local CloseButton = Instance.new("TextButton")
    
    -- Control buttons
    local StartButton = Instance.new("TextButton")
    local ViewLogButton = Instance.new("TextButton")
    
    -- Server type buttons
    local PublicButton = Instance.new("TextButton")
    local PrivateButton = Instance.new("TextButton")
    local PrivateServerBox = Instance.new("TextBox")
    
    -- Info labels
    local StatusLabel = Instance.new("TextLabel")
    local FieldLabel = Instance.new("TextLabel")
    local PlayerCountLabel = Instance.new("TextLabel")
    local DetectionCountLabel = Instance.new("TextLabel")
    local PositionLabel = Instance.new("TextLabel")
    local AntiIdleLabel = Instance.new("TextLabel")
    local InfoLabel = Instance.new("TextLabel")
    
    ScreenGui.Name = "ViciousBeeHunterGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- COMPACT FRAME: 500 wide x 380 tall
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -190)
    MainFrame.Size = UDim2.new(0, 500, 0, 300)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
    
    -- Title bar
    Title.Parent = MainFrame
    Title.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐝 Vicious Bee Detector v3.8 Compact"
    Title.TextColor3 = Color3.fromRGB(20, 20, 20)
    Title.TextSize = 16
    
    Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)
    
    CloseButton.Parent = MainFrame
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)

    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    CloseButton.Position = UDim2.new(1, -32, 0, 8)
    CloseButton.Size = UDim2.new(0, 24, 0, 24)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 14
    
    Instance.new("UICorner", CloseButton)
    
    -- ROW 2: CONTROLS & INFO
    -- Left side: Start button (HIDDEN - Auto-start handles this)
    StartButton.Parent = MainFrame
    StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    StartButton.Position = UDim2.new(0, 10, 0, 50)
    StartButton.Size = UDim2.new(0.3, -10, 0, 38)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.Text = "START"
    StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartButton.TextSize = 14
    StartButton.Visible = false  -- ✅ HIDE THE BUTTON
    
    Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0, 8)
    
    -- Left: View Log (expanded to fill start button space)
    ViewLogButton.Parent = MainFrame
    ViewLogButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
    ViewLogButton.Position = UDim2.new(0, 10, 0, 50)
    ViewLogButton.Size = UDim2.new(0.63, -10, 0, 38)
    ViewLogButton.Font = Enum.Font.GothamBold
    ViewLogButton.Text = "📋 LOG"
    ViewLogButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ViewLogButton.TextSize = 13
    
    Instance.new("UICorner", ViewLogButton).CornerRadius = UDim.new(0, 8)
    
    -- Right side: Server type buttons stacked
    PublicButton.Parent = MainFrame
    PublicButton.BackgroundColor3 = config.serverType == "Public" and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(60, 60, 65)
    PublicButton.Position = UDim2.new(0.66, 5, 0, 50)
    PublicButton.Size = UDim2.new(0.34, -15, 0, 17)
    PublicButton.Font = Enum.Font.GothamBold
    PublicButton.Text = "🌐 Public"
    PublicButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PublicButton.TextSize = 11
    
    Instance.new("UICorner", PublicButton).CornerRadius = UDim.new(0, 6)
    
    PrivateButton.Parent = MainFrame
    PrivateButton.BackgroundColor3 = config.serverType == "Private" and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(60, 60, 65)
    PrivateButton.Position = UDim2.new(0.66, 5, 0, 71)
    PrivateButton.Size = UDim2.new(0.34, -15, 0, 17)
    PrivateButton.Font = Enum.Font.GothamBold
    PrivateButton.Text = "🔒 Private"
    PrivateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrivateButton.TextSize = 11
    
    Instance.new("UICorner", PrivateButton).CornerRadius = UDim.new(0, 6)
    
    -- Private server link box (below server buttons)
    PrivateServerBox.Parent = MainFrame
    PrivateServerBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    PrivateServerBox.Position = UDim2.new(0, 10, 0, 172)
    PrivateServerBox.Size = UDim2.new(1, -20, 0, 28)
    PrivateServerBox.Font = Enum.Font.Gotham
    PrivateServerBox.PlaceholderText = "Private Server Link..."
    PrivateServerBox.Text = config.privateServerLink
    PrivateServerBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrivateServerBox.TextSize = 11
    PrivateServerBox.ClearTextOnFocus = false
    PrivateServerBox.Visible = config.serverType == "Private"
    
    Instance.new("UICorner", PrivateServerBox).CornerRadius = UDim.new(0, 8)
    
    -- INFO SECTION (Compact 2-column grid layout)
    local infoStartY = 135
    
    StatusLabel.Parent = MainFrame
    StatusLabel.Name = "StatusLabel"
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 10, 0, infoStartY)
    StatusLabel.Size = UDim2.new(0.5, -10, 0, 18)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 11
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    PlayerCountLabel.Parent = MainFrame
    PlayerCountLabel.Name = "PlayerCountLabel"
    PlayerCountLabel.BackgroundTransparency = 1
    PlayerCountLabel.Position = UDim2.new(0.5, 0, 0, infoStartY)
    PlayerCountLabel.Size = UDim2.new(0.5, -10, 0, 18)
    PlayerCountLabel.Font = Enum.Font.Gotham
    PlayerCountLabel.Text = "👥 Players: " .. getPlayerCount()
    PlayerCountLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    PlayerCountLabel.TextSize = 11
    PlayerCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    FieldLabel.Parent = MainFrame
    FieldLabel.Name = "FieldLabel"
    FieldLabel.BackgroundTransparency = 1
    FieldLabel.Position = UDim2.new(0, 10, 0, infoStartY + 22)
    FieldLabel.Size = UDim2.new(0.5, -10, 0, 18)
    FieldLabel.Font = Enum.Font.Gotham
    FieldLabel.Text = "Field: Waiting..."
    FieldLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    FieldLabel.TextSize = 11
    FieldLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    DetectionCountLabel.Parent = MainFrame
    DetectionCountLabel.Name = "DetectionCountLabel"
    DetectionCountLabel.BackgroundTransparency = 1
    DetectionCountLabel.Position = UDim2.new(0.5, 0, 0, infoStartY + 22)
    DetectionCountLabel.Size = UDim2.new(0.5, -10, 0, 18)
    DetectionCountLabel.Font = Enum.Font.Gotham
    DetectionCountLabel.Text = "Detections: 0"
    DetectionCountLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    DetectionCountLabel.TextSize = 11
    DetectionCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    PositionLabel.Parent = MainFrame
    PositionLabel.Name = "PositionLabel"
    PositionLabel.BackgroundTransparency = 1
    PositionLabel.Position = UDim2.new(0, 10, 0, infoStartY + 44)
    PositionLabel.Size = UDim2.new(1, -20, 0, 18)
    PositionLabel.Font = Enum.Font.Gotham
    PositionLabel.Text = "Position: Waiting..."
    PositionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    PositionLabel.TextSize = 11
    PositionLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    AntiIdleLabel.Parent = MainFrame
    AntiIdleLabel.Name = "AntiIdleLabel"
    AntiIdleLabel.BackgroundTransparency = 1
    AntiIdleLabel.Position = UDim2.new(0, 10, 0, infoStartY + 66)
    AntiIdleLabel.Size = UDim2.new(0.5, -10, 0, 18)
    AntiIdleLabel.Font = Enum.Font.Gotham
    AntiIdleLabel.Text = "🔄 Anti-Idle: Active"
    AntiIdleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    AntiIdleLabel.TextSize = 11
    AntiIdleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    InfoLabel.Parent = MainFrame
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.Position = UDim2.new(0.5, 0, 0, infoStartY + 66)
    InfoLabel.Size = UDim2.new(0.5, -10, 0, 18)
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.Text = "🔐 Secured"
    InfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    InfoLabel.TextSize = 10
    InfoLabel.TextWrapped = true
    InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Config indicator at bottom
    local ConfigLabel = Instance.new("TextLabel")
    ConfigLabel.Parent = MainFrame
    ConfigLabel.BackgroundTransparency = 1
    ConfigLabel.Position = UDim2.new(0, 10, 0, infoStartY + 88)
    ConfigLabel.Size = UDim2.new(1, -20, 0, 15)
    ConfigLabel.Font = Enum.Font.Gotham
    ConfigLabel.Text = "⚙️ Hardcoded Config (Edit script to change webhook/secret)"
    ConfigLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    ConfigLabel.TextSize = 9
    ConfigLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Button handlers
    PublicButton.MouseButton1Click:Connect(function()
        config.serverType = "Public"
        PublicButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        PrivateButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        PrivateServerBox.Visible = false
        
        if writefile then
            writefile("vicious_bee_serverconfig.txt", HttpService:JSONEncode({
                serverType = config.serverType,
                privateServerLink = config.privateServerLink
            }))
        end
    end)
    
    PrivateButton.MouseButton1Click:Connect(function()
        config.serverType = "Private"
        PrivateButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        PublicButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        PrivateServerBox.Visible = true
        
        if writefile then
            writefile("vicious_bee_serverconfig.txt", HttpService:JSONEncode({
                serverType = config.serverType,
                privateServerLink = config.privateServerLink
            }))
        end
    end)
    
    PrivateServerBox.FocusLost:Connect(function()
        config.privateServerLink = PrivateServerBox.Text
        if writefile then
            writefile("vicious_bee_serverconfig.txt", HttpService:JSONEncode({
                serverType = config.serverType,
                privateServerLink = config.privateServerLink
            }))
        end
    end)
    
    StartButton.MouseButton1Click:Connect(function()
        if not config.isRunning then
            _G._AntiIdleRunning = true
            -- START
            config.isRunning = true
            StartButton.Text = "STOP"
            StartButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
            StatusLabel.Text = "Status: 🟢 Running"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    
            -- 🔧 CLEANUP OLD CONNECTIONS
            if config._descendantConnection then
                config._descendantConnection:Disconnect()
                config._descendantConnection = nil
            end
            
            -- Clear old property watchers
            if config._propertyConnections then
                for _, conn in pairs(config._propertyConnections) do
                    pcall(function() conn:Disconnect() end)
                end
            end
            config._propertyConnections = {}  -- ⚠️ THIS WAS MISSING!
            
            -- ✅ FIND PARTICLES FOLDER
            local particles = Workspace:FindFirstChild("Particles")
            if particles then
                -- Hook 1: Catch truly NEW Thorns being added
                config._descendantConnection = particles.DescendantAdded:Connect(function(obj)
                    onNewObject(obj)
                    
                    -- Also watch this new object for property changes
                    if obj:IsA("BasePart") and obj.Name == "Thorn" then
                        local sizeConn = obj:GetPropertyChangedSignal("Size"):Connect(function()
                            onNewObject(obj)
                        end)
                        table.insert(config._propertyConnections, sizeConn)
                    end
                end)
                
                -- Hook 2: Watch EXISTING Thorns for activation (size change)
                for _, obj in ipairs(particles:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name == "Thorn" then
                        -- Watch for size changes (activation signal)
                        local sizeConn = obj:GetPropertyChangedSignal("Size"):Connect(function()
                            onNewObject(obj)
                        end)
                        table.insert(config._propertyConnections, sizeConn)
                    end
                end
                
                print("✅ Monitoring " .. #config._propertyConnections .. " existing Thorns + new spawns")
            else
                warn("⚠️ Particles folder not found")
            end
            
            -- 🔔 SEND START WEBHOOK
            sendWebhook(
                "🚀 Detection Started",
                "Vicious Bee detection has been started.\n\nBot: **" .. player.Name .. "**",
                0x00BFFF,
                {
                    { name = "🤖 Bot", value = player.Name, inline = true },
                    { name = "🖥️ Server Type", value = config.serverType, inline = true },
                    { name = "📍 Status", value = "Running", inline = true }
                }
            )
        else
            -- STOP
            config.isRunning = false
            _G._AntiIdleRunning = false
            StartButton.Text = "START"
            StartButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            StatusLabel.Text = "Status: ⛔ Stopped"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            
            -- Disconnect DescendantAdded
            if config._descendantConnection then
                config._descendantConnection:Disconnect()
                config._descendantConnection = nil
            end
            
            -- 🔧 CLEANUP PROPERTY WATCHERS (THIS WAS MISSING!)
            if config._propertyConnections then
                for _, conn in pairs(config._propertyConnections) do
                    pcall(function() conn:Disconnect() end)
                end
                config._propertyConnections = {}
            end
            -- ✅ Cleanup ancestry watchers
            if config._stingerAncestryConnections then
                for obj, conn in pairs(config._stingerAncestryConnections) do
                    pcall(function() conn:Disconnect() end)
                end
                config._stingerAncestryConnections = {}
            end
        end
    end)
end
createGUI()

-- Wait for GUI to load
task.wait(1)
identifyAsBot()  -- ✅ MARK OURSELVES AS BOT

-- ✅ AUTO-START THE SCRIPT
config.isRunning = true
_G._AntiIdleRunning = true

-- Update GUI to show running status
local gui = CoreGui:FindFirstChild("ViciousBeeHunterGUI")
if gui then
    local mainFrame = gui:FindFirstChild("MainFrame")
    if mainFrame then
        local startBtn = mainFrame:FindFirstChild("StartButton")
        local statusLabel = mainFrame:FindFirstChild("StatusLabel")
        
        if startBtn then
            startBtn.Text = "STOP"
            startBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        end
        
        if statusLabel then
            statusLabel.Text = "Status: 🟢 Running"
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end
    end
end

-- Start monitoring particles
local particles = Workspace:FindFirstChild("Particles")
if particles then
    -- Hook new Thorns
    config._descendantConnection = particles.DescendantAdded:Connect(function(obj)
        onNewObject(obj)
        
        if obj:IsA("BasePart") and obj.Name == "Thorn" then
            local sizeConn = obj:GetPropertyChangedSignal("Size"):Connect(function()
                onNewObject(obj)
            end)
            table.insert(config._propertyConnections, sizeConn)
        end
    end)
    
    -- Hook existing Thorns
    for _, obj in ipairs(particles:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Thorn" then
            local sizeConn = obj:GetPropertyChangedSignal("Size"):Connect(function()
                onNewObject(obj)
            end)
            table.insert(config._propertyConnections, sizeConn)
        end
    end
else
    warn("⚠️ Particles folder not found")
end

-- Send start webhook
sendWebhook(
    "🚀 Detection Auto-Started",
    "Vicious Bee detection has been automatically started.\n\nBot: **" .. player.Name .. "**",
    0x00BFFF,
    {
        { name = "🤖 Bot", value = player.Name, inline = true },
        { name = "🖥️ Server Type", value = config.serverType, inline = true },
        { name = "📍 Status", value = "Auto-Running", inline = true }
    }
)

-- ✅ ONE-TIME STARTUP CHECK with BOT DETECTION
task.spawn(function()
    task.wait(5)  -- Initial delay for script to fully load
    
    print("🔍 Performing ONE-TIME startup server check...")
    
    -- ✅ FIRST: Check for other bots
    local botCount, botNames = detectOtherBots()
    
    if botCount > 0 then
        print(string.format("⚠️ FOUND %d OTHER BOT(S) IN SERVER!", botCount))
        for _, name in ipairs(botNames) do
            print(string.format("   🤖 Bot: %s", name))
        end
        
        serverHopDueToBot(botNames[1])  -- Hop immediately
        return  -- Don't check player count, just hop
    end
    
    -- ✅ No other bots, check player count
    local currentPlayers = getPlayerCount()
    
    if currentPlayers > 3 then
        print(string.format("⚠️ Server CROWDED on startup (%d players) - will hop ONCE", currentPlayers))
        serverHopIfCrowded()
    else
        print(string.format("✅ Server OK on startup (%d players) - STAYING HERE FOREVER", currentPlayers))
        print("📌 Bot will remain in this server until disconnected/error")
    end
    
    -- ✅ CONTINUOUS MONITORING: Check for new bots joining
    Players.PlayerAdded:Connect(function(newPlayer)
        task.wait(2)  -- Give them time to load marker
        
        if newPlayer:FindFirstChild("_VBBOT") then
            print(string.format("⚠️ NEW BOT JOINED: %s", newPlayer.Name))
            serverHopDueToBot(newPlayer.Name)
        end
    end)
end)
