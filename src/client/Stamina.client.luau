-- Stamina.client.luau
-- Gestiona la stamina del jugador local:
--   · Shift (PC) / botón SPRINT (móvil) para correr
--   · Barra de stamina en pantalla
--   · Integración con el ciclo día/noche ya existente
--   · Expone un NumberValue en el Character para que otros scripts lo lean

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StaminaConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Estado global de stamina
-- (accesible desde otros scripts vía character:FindFirstChild("Stamina"))
-- ============================================================
local stamina       = Config.MAXIMO
local puedeSprintar = true   -- false cuando se agota; vuelve a true al pasar UMBRAL
local sprintActivo  = false  -- true mientras el jugador mantiene el botón
local esNoche       = false  -- se actualiza con los RemoteEvents del ciclo

-- Referencias al personaje actual (se actualizan en cada respawn)
local humanoidActual    = nil
local staminaValueActual = nil  -- NumberValue dentro del Character

-- ============================================================
-- Eventos de día/noche (ya creados por DayNightCycle)
-- ============================================================
local carpetaEventos = ReplicatedStorage:WaitForChild("Eventos")
carpetaEventos:WaitForChild("NocheComenzo").OnClientEvent:Connect(function()
	esNoche = true
end)
carpetaEventos:WaitForChild("DiaComenzo").OnClientEvent:Connect(function()
	esNoche = false
end)

-- ============================================================
-- Construir la UI de la barra de stamina (una sola vez)
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "StaminaUI"
screenGui.ResetOnSpawn = false
screenGui.Parent       = playerGui

-- Marco exterior (fondo oscuro, centrado en la parte inferior)
local marco = Instance.new("Frame")
marco.Name                   = "MarcoStamina"
marco.Size                   = UDim2.new(0, 210, 0, 36)
marco.AnchorPoint            = Vector2.new(0, 0)
marco.Position               = UDim2.new(0, 12, 0, 56)   -- debajo del HP bar
marco.BackgroundColor3       = Color3.fromRGB(12, 12, 18)
marco.BackgroundTransparency = 0.3
marco.BorderSizePixel        = 0
marco.Parent                 = screenGui

local cornerMarco = Instance.new("UICorner")
cornerMarco.CornerRadius = UDim.new(0, 8)
cornerMarco.Parent       = marco

-- Etiqueta "STAMINA" a la izquierda
local lblTitulo = Instance.new("TextLabel")
lblTitulo.Size               = UDim2.new(0, 28, 1, 0)
lblTitulo.BackgroundTransparency = 1
lblTitulo.Text               = "ST"
lblTitulo.Font               = Enum.Font.GothamBold
lblTitulo.TextScaled         = true
lblTitulo.TextColor3         = Color3.fromRGB(80, 160, 255)
lblTitulo.TextXAlignment     = Enum.TextXAlignment.Left
lblTitulo.Position           = UDim2.new(0, 7, 0, 0)
lblTitulo.Parent             = marco

-- Fondo de la barra
local barraFondo = Instance.new("Frame")
barraFondo.Name              = "BarraFondo"
barraFondo.Size              = UDim2.new(0, 125, 0, 10)
barraFondo.Position          = UDim2.new(0, 40, 0.5, -5)
barraFondo.BackgroundColor3  = Color3.fromRGB(35, 35, 50)
barraFondo.BorderSizePixel   = 0
barraFondo.Parent            = marco

local cornerFondo = Instance.new("UICorner")
cornerFondo.CornerRadius = UDim.new(1, 0)
cornerFondo.Parent       = barraFondo

-- Relleno de la barra (el que cambia de tamaño y color)
local barraRelleno = Instance.new("Frame")
barraRelleno.Name             = "Relleno"
barraRelleno.Size             = UDim2.new(1, 0, 1, 0)
barraRelleno.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
barraRelleno.BorderSizePixel  = 0
barraRelleno.Parent           = barraFondo

local cornerRelleno = Instance.new("UICorner")
cornerRelleno.CornerRadius = UDim.new(1, 0)
cornerRelleno.Parent       = barraRelleno

-- Número de stamina a la derecha
local lblNumero = Instance.new("TextLabel")
lblNumero.Name               = "Numero"
lblNumero.Size               = UDim2.new(0, 38, 1, 0)
lblNumero.Position           = UDim2.new(0, 168, 0, 0)
lblNumero.BackgroundTransparency = 1
lblNumero.Text               = "100"
lblNumero.Font               = Enum.Font.GothamBold
lblNumero.TextScaled         = true
lblNumero.TextColor3         = Color3.fromRGB(255, 255, 255)
lblNumero.TextXAlignment     = Enum.TextXAlignment.Right
lblNumero.Parent             = marco

