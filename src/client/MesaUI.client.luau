-- MesaUI.client.luau
-- Menú de crafteo de la Mesa de Trabajo.
-- Se abre al presionar E en la mesa.
-- Secciones: Consumibles (T/G) · Armas · Armaduras

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local MesaConfig   = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MesaConfig"))
local ArmasConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArmasConfig"))
local EquipoConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquipoConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Eventos ──────────────────────────────────────────────────────
local carpetaEventos = ReplicatedStorage:WaitForChild("Eventos")
local evAbrirMesa     = carpetaEventos:WaitForChild("AbrirMesaTrabajo")
local evSolCrafteo    = carpetaEventos:WaitForChild("SolicitarCrafteo")
local evResultCrafteo = carpetaEventos:WaitForChild("ResultadoCrafteo")
local evColocarItem   = carpetaEventos:WaitForChild("ColocarItem")
local evInventario    = carpetaEventos:WaitForChild("InventarioActualizado")

-- Eventos de equipo (creados por Equipo.server al arrancar)
local evCrafteoArma, evResultArma, evCrafteoArmadura, evResultArmadura, evEquipoActualizado
task.spawn(function()
	evCrafteoArma       = carpetaEventos:WaitForChild("SolicitarCrafteoArma")
	evResultArma        = carpetaEventos:WaitForChild("ResultadoCrafteoArma")
	evCrafteoArmadura   = carpetaEventos:WaitForChild("SolicitarCrafteoArmadura")
	evResultArmadura    = carpetaEventos:WaitForChild("ResultadoCrafteoArmadura")
	evEquipoActualizado = carpetaEventos:WaitForChild("EquipoActualizado")

	-- Conectar listeners de equipo aquí dentro del spawn para no bloquear
	evResultArma.OnClientEvent:Connect(function(resultado)
		for _, ref in pairs(bloquesArma) do ref.btn.Active = true end
		if resultado.exito and resultado.tipo then
			armaEquipada = resultado.tipo
		end
		actualizarBotones()
		mostrarFeedback(resultado.mensaje or (resultado.exito and "Arma equipada!" or "Error"), resultado.exito)
	end)

	evResultArmadura.OnClientEvent:Connect(function(resultado)
		for _, ref in pairs(bloquesArmadura) do ref.btn.Active = true end
		if resultado.exito and resultado.tipo then
			armaduraEquipada = resultado.tipo
		end
		actualizarBotones()
		mostrarFeedback(resultado.mensaje or (resultado.exito and "Armadura equipada!" or "Error"), resultado.exito)
	end)

	evEquipoActualizado.OnClientEvent:Connect(function(datos)
		if datos.arma     then armaEquipada     = datos.arma     end
		if datos.armadura then armaduraEquipada = datos.armadura end
		if menuAbierto then actualizarBotones() end
	end)
end)

-- ============================================================
-- Estado local
-- ============================================================
local menuAbierto      = false
local invLocal         = {}
local armaEquipada     = "Palo"
local armaduraEquipada = "SinArmadura"

-- Tablas de referencias a bloques de la UI
local bloques         = {}   -- consumibles: bloques[tipo] = { btn, lblInv }
local bloquesArma     = {}   -- armas:       bloquesArma[tipo] = { btn, lblEstado, bloque }
local bloquesArmadura = {}   -- armaduras:   bloquesArmadura[tipo] = { btn, lblEstado, bloque }

-- ============================================================
-- UI: Marco principal con scroll
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "MesaUI"
screenGui.ResetOnSpawn  = false
screenGui.DisplayOrder  = 14
screenGui.Parent        = playerGui

local marco = Instance.new("Frame")
marco.Name                   = "MarcoMesa"
marco.AnchorPoint            = Vector2.new(0.5, 0.5)
marco.Size                   = UDim2.new(0, 320, 0, 480)
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

