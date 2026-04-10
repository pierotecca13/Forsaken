-- InventarioUI.client.luau
-- Panel de inventario en la esquina inferior izquierda.
-- Muestra recursos, contador de slots y aviso "Inventario lleno".
-- Se actualiza con los eventos InventarioActualizado e InventarioLleno.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RecursosConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Eventos del servidor
local carpetaEventos          = ReplicatedStorage:WaitForChild("Eventos")
local evInventarioActualizado = carpetaEventos:WaitForChild("InventarioActualizado")
local evInventarioLleno       = carpetaEventos:WaitForChild("InventarioLleno")
local evCampamentoActualizado = carpetaEventos:WaitForChild("CampamentoActualizado")
local evDescartar             = carpetaEventos:WaitForChild("InventarioDescartar")
local evColocar               = carpetaEventos:WaitForChild("ColocarHerramienta")
local evVendajeActualizado    = carpetaEventos:WaitForChild("VendajeActualizado")

-- ============================================================
-- Panel principal (esquina inferior izquierda)
-- AnchorPoint (0,1) → la posición ancla la esquina inferior-izquierda
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "InventarioUI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

local marco = Instance.new("Frame")
marco.Name                   = "MarcoInventario"
marco.AnchorPoint            = Vector2.new(0, 1)           -- ancla esquina inferior-izquierda
marco.Size                   = UDim2.new(0, 165, 0, 200)   -- alto reducido para no llegar al ST bar
marco.Position               = UDim2.new(0, 12, 1, -12)    -- 12 px del borde izquierdo y del borde inferior
marco.BackgroundColor3       = Color3.fromRGB(10, 10, 15)
marco.BackgroundTransparency = 0.35
marco.BorderSizePixel        = 0
marco.Parent                 = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent       = marco

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(70, 70, 100)
stroke.Thickness = 1.5
stroke.Parent    = marco

local padding = Instance.new("UIPadding")
padding.PaddingLeft   = UDim.new(0, 10)
padding.PaddingRight  = UDim.new(0, 10)
padding.PaddingTop    = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent        = marco

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding   = UDim.new(0, 4)
layout.Parent    = marco

-- ── Título ──────────────────────────────────────────────────────
local titulo = Instance.new("TextLabel")
titulo.Name                  = "Titulo"
titulo.Size                  = UDim2.new(1, 0, 0, 20)
titulo.BackgroundTransparency = 1
titulo.Text                  = "INVENTARIO"
titulo.TextScaled            = true
titulo.Font                  = Enum.Font.GothamBold
titulo.TextColor3            = Color3.fromRGB(200, 200, 220)
titulo.TextXAlignment        = Enum.TextXAlignment.Left
titulo.LayoutOrder           = 0
titulo.Parent                = marco

-- ── Separador ───────────────────────────────────────────────────
local separador = Instance.new("Frame")
separador.Name             = "Separador"
separador.Size             = UDim2.new(1, 0, 0, 1)
separador.BackgroundColor3 = Color3.fromRGB(80, 80, 110)
separador.BorderSizePixel  = 0
separador.LayoutOrder      = 1
separador.Parent           = marco

-- ── Fila especial de Vendaje (fuera de slots normales) ──────────
local filaVendaje = Instance.new("Frame")
filaVendaje.Name                   = "FilaVendaje"
filaVendaje.Size                   = UDim2.new(1, 0, 0, 14)
filaVendaje.BackgroundTransparency = 1
filaVendaje.LayoutOrder            = 2
filaVendaje.Parent                 = marco

local lblVendaje = Instance.new("TextLabel")
lblVendaje.Size               = UDim2.new(1, 0, 1, 0)
lblVendaje.BackgroundTransparency = 1
lblVendaje.Text               = "🩹 Vendaje  0 / 2"
lblVendaje.TextScaled         = true
lblVendaje.Font               = Enum.Font.Gotham
lblVendaje.TextColor3         = Color3.fromRGB(200, 180, 220)
lblVendaje.TextXAlignment     = Enum.TextXAlignment.Left
lblVendaje.Parent             = filaVendaje

