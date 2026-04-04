-- init.client.luau
-- Script de inicialización del cliente.
-- Asegura que el ProximityPromptService esté activo
-- para que aparezca el indicador de tecla E en objetos, campamento y mesa.

local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.Enabled = true
