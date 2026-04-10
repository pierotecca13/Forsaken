-- SesionCofreAlm.luau  (ModuleScript en ServerScriptService/Server/)
-- Gestiona el cofre de almacenamiento por jugador.
-- API pública:
--   M.inicializar()           → conecta handlers de eventos (llamar una vez al arrancar)
--   M.limpiarJugador(player)  → destruye cofre y limpia estado al salir del juego/sesión

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventarioMgr   = require(script.Parent:WaitForChild("InventarioManager"))
local CofreAlmConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CofreAlmConfig"))

local M = {}

-- ============================================================
-- Estado por jugador
-- ============================================================
-- cofresAlm[player] = { cofre = { [recurso] = cantidad }, modelo = Instance }
local cofresAlm = {}

-- ============================================================
-- Helpers
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

local function esAlmacenable(recurso)
	for _, r in ipairs(CofreAlmConfig.ITEMS_ALMACENABLES) do
		if r == recurso then return true end
	end
	return false
end

local function calcularSlotsMax(player)
	local sesionId = player:GetAttribute("SesionActual")
	if not sesionId then return CofreAlmConfig.SLOTS_BASE end
	local sesFolder = ReplicatedStorage:FindFirstChild("Sesiones")
		and ReplicatedStorage.Sesiones:FindFirstChild("Sesion_" .. sesionId)
	if not sesFolder then return CofreAlmConfig.SLOTS_BASE end
	local nv = sesFolder:FindFirstChild("NivelCampamento")
	local nivel = nv and nv.Value or 1
	return CofreAlmConfig.SLOTS_POR_NIVEL[nivel] or CofreAlmConfig.SLOTS_BASE
end

-- Calcula cuántos slots físicos ocupa un cofre (cada slot = MAX_POR_SLOT unidades)
local function calcularSlotsEnCofre(cofre)
	local total = 0
	for _, cant in pairs(cofre) do
		total += math.ceil(cant / CofreAlmConfig.MAX_POR_SLOT)
	end
	return total
end

-- ============================================================
-- Crear modelo físico del cofre en la sesión del jugador
-- ============================================================
local function crearModeloFisico(offsetX, carpetaSesion, playerName)
	local posBase = Vector3.new(offsetX + CofreAlmConfig.OFFSET_COFRE.X, 0, -20)

	local modelo = Instance.new("Model")
	modelo.Name   = "CofreAlm_" .. playerName
	modelo.Parent = carpetaSesion

	local cuerpo = Instance.new("Part")
	cuerpo.Name       = "Cuerpo"
	cuerpo.Size       = Vector3.new(2, 1.2, 1.2)
	cuerpo.CFrame     = CFrame.new(posBase + Vector3.new(0, 0.6 + 1.2 / 2, 0))
	cuerpo.Anchored   = true
	cuerpo.CanCollide = true
	cuerpo.Color      = Color3.fromRGB(60, 40, 25)
	cuerpo.Material   = Enum.Material.Wood
	cuerpo.Parent     = modelo
	modelo.PrimaryPart = cuerpo

	local tapa = Instance.new("Part")
	tapa.Name       = "Tapa"
	tapa.Size       = Vector3.new(2.05, 0.35, 1.25)
	tapa.CFrame     = CFrame.new(posBase + Vector3.new(0, 0.6 + 1.2 + 0.35 / 2, 0))
	tapa.Anchored   = true
	tapa.CanCollide = false
	tapa.Color      = Color3.fromRGB(75, 52, 32)
	tapa.Material   = Enum.Material.Wood
	tapa.Parent     = modelo

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0  = cuerpo
	soldadura.Part1  = tapa
	soldadura.Parent = cuerpo

	-- Cerrojo decorativo
	local cerrojo = Instance.new("Part")
	cerrojo.Name       = "Cerrojo"
	cerrojo.Size       = Vector3.new(0.3, 0.3, 0.15)
	cerrojo.CFrame     = CFrame.new(posBase + Vector3.new(0, 0.6 + 1.05, -0.6))
	cerrojo.Anchored   = true
	cerrojo.CanCollide = false
	cerrojo.Color      = Color3.fromRGB(180, 140, 60)
	cerrojo.Material   = Enum.Material.Metal
	cerrojo.Parent     = modelo

	local soldCerrojo = Instance.new("WeldConstraint")
	soldCerrojo.Part0  = cuerpo
	soldCerrojo.Part1  = cerrojo
	soldCerrojo.Parent = cuerpo

	-- Billboard
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 170, 0, 28)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Parent      = cuerpo

	local lblBB = Instance.new("TextLabel")
	lblBB.Size                   = UDim2.new(1, 0, 1, 0)
	lblBB.BackgroundTransparency = 1
	lblBB.Text                   = "Cofre de " .. playerName
	lblBB.Font                   = Enum.Font.GothamBold
	lblBB.TextScaled             = true
	lblBB.TextColor3             = Color3.fromRGB(220, 180, 80)
	lblBB.TextStrokeTransparency = 0.4
	lblBB.Parent                 = bb

	return modelo, cuerpo
