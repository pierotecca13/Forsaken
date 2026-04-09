-- Recoleccion.server.luau
-- Sistema de recolección de recursos del Bosque.
-- Crea los objetos en el mapa, gestiona ProximityPrompt,
-- mantiene el inventario por jugador y dispara el respawn.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local ServerStorage     = game:GetService("ServerStorage")

local Config            = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RecursosConfig"))
local InventarioManager = require(script.Parent.InventarioManager)

-- Plantilla de árbol 3D (el usuario debe insertar "Arbol" en ServerStorage desde Toolbox)
local plantillaArbol = ServerStorage:FindFirstChild("Arbol")
-- Plantilla de roca 3D (el usuario debe insertar el modelo "Roca" de radico0303 en ServerStorage)
local plantillaRoca  = ServerStorage:FindFirstChild("Roca")
-- Plantilla de hongo 3D (modelo "Hongo" de D4RKBR1NGER en ServerStorage)
local plantillaHongo = ServerStorage:FindFirstChild("Hongo")

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

-- Leer posiciones generadas por WorldGen desde Workspace/PosicionesRecursos.
-- WorldGen corre antes que este script (orden garantizado por Roblox al ser
-- ambos Scripts en ServerScriptService). Esperamos hasta 10s por seguridad.
local function leerPosicionesGeneradas()
	local carpeta = Workspace:WaitForChild("PosicionesRecursos", 10)
	local lista   = {}

	if not carpeta then
		warn("[Recoleccion] No se encontró PosicionesRecursos — usando posiciones de emergencia.")
		-- Fallback mínimo para no romper el juego si WorldGen falla
		return {
			{ tipo = "Arbol", pos = Vector3.new( 20, 0,  20) },
			{ tipo = "Roca",  pos = Vector3.new(-22, 0, -18) },
			{ tipo = "Hongo", pos = Vector3.new( 12, 0, -38) },
		}
	end

	for _, subCarpeta in ipairs(carpeta:GetChildren()) do
		local tipo = subCarpeta.Name
		for _, valor in ipairs(subCarpeta:GetChildren()) do
			if valor:IsA("Vector3Value") then
				table.insert(lista, { tipo = tipo, pos = valor.Value })
			end
		end
	end

	return lista
end

local POSICIONES_EJEMPLO = leerPosicionesGeneradas()

-- Crea un árbol usando el modelo 3D de ServerStorage
local function crearArbolModelo(datos, info)
	local modelo = plantillaArbol:Clone()
	modelo.Name   = "Arbol"
	modelo:SetAttribute("TipoRecurso", "Arbol")
	modelo.Parent = carpetaRecursos

	-- Posicionar apoyado sobre el suelo (Y=0.4 = superficie del suelo generado)
	-- Usamos el pivô original para preservar la orientación vertical del modelo.
	-- CFrame.new(x,y,z) tiene rotación identidad y causa que el árbol quede horizontal
	-- si el pivô del modelo tenía alguna rotación.
	local bbCF, bbSize = modelo:GetBoundingBox()
	local bottomY    = bbCF.Position.Y - bbSize.Y / 2   -- base actual del modelo
	local deltaY     = 0.4 - bottomY                    -- cuánto subir para apoyar en el suelo
	local pivotActual = modelo:GetPivot()
	modelo:PivotTo(
		CFrame.new(datos.pos.X, pivotActual.Position.Y + deltaY, datos.pos.Z)
		* pivotActual.Rotation   -- conservar orientación original del modelo
	)

	-- Recopilar todas las BaseParts para efectos de transparencia/colisión
	local partes = {}
	for _, desc in ipairs(modelo:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(partes, desc)
		end
	end

	-- ProximityPrompt en PrimaryPart o primera BasePart disponible
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
		for _, p in ipairs(partes) do
			p.Transparency = 0.85
			p.CanCollide   = false
		end

		local cantidad = math.random(info.cantidadMin, info.cantidadMax)
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			for _, p in ipairs(partes) do
				p.Transparency = 0
				p.CanCollide   = true
			end
			prompt.Enabled = true
			return
		end

		print(string.format("[Recoleccion] %s recolectó %d %s", player.Name, cantidad, info.recurso))

		task.delay(info.respawnTiempo, function()
			for _, p in ipairs(partes) do
				p.Transparency = 0
				p.CanCollide   = true
			end
			prompt.Enabled = true
			print("[Recoleccion] Arbol reaparece en el mapa.")
		end)
	end)
end

