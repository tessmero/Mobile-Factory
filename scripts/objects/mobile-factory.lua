-- Create the Mobile Factory Object --
MF = {
	ent = nil,
	playerIndex = nil,
	player = "",
	updateTick = 1,
	lastUpdate = 0,
	lastSurface = nil,
	lastPosX = 0,
	lastPosY = 0,
	fS = nil,
	ccS = nil,
	II = nil,
	dataNetwork = nil,
	netwokController = nil,
	entitiesAround = nil,
	internalEnergyObj = nil,
	internalQuatronObj = nil,
	jumpDriveObj = nil,
	tpEnabled = true,
	onTP = false,
	tpCurrentTick = 0,
	tpLocation = nil,
	locked = true,
	laserRadiusMultiplier = 0,
	laserDrainMultiplier = 0,
	laserNumberMultiplier = 0,
	energyLaserActivated = false,
	fluidLaserActivated = false,
	itemLaserActivated = false,
	selectedInventory = nil,
	sendQuatronActivated = false,
	selectedPowerLaserMode = "input", -- input, output
	selectedFluidLaserMode = "input", -- input, output
	syncAreaID = 0,
	syncAreaInsideID = 0,
	syncAreaEnabled = true,
	syncAreaScanned = false,
	clonedResourcesTable = nil, -- {original, cloned}
	varTable = nil
}

-- Constructor --
function MF:new(args)
	local t = {}
	local player = nil
	if args then
		if args.refreshObj then t = args.refreshObj end
		if args.player then player = args.player end
	end
	local mt = {}
	setmetatable(t, mt)
	mt.__index = MF
	t.entitiesAround = t.entitiesAround or {}
	t.clonedResourcesTable = t.clonedResourcesTable or {}
	t.varTable = t.varTable or {}
	t.varTable.tech = t.varTable.tech or {}
	t.varTable.allowedPlayers = t.varTable.allowedPlayers or {}
	t.varTable.jets = t.varTable.jets or {}
	t.varTable.jets["cjTableSize"] = t.varTable.jets["cjTableSize"] or _MFConstructionJetDefaultTableSize
	--t.varTable.jets["cjUseGhostTable"] = t.varTable.jets["cjUseGhostTable"] or true

	if player then
		global.MFTable[player.name] = t
		t.playerIndex = player.index
		t.player = player.name
	end

	t.II = t.II or INV:new("Internal Inventory")
	t.dataNetwork = t.dataNetwork or DN:new(t)
	t.II.MF = t
	t.II.dataNetwork = t.dataNetwork
	t.dataNetwork.MF = t
	t.dataNetwork.invObj = t.II

	t.internalEnergyObj = t.internalEnergyObj or IEC:new(t)
	t.internalQuatronObj = t.internalQuatronObj or IQC:new(t)
	t.jumpDriveObj = t.jumpDriveObj or JD:new(t)

	t.MF = t
	UpSys.addObj(t)
	return t
end

function MF:refresh(obj)
  MF:new({refreshObj = obj})
end

-- Constructor for a placed Mobile Factory --
function MF:construct(object)
	if object == nil then return end
	self.ent = object
	if self.fS == nil or self.fS.valid == false then self.fS = nil createMFSurface(self) end
	if self.ccS == nil or self.ccS.valid == false then self.ccS = nil createControlRoom(self) end
	global.entsTable[object.unit_number] = self
	self.lastSurface = object.surface
	self.lastPosX = object.position.x
	self.lastPosY = object.position.y
end

-- Reconstructor --
function MF:rebuild(object)
	if object == nil then return end
	local mt = {}
	mt.__index = MF
	setmetatable(object, mt)
	IEC:rebuild(object.internalEnergyObj)
	IQC:rebuild(object.internalQuatronObj)
	JD:rebuild(object.jumpDriveObj)
	DN:rebuild(object.dataNetwork)
	NC:rebuild(object.networkController)
	INV:rebuild(object.II)
end

-- Destructor --
function MF:remove()
	self.ent = nil
	-- self.internalEnergyObj:removeEnergy(self.internalEnergyObj:energy())
	-- self.internalQuatronObj:removeQuatron(self.internalQuatronObj:quatron())
	-- self.jumpDriveObj.charge = 0
	self:removeSyncArea()
end

-- Is valid --
function MF:valid()
	return true
end

