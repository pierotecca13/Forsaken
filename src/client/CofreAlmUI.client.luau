-- CofreAlmUI.client.luau
-- Interfaz de dos paneles para el Cofre de Almacenamiento.
-- Panel izquierdo: inventario del jugador (click → mover al cofre).
-- Panel derecho:   contenido del cofre    (click → mover al inventario).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local CofreAlmConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CofreAlmConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Estado local
-- ============================================================
local uiAbierta     = false
local invLocal      = {}
local cofreLocal    = {}
local slotsMaxLocal = CofreAlmConfig.SLOTS_BASE

-- Nombres legibles de los recursos
local NOMBRES = {
	Madera      = "Madera",
	Piedra      = "Piedra",
	Hongos      = "Hongos",
	Piel        = "Piel",
	Colmillo    = "Colmillo",
	Garra       = "Garra",
	CarneConejo = "Carne Conejo",
	CarneZorro  = "Carne Zorro",
	CarneLobo   = "Carne Lobo",
	CarneOso    = "Carne Oso",
	Hierro      = "Hierro",
	Cristal     = "Cristal",
}

-- ============================================================
-- UI principal
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "CofreAlmUI"
screenGui.ResetOnSpawn  = false
screenGui.DisplayOrder  = 18
screenGui.Parent        = playerGui

local marco = Instance.new("Frame")
marco.Name                   = "Marco"
marco.AnchorPoint            = Vector2.new(0.5, 0.5)
marco.Size                   = UDim2.new(0, 680, 0, 460)
marco.Position               = UDim2.new(0.5, 0, 0.5, 0)
marco.BackgroundColor3       = Color3.fromRGB(18, 12, 8)
marco.BackgroundTransparency = 0.08
marco.BorderSizePixel        = 0
marco.Visible                = false
marco.Parent                 = screenGui

local cornerMarco = Instance.new("UICorner")
cornerMarco.CornerRadius = UDim.new(0, 12)
cornerMarco.Parent       = marco

local strokeMarco = Instance.new("UIStroke")
strokeMarco.Color     = Color3.fromRGB(140, 95, 40)
strokeMarco.Thickness = 2
strokeMarco.Parent    = marco

-- ── Encabezado ────────────────────────────────────────────────
local header = Instance.new("Frame")
header.Name                   = "Header"
header.Size                   = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3       = Color3.fromRGB(30, 20, 10)
header.BackgroundTransparency = 0
header.BorderSizePixel        = 0
header.Parent                 = marco

local cornerHeader = Instance.new("UICorner")
cornerHeader.CornerRadius = UDim.new(0, 12)
cornerHeader.Parent       = header

local headerBottom = Instance.new("Frame")
headerBottom.Size             = UDim2.new(1, 0, 0, 12)
headerBottom.Position         = UDim2.new(0, 0, 1, -12)
headerBottom.BackgroundColor3 = Color3.fromRGB(30, 20, 10)
headerBottom.BorderSizePixel  = 0
headerBottom.Parent           = header

local lblTitulo = Instance.new("TextLabel")
lblTitulo.Size               = UDim2.new(0.85, 0, 1, 0)
lblTitulo.Position           = UDim2.new(0, 14, 0, 0)
lblTitulo.BackgroundTransparency = 1
lblTitulo.Text               = "COFRE DE ALMACENAMIENTO"
lblTitulo.Font               = Enum.Font.GothamBold
lblTitulo.TextScaled         = true
lblTitulo.TextColor3         = Color3.fromRGB(220, 180, 80)
lblTitulo.TextXAlignment     = Enum.TextXAlignment.Left
lblTitulo.Parent             = header

local btnX = Instance.new("TextButton")
btnX.Size             = UDim2.new(0, 26, 0, 26)
btnX.Position         = UDim2.new(1, -36, 0.5, -13)
btnX.BackgroundColor3 = Color3.fromRGB(130, 35, 35)
btnX.Text             = "X"
btnX.Font             = Enum.Font.GothamBold
btnX.TextScaled       = true
btnX.TextColor3       = Color3.fromRGB(255, 255, 255)
btnX.Parent           = header

local cornerBtnX = Instance.new("UICorner")
cornerBtnX.CornerRadius = UDim.new(0, 6)
cornerBtnX.Parent       = btnX

-- ── Área de contenido ─────────────────────────────────────────
local contenido = Instance.new("Frame")
contenido.Name                   = "Contenido"
contenido.Size                   = UDim2.new(1, 0, 1, -36)
contenido.Position               = UDim2.new(0, 0, 0, 36)
contenido.BackgroundTransparency = 1
contenido.Parent                 = marco

