-- Recoleccion.server.luau
-- Sistema de recolección de recursos del Bosque.
-- Crea los objetos en el mapa, gestiona ProximityPrompt,
-- mantiene el inventario por jugador y dispara el respawn.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Config            = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RecursosConfig"))
local InventarioManager = require(script.Parent.InventarioManager)

-- Enviar inventario inicial cuando el jugador entra al juego
Players.PlayerAdded:Connect(function(player)
	task.wait(2)  -- esperar a que el cliente cargue la UI
	InventarioManager.enviar(player)
end)

-- ============================================================
-- Creación de objetos recolectables en el mapa
-- ============================================================

-- Carpeta que agrupa todos los recursos en Workspace
local carpetaRecursos = Instance.new("Folder")
carpetaRecursos.Name   = "RecursosBosque"
carpetaRecursos.Parent = Workspace

-- Posiciones de los 8 recursos de ejemplo
-- El suelo está en Y=0 (baseplate surface), por eso sumamos tamano.Y/2
local POSICIONES_EJEMPLO = {
	-- 3 Árboles
	{ tipo = "Arbol", pos = Vector3.new(  20,  0,  20) },
	{ tipo = "Arbol", pos = Vector3.new( -35,  0,  12) },
	{ tipo = "Arbol", pos = Vector3.new(  42,  0, -28) },
	-- 3 Rocas
	{ tipo = "Roca",  pos = Vector3.new( -22,  0, -18) },
	{ tipo = "Roca",  pos = Vector3.new(  30,  0,  38) },
	{ tipo = "Roca",  pos = Vector3.new( -48,  0,  44) },
	-- 2 Hongos
	{ tipo = "Hongo", pos = Vector3.new(  12,  0, -38) },
	{ tipo = "Hongo", pos = Vector3.new( -16,  0,  30) },
}

-- Crea un Part recolectable y conecta la lógica de recolección
local function crearRecurso(datos)
	local info = Config.TIPOS[datos.tipo]
	if not info then
		warn("[Recoleccion] Tipo desconocido: " .. tostring(datos.tipo))
		return
	end

	-- Calcular posición Y para que el objeto descanse sobre el suelo
	local posicionFinal = datos.pos + Vector3.new(0, info.tamano.Y / 2, 0)

	-- Crear la parte visual
	local parte = Instance.new("Part")
	parte.Name         = datos.tipo
	parte.Size         = info.tamano
	parte.Position     = posicionFinal
	parte.Anchored     = true
	parte.CanCollide   = true
	parte.Color        = info.color
	parte.Material     = info.material
	parte.Shape        = info.forma
	parte.CastShadow   = true
	parte.Parent       = carpetaRecursos

	-- Guardar el tipo como atributo para referencia futura (extensible)
	parte:SetAttribute("TipoRecurso", datos.tipo)

	-- ProximityPrompt: Roblox muestra la UI de "E" automáticamente
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText           = "Recolectar"
	prompt.ObjectText           = info.promptTexto
	prompt.KeyboardKeyCode      = Enum.KeyCode.E
	prompt.HoldDuration         = 0.0    -- presionar sin mantener
	prompt.MaxActivationDistance = 8     -- studs de alcance
	prompt.RequiresLineOfSight  = false
	prompt.Parent               = parte

	-- ── Lógica de recolección ──────────────────────────────
	prompt.Triggered:Connect(function(player)
		-- Deshabilitar de inmediato para evitar doble recolección
		prompt.Enabled       = false
		parte.Transparency   = 0.85
		parte.CanCollide     = false

		-- Cantidad aleatoria según config
		local cantidad = math.random(info.cantidadMin, info.cantidadMax)

		-- Intentar añadir al inventario; si está lleno, devolver el recurso al mapa
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			-- Inventario sin espacio: reactivar el objeto sin consumirlo
			parte.Transparency = 0
			parte.CanCollide   = true
			prompt.Enabled     = true
			return
		end

		print(string.format(
			"[Recoleccion] %s recolectó %d %s",
			player.Name, cantidad, info.recurso
		))

		-- Respawn tras el tiempo configurado
		task.delay(info.respawnTiempo, function()
			parte.Transparency = 0
			parte.CanCollide   = true
			prompt.Enabled     = true
			print(string.format("[Recoleccion] %s reaparece en el mapa.", datos.tipo))
		end)
	end)

	return parte
end

-- Instanciar todos los recursos de ejemplo
for _, datos in ipairs(POSICIONES_EJEMPLO) do
	crearRecurso(datos)
end

print(string.format("[Recoleccion] %d recursos creados en RecursosBosque.", #POSICIONES_EJEMPLO))
