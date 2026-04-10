-- [SESIONES] Este script fue reemplazado por el sistema de sesiones por grupo.
-- SesionManager.luau orquesta la creación de mundos por sesión.
do return end

-- Cofres.server.luau
-- Genera cofres en el mundo con timers y recompensas de gemas.
-- Tipos: Madera (1-2 gemas, 5 max, cada 6min)
--        Piedra (3-5 gemas, 3 max, cada 8min)
--        Dorado (6-10 gemas, 2 max, cada 10min)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local ServerStorage     = game:GetService("ServerStorage")

local GemasManager  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemasManager"))
local CofresConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CofresConfig"))

-- Evento para notificar al cliente cuántos vendajes tiene
local carpetaEventos      = ReplicatedStorage:WaitForChild("Eventos")
local evVendajeActualizado = carpetaEventos:WaitForChild("VendajeActualizado")

-- Plantilla del cofre de madera 3D (modelo "CofreMadera" de Culmbzy en ServerStorage)
local plantillaCofreMadera  = ServerStorage:FindFirstChild("CofreMadera")
-- Plantilla del cofre de piedra 3D (modelo "CofrePiedra" de EmpressRaven en ServerStorage)
local plantillaCofrePiedra  = ServerStorage:FindFirstChild("CofrePiedra")
-- Plantilla del cofre dorado 3D (modelo "CofresDorado" de julekpolak551 en ServerStorage)
local plantillaCofresDorado = ServerStorage:FindFirstChild("CofresDorado")

-- ============================================================
-- Cargar posiciones de WorldGen (con fallback a CofresConfig)
-- ============================================================
local function cargarPosicionesCofres()
	local carpeta = Workspace:WaitForChild("PosicionesCofres", 10)
	local lista = {}
	if carpeta then
		for _, v in ipairs(carpeta:GetChildren()) do
			if v:IsA("Vector3Value") then
				table.insert(lista, v.Value)
			end
		end
	end
	if #lista == 0 then
		warn("[Cofres] PosicionesCofres vacío — usando fallback de CofresConfig.")
		lista = CofresConfig.POSICIONES_SPAWN
	end
	return lista
end

local POSICIONES_SPAWN = cargarPosicionesCofres()

-- ============================================================
-- Estado de partida
-- ============================================================
local contadores        = { Madera = 0, Piedra = 0, Dorado = 0 }
local posicionesOcupadas = {}   -- { [tostring(Vector3)] = true }

-- ============================================================
-- Helpers
-- ============================================================