-- Tooltip Infos --
function MF:getTooltipInfos(GUIObj, gui, justCreated)

	if justCreated == true then

		-- Create the Inventory Title --
		local inventoryTitle = GUIObj:addTitledFrame("", gui, "vertical", {"gui-description.Inventory"}, _mfOrange)

		-- Create the Inventory Button --
		GUIObj:addSimpleButton("MFOpenI," ..GUIObj.MFPlayer.name, inventoryTitle, {"gui-description.OpenInventory"})

		-- Create the Lasers Title --
		local LasersFrame = GUIObj:addTitledFrame("", gui, "vertical", {"gui-description.Lasers"}, _mfOrange)

		-- Create the Power laser Settings --
		if technologyUnlocked("EnergyDrain1", getForce(self.player)) then
			LasersFrame.visible = true
			GUIObj:addLabel("", LasersFrame, {"", {"gui-description.PowerLaser"}}, _mfOrange)
			local state = "left"
			if self.selectedPowerLaserMode == "output" then state = "right" end
			GUIObj:addSwitch("MFPL" .. self.ent.unit_number, LasersFrame, {"gui-description.Drain"}, {"gui-description.Send"}, {"gui-description.DrainTT"}, {"gui-description.SendTT"}, state)
		end

		-- Create the Fluid Lasers Settings --
		if technologyUnlocked("FluidDrain1", getForce(self.player)) then
			LasersFrame.visible = true
			GUIObj:addLabel("", LasersFrame, {"", {"gui-description.FluidLaser"}}, _mfOrange)
			local state = "left"
			if self.selectedFluidLaserMode == "output" then state = "right" end
			GUIObj:addSwitch("MFFMode" .. self.ent.unit_number, LasersFrame, {"gui-description.Input"}, {"gui-description.Output"}, {"gui-description.InputTT"}, {"gui-description.OutputTT"}, state)
			GUIObj:addLabel("", LasersFrame, {"", {"gui-description.MSTarget"}}, _mfOrange)
			-- Create the Target List --
			local invs = {{"", {"gui-description.None"}}}
			local selectedIndex = 1
			local i = 1
			for k, deepTank in pairs(self.dataNetwork.DTKTable) do
				if deepTank ~= nil and deepTank.ent ~= nil then
					i = i + 1
					local itemText = {"", " (", {"gui-description.Empty"}, " - ", deepTank.player, ")"}
					if deepTank.filter ~= nil and game.fluid_prototypes[deepTank.filter] ~= nil then
						itemText = {"", " (", game.fluid_prototypes[deepTank.filter].localised_name, " - ", deepTank.player, ")"}
					elseif deepTank.inventoryFluid ~= nil and game.fluid_prototypes[deepTank.inventoryFluid] ~= nil then
						itemText = {"", " (", game.fluid_prototypes[deepTank.inventoryFluid].localised_name, " - ", deepTank.player, ")"}
					end
					invs[k+1] = {"", {"gui-description.DT"}, " ", tostring(deepTank.ID), itemText}
					if self.selectedInv == deepTank then
						selectedIndex = i
					end
				end
			end
			if selectedIndex ~= nil and selectedIndex > table_size(invs) then selectedIndex = nil end
			GUIObj:addDropDown("MFFTarget" .. self.ent.unit_number, LasersFrame, invs, selectedIndex)
		end

	end

end

-- Change the Mode --
function MF:fluidLaserMode(mode)
	if mode == "left" then
		self.selectedFluidLaserMode = "input"
	elseif mode == "right" then
		self.selectedFluidLaserMode = "output"
	end
end

-- Change the Fluid Laser Targeted Inventory --
function MF:fluidLaserTarget(ID)
	-- Check the ID --
	if ID == nil then
		self.selectedInv = nil
		return
	end
	-- Select the Inventory --
	self.selectedInv = nil
	for k, deepTank in pairs(self.dataNetwork.DTKTable) do
		if valid(deepTank) then
			if ID == deepTank.ID then
				self.selectedInv = deepTank
			end
		end
	end
end

-- Update the Mobile Factory --
function MF:update(event)
	if self.fS ~= nil and self.fS.valid == false then
		self.fS = nil
	end
	if self.ccS ~= nil and self.ccS.valid == false then
		self.ccS = nil
	end

	-- Set the lastUpdate variable --
	self.lastUpdate = game.tick
	-- Get the current tick --
	local tick = event.tick
	-- Update the Internal Inventory --
	if tick%_eventTick80 == 0 then self.II:rescan() end
	--Update all lasers --
	if tick%_eventTick60 == 0 then self:updateLasers() end
	-- Update the Fuel --
	if tick%_eventTick27 == 0 then self:updateFuel() end
	-- Scan Entities Around --
	if tick%_eventTick90 == 0 then self:scanEnt() end
	-- Update the Shield --
	self:updateShield(event)
	-- Update Pollution --
	if event.tick%_eventTick1200 == 0 then self:updatePollution() end
	-- Update Teleportation Box --
	if event.tick%_eventTick5 == 0 then self:factoryTeleportBox() end
	-- Check if the Mobile Factory has to TP --
	if self.onTP and game.tick - self.tpCurrentTick > 30 then
		self:TPMobileFactoryPart2()
	end
	-- Read Modules inside the Equipment Grid --
	if event.tick%_eventTick125 == 0 then self:scanModules() end
	-- Send Quatron Charge --
	if self.sendQuatronActivated == true then
		self:SendQuatronToOC(event)
		self:SendQuatronToFE(event)
	end
	-- Update the Sync Area --
	if tick%_eventTick30 == 0 then self:updateSyncArea() end
end

-- Return the Lasers radius --
function MF:getLaserRadius()
	return _mfBaseLaserRadius + (self.laserRadiusMultiplier * 2)
end

-- Return the number of Lasers --
function MF:getLaserNumber()
	return _mfBaseLaserNumber + self.laserNumberMultiplier
end

function MF:getLaserPower()
	return self.laserDrainMultiplier + 1
end

-- Return the Energy Lasers Drain --
function MF:getLaserEnergyDrain()
	return _mfEnergyDrain * (self.laserDrainMultiplier + 1)
end

-- Return the Fluid Lasers Drain --
function MF:getLaserFluidDrain()
	return _mfFluidDrain * (self.laserDrainMultiplier + 1)
end

-- Return the Logistic Lasers Drain --
function MF:getLaserItemDrain()
	return _mfItemsDrain * (self.laserDrainMultiplier + 1)
end

-- Return the Shield --
function MF:shield()
	if self.ent == nil or self.ent.valid == false or self.ent.grid == nil then return 0 end
	return self.ent.grid.shield
end

-- Return the max Shield --
function MF:maxShield()
	if self.ent == nil or self.ent.valid == false or self.ent.grid == nil then return 0 end
	return self.ent.grid.max_shield
end

-- Change the Power Laser to Drain or Send mode --
function MF:changePowerLaserMode(mode)
	if mode == "left" then
		self.selectedPowerLaserMode = "input"
	elseif mode == "right" then
		self.selectedPowerLaserMode = "output"
	end
end

