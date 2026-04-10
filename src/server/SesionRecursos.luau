-- SesionRecursos.luau  (ModuleScript en ServerScriptService/Server/)
-- Crea los recursos recolectables (Arbol, Roca, Hongo) para una sesión.
-- Función pública: M.crear(sesionId, carpetaSesion)
-- Las posiciones ya vienen con offsetX aplicado desde SesionMundoGen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Config            = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RecursosConfig"))
local InventarioManager = require(script.Parent:WaitForChild("InventarioManager"))

local plantillaArbol = ServerStorage:FindFirstChild("Arbol")
local plantillaRoca  = ServerStorage:FindFirstChild("Roca")
local plantillaHongo = ServerStorage:FindFirstChild("Hongo")

local M = {}

-- ============================================================
-- Helpers de modelo 3D (mismo patrón que Recoleccion.server.luau)
-- ============================================================

local function crearArbolModelo(dados, info, carpetaRecursos)
	local modelo = plantillaArbol:Clone()
	modelo.Name  = "Arbol"
	modelo:SetAttribute("TipoRecurso", "Arbol")
	modelo.Parent = carpetaRecursos

	local bbCF, bbSize = modelo:GetBoundingBox()
	local bottomY     = bbCF.Position.Y - bbSize.Y / 2
	local deltaY      = 0.4 - bottomY
	local pivotActual = modelo:GetPivot()
	modelo:PivotTo(
		CFrame.new(dados.pos.X, pivotActual.Position.Y + deltaY, dados.pos.Z)
		* pivotActual.Rotation
	)

	local partes = {}
	for _, desc in ipairs(modelo:GetDescendants()) do
		if desc:IsA("BasePart") then table.insert(partes, desc) end
	end

	local ancla = modelo.PrimaryPart or partes[1]
	if not ancla then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Recolectar"
	prompt.ObjectText            = info.promptTexto
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.HoldDuration          = 0.0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = ancla

	prompt.Triggered:Connect(function(player)
		prompt.Enabled = false
		for _, p in ipairs(partes) do p.Transparency = 0.85; p.CanCollide = false end
		local cantidad = math.random(info.cantidadMin, info.cantidadMax)
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			for _, p in ipairs(partes) do p.Transparency = 0; p.CanCollide = true end
			prompt.Enabled = true
			return
		end
		task.delay(info.respawnTiempo, function()
			for _, p in ipairs(partes) do p.Transparency = 0; p.CanCollide = true end
			prompt.Enabled = true
		end)
	end)
end

