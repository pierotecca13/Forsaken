-- Lobby.server.luau
-- Autoridad del servidor para el lobby: construcción del mundo,
-- compra de kits, sistema de cuadros de fiesta y lanzamiento al juego.
-- No toca ningún sistema de combate, inventario ni gemas existente.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local GemasManager     = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemasManager"))
local InventarioManager= require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("InventarioManager"))
local LobbyConfig      = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyConfig"))
local SesionManager    = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("SesionManager"))

-- ============================================================
-- Helper: obtener o crear instancia
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

-- ============================================================
-- Eventos remotos del lobby
-- ============================================================
local carpetaEventos = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")

local evLobbyEntrar        = obtenerOCrear(carpetaEventos, "RemoteEvent", "LobbyEntrar")        -- S→C
local evLobbyComprarKit    = obtenerOCrear(carpetaEventos, "RemoteEvent", "LobbyComprarKit")    -- C→S
local evLobbyResultadoKit  = obtenerOCrear(carpetaEventos, "RemoteEvent", "LobbyResultadoKit")  -- S→C
local evLobbyCuadroUnirse  = obtenerOCrear(carpetaEventos, "RemoteEvent", "LobbyCuadroUnirse")  -- C→S
local evLobbyCuadroSalir   = obtenerOCrear(carpetaEventos, "RemoteEvent", "LobbyCuadroSalir")   -- C→S
local evLobbyCuadroEstado  = obtenerOCrear(carpetaEventos, "RemoteEvent", "LobbyCuadroEstado")  -- S→AllClients
local evLobbyIniciarPartida= obtenerOCrear(carpetaEventos, "RemoteEvent", "LobbyIniciarPartida")-- C→S

-- ============================================================
-- Estado del servidor
-- ============================================================
local enLobby        = {}  -- [player] = true mientras esté en la zona del lobby
local transicionando = {}  -- [player] = true mientras espera CharacterAdded para aplicar kit

-- 3 cuadros de fiesta, cada uno con hasta 4 jugadores
local cuadros = {
	[1] = { jugadores = {}, iniciando = false },
	[2] = { jugadores = {}, iniciando = false },
	[3] = { jugadores = {}, iniciando = false },
}
local cuadroPorJugador = {}  -- [player] = índice del cuadro en que está

-- Referencias a los SpawnLocations creados al construir el lobby
local spawnLobby = nil
local spawnJuego = nil

-- Referencias a los BillboardGui y Parts de los cuadros
local billboardsCuadros = {}
local partesCuadros     = {}  -- [i] = Part del cuadro en el mundo 3D

-- Declaración adelantada: construirLobby referencia lanzarGrupo en un closure,
-- pero lanzarGrupo se define más abajo. En Lua, las funciones locales solo son
-- visibles desde su punto de declaración, así que se declara aquí como nil
-- y se asigna la implementación real más adelante.
local lanzarGrupo

-- ============================================================
-- Serializar estado de cuadros (solo nombres, seguro para FireAllClients)
-- ============================================================
local function serializarCuadros()
	local estado = {}
	for i = 1, 3 do
		local nombres = {}
		for _, p in ipairs(cuadros[i].jugadores) do
			table.insert(nombres, p.Name)
		end
		estado[i] = nombres
	end
	return estado
end

-- ============================================================
-- Actualizar BillboardGuis 3D de los cuadros y notificar clientes
-- ============================================================
local function actualizarCuadros()
	local estado = serializarCuadros()

	-- Actualizar BillboardGui del mundo 3D
	for i = 1, 3 do
		local bb = billboardsCuadros[i]
		if bb then
			local label = bb:FindFirstChild("JugadoresLabel")
			if label then
				local txt = ""
				for slot = 1, 4 do
					local nombre = estado[i][slot] or "---"
					txt = txt .. slot .. ". " .. nombre .. "\n"
				end
				label.Text = txt
			end
		end
	end

	-- Notificar a todos los clientes para que actualicen su UI
	evLobbyCuadroEstado:FireAllClients(estado)
end