-- Scan all Entities around the Mobile Factory --
function MF:scanEnt()
	-- Check the Mobile Factory --
	if self.ent == nil or self.ent.valid == false then return end
	-- Look for Entities --
	self.entitiesAround = self.ent.surface.find_entities_filtered{position=self.ent.position, radius=self:getLaserRadius()}
	-- Filter the Entities --
	for k, entity in pairs(self.entitiesAround) do
		local keep = false
		-- Keep Electric Entity --
		if entity.energy ~= nil and entity.electric_buffer_size ~= nil then
			keep = true
		end
		-- Keep Tank --
		if entity.type == "storage-tank" then
			keep = true
		end
		-- Keep Container --
		if entity.type == "container" or entity.type == "logistic-container" then
			keep = true
		end
		-- Removed not keeped Entity --
		if keep == false or valid(entity.last_user) == false or self.player ~= entity.last_user.name then
			self.entitiesAround[k] = nil
		end
	end
end

-- Update lasers of the Mobile Factory --
function MF:updateLasers()
	-- Check the Mobile Factory --
	if self.ent == nil or self.ent.valid == false then return end
	-- Create all Lasers --
	i = 1
	for k, entity in pairs(self.entitiesAround or {}) do
		if entity ~= nil and entity.valid == true then
			local laserUsed = false
			if self:updateEnergyLaser(entity) == true then laserUsed = true end
			if self:updateFluidLaser(entity) == true then laserUsed = true end
			if self:updateLogisticLaser(entity) == true then laserUsed = true end
			if laserUsed == true then i = i + 1 end
			if i > self:getLaserNumber() then return end
		end
	end
end

-------------------------------------------- Energy Laser --------------------------------------------
function MF:updateEnergyLaser(entity)
	-- Check if a laser should be created --
	if technologyUnlocked("EnergyDrain1", getForce(self.player)) == false or self.energyLaserActivated == false then return false end
	-- Create the Laser --
	local mobileFactory = false
	if string.match(entity.name, "MobileFactory") then mobileFactory = true end
	-- Exclude Mobile Factory, Character, Power Drain Pole and Entities with 0 energy --
	if mobileFactory == false and entity.type ~= "character" and entity.name ~= "OreCleaner" and entity.name ~= "FluidExtractor" and entity.energy ~= nil and entity.electric_buffer_size ~= nil then
		----------------------- Drain Power -------------------------
		if self.selectedPowerLaserMode == "input" and entity.energy > 0 then
			-- Missing Internal Energy or Structure Energy --
			local energyDrain = math.min(self.internalEnergyObj:maxEnergy() - self.internalEnergyObj:energy(), entity.energy)
			-- EnergyDrain or LaserDrain Caparity --
			local drainedEnergy = math.min(self:getLaserEnergyDrain(), energyDrain)
			-- Test if some Energy was drained --
			if drainedEnergy > 0 then
				-- Add the Energy to the Mobile Factory Batteries --
				self.internalEnergyObj:addEnergy(drainedEnergy)
				-- Remove the Energy from the Structure --
				entity.energy = entity.energy - drainedEnergy
				-- Create the Beam --
				self.ent.surface.create_entity{name="BlueBeam", duration=60, position=self.ent.position, target_position=entity.position, source_position={self.ent.position.x,self.ent.position.y}}
				-- One less Beam to the Beam capacity --
				return true
			end
		elseif self.selectedPowerLaserMode == "output" and entity.energy < entity.electric_buffer_size then
			-- Structure missing Energy or Laser Power --
			local energySend = math.min(entity.electric_buffer_size - entity.energy , self:getLaserEnergyDrain())
			-- Energy Send or Mobile Factory Energy --
			energySend = math.min(self.internalEnergyObj:energy(), energySend)
			-- Check if Energy can be send --
			if energySend > 0 then
				-- Add the Energy to the Entity --
				entity.energy = entity.energy + energySend
				-- Remove the Energy from the Mobile Factory --
				self.internalEnergyObj:removeEnergy(energySend)
				-- Create the Beam --
				self.ent.surface.create_entity{name="BlueBeam", duration=60, position=self.ent.position, target_position=entity.position, source_position={self.ent.position.x,self.ent.position.y}}
				-- One less Beam to the Beam capacity --
				return true
			end
		end
	end
end

-------------------------------------------- Fluid Laser --------------------------------------------
function MF:updateFluidLaser(entity)
	-- Check if a laser should be created --
	if technologyUnlocked("FluidDrain1", getForce(self.player)) == false or self.fluidLaserActivated == false then return false end
	if entity.type ~= "storage-tank" or self.selectedInv == nil then return false end

	-- Get both Tanks and their characteristics --
	local localTank = entity
	local distantTank = self.selectedInv
	local localFluid = nil
	
	-- Get the Fluid inside the local Tank --
	for i=1,#localTank.fluidbox do
		if localTank.fluidbox[i] then
			localFluid = localTank.fluidbox[i]
		end
	end
	
	-- Input mode --
	if self.selectedFluidLaserMode == "input" then
		if localFluid == nil then return end
		-- Check the local and distant Tank --
		if distantTank:canAccept(localFluid) == false then return end
		-- Send the Fluid --
		local amountAdded = distantTank:addFluid(localFluid)
		-- Remove the local Fluid --
		localTank.remove_fluid({name=localFluid.name, amount=amountAdded, minimum_temperature = -300, maximum_temperature = 1e7})
		if amountAdded > 0 then
			-- Create the Laser --
			self.ent.surface.create_entity{name="PurpleBeam", duration=60, position=self.ent.position, target=localTank.position, source=self.ent.position}
			-- Drain Energy --
			self.internalEnergyObj:removeEnergy(_mfFluidConsomption*amountAdded)
			-- One less Beam to the Beam capacity --
			return true
		end
	elseif self.selectedFluidLaserMode == "output" then
		-- Check the local and distant Tank --
		if localFluid and localFluid.name ~= distantTank.inventoryFluid then return end
		if distantTank.inventoryFluid == nil or distantTank.inventoryCount == 0 then return end
		-- Get the Fluid --
		local amountAdded = localTank.insert_fluid({name=distantTank.inventoryFluid, amount=distantTank.inventoryCount, temperature = distantTank.inventoryTemperature})
		-- Remove the distant Fluid --
		distantTank:getFluid({name = distantTank.inventoryFluid, amount = amountAdded})
		if amountAdded > 0 then
			-- Create the Laser --
			self.ent.surface.create_entity{name="PurpleBeam", duration=60, position=self.ent.position, target=localTank.position, source=self.ent.position}
			-- Drain Energy --
			self.internalEnergyObj:removeEnergy(_mfFluidConsomption*amountAdded)
			-- One less Beam to the Beam capacity --
			return true
		end
	end
