-- Varek.server.luau
-- Jefe del Bosque: oso gigante corrompido.
-- Sistema completamente autocontenido; no modifica otros scripts.
--
-- Flujo:
--   1. Al iniciar: crea la Arena de Varek y el modelo del jefe.
--   2. El jugador interactúa con el pilar de entrada → chequeo de armadura.
--   3. Con armadura equipada: teletransporte dentro, muros activos.
--   4. IA: patrulla / persigue / ataca / golpe de área cada 20 s.
--   5. Sin jugadores 10 s: Varek regenera 20 HP/s.
--   6. Al morir: animación de caída, muros se deshabilitan, cofre dorado aparece.
--   7. Cofre: entrega gemas, pieles, garras, Hoja Verde del Trébol.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local EquipoConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquipoConfig"))
local TrebolManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolManager"))
local GemasManager  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemasManager"))
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

local carpetaEventos        = obtenerOCrear(ReplicatedStorage, "Folder", "Eventos")
local evVarekVida           = obtenerOCrear(carpetaEventos, "RemoteEvent", "VarekVidaActualizada")
local evVarekEstado         = obtenerOCrear(carpetaEventos, "RemoteEvent", "VarekEstado")
local evVarekMensaje        = obtenerOCrear(carpetaEventos, "RemoteEvent", "VarekMensaje")

-- ============================================================
-- Constantes de la arena y del jefe
-- ============================================================
local ARENA_CENTRO     = Vector3.new(100, 0, 120)
local ENTRADA_POS      = Vector3.new(65, 2, 120)    -- fuera del muro oeste
local TELETRANSPORTE   = Vector3.new(80, 2, 120)    -- dentro de la arena
local VAREK_SPAWN_POS  = Vector3.new(112, 9, 120)   -- este de la arena

local VAREK_VIDA_MAX   = 300
local VAREK_DANO       = 20
local VAREK_VELOCIDAD  = 10
local RANGO_ATAQUE     = 12
local RANGO_DETECCION  = 55
local AREA_ATAQUE_CD   = 20    -- segundos entre golpes de área
local REGEN_DELAY      = 10    -- segundos sin target para empezar regen
local REGEN_POR_SEG    = 20    -- HP por segundo al regenerar

-- ============================================================
-- Estado global del jefe
-- ============================================================
local varekMuerto      = false
local varekModelo      = nil
local varekHumanoid    = nil
local varekHRP         = nil
local aiActivo         = false
local jugadoresEnArena = {}    -- [player] = true
local barreras         = {}    -- lista de Parts para las paredes invisibles

-- ============================================================
-- Helpers
-- ============================================================

-- Calcula daño de Varek considerando reducción de armadura del jugador
local function calcularDano(player)
	local tipoArmadura = player:GetAttribute("ArmaduraEquipada") or "SinArmadura"
	local infoArm      = EquipoConfig.ARMADURAS[tipoArmadura]
	local reduccion    = infoArm and infoArm.reduccion or 0
	return math.floor(VAREK_DANO * (1 - reduccion))
end

-- Devuelve el jugador vivo más cercano a Varek que esté en la arena
local function targetMasCercano()
	if not varekHRP then return nil end
	local mejor     = nil
	local mejorDist = math.huge
	for player in pairs(jugadoresEnArena) do
		local char = player.Character
		if char then
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and hrp then
				local d = (hrp.Position - varekHRP.Position).Magnitude
				if d < mejorDist then
					mejorDist = d
					mejor     = { player = player, hrp = hrp, hum = hum, dist = d }
				end
			end
		end
	end
	return mejor
end