end

-- ============================================================
-- Inicializar (llamar UNA vez al arrancar el servidor)
-- ============================================================
function M.inicializar()
	local carpetaEventos = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")

	local evCraftearCofreAlm   = obtenerOCrear(carpetaEventos, "RemoteEvent", "CraftearCofreAlm")
	local evAbrirCofreAlm      = obtenerOCrear(carpetaEventos, "RemoteEvent", "AbrirCofreAlm")
	local evMoverAlCofre       = obtenerOCrear(carpetaEventos, "RemoteEvent", "MoverAlCofre")
	local evMoverAlInventario  = obtenerOCrear(carpetaEventos, "RemoteEvent", "MoverAlInventario")
	local evCofreAlmActualizado = obtenerOCrear(carpetaEventos, "RemoteEvent", "CofreAlmActualizado")
	local evResultadoCrafteo   = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoCrafteo")

	-- ── HANDLER: Craftear cofre ───────────────────────────────────
	evCraftearCofreAlm.OnServerEvent:Connect(function(player)
		-- Ya tiene cofre en esta sesión
		if cofresAlm[player] then
			evResultadoCrafteo:FireClient(player, {
				exito   = false,
				tipo    = "CofreAlm",
				mensaje = "Ya tienes un Cofre de Almacenamiento.",
			})
			return
		end

		-- Necesita estar en una sesión activa
		local sesionId = player:GetAttribute("SesionActual")
		local offsetX  = player:GetAttribute("SesionOffsetX") or 0
		if not sesionId then
			evResultadoCrafteo:FireClient(player, {
				exito   = false,
				tipo    = "CofreAlm",
				mensaje = "No estás en una sesión activa.",
			})
			return
		end

		local carpetaSesionesWS = workspace:FindFirstChild("Sesiones")
		local carpetaSesion = carpetaSesionesWS and carpetaSesionesWS:FindFirstChild("Sesion_" .. sesionId)
		if not carpetaSesion then
			evResultadoCrafteo:FireClient(player, {
				exito   = false,
				tipo    = "CofreAlm",
				mensaje = "Error: sesión no encontrada.",
			})
			return
		end

		-- Descontar costo
		local ok, faltante = InventarioMgr.descontar(player, CofreAlmConfig.COSTO)
		if not ok then
			local nombre = faltante or "materiales"
			evResultadoCrafteo:FireClient(player, {
				exito   = false,
				tipo    = "CofreAlm",
				mensaje = "Materiales insuficientes. (Falta: " .. nombre .. ")",
			})
			return
		end

		-- Crear modelo físico
		local modelo, cuerpo = crearModeloFisico(offsetX, carpetaSesion, player.Name)

		-- Guardar estado
		local data = { cofre = {}, modelo = modelo }
		cofresAlm[player] = data
		player:SetAttribute("CofreAlmConstruido", true)

		-- Conectar ProximityPrompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Abrir"
		prompt.ObjectText            = "Cofre de Almacenamiento"
		prompt.KeyboardKeyCode       = Enum.KeyCode.E
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight   = false
		prompt.Parent                = cuerpo

		prompt.Triggered:Connect(function(activador)
			if activador ~= player then return end
			local d = cofresAlm[player]
			if not d then return end
			local slotsMax = calcularSlotsMax(player)
			evAbrirCofreAlm:FireClient(player, {
				cofre      = d.cofre,
				slotsMax   = slotsMax,
				inventario = InventarioMgr.obtener(player),
			})
		end)

		-- Notificar éxito
		evResultadoCrafteo:FireClient(player, {
			exito   = true,
			tipo    = "CofreAlm",
			mensaje = "Cofre de Almacenamiento construido!",
		})

		print(string.format("[CofreAlm] %s construyó su cofre (sesión %d).", player.Name, sesionId))
	end)

	-- ── HANDLER: Mover ítem del inventario al cofre ───────────────
	evMoverAlCofre.OnServerEvent:Connect(function(player, recurso)
		local data = cofresAlm[player]
		if not data then return end
		if not esAlmacenable(recurso) then return end

		local inv = InventarioMgr.obtener(player)
		if (inv[recurso] or 0) <= 0 then return end

		local cofre      = data.cofre
		local cantActual = cofre[recurso] or 0
		local slotsMax   = calcularSlotsMax(player)

		-- Calcular cuántos slots adicionales necesita agregar 1 unidad más
		-- Ej: cantActual=5 → ceil(5/5)=1 slot, cantNuevo=6 → ceil(6/5)=2 → delta=1
		-- Ej: cantActual=4 → ceil(4/5)=1 slot, cantNuevo=5 → ceil(5/5)=1 → delta=0
		local slotsActuales    = calcularSlotsEnCofre(cofre)
		local slotsCantActual  = cantActual > 0 and math.ceil(cantActual / CofreAlmConfig.MAX_POR_SLOT) or 0
		local slotsCantNuevo   = math.ceil((cantActual + 1) / CofreAlmConfig.MAX_POR_SLOT)
		local deltaSlotsNeeded = slotsCantNuevo - slotsCantActual

		if slotsActuales + deltaSlotsNeeded > slotsMax then return end

		-- Descontar del inventario (envía InventarioActualizado internamente)
		InventarioMgr.descontar(player, { [recurso] = 1 })

		-- Agregar al cofre
		cofre[recurso] = cantActual + 1

		-- Notificar cliente
		evCofreAlmActualizado:FireClient(player, { cofre = cofre, slotsMax = calcularSlotsMax(player) })
	end)

	-- ── HANDLER: Mover ítem del cofre al inventario ───────────────
	evMoverAlInventario.OnServerEvent:Connect(function(player, recurso)
		local data = cofresAlm[player]
		if not data then return end

		local cofre     = data.cofre
		local cantActual = cofre[recurso] or 0
		if cantActual <= 0 then return end

		-- Intentar agregar al inventario
		local exito = InventarioMgr.agregar(player, recurso, 1)
		if not exito then return end  -- InventarioMgr ya notifica InventarioLleno al cliente

		-- Descontar del cofre
		if cantActual <= 1 then
			cofre[recurso] = nil
		else
			cofre[recurso] = cantActual - 1
		end

		-- Notificar cliente
		local slotsMax = calcularSlotsMax(player)
		evCofreAlmActualizado:FireClient(player, { cofre = cofre, slotsMax = slotsMax })
	end)

	print("[CofreAlm] Handlers de cofre de almacenamiento conectados.")
end

-- ============================================================
-- Limpiar jugador al salir de sesión o del juego
-- ============================================================
function M.limpiarJugador(player)
	local data = cofresAlm[player]
	if not data then return end
	if data.modelo and data.modelo.Parent then
		data.modelo:Destroy()
	end
	cofresAlm[player] = nil
	player:SetAttribute("CofreAlmConstruido", nil)
end

return M