end

-------------------------------------------- Logistic Laser --------------------------------------------
function MF:updateLogisticLaser(entity)
	-- Check if a laser should be created --
	if technologyUnlocked("TechItemDrain", getForce(self.player)) == false or self.itemLaserActivated == false then return false end 
	-- Create the Laser --
	if self.itemLaserActivated == true and self.internalEnergyObj:energy() > _mfBaseItemEnergyConsumption * self:getLaserItemDrain() and (entity.type == "container" or entity.type == "logistic-container") then
		-- Get Chest Inventory --
		local inv = entity.get_inventory(defines.inventory.chest)
		-- Get the Internal Inventory --
		local dataInv = self.II
		if inv ~= nil and inv.valid == true then
			-- Create the Laser Capacity variable --
			local capItems = self:getLaserItemDrain()
			-- Get all Items --
			local invItems = inv.get_contents()
			-- Retrieve Items from the Inventory --
			for iName, iCount in pairs(invItems) do
				local added = dataInv:addItem(iName, math.min(iCount, capItems))
				-- Check if Items was added --
				if added > 0 then
					-- Remove Items from the Chest --
					local removedItems = inv.remove({name=iName, count=added})
					-- Recalcule the capItems --
					capItems = capItems - added
					-- Create the laser and remove energy --
					if added > 0 then
						self.ent.surface.create_entity{name="GreenBeam", duration=60, position=self.ent.position, target=entity.position, source=self.ent.position}
						self.internalEnergyObj:removeEnergy(_mfBaseItemEnergyConsumption * removedItems)
						-- One less Beam to the Beam capacity --
						return true
					end
					-- Test if capItems is empty --
					if capItems <= 0 then
						-- Stop --
						break
					end
				end
			end
		end
	end
end

-- Update the Fuel --
function MF:updateFuel()
	-- Check if the Mobile Factory is valid --
	if self.ent == nil or self.ent.valid == false then return end
	-- Recharge the tank fuel --
	if self.internalEnergyObj:energy() > 0 and self.ent.get_inventory(defines.inventory.fuel).get_item_count() < 2 then
		if self.ent.burner.remaining_burning_fuel == 0 and self.ent.get_inventory(defines.inventory.fuel).is_empty() == true then
			-- Insert coal in case of the Tank is off --
			self.ent.get_inventory(defines.inventory.fuel).insert({name="coal", count=1})
		elseif self.ent.burner.remaining_burning_fuel > 0 then
			-- Calcule the missing Fuel amount --
			local missingFuelValue = math.floor((_mfMaxFuelValue - self.ent.burner.remaining_burning_fuel) /_mfFuelMultiplicator)
			if math.floor(missingFuelValue/_mfFuelMultiplicator) < self.internalEnergyObj:energy() then
				-- Add the missing Fuel to the Tank --
				self.ent.burner.remaining_burning_fuel = _mfMaxFuelValue
				-- Drain energy --
				self.internalEnergyObj:removeEnergy(missingFuelValue/_mfFuelMultiplicator)
			end
		end
	end
end

-- Update the Shield --
function MF:updateShield(event)
	-- Get the current tick --
	local tick = event.tick
	-- Check if the Mobile Factory is valid --
	if self.ent == nil or self.ent.valid == false then return end
	-- Create the visual --
	if self:shield() > 0 then
		-- Calcule the shield tint --
		local tint = self:shield() / self:maxShield()
		-- Calcule the shield size --
		local mfB = self.ent.selection_box
		local size = (mfB.right_bottom.y - mfB.left_top.y) / 12
		rendering.draw_animation{animation="mfShield", target={self.ent.position.x-0.25, self.ent.position.y-0.3}, tint={1,tint,tint}, time_to_live=2, x_scale=size, y_scale=size, surface=self.ent.surface, render_layer=134}
	end
	-- Charge the Shield --
	local chargeSpeed = 10
	if tick%60 == 0 and self.internalEnergyObj:energy() > 0 then
		-- Get the Shield --
		for k, equipment in pairs(self.ent.grid.equipment) do
			-- Check if this is a Shield --
			if equipment.name == "mfShieldEquipment" then
				local missingCharge = equipment.max_shield - equipment.shield
				local chargeAmount = math.min(missingCharge, chargeSpeed)
				-- Check if the Shield can be charged --
				if chargeAmount > 0 and chargeAmount*_mfShieldComsuption <= self.internalEnergyObj:energy() then
					 -- Charge the Shield --
					 equipment.shield = equipment.shield + chargeAmount
					 -- Remove the energy --
					 self.internalEnergyObj:removeEnergy(chargeAmount*_mfShieldComsuption)
				end
			end
		end
	end
end