-- ── Panel izquierdo: Inventario ───────────────────────────────
local panelIzq = Instance.new("Frame")
panelIzq.Name                   = "PanelInventario"
panelIzq.Size                   = UDim2.new(0, 324, 1, -12)
panelIzq.Position               = UDim2.new(0, 10, 0, 6)
panelIzq.BackgroundColor3       = Color3.fromRGB(14, 10, 6)
panelIzq.BackgroundTransparency = 0.3
panelIzq.BorderSizePixel        = 0
panelIzq.Parent                 = contenido

local cornerIzq = Instance.new("UICorner")
cornerIzq.CornerRadius = UDim.new(0, 8)
cornerIzq.Parent       = panelIzq

local tituloIzq = Instance.new("TextLabel")
tituloIzq.Size               = UDim2.new(1, 0, 0, 26)
tituloIzq.BackgroundTransparency = 1
tituloIzq.Text               = "INVENTARIO"
tituloIzq.Font               = Enum.Font.GothamBold
tituloIzq.TextScaled         = true
tituloIzq.TextColor3         = Color3.fromRGB(200, 200, 200)
tituloIzq.TextXAlignment     = Enum.TextXAlignment.Center
tituloIzq.Parent             = panelIzq

local scrollIzq = Instance.new("ScrollingFrame")
scrollIzq.Name                   = "ScrollInv"
scrollIzq.Size                   = UDim2.new(1, -8, 1, -30)
scrollIzq.Position               = UDim2.new(0, 4, 0, 28)
scrollIzq.BackgroundTransparency = 1
scrollIzq.BorderSizePixel        = 0
scrollIzq.ScrollBarThickness     = 4
scrollIzq.ScrollBarImageColor3   = Color3.fromRGB(140, 95, 40)
scrollIzq.CanvasSize             = UDim2.new(0, 0, 0, 500)
scrollIzq.AutomaticCanvasSize    = Enum.AutomaticSize.None
scrollIzq.ScrollingDirection     = Enum.ScrollingDirection.Y
scrollIzq.Parent                 = panelIzq

local layoutIzq = Instance.new("UIListLayout")
layoutIzq.SortOrder = Enum.SortOrder.Name
layoutIzq.Padding   = UDim.new(0, 3)
layoutIzq.Parent    = scrollIzq

local paddingIzq = Instance.new("UIPadding")
paddingIzq.PaddingLeft   = UDim.new(0, 4)
paddingIzq.PaddingRight  = UDim.new(0, 4)
paddingIzq.PaddingTop    = UDim.new(0, 3)
paddingIzq.PaddingBottom = UDim.new(0, 3)
paddingIzq.Parent        = scrollIzq

-- ── Línea divisoria central ───────────────────────────────────
local divisor = Instance.new("Frame")
divisor.Name             = "Divisor"
divisor.Size             = UDim2.new(0, 2, 1, -12)
divisor.Position         = UDim2.new(0, 340, 0, 6)
divisor.BackgroundColor3 = Color3.fromRGB(100, 70, 30)
divisor.BorderSizePixel  = 0
divisor.Parent           = contenido

-- ── Panel derecho: Cofre ──────────────────────────────────────
local panelDer = Instance.new("Frame")
panelDer.Name                   = "PanelCofre"
panelDer.Size                   = UDim2.new(0, 324, 1, -12)
panelDer.Position               = UDim2.new(0, 346, 0, 6)
panelDer.BackgroundColor3       = Color3.fromRGB(12, 8, 4)
panelDer.BackgroundTransparency = 0.3
panelDer.BorderSizePixel        = 0
panelDer.Parent                 = contenido

local cornerDer = Instance.new("UICorner")
cornerDer.CornerRadius = UDim.new(0, 8)
cornerDer.Parent       = panelDer

local tituloDer = Instance.new("TextLabel")
tituloDer.Name               = "Titulo"
tituloDer.Size               = UDim2.new(1, 0, 0, 26)
tituloDer.BackgroundTransparency = 1
tituloDer.Text               = "COFRE  (0 / 5 slots)"
tituloDer.Font               = Enum.Font.GothamBold
tituloDer.TextScaled         = true
tituloDer.TextColor3         = Color3.fromRGB(220, 180, 80)
tituloDer.TextXAlignment     = Enum.TextXAlignment.Center
tituloDer.Parent             = panelDer