-- ============================================================
-- Crear arena visual + barreras + pilar de entrada
-- ============================================================
local function crearArena()
	local carpeta = Instance.new("Folder")
	carpeta.Name   = "ArenaVarek"
	carpeta.Parent = workspace

	-- Suelo oscuro (apenas elevado para diferenciarse del baseplate)
	local suelo = Instance.new("Part")
	suelo.Name        = "Suelo"
	suelo.Size        = Vector3.new(62, 0.5, 62)
	suelo.CFrame      = CFrame.new(ARENA_CENTRO + Vector3.new(0, 0.25, 0))
	suelo.Anchored    = true
	suelo.Color       = Color3.fromRGB(30, 10, 10)
	suelo.Material    = Enum.Material.Ground
	suelo.CanCollide  = true
	suelo.Parent      = carpeta

	-- 4 muros invisibles (CanCollide=true, bloquean físicamente)
	local definicionMuros = {
		{ pos = Vector3.new(100, 10, 90),  tam = Vector3.new(64, 20, 2) },  -- norte
		{ pos = Vector3.new(100, 10, 150), tam = Vector3.new(64, 20, 2) },  -- sur
		{ pos = Vector3.new(130, 10, 120), tam = Vector3.new(2, 20, 62) },  -- este
		{ pos = Vector3.new(70,  10, 120), tam = Vector3.new(2, 20, 62) },  -- oeste
	}
	for _, def in ipairs(definicionMuros) do
		local muro = Instance.new("Part")
		muro.Size         = def.tam
		muro.CFrame       = CFrame.new(def.pos)
		muro.Anchored     = true
		muro.Transparency = 1
		muro.CanCollide   = true
		muro.CanTouch     = false
		muro.Parent       = carpeta
		table.insert(barreras, muro)
	end

	-- Pilar de entrada (visible, neon rojo)
	local pilar = Instance.new("Part")
	pilar.Name        = "PilarEntrada"
	pilar.Size        = Vector3.new(1, 4, 1)
	pilar.CFrame      = CFrame.new(ENTRADA_POS)
	pilar.Anchored    = true
	pilar.Color       = Color3.fromRGB(200, 20, 20)
	pilar.Material    = Enum.Material.Neon
	pilar.CanCollide  = false
	pilar.Parent      = carpeta

	-- Luz puntual en el pilar
	local luzPilar = Instance.new("PointLight")
	luzPilar.Color      = Color3.fromRGB(255, 60, 60)
	luzPilar.Brightness = 3
	luzPilar.Range      = 14
	luzPilar.Parent     = pilar

	-- Cartel sobre el pilar
	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 200, 0, 36)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = false
	bb.Parent      = pilar

	local lblBB = Instance.new("TextLabel")
	lblBB.Size                    = UDim2.new(1, 0, 1, 0)
	lblBB.BackgroundTransparency  = 1
	lblBB.Text                    = "ARENA DE VAREK"
	lblBB.Font                    = Enum.Font.GothamBold
	lblBB.TextScaled              = true
	lblBB.TextColor3              = Color3.fromRGB(255, 80, 80)
	lblBB.TextStrokeTransparency  = 0.3
	lblBB.Parent                  = lblBB.Parent or bb  -- workaround for scope
	lblBB.Parent                  = bb

	-- ProximityPrompt de entrada
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Entrar"
	prompt.ObjectText            = "Arena de Varek"
	prompt.KeyboardKeyCode       = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.Parent                = pilar

	-- Handler de entrada
	prompt.Triggered:Connect(function(player)
		if varekMuerto then
			evVarekMensaje:FireClient(player, "Varek ya fue derrotado en esta partida.")
			return
		end
		if jugadoresEnArena[player] then return end

		local armadura = player:GetAttribute("ArmaduraEquipada") or "SinArmadura"
		if armadura == "SinArmadura" then
			evVarekMensaje:FireClient(player, "Necesitas armadura para enfrentar a Varek.")
			return
		end

		-- Teletransportar al jugador dentro de la arena
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		task.wait(0.05)
		hrp.CFrame = CFrame.new(TELETRANSPORTE)

		jugadoresEnArena[player] = true
		evVarekEstado:FireClient(player, { visible = true })
		if varekHumanoid then
			evVarekVida:FireClient(player, { vida = varekHumanoid.Health, vidaMax = VAREK_VIDA_MAX })
		end

		-- Detectar cuando el jugador muere para limpiar la tabla
		local humJug = char:FindFirstChildWhichIsA("Humanoid")
		if humJug then
			humJug.Died:Connect(function()
				jugadoresEnArena[player] = nil
				evVarekEstado:FireClient(player, { visible = false })
			end)
		end

		-- Limpiar si el jugador sale o se desconecta
		local conn
		conn = Players.PlayerRemoving:Connect(function(p)
			if p == player then
				jugadoresEnArena[player] = nil
				conn:Disconnect()
			end
		end)
	end)

	return carpeta
end