-- Send Quatron Charge to the Ore Cleaner --
function MF:SendQuatronToOC(event)
	-- Check if the Mobile Factory is valid --
	if self.ent == nil or self.ent.valid == false then return end
	-- Send Charge only every 10 ticks --
	if event.tick%10 ~= 0 then return end
	for k, oc in pairs(global.oreCleanerTable) do
	-- Check the Distance --
		if valid(oc) == true and oc.player == self.player and Util.distance(self.ent.position, oc.ent.position) < _mfOreCleanerMaxDistance then
			-- Test if there are space inside the Ore Cleaner for Quatron Charge --
			if oc.charge <= _mfFEMaxCharge - 100 then
				-- Get the Best Quatron Change --
				local charge = self.II:getBestQuatron()
				if charge > 0 then
					-- Add the Charge --
					oc:addQuatronCharge(charge)
					-- Create the Laser --
					self.ent.surface.create_entity{name="GreenBeam", duration=30, position=self.ent.position, target={oc.ent.position.x, oc.ent.position.y - 2}, source=self.ent}
				end
			end
		end
	end
end

-- Send Quatron Charge to all Fluid Extractors --
function MF:SendQuatronToFE(event)
	-- Check if the Mobile Factory is valid --
	if self.ent == nil or self.ent.valid == false then return end
	-- Send Charge only every 10 ticks --
	if event.tick%10 ~= 0 then return end
	for k, fe in pairs(global.fluidExtractorTable) do
		-- Check if the Fluid Extractor is valid --
		if valid(fe) == true and fe.player == self.player and Util.distance(self.ent.position, fe.ent.position) < _mfFluidExtractorMaxDistance then
			-- Test if there are space inside the Fluid Extractor for Quatron Charge --
			if fe.charge <= _mfFEMaxCharge - 100 then
				-- Get the Best Quatron Change --
				local charge = self.II:getBestQuatron()
				if charge > 0 then
					-- Add the Charge --
					fe:addQuatronCharge(charge)
					-- Create the Laser --
					fe.ent.surface.create_entity{name="GreenBeam", duration=30, position=self.ent.position, target={fe.ent.position.x, fe.ent.position.y - 2}, source=self.ent}
				end
			end
		end
	end
end

-- Send all Pollution outside --
function MF:updatePollution()
	-- Test if the Mobile Factory is valid --
	if self.fS == nil or self.ent == nil then return end
	if self.ent.valid == false then return end
	if self.ent.surface == nil then return end
	-- Get the total amount of Pollution --
	local totalPollution = self.fS.get_total_pollution()
	if totalPollution ~= nil then
		-- Create Pollution outside the Factory --
		self.ent.surface.pollute(self.ent.position, totalPollution)
		-- Clear the Factory Pollution --
		self.fS.clear_pollution()
	end
end

-- Update teleportation box --
function MF:factoryTeleportBox()
	-- Check the Mobile Factory --
	if self.ent == nil then return end
	if self.ent.valid == false then return end
	-- Mobile Factory Vehicule --
	if self.tpEnabled == true then
		local mfB = self.ent.bounding_box
		local entities = self.ent.surface.find_entities_filtered{area={{mfB.left_top.x-0.5,mfB.left_top.y-0.5},{mfB.right_bottom.x+0.5, mfB.right_bottom.y+0.5}}, type="character"}
		for k, entity in pairs(entities) do
			teleportPlayerInside(entity.player, self)
		end
	end
	-- Factory to Outside --
	if self.fS ~= nil then
		local entities = self.fS.find_entities_filtered{area={{-1,-1},{1,1}}, type="character"}
		for k, entity in pairs(entities) do
			teleportPlayerOutside(entity.player, self)
		end
	end
	-- Factory to Control Center --
	if technologyUnlocked("ControlCenter", getForce(self.player)) ~= false and self.fS ~= nil then
		local entities = self.fS.find_entities_filtered{area={{-3,-34},{3,-32}}, type="character"}
		for k, entity in pairs(entities) do
			teleportPlayerToControlCenter(entity.player, self)
		end
	end
	-- Control Center to Factory --
	if technologyUnlocked("ControlCenter", getForce(self.player)) ~= false and self.ccS ~= nil and self.fS ~= nil then
		local entities = self.ccS.find_entities_filtered{area={{-3,5},{3,8}}, type="character"}
		for k, entity in pairs(entities) do
			teleportPlayerToFactory(entity.player, self)
		end
	end
end

-- Scan modules inside the Equipment Grid --
function MF:scanModules()
	-- Check if the Technology is unlocked --
	if technologyUnlocked("EnergyPowerModule", getForce(self.player)) == nil then return end
	-- Check the Mobile Factory --
	if self.ent == nil or self.ent.valid == false then return end
	-- Init Variables --
	self.laserRadiusMultiplier = 0
	self.laserDrainMultiplier = 0
	self.laserNumberMultiplier = 0
	-- Look for Modules --
	for k, equipment in pairs(self.ent.grid.equipment) do
		if equipment.name == "EnergyPowerModule" then
			self.laserRadiusMultiplier = self.laserRadiusMultiplier + 1
		end
		if equipment.name == "EnergyEfficiencyModule" then
			self.laserDrainMultiplier = self.laserDrainMultiplier + 1
		end
		if equipment.name == "EnergyFocusModule" then
			self.laserNumberMultiplier = self.laserNumberMultiplier + 1
		end
	end
end

