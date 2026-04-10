-- [SESIONES] Este script fue reemplazado por el sistema de sesiones por grupo.
-- SesionManager.luau orquesta la creación de mundos por sesión.
do return end

-- Campamento.server.luau
-- Crea la hoguera del campamento, maneja el prompt de mejora,
-- valida y aplica el costo, y emite eventos a los clientes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

print("[Campamento] Cargando...")

local InventarioManager = require(script.Parent:WaitForChild("InventarioManager"))
local TrebolManager     = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolManager"))
local TrebolConfig      = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CampamentoConfig"))

print("[Campamento] Modulos cargados OK")

-- ============================================================
-- Eventos (reutiliza la carpeta creada por DayNightCycle)
-- ============================================================
local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(className)
		obj.Name   = nombre
		obj.Parent = parent
	end
	return obj
end

local carpetaEventos         = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evAbrirMenu            = obtenerOCrear(carpetaEventos, "RemoteEvent", "AbrirMenuCampamento")
local evSolicitarMejora      = obtenerOCrear(carpetaEventos, "RemoteEvent", "SolicitarMejora")
local evResultadoMejora      = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoMejora")
local evCampamentoActualizado = obtenerOCrear(carpetaEventos, "RemoteEvent", "CampamentoActualizado")

-- ============================================================
-- Nivel global: NumberValue en ReplicatedStorage
-- Otros scripts del servidor pueden leerlo con:
--   ReplicatedStorage:WaitForChild("NivelCampamento").Value
-- ============================================================
local nivelCampamento = Instance.new("NumberValue")
nivelCampamento.Name  = "NivelCampamento"
nivelCampamento.Value = 1
nivelCampamento.Parent = ReplicatedStorage

-- ============================================================
-- Estructura visual del campamento
-- ============================================================
local carpetaCamp = Instance.new("Folder")
carpetaCamp.Name   = "CampamentoBase"
carpetaCamp.Parent = Workspace

-- Plataforma de madera (suelo en Y=0, base de 0.5 de alto)
local base = Instance.new("Part")
base.Name     = "Base"
base.Size     = Vector3.new(8, 0.5, 8)
base.Position = Vector3.new(0, 0.25, -20)  -- alejado del spawn para no tapar al jugador
base.Anchored = true
base.Color    = Color3.fromRGB(90, 65, 40)
base.Material = Enum.Material.WoodPlanks
base.Parent   = carpetaCamp

-- Hoguera: esfera neon que representa el fuego
local hoguera = Instance.new("Part")
hoguera.Name      = "Hoguera"
hoguera.Shape     = Enum.PartType.Ball
hoguera.Size      = Vector3.new(1.8, 1.8, 1.8)
hoguera.Position  = Vector3.new(0, 1.65, -20)
hoguera.Anchored  = true
hoguera.Color     = Color3.fromRGB(255, 115, 25)
hoguera.Material  = Enum.Material.Neon
hoguera.CanCollide = false
hoguera.CastShadow = false
hoguera.Parent    = carpetaCamp

-- Luz puntual (visible especialmente de noche)
local luzFuego = Instance.new("PointLight")
luzFuego.Brightness = 4
luzFuego.Color      = Color3.fromRGB(255, 150, 50)
luzFuego.Range      = 24
luzFuego.Parent     = hoguera

-- Registrar hoguera base en HoguerasActivas para repeler corrompidos
local carpetaHogueras = obtenerOCrear(workspace, "Folder", "HoguerasActivas")
local marcadorCamp    = Instance.new("Part")
marcadorCamp.Name        = "RadioCampamento"
marcadorCamp.Size        = Vector3.new(1, 1, 1)
marcadorCamp.Anchored    = true
marcadorCamp.CanCollide  = false
marcadorCamp.Transparency = 1
marcadorCamp.Position    = hoguera.Position
marcadorCamp:SetAttribute("Radio", 20)
marcadorCamp.Parent      = carpetaHogueras

-- Etiqueta flotante sobre la hoguera
local billboard = Instance.new("BillboardGui")
billboard.Size         = UDim2.new(0, 170, 0, 32)
billboard.StudsOffset  = Vector3.new(0, 2.2, 0)
billboard.AlwaysOnTop  = false
billboard.Parent       = hoguera