-- Texto "AGOTADO" que aparece cuando el jugador se queda sin stamina
local lblAgotado = Instance.new("TextLabel")
lblAgotado.Name               = "Agotado"
lblAgotado.Size               = UDim2.new(1, 0, 1, 0)
lblAgotado.BackgroundTransparency = 1
lblAgotado.Text               = "AGOTADO"
lblAgotado.Font               = Enum.Font.GothamBold
lblAgotado.TextScaled         = true
lblAgotado.TextColor3         = Color3.fromRGB(255, 60, 60)
lblAgotado.TextXAlignment     = Enum.TextXAlignment.Center
lblAgotado.Visible            = false
lblAgotado.Parent             = marco

-- ============================================================
-- Actualizar la UI según el valor actual de stamina
-- ============================================================
local function actualizarBarraUI()
	local pct = stamina / Config.MAXIMO  -- 0.0 a 1.0

	-- Tamaño del relleno
	barraRelleno.Size = UDim2.new(math.max(pct, 0), 0, 1, 0)

	-- Color: verde > amarillo > rojo
	if pct > 0.5 then
		barraRelleno.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
	elseif pct > 0.2 then
		barraRelleno.BackgroundColor3 = Color3.fromRGB(220, 180, 30)
	else
		barraRelleno.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
	end

	-- Número
	lblNumero.Text = tostring(math.ceil(stamina))

	-- Mostrar "AGOTADO" solo si el jugador está bloqueado
	lblAgotado.Visible = (not puedeSprintar)
end

-- ============================================================
-- Configurar el personaje (inicial y en cada respawn)
-- ============================================================
local function configurarPersonaje(character)
	humanoidActual = character:WaitForChild("Humanoid")

	-- NumberValue accesible por otros scripts (ej.: combate)
	local sv = character:FindFirstChild("Stamina")
	if not sv then
		sv = Instance.new("NumberValue")
		sv.Name   = "Stamina"
		sv.Value  = Config.MAXIMO
		sv.Parent = character
	end
	staminaValueActual = sv

	-- Reiniciar estado al respawnear
	stamina       = Config.MAXIMO
	puedeSprintar = true
	humanoidActual.WalkSpeed = Config.VELOCIDAD_NORMAL

	actualizarBarraUI()
	print("[Stamina] Personaje configurado.")
end

-- Primera carga y respawns futuros
player.CharacterAdded:Connect(configurarPersonaje)
if player.Character then
	configurarPersonaje(player.Character)
end

-- ============================================================
-- Input: Shift en PC + botón táctil automático en móvil
-- ContextActionService crea el botón de sprint en móvil
-- ============================================================
local function manejarSprint(_, inputState, _)
	if inputState == Enum.UserInputState.Begin then
		sprintActivo = true
	elseif inputState == Enum.UserInputState.End
		or inputState == Enum.UserInputState.Cancel then
		sprintActivo = false
	end
	return Enum.ContextActionResult.Pass  -- no bloquear otros inputs
end

ContextActionService:BindAction(
	"ForsakenSprint",
	manejarSprint,
	true,                      -- true = crear botón táctil en móvil
	Enum.KeyCode.LeftShift
)
-- Posicionar el botón táctil en la esquina inferior derecha
ContextActionService:SetPosition("ForsakenSprint", UDim2.new(1, -80, 1, -80))
ContextActionService:SetTitle("ForsakenSprint", "SPRINT")

-- ============================================================
-- Loop principal: actualizar stamina y velocidad cada frame
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	-- Sin personaje activo: saltar
	if not humanoidActual
		or not humanoidActual.Parent
		or humanoidActual.Health <= 0 then
		return
	end

	-- ¿El jugador está intentando correr Y moviéndose?
	local intentandoCorrer = sprintActivo
		and (humanoidActual.MoveDirection.Magnitude > 0.1)
		and puedeSprintar

	if intentandoCorrer then
		-- Consumir stamina
		stamina = math.max(0, stamina - Config.CONSUMO_SPRINT * dt)
		humanoidActual.WalkSpeed = Config.VELOCIDAD_SPRINT

		-- Si se agota, bloquear el sprint
		if stamina == 0 then
			puedeSprintar = false
			sprintActivo  = false
		end
	else
		-- Recuperar stamina (más lento de noche)
		local multNoche = esNoche and Config.MULT_RECUPERACION_NOCHE or 1
		stamina = math.min(
			Config.MAXIMO,
			stamina + Config.RECUPERACION_BASE * multNoche * dt
		)
		humanoidActual.WalkSpeed = Config.VELOCIDAD_NORMAL

		-- Desbloquear sprint cuando supera el umbral de recuperación
		if not puedeSprintar and stamina >= Config.UMBRAL_RECUPERACION then
			puedeSprintar = true
		end
	end

	-- Sincronizar NumberValue en el Character (para combate y otros sistemas)
	if staminaValueActual then
		staminaValueActual.Value = math.floor(stamina)
	end

	actualizarBarraUI()
end)

print("[Stamina] Sistema de stamina activo.")