-- Call the mobile Factory to the player (Before TP) --
function MF:TPMobileFactoryPart1(location)
	-- Get the Player --
	local player = getPlayer(self.playerIndex)
	-- Check if the Surface Exist --
	if location.surface == nil or game.surfaces[location.surface.name] == nil then
		player.print({"", {"gui-description.TPSurfaceNoFound"}})
		return
	end
	-- Check if the Mobile Factory exist --
	if self.ent == nil or self.ent.valid == false then
		player.print({"", {"gui-description.MFLostOrDestroyed"}})
		return
	end
	-- Check if the Mobile Factory has a Driver --
	if self.ent.get_driver() == nil then
		player.print({"", {"gui-description.TPNoDriver"}})
		return
	end
	-- Try to find the best coords --
	local tpCoords = location.surface.find_non_colliding_position(self.MF.ent.name, {location.posX,location.posY}, 10, 0.1, false)
	-- Return if no coords was found --
	if tpCoords == nil then
		player.print({"", {"gui-description.TPObstruction"}})
		return
	end
	-- Set the Non-colliding Destination --
	location.posX = tpCoords.x
	location.posY = tpCoords.y
	-- Start the TP --
	self.onTP = true
	self.tpCurrentTick = game.tick
	self.tpLocation = location
	-- Start all Animations --
	local animation1 = rendering.draw_animation{animation="SimpleTPAn", animation_speed=0.5, render_layer=131, x_scale=4, y_scale=3.5, target={self.ent.position.x, self.ent.position.y-0.7}, surface=self.ent.surface, time_to_live=150*2}
	Util.resetAnimation(animation1, 150)
	local animation2 = rendering.draw_animation{animation="SimpleTPAn", animation_speed=0.5, render_layer=131, x_scale=4, y_scale=3.5, target={location.posX, location.posY-0.7}, surface=location.surface, time_to_live=150*2}
	Util.resetAnimation(animation2, 150)
	-- Play all Sounds --
	self.ent.surface.play_sound{path="MFSimpleTP", position=self.ent.position}
	self.ent.surface.play_sound{path="MFSimpleTP", position=player.position}
	-- Close the TPGUI --
	local MFPlayer = getMFPlayer(self.playerIndex)
	if MFPlayer.GUI["MFTPGUI"] ~= nil then
		MFPlayer.GUI["MFTPGUI"].destroy()
		MFPlayer.GUI["MFTPGUI"] = nil
	end
end

-- Call the mobile Factory to the player (After TP) --
function MF:TPMobileFactoryPart2()
	-- Get the Player --
	local player = getPlayer(self.playerIndex)
	-- Check if the Surface Exist --
	if self.tpLocation.surface == nil or game.surfaces[self.tpLocation.surface.name] == nil then
		player.print({"", {"gui-description.TPSurfaceNoFound"}})
		-- Stop the TP --
		self.onTP = false
		self.tpCurrentTick = 0
		self.tpLocation = nil
		return
	end
	-- Check if the Mobile Factory exist --
	if self.ent == nil or self.ent.valid == false then
		player.print({"", {"gui-description.MFLostOrDestroyed"}})
		-- Stop the TP --
		self.onTP = false
		self.tpCurrentTick = 0
		self.tpLocation = nil
		return
	end
	-- Check if the Mobile Factory has a Driver --
	if self.ent.get_driver() == nil then
		player.print({"", {"gui-description.TPNoDriver"}})
		-- Stop the TP --
		self.onTP = false
		self.tpCurrentTick = 0
		self.tpLocation = nil
		return
	end
	-- Get the distance --
	local distance = Util.distance({self.tpLocation.posX,self.tpLocation.posY}, self.ent.position)
	-- Remove the Jump Drive Charge --
	self.jumpDriveObj.charge = math.min(0, self.jumpDriveObj.charge - distance)
	-- Remove the Quatron --
	if self.tpLocation.surface ~= self.ent.surface then
		self.internalQuatronObj:removeQuatron(1000)
	end
	-- Teleport the Mobile Factory to the cords --
	self.ent.teleport({self.tpLocation.posX, self.tpLocation.posY}, self.tpLocation.surface)
	-- Save the position --
	self.lastSurface = self.ent.surface
	self.lastPosX = self.ent.position.x
	self.lastPosY = self.ent.position.y
	-- Stop the TP --
	self.onTP = false
	self.tpCurrentTick = 0
	self.tpLocation = nil
end

-- Remove the Sync Area --
function MF:removeSyncArea()
	if self.syncAreaScanned == false then return end
	rendering.destroy(self.syncAreaID)
	rendering.destroy(self.syncAreaInsideID)
	self.syncAreaID = 0
	self.syncAreaInsideID = 0
	self.syncAreaScanned = false
	self:unCloneSyncArea()
end

-- Update the Sync Area --
function MF:updateSyncArea()
	if self.ent == nil or self.ent.valid == false then return end

	local radius = 2 * _mfSyncAreaRadius
	local nearbyMFs = self.ent.surface.count_entities_filtered{position = self.ent.position, radius = radius, name = {"MobileFactory","GTMobileFactory","HMobileFactory"}, limit = 2}

	-- Check if the Mobile Factory is moving or the Sync Area is disabled --
	if self.syncAreaEnabled == false or self.ent.speed ~= 0 then
		self:removeSyncArea()
		return
	end

	if nearbyMFs > 1 then
		local player = getPlayer(self.player)
		if player.connected then
			player.create_local_flying_text{text={"info.MF-sync-too-close"}, position = self.ent.position}
		end
		self:removeSyncArea()
		return
	end

	-- Create the Circle --
	if self.syncAreaID == 0 then
		self.syncAreaID = rendering.draw_circle{color={108,52,131}, radius=_mfSyncAreaRadius, width=1, filled=false,target=self.ent, surface=self.ent.surface}
		self.syncAreaInsideID = rendering.draw_circle{color={108,52,131}, radius=_mfSyncAreaRadius, width=1, filled=false,target=_mfSyncAreaPosition, surface=self.fS}
	end

	-- Scan the Area if needed --
	if self.syncAreaScanned == false then
		self:syncAreaScan()
		self.syncAreaScanned = true
		return
	end

	-- Update Cloned Entities and Remove Invalid Pairs --
	self:updateClonedEntities()
end

