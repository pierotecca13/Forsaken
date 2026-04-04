-- Combate.server.luau
-- Gestiona el spawn del jugador (con control manual para el Reintentar),
-- entrega el arma inicial, valida ataques cuerpo a cuerpo y aplica daño.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArmasConfig"))

-- Desactivar el respawn automático para todos los jugadores;
-- el spawn se controla manualmente con player:LoadCharacter()
Players.CharacterAutoLoads = false

-- Posición de spawn: lateral al campamento (que está en 0,0,-20)
local SPAWN_CF = CFrame.new(5, 3, -14)

-- ============================================================
-- Eventos (reutiliza la carpeta de Eventos ya existente)
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

local carpetaEventos = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evAtacarMelee  = obtenerOCrear(carpetaEventos, "RemoteEvent", "AtacarMelee")
local evReintentar   = obtenerOCrear(carpetaEventos, "RemoteEvent", "Reintentar")

-- cooldowns[player] = timestamp del último ataque aceptado
local cooldowns = {}

-- ============================================================
-- Crear Tool (arma) con su Handle visual
-- ============================================================
local function crearHerramienta(tipoArma)
	local info = Config.ARMAS[tipoArma]
	if not info then
		warn("[Combate] Tipo de arma desconocida: " .. tostring(tipoArma))
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name           = tipoArma        -- clave legible por otros scripts
	tool.CanBeDropped   = false
	tool.RequiresHandle = true
	tool.ToolTip        = info.nombre

	local handle = Instance.new("Part")
	handle.Name     = "Handle"
	handle.Size     = info.tamano
	handle.Color    = info.color
	handle.Material = info.material
	handle.Parent   = tool

	return tool
end

-- ============================================================
-- Buscar objetivos en rango (solo NPCs/enemigos, no jugadores)
-- ============================================================
local function encontrarObjetivos(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	local objetivos = {}

	for _, modelo in ipairs(workspace:GetChildren()) do
		if modelo:IsA("Model") and modelo ~= character then
			-- Excluir personajes de otros jugadores (PvE solamente)
			if not Players:GetPlayerFromCharacter(modelo) then
				local humanoid = modelo:FindFirstChildWhichIsA("Humanoid")
				local otroHrp  = modelo:FindFirstChild("HumanoidRootPart")
				if humanoid and humanoid.Health > 0 and otroHrp then
					local dist = (otroHrp.Position - hrp.Position).Magnitude
					if dist <= Config.RANGO_ATAQUE then
						table.insert(objetivos, humanoid)
					end
				end
			end
		end
	end

	return objetivos
end

-- ============================================================
-- Ciclo de vida del jugador
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	cooldowns[player] = 0

	-- Cada vez que el personaje aparece: posicionar y dar arma
	player.CharacterAdded:Connect(function(character)
		-- Teleportar al campamento base
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if hrp then
			task.wait(0.15)   -- margen para que el motor termine de construir el rig
			hrp.CFrame = SPAWN_CF
		end

		-- Entregar arma equipada (parenting directo al character = equipa de inmediato)
		local tipoArma = player:GetAttribute("ArmaEquipada") or Config.ARMA_INICIAL
		local tool = crearHerramienta(tipoArma)
		if tool then
			tool.Parent = character
		end

		-- Registrar qué arma tiene (legible desde otros scripts)
		player:SetAttribute("ArmaEquipada", tipoArma)
	end)

	-- Spawn inicial
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)

-- ============================================================
-- Procesar solicitud de ataque
-- ============================================================
evAtacarMelee.OnServerEvent:Connect(function(player)
	local tipoArma = player:GetAttribute("ArmaEquipada") or Config.ARMA_INICIAL
	local infoArma = Config.ARMAS[tipoArma]
	if not infoArma then return end

	-- Validar cooldown en servidor (evita exploits de spam)
	local ahora = tick()
	if ahora - (cooldowns[player] or 0) < infoArma.cooldown then return end
	cooldowns[player] = ahora

	-- Aplicar daño a objetivos en rango
	local character = player.Character
	if not character then return end

	local objetivos = encontrarObjetivos(character)
	for _, humanoid in ipairs(objetivos) do
		humanoid:TakeDamage(infoArma.dano)
		print(string.format("[Combate] %s golpeo con %s: %d dano a %s",
			player.Name, tipoArma, infoArma.dano, humanoid.Parent.Name))
	end
end)

-- ============================================================
-- Respawn al pulsar Reintentar
-- ============================================================
evReintentar.OnServerEvent:Connect(function(player)
	player:LoadCharacter()
end)

print("[Combate] Sistema de combate iniciado.")
