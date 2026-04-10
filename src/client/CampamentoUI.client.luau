-- CampamentoUI.client.luau
-- Menú de mejora del campamento. Se abre al presionar E en la hoguera.
-- Muestra nivel actual, materiales, costo y botón de confirmar.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local TrebolConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Esperar eventos del servidor
local carpetaEventos          = ReplicatedStorage:WaitForChild("Eventos")
local evAbrirMenu                 = carpetaEventos:WaitForChild("AbrirMenuCampamento")
local evSolicitarMejora           = carpetaEventos:WaitForChild("SolicitarMejora")
local evResultadoMejora           = carpetaEventos:WaitForChild("ResultadoMejora")
local evCampamentoActualizado     = carpetaEventos:WaitForChild("CampamentoActualizado")
local evInventarioActualizado     = carpetaEventos:WaitForChild("InventarioActualizado")
local evReabastecerIluminacion    = carpetaEventos:WaitForChild("ReabastecerIluminacion")
local evResultadoReabastecimiento = carpetaEventos:WaitForChild("ResultadoReabastecimiento")
local evFeedbackIluminacion       = carpetaEventos:WaitForChild("FeedbackIluminacion")

-- ============================================================
-- Construir la UI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "CampamentoUI"
screenGui.ResetOnSpawn  = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent        = playerGui

-- Marco principal (centrado, altura automática)
local marco = Instance.new("Frame")
marco.Name                   = "Marco"
marco.AnchorPoint            = Vector2.new(0.5, 0.5)
marco.Size                   = UDim2.new(0, 340, 0, 520)
marco.Position               = UDim2.new(0.5, 0, 0.5, 0)
marco.BackgroundColor3       = Color3.fromRGB(16, 14, 22)
marco.BackgroundTransparency = 0.08
marco.BorderSizePixel        = 0
marco.Visible                = false
marco.Parent                 = screenGui

local cornerMarco = Instance.new("UICorner")
cornerMarco.CornerRadius = UDim.new(0, 12)
cornerMarco.Parent = marco

local strokeMarco = Instance.new("UIStroke")
strokeMarco.Color     = Color3.fromRGB(120, 100, 55)
strokeMarco.Thickness = 2
strokeMarco.Parent    = marco

local paddingMarco = Instance.new("UIPadding")
paddingMarco.PaddingLeft   = UDim.new(0, 16)
paddingMarco.PaddingRight  = UDim.new(0, 16)
paddingMarco.PaddingTop    = UDim.new(0, 14)
paddingMarco.PaddingBottom = UDim.new(0, 14)
paddingMarco.Parent        = marco

-- ScrollingFrame que contiene todo el contenido del menú
local scrollBody = Instance.new("ScrollingFrame")
scrollBody.Name                   = "ScrollBody"
scrollBody.Size                   = UDim2.new(1, 0, 1, 0)
scrollBody.BackgroundTransparency = 1
scrollBody.BorderSizePixel        = 0
scrollBody.ScrollBarThickness     = 3
scrollBody.ScrollBarImageColor3   = Color3.fromRGB(100, 80, 40)
scrollBody.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scrollBody.CanvasSize             = UDim2.new(0, 0, 0, 0)
scrollBody.ScrollingDirection     = Enum.ScrollingDirection.Y
scrollBody.Parent                 = marco

local paddingScroll = Instance.new("UIPadding")
paddingScroll.PaddingRight  = UDim.new(0, 6)
paddingScroll.PaddingBottom = UDim.new(0, 32)
paddingScroll.Parent        = scrollBody

local layoutMarco = Instance.new("UIListLayout")
layoutMarco.SortOrder = Enum.SortOrder.LayoutOrder
layoutMarco.Padding   = UDim.new(0, 8)
layoutMarco.Parent    = scrollBody

-- ── Helpers de construcción ──────────────────────────────────

local function crearSeparador(orden)
	local sep = Instance.new("Frame")
	sep.Size               = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3   = Color3.fromRGB(70, 60, 45)
	sep.BorderSizePixel    = 0
	sep.LayoutOrder        = orden
	sep.Parent             = scrollBody
end

local function crearLabel(texto, orden, fuente, colorTexto, alineacion)
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Text               = texto
	lbl.Font               = fuente or Enum.Font.Gotham
	lbl.TextScaled         = true
	lbl.TextColor3         = colorTexto or Color3.fromRGB(210, 210, 225)
	lbl.TextXAlignment     = alineacion or Enum.TextXAlignment.Left
	lbl.LayoutOrder        = orden
	lbl.Parent             = scrollBody
	return lbl
end

-- ── ENCABEZADO ───────────────────────────────────────────────
local headerFrame = Instance.new("Frame")
headerFrame.Size               = UDim2.new(1, 0, 0, 34)
headerFrame.BackgroundTransparency = 1
headerFrame.LayoutOrder        = 0
headerFrame.Parent             = scrollBody