local paddingMarco = Instance.new("UIPadding")
paddingMarco.PaddingLeft   = UDim.new(0, 14)
paddingMarco.PaddingRight  = UDim.new(0, 14)
paddingMarco.PaddingTop    = UDim.new(0, 12)
paddingMarco.PaddingBottom = UDim.new(0, 12)
paddingMarco.Parent        = marco

-- ScrollBody: contiene todo el contenido del menú
local scrollBody = Instance.new("ScrollingFrame")
scrollBody.Name                   = "ScrollBody"
scrollBody.Size                   = UDim2.new(1, 0, 1, -38)
scrollBody.Position               = UDim2.new(0, 0, 0, 38)
scrollBody.BackgroundTransparency = 1
scrollBody.BorderSizePixel        = 0
scrollBody.ScrollBarThickness     = 5
scrollBody.ScrollBarImageColor3   = Color3.fromRGB(140, 95, 40)
scrollBody.AutomaticCanvasSize    = Enum.AutomaticSize.None
scrollBody.CanvasSize             = UDim2.new(0, 0, 0, 1300)
scrollBody.ScrollingDirection     = Enum.ScrollingDirection.Y
scrollBody.Parent                 = marco

local paddingScroll = Instance.new("UIPadding")
paddingScroll.PaddingRight  = UDim.new(0, 8)
paddingScroll.PaddingBottom = UDim.new(0, 14)
paddingScroll.Parent        = scrollBody

local layoutMarco = Instance.new("UIListLayout")
layoutMarco.SortOrder = Enum.SortOrder.LayoutOrder
layoutMarco.Padding   = UDim.new(0, 8)
layoutMarco.Parent    = scrollBody

-- ── Encabezado ───────────────────────────────────────────────────
local headerFrame = Instance.new("Frame")
headerFrame.Size               = UDim2.new(1, 0, 0, 30)
headerFrame.BackgroundColor3   = Color3.fromRGB(18, 12, 8)
headerFrame.BackgroundTransparency = 0
headerFrame.ZIndex             = 10
headerFrame.Parent             = marco

local lblTitulo = Instance.new("TextLabel")
lblTitulo.Size               = UDim2.new(0.82, 0, 1, 0)
lblTitulo.BackgroundTransparency = 1
lblTitulo.Text               = "MESA DE TRABAJO"
lblTitulo.Font               = Enum.Font.GothamBold
lblTitulo.TextScaled         = true
lblTitulo.TextColor3         = Color3.fromRGB(255, 210, 100)
lblTitulo.TextXAlignment     = Enum.TextXAlignment.Left
lblTitulo.ZIndex             = 10
lblTitulo.Parent             = headerFrame

local btnCerrar = Instance.new("TextButton")
btnCerrar.Size              = UDim2.new(0, 26, 0, 26)
btnCerrar.Position          = UDim2.new(1, -26, 0.5, -13)
btnCerrar.BackgroundColor3  = Color3.fromRGB(130, 35, 35)
btnCerrar.Text              = "X"
btnCerrar.Font              = Enum.Font.GothamBold
btnCerrar.TextScaled        = true
btnCerrar.TextColor3        = Color3.fromRGB(255, 255, 255)
btnCerrar.ZIndex            = 10
btnCerrar.Parent            = headerFrame

local cornerX = Instance.new("UICorner")
cornerX.CornerRadius = UDim.new(0, 6)
cornerX.Parent       = btnCerrar

-- Botón X en ScreenGui propio con DisplayOrder alto → siempre visible
-- Posición calculada para coincidir con btnCerrar dentro del marco centrado
local screenGuiOverlay = Instance.new("ScreenGui")
screenGuiOverlay.Name         = "MesaUIOverlay"
screenGuiOverlay.ResetOnSpawn = false
screenGuiOverlay.DisplayOrder = 100
screenGuiOverlay.Enabled      = false
screenGuiOverlay.Parent       = playerGui

