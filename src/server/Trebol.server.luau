-- Trebol.server.luau
-- Gestiona el sistema de Hojas del Trébol:
--   · Inicializa atributos al entrar el jugador
--   · Envía el estado completo al cliente al respawnear
-- Las hojas se otorgan desde otros sistemas (ej. drops de jefes)
-- usando TrebolManager.darHoja(player, tipo).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrebolManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolManager"))
local TrebolConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolConfig"))

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

local carpetaEventos        = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evHojaTrebolActualizada = obtenerOCrear(carpetaEventos, "RemoteEvent", "HojaTrebolActualizada")

-- ============================================================
-- Jugador entra: inicializar atributos y sincronizar al respawnear
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	TrebolManager.inicializar(player)

	-- Al spawnearse (o respawnear), enviar el estado completo de hojas
	player.CharacterAdded:Connect(function()
		task.wait(0.4)   -- margen para que el personaje termine de cargar
		local estado = TrebolManager.obtenerTodas(player)
		for tipo, tiene in pairs(estado) do
			evHojaTrebolActualizada:FireClient(player, tipo, tiene)
		end
	end)
end)

print("[Trebol] Sistema de Hojas del Trébol iniciado.")