local scrollDer = Instance.new("ScrollingFrame")
scrollDer.Name                   = "ScrollCofre"
scrollDer.Size                   = UDim2.new(1, -8, 1, -30)
scrollDer.Position               = UDim2.new(0, 4, 0, 28)
scrollDer.BackgroundTransparency = 1
scrollDer.BorderSizePixel        = 0
scrollDer.ScrollBarThickness     = 4
scrollDer.ScrollBarImageColor3   = Color3.fromRGB(140, 95, 40)
scrollDer.CanvasSize             = UDim2.new(0, 0, 0, 500)
scrollDer.AutomaticCanvasSize    = Enum.AutomaticSize.None
scrollDer.ScrollingDirection     = Enum.ScrollingDirection.Y
scrollDer.Parent                 = panelDer

local layoutDer = Instance.new("UIListLayout")
layoutDer.SortOrder = Enum.SortOrder.LayoutOrder
layoutDer.Padding   = UDim.new(0, 3)
layoutDer.Parent    = scrollDer

local paddingDer = Instance.new("UIPadding")
paddingDer.PaddingLeft   = UDim.new(0, 4)
paddingDer.PaddingRight  = UDim.new(0, 4)
paddingDer.PaddingTop    = UDim.new(0, 3)
paddingDer.PaddingBottom = UDim.new(0, 3)
paddingDer.Parent        = scrollDer

-- ── Hint inferior ─────────────────────────────────────────────
local lblHint = Instance.new("TextLabel")
lblHint.Size               = UDim2.new(1, 0, 0, 16)
lblHint.AnchorPoint        = Vector2.new(0.5, 1)
lblHint.Position           = UDim2.new(0.5, 0, 1, -4)
lblHint.BackgroundTransparency = 1
lblHint.Text               = "Click en un ítem para moverlo   ·   Esc para cerrar"
lblHint.Font               = Enum.Font.Gotham
lblHint.TextScaled         = true
lblHint.TextColor3         = Color3.fromRGB(110, 100, 80)
lblHint.TextXAlignment     = Enum.TextXAlignment.Center
lblHint.Parent             = marco

-- ============================================================
-- Helpers de UI
-- ============================================================
local function crearBotonItem(parent, nombre, cantidad, color, onClick)
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(1, 0, 0, 36)
	btn.BackgroundColor3 = color
	btn.AutoButtonColor  = false
	btn.BorderSizePixel  = 0
	btn.Text             = ""
	btn.Parent           = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent       = btn

	local lblNom = Instance.new("TextLabel")
	lblNom.Size               = UDim2.new(0.72, 0, 1, 0)
	lblNom.Position           = UDim2.new(0, 8, 0, 0)
	lblNom.BackgroundTransparency = 1
	lblNom.Text               = nombre
	lblNom.Font               = Enum.Font.GothamBold
	lblNom.TextScaled         = true
	lblNom.TextColor3         = Color3.fromRGB(240, 230, 200)
	lblNom.TextXAlignment     = Enum.TextXAlignment.Left
	lblNom.Parent             = btn

	local lblCant = Instance.new("TextLabel")
	lblCant.Size               = UDim2.new(0.28, -8, 1, 0)
	lblCant.Position           = UDim2.new(0.72, 0, 0, 0)
	lblCant.BackgroundTransparency = 1
	lblCant.Text               = "×" .. cantidad
	lblCant.Font               = Enum.Font.GothamBold
	lblCant.TextScaled         = true
	lblCant.TextColor3         = Color3.fromRGB(200, 200, 150)
	lblCant.TextXAlignment     = Enum.TextXAlignment.Right
	lblCant.Parent             = btn

	btn.MouseButton1Click:Connect(onClick)
	return btn
end

local function crearSlotVacio(parent, orden)
	local slot = Instance.new("Frame")
	slot.Size             = UDim2.new(1, 0, 0, 36)
	slot.BackgroundColor3 = Color3.fromRGB(30, 20, 12)
	slot.BackgroundTransparency = 0.5
	slot.BorderSizePixel  = 0
	slot.LayoutOrder      = orden
	slot.Parent           = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent       = slot

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "— vacío —"
	lbl.Font               = Enum.Font.Gotham
	lbl.TextScaled         = true
	lbl.TextColor3         = Color3.fromRGB(80, 70, 55)
	lbl.Parent             = slot

	return slot
end

