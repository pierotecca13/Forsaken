-- Mesa.server.luau
-- Gestiona la Mesa de Trabajo:
--   · Construcción desde el Campamento (SolicitarMesa)
--   · Crafteo de ítems (SolicitarCrafteo)
--   · Colocación de Antorcha / Hoguera en el mundo (ColocarItem)
--
-- Las Hogueras colocadas se registran en Workspace.HoguerasActivas para
-- que Enemigos.server pueda calcular la repulsión de corrompidos.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MesaConfig    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MesaConfig"))
local InventarioMgr = require(script.Parent:FindFirstChild("InventarioManager"))

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

local carpetaEventos          = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evSolicitarMesa         = obtenerOCrear(carpetaEventos, "RemoteEvent", "SolicitarMesa")
local evResultadoConstruccion = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoConstruccion")
local evAbrirMesa             = obtenerOCrear(carpetaEventos, "RemoteEvent", "AbrirMesaTrabajo")
local evSolicitarCrafteo      = obtenerOCrear(carpetaEventos, "RemoteEvent", "SolicitarCrafteo")
local evResultadoCrafteo      = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoCrafteo")
local evColocarItem           = obtenerOCrear(carpetaEventos, "RemoteEvent", "ColocarItem")

-- ============================================================
-- Carpeta de hogueras activas (leída por Enemigos.server)
-- ============================================================
local carpetaHogueras = obtenerOCrear(workspace, "Folder", "HoguerasActivas")

-- ============================================================
-- Estado global
-- ============================================================
local mesaConstruida = false

-- ============================================================
-- Construir el modelo visual de la Mesa en el mundo
-- ============================================================
local function crearModeloMesa()
	local pos = MesaConfig.POSICION_MESA

	local carpeta = Instance.new("Folder")
	carpeta.Name   = "MesaTrabajo"
	carpeta.Parent = workspace

	-- Tablero superior (superficie de trabajo)
	local tablero = Instance.new("Part")
	tablero.Name      = "Tablero"
	tablero.Size      = Vector3.new(3.2, 0.25, 2)
	tablero.CFrame    = CFrame.new(pos)
	tablero.Anchored  = true
	tablero.Color     = Color3.fromRGB(100, 70, 40)
	tablero.Material  = Enum.Material.Wood
	tablero.Parent    = carpeta

	-- Soporte/cajón inferior
	local base = Instance.new("Part")
	base.Name     = "Base"
	base.Size     = Vector3.new(2.8, 0.9, 1.6)
	base.CFrame   = CFrame.new(pos + Vector3.new(0, -0.57, 0))
	base.Anchored = true
	base.Color    = Color3.fromRGB(80, 55, 30)
	base.Material = Enum.Material.Wood
	base.Parent   = carpeta

	-- Billboard flotante
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 160, 0, 28)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Parent      = tablero

	local lblBB = Instance.new("TextLabel")
	lblBB.Size                = UDim2.new(1, 0, 1, 0)
	lblBB.BackgroundTransparency = 1
	lblBB.Text                = "Mesa de Trabajo"
	lblBB.Font                = Enum.Font.GothamBold
	lblBB.TextScaled          = true
	lblBB.TextColor3          = Color3.fromRGB(255, 215, 100)
	lblBB.TextStrokeTransparency = 0.4
	lblBB.Parent              = bb

	-- ProximityPrompt para abrir el menú
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Abrir"
	prompt.ObjectText            = "Mesa de Trabajo"
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.Parent                = tablero

	-- Conectar prompt al evento de apertura de menú
	prompt.Triggered:Connect(function(player)
		evAbrirMesa:FireClient(player, {
			inventario = InventarioMgr.obtener(player),
			arma       = player:GetAttribute("ArmaEquipada") or "Palo",
			armadura   = player:GetAttribute("ArmaduraEquipada") or "SinArmadura",
		})
	end)

	return carpeta
end