local lblTitulo = Instance.new("TextLabel")
lblTitulo.Size               = UDim2.new(0.82, 0, 1, 0)
lblTitulo.BackgroundTransparency = 1
lblTitulo.Text               = "CAMPAMENTO BASE"
lblTitulo.Font               = Enum.Font.GothamBold
lblTitulo.TextScaled         = true
lblTitulo.TextColor3         = Color3.fromRGB(255, 210, 60)
lblTitulo.TextXAlignment     = Enum.TextXAlignment.Left
lblTitulo.Parent             = headerFrame

local btnCerrar = Instance.new("TextButton")
btnCerrar.Size              = UDim2.new(0, 28, 0, 28)
btnCerrar.Position          = UDim2.new(1, -28, 0.5, -14)
btnCerrar.BackgroundColor3  = Color3.fromRGB(130, 35, 35)
btnCerrar.Text              = "X"
btnCerrar.Font              = Enum.Font.GothamBold
btnCerrar.TextScaled        = true
btnCerrar.TextColor3        = Color3.fromRGB(255, 255, 255)
btnCerrar.Parent            = headerFrame

local cornerCerrar = Instance.new("UICorner")
cornerCerrar.CornerRadius = UDim.new(0, 6)
cornerCerrar.Parent = btnCerrar

-- ── NIVEL ACTUAL ─────────────────────────────────────────────
crearSeparador(1)

local seccionNivel = Instance.new("Frame")
seccionNivel.Size               = UDim2.new(1, 0, 0, 42)
seccionNivel.BackgroundColor3   = Color3.fromRGB(28, 24, 38)
seccionNivel.BackgroundTransparency = 0.25
seccionNivel.BorderSizePixel    = 0
seccionNivel.LayoutOrder        = 2
seccionNivel.Parent             = scrollBody

local cornerNivel = Instance.new("UICorner")
cornerNivel.CornerRadius = UDim.new(0, 8)
cornerNivel.Parent = seccionNivel

local lblNivelTitulo = Instance.new("TextLabel")
lblNivelTitulo.Size               = UDim2.new(0.45, 0, 1, 0)
lblNivelTitulo.Position           = UDim2.new(0, 10, 0, 0)
lblNivelTitulo.BackgroundTransparency = 1
lblNivelTitulo.Text               = "Nivel 1 / 5"
lblNivelTitulo.Font               = Enum.Font.GothamBold
lblNivelTitulo.TextScaled         = true
lblNivelTitulo.TextColor3         = Color3.fromRGB(255, 210, 60)
lblNivelTitulo.TextXAlignment     = Enum.TextXAlignment.Left
lblNivelTitulo.Parent             = seccionNivel

-- Indicador visual de nivel (puntos rellenos/vacíos)
local lblPuntos = Instance.new("TextLabel")
lblPuntos.Size               = UDim2.new(0.5, -10, 1, 0)
lblPuntos.Position           = UDim2.new(0.5, 0, 0, 0)
lblPuntos.BackgroundTransparency = 1
lblPuntos.Text               = "# o o o o"
lblPuntos.Font               = Enum.Font.GothamBold
lblPuntos.TextScaled         = true
lblPuntos.TextColor3         = Color3.fromRGB(255, 210, 60)
lblPuntos.TextXAlignment     = Enum.TextXAlignment.Right
lblPuntos.Parent             = seccionNivel

-- ── MATERIALES ───────────────────────────────────────────────
crearSeparador(3)
crearLabel("TUS MATERIALES:", 4, Enum.Font.GothamMedium, Color3.fromRGB(155, 150, 175))

local matFrame = Instance.new("Frame")
matFrame.Size           = UDim2.new(1, 0, 0, 0)
matFrame.AutomaticSize  = Enum.AutomaticSize.Y
matFrame.BackgroundTransparency = 1
matFrame.LayoutOrder    = 5
matFrame.Parent         = scrollBody

local layoutMat = Instance.new("UIListLayout")
layoutMat.SortOrder = Enum.SortOrder.LayoutOrder
layoutMat.Padding   = UDim.new(0, 3)
layoutMat.Parent    = matFrame

-- Colores por recurso
local COLORES = {
	Madera     = Color3.fromRGB(185, 140, 75),
	Piedra     = Color3.fromRGB(160, 160, 175),
	Hongos     = Color3.fromRGB(190, 110, 220),
	HojaTrebol = Color3.fromRGB(80, 210, 80),
}