-- Notificación flotante cuando se recibe un vendaje
local function mostrarNotificacionVendaje()
	local notif = Instance.new("Frame")
	notif.Size             = UDim2.new(0, 210, 0, 38)
	notif.AnchorPoint      = Vector2.new(0.5, 0)
	notif.Position         = UDim2.new(0.5, 0, 0, 68)
	notif.BackgroundColor3 = Color3.fromRGB(240, 235, 255)
	notif.BackgroundTransparency = 1
	notif.BorderSizePixel  = 0
	notif.ZIndex           = 10
	notif.Parent           = screenGui

	local notifCorner = Instance.new("UICorner")
	notifCorner.CornerRadius = UDim.new(0, 8)
	notifCorner.Parent = notif

	local notifLbl = Instance.new("TextLabel")
	notifLbl.Size               = UDim2.new(1, -14, 1, 0)
	notifLbl.Position           = UDim2.new(0, 7, 0, 0)
	notifLbl.BackgroundTransparency = 1
	notifLbl.Text               = "🩹  ¡Vendaje recibido!"
	notifLbl.Font               = Enum.Font.GothamBold
	notifLbl.TextScaled         = true
	notifLbl.TextColor3         = Color3.fromRGB(90, 50, 160)
	notifLbl.TextXAlignment     = Enum.TextXAlignment.Left
	notifLbl.TextTransparency   = 1
	notifLbl.ZIndex             = 11
	notifLbl.Parent             = notif

	-- Fade in
	TweenService:Create(notif,    TweenInfo.new(0.3), { BackgroundTransparency = 0.08 }):Play()
	TweenService:Create(notifLbl, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()

	-- Fade out tras 2.5 s
	task.delay(2.5, function()
		TweenService:Create(notif,    TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(notifLbl, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.delay(0.55, function() notif:Destroy() end)
	end)
end

-- Actualizar fila de vendaje cuando el servidor notifica un cambio
local vendajesUI = 0
evVendajeActualizado.OnClientEvent:Connect(function(cantidad)
	lblVendaje.Text = "🩹 Vendaje  " .. cantidad .. " / 2"
	if cantidad > vendajesUI then
		mostrarNotificacionVendaje()
	end
	vendajesUI = cantidad
end)

-- Valor inicial desde el atributo del jugador (ya establecido por el servidor)
do
	local Players = game:GetService("Players")
	local inicial = Players.LocalPlayer:GetAttribute("Vendajes") or 0
	lblVendaje.Text = "🩹 Vendaje  " .. inicial .. " / 2"
	vendajesUI = inicial
end

-- ── Fila de mochila: etiqueta + barra visual + fracción ─────────
-- La barra comunica visualmente "qué tan llena está la mochila"
-- sin necesitar entender la math de stacks/slots.
local filaMochila = Instance.new("Frame")
filaMochila.Name                   = "FilaMochila"
filaMochila.Size                   = UDim2.new(1, 0, 0, 18)
filaMochila.BackgroundTransparency = 1
filaMochila.LayoutOrder            = 3
filaMochila.Parent                 = marco

-- Etiqueta "Mochila"
local lblMochilaNombre = Instance.new("TextLabel")
lblMochilaNombre.Size               = UDim2.new(0, 48, 1, 0)
lblMochilaNombre.BackgroundTransparency = 1
lblMochilaNombre.Text               = "Mochila"
lblMochilaNombre.TextScaled         = true
lblMochilaNombre.Font               = Enum.Font.Gotham
lblMochilaNombre.TextColor3         = Color3.fromRGB(160, 160, 190)
lblMochilaNombre.TextXAlignment     = Enum.TextXAlignment.Left
lblMochilaNombre.Parent             = filaMochila

-- Fondo de la barra (gris oscuro)
local barraFondoMochila = Instance.new("Frame")
barraFondoMochila.Size             = UDim2.new(1, -88, 0, 10)
barraFondoMochila.Position         = UDim2.new(0, 52, 0.5, -5)
barraFondoMochila.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
barraFondoMochila.BorderSizePixel  = 0
barraFondoMochila.Parent           = filaMochila

local cornerBarraFM = Instance.new("UICorner")
cornerBarraFM.CornerRadius = UDim.new(1, 0)
cornerBarraFM.Parent       = barraFondoMochila

-- Relleno de la barra (color dinámico según ocupación)
local barraRellenoMochila = Instance.new("Frame")
barraRellenoMochila.Name             = "Relleno"
barraRellenoMochila.Size             = UDim2.new(0, 0, 1, 0)
barraRellenoMochila.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
barraRellenoMochila.BorderSizePixel  = 0
barraRellenoMochila.Parent           = barraFondoMochila

local cornerBarraRM = Instance.new("UICorner")
cornerBarraRM.CornerRadius = UDim.new(1, 0)
cornerBarraRM.Parent       = barraRellenoMochila

-- Fracción pequeña a la derecha (ej. "3/10")
local lblFraccion = Instance.new("TextLabel")
lblFraccion.Name                 = "Fraccion"
lblFraccion.Size                 = UDim2.new(0, 32, 1, 0)
lblFraccion.Position             = UDim2.new(1, -32, 0, 0)
lblFraccion.BackgroundTransparency = 1
lblFraccion.Text                 = "0/10"
lblFraccion.TextScaled           = true
lblFraccion.Font                 = Enum.Font.GothamBold
lblFraccion.TextColor3           = Color3.fromRGB(200, 200, 200)
lblFraccion.TextXAlignment       = Enum.TextXAlignment.Right
lblFraccion.Parent               = filaMochila

-- ── ScrollingFrame para la lista de recursos ───────────────────
-- El título y la barra Mochila quedan siempre visibles arriba;
-- los recursos se pueden desplazar sin que el panel crezca.

local sepScrollHeader = Instance.new("Frame")
sepScrollHeader.Size             = UDim2.new(1, 0, 0, 1)
sepScrollHeader.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
sepScrollHeader.BorderSizePixel  = 0
sepScrollHeader.LayoutOrder      = 4   -- desplazado para dejar espacio a filaMochila (3)
sepScrollHeader.Parent           = marco

local scrollRecursos = Instance.new("ScrollingFrame")
scrollRecursos.Name                   = "ScrollRecursos"
scrollRecursos.Size                   = UDim2.new(1, 0, 0, 110)
scrollRecursos.BackgroundTransparency = 1
scrollRecursos.BorderSizePixel        = 0
scrollRecursos.ScrollBarThickness     = 3
scrollRecursos.ScrollBarImageColor3   = Color3.fromRGB(90, 90, 130)
scrollRecursos.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scrollRecursos.CanvasSize             = UDim2.new(0, 0, 0, 0)
scrollRecursos.ScrollingDirection     = Enum.ScrollingDirection.Y
scrollRecursos.LayoutOrder            = 5   -- desplazado tras sepScrollHeader
scrollRecursos.Parent                 = marco

local layoutScroll = Instance.new("UIListLayout")
layoutScroll.SortOrder = Enum.SortOrder.LayoutOrder
layoutScroll.Padding   = UDim.new(0, 4)
layoutScroll.Parent    = scrollRecursos

-- Margen derecho para que el scrollbar no tape los números
local paddingScroll = Instance.new("UIPadding")
paddingScroll.PaddingRight = UDim.new(0, 6)
paddingScroll.Parent       = scrollRecursos

-- ── Filas de recursos ───────────────────────────────────────────

local COLORES_RECURSO = {
	-- Materiales
	Madera   = Color3.fromRGB(180, 140, 80),
	Piedra   = Color3.fromRGB(160, 160, 175),
	Hongos   = Color3.fromRGB(190, 110, 220),
	Piel     = Color3.fromRGB(210, 165, 100),
	Colmillo = Color3.fromRGB(240, 230, 200),
	Garra    = Color3.fromRGB(160, 110, 55),
	-- Comida (tonos rojizos)
	CarneConejo = Color3.fromRGB(230, 175, 155),
	CarneZorro  = Color3.fromRGB(215, 140, 110),
	CarneLobo   = Color3.fromRGB(185, 90,  75),
	CarneOso    = Color3.fromRGB(150, 55,  45),
	-- Herramientas (tonos amarillo-verdosos)
	Antorcha    = Color3.fromRGB(240, 210, 80),
	Hoguera     = Color3.fromRGB(255, 160, 40),
}

-- filasRecurso["Madera"] = TextLabel de la cantidad
local filasRecurso  = {}
local framosRecurso = {}   -- framosRecurso["Madera"] = Frame de la fila completa

-- Declaraciones adelantadas usadas en closures del loop de filas
local abrirPopupDescarte
local abrirPopupHerramienta
local sepComida, sepHerramientas  -- separadores de sección (visibles solo cuando hay items)

-- Índices donde empiezan las secciones especiales dentro de ORDEN_INVENTARIO
local primerComidaIdx       = #Config.ORDEN_INVENTARIO - #Config.ORDEN_COMIDA - #Config.ORDEN_HERRAMIENTAS + 1
local primerHerramientaIdx  = #Config.ORDEN_INVENTARIO - #Config.ORDEN_HERRAMIENTAS + 1
local separadorComidaAgregado      = false
local separadorHerramientaAgregado = false

for i, nombreRecurso in ipairs(Config.ORDEN_INVENTARIO) do

	-- Insertar separador "─ COMIDA ─" antes del primer alimento
	if i == primerComidaIdx and not separadorComidaAgregado then
		separadorComidaAgregado = true

		local sepC = Instance.new("TextLabel")
		sepC.Name                  = "SeparadorComida"
		sepC.Size                  = UDim2.new(1, 0, 0, 11)
		sepC.BackgroundTransparency = 1
		sepC.Text                  = "─  COMIDA  ─"
		sepC.TextScaled            = true
		sepC.Font                  = Enum.Font.Gotham
		sepC.TextColor3            = Color3.fromRGB(180, 100, 80)
		sepC.TextXAlignment        = Enum.TextXAlignment.Center
		sepC.LayoutOrder           = i + 2   -- justo antes de las filas de comida
		sepC.Visible               = false   -- oculto hasta que haya al menos un alimento
		sepC.Parent                = scrollRecursos
		sepComida = sepC
	end

	-- Insertar separador "─ HERRAMIENTAS ─" antes de la primera herramienta
	if i == primerHerramientaIdx and not separadorHerramientaAgregado then
		separadorHerramientaAgregado = true

		local sepH = Instance.new("TextLabel")
		sepH.Name                  = "SeparadorHerramientas"
		sepH.Size                  = UDim2.new(1, 0, 0, 11)
		sepH.BackgroundTransparency = 1
		sepH.Text                  = "─  HERRAMIENTAS  ─"
		sepH.TextScaled            = true
		sepH.Font                  = Enum.Font.Gotham
		sepH.TextColor3            = Color3.fromRGB(140, 155, 100)
		sepH.TextXAlignment        = Enum.TextXAlignment.Center
		sepH.LayoutOrder           = i + 3   -- entre comida y herramientas
		sepH.Visible               = false   -- oculto hasta que haya al menos una herramienta
		sepH.Parent                = scrollRecursos
		sepHerramientas = sepH
	end

	-- Orden real: +1 si es comida (sep comida), +2 si es herramienta (sep comida + sep herram)
	local esHerramienta = i >= primerHerramientaIdx
	local esComida      = i >= primerComidaIdx and not esHerramienta
	local orden
	if esHerramienta then
		orden = i + 4
	elseif esComida then
		orden = i + 3
	else
		orden = i + 2
	end

	local fila = Instance.new("Frame")
	fila.Name                   = "Fila_" .. nombreRecurso
	fila.Size                   = UDim2.new(1, 0, 0, 18)
	fila.BackgroundTransparency = 1
	fila.LayoutOrder            = orden
	fila.Parent                 = scrollRecursos

	local lblNombre = Instance.new("TextLabel")
	lblNombre.Size               = UDim2.new(0.75, 0, 1, 0)
	lblNombre.BackgroundTransparency = 1
	lblNombre.Text               = Config.ICONOS[nombreRecurso] .. " " .. nombreRecurso
	lblNombre.TextScaled         = true
	lblNombre.Font               = Enum.Font.Gotham
	lblNombre.TextColor3         = COLORES_RECURSO[nombreRecurso] or Color3.fromRGB(220, 220, 220)
	lblNombre.TextXAlignment     = Enum.TextXAlignment.Left
	lblNombre.Parent             = fila

	local lblCantidad = Instance.new("TextLabel")
	lblCantidad.Name             = "Cantidad"
	lblCantidad.Size             = UDim2.new(0.25, 0, 1, 0)
	lblCantidad.Position         = UDim2.new(0.75, 0, 0, 0)
	lblCantidad.BackgroundTransparency = 1
	lblCantidad.Text             = "0"
	lblCantidad.TextScaled       = true
	lblCantidad.Font             = Enum.Font.GothamBold
	lblCantidad.TextColor3       = Color3.fromRGB(255, 255, 255)
	lblCantidad.TextXAlignment   = Enum.TextXAlignment.Right
	lblCantidad.Parent           = fila

	-- Comida y herramientas se ocultan al inicio; aparecen en cuanto el jugador las tiene
	local esComiOHerr = table.find(Config.ORDEN_COMIDA, nombreRecurso)
		or table.find(Config.ORDEN_HERRAMIENTAS, nombreRecurso)
		or table.find(Config.ORDEN_MINERALES_AVZ, nombreRecurso)
	if esComiOHerr then
		fila.Visible = false
	end

	-- Botón transparente sobre la fila para capturar clics (mouse y móvil)
	local btnClick = Instance.new("TextButton")
	btnClick.Size                   = UDim2.new(1, 0, 1, 0)
	btnClick.BackgroundTransparency = 1
	btnClick.Text                   = ""
	btnClick.ZIndex                 = 3
	btnClick.Parent                 = fila

	local recursoLocal    = nombreRecurso  -- closure para capturar el recurso de esta fila
	local esHerramienta = table.find(Config.ORDEN_HERRAMIENTAS, nombreRecurso) ~= nil
	btnClick.MouseButton1Click:Connect(function()
		local cantidad = tonumber(filasRecurso[recursoLocal] and filasRecurso[recursoLocal].Text) or 0
		if cantidad <= 0 then return end
		if esHerramienta then
			abrirPopupHerramienta(recursoLocal)
		else
			abrirPopupDescarte(recursoLocal, cantidad)
		end
	end)

	framosRecurso[nombreRecurso] = fila
	filasRecurso[nombreRecurso]  = lblCantidad
end

-- ============================================================
-- Notificación "Inventario lleno"
-- Aparece encima del panel y desaparece sola
-- ============================================================

local guiNotif = Instance.new("ScreenGui")
guiNotif.Name          = "InventarioNotif"
guiNotif.ResetOnSpawn  = false
guiNotif.DisplayOrder  = 15
guiNotif.Parent        = playerGui

local lblNotif = Instance.new("TextLabel")
lblNotif.Name                  = "MensajeLleno"
lblNotif.AnchorPoint           = Vector2.new(0.5, 1)
lblNotif.Size                  = UDim2.new(0, 180, 0, 28)
lblNotif.Position              = UDim2.new(0.5, 0, 0.88, 0)  -- centro-inferior, independiente del alto del panel
lblNotif.BackgroundColor3      = Color3.fromRGB(180, 40, 40)
lblNotif.BackgroundTransparency = 0.2
lblNotif.BorderSizePixel       = 0
lblNotif.Text                  = "Inventario lleno"
lblNotif.Font                  = Enum.Font.GothamBold
lblNotif.TextScaled            = true
lblNotif.TextColor3            = Color3.fromRGB(255, 230, 230)
lblNotif.TextXAlignment        = Enum.TextXAlignment.Center
lblNotif.Visible               = false
lblNotif.Parent                = guiNotif

local cornerNotif = Instance.new("UICorner")
cornerNotif.CornerRadius = UDim.new(0, 6)
cornerNotif.Parent       = lblNotif

-- ============================================================
-- Popup de descarte (se crea una vez y se reutiliza)
-- ============================================================

local guiDescarte = Instance.new("ScreenGui")
guiDescarte.Name         = "DescartarUI"
guiDescarte.ResetOnSpawn = false
guiDescarte.DisplayOrder = 30
guiDescarte.Parent       = playerGui

local popupFrame = Instance.new("Frame")
popupFrame.Name                   = "Popup"
popupFrame.Size                   = UDim2.new(0, 210, 0, 120)
popupFrame.AnchorPoint            = Vector2.new(0.5, 0.5)
popupFrame.Position               = UDim2.new(0.5, 0, 0.5, 0)
popupFrame.BackgroundColor3       = Color3.fromRGB(12, 12, 18)
popupFrame.BackgroundTransparency = 0.15
popupFrame.BorderSizePixel        = 0
popupFrame.Visible                = false
popupFrame.Parent                 = guiDescarte

local _pc = Instance.new("UICorner")
_pc.CornerRadius = UDim.new(0, 10)
_pc.Parent       = popupFrame

local _ps = Instance.new("UIStroke")
_ps.Color     = Color3.fromRGB(80, 80, 120)
_ps.Thickness = 1.5
_ps.Parent    = popupFrame

-- Título: "[ícono] Recurso ×N"
local popupTitulo = Instance.new("TextLabel")
popupTitulo.Name                   = "Titulo"
popupTitulo.Size                   = UDim2.new(1, -12, 0, 28)
popupTitulo.Position               = UDim2.new(0, 6, 0, 6)
popupTitulo.BackgroundTransparency = 1
popupTitulo.Text                   = ""
popupTitulo.TextColor3             = Color3.fromRGB(220, 220, 240)
popupTitulo.TextScaled             = true
popupTitulo.Font                   = Enum.Font.GothamBold
popupTitulo.Parent                 = popupFrame

-- Fila de botones de cantidad
local filaBtn = Instance.new("Frame")
filaBtn.Size                   = UDim2.new(1, -12, 0, 30)
filaBtn.Position               = UDim2.new(0, 6, 0, 40)
filaBtn.BackgroundTransparency = 1
filaBtn.Parent                 = popupFrame

local layoutBtn = Instance.new("UIListLayout")
layoutBtn.FillDirection = Enum.FillDirection.Horizontal
layoutBtn.Padding       = UDim.new(0, 5)
layoutBtn.Parent        = filaBtn

local function crearBotonDescarte(texto, color)
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(0, 58, 1, 0)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel  = 0
	btn.Text             = texto
	btn.TextColor3       = Color3.fromRGB(240, 240, 240)
	btn.TextScaled       = true
	btn.Font             = Enum.Font.GothamBold
	btn.AutoButtonColor  = false
	btn.Parent           = filaBtn
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent       = btn
	return btn
end

local btnUno    = crearBotonDescarte("×1",      Color3.fromRGB(60, 80, 120))
local btnDiez   = crearBotonDescarte("×10",     Color3.fromRGB(80, 60, 120))
local btnTodo   = crearBotonDescarte("Todo",    Color3.fromRGB(120, 50, 50))
local btnColocar = crearBotonDescarte("Colocar", Color3.fromRGB(40, 110, 60))
btnColocar.Size    = UDim2.new(1, 0, 1, 0)  -- ocupa todo el ancho cuando está solo
btnColocar.Visible = false

-- Botón cancelar (fila inferior, centrado)
local btnCancelar = Instance.new("TextButton")
btnCancelar.Size             = UDim2.new(1, -12, 0, 24)
btnCancelar.Position         = UDim2.new(0, 6, 0, 82)
btnCancelar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
btnCancelar.BorderSizePixel  = 0
btnCancelar.Text             = "Cancelar"
btnCancelar.TextColor3       = Color3.fromRGB(160, 160, 180)
btnCancelar.TextScaled       = true
btnCancelar.Font             = Enum.Font.Gotham
btnCancelar.AutoButtonColor  = false
btnCancelar.Parent           = popupFrame
local _cc = Instance.new("UICorner")
_cc.CornerRadius = UDim.new(0, 6)
_cc.Parent       = btnCancelar

-- Estado del popup
local recursoActivo  = nil
local cantidadActiva = 0

local function cerrarPopup()
	popupFrame.Visible = false
	recursoActivo      = nil
	cantidadActiva     = 0
end

abrirPopupDescarte = function(recurso, cantidad)
	recursoActivo  = recurso
	cantidadActiva = cantidad
	local icono = Config.ICONOS[recurso] or ""
	popupTitulo.Text   = icono .. " " .. recurso .. "  ×" .. cantidad
	-- Mostrar botones de cantidad, ocultar botón colocar
	btnUno.Visible    = true
	btnDiez.Visible   = true
	btnTodo.Visible   = true
	btnColocar.Visible = false
	popupFrame.Visible = true
end

abrirPopupHerramienta = function(recurso)
	recursoActivo  = recurso
	cantidadActiva = 1
	local icono = Config.ICONOS[recurso] or ""
	popupTitulo.Text = icono .. " " .. recurso
	-- Mostrar solo el botón colocar, ocultar botones de cantidad
	btnUno.Visible    = false
	btnDiez.Visible   = false
	btnTodo.Visible   = false
	btnColocar.Visible = true
	popupFrame.Visible = true
end

btnUno.MouseButton1Click:Connect(function()
	if not recursoActivo then return end
	evDescartar:FireServer(recursoActivo, 1)
	cerrarPopup()
end)

btnDiez.MouseButton1Click:Connect(function()
	if not recursoActivo then return end
	evDescartar:FireServer(recursoActivo, math.min(10, cantidadActiva))
	cerrarPopup()
end)

btnTodo.MouseButton1Click:Connect(function()
	if not recursoActivo then return end
	evDescartar:FireServer(recursoActivo, cantidadActiva)
	cerrarPopup()
end)

btnCancelar.MouseButton1Click:Connect(cerrarPopup)

btnColocar.MouseButton1Click:Connect(function()
	if not recursoActivo then return end
	evColocar:FireServer(recursoActivo)
	cerrarPopup()
end)

-- ── Animación de bump cuando sube un recurso ────────────────────
local function animarCambio(label)
	TweenService:Create(
		label,
		TweenInfo.new(0.12),
		{ TextColor3 = Color3.fromRGB(255, 230, 80) }
	):Play()

	task.delay(0.12, function()
		TweenService:Create(
			label,
			TweenInfo.new(0.25),
			{ TextColor3 = Color3.fromRGB(255, 255, 255) }
		):Play()
	end)
end

-- ── Mostrar aviso "Inventario lleno" ────────────────────────────
local notifActiva = false
local function mostrarInventarioLleno()
	if notifActiva then return end
	notifActiva       = true
	lblNotif.Visible  = true
	lblNotif.BackgroundTransparency = 0.2

	-- Fade out después de 2 segundos
	task.delay(1.8, function()
		TweenService:Create(
			lblNotif,
			TweenInfo.new(0.4),
			{ BackgroundTransparency = 1, TextTransparency = 1 }
		):Play()
		task.delay(0.45, function()
			lblNotif.Visible          = false
			lblNotif.TextTransparency = 0
			notifActiva               = false
		end)
	end)
end

-- ============================================================
-- Actualizar UI cuando el servidor envía el inventario
-- Recibe: inventario (tabla), slotsUsados (número), slotsMaximos (número)
-- ============================================================
evInventarioActualizado.OnClientEvent:Connect(function(inventario, slotsUsados, slotsMaximos)
	-- Actualizar filas de recursos
	for nombreRecurso, label in pairs(filasRecurso) do
		local valorNuevo  = inventario[nombreRecurso] or 0
		local valorActual = tonumber(label.Text) or 0

		label.Text = tostring(valorNuevo)

		if valorNuevo > valorActual then
			animarCambio(label)
		end

		-- Mostrar/ocultar filas de comida y herramientas según si el jugador las tiene
		local esComiOHerr = table.find(Config.ORDEN_COMIDA, nombreRecurso)
			or table.find(Config.ORDEN_HERRAMIENTAS, nombreRecurso)
		if esComiOHerr and framosRecurso[nombreRecurso] then
			framosRecurso[nombreRecurso].Visible = valorNuevo > 0
		end
	end

	-- Visibilidad de separadores: solo si al menos un item de esa categoría existe
	if sepComida then
		local hayComida = false
		for _, r in ipairs(Config.ORDEN_COMIDA) do
			if (inventario[r] or 0) > 0 then hayComida = true; break end
		end
		sepComida.Visible = hayComida
	end
	if sepHerramientas then
		local hayHerr = false
		for _, r in ipairs(Config.ORDEN_HERRAMIENTAS) do
			if (inventario[r] or 0) > 0 then hayHerr = true; break end
		end
		sepHerramientas.Visible = hayHerr
	end

	-- Actualizar barra de mochila
	local maxMostrar = slotsMaximos or 10
	local usados     = slotsUsados  or 0
	local pct        = math.clamp((maxMostrar > 0) and (usados / maxMostrar) or 0, 0, 1)

	-- Animar la barra con tween suave
	TweenService:Create(
		barraRellenoMochila,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad),
		{ Size = UDim2.new(pct, 0, 1, 0) }
	):Play()

	-- Color dinámico: verde → amarillo → rojo
	if pct >= 1 then
		barraRellenoMochila.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
	elseif pct >= 0.75 then
		barraRellenoMochila.BackgroundColor3 = Color3.fromRGB(220, 175, 35)
	else
		barraRellenoMochila.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
	end

	-- Fracción numérica secundaria
	lblFraccion.Text = usados .. "/" .. maxMostrar
end)

-- Aviso cuando el inventario rechaza un ítem
evInventarioLleno.OnClientEvent:Connect(mostrarInventarioLleno)

-- Actualizar slots máximos al subir nivel del campamento
-- (el server envía el inventario completo al mejorar, pero actualizamos el
--  máximo aquí también para que sea inmediato si llega antes que el inventario)
evCampamentoActualizado.OnClientEvent:Connect(function(nuevoNivel)
	-- Actualizar la fracción de la barra con el nuevo máximo
	-- (el servidor enviará InventarioActualizado poco después con el valor exacto)
	local maxNuevo = Config.SLOTS_POR_NIVEL[nuevoNivel] or 10
	local usados   = tonumber(lblFraccion.Text:match("^(%d+)")) or 0
	lblFraccion.Text = usados .. "/" .. maxNuevo
end)

print("[InventarioUI] Panel de inventario activo.")
