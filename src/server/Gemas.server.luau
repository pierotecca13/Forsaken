-- Gemas.server.luau
-- Inicializa las gemas de cada jugador y crea el RemoteEvent de sincronía.
-- Las gemas son moneda global: no ocupan inventario, persisten toda la sesión.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemasManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemasManager"))

-- ============================================================
-- Eventos
-- ============================================================
local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj        = Instance.new(className)
		obj.Name   = nombre
		obj.Parent = parent
	end
	return obj
end

local carpetaEventos  = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evActualizadas  = obtenerOCrear(carpetaEventos, "RemoteEvent", "GemasActualizadas")

-- ============================================================
-- Jugador entra: inicializar y sincronizar al spawnear
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	-- Cargar gemas persistidas desde DataStore
	GemasManager.cargar(player)

	-- Al spawnear (o respawnear) enviar el saldo actual al cliente
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		evActualizadas:FireClient(player, GemasManager.obtener(player))
	end)
end)

-- Guardar gemas al desconectarse
Players.PlayerRemoving:Connect(function(player)
	GemasManager.guardar(player)
end)

-- Guardar gemas de todos al cerrar el servidor
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		GemasManager.guardar(player)
	end
end)

print("[Gemas] Sistema de gemas iniciado.")