-- Scan around the Mobile Factory for the Sync Area --
function MF:syncAreaScan()
	self.clonedResourcesTable = {}
	-- Cloning Tiles --
	local radius = _mfSyncAreaRadius + 1
	local bdb = {{self.ent.position.x - radius, self.ent.position.y - radius},{self.ent.position.x + radius, self.ent.position.y + radius}}
	local clonedBdb = {{_mfSyncAreaPosition.x - radius, _mfSyncAreaPosition.y - radius},{_mfSyncAreaPosition.x + radius, _mfSyncAreaPosition.y + radius}}

	local inside = self.fS
	local outside = self.ent.surface
	local obstructed = nil
	local distancesInBools = {}
	local distancesOutBools = {}

	-- Look for Entities inside the Sync Area --
	local entTableIn = inside.find_entities_filtered{area = clonedBdb, build_type}

--[[
	-- 06-05-2020: suggestion from Klonan, with idea/contributions from Optera
	-- this is complicated. I don't need entities for obstruction detection, but I need them for cloning
	tiles = outside.find_tiles_filtered{position = sync-area, radius = sync-area-radius}
	inside.count_entities_filtered{area = {{tile.position.x, tile.position.y}, {tile.position.x + 1, tile.position.y + 1}}, collision_mask = tile.prototype.collision_mask, limit = 1}
--]]
	-- Check if Entities inside Can't be Placed Outside --
	for k, ent in pairs(entTableIn) do
		if not _mfSyncAreaIgnoredTypes[ent.type] then
			local posX = math.floor(self.ent.position.x) + (ent.position.x - _mfSyncAreaPosition.x)
			local posY = math.floor(self.ent.position.y) + (ent.position.y - _mfSyncAreaPosition.y)

			distancesInBools[k] = Util.distance(ent.position, _mfSyncAreaPosition) < _mfSyncAreaRadius

			-- if we can place it, including marking obstructions for deconstruction... would overlap entities if we have friendly chests etc on the other side
			local arg = {
				name = ent.name,
				position = {posX, posY},
				direction = ent.direction,
				force = ent.force,
				build_check_type = defines.build_check_type.ghost_place,
				forced = true
			}
			-- Will create_entity Fail Without More Details? --
			if _mfSyncAreaExtraDetails[ent.type] then
				for _, key in pairs(_mfSyncAreaExtraDetails[ent.type]) do
					-- LuaItemStack vs SimpleItemStack (dictionary) --
					if key == "stack" then
						--unsure if stack could ever be invalid, but reading would cause an error
						if ent.stack.valid_for_read then
							arg.stack = {name = ent.stack.name, count = ent.stack.count}
						else
							--this is such a hackjob
							arg = nil
							break
						end
					else
						arg[key] = ent[key]
					end
				end
			end
 			if arg and outside.can_place_entity(arg) == false then
				obstructed = ent.localised_name or {"", ent.name}
				break
			end
		end
	end
	if obstructed then
		local player = nil
		if self.player ~= "" then
			player = getPlayer(self.player)
			if player.connected then
				player.create_local_flying_text{text={"", {"info.MF-sync-collision-in-out"}, ": ", obstructed}, position = self.ent.position}
			end
		end
		return
	end

	-- Look for Entities around the Mobile Factory --
	local entTableOut = outside.find_entities_filtered{area = bdb}

	-- Check if Entities inside Can't be Placed Iutside --
	for k, ent in pairs(entTableOut) do
		if _mfSyncAreaAllowedTypes[ent.type] == true then
			local posX = (ent.position.x - math.floor(self.ent.position.x)) + _mfSyncAreaPosition.x
			local posY = (ent.position.y - math.floor(self.ent.position.y)) + _mfSyncAreaPosition.y

			distancesOutBools[k] = Util.distance(ent.position, {math.floor(self.ent.position.x), math.floor(self.ent.position.y)}) < _mfSyncAreaRadius
			if distancesOutBools[k] and inside.entity_prototype_collides(ent.name, {posX, posY}, false) == true then
				obstructed = ent.localised_name or {"", ent.name}
				break
			end
		end
	end
	if obstructed then
		local player = nil
		if self.player ~= "" then
			player = getPlayer(self.player)
			if player.connected then
				player.create_local_flying_text{text={"", {"info.MF-sync-collision-out-in"}, ": ", obstructed}, position = self.ent.position}
			end
		end
		return
	end

	-- Clone Area to Sync Area --
	-- cloning the area can destroy inside entities (invalid tile placement), thus we checked first
	outside.clone_area{source_area=bdb, destination_area=clonedBdb, destination_surface=inside, clone_entities=false, clone_decoratives=false, clear_destination_entities=false}
	createSyncAreaMFSurface(inside)

	-- Clone Outside Entities --
	for k, ent in pairs(entTableOut) do
		if _mfSyncAreaAllowedTypes[ent.type] == true and distancesOutBools[k] == true and ent.name ~= "InternalEnergyCube" and ent.name ~= "InternalQuatronCube" then
			self:cloneEntity(ent, "in")
		end
	end

	-- Clone Inside Entities --
	for k, ent in pairs(entTableIn) do
		if _mfSyncAreaAllowedTypes[ent.type] == true and distancesInBools[k] == true then
			self:cloneEntity(ent, "out")
		end
		if ent.type == "mining-drill" then
			ent.update_connections()
		end
	end

end