-- ============================================================
-- Crear modelo visual de Varek
-- ============================================================
local function crearVarek()
	local modelo = Instance.new("Model")
	modelo.Name   = "Varek"
	modelo.Parent = workspace

	-- HumanoidRootPart (invisible, sirve de anclaje de movimiento)
	local hrp = Instance.new("Part")
	hrp.Name         = "HumanoidRootPart"
	hrp.Size         = Vector3.new(2, 2, 2)
	hrp.Transparency = 1
	hrp.CanCollide   = false
	hrp.CFrame       = CFrame.new(VAREK_SPAWN_POS)
	hrp.Parent       = modelo

	-- Torso (cuerpo principal, 5× el Oso normal)
	local torso = Instance.new("Part")
	torso.Name     = "Torso"
	torso.Size     = Vector3.new(12.5, 12.5, 7.5)
	torso.Color    = Color3.fromRGB(20, 5, 5)
	torso.Material = Enum.Material.Slate
	torso.CFrame   = hrp.CFrame * CFrame.new(0, 0, 0)
	torso.Parent   = modelo

	local weldTorso = Instance.new("WeldConstraint")
	weldTorso.Part0  = hrp
	weldTorso.Part1  = torso
	weldTorso.Parent = modelo

	-- Cabeza (encima del torso)
	local cabeza = Instance.new("Part")
	cabeza.Name     = "Head"
	cabeza.Size     = Vector3.new(9, 8, 7.5)
	cabeza.Color    = Color3.fromRGB(25, 8, 8)
	cabeza.Material = Enum.Material.Slate
	cabeza.CFrame   = hrp.CFrame * CFrame.new(0, 10.25, 0)   -- encima del torso
	cabeza.Parent   = modelo

	local weldCabeza = Instance.new("WeldConstraint")
	weldCabeza.Part0  = hrp
	weldCabeza.Part1  = cabeza
	weldCabeza.Parent = modelo

	-- Ojos (neon rojo, esferas pequeñas)
	local offsetOjosX = { -1.5, 1.5 }
	for _, ox in ipairs(offsetOjosX) do
		local ojo = Instance.new("Part")
		ojo.Shape       = Enum.PartType.Ball
		ojo.Size        = Vector3.new(1.2, 1.2, 1.2)
		ojo.Color       = Color3.fromRGB(255, 0, 0)
		ojo.Material    = Enum.Material.Neon
		ojo.CanCollide  = false
		ojo.CastShadow  = false
		ojo.CFrame      = hrp.CFrame * CFrame.new(ox, 11, -3.5)
		ojo.Parent      = modelo

		local wOjo = Instance.new("WeldConstraint")
		wOjo.Part0  = hrp
		wOjo.Part1  = ojo
		wOjo.Parent = modelo
	end

	-- Humanoid (controla movimiento y vida)
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth              = VAREK_VIDA_MAX
	humanoid.Health                 = VAREK_VIDA_MAX
	humanoid.WalkSpeed              = VAREK_VELOCIDAD
	humanoid.DisplayDistanceType    = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType      = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoRotate             = true
	humanoid.Parent                 = modelo

	-- Billboard de vida (patrón igual que Enemigos.server)
	local bb = Instance.new("BillboardGui")
	bb.Name        = "BarraVida"
	bb.Size        = UDim2.new(0, 160, 0, 36)
	bb.StudsOffset = Vector3.new(0, 10, 0)
	bb.AlwaysOnTop = false
	bb.Parent      = cabeza

	local lblNombre = Instance.new("TextLabel")
	lblNombre.Size               = UDim2.new(1, 0, 0.45, 0)
	lblNombre.BackgroundTransparency = 1
	lblNombre.Text               = "VAREK"
	lblNombre.Font               = Enum.Font.GothamBold
	lblNombre.TextScaled         = true
	lblNombre.TextColor3         = Color3.fromRGB(255, 60, 60)
	lblNombre.TextStrokeTransparency = 0.3
	lblNombre.Parent             = bb

	local barraFondo = Instance.new("Frame")
	barraFondo.Size               = UDim2.new(1, 0, 0.4, 0)
	barraFondo.Position           = UDim2.new(0, 0, 0.55, 0)
	barraFondo.BackgroundColor3   = Color3.fromRGB(40, 0, 0)
	barraFondo.BorderSizePixel    = 0
	barraFondo.Parent             = bb

	local barraFill = Instance.new("Frame")
	barraFill.Name              = "Fill"
	barraFill.Size              = UDim2.new(1, 0, 1, 0)
	barraFill.BackgroundColor3  = Color3.fromRGB(200, 30, 30)
	barraFill.BorderSizePixel   = 0
	barraFill.Parent            = barraFondo

	modelo.PrimaryPart = hrp

	return modelo, humanoid, hrp, barraFill