local btnCerrarOverlay = Instance.new("TextButton")
btnCerrarOverlay.AnchorPoint     = Vector2.new(0, 0)
btnCerrarOverlay.Size            = UDim2.new(0, 26, 0, 26)
-- marco: 320×480 centrado → top-left=(–160,–240). Padding 14/12. btnCerrar dentro del headerFrame a X+120, Y–226
btnCerrarOverlay.Position        = UDim2.new(0.5, 120, 0.5, -226)
btnCerrarOverlay.BackgroundColor3 = Color3.fromRGB(130, 35, 35)
btnCerrarOverlay.Text            = "X"
btnCerrarOverlay.Font            = Enum.Font.GothamBold
btnCerrarOverlay.TextScaled      = true
btnCerrarOverlay.TextColor3      = Color3.fromRGB(255, 255, 255)
btnCerrarOverlay.Parent          = screenGuiOverlay

local cornerXOverlay = Instance.new("UICorner")
cornerXOverlay.CornerRadius = UDim.new(0, 6)
cornerXOverlay.Parent       = btnCerrarOverlay

-- ── Helpers de UI ────────────────────────────────────────────────
local function crearSeparador(orden, color)
	local sep = Instance.new("Frame")
	sep.Size             = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3 = color or Color3.fromRGB(70, 50, 25)
	sep.BorderSizePixel  = 0
	sep.LayoutOrder      = orden
	sep.Parent           = scrollBody
	return sep
end

local function crearTituloSeccion(texto, orden, color)
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Text               = texto
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextScaled         = true
	lbl.TextColor3         = color or Color3.fromRGB(255, 210, 100)
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.LayoutOrder        = orden
	lbl.Parent             = scrollBody
	return lbl
end

local function crearBloque(orden, bgColor)
	local bloque = Instance.new("Frame")
	bloque.Size               = UDim2.new(1, 0, 0, 0)
	bloque.AutomaticSize      = Enum.AutomaticSize.Y
	bloque.BackgroundColor3   = bgColor or Color3.fromRGB(28, 20, 12)
	bloque.BackgroundTransparency = 0.3
	bloque.BorderSizePixel    = 0
	bloque.LayoutOrder        = orden
	bloque.Parent             = scrollBody

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent       = bloque

	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, 10)
	p.PaddingRight  = UDim.new(0, 10)
	p.PaddingTop    = UDim.new(0, 8)
	p.PaddingBottom = UDim.new(0, 8)
	p.Parent        = bloque

	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding   = UDim.new(0, 4)
	l.Parent    = bloque

	return bloque
end

local function crearFilaTop(parent)
	local fila = Instance.new("Frame")
	fila.Size               = UDim2.new(1, 0, 0, 20)
	fila.BackgroundTransparency = 1
	fila.LayoutOrder        = 1
	fila.Parent             = parent
	return fila
end

local function crearLblCosto(parent, costosTabla)
	local partes = {}
	for recurso, cantidad in pairs(costosTabla) do
		table.insert(partes, cantidad .. " " .. recurso)
	end
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 0, 13)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "Costo: " .. table.concat(partes, "  +  ")
	lbl.Font               = Enum.Font.Gotham
	lbl.TextScaled         = true
	lbl.TextColor3         = Color3.fromRGB(165, 145, 90)
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.LayoutOrder        = 3
	lbl.Parent             = parent
	return lbl
end

local function crearBoton(parent, texto, color)
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = color or Color3.fromRGB(70, 100, 45)
	btn.Text             = texto
	btn.Font             = Enum.Font.GothamBold
	btn.TextScaled       = true
	btn.TextColor3       = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor  = false
	btn.LayoutOrder      = 4
	btn.Parent           = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent       = btn
	return btn
end

-- ============================================================
-- SECCIÓN 1: Consumibles (Antorcha / Hoguera)
-- ============================================================
crearSeparador(1)
crearTituloSeccion("CONSUMIBLES", 2, Color3.fromRGB(255, 180, 60))

