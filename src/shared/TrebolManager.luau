-- TrebolManager.luau  (ModuleScript en ReplicatedStorage/Shared/)
-- API unificada para las Hojas del Trébol.
-- Usar desde scripts del servidor (con parámetro player) para
-- verificar y otorgar hojas sin duplicar lógica.
--
-- Uso:
--   local TrebolManager = require(RS.Shared.TrebolManager)
--   TrebolManager.tieneHoja(player, "Verde")  → true/false
--   TrebolManager.darHoja(player, "Verde")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrebolConfig      = require(script.Parent:WaitForChild("TrebolConfig"))

local M = {}

-- Devuelve si el jugador tiene la hoja indicada
function M.tieneHoja(player, tipo)
	local attr = TrebolConfig.PREFIJO_ATRIBUTO .. tipo
	return player:GetAttribute(attr) == true
end

-- Otorga la hoja al jugador (idempotente: no hace nada si ya la tiene)
-- Dispara el RemoteEvent HojaTrebolActualizada para actualizar la UI del cliente
function M.darHoja(player, tipo)
	if M.tieneHoja(player, tipo) then return end

	local attr = TrebolConfig.PREFIJO_ATRIBUTO .. tipo
	player:SetAttribute(attr, true)

	-- Notificar cliente
	local carpetaEventos = ReplicatedStorage:FindFirstChild("Eventos")
	if carpetaEventos then
		local ev = carpetaEventos:FindFirstChild("HojaTrebolActualizada")
		if ev then
			ev:FireClient(player, tipo, true)
		end
	end

	print(string.format("[TrebolManager] %s obtuvo la Hoja %s.", player.Name, tipo))
end

-- Inicializa los atributos de las 4 hojas en false para un jugador nuevo
function M.inicializar(player)
	for _, tipo in ipairs(TrebolConfig.ORDEN) do
		local attr = TrebolConfig.PREFIJO_ATRIBUTO .. tipo
		if player:GetAttribute(attr) == nil then
			player:SetAttribute(attr, false)
		end
	end
end

-- Devuelve tabla con el estado de todas las hojas del jugador
function M.obtenerTodas(player)
	local estado = {}
	for _, tipo in ipairs(TrebolConfig.ORDEN) do
		estado[tipo] = M.tieneHoja(player, tipo)
	end
	return estado
end

return M