-- Crear una fila de material (nombre a la izquierda, cantidad a la derecha)
local function crearFilaMaterial(recurso, orden)
	local fila = Instance.new("Frame")
	fila.Name               = "Fila_" .. recurso
	fila.Size               = UDim2.new(1, 0, 0, 22)
	fila.BackgroundTransparency = 1
	fila.LayoutOrder        = orden
	fila.Parent             = matFrame

	local lblNombre = Instance.new("TextLabel")
	lblNombre.Size               = UDim2.new(0.7, 0, 1, 0)
	lblNombre.BackgroundTransparency = 1
	lblNombre.Font               = Enum.Font.Gotham
	lblNombre.TextScaled         = true
	lblNombre.TextColor3         = COLORES[recurso] or Color3.fromRGB(220, 220, 220)
	lblNombre.TextXAlignment     = Enum.TextXAlignment.Left
	lblNombre.Parent             = fila

	local lblCantidad = Instance.new("TextLabel")
	lblCantidad.Name             = "Cantidad"
	lblCantidad.Size             = UDim2.new(0.3, 0, 1, 0)
	lblCantidad.Position         = UDim2.new(0.7, 0, 0, 0)
	lblCantidad.BackgroundTransparency = 1
	lblCantidad.Text             = "0"
	lblCantidad.Font             = Enum.Font.GothamBold
	lblCantidad.TextScaled       = true
	lblCantidad.TextColor3       = Color3.fromRGB(255, 255, 255)
	lblCantidad.TextXAlignment   = Enum.TextXAlignment.Right
	lblCantidad.Parent           = fila

	return fila, lblNombre, lblCantidad
end

-- Filas de materiales siempre visibles
local RECURSOS_BASE = { "Madera", "Piedra", "Hongos" }
local lblsCantidad  = {}  -- lblsCantidad["Madera"] = TextLabel del número
local nombresCfg    = {}  -- se rellena cuando llegan los datos del servidor

for i, recurso in ipairs(RECURSOS_BASE) do
	local _, lblN, lblC = crearFilaMaterial(recurso, i)
	lblN.Text = recurso           -- por defecto; se actualiza con el nombre del config
	lblsCantidad[recurso] = lblC
end

-- Fila especial para HojaTrebol (solo visible en nivel 4)
local filaHoja, lblHojaNombre, lblHojaCantidad = crearFilaMaterial("HojaTrebol", 4)
filaHoja.Visible = false
lblsCantidad["HojaTrebol"] = lblHojaCantidad

-- ── COSTO SIGUIENTE NIVEL ────────────────────────────────────
crearSeparador(6)
local lblCostoTitulo = crearLabel("PARA SUBIR A NIVEL 2:", 7,
	Enum.Font.GothamMedium, Color3.fromRGB(155, 150, 175))

local costoFrame = Instance.new("Frame")
costoFrame.Name           = "CostoFrame"
costoFrame.Size           = UDim2.new(1, 0, 0, 0)
costoFrame.AutomaticSize  = Enum.AutomaticSize.Y
costoFrame.BackgroundTransparency = 1
costoFrame.LayoutOrder    = 8
costoFrame.Parent         = scrollBody

local layoutCosto = Instance.new("UIListLayout")
layoutCosto.SortOrder = Enum.SortOrder.LayoutOrder
layoutCosto.Padding   = UDim.new(0, 3)
layoutCosto.Parent    = costoFrame

-- Pre-creamos 6 filas de costo (recursos + trébolees); se muestran según el nivel
local MAX_COSTO = 6
local filasCosto = {}

for i = 1, MAX_COSTO do
	local fila = Instance.new("Frame")
	fila.Size               = UDim2.new(1, 0, 0, 22)
	fila.BackgroundTransparency = 1
	fila.LayoutOrder        = i
	fila.Visible            = false
	fila.Parent             = costoFrame

	local lblRecurso = Instance.new("TextLabel")
	lblRecurso.Name          = "Recurso"
	lblRecurso.Size          = UDim2.new(0.42, 0, 1, 0)
	lblRecurso.BackgroundTransparency = 1
	lblRecurso.Font          = Enum.Font.Gotham
	lblRecurso.TextScaled    = true
	lblRecurso.TextColor3    = Color3.fromRGB(215, 215, 215)
	lblRecurso.TextXAlignment = Enum.TextXAlignment.Left
	lblRecurso.Parent        = fila

	local lblNecesita = Instance.new("TextLabel")
	lblNecesita.Name         = "Necesita"
	lblNecesita.Size         = UDim2.new(0.28, 0, 1, 0)
	lblNecesita.Position     = UDim2.new(0.42, 0, 0, 0)
	lblNecesita.BackgroundTransparency = 1
	lblNecesita.Font         = Enum.Font.Gotham
	lblNecesita.TextScaled   = true
	lblNecesita.TextColor3   = Color3.fromRGB(180, 180, 180)
	lblNecesita.TextXAlignment = Enum.TextXAlignment.Center
	lblNecesita.Parent       = fila

	local lblTienes = Instance.new("TextLabel")
	lblTienes.Name           = "Tienes"
	lblTienes.Size           = UDim2.new(0.3, 0, 1, 0)
	lblTienes.Position       = UDim2.new(0.7, 0, 0, 0)
	lblTienes.BackgroundTransparency = 1
	lblTienes.Font           = Enum.Font.GothamBold
	lblTienes.TextScaled     = true
	lblTienes.TextXAlignment = Enum.TextXAlignment.Right
	lblTienes.Parent         = fila

	filasCosto[i] = { fila = fila, recurso = lblRecurso, necesita = lblNecesita, tienes = lblTienes }
end