for idx, tipo in ipairs(MesaConfig.ORDEN_RECETAS) do
	local receta = MesaConfig.RECETAS[tipo]
	local orden  = 3 + (idx - 1) * 3

	local bloque = crearBloque(orden)

	-- Fila nombre + contador de inventario
	local filaTop     = crearFilaTop(bloque)
	local lblNombre   = Instance.new("TextLabel")
	lblNombre.Size               = UDim2.new(0.65, 0, 1, 0)
	lblNombre.BackgroundTransparency = 1
	lblNombre.Text               = receta.nombre
	lblNombre.Font               = Enum.Font.GothamBold
	lblNombre.TextScaled         = true
	lblNombre.TextColor3         = Color3.fromRGB(255, 210, 130)
	lblNombre.TextXAlignment     = Enum.TextXAlignment.Left
	lblNombre.Parent             = filaTop

	local lblInventario = Instance.new("TextLabel")
	lblInventario.Size           = UDim2.new(0.35, 0, 1, 0)
	lblInventario.Position       = UDim2.new(0.65, 0, 0, 0)
	lblInventario.BackgroundTransparency = 1
	lblInventario.Text           = "0 / " .. receta.maxInventario
	lblInventario.Font           = Enum.Font.GothamBold
	lblInventario.TextScaled     = true
	lblInventario.TextColor3     = Color3.fromRGB(180, 180, 180)
	lblInventario.TextXAlignment = Enum.TextXAlignment.Right
	lblInventario.Parent         = filaTop

	-- Costo
	local partes = {}
	for recurso, cantidad in pairs(receta.costo) do
		table.insert(partes, cantidad .. " " .. recurso)
	end
	local lblCosto = Instance.new("TextLabel")
	lblCosto.Size               = UDim2.new(1, 0, 0, 14)
	lblCosto.BackgroundTransparency = 1
	lblCosto.Text               = "Costo: " .. table.concat(partes, "  +  ")
	lblCosto.Font               = Enum.Font.Gotham
	lblCosto.TextScaled         = true
	lblCosto.TextColor3         = Color3.fromRGB(165, 145, 90)
	lblCosto.TextXAlignment     = Enum.TextXAlignment.Left
	lblCosto.LayoutOrder        = 2
	lblCosto.Parent             = bloque

	local btnCraftear = crearBoton(bloque, "CRAFTEAR  " .. string.upper(receta.nombre), Color3.fromRGB(70, 100, 45))
	bloques[tipo] = { btn = btnCraftear, lblInv = lblInventario }

	if idx < #MesaConfig.ORDEN_RECETAS then
		crearSeparador(orden + 1)
	end

	btnCraftear.MouseButton1Click:Connect(function()
		if not btnCraftear.Active then return end
		btnCraftear.Active = false
		evSolCrafteo:FireServer(tipo)
	end)
end

-- Hint teclas colocación
crearSeparador(20)
local lblHint = Instance.new("TextLabel")
lblHint.Size               = UDim2.new(1, 0, 0, 18)
lblHint.BackgroundTransparency = 1
lblHint.Text               = "T: Colocar Antorcha   ·   G: Colocar Hoguera"
lblHint.Font               = Enum.Font.Gotham
lblHint.TextScaled         = true
lblHint.TextColor3         = Color3.fromRGB(140, 130, 110)
lblHint.TextXAlignment     = Enum.TextXAlignment.Center
lblHint.LayoutOrder        = 21
lblHint.Parent             = scrollBody

-- ============================================================
-- SECCIÓN 2: Armas
-- ============================================================
crearSeparador(30)
crearTituloSeccion("ARMAS", 31, Color3.fromRGB(255, 160, 80))

local armasCrafteables = {}
for _, tipo in ipairs(EquipoConfig.ORDEN_ARMAS) do
	if EquipoConfig.CRAFTEO_ARMAS[tipo] then
		table.insert(armasCrafteables, tipo)
	end