-- Crea una roca usando el modelo 3D de radico0303 desde ServerStorage,
-- escalado al tamaño objetivo definido en RecursosConfig (4×2.5×4).
-- Soporta tanto MeshPart directo como Model con múltiples partes.
local function crearRocaModelo(datos, info)
	local modelo = plantillaRoca:Clone()
	modelo.Name = "Roca"
	modelo:SetAttribute("TipoRecurso", "Roca")

	-- Deshabilitar scripts decorativos que vienen con modelos de Toolbox
	for _, desc in ipairs(modelo:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") then
			desc.Disabled = true
		end
	end

	local rotY  = math.rad(math.random(0, 359))
	local partes = {}
	local ancla

	if modelo:IsA("BasePart") then
		-- Caso: el modelo es directamente una MeshPart/Part
		local objetivo = info.tamano
		local s        = modelo.Size
		local factor   = math.min(objetivo.X / s.X, objetivo.Y / s.Y, objetivo.Z / s.Z)
		modelo.Size     = s * factor
		modelo.CFrame   = CFrame.new(datos.pos.X, 0.4 + modelo.Size.Y / 2, datos.pos.Z)
		                  * CFrame.Angles(0, rotY, 0)
		modelo.Anchored  = true
		modelo.CanCollide = true
		table.insert(partes, modelo)
		ancla = modelo
	else
		-- Caso: el modelo es un Model con múltiples BaseParts
		local _, bbSize = modelo:GetBoundingBox()
		local objetivo  = info.tamano
		local factor    = math.min(objetivo.X / bbSize.X, objetivo.Y / bbSize.Y, objetivo.Z / bbSize.Z)
		modelo:ScaleTo(factor)

		local bbCF2, bbSize2 = modelo:GetBoundingBox()
		local bottomY     = bbCF2.Position.Y - bbSize2.Y / 2
		local deltaY      = 0.4 - bottomY
		local pivotActual = modelo:GetPivot()
		modelo:PivotTo(
			CFrame.new(datos.pos.X, pivotActual.Position.Y + deltaY, datos.pos.Z)
			* CFrame.Angles(0, rotY, 0)
		)

		for _, desc in ipairs(modelo:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(partes, desc)
			end
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
		for _, p in ipairs(partes) do
			p.Transparency = 0.85
			p.CanCollide   = false
		end

		local cantidad = math.random(info.cantidadMin, info.cantidadMax)
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			for _, p in ipairs(partes) do
				p.Transparency = 0
				p.CanCollide   = true
			end
			prompt.Enabled = true
			return
		end

		print(string.format("[Recoleccion] %s recolectó %d %s", player.Name, cantidad, info.recurso))

		task.delay(info.respawnTiempo, function()
			for _, p in ipairs(partes) do
				p.Transparency = 0
				p.CanCollide   = true
			end
			prompt.Enabled = true
			print("[Recoleccion] Roca reaparece en el mapa.")
		end)
	end)
end

-- Crea un hongo usando el modelo 3D de D4RKBR1NGER con brillo sutil de PointLight
local function crearHongoModelo(datos, info)
	local modelo = plantillaHongo:Clone()
	modelo.Name = "Hongo"
	modelo:SetAttribute("TipoRecurso", "Hongo")

	for _, desc in ipairs(modelo:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") then
			desc.Disabled = true
		end
	end

	local rotY  = math.rad(math.random(0, 359))
	local partes = {}
	local ancla

	if modelo:IsA("BasePart") then
		local objetivo = info.tamano
		local s        = modelo.Size
		local factor   = math.min(objetivo.X / s.X, objetivo.Y / s.Y, objetivo.Z / s.Z)
		modelo.Size      = s * factor
		modelo.CFrame    = CFrame.new(datos.pos.X, 0.4 + modelo.Size.Y / 2, datos.pos.Z)
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
			CFrame.new(datos.pos.X, pivotActual.Position.Y + deltaY, datos.pos.Z)
			* CFrame.Angles(0, rotY, 0)
		)

		for _, desc in ipairs(modelo:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(partes, desc)
			end
		end
		ancla = modelo.PrimaryPart or partes[1]
	end

	modelo.Parent = carpetaRecursos
	if not ancla then return end

	-- Brillo morado alrededor del hongo
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
		for _, p in ipairs(partes) do
			p.Transparency = 0.85
			p.CanCollide   = false
		end

		local cantidad = math.random(info.cantidadMin, info.cantidadMax)
		local ok = InventarioManager.agregar(player, info.recurso, cantidad)
		if not ok then
			for _, p in ipairs(partes) do
				p.Transparency = 0
				p.CanCollide   = true
			end
			luz.Enabled    = true
			prompt.Enabled = true
			return
		end

		print(string.format("[Recoleccion] %s recolectó %d %s", player.Name, cantidad, info.recurso))

		task.delay(info.respawnTiempo, function()
			for _, p in ipairs(partes) do
				p.Transparency = 0
				p.CanCollide   = true
			end
			luz.Enabled    = true
			prompt.Enabled = true
			print("[Recoleccion] Hongo reaparece en el mapa.")
		end)
	end)
end

-- Crea un Part recolectable y conecta la lógica de recolección
local function crearRecurso(datos)
	local info = Config.TIPOS[datos.tipo]
	if not info then
		warn("[Recoleccion] Tipo desconocido: " .. tostring(datos.tipo))
		return
	end

	-- Árbol: usar modelo 3D si la plantilla está disponible en ServerStorage
	if datos.tipo == "Arbol" and plantillaArbol then
		crearArbolModelo(datos, info)
		return
	end

	-- Roca: usar modelo 3D de radico0303 si la plantilla está disponible en ServerStorage
	if datos.tipo == "Roca" and plantillaRoca then
		crearRocaModelo(datos, info)
		return
	end

	-- Hongo: usar modelo 3D de D4RKBR1NGER si la plantilla está disponible en ServerStorage
	if datos.tipo == "Hongo" and plantillaHongo then
		crearHongoModelo(datos, info)
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

print(string.format("[Recoleccion] %d recursos creados en RecursosBosque (posiciones aleatorias de WorldGen).", #POSICIONES_EJEMPLO))
