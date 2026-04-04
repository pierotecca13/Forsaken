-- InventarioManager.luau  (ModuleScript en ServerScriptService/Server/)
-- Fuente única de verdad del inventario de cada jugador.
-- Gestiona slots limitados según nivel del campamento.
-- Recoleccion, Enemigos y Campamento lo requieren en lugar de tablas propias.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecursosConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RecursosConfig"))

local M = {}

-- inventarios[player] = { Madera=0, Piedra=0, ... }
local inventarios = {}

-- ── Helpers internos ────────────────────────────────────────────

local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(className)
		obj.Name   = nombre
		obj.Parent = parent
	end
	return obj
end

-- Eventos remotos
local carpetaEventos          = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evInventarioActualizado = obtenerOCrear(carpetaEventos, "RemoteEvent", "InventarioActualizado")
local evInventarioLleno       = obtenerOCrear(carpetaEventos, "RemoteEvent", "InventarioLleno")

-- Lee el nivel actual del campamento desde el NumberValue que crea Campamento.server
local function nivelCampamento()
	local nv = ReplicatedStorage:FindFirstChild("NivelCampamento")
	return nv and nv.Value or 1
end

-- Cuántos slots ocupa una cantidad de un recurso concreto
local function slotsDeRecurso(cantidad, maxPorSlot)
	if cantidad <= 0 then return 0 end
	return math.ceil(cantidad / maxPorSlot)
end

-- Total de slots consumidos por el inventario completo
local function calcularSlotsUsados(inv)
	local total = 0
	for recurso, cantidad in pairs(inv) do
		local maxSlot = RecursosConfig.MAX_POR_SLOT[recurso] or 1
		total += slotsDeRecurso(cantidad, maxSlot)
	end
	return total
end

-- Slots máximos permitidos según nivel del campamento actual
local function calcularSlotsMaximos()
	local nivel = nivelCampamento()
	return RecursosConfig.SLOTS_POR_NIVEL[nivel] or 10
end

-- ── API pública ──────────────────────────────────────────────────

-- Devuelve la tabla de inventario del jugador (crea una vacía si no existe)
function M.obtener(player)
	if not inventarios[player] then
		inventarios[player] = {
			Madera      = 0,
			Piedra      = 0,
			Hongos      = 0,
			Hierro      = 0,
			Cristal     = 0,
			HojaTrebol  = 0,
			Piel        = 0,
			Colmillo    = 0,
			Garra       = 0,
			CarneConejo = 0,
			CarneZorro  = 0,
			CarneLobo   = 0,
			CarneOso    = 0,
			Antorcha    = 0,
			Hoguera     = 0,
		}
	end
	return inventarios[player]
end

-- Envía el inventario actual al cliente junto con el estado de slots
function M.enviar(player)
	local inv          = M.obtener(player)
	local slotsUsados  = calcularSlotsUsados(inv)
	local slotsMaximos = calcularSlotsMaximos()
	evInventarioActualizado:FireClient(player, inv, slotsUsados, slotsMaximos)
end

-- Intenta sumar 'cantidad' del recurso al inventario del jugador.
-- Devuelve true si tuvo éxito, false si el inventario no tiene espacio.
-- Cuando falla, dispara InventarioLleno al cliente para mostrar el aviso.
function M.agregar(player, recurso, cantidad)
	local inv     = M.obtener(player)
	local maxSlot = RecursosConfig.MAX_POR_SLOT[recurso] or 1

	-- Calcular cuántos slots adicionales necesitaría esta operación
	local actual   = inv[recurso] or 0
	local nueva    = actual + cantidad
	local delta    = slotsDeRecurso(nueva, maxSlot) - slotsDeRecurso(actual, maxSlot)

	local slotsActuales = calcularSlotsUsados(inv)
	local slotsMax      = calcularSlotsMaximos()

	if slotsActuales + delta > slotsMax then
		-- No cabe: notificar al cliente y rechazar
		evInventarioLleno:FireClient(player)
		return false
	end

	inv[recurso] = nueva
	M.enviar(player)
	return true
end

-- Intenta descontar los recursos del mapa {recurso = cantidad}.
-- Devuelve (true, nil) si se pudo, (false, "NombreRecurso") si falta alguno.
-- Al descontar siempre hay espacio de sobra (los slots solo se reducen).
function M.descontar(player, costos)
	local inv = M.obtener(player)

	-- Validar sin modificar
	for recurso, cantidad in pairs(costos) do
		if (inv[recurso] or 0) < cantidad then
			return false, recurso
		end
	end

	-- Descontar
	for recurso, cantidad in pairs(costos) do
		inv[recurso] = inv[recurso] - cantidad
	end
	M.enviar(player)
	return true, nil
end

-- Limpieza al desconectarse
Players.PlayerRemoving:Connect(function(player)
	inventarios[player] = nil
end)

return M