-- ============================================================
-- Poblar paneles
-- ============================================================
local function poblarPanelInventario()
	for _, child in ipairs(scrollIzq:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local itemsMostrados = 0
	for _, recurso in ipairs(CofreAlmConfig.ITEMS_ALMACENABLES) do
		local cant   = invLocal[recurso] or 0
		local nombre = NOMBRES[recurso] or recurso
		local color  = cant > 0
			and Color3.fromRGB(40, 30, 18)
			or  Color3.fromRGB(25, 18, 10)

		local btn = crearBotonItem(scrollIzq, nombre, cant, color, function()
			if (invLocal[recurso] or 0) <= 0 then return end
			local evMoverAlCofre = ReplicatedStorage.Eventos:FindFirstChild("MoverAlCofre")
			if evMoverAlCofre then evMoverAlCofre:FireServer(recurso) end
		end)
		btn.Name   = recurso
		btn.Active = cant > 0

		if cant <= 0 then
			btn.BackgroundTransparency = 0.6
			for _, child in ipairs(btn:GetDescendants()) do
				if child:IsA("TextLabel") then
					child.TextColor3 = Color3.fromRGB(80, 70, 55)
				end
			end
		end

		itemsMostrados += 1
	end

	scrollIzq.CanvasSize = UDim2.new(0, 0, 0, itemsMostrados * 39 + 6)
end

local function poblarPanelCofre()
	for _, child in ipairs(scrollDer:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local maxPorSlot  = CofreAlmConfig.MAX_POR_SLOT
	local slotsUsados = 0
	local orden       = 0

	-- Cada recurso puede ocupar varios slots (ceil(cantidad / maxPorSlot))
	-- Se muestra una fila por cada slot físico ocupado
	for recurso, cantTotal in pairs(cofreLocal) do
		local nombre      = NOMBRES[recurso] or recurso
		local cantRestante = cantTotal
		while cantRestante > 0 do
			orden += 1
			slotsUsados += 1
			local cantEsteSlot = math.min(cantRestante, maxPorSlot)
			cantRestante -= cantEsteSlot

			local btn = crearBotonItem(scrollDer, nombre, cantEsteSlot, Color3.fromRGB(50, 35, 18), function()
				local evMoverAlInventario = ReplicatedStorage.Eventos:FindFirstChild("MoverAlInventario")
				if evMoverAlInventario then evMoverAlInventario:FireServer(recurso) end
			end)
			btn.LayoutOrder = orden
		end
	end

	for _ = slotsUsados + 1, slotsMaxLocal do
		orden += 1
		crearSlotVacio(scrollDer, orden)
	end

	tituloDer.Text       = string.format("COFRE  (%d / %d slots)", slotsUsados, slotsMaxLocal)
	scrollDer.CanvasSize = UDim2.new(0, 0, 0, slotsMaxLocal * 39 + 6)
end

-- ============================================================
-- Abrir / cerrar UI
-- ============================================================
local function abrirUI(datos)
	cofreLocal    = datos.cofre      or {}
	slotsMaxLocal = datos.slotsMax   or CofreAlmConfig.SLOTS_BASE
	invLocal      = datos.inventario or invLocal

	poblarPanelInventario()
	poblarPanelCofre()
	scrollIzq.CanvasPosition = Vector2.new(0, 0)
	scrollDer.CanvasPosition = Vector2.new(0, 0)

	uiAbierta     = true
	marco.Visible = true
end

local function cerrarUI()
	uiAbierta     = false
	marco.Visible = false
end

-- ============================================================
-- Conectar eventos (DESPUÉS de definir todas las funciones)
-- ============================================================
btnX.MouseButton1Click:Connect(cerrarUI)

UserInputService.InputBegan:Connect(function(input, _gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape and uiAbierta then
		cerrarUI()
	end
end)

task.spawn(function()
	local carpetaEventos = ReplicatedStorage:WaitForChild("Eventos")

	local evAbrirCofreAlm      = carpetaEventos:WaitForChild("AbrirCofreAlm")
	local evCofreAlmActualizado = carpetaEventos:WaitForChild("CofreAlmActualizado")
	local evInventario          = carpetaEventos:WaitForChild("InventarioActualizado")

	-- Todas las funciones ya están definidas en este punto, no hay riesgo de nil
	evAbrirCofreAlm.OnClientEvent:Connect(abrirUI)

	evCofreAlmActualizado.OnClientEvent:Connect(function(datos)
		cofreLocal    = datos.cofre     or {}
		slotsMaxLocal = datos.slotsMax  or CofreAlmConfig.SLOTS_BASE
		if uiAbierta then
			poblarPanelCofre()
			poblarPanelInventario()
		end
	end)

	evInventario.OnClientEvent:Connect(function(inv)
		invLocal = inv or {}
		if uiAbierta then poblarPanelInventario() end
	end)
end)

print("[CofreAlmUI] Interfaz del cofre de almacenamiento lista.")