-- ============================================================
-- Crear Antorcha en el mundo
-- ============================================================
local function crearAntorcha(posicion)
	local receta = MesaConfig.RECETAS.Antorcha

	local carpetaAnt = Instance.new("Folder")
	carpetaAnt.Name   = "Antorcha_Mundo"
	carpetaAnt.Parent = workspace

	-- Palo
	local palo = Instance.new("Part")
	palo.Name     = "Palo"
	palo.Size     = Vector3.new(0.2, 0.8, 0.2)
	palo.CFrame   = CFrame.new(posicion + Vector3.new(0, 0.4, 0))
	palo.Anchored = true
	palo.Color    = Color3.fromRGB(90, 60, 30)
	palo.Material = Enum.Material.Wood
	palo.Parent   = carpetaAnt

	-- Llama (neon)
	local llama = Instance.new("Part")
	llama.Name      = "Llama"
	llama.Shape     = Enum.PartType.Ball
	llama.Size      = Vector3.new(0.35, 0.35, 0.35)
	llama.CFrame    = CFrame.new(posicion + Vector3.new(0, 0.9, 0))
	llama.Anchored  = true
	llama.Color     = receta.colorLuz
	llama.Material  = Enum.Material.Neon
	llama.CanCollide = false
	llama.CastShadow = false
	llama.Parent    = carpetaAnt

	-- Luz puntual
	local luz = Instance.new("PointLight")
	luz.Brightness = receta.brilloLuz
	luz.Color      = receta.colorLuz
	luz.Range      = receta.radioLuz
	luz.Parent     = llama

	-- Registrar en HoguerasActivas para que Enemigos.server la detecte
	local marcadorAnt = Instance.new("Part")
	marcadorAnt.Name        = "RadioAntorcha"
	marcadorAnt.Size        = Vector3.new(1, 1, 1)
	marcadorAnt.Anchored    = true
	marcadorAnt.CanCollide  = false
	marcadorAnt.Transparency = 1
	marcadorAnt.CFrame      = CFrame.new(posicion)
	marcadorAnt:SetAttribute("Radio", receta.radioRepulsion)
	marcadorAnt.Parent      = carpetaHogueras

	-- Auto-apagar tras la duración configurada
	task.delay(receta.duracion, function()
		-- Apagado gradual
		for i = 1, 6 do
			task.wait(0.1)
			if llama and llama.Parent then
				llama.Transparency = i / 6
				luz.Brightness     = receta.brilloLuz * (1 - i / 6)
			end
		end
		if marcadorAnt and marcadorAnt.Parent then marcadorAnt:Destroy() end
		if carpetaAnt and carpetaAnt.Parent then
			carpetaAnt:Destroy()
		end
	end)
end

-- ============================================================
-- Crear Hoguera Portátil en el mundo
-- ============================================================
local function crearHoguera(posicion)
	local receta = MesaConfig.RECETAS.Hoguera

	local carpetaHog = Instance.new("Folder")
	carpetaHog.Name   = "Hoguera_Mundo"
	carpetaHog.Parent = workspace

	-- Base de piedras (base)
	local base = Instance.new("Part")
	base.Name     = "Base"
	base.Size     = Vector3.new(0.9, 0.15, 0.9)
	base.CFrame   = CFrame.new(posicion)
	base.Anchored = true
	base.Color    = Color3.fromRGB(130, 125, 120)
	base.Material = Enum.Material.Slate
	base.Parent   = carpetaHog

	-- Fuego principal
	local fuego = Instance.new("Part")
	fuego.Name      = "Fuego"
	fuego.Shape     = Enum.PartType.Ball
	fuego.Size      = Vector3.new(0.8, 0.8, 0.8)
	fuego.CFrame    = CFrame.new(posicion + Vector3.new(0, 0.5, 0))
	fuego.Anchored  = true
	fuego.Color     = receta.colorLuz
	fuego.Material  = Enum.Material.Neon
	fuego.CanCollide = false
	fuego.CastShadow = false
	fuego.Parent    = carpetaHog

	-- Luz intensa
	local luz = Instance.new("PointLight")
	luz.Brightness = receta.brilloLuz
	luz.Color      = receta.colorLuz
	luz.Range      = receta.radioLuz
	luz.Parent     = fuego

	-- Registrar en HoguerasActivas para que Enemigos.server la detecte
	local marcador = Instance.new("Part")
	marcador.Name        = "RadioHoguera"
	marcador.Size        = Vector3.new(1, 1, 1)
	marcador.Anchored    = true
	marcador.CanCollide  = false
	marcador.Transparency = 1
	marcador.CFrame      = CFrame.new(posicion)
	marcador:SetAttribute("Radio", receta.radioRepulsion)
	marcador.Parent      = carpetaHogueras

	-- Auto-apagar tras la duración configurada
	task.delay(receta.duracion, function()
		for i = 1, 6 do
			task.wait(0.15)
			if fuego and fuego.Parent then
				fuego.Transparency = i / 6
				luz.Brightness     = receta.brilloLuz * (1 - i / 6)
			end
		end
		if marcador and marcador.Parent then marcador:Destroy() end
		if carpetaHog and carpetaHog.Parent then carpetaHog:Destroy() end
	end)
