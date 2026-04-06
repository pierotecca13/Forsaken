-- Combate.client.luau
-- Barra de vida, efecto de swing, pantalla de muerte con opciones de revivir.
-- El daño real lo calcula el servidor; este script maneja solo input y UI.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArmasConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Ocultar barra de vida nativa de Roblox (usamos la nuestra)
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

local carpetaEventos  = ReplicatedStorage:WaitForChild("Eventos")
local evAtacarMelee   = carpetaEventos:WaitForChild("AtacarMelee")
local evReintentar    = carpetaEventos:WaitForChild("Reintentar")
local evRevivireAqui  = carpetaEventos:WaitForChild("RevivireAqui")
local evGemas         = carpetaEventos:WaitForChild("GemasActualizadas")

-- Saldo de gemas local (se actualiza con cada evento GemasActualizadas)
local gemasLocales = 0

-- ============================================================
-- UI: Barra de vida (esquina superior izquierda)
-- ============================================================
local guiVida = Instance.new("ScreenGui")
guiVida.Name          = "VidaUI"
guiVida.ResetOnSpawn  = false
guiVida.Parent        = playerGui

local marcoVida = Instance.new("Frame")
marcoVida.Size                   = UDim2.new(0, 210, 0, 36)
marcoVida.Position               = UDim2.new(0, 12, 0, 12)
marcoVida.BackgroundColor3       = Color3.fromRGB(12, 12, 18)
marcoVida.BackgroundTransparency = 0.3
marcoVida.BorderSizePixel        = 0
marcoVida.Parent                 = guiVida

local cornerVida = Instance.new("UICorner")
cornerVida.CornerRadius = UDim.new(0, 8)
cornerVida.Parent       = marcoVida

-- Etiqueta "HP"
local lblHP = Instance.new("TextLabel")
lblHP.Size               = UDim2.new(0, 28, 1, 0)
lblHP.Position           = UDim2.new(0, 7, 0, 0)
lblHP.BackgroundTransparency = 1
lblHP.Text               = "HP"
lblHP.Font               = Enum.Font.GothamBold
lblHP.TextScaled         = true
lblHP.TextColor3         = Color3.fromRGB(255, 75, 75)
lblHP.TextXAlignment     = Enum.TextXAlignment.Left
lblHP.Parent             = marcoVida

-- Fondo gris oscuro de la barra
local barraFondo = Instance.new("Frame")
barraFondo.Size             = UDim2.new(0, 125, 0, 10)
barraFondo.Position         = UDim2.new(0, 40, 0.5, -5)
barraFondo.BackgroundColor3 = Color3.fromRGB(40, 15, 15)
barraFondo.BorderSizePixel  = 0
barraFondo.Parent           = marcoVida

local cornerBarraF = Instance.new("UICorner")
cornerBarraF.CornerRadius = UDim.new(1, 0)
cornerBarraF.Parent       = barraFondo

-- Relleno rojo de la barra
local barraRelleno = Instance.new("Frame")
barraRelleno.Name             = "Relleno"
barraRelleno.Size             = UDim2.new(1, 0, 1, 0)
barraRelleno.BackgroundColor3 = Color3.fromRGB(60, 210, 60)
barraRelleno.BorderSizePixel  = 0
barraRelleno.Parent           = barraFondo

local cornerBarraR = Instance.new("UICorner")
cornerBarraR.CornerRadius = UDim.new(1, 0)
cornerBarraR.Parent       = barraRelleno

-- Número de vida (ej.: "85")
local lblNumVida = Instance.new("TextLabel")
lblNumVida.Size               = UDim2.new(0, 38, 1, 0)
lblNumVida.Position           = UDim2.new(0, 168, 0, 0)
lblNumVida.BackgroundTransparency = 1
lblNumVida.Text               = "100"
lblNumVida.Font               = Enum.Font.GothamBold
lblNumVida.TextScaled         = true
lblNumVida.TextColor3         = Color3.fromRGB(255, 255, 255)
lblNumVida.TextXAlignment     = Enum.TextXAlignment.Left
lblNumVida.Parent             = marcoVida

-- ============================================================
-- UI: Pantalla de muerte (oculta por defecto)
-- ============================================================
local guiMuerte = Instance.new("ScreenGui")
guiMuerte.Name          = "MuerteUI"
guiMuerte.ResetOnSpawn  = false
guiMuerte.DisplayOrder  = 20   -- por encima del resto de UIs
guiMuerte.Parent        = playerGui

-- Overlay semitransparente
local overlay = Instance.new("Frame")
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel        = 0
overlay.Visible                = false
overlay.Parent                 = guiMuerte

-- Panel central (ampliado para dos botones)
local panel = Instance.new("Frame")
panel.Size                   = UDim2.new(0, 340, 0, 245)
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3       = Color3.fromRGB(22, 8, 8)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = guiMuerte