-- Zona desbloqueada (debajo del costo)
local lblZona = crearLabel("Desbloquea: Frostveil", 9,
	Enum.Font.Gotham, Color3.fromRGB(100, 195, 255))

-- ── BOTÓN DE MEJORA ──────────────────────────────────────────
crearSeparador(10)

local btnMejorar = Instance.new("TextButton")
btnMejorar.Name             = "BtnMejorar"
btnMejorar.Size             = UDim2.new(1, 0, 0, 44)
btnMejorar.BackgroundColor3 = Color3.fromRGB(35, 130, 55)
btnMejorar.Text             = "MEJORAR CAMPAMENTO"
btnMejorar.Font             = Enum.Font.GothamBold
btnMejorar.TextScaled       = true
btnMejorar.TextColor3       = Color3.fromRGB(255, 255, 255)
btnMejorar.LayoutOrder      = 11
btnMejorar.AutoButtonColor  = false
btnMejorar.Parent           = scrollBody

local cornerBtn = Instance.new("UICorner")
cornerBtn.CornerRadius = UDim.new(0, 8)
cornerBtn.Parent = btnMejorar

-- ── MENSAJE DE ESTADO ────────────────────────────────────────
local lblMensaje = Instance.new("TextLabel")
lblMensaje.Name               = "Mensaje"
lblMensaje.Size               = UDim2.new(1, 0, 0, 26)
lblMensaje.BackgroundTransparency = 1
lblMensaje.Text               = ""
lblMensaje.Font               = Enum.Font.GothamMedium
lblMensaje.TextScaled         = true
lblMensaje.TextColor3         = Color3.fromRGB(255, 75, 75)
lblMensaje.TextXAlignment     = Enum.TextXAlignment.Center
lblMensaje.TextWrapped        = true
lblMensaje.LayoutOrder        = 12
lblMensaje.Visible            = false
lblMensaje.Parent             = scrollBody

-- ── SECCIÓN: CONSTRUCCIONES ──────────────────────────────────
crearSeparador(13)
crearLabel("CONSTRUCCIONES:", 14, Enum.Font.GothamMedium, Color3.fromRGB(155, 150, 175))

-- Subtexto del costo de la mesa
local lblMesaCosto = Instance.new("TextLabel")
lblMesaCosto.Size               = UDim2.new(1, 0, 0, 16)
lblMesaCosto.BackgroundTransparency = 1
lblMesaCosto.Text               = "Mesa de Trabajo  ·  2 Madera + 2 Piedra"
lblMesaCosto.Font               = Enum.Font.Gotham
lblMesaCosto.TextScaled         = true
lblMesaCosto.TextColor3         = Color3.fromRGB(155, 150, 130)
lblMesaCosto.TextXAlignment     = Enum.TextXAlignment.Center
lblMesaCosto.LayoutOrder        = 15
lblMesaCosto.Parent             = scrollBody

-- Botón para construir la mesa
local btnMesa = Instance.new("TextButton")
btnMesa.Name             = "BtnMesa"
btnMesa.Size             = UDim2.new(1, 0, 0, 40)
btnMesa.BackgroundColor3 = Color3.fromRGB(80, 58, 28)
btnMesa.Text             = "CONSTRUIR MESA DE TRABAJO"
btnMesa.Font             = Enum.Font.GothamBold
btnMesa.TextScaled       = true
btnMesa.TextColor3       = Color3.fromRGB(255, 255, 255)
btnMesa.AutoButtonColor  = false
btnMesa.LayoutOrder      = 16
btnMesa.Parent           = scrollBody

local cornerBtnMesa = Instance.new("UICorner")
cornerBtnMesa.CornerRadius = UDim.new(0, 8)
cornerBtnMesa.Parent       = btnMesa

-- ── SECCIÓN: REABASTECER ILUMINACIÓN ─────────────────────────
crearSeparador(17)
crearLabel("ILUMINACION:", 18, Enum.Font.GothamMedium, Color3.fromRGB(155, 150, 175))

local lblIlumConteo = Instance.new("TextLabel")
lblIlumConteo.Size               = UDim2.new(1, 0, 0, 18)
lblIlumConteo.BackgroundTransparency = 1
lblIlumConteo.Text               = "Antorchas apagadas: 0  ·  Hogueras apagadas: 0"
lblIlumConteo.Font               = Enum.Font.Gotham
lblIlumConteo.TextScaled         = true
lblIlumConteo.TextColor3         = Color3.fromRGB(155, 150, 130)
lblIlumConteo.TextXAlignment     = Enum.TextXAlignment.Center
lblIlumConteo.LayoutOrder        = 19
lblIlumConteo.Parent             = scrollBody

local lblIlumCosto = Instance.new("TextLabel")
lblIlumCosto.Size               = UDim2.new(1, 0, 0, 16)
lblIlumCosto.BackgroundTransparency = 1
lblIlumCosto.Text               = "Costo: 0 Madera"
lblIlumCosto.Font               = Enum.Font.Gotham
lblIlumCosto.TextScaled         = true
lblIlumCosto.TextColor3         = Color3.fromRGB(185, 140, 75)
lblIlumCosto.TextXAlignment     = Enum.TextXAlignment.Center
lblIlumCosto.LayoutOrder        = 20
lblIlumCosto.Parent             = scrollBody

