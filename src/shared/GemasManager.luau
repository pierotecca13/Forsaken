-- GemasManager.luau  (ModuleScript en ReplicatedStorage/Shared/)
-- Moneda global del jugador: Gemas.
-- Se almacena como atributo del Player ("Gemas") para que persista
-- durante la sesión y sea legible desde cualquier script del servidor.
-- Las gemas también se guardan en DataStore para persistir entre partidas.
--
-- Uso desde el servidor:
--   local GM = require(RS.Shared.GemasManager)
--   GM.cargar(player)        → carga desde DataStore al conectarse
--   GM.guardar(player)       → guarda en DataStore al desconectarse
--   GM.agregar(player, 50)
--   GM.gastar(player, 10)   → true si tuvo éxito, false si no alcanza
--   GM.obtener(player)      → número actual

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ATRIBUTO = "Gemas"

-- El DataStore se inicializa de forma segura: si Studio no tiene acceso a API
-- Services (o si el módulo se carga en el cliente), STORE queda en nil y las
-- funciones cargar/guardar simplemente no persisten sin romper nada.
local STORE
do
	local ok, result = pcall(function()
		return game:GetService("DataStoreService"):GetDataStore("GemasJugador_v1")
	end)
	STORE = ok and result or nil
end

local M = {}

-- Devuelve el saldo actual de gemas del jugador
function M.obtener(player)
	return player:GetAttribute(ATRIBUTO) or 0
end

-- Inicializa el atributo (llamar en PlayerAdded)
function M.inicializar(player)
	if player:GetAttribute(ATRIBUTO) == nil then
		player:SetAttribute(ATRIBUTO, 0)
	end
end

-- Suma gemas y notifica al cliente
function M.agregar(player, cantidad)
	if cantidad <= 0 then return end
	local nuevo = M.obtener(player) + cantidad
	player:SetAttribute(ATRIBUTO, nuevo)
	M._notificar(player, nuevo)
	print(string.format("[Gemas] %s recibió %d gemas (total: %d).", player.Name, cantidad, nuevo))
end

-- Intenta gastar gemas. Devuelve true si tuvo éxito, false si no alcanza.
function M.gastar(player, cantidad)
	if cantidad <= 0 then return true end
	local actual = M.obtener(player)
	if actual < cantidad then return false end
	local nuevo = actual - cantidad
	player:SetAttribute(ATRIBUTO, nuevo)
	M._notificar(player, nuevo)
	print(string.format("[Gemas] %s gastó %d gemas (restante: %d).", player.Name, cantidad, nuevo))
	return true
end

-- Carga el saldo desde DataStore (usar en PlayerAdded en lugar de inicializar)
function M.cargar(player)
	local gemas = 0
	if STORE then
		local ok, valor = pcall(function()
			return STORE:GetAsync("Gemas_" .. player.UserId)
		end)
		if ok and type(valor) == "number" then
			gemas = valor
		end
	end
	player:SetAttribute(ATRIBUTO, gemas)
	print(string.format("[Gemas] %s cargó %d gemas.", player.Name, gemas))
end

-- Guarda el saldo actual en DataStore (usar en PlayerRemoving y BindToClose)
function M.guardar(player)
	if not STORE then return end
	local ok, err = pcall(function()
		STORE:SetAsync("Gemas_" .. player.UserId, M.obtener(player))
	end)
	if not ok then
		warn("[Gemas] Error al guardar gemas de " .. player.Name .. ": " .. tostring(err))
	end
end

-- Dispara el evento de actualización al cliente (interno)
function M._notificar(player, cantidad)
	local carpetaEventos = ReplicatedStorage:FindFirstChild("Eventos")
	if not carpetaEventos then return end
	local ev = carpetaEventos:FindFirstChild("GemasActualizadas")
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name   = "GemasActualizadas"
		ev.Parent = carpetaEventos
	end
	ev:FireClient(player, cantidad)
end

return M
