-- 防止重复运行导致冲突
if _G.ESP_Loaded then
    _G.ESP_Loaded = false
    task.wait(0.5)
end
_G.ESP_Loaded = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==================== 1. UI 界面创建 ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CustomMobileESP_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- 兼容不同执行器的安全父级挂载
local success, err = pcall(function()
    ScreenGui.Parent = game:GetService("CoreGui")
end)
if not success then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- 主面板 (UI)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 180, 0, 110)
MainFrame.Position = UDim2.new(0.5, -90, 0.4, -55)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

-- UI 圆角
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- 标题栏
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Title.Text = "  MOBILE ESP"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.Parent = MainFrame

-- 功能开关按钮 (Toggle)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.85, 0, 0, 40)
ToggleBtn.Position = UDim2.new(0.075, 0, 0.45, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ToggleBtn.Text = "ESP: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
ToggleBtn.Font = Enum.Font.SourceSansBold
ToggleBtn.TextSize = 18
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleBtn

-- 独立的小型收起/展开按钮 (固定在屏幕边缘)
local MenuToggle = Instance.new("TextButton")
MenuToggle.Size = UDim2.new(0, 50, 0, 50)
MenuToggle.Position = UDim2.new(0, 10, 0.1, 0)
MenuToggle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MenuToggle.Text = "MENU"
MenuToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
MenuToggle.Font = Enum.Font.SourceSansBold
MenuToggle.TextSize = 14
MenuToggle.Visible = false
MenuToggle.Parent = ScreenGui

local MenuCorner = Instance.new("UICorner")
MenuCorner.CornerRadius = UDim.new(0, 25)
MenuCorner.Parent = MenuToggle

-- ==================== 2. 严格的单指拖动算法 (防瞬移) ====================
local dragToggle = false
local dragStart = nil
local startPos = nil
local activeTouchInput = nil -- 锁定当前负责拖动的那根手指

MainFrame.InputBegan:Connect(function(input)
    -- 仅允许 Touch(手机触屏) 或 MouseButton1(PC测试)，且当前没有其他手指在拖动
    if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and not dragToggle then
        dragToggle = true
        activeTouchInput = input -- 绑定当前触点
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragToggle = false
                activeTouchInput = nil
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    -- 只有当发生改变的触点是绑定的那根手指，才允许计算位移
    if input == activeTouchInput and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        if dragToggle then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end
end)

-- 隐藏/显示 UI 逻辑
local uiVisible = true
local function toggleUI()
    uiVisible = not uiVisible
    MainFrame.Visible = uiVisible
    MenuToggle.Visible = not uiVisible
end

-- 在主面板内双指点击标题，或者点击缩小的MENU按钮可以切换显隐
MenuToggle.MouseButton1Click:Connect(toggleUI)
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- 点击标题双击或者长按可隐藏界面（手机端防误触隐藏）
        if input.Position.Z > 1 then toggleUI() end 
    end
end)

-- ==================== 3. 实时全局扫描透视系统 ====================
local espEnabled = false
local espObjects = {}

-- 创建单个玩家的透视框 (Highlight 完美渲染)
local function createESP(player)
    if player == LocalPlayer then return end
    if espObjects[player] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight_" .. player.Name
    highlight.FillTransparency = 0.5 -- 填充半透明
    highlight.OutlineTransparency = 0 -- 描边完全不透明
    
    -- 初始状态：未开启时隐藏，或者根据需求未激活显示为默认绿色
    highlight.FillColor = Color3.fromRGB(0, 255, 0)
    highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
    highlight.Enabled = false
    
    espObjects[player] = highlight

    -- 绑定角色刷新事件
    local function applyToCharacter(char)
        if char then
            highlight.Adornee = char
            highlight.Parent = char
        end
    end

    if player.Character then applyToCharacter(player.Character) end
    player.CharacterAdded:Connect(applyToCharacter)
end

-- 移除单个玩家的透视框
local function removeESP(player)
    if espObjects[player] then
        pcall(function() espObjects[player]:Destroy() end)
        espObjects[player] = nil
    end
end

-- 全局实时刷新与死人/退出检测
RunService.RenderStepped:Connect(function()
    if not _G.ESP_Loaded then return end

    -- 遍历当前服务器所有玩家进行【全局扫描】
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- 1. 如果是新加入的敌人，立刻捕获并创建
            if not espObjects[player] then
                createESP(player)
            end
            
            local hl = espObjects[player]
            local char = player.Character
            
            -- 2. 状态判断：死人、不在地图中
            if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") and char.Humanoid.Health > 0 then
                if espEnabled then
                    hl.Enabled = true
                    hl.FillColor = Color3.fromRGB(255, 0, 0)    -- 激活透视：红色
                    hl.OutlineColor = Color3.fromRGB(255, 0, 0) -- 激活透视：红色
                else
                    hl.Enabled = true
                    hl.FillColor = Color3.fromRGB(0, 255, 0)    -- 未开启功能：绿色
                    hl.OutlineColor = Color3.fromRGB(0, 255, 0) -- 未开启功能：绿色
                end
            else
                -- 3. 角色死亡：对应的 ESP 立即隐藏/消失
                if hl then hl.Enabled = false end
            end
        end
    end

    -- 4. 退出检测：清理已经离开游戏的玩家残留
    for player, _ in pairs(espObjects) do
        if not Players:FindFirstChild(player.Name) then
            removeESP(player)
        end
    end
end)

-- 监听新玩家加入游戏 (确保100%全天候扫描)
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

-- 按钮事件：开启/关闭透视状态
ToggleBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        ToggleBtn.Text = "ESP: ON"
        ToggleBtn.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        ToggleBtn.Text = "ESP: OFF"
        ToggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

-- 首次载入初始化现有人群
for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