-- ============================================================
-- Quitar jugador de su cuadro actual (si está en uno)
-- ============================================================
local function salirDeCuadro(player)
	local idx = cuadroPorJugador[player]
	if not idx then return end

	-- Eliminar de la lista de jugadores del cuadro
	local lista = cuadros[idx].jugadores
	for i, p in ipairs(lista) do
		if p == player then
			table.remove(lista, i)
			break
		end
	end

	cuadroPorJugador[player] = nil
	actualizarCuadros()
end

-- ============================================================
-- Construir el mundo del lobby (se llama una sola vez al iniciar)
-- ============================================================
local function construirLobby()
	-- Carpeta contenedora
	local lobbyArea = Instance.new("Folder")
	lobbyArea.Name   = "LobbyArea"
	lobbyArea.Parent = workspace

	-- Plataforma oscura
	local suelo = Instance.new("Part")
	suelo.Name        = "SueloLobby"
	suelo.Size        = Vector3.new(100, 0.5, 60)
	suelo.CFrame      = CFrame.new(-500, 500.25, 0)
	suelo.Anchored    = true
	suelo.Material    = Enum.Material.SmoothPlastic
	suelo.Color       = Color3.fromRGB(20, 20, 28)
	suelo.Parent      = lobbyArea

	-- SpawnLocation del lobby (donde aparecen los jugadores al entrar/volver)
	local sl = Instance.new("SpawnLocation")
	sl.Name        = "SpawnLobby"
	sl.Size        = Vector3.new(4, 0.4, 4)
	sl.CFrame      = LobbyConfig.SPAWN_LOBBY_CF
	sl.Anchored    = true
	sl.Neutral     = true
	sl.Duration    = 0
	sl.Color       = Color3.fromRGB(163, 162, 165)  -- gris piedra
	sl.Material    = Enum.Material.SmoothPlastic
	sl.Parent      = lobbyArea
	spawnLobby     = sl

	-- SpawnLocation del juego (desactivado, solo se usa como RespawnLocation)
	local sj = Instance.new("SpawnLocation")
	sj.Name        = "SpawnJuego"
	sj.Size        = Vector3.new(4, 0.4, 4)
	sj.CFrame      = LobbyConfig.SPAWN_JUEGO_CF
	sj.Anchored    = true
	sj.Neutral     = true
	sj.Enabled      = false  -- desactivado: los jugadores no aparecen aquí automáticamente
	sj.Duration     = 0
	sj.Color        = Color3.fromRGB(75, 151, 75)
	sj.Material     = Enum.Material.SmoothPlastic
	sj.Transparency = 1      -- invisible: Enabled=false no oculta la Part visualmente
	sj.CanCollide   = false  -- no bloquea el movimiento del jugador
	sj.Parent       = workspace
	spawnJuego     = sj

	-- ── Crear los 3 cofres de kit ─────────────────────────────
	local carpetaCofres = Instance.new("Folder")
	carpetaCofres.Name   = "CofresKit"
	carpetaCofres.Parent = lobbyArea

	local ordenCofres = { "Explorador", "Combatiente", "Craftero" }
	local coloresCofres = {
		Explorador  = Color3.fromRGB(120, 80, 40),   -- madera cálida
		Combatiente = Color3.fromRGB(80, 80, 100),   -- gris acero
		Craftero    = Color3.fromRGB(60, 100, 60),   -- verde bosque
	}

	for _, kitId in ipairs(ordenCofres) do
		local pos  = LobbyConfig.POSICIONES_COFRES[kitId]
		local cfg  = LobbyConfig.KITS[kitId]
		local color = coloresCofres[kitId]

		local modelo = Instance.new("Model")
		modelo.Name   = "Cofre_" .. kitId
		modelo.Parent = carpetaCofres

		-- Cuerpo del cofre
		local cuerpo = Instance.new("Part")
		cuerpo.Name     = "Cuerpo"
		cuerpo.Size     = Vector3.new(2, 1.2, 1.2)
		cuerpo.CFrame   = CFrame.new(pos)
		cuerpo.Anchored = true
		cuerpo.Material = Enum.Material.Wood
		cuerpo.Color    = color
		cuerpo.Parent   = modelo
		modelo.PrimaryPart = cuerpo

		-- Tapa del cofre (visual)
		local tapa = Instance.new("Part")
		tapa.Name     = "Tapa"
		tapa.Size     = Vector3.new(2, 0.4, 1.2)
		tapa.CFrame   = CFrame.new(pos + Vector3.new(0, 0.8, 0))
		tapa.Anchored = true
		tapa.Material = Enum.Material.Wood
		tapa.Color    = color
		tapa.Parent   = modelo

		-- BillboardGui con nombre del kit
		local bb = Instance.new("BillboardGui")
		bb.Name            = "NombreKit"
		bb.Size            = UDim2.new(0, 180, 0, 50)
		bb.StudsOffset     = Vector3.new(0, 2.2, 0)
		bb.AlwaysOnTop     = false
		bb.Parent          = cuerpo

		local lblNombre = Instance.new("TextLabel")
		lblNombre.Name            = "Nombre"
		lblNombre.Size            = UDim2.new(1, 0, 0.5, 0)
		lblNombre.Position        = UDim2.new(0, 0, 0, 0)
		lblNombre.BackgroundTransparency = 1
		lblNombre.Text            = cfg.nombre
		lblNombre.TextColor3      = Color3.fromRGB(255, 220, 120)
		lblNombre.TextScaled      = true
		lblNombre.Font            = Enum.Font.GothamBold
		lblNombre.Parent          = bb

		local lblDesc = Instance.new("TextLabel")
		lblDesc.Name             = "Descripcion"
		lblDesc.Size             = UDim2.new(1, 0, 0.5, 0)
		lblDesc.Position         = UDim2.new(0, 0, 0.5, 0)
		lblDesc.BackgroundTransparency = 1
		lblDesc.Text             = cfg.descripcion
		lblDesc.TextColor3       = Color3.fromRGB(200, 200, 200)
		lblDesc.TextScaled       = true
		lblDesc.Font             = Enum.Font.Gotham
		lblDesc.Parent           = bb

		-- ProximityPrompt para interactuar (tecla E)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText    = "Comprar kit (200 ◆)"
		prompt.ObjectText    = cfg.nombre
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration  = 0
		prompt.MaxActivationDistance = 8
		prompt.Parent        = cuerpo

		-- Capturar kitId en closure para el handler del prompt
		local kitIdLocal = kitId
		prompt.Triggered:Connect(function(player)
			-- La lógica de compra se maneja en la función comprarKit
			local ok, msg = false, ""

			-- Guard: debe estar en lobby
			if not enLobby[player] then
				evLobbyResultadoKit:FireClient(player, false, "No estás en el lobby")
				return
			end

			-- Guard: ya compró un kit esta partida
			if player:GetAttribute("KitComprado") ~= nil then
				evLobbyResultadoKit:FireClient(player, false, "Ya compraste un kit esta partida")
				return
			end

			-- Guard: kit válido
			local kitCfg = LobbyConfig.KITS[kitIdLocal]
			if not kitCfg then
				evLobbyResultadoKit:FireClient(player, false, "Kit inválido")
				return
			end

			-- Intentar gastar gemas
			if not GemasManager.gastar(player, LobbyConfig.PRECIO_KIT) then
				evLobbyResultadoKit:FireClient(player, false, "Gemas insuficientes")
				return
			end

			-- Registrar la compra como atributo del jugador
			player:SetAttribute("KitComprado", kitIdLocal)
			evLobbyResultadoKit:FireClient(player, true, "Kit adquirido: " .. kitCfg.nombre)
			print(string.format("[Lobby] %s compró el %s", player.Name, kitCfg.nombre))
		end)
	end

	-- ── Crear los 3 cuadros de fiesta ─────────────────────────
	local carpetaCuadros = Instance.new("Folder")
	carpetaCuadros.Name   = "CuadrosFiesta"
	carpetaCuadros.Parent = lobbyArea

	for i, pos in ipairs(LobbyConfig.POSICIONES_CUADROS) do
		local cuadroPart = Instance.new("Part")
		cuadroPart.Name     = "Cuadro_" .. i
		cuadroPart.Size     = Vector3.new(7, 0.3, 7)
		cuadroPart.CFrame   = CFrame.new(pos)
		cuadroPart.Anchored = true
		cuadroPart.Material = Enum.Material.Neon
		cuadroPart.Color    = Color3.fromRGB(40, 60, 100)
		cuadroPart.Parent   = carpetaCuadros

		-- BillboardGui con lista de jugadores (actualizable desde el servidor)
		local bb = Instance.new("BillboardGui")
		bb.Name          = "InfoCuadro"
		bb.Size          = UDim2.new(0, 160, 0, 120)
		bb.StudsOffset   = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop   = false
		bb.Parent        = cuadroPart

		local lblTitulo = Instance.new("TextLabel")
		lblTitulo.Name            = "Titulo"
		lblTitulo.Size            = UDim2.new(1, 0, 0.25, 0)
		lblTitulo.Position        = UDim2.new(0, 0, 0, 0)
		lblTitulo.BackgroundTransparency = 1
		lblTitulo.Text            = "Cuadro " .. i
		lblTitulo.TextColor3      = Color3.fromRGB(180, 220, 255)
		lblTitulo.TextScaled      = true
		lblTitulo.Font            = Enum.Font.GothamBold
		lblTitulo.Parent          = bb

		local lblJugadores = Instance.new("TextLabel")
		lblJugadores.Name            = "JugadoresLabel"
		lblJugadores.Size            = UDim2.new(1, 0, 0.75, 0)
		lblJugadores.Position        = UDim2.new(0, 0, 0.25, 0)
		lblJugadores.BackgroundTransparency = 1
		lblJugadores.Text            = "1. ---\n2. ---\n3. ---\n4. ---\n"
		lblJugadores.TextColor3      = Color3.fromRGB(200, 200, 200)
		lblJugadores.TextScaled      = true
		lblJugadores.Font            = Enum.Font.Gotham
		lblJugadores.Parent          = bb

		billboardsCuadros[i] = bb
		partesCuadros[i]     = cuadroPart

		-- ProximityPrompt para iniciar la partida desde el cuadro (tecla E)
		local promptEmpezar = Instance.new("ProximityPrompt")
		promptEmpezar.ActionText             = "Empezar"
		promptEmpezar.ObjectText             = "Cuadro " .. i
		promptEmpezar.KeyboardKeyCode        = Enum.KeyCode.E
		promptEmpezar.HoldDuration           = 0
		promptEmpezar.MaxActivationDistance  = 10
		promptEmpezar.Parent                 = cuadroPart

		local cuadroIdxLocal = i
		promptEmpezar.Triggered:Connect(function(player)
			-- Solo puede iniciar si está dentro de este cuadro
			if cuadroPorJugador[player] == cuadroIdxLocal then
				lanzarGrupo(cuadroIdxLocal)
			end
		end)
	end

	-- ── Ajustar iluminación para ambiente oscuro de bosque ────
	Lighting.Brightness     = 0.1
	Lighting.FogEnd         = 120
	Lighting.FogColor       = Color3.fromRGB(10, 15, 10)
	Lighting.OutdoorAmbient = Color3.fromRGB(15, 20, 15)
	Lighting.Ambient        = Color3.fromRGB(30, 35, 30)

	print("[Lobby] Mundo del lobby construido correctamente.")
