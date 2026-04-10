-- SesionEnemigos.luau  (ModuleScript en ServerScriptService/Server/)
-- Sistema de enemigos para una sesión específica.
-- Función pública: M.iniciar(sesionId, carpetaSesion, sesionRef)
-- sesionRef.cancelar = true cancela los respawns pendientes.

local Players            = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Lighting           = game:GetService("Lighting")

local Config        = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemigosConfig"))
local EquipoConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquipoConfig"))
local InventarioMgr = require(script.Parent:WaitForChild("InventarioManager"))

local M = {}

-- ============================================================
-- Helpers compartidos entre sesiones
-- ============================================================
local function fusionarInfo(tipoBase, corrompido)
	local base = {}
	for k, v in pairs(Config.ENEMIGOS[tipoBase]) do base[k] = v end
	if corrompido then
		for k, v in pairs(Config.CORROMPIDOS[tipoBase]) do base[k] = v end
	end
	return base
end

-- ============================================================
-- Función principal
-- ============================================================
function M.iniciar(sesionId, carpetaSesion, sesionRef)
	-- Estado local a esta sesión
	local registroEnemigos       = {}
	local lobosCorruptosActivos  = {}
	local esNoche                = false

	-- ── Filtro por sesión ────────────────────────────────────
	local function jugadorCercano(hrp, rango)
		local mejorDist = rango + 1
		local resultado = nil
		for _, jug in ipairs(Players:GetPlayers()) do
			-- Solo jugadores de esta sesión
			if jug:GetAttribute("SesionActual") ~= sesionId then continue end
			local ch   = jug.Character
			if not ch then continue end
			local jHrp = ch:FindFirstChild("HumanoidRootPart")
			local jHum = ch:FindFirstChildWhichIsA("Humanoid")
			if jHrp and jHum and jHum.Health > 0 then
				local d = (jHrp.Position - hrp.Position).Magnitude
				if d < mejorDist then
					mejorDist = d
					resultado = { hrp = jHrp, humanoid = jHum, dist = d }
				end
			end
		end
		return resultado
	end

	local function darDrops(posicion, drops)
		local masCorto, minDist = nil, 30
		for _, jug in ipairs(Players:GetPlayers()) do
			if jug:GetAttribute("SesionActual") ~= sesionId then continue end
			local ch = jug.Character
			if not ch then continue end
			local jHrp = ch:FindFirstChild("HumanoidRootPart")
			if jHrp then
				local d = (jHrp.Position - posicion).Magnitude
				if d < minDist then minDist = d; masCorto = jug end
			end
		end
		if not masCorto then return end
		for _, drop in ipairs(drops) do
			local cantidad = math.random(drop.min, drop.max)
			if cantidad > 0 then
				InventarioMgr.agregar(masCorto, drop.recurso, cantidad)
			end
		end
	end

	-- ── Hogueras de esta sesión ──────────────────────────────
	local function jugadorEnZonaLuz(jugHrp)
		local carpetaHogueras = carpetaSesion:FindFirstChild("HoguerasActivas")
		if not carpetaHogueras then return false end
		for _, parte in ipairs(carpetaHogueras:GetChildren()) do
			if not parte:IsA("BasePart") then continue end
			local radio = parte:GetAttribute("Radio") or 0
			if (parte.Position - jugHrp.Position).Magnitude <= radio then
				return true
			end
		end
		return false
	end

	-- ── Modelo visual ────────────────────────────────────────
	local function crearModelo(info, posicion, corrompido)
		local modelo = Instance.new("Model")
		modelo.Name  = info.nombre .. "_NPC"

		local hrp = Instance.new("Part")
		hrp.Name       = "HumanoidRootPart"
		hrp.Size       = info.tamCuerpo
		hrp.CFrame     = CFrame.new(posicion)
		hrp.Color      = info.colorCuerpo
		hrp.Material   = Enum.Material.SmoothPlastic
		hrp.Anchored   = false
		hrp.CanCollide = true
		hrp.Parent     = modelo

		local cabeza = Instance.new("Part")
		cabeza.Name       = "Head"
		cabeza.Size       = info.tamCabeza
		cabeza.CFrame     = CFrame.new(posicion + Vector3.new(0, info.tamCuerpo.Y * 0.6, 0))
		cabeza.Color      = info.colorCabeza
		cabeza.Material   = Enum.Material.SmoothPlastic
		cabeza.CanCollide = false
		cabeza.Parent     = modelo

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp; weld.Part1 = cabeza; weld.Parent = hrp

		if corrompido then
			for _, ladoX in ipairs({ -0.18, 0.18 }) do
				local ojo = Instance.new("Part")
				ojo.Shape      = Enum.PartType.Ball
				ojo.Size       = Vector3.new(0.18, 0.18, 0.18)
				ojo.CFrame     = CFrame.new(posicion + Vector3.new(
					ladoX * info.tamCabeza.X,
					info.tamCuerpo.Y * 0.6,
					-info.tamCabeza.Z * 0.52))
				ojo.Color      = Color3.fromRGB(255, 30, 30)
				ojo.Material   = Enum.Material.Neon
				ojo.CanCollide = false
				ojo.CastShadow = false
				ojo.Parent     = modelo
				local woWeld   = Instance.new("WeldConstraint")
				woWeld.Part0 = cabeza; woWeld.Part1 = ojo; woWeld.Parent = cabeza
			end
		end

		local humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth             = info.vida
		humanoid.Health                = info.vida
		humanoid.WalkSpeed             = info.velocidad
		humanoid.NameDisplayDistance   = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.Parent                = modelo

		local bb = Instance.new("BillboardGui")
		bb.Size        = UDim2.new(0, 120, 0, 36)
		bb.StudsOffset = Vector3.new(0, info.tamCuerpo.Y + 1.5, 0)
		bb.Parent      = hrp

		local lblN = Instance.new("TextLabel")
		lblN.Size                   = UDim2.new(1, 0, 0.5, 0)
		lblN.Text                   = info.nombre
		lblN.Font                   = Enum.Font.GothamBold
		lblN.TextScaled             = true
		lblN.TextColor3             = corrompido and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(220, 220, 220)
		lblN.BackgroundTransparency = 1
		lblN.Parent                 = bb

		local fondoBV = Instance.new("Frame")
		fondoBV.Size              = UDim2.new(1, 0, 0.38, 0)
		fondoBV.Position          = UDim2.new(0, 0, 0.62, 0)
		fondoBV.BackgroundColor3  = Color3.fromRGB(40, 10, 10)
		fondoBV.BorderSizePixel   = 0
		fondoBV.Parent            = bb

		local barraBV = Instance.new("Frame")
		barraBV.Name            = "BarraVida"
		barraBV.Size            = UDim2.new(1, 0, 1, 0)
		barraBV.BackgroundColor3 = corrompido and Color3.fromRGB(180, 0, 180) or Color3.fromRGB(200, 35, 35)
		barraBV.BorderSizePixel = 0
		barraBV.Parent          = fondoBV

		humanoid.HealthChanged:Connect(function(v)
			barraBV.Size = UDim2.new(math.max(v / info.vida, 0), 0, 1, 0)
		end)

		modelo.PrimaryPart = hrp
		modelo.Parent      = workspace
		return modelo, humanoid, hrp, cabeza, bb
	end

	-- ── Pathfinding ──────────────────────────────────────────
	local function moverHacia(humanoid, hrp, objetivo, path)
		local ok = pcall(function()
			path:ComputeAsync(hrp.Position, objetivo)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local wps = path:GetWaypoints()
			if wps[2] then humanoid:MoveTo(wps[2].Position) end
		else
			humanoid:MoveTo(objetivo)
		end
	end

	local function moverAlejandose(humanoid, hrp, jugadorHrp)
		local dir = (hrp.Position - jugadorHrp.Position)
		if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
		humanoid:MoveTo(hrp.Position + dir.Unit * 20)
	end

	-- ── Ciclo de vida de un enemigo ──────────────────────────
	local function gestionarEnemigo(tipoBase, posBase, corrompido, refCancelar)
		local info  = fusionarInfo(tipoBase, corrompido)
		local spawn = posBase + Vector3.new(0, info.tamCuerpo.Y, 0)
		local modelo, humanoid, hrp, cabeza, bb = crearModelo(info, spawn, corrompido)

		refCancelar.modelo = modelo

		local estado       = "patrullar"
		local ultimoAtaque = 0
		local timerPat     = 0
		local fueAtacado   = false

		local path = PathfindingService:CreatePath({
			AgentHeight  = info.tamCuerpo.Y + info.tamCabeza.Y + 0.5,
			AgentRadius  = math.max(info.tamCuerpo.X, info.tamCuerpo.Z) / 2 + 0.2,
			AgentCanJump = false,
		})

		local loboRef = nil
		if corrompido and tipoBase == "Lobo" then
			loboRef = { hrp = hrp, estado = "patrullar" }
			table.insert(lobosCorruptosActivos, loboRef)
		end

		humanoid.HealthChanged:Connect(function(v)
			if v < info.vida then fueAtacado = true end
		end)

		humanoid.Died:Connect(function()
			estado = "muerto"
			if bb then bb.Enabled = false end
			if loboRef then
				for i, r in ipairs(lobosCorruptosActivos) do
					if r == loboRef then table.remove(lobosCorruptosActivos, i); break end
				end
			end
			darDrops(hrp.Position, info.drops)
			hrp.Anchored = true
			if cabeza and cabeza.Parent then cabeza.Anchored = true end
			hrp.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
			task.spawn(function()
				task.wait(1.5)
				for i = 1, 8 do
					task.wait(0.06)
					local t = i / 8
					if hrp and hrp.Parent     then hrp.Transparency    = t end
					if cabeza and cabeza.Parent then cabeza.Transparency = t end
				end
			end)
			task.delay(info.tiempoRespawn, function()
				if refCancelar.cancelar or sesionRef.cancelar then return end
				if modelo and modelo.Parent then modelo:Destroy() end
				local nuevoRef = { cancelar = false }
				registroEnemigos[nuevoRef] = true
				registroEnemigos[refCancelar] = nil
				gestionarEnemigo(tipoBase, posBase, corrompido, nuevoRef)
			end)
		end)

		task.spawn(function()
			while true do
				task.wait(0.15)
				if refCancelar.cancelar or sesionRef.cancelar then break end
				if not modelo.Parent or humanoid.Health <= 0 then break end

				local jug = jugadorCercano(hrp, math.max(info.rangoDeteccion, info.rangoAtaque) + 5)
				if loboRef then loboRef.estado = estado end

				local comp = info.comportamiento

				if comp == "pasivo" then
					if jug and jug.dist <= info.rangoAtaque and fueAtacado then
						estado = "atacar"
					elseif jug and jug.dist <= info.rangoDeteccion then
						estado = fueAtacado and "perseguir" or "huir"
					else
						estado = "patrullar"
					end
				elseif comp == "agresivo" then
					if jug and jug.dist <= info.rangoAtaque then
						estado = "atacar"
					elseif jug and jug.dist <= info.rangoDeteccion then
						estado = "perseguir"
					else
						estado = "patrullar"
					end
				elseif comp == "corrupto_lobo" then
					local enLuz = jug and jugadorEnZonaLuz(jug.hrp)
					if jug and jug.dist <= info.rangoAtaque and not enLuz then
						estado = "atacar"
					elseif jug and jug.dist <= info.rangoDeteccion and not enLuz then
						estado = "perseguir"
					else
						estado = "patrullar"
					end
				elseif comp == "cauto" or comp == "oso_sombra" then
					local enLuz = (comp == "oso_sombra") and jug and jugadorEnZonaLuz(jug.hrp)
					if jug and jug.dist <= info.rangoAtaque and not enLuz then
						estado = "atacar"
					elseif jug and jug.dist <= info.rangoDeteccion and not enLuz then
						estado = "perseguir"
					else
						estado = "patrullar"
					end
				end

				-- Corrompidos huyen de zonas iluminadas
				if corrompido and jugadorEnZonaLuz(hrp) then
					estado = "patrullar"
					local carpetaHogueras = carpetaSesion:FindFirstChild("HoguerasActivas")
					if carpetaHogueras then
						for _, marcador in ipairs(carpetaHogueras:GetChildren()) do
							if not marcador:IsA("BasePart") then continue end
							local radio = marcador:GetAttribute("Radio") or 0
							if (marcador.Position - hrp.Position).Magnitude <= radio then
								local dir = (hrp.Position - marcador.Position)
								if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
								humanoid:MoveTo(hrp.Position + dir.Unit * (radio + 5))
								timerPat = math.random(3, 5)
								break
							end
						end
					end
				end

				if comp == "corrupto_lobo" and estado == "atacar" and jug then
					for _, lr in ipairs(lobosCorruptosActivos) do
						if lr ~= loboRef and lr.hrp and lr.hrp.Parent then
							if (lr.hrp.Position - hrp.Position).Magnitude <= 35 then
								lr.estado = "perseguir"
							end
						end
					end
				end

				humanoid.WalkSpeed = (estado == "huir")
					and (info.velocidadHuida or info.velocidad)
					or info.velocidad

				if estado == "patrullar" then
					timerPat -= 0.15
					if timerPat <= 0 then
						local a = math.random() * 2 * math.pi
						local r = math.random(2, info.radioPatrulla)
						humanoid:MoveTo(posBase + Vector3.new(math.cos(a)*r, 0, math.sin(a)*r))
						timerPat = math.random(3, 7)
					end
				elseif estado == "huir" and jug then
					moverAlejandose(humanoid, hrp, jug.hrp)
				elseif estado == "perseguir" and jug then
					humanoid:MoveTo(jug.hrp.Position)
				elseif estado == "atacar" and jug then
					humanoid:MoveTo(hrp.Position)
					local ahora = tick()
					if ahora - ultimoAtaque >= info.cooldown then
						ultimoAtaque = ahora
						local danoFinal  = info.dano
						local playerInst = Players:GetPlayerFromCharacter(jug.humanoid.Parent)
						if playerInst then
							local armadura  = playerInst:GetAttribute("ArmaduraEquipada")
							local infoArm   = EquipoConfig.ARMADURAS[armadura]
							local reduccion = infoArm and infoArm.reduccion or 0
							danoFinal = math.max(1, math.ceil(danoFinal * (1 - reduccion)))
						end
						jug.humanoid:TakeDamage(danoFinal)
						if info.comportamiento == "oso_sombra" then
							local dir = (jug.hrp.Position - hrp.Position).Unit
							local bv  = Instance.new("BodyVelocity")
							bv.Velocity = (dir + Vector3.new(0, 0.4, 0)) * 45
							bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
							bv.Parent   = jug.hrp
							game:GetService("Debris"):AddItem(bv, 0.25)
						end
					end
				end
			end
		end)
	end

	-- ── Limpiar todos los enemigos de esta sesión ────────────
	local function limpiarEnemigos()
		for ref in pairs(registroEnemigos) do
			ref.cancelar = true
			if ref.modelo and ref.modelo.Parent then
				ref.modelo:Destroy()
			end
		end
		registroEnemigos      = {}
		lobosCorruptosActivos = {}
	end

	-- ── Lanzar enemigos de una carpeta de posiciones ─────────
	local function iniciarEnemigos(corrompido)
		local nombreCarpeta   = corrompido and "PosicionesEnemigosCorrompidos" or "PosicionesEnemigos"
		local carpetaEnemigos = carpetaSesion:FindFirstChild(nombreCarpeta)
		local retardo         = 0

		for tipoBase in pairs(Config.ENEMIGOS) do
			local posiciones = {}
			if carpetaEnemigos then
				local sub = carpetaEnemigos:FindFirstChild(tipoBase)
				if sub then
					for _, v in ipairs(sub:GetChildren()) do
						if v:IsA("Vector3Value") then table.insert(posiciones, v.Value) end
					end
				end
			end
			for _, pos in ipairs(posiciones) do
				local ref = { cancelar = false }
				registroEnemigos[ref] = true
				task.delay(retardo, function()
					if not ref.cancelar and not sesionRef.cancelar then
						gestionarEnemigo(tipoBase, pos, corrompido, ref)
					end
				end)
				retardo += 0.3
			end
		end
	end

	-- ── Detección de día/noche (Lighting global) ─────────────
	local function esFaseNoche()
		local h = Lighting.ClockTime
		return h >= 19 or h < 7
	end

	esNoche = esFaseNoche()
	iniciarEnemigos(esNoche)

	local faseActual = esNoche
	task.spawn(function()
		while true do
			task.wait(1)
			if sesionRef.cancelar then break end
			local nuevaFase = esFaseNoche()
			if nuevaFase ~= faseActual then
				faseActual = nuevaFase
				esNoche    = nuevaFase
				limpiarEnemigos()
				task.wait(1)
				if not sesionRef.cancelar then
					iniciarEnemigos(esNoche)
				end
			end
		end
	end)

	print(string.format("[SesionEnemigos] Sesion %d: enemigos iniciados (%s).",
		sesionId, esNoche and "NOCHE" or "DIA"))
end

return M
