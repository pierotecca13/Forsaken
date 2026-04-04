-- Comida.client.luau
-- Selector de alimentos con tecla F.
--
-- Flujo:
--   · Primer F  → abre picker, selecciona el alimento MÁS potente disponible
--   · Siguientes F → cicla hacia alimentos más débiles (y vuelve al más potente)
--   · Sin pulsar F durante 2 s → come automáticamente el seleccionado
--   · Escape → cierra el picker sin comer

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ComidaConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ComidaConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Eventos ──────────────────────────────────────────────────────
local carpetaEventos   = ReplicatedStorage:WaitForChild("Eventos")
local evInventario     = carpetaEventos:WaitForChild("InventarioActualizado")
local evComerAlimento  = carpetaEventos:WaitForChild("ComerAlimento")
local evResultadoComer = carpetaEventos:WaitForChild("ResultadoComer")

-- ============================================================
-- UI: Selector de alimento
-- Aparece centrado en pantalla (~72 % de altura) al pulsar F
-- ============================================================

local guiComida = Instance.new("ScreenGui")
guiComida.Name          = "ComidaUI"
guiComida.ResetOnSpawn  = false
guiComida.DisplayOrder  = 12
guiComida.Parent        = playerGui

-- Panel principal
local panel = Instance.new("Frame")
panel.Name                   = "PanelComida"
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.Size                   = UDim2.new(0, 280, 0, 54)
panel.Position               = UDim2.new(0.5, 0, 0.72, 0)
panel.BackgroundColor3       = Color3.fromRGB(18, 10, 8)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel        = 0
panel.Visible                = false
panel.Parent                 = guiComida

local cornerPanel = Instance.new("UICorner")
cornerPanel.CornerRadius = UDim.new(0, 8)
cornerPanel.Parent       = panel

local strokePanel = Instance.new("UIStroke")
strokePanel.Color     = Color3.fromRGB(200, 120, 50)
strokePanel.Thickness = 1.5
strokePanel.Parent    = panel

-- Nombre del alimento y cantidad  (ej. "[2/2]  Carne de Lobo  ×1")
local lblNombre = Instance.new("TextLabel")
lblNombre.Size               = UDim2.new(1, -16, 0, 24)
lblNombre.Position           = UDim2.new(0, 8, 0, 4)
lblNombre.BackgroundTransparency = 1
lblNombre.Text               = ""
lblNombre.Font               = Enum.Font.GothamBold
lblNombre.TextScaled         = true
lblNombre.TextColor3         = Color3.fromRGB(255, 220, 160)
lblNombre.TextXAlignment     = Enum.TextXAlignment.Center
lblNombre.Parent             = panel

-- HP que recupera (base y con penalización nocturna)
local lblHP = Instance.new("TextLabel")
lblHP.Size               = UDim2.new(1, -16, 0, 14)
lblHP.Position           = UDim2.new(0, 8, 0, 28)
lblHP.BackgroundTransparency = 1
lblHP.Text               = ""
lblHP.Font               = Enum.Font.Gotham
lblHP.TextScaled         = true
lblHP.TextColor3         = Color3.fromRGB(110, 210, 100)
lblHP.TextXAlignment     = Enum.TextXAlignment.Center
lblHP.Parent             = panel

-- Barra de cuenta regresiva (se vacía mientras espera auto-comer)
local barraFondo = Instance.new("Frame")
barraFondo.Size             = UDim2.new(1, -8, 0, 4)
barraFondo.Position         = UDim2.new(0, 4, 1, -6)
barraFondo.BackgroundColor3 = Color3.fromRGB(40, 20, 10)
barraFondo.BorderSizePixel  = 0
barraFondo.Parent           = panel

local cornerBF = Instance.new("UICorner")
cornerBF.CornerRadius = UDim.new(1, 0)
cornerBF.Parent       = barraFondo

local barraTimer = Instance.new("Frame")
barraTimer.Size             = UDim2.new(1, 0, 1, 0)
barraTimer.BackgroundColor3 = Color3.fromRGB(200, 120, 50)
barraTimer.BorderSizePixel  = 0
barraTimer.Parent           = barraFondo

local cornerBT = Instance.new("UICorner")
cornerBT.CornerRadius = UDim.new(1, 0)
cornerBT.Parent       = barraTimer

-- Pista de navegación debajo del panel
local lblHint = Instance.new("TextLabel")
lblHint.AnchorPoint           = Vector2.new(0.5, 0)
lblHint.Size                  = UDim2.new(0, 280, 0, 12)
lblHint.Position              = UDim2.new(0.5, 0, 1, 4)
lblHint.BackgroundTransparency = 1
lblHint.Text                  = "F: ciclar  ·  Esc: cancelar"
lblHint.Font                  = Enum.Font.Gotham
lblHint.TextScaled            = true
lblHint.TextColor3            = Color3.fromRGB(140, 140, 140)
lblHint.TextXAlignment        = Enum.TextXAlignment.Center
lblHint.Parent                = panel

-- ============================================================
-- UI: Feedback de curación (+X HP flotante)
-- ============================================================

local lblFeedback = Instance.new("TextLabel")
lblFeedback.AnchorPoint        = Vector2.new(0.5, 1)
lblFeedback.Size               = UDim2.new(0, 200, 0, 28)
lblFeedback.Position           = UDim2.new(0.5, 0, 0.65, 0)
lblFeedback.BackgroundTransparency = 1
lblFeedback.Text               = ""
lblFeedback.Font               = Enum.Font.GothamBold
lblFeedback.TextScaled         = true
lblFeedback.TextColor3         = Color3.fromRGB(100, 230, 100)
lblFeedback.TextTransparency   = 1
lblFeedback.TextXAlignment     = Enum.TextXAlignment.Center
lblFeedback.Parent             = guiComida