end

for idx, tipo in ipairs(armasCrafteables) do
	local crafteo  = EquipoConfig.CRAFTEO_ARMAS[tipo]
	local infoArma = ArmasConfig.ARMAS[tipo]
	local orden    = 32 + (idx - 1) * 2

	local bloque   = crearBloque(orden, Color3.fromRGB(22, 16, 8))
	bloque.AutomaticSize = Enum.AutomaticSize.None
	bloque.Size          = UDim2.new(1, 0, 0, 108)
	local filaTop  = crearFilaTop(bloque)

	local lblNombre = Instance.new("TextLabel")
	lblNombre.Size               = UDim2.new(0.68, 0, 1, 0)
	lblNombre.BackgroundTransparency = 1
	lblNombre.Text               = infoArma and infoArma.nombre or tipo
	lblNombre.Font               = Enum.Font.GothamBold
	lblNombre.TextScaled         = true
	lblNombre.TextColor3         = Color3.fromRGB(255, 190, 90)
	lblNombre.TextXAlignment     = Enum.TextXAlignment.Left
	lblNombre.Parent             = filaTop

	local lblEstado = Instance.new("TextLabel")
	lblEstado.Name               = "Estado"
	lblEstado.Size               = UDim2.new(0.32, 0, 1, 0)
	lblEstado.Position           = UDim2.new(0.68, 0, 0, 0)
	lblEstado.BackgroundTransparency = 1
	lblEstado.Text               = ""
	lblEstado.Font               = Enum.Font.GothamBold
	lblEstado.TextScaled         = true
	lblEstado.TextColor3         = Color3.fromRGB(100, 220, 100)
	lblEstado.TextXAlignment     = Enum.TextXAlignment.Right
	lblEstado.Parent             = filaTop

	-- Stats del arma
	local lblStats = Instance.new("TextLabel")
	lblStats.Size               = UDim2.new(1, 0, 0, 13)
	lblStats.BackgroundTransparency = 1
	lblStats.Text               = string.format("Daño: %d   Velocidad: %.1fs",
		infoArma and infoArma.dano or 0,
		infoArma and infoArma.cooldown or 1.0)
	lblStats.Font               = Enum.Font.Gotham
	lblStats.TextScaled         = true
	lblStats.TextColor3         = Color3.fromRGB(140, 180, 220)
	lblStats.TextXAlignment     = Enum.TextXAlignment.Left
	lblStats.LayoutOrder        = 2
	lblStats.Parent             = bloque

	crearLblCosto(bloque, crafteo.costo)

	local btnCraft = crearBoton(bloque,
		"CRAFTEAR  " .. string.upper(infoArma and infoArma.nombre or tipo),
		Color3.fromRGB(110, 75, 30))

	bloquesArma[tipo] = { btn = btnCraft, lblEstado = lblEstado, bloque = bloque }

	if idx < #armasCrafteables then
		crearSeparador(orden + 1, Color3.fromRGB(80, 55, 25))
	end

	btnCraft.MouseButton1Click:Connect(function()
		if not btnCraft.Active then return end
		btnCraft.Active = false
		if evCrafteoArma then evCrafteoArma:FireServer(tipo) end
	end)
end

-- ============================================================
-- SECCIÓN 3: Armaduras
-- ============================================================
crearSeparador(50)
crearTituloSeccion("ARMADURAS", 51, Color3.fromRGB(120, 200, 255))

local armadurasOrden = {}
for _, tipo in ipairs(EquipoConfig.ORDEN_ARMADURAS) do
	if EquipoConfig.ARMADURAS[tipo] and EquipoConfig.ARMADURAS[tipo].costo then
		table.insert(armadurasOrden, tipo)
	end
end