local function crearRocaModelo(dados, info, carpetaRecursos)
	local modelo = plantillaRoca:Clone()
	modelo.Name  = "Roca"
	modelo:SetAttribute("TipoRecurso", "Roca")

	for _, desc in ipairs(modelo:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") then desc.Disabled = true end
	end

	local rotY  = math.rad(math.random(0, 359))
	local partes = {}
	local ancla

	if modelo:IsA("BasePart") then
		local objetivo = info.tamano
		local s        = modelo.Size
		local factor   = math.min(objetivo.X / s.X, objetivo.Y / s.Y, objetivo.Z / s.Z)
		modelo.Size      = s * factor
		modelo.CFrame    = CFrame.new(dados.pos.X, 0.4 + modelo.Size.Y / 2, dados.pos.Z)
		                   * CFrame.Angles(0, rotY, 0)
		modelo.Anchored  = true
		modelo.CanCollide = true
		table.insert(partes, modelo)
		ancla = modelo
	else
		local _, bbSize = modelo:GetBoundingBox()
		local objetivo  = info.tamano
		local factor    = math.min(objetivo.X / bbSize.X, objetivo.Y / bbSize.Y, objetivo.Z / bbSize.Z)
		modelo:ScaleTo(factor)
		local bbCF2, bbSize2 = modelo:GetBoundingBox()
		local bottomY     = bbCF2.Position.Y - bbSize2.Y / 2
		local deltaY      = 0.4 - bottomY
		local pivotActual = modelo:GetPivot()
		modelo:PivotTo(
			CFrame.new(dados.pos.X, pivotActual.Position.Y + deltaY, dados.pos.Z)
			* CFrame.Angles(0, rotY, 0)
		)
		for _, desc in ipairs(modelo:GetDescendants()) do
			if desc:IsA("BasePart") then table.insert(partes, desc) end
		end
		ancla = modelo.PrimaryPart or partes[1]
	end

	modelo.Parent = carpetaRecursos
	if not ancla then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Recolectar"
	prompt.ObjectText            = info.promptTexto
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.HoldDuration          = 0.0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = ancla

	prompt.Triggered:Connect(function(player)
		prompt.Enabled = false
		for _, p in ipairs(partes) do p.Transparency = 0.85; p.CanCollide = false end
		local cantidad = math.random(info.cantidadMin, info.cantidadMax)
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			for _, p in ipairs(partes) do p.Transparency = 0; p.CanCollide = true end
			prompt.Enabled = true
			return
		end
		task.delay(info.respawnTiempo, function()
			for _, p in ipairs(partes) do p.Transparency = 0; p.CanCollide = true end
			prompt.Enabled = true
		end)
	end)
end

local function crearHongoModelo(dados, info, carpetaRecursos)
	local modelo = plantillaHongo:Clone()
	modelo.Name  = "Hongo"
	modelo:SetAttribute("TipoRecurso", "Hongo")

	for _, desc in ipairs(modelo:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") then desc.Disabled = true end
	end

	local rotY  = math.rad(math.random(0, 359))
	local partes = {}
	local ancla

	if modelo:IsA("BasePart") then
		local objetivo = info.tamano
		local s        = modelo.Size
		local factor   = math.min(objetivo.X / s.X, objetivo.Y / s.Y, objetivo.Z / s.Z)
		modelo.Size      = s * factor
		modelo.CFrame    = CFrame.new(dados.pos.X, 0.4 + modelo.Size.Y / 2, dados.pos.Z)
		                   * CFrame.Angles(0, rotY, 0)
		modelo.Anchored  = true
		modelo.CanCollide = true
		table.insert(partes, modelo)
		ancla = modelo
	else
		local _, bbSize = modelo:GetBoundingBox()
		local objetivo  = info.tamano
		local factor    = math.min(objetivo.X / bbSize.X, objetivo.Y / bbSize.Y, objetivo.Z / bbSize.Z)
		modelo:ScaleTo(factor)
		local bbCF2, bbSize2 = modelo:GetBoundingBox()
		local bottomY     = bbCF2.Position.Y - bbSize2.Y / 2
		local deltaY      = 0.4 - bottomY
		local pivotActual = modelo:GetPivot()
		modelo:PivotTo(
			CFrame.new(dados.pos.X, pivotActual.Position.Y + deltaY, dados.pos.Z)
			* CFrame.Angles(0, rotY, 0)
		)
		for _, desc in ipairs(modelo:GetDescendants()) do
			if desc:IsA("BasePart") then table.insert(partes, desc) end
		end
		ancla = modelo.PrimaryPart or partes[1]
	end

	modelo.Parent = carpetaRecursos
	if not ancla then return end

	local luz = Instance.new("PointLight")
	luz.Brightness = 2
	luz.Color      = Color3.fromRGB(180, 100, 210)
	luz.Range      = 14
	luz.Parent     = ancla

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Recolectar"
	prompt.ObjectText            = info.promptTexto
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.HoldDuration          = 0.0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = ancla

	prompt.Triggered:Connect(function(player)
		prompt.Enabled = false
		luz.Enabled    = false
		for _, p in ipairs(partes) do p.Transparency = 0.85; p.CanCollide = false end
		local cantidad = math.random(info.cantidadMin, info.cantidadMax)
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			for _, p in ipairs(partes) do p.Transparency = 0; p.CanCollide = true end
			luz.Enabled    = true
			prompt.Enabled = true
			return
		end
		task.delay(info.respawnTiempo, function()
			for _, p in ipairs(partes) do p.Transparency = 0; p.CanCollide = true end
			luz.Enabled    = true
			prompt.Enabled = true
		end)
	end)
end

-- Fallback procedural (si no hay plantilla 3D)
local function crearRecursoProcedural(dados, info, carpetaRecursos)
	local posicionFinal = dados.pos + Vector3.new(0, info.tamano.Y / 2, 0)
	local parte = Instance.new("Part")
	parte.Name         = dados.tipo
	parte.Size         = info.tamano
	parte.Position     = posicionFinal
	parte.Anchored     = true
	parte.CanCollide   = true
	parte.Color        = info.color
	parte.Material     = info.material
	parte.Shape        = info.forma
	parte.CastShadow   = true
	parte.Parent       = carpetaRecursos
	parte:SetAttribute("TipoRecurso", dados.tipo)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Recolectar"
	prompt.ObjectText            = info.promptTexto
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.HoldDuration          = 0.0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = parte

	prompt.Triggered:Connect(function(player)
		prompt.Enabled     = false
		parte.Transparency = 0.85
		parte.CanCollide   = false
		local cantidad = math.random(info.cantidadMin, info.cantidadMax)
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			parte.Transparency = 0
			parte.CanCollide   = true
			prompt.Enabled     = true
			return
		end
		task.delay(info.respawnTiempo, function()
			parte.Transparency = 0
			parte.CanCollide   = true
			prompt.Enabled     = true
		end)
	end)
end

-- ============================================================
-- Función principal
-- ============================================================
function M.crear(sesionId, carpetaSesion)
	-- Subcarpeta para los recursos de esta sesión
	local carpetaRecursos = Instance.new("Folder")
	carpetaRecursos.Name   = "RecursosBosque"
	carpetaRecursos.Parent = carpetaSesion

	local posRecursos = carpetaSesion:FindFirstChild("PosicionesRecursos")
	if not posRecursos then
		warn(string.format("[SesionRecursos] Sesion %d: no se encontro PosicionesRecursos.", sesionId))
		return
	end

	local lista = {}
	for _, subCarpeta in ipairs(posRecursos:GetChildren()) do
		local tipo = subCarpeta.Name
		for _, valor in ipairs(subCarpeta:GetChildren()) do
			if valor:IsA("Vector3Value") then
				table.insert(lista, { tipo = tipo, pos = valor.Value })
			end
		end
	end

	for _, dados in ipairs(lista) do
		local info = Config.TIPOS[dados.tipo]
		if not info then continue end

		if dados.tipo == "Arbol" and plantillaArbol then
			crearArbolModelo(dados, info, carpetaRecursos)
		elseif dados.tipo == "Roca" and plantillaRoca then
			crearRocaModelo(dados, info, carpetaRecursos)
		elseif dados.tipo == "Hongo" and plantillaHongo then
			crearHongoModelo(dados, info, carpetaRecursos)
		else
			crearRecursoProcedural(dados, info, carpetaRecursos)
		end
	end

	print(string.format("[SesionRecursos] Sesion %d: %d recursos creados.", sesionId, #lista))
end

return M
