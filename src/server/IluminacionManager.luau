-- IluminacionManager.luau  (ModuleScript en ServerScriptService/Server/)
-- Registra y controla el estado de todas las antorchas y hogueras portátiles
-- colocadas en el mundo, por sesión. Maneja los timers de auto-apagado,
-- las transiciones visuales y los ProximityPrompts de reencendido individual.
--
-- API pública:
--   M.inicializarSesion(sesionId)
--   M.registrar(sesionId, tipo, carpeta, llama, luz, parteBase, marcador, posicion, receta) → objId
--   M.apagar(sesionId, objId)
--   M.reencender(sesionId, objId, carpetaHoguerasActivas)
--   M.contarApagados(sesionId)     → { antorchas = N, hogueras = N }
--   M.costoCombinado(sesionId)     → número (antorchas×1 + hogueras×4)
--   M.reencenderTodos(sesionId, carpetaHoguerasActivas)
--   M.limpiarSesion(sesionId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventarioMgr = require(script.Parent:WaitForChild("InventarioManager"))

local M = {}

-- ============================================================
-- Constantes
-- ============================================================
local COSTO_REENCENDER = { Antorcha = 1, Hoguera = 4 }

-- ============================================================
-- Estado interno
-- ============================================================
-- registros[sesionId][objId] = {
--   tipo           = "Antorcha" | "Hoguera",
--   encendida      = bool,
--   carpeta        = Folder,
--   llama          = Part,        -- Llama (ant) o Fuego (hog)
--   luz            = PointLight,
--   parteBase      = Part,        -- Palo (ant) o Base (hog)
--   colorOrigLlama = Color3,
--   colorOrigBase  = Color3,
--   marcador       = Part | nil,
--   humo           = Smoke | nil,
--   prompt         = ProximityPrompt | nil,
--   timerHilo      = thread | nil,
--   receta         = tabla,
--   posicion       = Vector3,
-- }
local registros  = {}
local contadorId = 0

-- ============================================================
-- Helpers internos
-- ============================================================

local function carpetaHoguerasDeSesion(sesionId)
	local sesFolder  = workspace:FindFirstChild("Sesiones")
	local carpetaSes = sesFolder and sesFolder:FindFirstChild("Sesion_" .. tostring(sesionId))
	return carpetaSes and carpetaSes:FindFirstChild("HoguerasActivas")
end

local function enviarFeedback(player, mensaje)
	local carpetaEventos = ReplicatedStorage:FindFirstChild("Eventos")
	local ev = carpetaEventos and carpetaEventos:FindFirstChild("FeedbackIluminacion")
	if ev then ev:FireClient(player, mensaje) end
end

-- ============================================================
-- API pública
-- ============================================================

-- Prepara la tabla de registros para una nueva sesión.
function M.inicializarSesion(sesionId)
	registros[sesionId] = {}
end

-- Registra un objeto recién creado (encendido) y lanza su timer de auto-apagado.
-- Devuelve el objId único asignado.
function M.registrar(sesionId, tipo, carpeta, llama, luz, parteBase, marcador, posicion, receta)
	if not registros[sesionId] then registros[sesionId] = {} end

	contadorId += 1
	local prefijo = tipo == "Antorcha" and "ant" or "hog"
	local objId   = prefijo .. "_" .. contadorId

	registros[sesionId][objId] = {
		tipo           = tipo,
		encendida      = true,
		carpeta        = carpeta,
		llama          = llama,
		luz            = luz,
		parteBase      = parteBase,
		colorOrigLlama = llama.Color,
		colorOrigBase  = parteBase.Color,
		marcador       = marcador,
		humo           = nil,
		prompt         = nil,
		timerHilo      = nil,
		receta         = receta,
		posicion       = posicion,
	}

	-- Iniciar timer de auto-apagado
	registros[sesionId][objId].timerHilo = task.delay(receta.duracion, function()
		M.apagar(sesionId, objId)
	end)

	return objId
end

-- Apaga el objeto: cambio visual a "quemado", añade humo y ProximityPrompt de reencendido.
function M.apagar(sesionId, objId)
	local sesReg = registros[sesionId]
	if not sesReg then return end
	local r = sesReg[objId]
	if not r or not r.encendida then return end
	if not r.carpeta or not r.carpeta.Parent then return end

	r.encendida = false

	-- Ocultar llama y desactivar luz
	r.llama.Transparency = 1
	r.luz.Enabled        = false

	-- Apariencia "quemada"
	if r.tipo == "Antorcha" then
		r.parteBase.Color = Color3.fromRGB(40, 28, 15)   -- palo oscuro quemado
	else
		r.parteBase.Color = Color3.fromRGB(80, 78, 76)   -- brasas grises
	end

	-- Humo tenue (la llama sigue existiendo como ancla, solo invisible)
	local humo = Instance.new("Smoke")
	humo.Color        = Color3.fromRGB(120, 120, 120)
	humo.Opacity      = 0.08
	humo.RiseVelocity = 1
	humo.Size         = 0.15
	humo.Parent       = r.llama
	r.humo = humo

	-- Quitar marcador de HoguerasActivas (ya no protege)
	if r.marcador and r.marcador.Parent then r.marcador:Destroy() end
	r.marcador = nil

	-- ProximityPrompt para reencendido individual
	local costoMadera   = COSTO_REENCENDER[r.tipo]
	local sesionIdLocal = sesionId
	local objIdLocal    = objId

	local pp = Instance.new("ProximityPrompt")
	pp.ActionText            = "Reencender  (" .. costoMadera .. " Madera)"
	pp.ObjectText            = r.tipo
	pp.KeyboardKeyCode       = Enum.KeyCode.E
	pp.MaxActivationDistance = 5
	pp.Parent                = r.parteBase   -- parte con colisión

	-- Conexión servidor-side: validar y reencender al presionar E
	pp.Triggered:Connect(function(player)
		if player:GetAttribute("SesionActual") ~= sesionIdLocal then return end

		-- Verificar que el objeto todavía existe y sigue apagado
		local sesRegActual = registros[sesionIdLocal]
		local reg = sesRegActual and sesRegActual[objIdLocal]
		if not reg or reg.encendida then return end

		-- Validar y descontar Madera (solo del inventario en reencendido individual)
		local ok = InventarioMgr.descontar(player, { Madera = costoMadera })
		if not ok then
			enviarFeedback(player, "Madera insuficiente")
			return
		end

		local carpetaHogs = carpetaHoguerasDeSesion(sesionIdLocal)
		M.reencender(sesionIdLocal, objIdLocal, carpetaHogs)
	end)

	r.prompt = pp
end

-- Re-enciende el objeto: restaura visual, recrea marcador y reinicia el timer.
function M.reencender(sesionId, objId, carpetaHoguerasActivas)
	local sesReg = registros[sesionId]
	if not sesReg then return end
	local r = sesReg[objId]
	if not r or r.encendida then return end
	if not r.carpeta or not r.carpeta.Parent then return end

	-- Cancelar timer zombie (si quedó activo por alguna razón)
	if r.timerHilo then task.cancel(r.timerHilo) ; r.timerHilo = nil end

	r.encendida = true

	-- Restaurar visual
	r.llama.Transparency = 0
	r.llama.Color        = r.colorOrigLlama
	r.luz.Enabled        = true
	r.parteBase.Color    = r.colorOrigBase

	-- Destruir humo
	if r.humo then r.humo:Destroy() ; r.humo = nil end

	-- Destruir ProximityPrompt de reencendido
	if r.prompt then r.prompt:Destroy() ; r.prompt = nil end

	-- Recrear marcador en HoguerasActivas de la sesión
	if carpetaHoguerasActivas then
		local nombreMarcador = r.tipo == "Antorcha" and "RadioAntorcha" or "RadioHoguera"
		local marcadorNuevo  = Instance.new("Part")
		marcadorNuevo.Name        = nombreMarcador
		marcadorNuevo.Size        = Vector3.new(1, 1, 1)
		marcadorNuevo.Anchored    = true
		marcadorNuevo.CanCollide  = false
		marcadorNuevo.Transparency = 1
		marcadorNuevo.CFrame      = CFrame.new(r.posicion)
		marcadorNuevo:SetAttribute("Radio", r.receta.radioRepulsion)
		marcadorNuevo.Parent      = carpetaHoguerasActivas
		r.marcador = marcadorNuevo
	end

	-- Nuevo timer de auto-apagado
	r.timerHilo = task.delay(r.receta.duracion, function()
		M.apagar(sesionId, objId)
	end)
end

-- Devuelve el conteo de objetos apagados en la sesión.
function M.contarApagados(sesionId)
	local resultado = { antorchas = 0, hogueras = 0 }
	local sesReg    = registros[sesionId]
	if not sesReg then return resultado end
	for _, r in pairs(sesReg) do
		if not r.encendida then
			if r.tipo == "Antorcha" then
				resultado.antorchas += 1
			else
				resultado.hogueras += 1
			end
		end
	end
	return resultado
end

-- Calcula el costo total en Madera para reencender todos los apagados.
function M.costoCombinado(sesionId)
	local conteo = M.contarApagados(sesionId)
	return conteo.antorchas * COSTO_REENCENDER.Antorcha
	     + conteo.hogueras  * COSTO_REENCENDER.Hoguera
end

-- Enciende todos los objetos apagados de la sesión.
function M.reencenderTodos(sesionId, carpetaHoguerasActivas)
	local sesReg = registros[sesionId]
	if not sesReg then return end
	-- Iterar sobre copia de las claves para evitar modificación durante iteración
	local ids = {}
	for id, r in pairs(sesReg) do
		if not r.encendida then table.insert(ids, id) end
	end
	for _, id in ipairs(ids) do
		M.reencender(sesionId, id, carpetaHoguerasActivas)
	end
end

-- Limpia todos los registros de una sesión al terminar.
-- Cancela timers activos y destruye ProximityPrompts pendientes.
-- Los modelos físicos se destruyen solos al destruirse la carpeta de sesión.
function M.limpiarSesion(sesionId)
	local sesReg = registros[sesionId]
	if not sesReg then return end
	for _, r in pairs(sesReg) do
		if r.timerHilo then
			task.cancel(r.timerHilo)
			r.timerHilo = nil
		end
		if r.prompt and r.prompt.Parent then
			r.prompt:Destroy()
		end
	end
	registros[sesionId] = nil
end

print("[IluminacionManager] Sistema de iluminacion persistente cargado.")

return M