for idx, tipo in ipairs(armadurasOrden) do
	local infoArm = EquipoConfig.ARMADURAS[tipo]
	local orden   = 52 + (idx - 1) * 2

	local bloque  = crearBloque(orden, Color3.fromRGB(8, 14, 22))
	bloque.AutomaticSize = Enum.AutomaticSize.None
	bloque.Size          = UDim2.new(1, 0, 0, 108)
	local filaTop = crearFilaTop(bloque)

	local lblNombre = Instance.new("TextLabel")
	lblNombre.Size               = UDim2.new(0.68, 0, 1, 0)
	lblNombre.BackgroundTransparency = 1
	lblNombre.Text               = infoArm.nombre
	lblNombre.Font               = Enum.Font.GothamBold
	lblNombre.TextScaled         = true
	lblNombre.TextColor3         = Color3.fromRGB(120, 200, 255)
	lblNombre.TextXAlignment     = Enum.TextXAlignment.Left
	lblNombre.Parent             = filaTop

	local lblEstado = Instance.new("TextLabel")
	lblEstado.Name               = "Estado"
	lblEstado.Size               = UDim2.new(0.32, 0, 1, 0)
	lblEstado.Position           = UDim2.new(0.68, 0, 0, 0)
	lblEstado.BackgroundTransparency = 1
	lblEstado.Text               = ""
	lblEstado.Font               = Enum.Font.GothamBold
	lblEstado.TextScaled         = true
	lblEstado.TextColor3         = Color3.fromRGB(100, 220, 100)
	lblEstado.TextXAlignment     = Enum.TextXAlignment.Right
	lblEstado.Parent             = filaTop

	-- Stat de reducción
	local lblRed = Instance.new("TextLabel")
	lblRed.Size               = UDim2.new(1, 0, 0, 13)
	lblRed.BackgroundTransparency = 1
	lblRed.Text               = string.format("Reduccion de daño: %d%%", math.floor(infoArm.reduccion * 100))
	lblRed.Font               = Enum.Font.Gotham
	lblRed.TextScaled         = true
	lblRed.TextColor3         = Color3.fromRGB(120, 200, 255)
	lblRed.TextXAlignment     = Enum.TextXAlignment.Left
	lblRed.LayoutOrder        = 2
	lblRed.Parent             = bloque

	crearLblCosto(bloque, infoArm.costo)

	local btnCraft = crearBoton(bloque,
		"CRAFTEAR  " .. string.upper(infoArm.nombre),
		Color3.fromRGB(30, 55, 80))

	bloquesArmadura[tipo] = { btn = btnCraft, lblEstado = lblEstado, bloque = bloque }

	if idx < #armadurasOrden then
		crearSeparador(orden + 1, Color3.fromRGB(25, 40, 60))
	end

	btnCraft.MouseButton1Click:Connect(function()
		if not btnCraft.Active then return end
		btnCraft.Active = false
		if evCrafteoArmadura then evCrafteoArmadura:FireServer(tipo) end
	end)
end

-- ── Feedback flotante ────────────────────────────────────────────
local lblFeedback = Instance.new("TextLabel")
lblFeedback.AnchorPoint        = Vector2.new(0.5, 0)
lblFeedback.Size               = UDim2.new(0, 300, 0, 26)
lblFeedback.Position           = UDim2.new(0.5, 0, 0.28, 0)
lblFeedback.BackgroundTransparency = 1
lblFeedback.Text               = ""
lblFeedback.Font               = Enum.Font.GothamBold
lblFeedback.TextScaled         = true
lblFeedback.TextColor3         = Color3.fromRGB(100, 220, 100)
lblFeedback.TextTransparency   = 1
lblFeedback.Parent             = screenGui