end

-- ============================================================
-- Aplicar items de inventario del kit al inicio de la partida
-- ============================================================
local function aplicarKitInventario(player)
	local kitId = player:GetAttribute("KitComprado")
	if not kitId then return end

	local kitCfg = LobbyConfig.KITS[kitId]
	if not kitCfg then return end

	-- Agregar cada item del kit al inventario
	for recurso, cantidad in pairs(kitCfg.items) do
		InventarioManager.agregar(player, recurso, cantidad)
	end

	-- Limpiar el atributo una vez aplicado (para que no se aplique en respawns futuros)
	player:SetAttribute("KitComprado", nil)
	print(string.format("[Lobby] Kit '%s' aplicado al inventario de %s.", kitId, player.Name))
end

-- ============================================================
-- Enviar al jugador al lobby (spawn + flags)
-- ============================================================
local function enviarAlLobby(player)
	-- Marcar como en lobby y resetear estado de partida anterior
	player:SetAttribute("EnLobby", true)
	player:SetAttribute("KitComprado", nil)
	player:SetAttribute("ArmaEquipada", "Palo")

	enLobby[player] = true

	-- Posicionar el próximo spawn en el lobby
	if spawnLobby then
		player.RespawnLocation = spawnLobby
	end

	-- Cargar personaje (aparecerá en SpawnLobby)
	player:LoadCharacter()