local cornerPanel = Instance.new("UICorner")
cornerPanel.CornerRadius = UDim.new(0, 14)
cornerPanel.Parent       = panel

local strokePanel = Instance.new("UIStroke")
strokePanel.Color     = Color3.fromRGB(180, 30, 30)
strokePanel.Thickness = 2
strokePanel.Parent    = panel

-- Texto principal "HAS MUERTO"
local lblMuerte = Instance.new("TextLabel")
lblMuerte.Size               = UDim2.new(1, 0, 0, 55)
lblMuerte.Position           = UDim2.new(0, 0, 0, 22)
lblMuerte.BackgroundTransparency = 1
lblMuerte.Text               = "HAS MUERTO"
lblMuerte.Font               = Enum.Font.GothamBold
lblMuerte.TextScaled         = true
lblMuerte.TextColor3         = Color3.fromRGB(220, 45, 45)
lblMuerte.TextXAlignment     = Enum.TextXAlignment.Center
lblMuerte.Parent             = panel

-- Botón Revivir aquí (verde si tiene gemas, gris si no)
local btnRevivir = Instance.new("TextButton")
btnRevivir.Size             = UDim2.new(0, 300, 0, 52)
btnRevivir.AnchorPoint      = Vector2.new(0.5, 0)
btnRevivir.Position         = UDim2.new(0.5, 0, 0, 90)
btnRevivir.BackgroundColor3 = Color3.fromRGB(35, 130, 55)
btnRevivir.Text             = "Revivir aquí  (150 ◆)"
btnRevivir.Font             = Enum.Font.GothamBold
btnRevivir.TextScaled       = true
btnRevivir.TextColor3       = Color3.fromRGB(255, 255, 255)
btnRevivir.AutoButtonColor  = false
btnRevivir.Parent           = panel

local cornerRevivir = Instance.new("UICorner")
cornerRevivir.CornerRadius = UDim.new(0, 8)
cornerRevivir.Parent       = btnRevivir

-- Botón Volver al Lobby (rojo, siempre disponible)
local btnReintentar = Instance.new("TextButton")
btnReintentar.Size             = UDim2.new(0, 300, 0, 42)
btnReintentar.AnchorPoint      = Vector2.new(0.5, 0)
btnReintentar.Position         = UDim2.new(0.5, 0, 0, 157)
btnReintentar.BackgroundColor3 = Color3.fromRGB(160, 35, 35)
btnReintentar.Text             = "Volver al Lobby"
btnReintentar.Font             = Enum.Font.GothamBold
btnReintentar.TextScaled       = true
btnReintentar.TextColor3       = Color3.fromRGB(255, 255, 255)
btnReintentar.AutoButtonColor  = false
btnReintentar.Parent           = panel

local cornerBtn = Instance.new("UICorner")
cornerBtn.CornerRadius = UDim.new(0, 8)
cornerBtn.Parent       = btnReintentar

-- ============================================================
-- Funciones de UI
-- ============================================================

local function actualizarBarraVida(vida, maxVida)
	local pct = math.clamp(vida / maxVida, 0, 1)

	-- Tween suave de la barra
	TweenService:Create(
		barraRelleno,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad),
		{ Size = UDim2.new(pct, 0, 1, 0) }
	):Play()

	-- Color dinámico: verde → amarillo → rojo
	if pct > 0.6 then
		barraRelleno.BackgroundColor3 = Color3.fromRGB(60, 210, 60)
	elseif pct > 0.3 then
		barraRelleno.BackgroundColor3 = Color3.fromRGB(220, 180, 30)
	else
		barraRelleno.BackgroundColor3 = Color3.fromRGB(210, 45, 45)
	end

	lblNumVida.Text = tostring(math.ceil(vida))
end

-- Actualiza el aspecto del botón Revivir según el saldo de gemas actual
local function actualizarBotonRevivir()
	if gemasLocales >= 150 then
		btnRevivir.BackgroundColor3 = Color3.fromRGB(35, 130, 55)
		btnRevivir.Text             = "Revivir aquí  (150 ◆)"
		btnRevivir.Active           = true
	else
		btnRevivir.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		btnRevivir.Text             = "Gemas insuficientes"
		btnRevivir.Active           = false
	end
end

