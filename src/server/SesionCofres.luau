-- SesionCofres.luau  (ModuleScript en ServerScriptService/Server/)
-- Crea y respawnea cofres para una sesión específica.
-- Función pública: M.crear(sesionId, carpetaSesion, sesionRef)
-- sesionRef.cancelar = true detiene los loops de respawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local GemasManager  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemasManager"))
local CofresConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CofresConfig"))

local function obtenerOCrear(parent, className, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(className)
		obj.Name   = nombre
		obj.Parent = parent
	end
	return obj
end

local carpetaEventos       = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evVendajeActualizado = obtenerOCrear(carpetaEventos, "RemoteEvent", "VendajeActualizado")

local plantillaCofreMadera  = ServerStorage:FindFirstChild("CofreMadera")
local plantillaCofrePiedra  = ServerStorage:FindFirstChild("CofrePiedra")
local plantillaCofresDorado = ServerStorage:FindFirstChild("CofresDorado")

local TAMANO_COFRE = Vector3.new(3, 2.3, 1.8)

local M = {}

-- ============================================================
-- Recompensa (mismo código que Cofres.server.luau)
-- ============================================================
local function darRecompensa(player, cfg)
	local chance          = cfg.chanceVendaje or 0
	local vendajesActuales = player:GetAttribute("Vendajes") or 0
	if chance > 0 and vendajesActuales < 2 and math.random() < chance then
		local nuevo = vendajesActuales + 1
		player:SetAttribute("Vendajes", nuevo)
		evVendajeActualizado:FireClient(player, nuevo)
		print(string.format("[SesionCofres] %s recibio un Vendaje (%d/2).", player.Name, nuevo))
	else
		local gemas = math.random(cfg.gemasMin, cfg.gemasMax)
		GemasManager.agregar(player, gemas)
		print(string.format("[SesionCofres] %s recogio %s: +%d gemas.", player.Name, cfg.nombre, gemas))
	end
end

-- ============================================================
-- Cofre 3D con modelo de ServerStorage
-- ============================================================
local function crearCofre3D(plantilla, nombre, pos, cfg, carpetaSesion, posicionesOcupadas, contadores, tipo)
	local modelo = plantilla:Clone()
	modelo.Name  = nombre

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
			if desc:IsA("BasePart") then table.insert(partes, desc) end
		end
		ancla = modelo.PrimaryPart or partes[1]
	end

	modelo.Parent = carpetaSesion
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
		contadores[tipo] = math.max(0, contadores[tipo] - 1)
		task.delay(0.4, function()
			if modelo and modelo.Parent then modelo:Destroy() end
		end)
	end)
end

-- ============================================================
-- Cofre procedural (fallback si no hay plantilla)
-- ============================================================
local function crearCofreProcedural(tipo, pos, cfg, carpetaSesion, posicionesOcupadas, contadores)
	local cofreModel = Instance.new("Model")
	cofreModel.Name   = "Cofre_" .. tipo
	cofreModel.Parent = carpetaSesion

	local cuerpo = Instance.new("Part")
	cuerpo.Name       = "Cuerpo"
	cuerpo.Size       = Vector3.new(2, 1.2, 1.2)
	cuerpo.CFrame     = CFrame.new(pos)
	cuerpo.Anchored   = true
	cuerpo.CanCollide = true
	cuerpo.Color      = cfg.color
	cuerpo.Material   = cfg.material
	cuerpo.Parent     = cofreModel
	cofreModel.PrimaryPart = cuerpo

	local tapa = Instance.new("Part")
	tapa.Name       = "Tapa"
	tapa.Size       = Vector3.new(2.05, 0.35, 1.25)
	tapa.Anchored   = true
	tapa.CanCollide = false
	tapa.Color      = Color3.new(
		math.min(cfg.color.R + 0.06, 1),
		math.min(cfg.color.G + 0.06, 1),
		math.min(cfg.color.B + 0.06, 1)
	)
	tapa.Material = cfg.material
	tapa.CFrame   = CFrame.new(pos + Vector3.new(0, 0.775, 0))
	tapa.Parent   = cofreModel

	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cuerpo; soldadura.Part1 = tapa; soldadura.Parent = cuerpo

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Abrir"
	prompt.ObjectText            = "Cofre"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration          = 0
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.Parent                = cuerpo

	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled then return end
		prompt.Enabled = false
		darRecompensa(player, cfg)
		posicionesOcupadas[tostring(pos)] = nil
		contadores[tipo] = math.max(0, contadores[tipo] - 1)
		task.delay(0.4, function()
			if cofreModel and cofreModel.Parent then cofreModel:Destroy() end
		end)
	end)
end

-- ============================================================
-- Dispatcher que elige 3D o procedural
-- ============================================================
local function crearCofre(tipo, pos, carpetaSesion, posicionesOcupadas, contadores)
	local cfg = CofresConfig.TIPOS[tipo]
	if tipo == "Madera" and plantillaCofreMadera then
		crearCofre3D(plantillaCofreMadera, "Cofre_Madera", pos, cfg, carpetaSesion, posicionesOcupadas, contadores, tipo)
	elseif tipo == "Piedra" and plantillaCofrePiedra then
		crearCofre3D(plantillaCofrePiedra, "Cofre_Piedra", pos, cfg, carpetaSesion, posicionesOcupadas, contadores, tipo)
	elseif tipo == "Dorado" and plantillaCofresDorado then
		crearCofre3D(plantillaCofresDorado, "Cofre_Dorado", pos, cfg, carpetaSesion, posicionesOcupadas, contadores, tipo)
	else
		crearCofreProcedural(tipo, pos, cfg, carpetaSesion, posicionesOcupadas, contadores)
	end
end

-- ============================================================
-- Función principal
-- ============================================================
function M.crear(sesionId, carpetaSesion, sesionRef)
	-- Cargar posiciones del pool generado por SesionMundoGen
	local POSICIONES_SPAWN = {}
	local posCofresFolder  = carpetaSesion:FindFirstChild("PosicionesCofres")
	if posCofresFolder then
		for _, v in ipairs(posCofresFolder:GetChildren()) do
			if v:IsA("Vector3Value") then
				table.insert(POSICIONES_SPAWN, v.Value)
			end
		end
	end
	if #POSICIONES_SPAWN == 0 then
		warn(string.format("[SesionCofres] Sesion %d: PosicionesCofres vacia.", sesionId))
		return
	end

	-- Estado local de esta sesión
	local contadores         = { Madera = 0, Piedra = 0, Dorado = 0 }
	local posicionesOcupadas = {}

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

	-- Loop de spawn por tipo
	for tipo, cfg in pairs(CofresConfig.TIPOS) do
		local tipoLocal = tipo
		task.spawn(function()
			while true do
				task.wait(cfg.intervalo)
				if sesionRef.cancelar then break end
				if contadores[tipoLocal] < cfg.maxPartida then
					local pos = posicionLibre()
					if pos then
						posicionesOcupadas[tostring(pos)] = true
						contadores[tipoLocal] += 1
						crearCofre(tipoLocal, pos, carpetaSesion, posicionesOcupadas, contadores)
					end
				end
			end
		end)
	end

	print(string.format("[SesionCofres] Sesion %d: loops de cofres iniciados (%d posiciones).",
		sesionId, #POSICIONES_SPAWN))
end

return M