end

-- ============================================================
-- Golpe de área: empuja a todos los jugadores en la arena
-- ============================================================
local function golpeArea()
	if not varekHRP then return end

	for player in pairs(jugadoresEnArena) do
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if hrp and hum and hum.Health > 0 then
				-- Dirección de empuje: alejarse de Varek
				local dir = (hrp.Position - varekHRP.Position).Unit
				hrp.AssemblyLinearVelocity = dir * 55 + Vector3.new(0, 28, 0)
				hum:TakeDamage(10)   -- daño del golpe de área (sin reducción)
			end
		end
	end

	-- Notificar mensaje de área
	for player in pairs(jugadoresEnArena) do
		evVarekMensaje:FireClient(player, "¡GOLPE DE ÁREA!")
	end
end

-- ============================================================
-- Animación de caída (rota el modelo 90° sobre el eje Z)
-- ============================================================
local function animacionCaida()
	if not varekHRP then return end
	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local objetivo  = {
		CFrame = varekHRP.CFrame * CFrame.Angles(0, 0, math.rad(-90))
	}
	local tween = TweenService:Create(varekHRP, tweenInfo, objetivo)
	tween:Play()
	tween.Completed:Wait()
end

-- ============================================================
-- Crear cofre de recompensas
-- ============================================================
local function crearCofre()
	local cofrePart = Instance.new("Part")
	cofrePart.Name        = "CofreVarek"
	cofrePart.Size        = Vector3.new(3, 2, 2)
	cofrePart.CFrame      = CFrame.new(ARENA_CENTRO + Vector3.new(0, 1.25, 0))
	cofrePart.Anchored    = true
	cofrePart.Color       = Color3.fromRGB(255, 200, 30)
	cofrePart.Material    = Enum.Material.SmoothPlastic
	cofrePart.Parent      = workspace

	local luzCofre = Instance.new("PointLight")
	luzCofre.Color      = Color3.fromRGB(255, 220, 80)
	luzCofre.Brightness = 4
	luzCofre.Range      = 16
	luzCofre.Parent     = cofrePart

	local bbCofre = Instance.new("BillboardGui")
	bbCofre.Size        = UDim2.new(0, 170, 0, 28)
	bbCofre.StudsOffset = Vector3.new(0, 2, 0)
	bbCofre.Parent      = cofrePart

	local lblCofre = Instance.new("TextLabel")
	lblCofre.Size                   = UDim2.new(1, 0, 1, 0)
	lblCofre.BackgroundTransparency = 1
	lblCofre.Text                   = "Recompensas de Varek"
	lblCofre.Font                   = Enum.Font.GothamBold
	lblCofre.TextScaled             = true
	lblCofre.TextColor3             = Color3.fromRGB(255, 230, 80)
	lblCofre.TextStrokeTransparency = 0.3
	lblCofre.Parent                 = bbCofre

	local promptCofre = Instance.new("ProximityPrompt")
	promptCofre.ActionText            = "Recoger"
	promptCofre.ObjectText            = "Cofre de Varek"
	promptCofre.KeyboardKeyCode       = Enum.KeyCode.E
	promptCofre.MaxActivationDistance = 10
	promptCofre.Parent                = cofrePart

	local cofreRecogido = false
	promptCofre.Triggered:Connect(function(player)
		if cofreRecogido then return end
		cofreRecogido = true
		promptCofre.Enabled = false

		-- Entregar recompensas
		TrebolManager.darHoja(player, "Verde")
		GemasManager.agregar(player, math.random(50, 80))   -- gemas como moneda global
		InventarioMgr.agregar(player, "Piel",  math.random(3, 5))
		InventarioMgr.agregar(player, "Garra", math.random(2, 3))

		-- Mensaje a todos en la arena
		for p in pairs(jugadoresEnArena) do
			evVarekMensaje:FireClient(p, "¡Varek ha sido derrotado! Hoja Verde del Trébol obtenida.")
		end

		task.delay(1.5, function()
			if cofrePart and cofrePart.Parent then cofrePart:Destroy() end
		end)
	end)