-- ============================================================
-- Lógica de actualización de botones
-- ============================================================
function actualizarBotones()
	-- ── Consumibles ──────────────────────────────────────────────
	for tipo, ref in pairs(bloques) do
		local receta   = MesaConfig.RECETAS[tipo]
		local tieneInv = invLocal[tipo] or 0
		local lleno    = tieneInv >= receta.maxInventario

		ref.lblInv.Text       = tieneInv .. " / " .. receta.maxInventario
		ref.lblInv.TextColor3 = lleno
			and Color3.fromRGB(220, 70, 70)
			or  Color3.fromRGB(180, 180, 180)

		local puedePagar = true
		for recurso, cantidad in pairs(receta.costo) do
			if (invLocal[recurso] or 0) < cantidad then
				puedePagar = false; break
			end
		end
		local puede = puedePagar and not lleno
		ref.btn.Active           = puede
		ref.btn.BackgroundColor3 = puede
			and Color3.fromRGB(70, 100, 45)
			or  Color3.fromRGB(50, 50, 50)
	end

	-- ── Armas ────────────────────────────────────────────────────
	local ordenArmas = EquipoConfig.ORDEN_ARMAS
	local idxActualA = table.find(ordenArmas, armaEquipada) or 1

	for tipo, ref in pairs(bloquesArma) do
		local crafteo     = EquipoConfig.CRAFTEO_ARMAS[tipo]
		local idxObj      = table.find(ordenArmas, tipo) or 1
		local esEquipada  = (armaEquipada == tipo)
		local bloqueada   = (idxObj > idxActualA + 1)

		if esEquipada then
			ref.lblEstado.Text       = "EQUIPADA"
			ref.lblEstado.TextColor3 = Color3.fromRGB(100, 220, 100)
			ref.bloque.BackgroundColor3 = Color3.fromRGB(15, 30, 10)
			ref.btn.Active           = false
			ref.btn.BackgroundColor3 = Color3.fromRGB(30, 65, 25)
			ref.btn.Text             = "YA EQUIPADA"
		elseif bloqueada then
			ref.lblEstado.Text       = "BLOQUEADA"
			ref.lblEstado.TextColor3 = Color3.fromRGB(150, 80, 80)
			ref.bloque.BackgroundColor3 = Color3.fromRGB(22, 16, 8)
			ref.btn.Active           = false
			ref.btn.BackgroundColor3 = Color3.fromRGB(45, 35, 20)
			ref.btn.Text             = "BLOQUEADA"
		else
			-- Siguiente crafteable: verificar materiales
			ref.lblEstado.Text       = ""
			ref.bloque.BackgroundColor3 = Color3.fromRGB(22, 16, 8)
			local puedePagar = true
			for recurso, cantidad in pairs(crafteo.costo) do
				if (invLocal[recurso] or 0) < cantidad then
					puedePagar = false; break
				end
			end
			ref.btn.Active           = puedePagar
			ref.btn.BackgroundColor3 = puedePagar
				and Color3.fromRGB(110, 75, 30)
				or  Color3.fromRGB(50, 50, 50)
			local infoArma = ArmasConfig.ARMAS[tipo]
			ref.btn.Text = "CRAFTEAR  " .. string.upper(infoArma and infoArma.nombre or tipo)
		end
	end

	-- ── Armaduras ─────────────────────────────────────────────────
	local ordenArms  = EquipoConfig.ORDEN_ARMADURAS
	local idxActualAr = table.find(ordenArms, armaduraEquipada) or 1

	for tipo, ref in pairs(bloquesArmadura) do
		local infoArm    = EquipoConfig.ARMADURAS[tipo]
		local idxObj     = table.find(ordenArms, tipo) or 1
		local esEquipada = (armaduraEquipada == tipo)
		local bloqueada  = (idxObj > idxActualAr + 1)

		if esEquipada then
			ref.lblEstado.Text       = "EQUIPADA"
			ref.lblEstado.TextColor3 = Color3.fromRGB(100, 220, 100)
			ref.bloque.BackgroundColor3 = Color3.fromRGB(8, 18, 30)
			ref.btn.Active           = false
			ref.btn.BackgroundColor3 = Color3.fromRGB(20, 40, 60)
			ref.btn.Text             = "YA EQUIPADA"
		elseif bloqueada then
			ref.lblEstado.Text       = "BLOQUEADA"
			ref.lblEstado.TextColor3 = Color3.fromRGB(150, 80, 80)
			ref.bloque.BackgroundColor3 = Color3.fromRGB(8, 14, 22)
			ref.btn.Active           = false
			ref.btn.BackgroundColor3 = Color3.fromRGB(25, 35, 45)
			ref.btn.Text             = "BLOQUEADA"
		else
			ref.lblEstado.Text       = ""
			ref.bloque.BackgroundColor3 = Color3.fromRGB(8, 14, 22)
			local puedePagar = true
			for recurso, cantidad in pairs(infoArm.costo) do
				if (invLocal[recurso] or 0) < cantidad then
					puedePagar = false; break
				end
			end
			ref.btn.Active           = puedePagar
			ref.btn.BackgroundColor3 = puedePagar
				and Color3.fromRGB(30, 55, 80)
				or  Color3.fromRGB(50, 50, 50)
			ref.btn.Text = "CRAFTEAR  " .. string.upper(infoArm.nombre)
		end
	end
