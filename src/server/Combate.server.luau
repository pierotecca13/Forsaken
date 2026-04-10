-- Combate.server.luau
-- Gestiona el spawn del jugador (con control manual para el Reintentar),
-- entrega el arma inicial, valida ataques cuerpo a cuerpo y aplica daño.
-- También maneja el revivir en el lugar con costo de gemas.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config          = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArmasConfig"))
local GemasManager    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemasManager"))
local SesionManager   = require(script.Parent:WaitForChild("SesionManager"))

-- Desactivar el respawn automático para todos los jugadores;
-- el spawn se controla manualmente con player:LoadCharacter()
Players.CharacterAutoLoads = false

-- Posición de spawn: lateral al campamento (que está en 0,0,-20)
local SPAWN_CF = CFrame.new(5, 3, -14)

-- Costo en gemas para revivir en el lugar de muerte
local COSTO_REVIVIR = 150

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

local carpetaEventos      = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evAtacarMelee       = obtenerOCrear(carpetaEventos, "RemoteEvent", "AtacarMelee")
local evReintentar        = obtenerOCrear(carpetaEventos, "RemoteEvent", "Reintentar")
local evRevivireAqui      = obtenerOCrear(carpetaEventos, "RemoteEvent", "RevivireAqui")
local evUsarVendaje       = obtenerOCrear(carpetaEventos, "RemoteEvent", "UsarVendaje")
local evVendajeActualizado = obtenerOCrear(carpetaEventos, "RemoteEvent", "VendajeActualizado")

-- cooldowns[player] = timestamp del último ataque aceptado
local cooldowns = {}

-- posicionesMuerte[player] = CFrame donde murió el jugador por última vez
local posicionesMuerte = {}

-- reviviendo[player] = CFrame destino si el próximo spawn es un revivir
local reviviendo = {}

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
	player:SetAttribute("Vendajes", 0)  -- inicializar vendajes al entrar

	-- Cada vez que el personaje aparece: posicionar y dar arma
	player.CharacterAdded:Connect(function(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if hrp then
			task.wait(0.15)   -- margen para que el motor termine de construir el rig

			-- Si viene de un revivir: usar la posición de muerte; si no, campamento base
			if reviviendo[player] then
				hrp.CFrame        = reviviendo[player]
				reviviendo[player] = nil
				-- Dar 50% de vida al revivir
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					task.wait(0.05)
					hum.Health = hum.MaxHealth * 0.5
				end
			elseif not player:GetAttribute("EnLobby") then
				-- Posicionar en el campamento de la sesión correspondiente
				local offsetX = player:GetAttribute("SesionOffsetX") or 0
				hrp.CFrame = CFrame.new(5 + offsetX, 3, -14)
			end
		end

		-- Entregar arma equipada (parenting directo al character = equipa de inmediato)
		local tipoArma = player:GetAttribute("ArmaEquipada") or Config.ARMA_INICIAL
		local tool = crearHerramienta(tipoArma)
		if tool then
			tool.Parent = character
		end

		-- Registrar qué arma tiene (legible desde otros scripts)
		player:SetAttribute("ArmaEquipada", tipoArma)

		-- Capturar posición cuando el jugador muera (para revivir en el lugar)
		local hum = character:WaitForChild("Humanoid", 5)
		if hum and hrp then
			hum.Died:Connect(function()
				if hrp and hrp.Parent then
					posicionesMuerte[player] = CFrame.new(hrp.Position)
				end
			end)
		end
	end)

	-- El spawn inicial lo maneja Lobby.server.luau
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player]        = nil
	posicionesMuerte[player] = nil
	reviviendo[player]       = nil
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
-- Volver al Lobby: redirige al SpawnLobby y resetea el estado
-- ============================================================
evReintentar.OnServerEvent:Connect(function(player)
	-- Notificar al gestor de sesiones antes de resetear atributos
	SesionManager.playerSale(player)
	player:SetAttribute("EnLobby", true)
	player:SetAttribute("ArmaEquipada", "Palo")
	player:SetAttribute("KitComprado", nil)
	-- Resetear vendajes al salir al lobby (se pierde el progreso de la partida)
	player:SetAttribute("Vendajes", 0)
	evVendajeActualizado:FireClient(player, 0)
	local spawnLobby = workspace:FindFirstChild("SpawnLobby")
	if spawnLobby then
		player.RespawnLocation = spawnLobby
	end
	player:LoadCharacter()
end)

-- ============================================================
-- Revivir en el lugar (descuenta COSTO_REVIVIR gemas)
-- ============================================================
evRevivireAqui.OnServerEvent:Connect(function(player)
	-- Validar y descontar gemas server-side (evita exploits)
	if not GemasManager.gastar(player, COSTO_REVIVIR) then
		print(string.format("[Combate] %s intentó revivir pero no tiene gemas suficientes.", player.Name))
		return
	end

	-- Marcar destino del próximo spawn como la posición de muerte
	local cf = posicionesMuerte[player]
	if cf then
		reviviendo[player] = cf
	end

	player:LoadCharacter()
end)

-- ============================================================
-- Usar Vendaje desde la pantalla de muerte (revive en el lugar con 50% HP)
-- ============================================================
evUsarVendaje.OnServerEvent:Connect(function(player)
	local actual = player:GetAttribute("Vendajes") or 0
	if actual < 1 then
		print(string.format("[Combate] %s intentó usar vendaje pero no tiene.", player.Name))
		return
	end

	-- Consumir el vendaje
	local nuevo = actual - 1
	player:SetAttribute("Vendajes", nuevo)
	evVendajeActualizado:FireClient(player, nuevo)

	-- Revivir en el lugar de muerte (reutiliza la misma lógica que RevivireAqui)
	local cf = posicionesMuerte[player]
	if cf then
		reviviendo[player] = cf
	end

	print(string.format("[Combate] %s usó un Vendaje. Le quedan %d.", player.Name, nuevo))
	player:LoadCharacter()
end)

print("[Combate] Sistema de combate iniciado.")