local btnReabastecer = Instance.new("TextButton")
btnReabastecer.Name             = "BtnReabastecer"
btnReabastecer.Size             = UDim2.new(1, 0, 0, 40)
btnReabastecer.BackgroundColor3 = Color3.fromRGB(45, 40, 20)
btnReabastecer.Text             = "REABASTECER ILUMINACION"
btnReabastecer.Font             = Enum.Font.GothamBold
btnReabastecer.TextScaled       = true
btnReabastecer.TextColor3       = Color3.fromRGB(255, 255, 255)
btnReabastecer.AutoButtonColor  = false
btnReabastecer.Active           = false
btnReabastecer.LayoutOrder      = 21
btnReabastecer.Parent           = scrollBody

local cornerBtnReab = Instance.new("UICorner")
cornerBtnReab.CornerRadius = UDim.new(0, 8)
cornerBtnReab.Parent       = btnReabastecer

local lblIlumMensaje = Instance.new("TextLabel")
lblIlumMensaje.Size               = UDim2.new(1, 0, 0, 26)
lblIlumMensaje.BackgroundTransparency = 1
lblIlumMensaje.Text               = ""
lblIlumMensaje.Font               = Enum.Font.GothamMedium
lblIlumMensaje.TextScaled         = true
lblIlumMensaje.TextColor3         = Color3.fromRGB(255, 75, 75)
lblIlumMensaje.TextXAlignment     = Enum.TextXAlignment.Center
lblIlumMensaje.TextWrapped        = true
lblIlumMensaje.LayoutOrder        = 22
lblIlumMensaje.Visible            = false
lblIlumMensaje.Parent             = scrollBody

-- ============================================================
-- Estado local del menú y la mesa
-- ============================================================
local menuAbierto      = false
local datosActuales    = nil   -- tabla enviada por el servidor
local mesaConstruida   = false
local COSTO_MESA       = { Madera = 2, Piedra = 2 }
local datosIluminacion = { antorchasApagadas = 0, hoguerasApagadas = 0, costoTotal = 0 }

-- ============================================================
-- Funciones de actualización
-- ============================================================

-- Comprueba si el inventario cubre todos los costos
local function puedeCostearse(inventario, costos)
	for recurso, cantidad in pairs(costos) do
		if (inventario[recurso] or 0) < cantidad then
			return false
		end
	end
	return true
end

-- Comprueba si el jugador posee todos los trébolees requeridos
local function puedeCostearseTreboles(treboles)
	for _, tipo in ipairs(treboles or {}) do
		if player:GetAttribute("Hoja" .. tipo) ~= true then
			return false
		end
	end
	return true
end

-- Actualiza la sección de iluminación con los datos recibidos del servidor
local function actualizarSeccionIluminacion(ilum)
	datosIluminacion = ilum or datosIluminacion
	local ant  = datosIluminacion.antorchasApagadas or 0
	local hog  = datosIluminacion.hoguerasApagadas  or 0
	local cost = datosIluminacion.costoTotal        or 0

	lblIlumConteo.Text = string.format("Antorchas apagadas: %d  ·  Hogueras apagadas: %d", ant, hog)
	lblIlumCosto.Text  = string.format("Costo: %d Madera", cost)

	local hayApagadas = (ant + hog) > 0
	btnReabastecer.Active           = hayApagadas
	btnReabastecer.BackgroundColor3 = hayApagadas
		and Color3.fromRGB(115, 90, 25)
		or  Color3.fromRGB(45, 40, 20)
	lblIlumMensaje.Visible = false
end

local function actualizarBtnMesa(inventario)
	if mesaConstruida then
		btnMesa.Text             = "✓  Mesa de Trabajo construida"
		btnMesa.BackgroundColor3 = Color3.fromRGB(30, 75, 35)
		btnMesa.Active           = false
		lblMesaCosto.Visible     = false
		return
	end
	lblMesaCosto.Visible  = true
	local puedePagar = puedeCostearse(inventario or {}, COSTO_MESA)
	btnMesa.Active           = puedePagar
	btnMesa.BackgroundColor3 = puedePagar
		and Color3.fromRGB(100, 72, 35)
		or  Color3.fromRGB(50, 40, 22)
end

btnMesa.MouseButton1Click:Connect(function()
	if not menuAbierto or not btnMesa.Active or mesaConstruida then return end
	btnMesa.Active = false
	local evMesa = carpetaEventos:FindFirstChild("SolicitarMesa")
	if evMesa then evMesa:FireServer() end
end)