end

-- ============================================================
-- Manejo de la muerte de Varek
-- ============================================================
local function manejarMuerte()
	aiActivo   = false
	varekMuerto = true

	-- Animación de caída
	animacionCaida()
	task.wait(2)

	-- Deshabilitar barreras (jugadores pueden salir)
	for _, pared in ipairs(barreras) do
		if pared and pared.Parent then
			pared.CanCollide = false
		end
	end

	-- Notificar a clientes: ocultar barra de vida
	for player in pairs(jugadoresEnArena) do
		evVarekEstado:FireClient(player, { visible = false })
	end

	-- Crear cofre con recompensas
	crearCofre()

	-- Destruir modelo tras 5 s
	task.delay(5, function()
		if varekModelo and varekModelo.Parent then
			varekModelo:Destroy()
		end
		varekModelo   = nil
		varekHumanoid = nil
		varekHRP      = nil
	end)
end

-- ============================================================
-- IA principal (loop en task.spawn)
-- ============================================================
local function iniciarAI(barraFill)
	aiActivo = true

	task.spawn(function()
		local cooldownAtaque  = 0
		local areaAtaqueTimer = 0
		local tiempoSinTarget = 0
		local ticker          = 0

		-- Puntos de patrulla dentro de la arena
		local puntosPatrulla = {
			Vector3.new(90,  2, 110),
			Vector3.new(110, 2, 130),
			Vector3.new(120, 2, 108),
			Vector3.new(95,  2, 135),
		}
		local idxPatrulla = 1

		while aiActivo and varekHumanoid and varekHumanoid.Health > 0 do
			task.wait(0.2)
			ticker += 1
			cooldownAtaque = math.max(0, cooldownAtaque - 0.2)
			areaAtaqueTimer += 0.2

			local info = targetMasCercano()

			if info then
				-- Hay jugador: perseguir y atacar
				tiempoSinTarget = 0
				varekHumanoid:MoveTo(info.hrp.Position)

				if info.dist <= RANGO_ATAQUE then
					if cooldownAtaque <= 0 then
						local dano = calcularDano(info.player)
						info.hum:TakeDamage(dano)
						cooldownAtaque = 1.5
					end
				end
			else
				-- Sin jugadores: patrullar
				tiempoSinTarget += 0.2
				local destino = puntosPatrulla[idxPatrulla]
				varekHumanoid:MoveTo(destino)
				if (varekHRP.Position - destino).Magnitude < 8 then
					idxPatrulla = (idxPatrulla % #puntosPatrulla) + 1
				end

				-- Regenerar vida si lleva 10 s sin target
				if tiempoSinTarget >= REGEN_DELAY then
					local nuevaVida = math.min(varekHumanoid.Health + REGEN_POR_SEG * 0.2, VAREK_VIDA_MAX)
					varekHumanoid.Health = nuevaVida
				end
			end

			-- Golpe de área cada 20 s
			if areaAtaqueTimer >= AREA_ATAQUE_CD then
				golpeArea()
				areaAtaqueTimer = 0
			end

			-- Actualizar barra de vida del billboard y evento (~cada 1 s)
			if ticker % 5 == 0 and varekHumanoid then
				local pct = varekHumanoid.Health / VAREK_VIDA_MAX
				if barraFill and barraFill.Parent then
					barraFill.Size = UDim2.new(pct, 0, 1, 0)
				end
				evVarekVida:FireAllClients({ vida = varekHumanoid.Health, vidaMax = VAREK_VIDA_MAX })
			end
		end

		-- Salir del loop = Varek murió (o aiActivo=false)
		if varekHumanoid and varekHumanoid.Health <= 0 then
			manejarMuerte()
		end
	end)
end

-- ============================================================
-- Inicialización al cargar el script
-- ============================================================
crearArena()

local modelo, humanoid, hrp, barraFill = crearVarek()
varekModelo   = modelo
varekHumanoid = humanoid
varekHRP      = hrp

iniciarAI(barraFill)

print("[Varek] Sistema del jefe Varek iniciado.")
