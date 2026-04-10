-- SesionCampamento.luau  (ModuleScript en ServerScriptService/Server/)
-- Crea el campamento para una sesión en la posición con offset.
-- Función pública: M.crear(sesionId, offsetX, carpetaSesion, nivelCampamento)
-- nivelCampamento: NumberValue ya creado por SesionManager.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventarioManager = require(script.Parent:WaitForChild("InventarioManager"))
local TrebolManager     = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolManager"))
local TrebolConfig      = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolConfig"))
local Config            = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CampamentoConfig"))

local M = {}

-- ============================================================
-- Helper
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

-- Notificar a todos los jugadores de la sesión
local function notificarSesion(sesionId, evento, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("SesionActual") == sesionId then
			evento:FireClient(p, ...)
		end
	end
end

-- ============================================================
-- Función principal
-- ============================================================
function M.crear(sesionId, offsetX, carpetaSesion, nivelCampamento)
	local carpetaEventos          = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
	local evAbrirMenu             = obtenerOCrear(carpetaEventos, "RemoteEvent", "AbrirMenuCampamento")
	local evSolicitarMejora       = obtenerOCrear(carpetaEventos, "RemoteEvent", "SolicitarMejora")
	local evResultadoMejora       = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoMejora")
	local evCampamentoActualizado = obtenerOCrear(carpetaEventos, "RemoteEvent", "CampamentoActualizado")

	-- Posición del campamento para esta sesión
	local campPos = Vector3.new(offsetX + 0, 0, -20)

	local carpetaCamp = Instance.new("Folder")
	carpetaCamp.Name   = "CampamentoBase"
	carpetaCamp.Parent = carpetaSesion

	-- Plataforma
	local base = Instance.new("Part")
	base.Name      = "Base"
	base.Size      = Vector3.new(8, 0.5, 8)
	base.Position  = Vector3.new(campPos.X, 0.25, campPos.Z)
	base.Anchored  = true
	base.Color     = Color3.fromRGB(90, 65, 40)
	base.Material  = Enum.Material.WoodPlanks
	base.Parent    = carpetaCamp

	-- Hoguera
	local hoguera = Instance.new("Part")
	hoguera.Name       = "Hoguera"
	hoguera.Shape      = Enum.PartType.Ball
	hoguera.Size       = Vector3.new(1.8, 1.8, 1.8)
	hoguera.Position   = Vector3.new(campPos.X, 1.65, campPos.Z)
	hoguera.Anchored   = true
	hoguera.Color      = Color3.fromRGB(255, 115, 25)
	hoguera.Material   = Enum.Material.Neon
	hoguera.CanCollide = false
	hoguera.CastShadow = false
	hoguera.Parent     = carpetaCamp

	local luzFuego = Instance.new("PointLight")
	luzFuego.Brightness = 4
	luzFuego.Color      = Color3.fromRGB(255, 150, 50)
	luzFuego.Range      = 24
	luzFuego.Parent     = hoguera

	-- Registrar hoguera en HoguerasActivas de la sesión (para SesionEnemigos)
	local carpetaHogueras = obtenerOCrear(carpetaSesion, "Folder", "HoguerasActivas")
	local marcadorCamp    = Instance.new("Part")
	marcadorCamp.Name         = "RadioCampamento"
	marcadorCamp.Size         = Vector3.new(1, 1, 1)
	marcadorCamp.Anchored     = true
	marcadorCamp.CanCollide   = false
	marcadorCamp.Transparency = 1
	marcadorCamp.Position     = hoguera.Position
	marcadorCamp:SetAttribute("Radio", 20)
	marcadorCamp.Parent       = carpetaHogueras

	-- Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Size        = UDim2.new(0, 170, 0, 32)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent      = hoguera

	local lblBillboard = Instance.new("TextLabel")
	lblBillboard.Size                   = UDim2.new(1, 0, 1, 0)
	lblBillboard.BackgroundTransparency = 1
	lblBillboard.Text                   = "Campamento  Nv. 1"
	lblBillboard.Font                   = Enum.Font.GothamBold
	lblBillboard.TextScaled             = true
	lblBillboard.TextColor3             = Color3.fromRGB(255, 200, 60)
	lblBillboard.TextStrokeTransparency = 0.4
	lblBillboard.Parent                 = billboard

	-- ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Mejorar"
	prompt.ObjectText            = "Campamento  Nv. 1"
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = base

	nivelCampamento.Changed:Connect(function(nv)
		local texto = "Campamento  Nv. " .. nv
		prompt.ObjectText  = texto
		lblBillboard.Text  = texto
		if nv >= Config.NIVEL_MAXIMO then
			prompt.Enabled = false
		end
	end)

	-- Abrir menú
	prompt.Triggered:Connect(function(player)
		-- Solo jugadores de esta sesión pueden interactuar
		if player:GetAttribute("SesionActual") ~= sesionId then return end
		evAbrirMenu:FireClient(player, {
			nivel        = nivelCampamento.Value,
			nivelMaximo  = Config.NIVEL_MAXIMO,
			inventario   = InventarioManager.obtener(player),
			costos       = Config.COSTOS,
			nombresRec   = Config.NOMBRES,
			ordenDisplay = Config.ORDEN_DISPLAY,
		})
	end)

	-- Solicitud de mejora (múltiples sesiones pueden tener este handler, se filtra por sesión)
	evSolicitarMejora.OnServerEvent:Connect(function(player)
		-- Ignorar si el jugador no pertenece a esta sesión
		if player:GetAttribute("SesionActual") ~= sesionId then return end

		local nivelActual = nivelCampamento.Value

		if nivelActual >= Config.NIVEL_MAXIMO then
			evResultadoMejora:FireClient(player, {
				exito   = false,
				mensaje = "El campamento ya esta al nivel maximo.",
			})
			return
		end

		local datosNivel = Config.COSTOS[nivelActual]
		if not datosNivel then
			evResultadoMejora:FireClient(player, { exito = false, mensaje = "Error: nivel sin configurar." })
			return
		end

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

		local exito, recursoFaltante = InventarioManager.descontar(player, datosNivel.recursos)
		if not exito then
			local nombre = Config.NOMBRES[recursoFaltante] or recursoFaltante
			evResultadoMejora:FireClient(player, {
				exito   = false,
				mensaje = "Materiales insuficientes  (" .. nombre .. ")",
			})
			return
		end

		nivelCampamento.Value = nivelActual + 1
		local nuevoNivel = nivelCampamento.Value
		local zona       = datosNivel.zona

		evResultadoMejora:FireClient(player, {
			exito      = true,
			nuevoNivel = nuevoNivel,
			zona       = zona,
			inventario = InventarioManager.obtener(player),
			mensaje    = "Campamento mejorado!  Zona " .. zona .. " desbloqueada.",
		})

		notificarSesion(sesionId, evCampamentoActualizado, nuevoNivel, zona)

		print(string.format("[SesionCampamento] Sesion %d: %s mejoro a Nv.%d - %s.",
			sesionId, player.Name, nuevoNivel, zona))
	end)

	print(string.format("[SesionCampamento] Sesion %d: campamento creado en X=%d.", sesionId, offsetX))
end

return M