-- Actualiza la sección de materiales con los valores actuales
local function actualizarInventarioUI(inventario, ordenDisplay, nombres)
	-- Determinar si el nivel actual requiere HojaTrebol
	local necesitaHoja = false
	if datosActuales and datosActuales.costos then
		local costosNivel = datosActuales.costos[datosActuales.nivel]
		if costosNivel and costosNivel.recursos and costosNivel.recursos.HojaTrebol then
			necesitaHoja = true
		end
	end
	filaHoja.Visible = necesitaHoja

	-- Actualizar cantidades
	for recurso, lbl in pairs(lblsCantidad) do
		lbl.Text = tostring(inventario[recurso] or 0)
	end

	-- Actualizar nombres con los del servidor (tienen tildes correctas)
	if nombres then
		for _, recurso in ipairs(RECURSOS_BASE) do
			local fila = matFrame:FindFirstChild("Fila_" .. recurso)
			if fila then
				local lblN = fila:FindFirstChild("TextLabel") or fila:FindFirstChildWhichIsA("TextLabel")
				-- Buscar el label de nombre (el que NO es "Cantidad")
				for _, child in ipairs(fila:GetChildren()) do
					if child:IsA("TextLabel") and child.Name ~= "Cantidad" then
						child.Text = nombres[recurso] or recurso
					end
				end
			end
		end
		lblHojaNombre.Text = nombres.HojaTrebol or "Hojas del Trebol"
	end
end

-- Rellena las filas de costo para el nivel actual (recursos + trébolees)
local function actualizarCostoUI(costos, inventario, nombres, ordenDisplay, treboles)
	-- Ocultar todas las filas primero
	for i = 1, MAX_COSTO do
		filasCosto[i].fila.Visible = false
	end

	local idx = 1
	-- Recursos materiales
	for _, recurso in ipairs(ordenDisplay or {}) do
		local cantidad = costos[recurso]
		if cantidad and idx <= MAX_COSTO then
			local tienes     = inventario[recurso] or 0
			local puedePagar = tienes >= cantidad
			local nombre     = (nombres and nombres[recurso]) or recurso
			local ref        = filasCosto[idx]

			ref.recurso.Text       = nombre
			ref.recurso.TextColor3 = Color3.fromRGB(215, 215, 215)
			ref.necesita.Text      = "Nec. " .. cantidad
			ref.tienes.Text        = "Tienes " .. tienes
			ref.tienes.TextColor3  = puedePagar
				and Color3.fromRGB(90, 220, 90)
				or  Color3.fromRGB(255, 70, 70)
			ref.fila.Visible = true
			idx = idx + 1
		end
	end

	-- Trébolees requeridos (se poseen, no se consumen)
	for _, tipo in ipairs(treboles or {}) do
		if idx <= MAX_COSTO then
			local tieneHoja = player:GetAttribute("Hoja" .. tipo) == true
			local cfg       = TrebolConfig.HOJAS[tipo]
			local nombre    = cfg and ("Hoja " .. cfg.nombre) or ("Hoja " .. tipo)
			local color     = cfg and cfg.color or Color3.fromRGB(80, 210, 80)
			local ref       = filasCosto[idx]

			ref.recurso.Text       = nombre
			ref.recurso.TextColor3 = color
			ref.necesita.Text      = "Requerida"
			ref.tienes.Text        = tieneHoja and "✓ Tienes" or "✗ Falta"
			ref.tienes.TextColor3  = tieneHoja
				and Color3.fromRGB(90, 220, 90)
				or  Color3.fromRGB(255, 70, 70)
			ref.fila.Visible = true
			idx = idx + 1
		end
	end
end

