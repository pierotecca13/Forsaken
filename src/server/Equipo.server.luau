-- Equipo.server.luau
-- Crafteo de armas y armaduras en la Mesa de Trabajo.
-- Las armas y armaduras son progresivas: solo se puede craftear
-- el siguiente nivel si se tiene el anterior.
-- Al craftear un arma mejor, la anterior se descarta automáticamente.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmasConfig   = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArmasConfig"))
local EquipoConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquipoConfig"))
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

local carpetaEventos      = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evCrafteoArma       = obtenerOCrear(carpetaEventos, "RemoteEvent", "SolicitarCrafteoArma")
local evResultArma        = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoCrafteoArma")
local evCrafteoArmadura   = obtenerOCrear(carpetaEventos, "RemoteEvent", "SolicitarCrafteoArmadura")
local evResultArmadura    = obtenerOCrear(carpetaEventos, "RemoteEvent", "ResultadoCrafteoArmadura")
local evEquipoActualizado = obtenerOCrear(carpetaEventos, "RemoteEvent", "EquipoActualizado")

-- ============================================================
-- Inicializar atributos al entrar
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	-- Armadura inicial (el arma la maneja Combate.server)
	player:SetAttribute("ArmaduraEquipada", EquipoConfig.ARMADURA_INICIAL)

	-- Al respawnear, notificar al cliente del equipo real
	-- (Combate.server re-entrega el arma; esperamos 0.3 s para que termine)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		evEquipoActualizado:FireClient(player, {
			arma     = player:GetAttribute("ArmaEquipada") or "Palo",
			armadura = player:GetAttribute("ArmaduraEquipada") or EquipoConfig.ARMADURA_INICIAL,
		})
	end)
end)

-- ============================================================
-- Crear Tool de arma (mismo patrón que Combate.server)
-- ============================================================
local function crearHerramienta(tipoArma)
	local info = ArmasConfig.ARMAS[tipoArma]
	if not info then return nil end

	local tool = Instance.new("Tool")
	tool.Name           = tipoArma
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

-- Reemplaza el arma en el personaje del jugador
local function equiparArma(player, tipoArma)
	local character = player.Character
	if not character then return end

	-- Destruir arma anterior
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end

	-- Equipar nueva arma (parenting al character = equipa de inmediato)
	local tool = crearHerramienta(tipoArma)
	if tool then
		tool.Parent = character
	end

	player:SetAttribute("ArmaEquipada", tipoArma)
end

-- ============================================================
-- HANDLER: Craftear arma
-- ============================================================
evCrafteoArma.OnServerEvent:Connect(function(player, tipoArma)
	local crafteo = EquipoConfig.CRAFTEO_ARMAS[tipoArma]
	if not crafteo then return end

	-- Verificar prerrequisito (debe tener el arma del nivel anterior)
	local orden       = EquipoConfig.ORDEN_ARMAS
	local idxObjetivo = table.find(orden, tipoArma)
	if not idxObjetivo then return end

	local armaActual = player:GetAttribute("ArmaEquipada") or "Palo"
	local idxActual  = table.find(orden, armaActual) or 1

	if idxActual < idxObjetivo - 1 then
		local tipoAnterior = orden[idxObjetivo - 1]
		local infoAnt      = ArmasConfig.ARMAS[tipoAnterior]
		evResultArma:FireClient(player, {
			exito   = false,
			mensaje = "Necesitas primero: " .. (infoAnt and infoAnt.nombre or tipoAnterior),
		})
		return
	end

	-- Verificar y descontar materiales
	local ok, faltante = InventarioMgr.descontar(player, crafteo.costo)
	if not ok then
		evResultArma:FireClient(player, {
			exito   = false,
			mensaje = "Materiales insuficientes. (Falta: " .. (faltante or "?") .. ")",
		})
		return
	end

	-- Equipar nueva arma (descarta la anterior automáticamente)
	equiparArma(player, tipoArma)

	-- Notificar cliente del nuevo equipo
	evEquipoActualizado:FireClient(player, {
		arma     = tipoArma,
		armadura = player:GetAttribute("ArmaduraEquipada") or EquipoConfig.ARMADURA_INICIAL,
	})

	local infoArma = ArmasConfig.ARMAS[tipoArma]
	evResultArma:FireClient(player, {
		exito   = true,
		tipo    = tipoArma,
		mensaje = (infoArma and infoArma.nombre or tipoArma) .. " equipada!",
	})

	print(string.format("[Equipo] %s crafteó y equipó %s.", player.Name, tipoArma))
end)

-- ============================================================
-- HANDLER: Craftear armadura
-- ============================================================
evCrafteoArmadura.OnServerEvent:Connect(function(player, tipoArmadura)
	local infoArm = EquipoConfig.ARMADURAS[tipoArmadura]
	if not infoArm or not infoArm.costo then return end

	-- Verificar prerrequisito (debe tener la armadura del nivel anterior)
	local orden       = EquipoConfig.ORDEN_ARMADURAS
	local idxObjetivo = table.find(orden, tipoArmadura)
	if not idxObjetivo then return end

	local armaduraActual = player:GetAttribute("ArmaduraEquipada") or EquipoConfig.ARMADURA_INICIAL
	local idxActual      = table.find(orden, armaduraActual) or 1

	if idxActual < idxObjetivo - 1 then
		local tipoAnterior = orden[idxObjetivo - 1]
		local infoAnt      = EquipoConfig.ARMADURAS[tipoAnterior]
		evResultArmadura:FireClient(player, {
			exito   = false,
			mensaje = "Necesitas primero: " .. (infoAnt and infoAnt.nombre or tipoAnterior),
		})
		return
	end

	-- Verificar y descontar materiales
	local ok, faltante = InventarioMgr.descontar(player, infoArm.costo)
	if not ok then
		evResultArmadura:FireClient(player, {
			exito   = false,
			mensaje = "Materiales insuficientes. (Falta: " .. (faltante or "?") .. ")",
		})
		return
	end

	-- Equipar nueva armadura (reemplaza la anterior)
	player:SetAttribute("ArmaduraEquipada", tipoArmadura)

	-- Notificar cliente del nuevo equipo
	evEquipoActualizado:FireClient(player, {
		arma     = player:GetAttribute("ArmaEquipada") or "Palo",
		armadura = tipoArmadura,
	})

	evResultArmadura:FireClient(player, {
		exito   = true,
		tipo    = tipoArmadura,
		mensaje = infoArm.nombre .. " equipada! (-" .. math.floor(infoArm.reduccion * 100) .. "% daño)",
	})

	print(string.format("[Equipo] %s equipó %s (reducción %d%%).",
		player.Name, tipoArmadura, math.floor(infoArm.reduccion * 100)))
end)

print("[Equipo] Sistema de crafteo de equipo iniciado.")