-- ============================================================
-- Estado local
-- ============================================================

local invLocal        = {}     -- copia sincronizada del inventario
local pickerAbierto   = false
local seleccionIdx    = 1      -- índice dentro de listaDisponible()
local timerAutoEat    = 0
local DELAY_AUTO_EAT  = 2.0   -- segundos hasta comer automáticamente

-- Mantener copia local del inventario actualizada
evInventario.OnClientEvent:Connect(function(inv)
	invLocal = inv
	-- Si el picker está abierto y el ítem seleccionado ya no está, ciclar
	if pickerAbierto then
		local lista = listaDisponible()
		if #lista == 0 then
			cerrarPicker()
		else
			seleccionIdx = math.clamp(seleccionIdx, 1, #lista)
			actualizarPicker(lista)
		end
	end
end)

-- ── Helpers ─────────────────────────────────────────────────────

-- Lista de tipos de comida que el jugador tiene en su inventario (> 0)
function listaDisponible()
	local lista = {}
	for _, tipo in ipairs(ComidaConfig.ORDEN) do
		if (invLocal[tipo] or 0) > 0 then
			table.insert(lista, tipo)
		end
	end
	return lista
end

-- Texto del HP recuperado con y sin penalización nocturna
local function textoHP(vidaBase)
	local conNoche = math.floor(vidaBase * (1 - ComidaConfig.PENALIZACION_NOCHE))
	return string.format("+%d HP   (noche: +%d HP)", vidaBase, conNoche)
end

-- Refrescar los textos del panel con el alimento actualmente seleccionado
function actualizarPicker(lista)
	if #lista == 0 then return end
	seleccionIdx = math.clamp(seleccionIdx, 1, #lista)

	local tipo  = lista[seleccionIdx]
	local info  = ComidaConfig.ALIMENTOS[tipo]
	local cant  = invLocal[tipo] or 0

	-- Indicador de posición si hay varios tipos disponibles
	local nav = (#lista > 1)
		and string.format("[%d/%d]  ", seleccionIdx, #lista)
		or  ""

	lblNombre.Text = nav .. info.nombre .. "  ×" .. cant
	lblHP.Text     = textoHP(info.vidaBase)
end

-- Abrir el picker y empezar la cuenta regresiva
function abrirPicker(lista)
	pickerAbierto  = true
	timerAutoEat   = DELAY_AUTO_EAT
	panel.Visible  = true
	actualizarPicker(lista)
end

-- Cerrar el picker sin comer
function cerrarPicker()
	pickerAbierto = false
	panel.Visible = false
end

-- Enviar petición de comer el ítem seleccionado al servidor
local function comer()
	local lista = listaDisponible()
	if #lista == 0 then cerrarPicker(); return end
	seleccionIdx = math.clamp(seleccionIdx, 1, #lista)
	evComerAlimento:FireServer(lista[seleccionIdx])
	cerrarPicker()
end

-- ── Tecla F ─────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F then return end

	local lista = listaDisponible()

	if #lista == 0 then
		-- Sin comida: mostrar aviso breve
		lblFeedback.Text             = "Sin alimentos"
		lblFeedback.TextColor3       = Color3.fromRGB(190, 190, 190)
		lblFeedback.TextTransparency = 0
		TweenService:Create(
			lblFeedback,
			TweenInfo.new(1.2),
			{ TextTransparency = 1 }
		):Play()
		return
	end

	if not pickerAbierto then
		-- Primera pulsación: abrir el picker apuntando al más potente disponible
		seleccionIdx = #lista
		abrirPicker(lista)
	else
		-- Pulsaciones siguientes: ciclar hacia el más débil (y volver al inicio)
		seleccionIdx = seleccionIdx - 1
		if seleccionIdx < 1 then seleccionIdx = #lista end
		timerAutoEat = DELAY_AUTO_EAT   -- reiniciar cuenta regresiva al ciclar
		actualizarPicker(lista)
	end
end)

-- Cerrar con Escape
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and pickerAbierto then
		cerrarPicker()
	end
end)

-- ── Cuenta regresiva → auto-comer ───────────────────────────────
task.spawn(function()
	while true do
		task.wait(0.05)
		if pickerAbierto then
			timerAutoEat = math.max(0, timerAutoEat - 0.05)
			barraTimer.Size = UDim2.new(timerAutoEat / DELAY_AUTO_EAT, 0, 1, 0)
			if timerAutoEat <= 0 then
				comer()
			end
		end
	end
end)

-- ── Feedback visual del servidor ────────────────────────────────
evResultadoComer.OnClientEvent:Connect(function(resultado)
	if resultado.vidaLlena then
		lblFeedback.Text       = "Vida completa"
		lblFeedback.TextColor3 = Color3.fromRGB(190, 190, 190)
	else
		local sufijo = resultado.noche and "  (noche)" or ""
		lblFeedback.Text       = "+" .. resultado.vidaCurada .. " HP" .. sufijo
		lblFeedback.TextColor3 = Color3.fromRGB(100, 230, 100)
	end

	-- Aparecer y subir suavemente hasta desvanecerse
	lblFeedback.Position       = UDim2.new(0.5, 0, 0.65, 0)
	lblFeedback.TextTransparency = 0

	TweenService:Create(
		lblFeedback,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position         = UDim2.new(0.5, 0, 0.58, 0),
			TextTransparency = 1,
		}
	):Play()
end)

print("[Comida] Sistema de alimentación activo.")