-- Efecto visual de swing: el palo de madera barre un arco desde la mano derecha
local function efectoSwing(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local rango    = Config.RANGO_ATAQUE
	-- Pivote en la posición de la mano derecha del personaje
	local pivotCF  = hrp.CFrame * CFrame.new(1.2, 0, 0)

	-- Cuerpo del palo (madera, mismo color que el arma del config)
	local palo = Instance.new("Part")
	palo.Size         = Vector3.new(0.28, 0.28, rango * 0.85)
	palo.Anchored     = true
	palo.CanCollide   = false
	palo.CastShadow   = false
	palo.Material     = Enum.Material.Wood
	palo.Color        = Color3.fromRGB(139, 90, 43)
	palo.Transparency = 0
	palo.CFrame       = pivotCF * CFrame.Angles(0, math.rad(-60), 0)
	                    * CFrame.new(0, 0, -(rango * 0.425))
	palo.Parent       = workspace

	-- Flash pequeño en la punta al impactar
	local punta = Instance.new("Part")
	punta.Shape        = Enum.PartType.Ball
	punta.Size         = Vector3.new(0.55, 0.55, 0.55)
	punta.Anchored     = true
	punta.CanCollide   = false
	punta.CastShadow   = false
	punta.Material     = Enum.Material.Neon
	punta.Color        = Color3.fromRGB(255, 230, 140)
	punta.Transparency = 0.35
	punta.CFrame       = pivotCF * CFrame.Angles(0, math.rad(-60), 0)
	                     * CFrame.new(0, 0, -(rango * 0.85))
	punta.Parent       = workspace

	-- Swing de derecha (-60°) a izquierda (+40°)
	TweenService:Create(palo, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		CFrame       = pivotCF * CFrame.Angles(0, math.rad(40), 0) * CFrame.new(0, 0, -(rango * 0.425)),
		Transparency = 0.55,
	}):Play()

	TweenService:Create(punta, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		CFrame       = pivotCF * CFrame.Angles(0, math.rad(40), 0) * CFrame.new(0, 0, -(rango * 0.85)),
		Transparency = 1,
		Size         = Vector3.new(1.4, 1.4, 1.4),
	}):Play()

	game:GetService("Debris"):AddItem(palo,  0.22)
	game:GetService("Debris"):AddItem(punta, 0.22)
end

-- ============================================================
-- Conectar Tool.Activated cuando el jugador equipa un arma
-- ============================================================
local ultimoAtaque = 0  -- cooldown local para feedback inmediato

local function conectarHerramienta(tool)
	if not tool:IsA("Tool") then return end

	tool.Activated:Connect(function()
		local character = player.Character
		if not character then return end

		-- Cooldown local (mismo valor que el servidor para respuesta inmediata)
		local infoArma = Config.ARMAS[tool.Name]
		local cooldown = infoArma and infoArma.cooldown or 1.0
		local ahora    = tick()
		if ahora - ultimoAtaque < cooldown then return end
		ultimoAtaque = ahora

		-- Efecto visual inmediato
		efectoSwing(character)

		-- Enviar al servidor para validación y daño real
		evAtacarMelee:FireServer()
	end)
end

-- ============================================================
-- Configurar combate para el personaje actual (y en respawns)
-- ============================================================
local function configurarCombate(character)
	local humanoid = character:WaitForChild("Humanoid")

	-- Inicializar barra de vida
	actualizarBarraVida(humanoid.Health, humanoid.MaxHealth)

	-- Actualizar barra cuando la vida cambia
	humanoid.HealthChanged:Connect(function(vida)
		actualizarBarraVida(vida, humanoid.MaxHealth)
	end)

	-- Mostrar pantalla de muerte al morir
	humanoid.Died:Connect(function()
		actualizarBotonRevivir()   -- estado del botón según gemas actuales
		overlay.Visible = true
		panel.Visible   = true
	end)

	-- Ocultar pantalla de muerte (en respawns)
	overlay.Visible = false
	panel.Visible   = false

	-- Conectar armas que ya estén en el personaje
	for _, child in ipairs(character:GetChildren()) do
		conectarHerramienta(child)
	end

	-- Conectar armas que se añadan después (equip / cambio de arma)
	character.ChildAdded:Connect(conectarHerramienta)
end

player.CharacterAdded:Connect(configurarCombate)
if player.Character then
	configurarCombate(player.Character)
end

-- ============================================================
-- Sincronizar saldo de gemas para activar/desactivar Revivir
-- ============================================================
evGemas.OnClientEvent:Connect(function(cantidad)
	gemasLocales = cantidad
end)

-- ============================================================
-- Botón Revivir aquí
-- ============================================================
btnRevivir.MouseButton1Click:Connect(function()
	if not btnRevivir.Active then return end
	btnRevivir.Active = false
	btnRevivir.Text   = "Reviviendo..."
	evRevivireAqui:FireServer()
end)

-- ============================================================
-- Botón Volver al Lobby (respawnea en campamento por ahora)
-- TODO: cuando exista el lobby, cambiar FireServer() por TeleportService
-- ============================================================
btnReintentar.MouseButton1Click:Connect(function()
	if not btnReintentar.Active then return end
	btnReintentar.Active = false
	btnReintentar.Text   = "Cargando..."
	evReintentar:FireServer()
end)

-- Reactivar ambos botones cuando el nuevo personaje aparece
player.CharacterAdded:Connect(function()
	btnReintentar.Active = true
	btnReintentar.Text   = "Volver al Lobby"
	btnRevivir.Active    = true
	actualizarBotonRevivir()
end)

print("[Combate] Cliente de combate activo.")