local lblBillboard = Instance.new("TextLabel")
lblBillboard.Size                = UDim2.new(1, 0, 1, 0)
lblBillboard.BackgroundTransparency = 1
lblBillboard.Text                = "Campamento  Nv. 1"
lblBillboard.Font                = Enum.Font.GothamBold
lblBillboard.TextScaled          = true
lblBillboard.TextColor3          = Color3.fromRGB(255, 200, 60)
lblBillboard.TextStrokeTransparency = 0.4
lblBillboard.Parent              = billboard

-- ProximityPrompt en la base (el jugador presiona E al acercarse)
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText            = "Mejorar"
prompt.ObjectText            = "Campamento  Nv. 1"
prompt.KeyboardKeyCode       = Enum.KeyCode.E
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight   = false
prompt.Parent                = base

-- Sincronizar textos cuando el nivel cambia
nivelCampamento.Changed:Connect(function(nv)
	local texto = "Campamento  Nv. " .. nv
	prompt.ObjectText    = texto
	lblBillboard.Text    = texto
	if nv >= Config.NIVEL_MAXIMO then
		prompt.Enabled = false
	end
end)

-- ============================================================
-- Abrir menú: el servidor envía los datos al cliente que activó el prompt
-- ============================================================
prompt.Triggered:Connect(function(player)
	evAbrirMenu:FireClient(player, {
		nivel         = nivelCampamento.Value,
		nivelMaximo   = Config.NIVEL_MAXIMO,
		inventario    = InventarioManager.obtener(player),
		costos        = Config.COSTOS,
		nombresRec    = Config.NOMBRES,
		ordenDisplay  = Config.ORDEN_DISPLAY,
	})
end)

-- ============================================================
-- Solicitud de mejora desde el cliente
-- ============================================================
evSolicitarMejora.OnServerEvent:Connect(function(player)
	local nivelActual = nivelCampamento.Value

	-- Comprobaciones previas
	if nivelActual >= Config.NIVEL_MAXIMO then
		evResultadoMejora:FireClient(player, {
			exito   = false,
			mensaje = "El campamento ya esta al nivel maximo.",
		})
		return
	end

	local datosNivel = Config.COSTOS[nivelActual]
	if not datosNivel then
		evResultadoMejora:FireClient(player, {
			exito   = false,
			mensaje = "Error: nivel sin configurar.",
		})
		return
	end

	-- Validar trébolees requeridos (no se consumen, solo deben poseerse)
	local treboles = datosNivel.treboles or {}
	for _, tipo in ipairs(treboles) do
		if not TrebolManager.tieneHoja(player, tipo) then
			local nombreBioma = TrebolConfig.HOJAS[tipo] and TrebolConfig.HOJAS[tipo].nombre or tipo
			evResultadoMejora:FireClient(player, {
				exito   = false,
				mensaje = "Necesitas la Hoja del Trebol de " .. nombreBioma .. ".",
			})
			return
		end
	end

	-- Intentar descontar del inventario
	local exito, recursoFaltante = InventarioManager.descontar(player, datosNivel.recursos)

	if not exito then
		local nombre = Config.NOMBRES[recursoFaltante] or recursoFaltante
		evResultadoMejora:FireClient(player, {
			exito   = false,
			mensaje = "Materiales insuficientes  (" .. nombre .. ")",
		})
		return
	end

	-- Éxito: subir nivel
	nivelCampamento.Value = nivelActual + 1
	local nuevoNivel = nivelCampamento.Value
	local zona       = datosNivel.zona

	-- Responder al jugador con los datos actualizados
	evResultadoMejora:FireClient(player, {
		exito       = true,
		nuevoNivel  = nuevoNivel,
		zona        = zona,
		inventario  = InventarioManager.obtener(player),
		mensaje     = "Campamento mejorado!  Zona " .. zona .. " desbloqueada.",
	})

	-- Notificar el nuevo nivel a todos (para UI y futuros sistemas de zona)
	evCampamentoActualizado:FireAllClients(nuevoNivel, zona)

	print(string.format("[Campamento] %s mejoro el campamento a Nv.%d - %s desbloqueada.",
		player.Name, nuevoNivel, zona))
end)

print("[Campamento] Sistema de campamento base iniciado.")