-- Abre y rellena el menú completo con datos del servidor
local function abrirMenu(datos)
	datosActuales = datos
	menuAbierto   = true
	lblMensaje.Visible = false

	-- Nivel
	lblNivelTitulo.Text = "Nivel " .. datos.nivel .. " / " .. datos.nivelMaximo

	-- Puntos indicadores  (# = relleno, o = vacío)
	local puntos = {}
	for i = 1, datos.nivelMaximo do
		table.insert(puntos, i <= datos.nivel and "#" or "o")
	end
	lblPuntos.Text = table.concat(puntos, " ")

	-- Inventario
	actualizarInventarioUI(datos.inventario, datos.ordenDisplay, datos.nombresRec)

	-- Costo / nivel máximo
	if datos.nivel >= datos.nivelMaximo then
		lblCostoTitulo.Text = "NIVEL MAXIMO ALCANZADO"
		costoFrame.Visible  = false
		lblZona.Visible     = false
		btnMejorar.Active   = false
		btnMejorar.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		btnMejorar.Text     = "NIVEL MAXIMO"
	else
		local datosNivel = datos.costos[datos.nivel]
		costoFrame.Visible = true
		lblZona.Visible    = true

		if datosNivel then
			lblCostoTitulo.Text = "PARA SUBIR A NIVEL " .. (datos.nivel + 1) .. ":"
			lblZona.Text        = "Desbloquea: " .. datosNivel.zona

			actualizarCostoUI(
				datosNivel.recursos,
				datos.inventario,
				datos.nombresRec,
				datos.ordenDisplay,
				datosNivel.treboles
			)

			local puede = puedeCostearse(datos.inventario, datosNivel.recursos)
				and puedeCostearseTreboles(datosNivel.treboles)
			btnMejorar.Active   = puede
			btnMejorar.BackgroundColor3 = puede
				and Color3.fromRGB(35, 130, 55)
				or  Color3.fromRGB(90, 45, 45)
			btnMejorar.Text = "MEJORAR CAMPAMENTO"
		end
	end

	-- Verificar si la mesa ya existe en el mundo
	mesaConstruida = workspace:FindFirstChild("MesaTrabajo") ~= nil
	actualizarBtnMesa(datos.inventario)

	-- Sección de iluminación
	if datos.iluminacion then
		actualizarSeccionIluminacion(datos.iluminacion)
	end

	marco.Visible = true
end

local function cerrarMenu()
	marco.Visible  = false
	menuAbierto    = false
	lblMensaje.Visible = false
end

-- ============================================================
-- Conexiones de eventos
-- ============================================================

btnCerrar.MouseButton1Click:Connect(cerrarMenu)

btnMejorar.MouseButton1Click:Connect(function()
	if not menuAbierto or not btnMejorar.Active then return end
	btnMejorar.Active = false
	evSolicitarMejora:FireServer()
	lblMensaje.Text       = "Enviando..."
	lblMensaje.TextColor3 = Color3.fromRGB(200, 200, 200)
	lblMensaje.Visible    = true
end)

-- Servidor abre el menú con datos frescos
evAbrirMenu.OnClientEvent:Connect(function(datos)
	abrirMenu(datos)
end)

-- Resultado de la solicitud de mejora
evResultadoMejora.OnClientEvent:Connect(function(resultado)
	btnMejorar.Active = true

	if resultado.exito then
		-- Actualizar datos con el nuevo nivel e inventario
		if datosActuales then
			datosActuales.nivel      = resultado.nuevoNivel
			datosActuales.inventario = resultado.inventario
			abrirMenu(datosActuales)
		end
		lblMensaje.Text       = resultado.mensaje or "Mejora completada!"
		lblMensaje.TextColor3 = Color3.fromRGB(90, 220, 90)
	else
		lblMensaje.Text       = resultado.mensaje or "Error desconocido."
		lblMensaje.TextColor3 = Color3.fromRGB(255, 70, 70)
	end
	lblMensaje.Visible = true
end)

-- Si el inventario cambia mientras el menú está abierto (recolectar mientras espera)
evInventarioActualizado.OnClientEvent:Connect(function(inventario)
	if not menuAbierto or not datosActuales then return end
	datosActuales.inventario = inventario
	actualizarInventarioUI(inventario, datosActuales.ordenDisplay, datosActuales.nombresRec)

	local datosNivel = datosActuales.costos and datosActuales.costos[datosActuales.nivel]
	if datosNivel then
		actualizarCostoUI(
			datosNivel.recursos, inventario,
			datosActuales.nombresRec, datosActuales.ordenDisplay,
			datosNivel.treboles
		)
		local puede = puedeCostearse(inventario, datosNivel.recursos)
			and puedeCostearseTreboles(datosNivel.treboles)
		btnMejorar.Active   = puede
		btnMejorar.BackgroundColor3 = puede
			and Color3.fromRGB(35, 130, 55)
			or  Color3.fromRGB(90, 45, 45)
	end
	-- También actualizar botón de mesa
	if not mesaConstruida then
		actualizarBtnMesa(inventario)
	end
end)

-- Resultado de la construcción de la mesa
-- Usamos task.spawn para no bloquear el script si Mesa.server aún no creó el evento
task.spawn(function()
	local evResultadoConstruccion = carpetaEventos:WaitForChild("ResultadoConstruccion")
	evResultadoConstruccion.OnClientEvent:Connect(function(resultado)
		if resultado.exito then
			mesaConstruida = true
			actualizarBtnMesa({})
		else
			-- Mostrar error en el mensaje de estado del menú
			if menuAbierto then
				lblMensaje.Text       = resultado.mensaje or "No se pudo construir la mesa."
				lblMensaje.TextColor3 = Color3.fromRGB(255, 70, 70)
				lblMensaje.Visible    = true
				btnMesa.Active        = true
			end
		end
	end)
end)

-- Notificación global cuando alguien mejora el campamento
evCampamentoActualizado.OnClientEvent:Connect(function(nuevoNivel, zona)
	-- Crear una notificación flotante temporal (igual que la alerta de noche)
	local notifGui = Instance.new("ScreenGui")
	notifGui.Name          = "CampNotif"
	notifGui.ResetOnSpawn  = false
	notifGui.Parent        = playerGui

	local notifFrame = Instance.new("Frame")
	notifFrame.Size               = UDim2.new(0, 380, 0, 56)
	notifFrame.AnchorPoint        = Vector2.new(0.5, 0)
	notifFrame.Position           = UDim2.new(0.5, 0, 0, 72)
	notifFrame.BackgroundColor3   = Color3.fromRGB(30, 85, 35)
	notifFrame.BackgroundTransparency = 0.12
	notifFrame.BorderSizePixel    = 0
	notifFrame.Parent             = notifGui

	local cornerNotif = Instance.new("UICorner")
	cornerNotif.CornerRadius = UDim.new(0, 10)
	cornerNotif.Parent = notifFrame

	local lblNotif = Instance.new("TextLabel")
	lblNotif.Size               = UDim2.new(1, 0, 1, 0)
	lblNotif.BackgroundTransparency = 1
	lblNotif.Text               = "Campamento Nv." .. nuevoNivel .. "  —  " .. zona .. " desbloqueada!"
	lblNotif.Font               = Enum.Font.GothamBold
	lblNotif.TextScaled         = true
	lblNotif.TextColor3         = Color3.fromRGB(110, 240, 110)
	lblNotif.Parent             = notifFrame

	-- Desaparecer tras 3 segundos
	task.delay(2.5, function()
		TweenService:Create(notifFrame, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(lblNotif,   TweenInfo.new(1), { TextTransparency = 1 }):Play()
		task.delay(1, function() notifGui:Destroy() end)
	end)
end)

-- Si el jugador obtiene una hoja mientras el menú está abierto, refrescar el costo
task.spawn(function()
	local evHoja = carpetaEventos:WaitForChild("HojaTrebolActualizada")
	evHoja.OnClientEvent:Connect(function()
		if not menuAbierto or not datosActuales then return end
		local datosNivel = datosActuales.costos and datosActuales.costos[datosActuales.nivel]
		if not datosNivel then return end
		actualizarCostoUI(
			datosNivel.recursos, datosActuales.inventario,
			datosActuales.nombresRec, datosActuales.ordenDisplay,
			datosNivel.treboles
		)
		local puede = puedeCostearse(datosActuales.inventario, datosNivel.recursos)
			and puedeCostearseTreboles(datosNivel.treboles)
		btnMejorar.Active   = puede
		btnMejorar.BackgroundColor3 = puede
			and Color3.fromRGB(35, 130, 55)
			or  Color3.fromRGB(90, 45, 45)
	end)
end)

-- Click en "Reabastecer iluminación"
btnReabastecer.MouseButton1Click:Connect(function()
	if not menuAbierto or not btnReabastecer.Active then return end
	btnReabastecer.Active = false
	evReabastecerIluminacion:FireServer()
	lblIlumMensaje.Text       = "Reabasteciendo..."
	lblIlumMensaje.TextColor3 = Color3.fromRGB(200, 200, 200)
	lblIlumMensaje.Visible    = true
end)

-- Resultado del reabastecimiento
evResultadoReabastecimiento.OnClientEvent:Connect(function(resultado)
	btnReabastecer.Active     = true
	lblIlumMensaje.Text       = resultado.mensaje or ""
	lblIlumMensaje.TextColor3 = resultado.exito
		and Color3.fromRGB(90, 220, 90)
		or  Color3.fromRGB(255, 70, 70)
	lblIlumMensaje.Visible = true
	-- Si fue exitoso, la iluminación quedó toda encendida
	if resultado.exito then
		actualizarSeccionIluminacion({ antorchasApagadas = 0, hoguerasApagadas = 0, costoTotal = 0 })
	end
end)

-- Feedback de ProximityPrompt individual (Madera insuficiente al presionar E)
evFeedbackIluminacion.OnClientEvent:Connect(function(mensaje)
	-- Notificación flotante temporal (mismo patrón que CampamentoActualizado)
	local notifGui = Instance.new("ScreenGui")
	notifGui.Name         = "IlumFeedback"
	notifGui.ResetOnSpawn = false
	notifGui.Parent       = playerGui

	local notifFrame = Instance.new("Frame")
	notifFrame.Size               = UDim2.new(0, 280, 0, 44)
	notifFrame.AnchorPoint        = Vector2.new(0.5, 0)
	notifFrame.Position           = UDim2.new(0.5, 0, 0, 72)
	notifFrame.BackgroundColor3   = Color3.fromRGB(100, 30, 30)
	notifFrame.BackgroundTransparency = 0.12
	notifFrame.BorderSizePixel    = 0
	notifFrame.Parent             = notifGui

	local cornerNotifIlum = Instance.new("UICorner")
	cornerNotifIlum.CornerRadius = UDim.new(0, 10)
	cornerNotifIlum.Parent = notifFrame

	local lblNotifIlum = Instance.new("TextLabel")
	lblNotifIlum.Size               = UDim2.new(1, 0, 1, 0)
	lblNotifIlum.BackgroundTransparency = 1
	lblNotifIlum.Text               = mensaje or ""
	lblNotifIlum.Font               = Enum.Font.GothamBold
	lblNotifIlum.TextScaled         = true
	lblNotifIlum.TextColor3         = Color3.fromRGB(255, 120, 120)
	lblNotifIlum.Parent             = notifFrame

	task.delay(2, function()
		TweenService:Create(notifFrame, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(lblNotifIlum, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		task.delay(0.8, function() notifGui:Destroy() end)
	end)
end)

print("[CampamentoUI] Menu de campamento listo.")