end

function mostrarFeedback(texto, exito)
	lblFeedback.Text             = texto
	lblFeedback.TextColor3       = exito
		and Color3.fromRGB(100, 220, 100)
		or  Color3.fromRGB(220, 80, 80)
	lblFeedback.TextTransparency = 0
	TweenService:Create(
		lblFeedback,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 1 }
	):Play()
end

-- ============================================================
-- Abrir / cerrar menú
-- ============================================================
local function abrirMenu(datos)
	invLocal      = datos.inventario or invLocal
	if datos.arma     then armaEquipada     = datos.arma     end
	if datos.armadura then armaduraEquipada = datos.armadura end
	menuAbierto   = true
	scrollBody.CanvasPosition = Vector2.new(0, 0)   -- siempre arriba al abrir
	marco.Visible             = true
	screenGuiOverlay.Enabled  = true
	actualizarBotones()
end

local function cerrarMenu()
	menuAbierto              = false
	marco.Visible            = false
	screenGuiOverlay.Enabled = false
end

btnCerrar.MouseButton1Click:Connect(cerrarMenu)
btnCerrarOverlay.MouseButton1Click:Connect(cerrarMenu)
evAbrirMesa.OnClientEvent:Connect(abrirMenu)

-- Inventario actualizado (recolección, drops, etc.)
evInventario.OnClientEvent:Connect(function(inv)
	invLocal = inv
	if menuAbierto then actualizarBotones() end
end)

-- Resultado de crafteo de consumibles
evResultCrafteo.OnClientEvent:Connect(function(resultado)
	for _, ref in pairs(bloques) do ref.btn.Active = true end
	actualizarBotones()
	mostrarFeedback(resultado.mensaje or (resultado.exito and "Crafteado!" or "Error"), resultado.exito)
end)

-- ============================================================
-- Teclas T/G para colocar consumibles en el mundo
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- Escape: Roblox pone gameProcessed=true, verificar ANTES del guard
	if input.KeyCode == Enum.KeyCode.Escape then
		if menuAbierto then cerrarMenu() end
		return
	end

	if gameProcessed then return end

	local tipo = nil
	if input.KeyCode == Enum.KeyCode.T then
		tipo = "Antorcha"
	elseif input.KeyCode == Enum.KeyCode.G then
		tipo = "Hoguera"
	end
	if not tipo then return end

	local cant = invLocal[tipo] or 0
	if cant <= 0 then
		mostrarFeedback("No tienes " .. MesaConfig.RECETAS[tipo].nombre, false)
		return
	end
	evColocarItem:FireServer(tipo)
end)

print("[MesaUI] Sistema de Mesa de Trabajo activo.")