end

-- ============================================================
-- Obtener posición delante del jugador para colocar el ítem
-- ============================================================
local function posicionColocacion(player)
	local character = player.Character
	if not character then return Vector3.new(0, 1, 0) end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return Vector3.new(0, 1, 0) end
	-- 3 studs delante del jugador, a nivel del suelo
	return hrp.Position + hrp.CFrame.LookVector * 3 + Vector3.new(0, -hrp.Size.Y / 2, 0)
end

-- ============================================================
-- HANDLER: Solicitar construcción de la Mesa
-- ============================================================
evSolicitarMesa.OnServerEvent:Connect(function(player)
	-- Evitar duplicados
	if mesaConstruida then
		evResultadoConstruccion:FireClient(player, {
			exito   = false,
			mensaje = "La mesa ya está construida.",
		})
		return
	end

	-- Descontar costo del inventario
	local ok, faltante = InventarioMgr.descontar(player, MesaConfig.COSTO_CONSTRUCCION)
	if not ok then
		local nombre = faltante or "materiales"
		evResultadoConstruccion:FireClient(player, {
			exito   = false,
			mensaje = string.format("Necesitas %d Madera y %d Piedra. (Falta: %s)",
				MesaConfig.COSTO_CONSTRUCCION.Madera,
				MesaConfig.COSTO_CONSTRUCCION.Piedra,
				nombre),
		})
		return
	end

	-- Construir mesa en el mundo
	mesaConstruida = true
	crearModeloMesa()

	evResultadoConstruccion:FireClient(player, {
		exito   = true,
		mensaje = "Mesa de Trabajo construida!",
	})

	print(string.format("[Mesa] %s construyó la Mesa de Trabajo.", player.Name))
end)

-- ============================================================
-- HANDLER: Craftear ítem en la Mesa
-- ============================================================
evSolicitarCrafteo.OnServerEvent:Connect(function(player, tipo)
	local receta = MesaConfig.RECETAS[tipo]
	if not receta then return end

	local inv = InventarioMgr.obtener(player)

	-- Comprobar límite máximo de ese ítem en inventario
	if (inv[tipo] or 0) >= receta.maxInventario then
		evResultadoCrafteo:FireClient(player, {
			exito   = false,
			mensaje = "Ya llevas el máximo de " .. receta.nombre .. " (" .. receta.maxInventario .. ").",
		})
		return
	end

	-- Comprobar y descontar materiales
	local ok, faltante = InventarioMgr.descontar(player, receta.costo)
	if not ok then
		evResultadoCrafteo:FireClient(player, {
			exito   = false,
			mensaje = "Materiales insuficientes para " .. receta.nombre .. ".",
		})
		return
	end

	-- Agregar el ítem crafteado al inventario
	-- (Los materiales ya se descontaron; forzamos el add sin fallo de slots)
	local invActual = InventarioMgr.obtener(player)
	invActual[tipo] = (invActual[tipo] or 0) + 1
	InventarioMgr.enviar(player)

	evResultadoCrafteo:FireClient(player, {
		exito   = true,
		tipo    = tipo,
		nombre  = receta.nombre,
		mensaje = receta.nombre .. " crafteada!",
	})

	print(string.format("[Mesa] %s crafteó %s.", player.Name, tipo))
end)

-- ============================================================
-- HANDLER: Colocar ítem en el mundo (Antorcha = T, Hoguera = G)
-- ============================================================
evColocarItem.OnServerEvent:Connect(function(player, tipo)
	local inv = InventarioMgr.obtener(player)

	-- Verificar que el jugador tiene el ítem
	if (inv[tipo] or 0) <= 0 then return end

	-- Descontar 1 unidad del inventario
	InventarioMgr.descontar(player, { [tipo] = 1 })

	-- Obtener posición de colocación
	local pos = posicionColocacion(player)

	-- Crear el objeto en el mundo
	if tipo == "Antorcha" then
		crearAntorcha(pos)
	elseif tipo == "Hoguera" then
		crearHoguera(pos)
	end

	print(string.format("[Mesa] %s colocó %s en el mundo.", player.Name, tipo))
end)

print("[Mesa] Sistema de Mesa de Trabajo iniciado.")