-- Clone an Entity --
function MF:cloneEntity(ent, side) -- side: in (Clone inside), out (Clone outside)
	if self.ent == nil or self.ent.valid == false then return nil end
	local posX = 0
	local posY = 0
	local surface = nil
	local clone = nil
	-- Calcul the position and set the Surface --
	if side == "in" then
		posX = ent.position.x - math.floor(self.ent.position.x) + _mfSyncAreaPosition.x
		posY = ent.position.y - math.floor(self.ent.position.y) + _mfSyncAreaPosition.y
		surface = self.fS
	end
	if side == "out" then
		posX = math.floor(self.ent.position.x) + ent.position.x - _mfSyncAreaPosition.x
		posY = math.floor(self.ent.position.y) + ent.position.y - _mfSyncAreaPosition.y
		surface = self.ent.surface
	end
	-- Clone the Entity --
	clone = ent.clone{position={posX, posY}, surface=surface}
	if clone ~= nil then
		table.insert(self.clonedResourcesTable,  {original=ent, cloned=clone})
		if ent.type == "container" then
			clone.get_inventory(defines.inventory.chest).clear()
		end
		if ent.type == "storage-tank" then
			clone.clear_fluid_inside()
		end
		if ent.type == "accumulator" then
			clone.energy = 0
		end
	end
	return clone
end

-- Return Items From Chest2 to Chest1 --
local function uncloneChest(chest1, chest2)
	local inv1 = chest1.get_inventory(defines.inventory.chest)
	local inv2 = chest2.get_inventory(defines.inventory.chest)
	for item, count in pairs(inv2.get_contents()) do
		inv1.insert({name = item, count = count})
	end
	inv2.clear()
end

-- Return Fluid From Tank2 to Tank1 --
local function uncloneStorageTank(tank1, tank2)

	-- Check the Tanks --
	if tank1.fluidbox[1] == nil and tank2.fluidbox[1] == nil then return end

	-- Get Tanks Fluid --
	local t1FluidName = nil
	local t1FluidAmount = 0
	local t1FluidTemperature = nil
	local t2FluidName = nil
	local t2FluidAmount = 0
	local t2FluidTemperature = nil
	if tank1.fluidbox[1] ~= nil then
		t1FluidName = tank1.fluidbox[1].name
		t1FluidAmount = tank1.fluidbox[1].amount
		t1FluidTemperature = tank1.fluidbox[1].temperature
	end
	if tank2.fluidbox[1] ~= nil then
		t2FluidName = tank2.fluidbox[1].name
		t2FluidAmount = tank2.fluidbox[1].amount
		t2FluidTemperature = tank2.fluidbox[1].temperature
	end

	-- Clear Tank2 --
	tank2.clear_fluid_inside()

	-- Check the Fluids --
	if t1FluidName ~= nil and t2FluidName ~= nil and t1FluidName ~= t2FluidName then return end
	if t1FluidName == nil then t1FluidTemperature = t2FluidTemperature end
	if t2FluidName == nil then t2FluidTemperature = t1FluidTemperature end

	-- Calcul total Fluid --
	local fluidName = t1FluidName or t2FluidName
	local fluidAmount = math.floor(t1FluidAmount + t2FluidAmount)
	local fluidTemperature = math.floor(t1FluidTemperature + t2FluidTemperature)/2


	-- Check the Amount of Fluid --
	if fluidAmount <= 0 then return end

	-- Give Tank1 all Fluid --
	tank1.fluidbox[1] = {name=fluidName, amount=fluidAmount, temperature=fluidTemperature}

end

-- Send Energy from cloned Accu2 --
local function uncloneAccumulator(accu1, accu2)
	-- Calcul the total energy --	
	local totalEnergy = accu1.energy + accu2.energy
	-- Set the Energy of the Accu1 --
	accu1.energy = totalEnergy
end

-- Unclone all Entities inside the Sync Area --
function MF:unCloneSyncArea()
	-- Set default Tiles --
	createSyncAreaMFSurface(self.fS, true)
	-- Update Before Trying to Unclone -- 
	self:updateClonedEntities()
	-- Remove all cloned Entities --
	for i, ents in pairs(self.clonedResourcesTable) do
		if ents.original.type == "container" then
			uncloneChest(ents.original, ents.cloned)
		elseif ents.original.type == "storage-tank" then
			uncloneStorageTank(ents.original, ents.cloned)
		elseif ents.original.type == "accumulator" then
			uncloneAccumulator(ents.original, ents.cloned)
		end
		script.raise_event(defines.events.script_raised_destroy, {entity=ents.cloned})
		ents.cloned.destroy()
	end
	self.clonedResourcesTable = {}
end

-- Update Entities inside the Sync Area --
function MF:updateClonedEntities()
	for i, ents in pairs(self.clonedResourcesTable) do
		self:updateClonedEntity(ents)
		if ents.original == nil or ents.original.valid == false then
			-- only checking original because both are nil/invalid after updating
			table.remove(self.clonedResourcesTable, i)
		end
	end
end

-- Update an Entity inside the Sync Area --
function MF:updateClonedEntity(ents)
	-- Check the Entities --
	if ents == nil then return end
	if ents.original == nil or ents.original.valid == false then
		if ents.cloned ~= nil and ents.cloned.valid == true then
			ents.cloned.destroy({raise_destroy = true})
		end
		return
	end
	if ents.cloned == nil or ents.cloned.valid == false then
		if ents.original ~= nil and ents.original.valid == true then
			ents.original.destroy({raise_destroy = true})
		end
		return
	end
	if ents.original.type == "resource" then
		-- If the Entity is a resource --
		if ents.cloned.amount < ents.original.amount then
			ents.original.amount = ents.cloned.amount
		end
		if ents.cloned.amount > ents.original.amount then
			ents.cloned.amount = ents.original.amount
		end
		if ents.original.amount <= 0 then
			ents.original.destroy()
			ents.cloned.destroy()
		end
	elseif ents.original.type == "container" then
		-- If the Entity is a Chest --
		Util.syncChest(ents.original, ents.cloned)
	elseif ents.original.type == "storage-tank" then
		-- If the Entity is a Storage Tank --
		Util.syncTank(ents.original, ents.cloned)
	elseif ents.original.type == "accumulator" then
		-- If the Entity is an Accumulator --
		Util.syncAccumulator(ents.original, ents.cloned)
	end
end
