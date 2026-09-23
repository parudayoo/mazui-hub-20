
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ▼ 設定項目 ▼
local TARGET_KEY = Enum.KeyCode.T -- 手動移動用キー
local TWEEN_TIME = 3 -- 移動にかかる時間（秒）
local OFFSET_Z = -8 -- Reachパーツの「ちょっと奥」の距離
local OFFSET_Y = 3 -- 地面へのめり込みを防ぐための高さ
local SPAM_DURATION = 0.3 -- Eキーを連打する時間（秒）
-- ▲ 設定項目 ▲

-- =========================================
-- 1. UIの作成 (20th quest Auto ボタン)
-- =========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Quest20thAutoGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 50)
frame.Position = UDim2.new(0.5, -100, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = frame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, 0, 1, 0)
toggleButton.BackgroundTransparency = 1
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Text = "20th quest Auto: OFF"
toggleButton.TextColor3 = Color3.fromRGB(255, 100, 100)
toggleButton.TextSize = 18
toggleButton.Parent = frame

-- =========================================
-- 2. 共通の関数群
-- =========================================
local autoFarming = false
local loopCoroutine = nil

-- Tween移動を行い、完了まで待機する関数
local function tweenMoveTo(targetCFrame, duration)
    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait() -- 移動完了まで待機
    return true
end

-- Eキーを指定秒数連打する関数
local function spamEKeyForDuration(duration)
    local startTime = tick()
    while tick() - startTime < duration do
        if not autoFarming then break end -- ループがOFFになったら即座に停止
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        task.wait(0.05)
    end
end

-- Reachのちょっと奥のCFrameを取得する関数
local function getReachTargetCFrame()
    local reachPart = workspace:FindFirstChild("20thEvent")
        and workspace["20thEvent"]:FindFirstChild("TreeIsland")
        and workspace["20thEvent"]["TreeIsland"]:FindFirstChild("Reach")
    
    if reachPart then
        return reachPart.CFrame * CFrame.new(0, OFFSET_Y, OFFSET_Z)
    end
    return nil
end

-- =========================================
-- 3. オートループのロジック
-- =========================================
local function startAutoLoop()
    while autoFarming do
        local eventFolder = workspace:FindFirstChild("20thEvent")
        if not eventFolder then task.wait(1) continue end
        
        local owlIsland = eventFolder:FindFirstChild("OwlIsland")
        if not owlIsland then task.wait(1) continue end
        
        local plantsFolder = owlIsland:FindFirstChild("Plants")
        if not plantsFolder then task.wait(1) continue end
        
        local plants = plantsFolder:GetChildren()
        if #plants == 0 then task.wait(1) continue end
        
        -- 植物モデルを調べ、Fruitsフォルダ内の「親モデルと同名」のオブジェクト数をカウント
        local plantDataList = {}
        for _, plantModel in ipairs(plants) do
            if plantModel:IsA("Model") then
                local fruitsFolder = plantModel:FindFirstChild("Fruits")
                local matchCount = 0
                
                if fruitsFolder then
                    for _, fruit in ipairs(fruitsFolder:GetChildren()) do
                        if fruit.Name == plantModel.Name then
                            matchCount = matchCount + 1
                        end
                    end
                end
                
                table.insert(plantDataList, {
                    model = plantModel,
                    count = matchCount
                })
            end
        end
        
        -- 「親モデルと一緒の名前が多い順（降順）」にソート
        table.sort(plantDataList, function(a, b)
            return a.count > b.count
        end)
        
        -- ソートされた順番に処理を実行
        for _, plantData in ipairs(plantDataList) do
            if not autoFarming then break end
            
            -- 対象となる実がないモデルはスキップする場合
            if plantData.count == 0 then continue end
            
            local plantModel = plantData.model
            local plantPart = plantModel.PrimaryPart or plantModel:FindFirstChildWhichIsA("BasePart")
            
            if plantPart then
                -- ① 植物に高速移動
                local plantCFrame = plantPart.CFrame * CFrame.new(0, OFFSET_Y, 0)
                local movedToPlant = tweenMoveTo(plantCFrame, TWEEN_TIME)
                
                if movedToPlant and autoFarming then
                    -- ② Eキーを連打する
                    spamEKeyForDuration(SPAM_DURATION)
                    
                    -- ループがOFFにされていたら中止
                    if not autoFarming then break end
                    
                    -- ③ Reachのちょっと奥へ高速移動
                    local reachCFrame = getReachTargetCFrame()
                    if reachCFrame then
                        tweenMoveTo(reachCFrame, TWEEN_TIME)
                    end
                end
            end
            
            task.wait(0.5) -- 次のターゲットへ行く前の少しのインターバル
        end
        
        task.wait(0.5) -- 全ターゲットを巡回し終えた後のインターバル
    end
end

-- =========================================
-- 4. イベントの接続
-- =========================================

-- UIボタンのクリックイベント
toggleButton.MouseButton1Click:Connect(function()
    autoFarming = not autoFarming
    if autoFarming then
        toggleButton.Text = "20th quest Auto: ON"
        toggleButton.TextColor3 = Color3.fromRGB(100, 255, 100)
        loopCoroutine = task.spawn(startAutoLoop)
    else
        toggleButton.Text = "20th quest Auto: OFF"
        toggleButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        if loopCoroutine then
            task.cancel(loopCoroutine)
            loopCoroutine = nil
        end
        -- 念のためEキーを強制的に離す
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end
end)

-- Tキーによる単発のReach移動（既存機能）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == TARGET_KEY then
        local targetCFrame = getReachTargetCFrame()
        if targetCFrame then
            local character = player.Character
            if not character then return end
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                -- 手動移動時は他の処理を止めないよう、待機(Wait)させずにPlayだけ実行
                local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})
                tween:Play()
            end
        else
            warn("Reachパーツが見つかりません")
        end
    end
end)