-- Devuelve una posición libre aleatoria del pool, o nil si no hay
local function posicionLibre()
	local disponibles = {}
	for _, pos in ipairs(POSICIONES_SPAWN) do
		if not posicionesOcupadas[tostring(pos)] then
			table.insert(disponibles, pos)
		end
	end
	if #disponibles == 0 then return nil end
	return disponibles[math.random(#disponibles)]
end

-- ============================================================
-- Recompensa del cofre: vendaje (si hay suerte y cupo) o gemas
-- ============================================================
local function darRecompensa(player, cfg)
	local chance = cfg.chanceVendaje or 0
	local vendajesActuales = player:GetAttribute("Vendajes") or 0

	if chance > 0 and vendajesActuales < 2 and math.random() < chance then
		-- Da un vendaje en lugar de gemas
		local nuevo = vendajesActuales + 1
		player:SetAttribute("Vendajes", nuevo)
		evVendajeActualizado:FireClient(player, nuevo)
		print(string.format("[Cofres] %s recibió un Vendaje (%d/2).", player.Name, nuevo))
	else
		-- Da gemas normalmente
		local gemas = math.random(cfg.gemasMin, cfg.gemasMax)
		GemasManager.agregar(player, gemas)
		print(string.format("[Cofres] %s recogió %s: +%d gemas.", player.Name, cfg.nombre, gemas))
	end
end

-- ============================================================
-- Cofres 3D con modelo desde ServerStorage
-- Soporta MeshPart directo o Model con múltiples partes.
-- ============================================================
local TAMANO_COFRE = Vector3.new(3, 2.3, 1.8)  -- tamaño uniforme para todos los cofres 3D

local function crearCofre3D(plantilla, nombre, pos, cfg)
	local modelo = plantilla:Clone()
	modelo.Name = nombre

	-- Deshabilitar scripts decorativos del modelo de Toolbox
	for _, desc in ipairs(modelo:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") then
			desc.Disabled = true
		end
	end

	local partes = {}
	local ancla

	if modelo:IsA("BasePart") then
		local s      = modelo.Size
		local factor = math.min(TAMANO_COFRE.X / s.X, TAMANO_COFRE.Y / s.Y, TAMANO_COFRE.Z / s.Z)
		modelo.Size       = s * factor
		modelo.CFrame     = CFrame.new(pos.X, 0.4 + modelo.Size.Y / 2, pos.Z)
		modelo.Anchored   = true
		modelo.CanCollide = true
		table.insert(partes, modelo)
		ancla = modelo
	else
		local _, bbSize = modelo:GetBoundingBox()
		local factor    = math.min(TAMANO_COFRE.X / bbSize.X, TAMANO_COFRE.Y / bbSize.Y, TAMANO_COFRE.Z / bbSize.Z)
		modelo:ScaleTo(factor)

		local bbCF2, bbSize2 = modelo:GetBoundingBox()
		local bottomY     = bbCF2.Position.Y - bbSize2.Y / 2
		local deltaY      = 0.4 - bottomY
		local pivotActual = modelo:GetPivot()
		modelo:PivotTo(CFrame.new(pos.X, pivotActual.Position.Y + deltaY, pos.Z))

		for _, desc in ipairs(modelo:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(partes, desc)
			end
		end
		ancla = modelo.PrimaryPart or partes[1]
	end

	modelo.Parent = workspace
	if not ancla then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Abrir"
	prompt.ObjectText            = "Cofre"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration          = 0
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = ancla

	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled then return end
		prompt.Enabled = false

		darRecompensa(player, cfg)

		posicionesOcupadas[tostring(pos)] = nil

		task.delay(0.4, function()
			if modelo and modelo.Parent then
				modelo:Destroy()
			end
		end)
	end)
end

-- ============================================================
-- Crear cofre en el mundo
-- ============================================================
local function crearCofre(tipo, pos)
	local cfg = CofresConfig.TIPOS[tipo]

	-- Cofres 3D: usar modelo de Toolbox si la plantilla está disponible
	if tipo == "Madera" and plantillaCofreMadera then
		crearCofre3D(plantillaCofreMadera, "Cofre_Madera", pos, cfg)
		return
	end
	if tipo == "Piedra" and plantillaCofrePiedra then
		crearCofre3D(plantillaCofrePiedra, "Cofre_Piedra", pos, cfg)
		return
	end
	if tipo == "Dorado" and plantillaCofresDorado then
		crearCofre3D(plantillaCofresDorado, "Cofre_Dorado", pos, cfg)
		return
	end

	-- Modelo raíz
	local cofreModel = Instance.new("Model")
	cofreModel.Name   = "Cofre_" .. tipo
	cofreModel.Parent = workspace

	-- Cuerpo principal del cofre
	local cuerpo = Instance.new("Part")
	cuerpo.Name      = "Cuerpo"
	cuerpo.Size      = Vector3.new(2, 1.2, 1.2)
	cuerpo.CFrame    = CFrame.new(pos)
	cuerpo.Anchored  = true
	cuerpo.CanCollide = true
	cuerpo.Color     = cfg.color
	cuerpo.Material  = cfg.material
	cuerpo.Parent    = cofreModel
	cofreModel.PrimaryPart = cuerpo

	-- Tapa del cofre (ligeramente más clara)
	local tapa = Instance.new("Part")
	tapa.Name      = "Tapa"
	tapa.Size      = Vector3.new(2.05, 0.35, 1.25)
	tapa.Anchored  = true
	tapa.CanCollide = false
	tapa.Color     = Color3.new(
		math.min(cfg.color.R + 0.06, 1),
		math.min(cfg.color.G + 0.06, 1),
		math.min(cfg.color.B + 0.06, 1)
	)
	tapa.Material  = cfg.material
	tapa.CFrame    = CFrame.new(pos + Vector3.new(0, 0.775, 0))
	tapa.Parent    = cofreModel

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cuerpo
	soldadura.Part1 = tapa
	soldadura.Parent = cuerpo

	-- Destello dorado para el cofre dorado
	if tipo == "Dorado" then
		local brillo = Instance.new("SelectionBox")
		brillo.Adornee      = cofreModel
		brillo.Color3       = Color3.fromRGB(255, 220, 0)
		brillo.LineThickness = 0.04
		brillo.Parent       = cofreModel
	end

	-- ProximityPrompt para recoger
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText           = "Abrir"
	prompt.ObjectText           = "Cofre"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration         = 0
	prompt.KeyboardKeyCode      = Enum.KeyCode.E
	prompt.Parent               = cuerpo

	-- Al recoger: dar gemas y destruir cofre
	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled then return end
		prompt.Enabled = false

		darRecompensa(player, cfg)

		-- Liberar la posición para futuros spawns
		posicionesOcupadas[tostring(pos)] = nil

		task.delay(0.4, function()
			if cofreModel and cofreModel.Parent then
				cofreModel:Destroy()
			end
		end)
	end)
end

-- ============================================================
-- Loops de spawn (uno por tipo, arrancan al iniciar el servidor)
-- ============================================================
for tipo, cfg in pairs(CofresConfig.TIPOS) do
	task.spawn(function()
		while true do
			task.wait(cfg.intervalo)
			if contadores[tipo] < cfg.maxPartida then
				local pos = posicionLibre()
				if pos then
					posicionesOcupadas[tostring(pos)] = true
					contadores[tipo] += 1
					crearCofre(tipo, pos)
					print(string.format("[Cofres] Cofre %s spawneado en %s (total: %d/%d).",
						tipo, tostring(pos), contadores[tipo], cfg.maxPartida))
				end
			end
		end
	end)
end

print("[Cofres] Sistema de cofres iniciado.")