end

-- ============================================================
-- Lanzar el grupo de un cuadro hacia el juego
-- (implementación de la declaración adelantada de arriba)
-- ============================================================
lanzarGrupo = function(cuadroIdx)
	local cuadro = cuadros[cuadroIdx]
	if not cuadro then return end

	-- Guard: ya se está lanzando este cuadro
	if cuadro.iniciando then return end
	cuadro.iniciando = true

	-- Copiar el grupo antes de limpiar el cuadro
	local grupo = {}
	for _, p in ipairs(cuadro.jugadores) do
		table.insert(grupo, p)
	end

	-- Limpiar el cuadro inmediatamente
	cuadro.jugadores = {}
	for _, p in ipairs(grupo) do
		cuadroPorJugador[p] = nil
	end
	actualizarCuadros()

	-- Preparar cada jugador (flags y arma inicial) — LoadCharacter lo llama SesionManager
	for _, player in ipairs(grupo) do
		enLobby[player]        = false
		transicionando[player] = true
		player:SetAttribute("EnLobby", false)

		local kitId = player:GetAttribute("KitComprado")
		if kitId then
			local kitCfg = LobbyConfig.KITS[kitId]
			if kitCfg and kitCfg.armaInicial then
				player:SetAttribute("ArmaEquipada", kitCfg.armaInicial)
			end
		end

		if spawnJuego then
			player.RespawnLocation = spawnJuego
		end
	end

	-- Crear sesión en coroutine separado (genera el mundo, llama LoadCharacter)
	task.spawn(function()
		SesionManager.nuevaSesion(grupo)
	end)

	cuadro.iniciando = false
	print(string.format("[Lobby] Cuadro %d lanzado al juego con %d jugadores.", cuadroIdx, #grupo))
end

-- ============================================================
-- Ciclo de vida del jugador
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	-- Conectar el listener de CharacterAdded para este jugador
	player.CharacterAdded:Connect(function(_character)
		if enLobby[player] then
			-- Spawn en lobby: mostrar UI del lobby al cliente
			task.wait(0.3)
			evLobbyEntrar:FireClient(player)

		elseif transicionando[player] then
			-- Spawn en juego: aplicar items de kit al inventario
			transicionando[player] = nil
			task.wait(0.5)  -- esperar a que el inventario esté listo
			aplicarKitInventario(player)
		end
	end)

	-- Mandar al lobby cuando el jugador entra por primera vez
	task.wait(0.1)  -- pequeño margen para que otros scripts inicialicen
	enviarAlLobby(player)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Limpiar estado del jugador
	salirDeCuadro(player)
	enLobby[player]        = nil
	transicionando[player] = nil
end)

-- ============================================================
-- Handlers de eventos remotos
-- ============================================================

-- Comprar kit desde el cliente (alternativa a ProximityPrompt en dispositivos sin teclado)
evLobbyComprarKit.OnServerEvent:Connect(function(player, kitId)
	if not enLobby[player] then
		evLobbyResultadoKit:FireClient(player, false, "No estás en el lobby")
		return
	end
	if player:GetAttribute("KitComprado") ~= nil then
		evLobbyResultadoKit:FireClient(player, false, "Ya compraste un kit esta partida")
		return
	end
	local kitCfg = LobbyConfig.KITS[kitId]
	if not kitCfg then
		evLobbyResultadoKit:FireClient(player, false, "Kit inválido")
		return
	end
	if not GemasManager.gastar(player, LobbyConfig.PRECIO_KIT) then
		evLobbyResultadoKit:FireClient(player, false, "Gemas insuficientes")
		return
	end
	player:SetAttribute("KitComprado", kitId)
	evLobbyResultadoKit:FireClient(player, true, "Kit adquirido: " .. kitCfg.nombre)
end)

-- Unirse a un cuadro de fiesta
evLobbyCuadroUnirse.OnServerEvent:Connect(function(player, cuadroIndex)
	if not enLobby[player] then return end
	if type(cuadroIndex) ~= "number" or cuadroIndex < 1 or cuadroIndex > 3 then return end

	local cuadro = cuadros[cuadroIndex]

	-- Si ya está en ese cuadro, no hacer nada
	if cuadroPorJugador[player] == cuadroIndex then return end

	-- Salir del cuadro actual si tiene uno
	salirDeCuadro(player)

	-- Verificar que el cuadro no esté lleno
	if #cuadro.jugadores >= 4 then
		evLobbyResultadoKit:FireClient(player, false, "El cuadro está lleno")
		return
	end

	table.insert(cuadro.jugadores, player)
	cuadroPorJugador[player] = cuadroIndex
	actualizarCuadros()
end)

-- Salir del cuadro actual
evLobbyCuadroSalir.OnServerEvent:Connect(function(player)
	salirDeCuadro(player)
end)

-- Iniciar partida desde el cuadro
evLobbyIniciarPartida.OnServerEvent:Connect(function(player)
	local idx = cuadroPorJugador[player]
	if not idx then
		-- Si no está en ningún cuadro, crear un grupo solo con él
		-- Buscar un cuadro libre o usar el primero disponible
		for i = 1, 3 do
			if #cuadros[i].jugadores == 0 and not cuadros[i].iniciando then
				table.insert(cuadros[i].jugadores, player)
				cuadroPorJugador[player] = i
				lanzarGrupo(i)
				return
			end
		end
		-- Si todos los cuadros tienen gente, simplemente lanzar solo
		enLobby[player]        = false
		transicionando[player] = true
		player:SetAttribute("EnLobby", false)
		local kitId = player:GetAttribute("KitComprado")
		if kitId then
			local kitCfg = LobbyConfig.KITS[kitId]
			if kitCfg and kitCfg.armaInicial then
				player:SetAttribute("ArmaEquipada", kitCfg.armaInicial)
			end
		end
		if spawnJuego then player.RespawnLocation = spawnJuego end
		task.spawn(function()
			SesionManager.nuevaSesion({ player })
		end)
		return
	end
	lanzarGrupo(idx)
end)

-- ============================================================
-- Inicialización
-- ============================================================
construirLobby()

-- Loop de detección de zona: cada 0.3s revisa qué jugadores están
-- parados encima de cada cuadro y actualiza la membresía automáticamente.
task.spawn(function()
	while true do
		task.wait(0.3)
		for i, parte in ipairs(partesCuadros) do
			local halfX = parte.Size.X / 2 + 1
			local halfZ = parte.Size.Z / 2 + 1
			local cf    = parte.CFrame

			for _, player in ipairs(Players:GetPlayers()) do
				if not enLobby[player] then continue end
				local char = player.Character
				if not char then continue end
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then continue end

				-- Convertir posición del jugador al espacio local del cuadro
				local rel   = cf:PointToObjectSpace(hrp.Position)
				local enZona = math.abs(rel.X) <= halfX
					and math.abs(rel.Z) <= halfZ
					and rel.Y < parte.Size.Y + 6
					and rel.Y > -parte.Size.Y - 1

				local cuadroActual = cuadroPorJugador[player]

				if enZona and cuadroActual ~= i then
					-- Entró en este cuadro; salir del anterior si tenía uno
					if cuadroActual then salirDeCuadro(player) end
					if #cuadros[i].jugadores < 4 then
						table.insert(cuadros[i].jugadores, player)
						cuadroPorJugador[player] = i
						actualizarCuadros()
					end
				elseif not enZona and cuadroActual == i then
					-- Salió de este cuadro
					salirDeCuadro(player)
				end
			end
		end
	end
end)

print("[Lobby] Sistema de lobby iniciado.")
