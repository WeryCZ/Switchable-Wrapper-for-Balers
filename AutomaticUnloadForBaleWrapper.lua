AutomaticUnloadForBaleWrapper = {};
AutomaticUnloadForBaleWrapper.modName = "";

for _, mod in pairs(g_modManager.mods) do
	if mod.title == "Automatisches Abladen für Ballenwickler" or mod.title == "Automatic unload for bale wrappers" then		
		if g_modIsLoaded[tostring(mod.modName)] then	
			AutomaticUnloadForBaleWrapper.modName = mod.modName;
			
			break;
		end;
	end;
end;

AutomaticUnloadForBaleWrapper.DROP_MODE_MANUAL = 1;
AutomaticUnloadForBaleWrapper.DROP_MODE_AUTOMATIC = 2;
AutomaticUnloadForBaleWrapper.DROP_MODE_COLLECT = 3;
AutomaticUnloadForBaleWrapper.DROP_MODE_MAX_STATE = 2;
AutomaticUnloadForBaleWrapper.DROP_MODE_BALER_MAX_STATE = 3;
AutomaticUnloadForBaleWrapper.FORCE_DROP_BALE = false;

function AutomaticUnloadForBaleWrapper.initSpecialization()
	local schemaSavegame = Vehicle.xmlSchemaSavegame;

	schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?).automaticUnloadForBaleWrapper#currentDropModeState", "Current drop mode.", AutomaticUnloadForBaleWrapper.DROP_MODE_MANUAL);
	schemaSavegame:register(XMLValueType.BOOL, "vehicles.vehicle(?).automaticUnloadForBaleWrapper#baleWrapperIsActive", "Is bale wrapper active.", true);
end;

function AutomaticUnloadForBaleWrapper.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(BaleWrapper, specializations);
end;

function AutomaticUnloadForBaleWrapper.registerEventListeners(vehicleType)
	local functionNames = {
		"onLoad",
		"onUpdate",
		"saveToXMLFile",
		"onWriteStream",
		"onReadStream",
		"onRegisterActionEvents"
	};
	
	for _, functionName in ipairs(functionNames) do
		SpecializationUtil.registerEventListener(vehicleType, functionName, AutomaticUnloadForBaleWrapper);
	end;
end;

function AutomaticUnloadForBaleWrapper.registerFunctions(vehicleType)
	local functionNames = {
		"setDropMode",
		"toggleBaleWrapper"
	};
	
	for _, functionName in ipairs(functionNames) do
		SpecializationUtil.registerFunction(vehicleType, functionName, AutomaticUnloadForBaleWrapper[functionName]);
	end;
end;

function AutomaticUnloadForBaleWrapper:onLoad(savegame)
	local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
	local specBaler = self.spec_baler;

	specAutomaticUnloadForBaleWrapper.foundGoeweilDLC = self.xmlFile.filename:find("pdlc/goeweilPack/vehicles/goeweil/ltMaster/ltMaster.xml") or self.xmlFile.filename:find("pdlc/goeweilPack/vehicles/goeweil/varioMaster/varioMaster.xml");

	--## deactivate default button for switching between automatic and manual unload for balers with bale wrappers
	self.spec_baleWrapper.toggleableAutomaticDrop = false;
	
	if savegame ~= nil and not savegame.resetVehicles then
		specAutomaticUnloadForBaleWrapper.currentDropModeState = savegame.xmlFile:getValue(savegame.key .. ".automaticUnloadForBaleWrapper#currentDropModeState", AutomaticUnloadForBaleWrapper.DROP_MODE_MANUAL);
		
		if specBaler ~= nil and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then	
			specAutomaticUnloadForBaleWrapper.baleWrapperIsActive = savegame.xmlFile:getValue(savegame.key .. ".automaticUnloadForBaleWrapper#baleWrapperIsActive", true);
		end;
	else
		specAutomaticUnloadForBaleWrapper.currentDropModeState = AutomaticUnloadForBaleWrapper.DROP_MODE_MANUAL;
		
		if specBaler ~= nil and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then
			specAutomaticUnloadForBaleWrapper.baleWrapperIsActive = true;
		end;
	end;
	
	self:setDropMode(specAutomaticUnloadForBaleWrapper.currentDropModeState, false);

	specAutomaticUnloadForBaleWrapper.l10NTexts = {};
	specAutomaticUnloadForBaleWrapper.maxDropState = AutomaticUnloadForBaleWrapper.DROP_MODE_MAX_STATE;
	
	if specBaler ~= nil and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then
		self:toggleBaleWrapper(specAutomaticUnloadForBaleWrapper.baleWrapperIsActive);
		
		self.doStateChange = Utils.overwrittenFunction(self.doStateChange, AutomaticUnloadForBaleWrapper.doStateChange);
		self.pickupWrapperBale = Utils.overwrittenFunction(self.pickupWrapperBale, AutomaticUnloadForBaleWrapper.pickupWrapperBale);

		local l10NTexts = {
			"START_BALE_WRAPPER",
			"STOP_BALE_WRAPPER",
			"DROP_MODE_COLLECT",
		};
	
		for _, l10NText in pairs(l10NTexts) do
			specAutomaticUnloadForBaleWrapper.l10NTexts[l10NText] = g_i18n:getText(l10NText, AutomaticUnloadForBaleWrapper.modName);
		end;

		--## enable the collect mode for balers with bale wrappers
		specAutomaticUnloadForBaleWrapper.maxDropState = AutomaticUnloadForBaleWrapper.DROP_MODE_BALER_MAX_STATE;
	end;

	local l10NTexts = {
		"DROP_MODE_MANUALLY",
		"DROP_MODE_AUTOMATIC",
		"CURRENT_DROP_MODE"
	};

	for _, l10NText in pairs(l10NTexts) do
		specAutomaticUnloadForBaleWrapper.l10NTexts[l10NText] = g_i18n:getText(l10NText, AutomaticUnloadForBaleWrapper.modName);
	end;
end;

function AutomaticUnloadForBaleWrapper:setDropMode(currentDropModeState, noEventSend)
    local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;

	if currentDropModeState ~= specAutomaticUnloadForBaleWrapper.currentDropModeState then
		specAutomaticUnloadForBaleWrapper.currentDropModeState = currentDropModeState;
		
		 if not noEventSend then
			if g_server ~= nil then
				g_server:broadcastEvent(SetDropModeEvent.new(self, currentDropModeState), nil, nil, self);
			else
				g_client:getServerConnection():sendEvent(SetDropModeEvent.new(self, currentDropModeState));
			end;
		end;
	end;
end;

function AutomaticUnloadForBaleWrapper:onWriteStream(streamId, connection)
	if not connection:getIsServer() then 
		local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
		local specBaler = self.spec_baler;
		
		streamWriteUIntN(streamId, specAutomaticUnloadForBaleWrapper.currentDropModeState, specAutomaticUnloadForBaleWrapper.maxDropState);

		if specBaler ~= nil and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then	
			streamWriteBool(streamId, specAutomaticUnloadForBaleWrapper.baleWrapperIsActive);
		end;
	end;
end;

function AutomaticUnloadForBaleWrapper:onReadStream(streamId, connection)
	if connection:getIsServer() then
		local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
		local specBaler = self.spec_baler;
		
		specAutomaticUnloadForBaleWrapper.currentDropModeState = streamReadUIntN(streamId, specAutomaticUnloadForBaleWrapper.maxDropState);
		
		if specBaler ~= nil and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then
			specAutomaticUnloadForBaleWrapper.baleWrapperIsActive = streamReadBool(streamId);
		end;
	end;
end;

function AutomaticUnloadForBaleWrapper:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
        local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
        
		self:clearActionEventsTable(specAutomaticUnloadForBaleWrapper.actionEvents);
        
		if self:getIsActiveForInput(true, false) then
            local newFunctions = {
				"CHANGE_DROP_MODE_BUTTON",
				"TOGGLE_BALE_WRAPPER_BUTTON"
			};
			
			for _, newFunction in ipairs(newFunctions) do
				local _, actionEventId = self:addPoweredActionEvent(specAutomaticUnloadForBaleWrapper.actionEvents, InputAction[newFunction], self, AutomaticUnloadForBaleWrapper.actionEventChangeDropeMode, false, true, false, true, nil);
			
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH);
				g_inputBinding:setActionEventActive(actionEventId, false);
			end;
		end;
	end;
end;

function AutomaticUnloadForBaleWrapper.actionEventChangeDropeMode(self, actionName, inputValue, callbackState, isAnalog)
	local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
	local specBaler = self.spec_baler;
	
	if actionName == "CHANGE_DROP_MODE_BUTTON" then
		if specAutomaticUnloadForBaleWrapper.currentDropModeState < specAutomaticUnloadForBaleWrapper.maxDropState then
			self:setDropMode(specAutomaticUnloadForBaleWrapper.currentDropModeState + 1);
		else
			self:setDropMode(AutomaticUnloadForBaleWrapper.DROP_MODE_MANUAL);
		end;
	else
		if specBaler ~= nil then	
			self:toggleBaleWrapper(not specAutomaticUnloadForBaleWrapper.baleWrapperIsActive);
		end;
	end;
end;

function AutomaticUnloadForBaleWrapper:doStateChange(superFunc, id, nearestBaleServerId)
    local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
	local specBaleWrapper = self.spec_baleWrapper;
	
	if id == BaleWrapper.CHANGE_WRAPPING_START and not specAutomaticUnloadForBaleWrapper.baleWrapperIsActive and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then
        specBaleWrapper.baleWrapperState = BaleWrapper.STATE_WRAPPER_FINSIHED;
        
		return;
    end;

	if id == BaleWrapper.CHANGE_WRAPPING_START or specBaleWrapper.baleWrapperState ~= BaleWrapper.STATE_WRAPPER_FINSIHED and id == BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE then
		local bale = NetworkUtil.getObject(specBaleWrapper.currentWrapper.currentBale)
		local baleType = specBaleWrapper.currentWrapper.allowedBaleTypes[specBaleWrapper.currentBaleTypeIndex]

		if not bale:getSupportsWrapping() or baleType.skipWrapping or bale.wrappingState == 1 then
			if self.isServer then
				specBaleWrapper.setWrappingStateFinished = true
			end

			return
		end
	end

	if id == BaleWrapper.CHANGE_GRAB_BALE then
		local bale = NetworkUtil.getObject(nearestBaleServerId)
		specBaleWrapper.baleGrabber.currentBale = nearestBaleServerId

		if bale ~= nil then
			local x, y, z = localToLocal(bale.nodeId, getParent(specBaleWrapper.baleGrabber.grabNode), 0, 0, 0)

			setTranslation(specBaleWrapper.baleGrabber.grabNode, x, y, z)
			bale:mountKinematic(self, specBaleWrapper.baleGrabber.grabNode, 0, 0, 0, 0, 0, 0)
			bale:setCanBeSold(false)

			specBaleWrapper.baleToMount = nil

			self:playMoveToWrapper(bale)
		else
			specBaleWrapper.baleToMount = {
				serverId = nearestBaleServerId,
				linkNode = specBaleWrapper.baleGrabber.grabNode,
				trans = {
					0,
					0,
					0
				},
				rot = {
					0,
					0,
					0
				}
			}
		end

		specBaleWrapper.baleWrapperState = BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER
	elseif id == BaleWrapper.CHANGE_DROP_BALE_AT_GRABBER then
		local attachNode = specBaleWrapper.currentWrapper.baleNode
		local bale = NetworkUtil.getObject(specBaleWrapper.baleGrabber.currentBale)

		if bale ~= nil then
			bale:mountKinematic(self, attachNode, 0, 0, 0, 0, 0, 0)
			bale:setCanBeSold(false)

			specBaleWrapper.baleToMount = nil
		else
			specBaleWrapper.baleToMount = {
				serverId = specBaleWrapper.baleGrabber.currentBale,
				linkNode = attachNode,
				trans = {
					0,
					0,
					0
				},
				rot = {
					0,
					0,
					0
				}
			}
		end

		self:updateWrapNodes(true, false, 0)

		specBaleWrapper.currentWrapper.currentBale = specBaleWrapper.baleGrabber.currentBale
		specBaleWrapper.baleGrabber.currentBale = nil

		if specBaleWrapper.currentWrapper.animations.moveToWrapper.animName ~= nil and specBaleWrapper.currentWrapper.animations.moveToWrapper.reverseAfterMove then
			self:playAnimation(specBaleWrapper.currentWrapper.animations.moveToWrapper.animName, -specBaleWrapper.currentWrapper.animations.moveToWrapper.animSpeed, nil, true)
		end

		specBaleWrapper.baleWrapperState = BaleWrapper.STATE_MOVING_GRABBER_TO_WORK
	elseif id == BaleWrapper.CHANGE_WRAPPING_START then
		specBaleWrapper.baleWrapperState = BaleWrapper.STATE_WRAPPER_WRAPPING_BALE

		if self.isClient then
			g_soundManager:playSamples(specBaleWrapper.currentWrapper.samples.start)
			g_soundManager:playSamples(specBaleWrapper.currentWrapper.samples.wrap, 0, specBaleWrapper.currentWrapper.samples.start[1])
		end

		if specBaleWrapper.currentWrapper.animations.wrapBale.animName ~= nil then
			self:playAnimation(specBaleWrapper.currentWrapper.animations.wrapBale.animName, specBaleWrapper.currentWrapper.animations.wrapBale.animSpeed, nil, true)
		end
	elseif id == BaleWrapper.CHANGE_WRAPPING_BALE_FINSIHED then
		if self.isClient then
			g_soundManager:stopSamples(specBaleWrapper.currentWrapper.samples.wrap)
			g_soundManager:stopSamples(specBaleWrapper.currentWrapper.samples.stop)

			if specBaleWrapper.currentWrapper.wrappingSoundEndTime == 1 then
				g_soundManager:playSamples(specBaleWrapper.currentWrapper.samples.stop)
			end

			g_soundManager:stopSamples(specBaleWrapper.currentWrapper.samples.start)
		end

		self:updateWrappingState(1, true)

		specBaleWrapper.baleWrapperState = BaleWrapper.STATE_WRAPPER_FINSIHED
		local bale = NetworkUtil.getObject(specBaleWrapper.currentWrapper.currentBale)
		local baleType = specBaleWrapper.currentWrapper.allowedBaleTypes[specBaleWrapper.currentBaleTypeIndex]
		local skippedWrapping = not bale:getSupportsWrapping() or baleType.skipWrapping

		if skippedWrapping or bale.wrappingState == 1 then
			self:updateWrappingState(0, true)
		end

		if not skippedWrapping then
			local animation = specBaleWrapper.currentWrapper.animations.resetWrapping

			if animation.animName ~= nil then
				self:playAnimation(animation.animName, animation.animSpeed, nil, true)
			end
		end
	elseif id == BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE then
		self:updateWrapNodes(false, false, 0)

		if specBaleWrapper.currentWrapper.animations.dropFromWrapper.animName ~= nil then
			self:playAnimation(specBaleWrapper.currentWrapper.animations.dropFromWrapper.animName, specBaleWrapper.currentWrapper.animations.dropFromWrapper.animSpeed, nil, true)
		end

		specBaleWrapper.baleWrapperState = BaleWrapper.STATE_WRAPPER_DROPPING_BALE
	elseif id == BaleWrapper.CHANGE_WRAPPER_BALE_DROPPED then
		local bale = NetworkUtil.getObject(specBaleWrapper.currentWrapper.currentBale)

		if bale ~= nil then
			bale:unmountKinematic()
			bale:setCanBeSold(true)

			local baleType = specBaleWrapper.currentWrapper.allowedBaleTypes[specBaleWrapper.currentBaleTypeIndex]

			if bale:getSupportsWrapping() and not baleType.skipWrapping and specAutomaticUnloadForBaleWrapper.baleWrapperIsActive then
				local stats = g_currentMission:farmStats(self:getOwnerFarmId())
				local total = stats:updateStats("wrappedBales", 1)

				g_achievementManager:tryUnlock("WrappedBales", total)

				if bale.wrappingState < 1 then
					bale:setWrappingState(1)
				end
			end
		end

		specBaleWrapper.lastDroppedBale = bale
		specBaleWrapper.currentWrapper.currentBale = nil
		specBaleWrapper.currentWrapper.currentTime = 0

		if specBaleWrapper.currentWrapper.animations.resetAfterDrop.animName ~= nil then
			local dropAnimationName = specBaleWrapper.currentWrapper.animations.dropFromWrapper.animName

			if self:getIsAnimationPlaying(dropAnimationName) then
				self:stopAnimation(dropAnimationName, true)
				self:setAnimationTime(dropAnimationName, 1, true, false)
			end

			self:playAnimation(specBaleWrapper.currentWrapper.animations.resetAfterDrop.animName, specBaleWrapper.currentWrapper.animations.resetAfterDrop.animSpeed, nil, true)
		end

		self:setBaleWrapperType(specBaleWrapper.currentWrapper == specBaleWrapper.roundBaleWrapper, specBaleWrapper.currentBaleTypeIndex)

		specBaleWrapper.baleWrapperState = BaleWrapper.STATE_WRAPPER_RESETTING_PLATFORM
	elseif id == BaleWrapper.CHANGE_WRAPPER_PLATFORM_RESET then
		self:updateWrappingState(0)
		self:updateWrapNodes(false, true, 0)

		specBaleWrapper.baleWrapperState = BaleWrapper.STATE_NONE
	elseif id == BaleWrapper.CHANGE_BUTTON_EMPTY then
		assert(self.isServer)

		if specBaleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
			g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE), true, nil, self)
		end
	end
end;

function AutomaticUnloadForBaleWrapper:pickupWrapperBale(superFunc, bale, baleType)
    local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
	
	if not specAutomaticUnloadForBaleWrapper.baleWrapperIsActive and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then 
        g_server:broadcastEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_GRAB_BALE, NetworkUtil.getObjectId(bale)), true, nil, self);
    else
        superFunc(self, bale, baleType);
    end;
end;

function AutomaticUnloadForBaleWrapper:toggleBaleWrapper(baleWrapperIsActive, noEventSend)
	local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
	
	if baleWrapperIsActive ~= specAutomaticUnloadForBaleWrapper.baleWrapperIsActive then
		if not noEventSend then
			if g_server ~= nil then
				g_server:broadcastEvent(ToggleBaleWrapperEvent.new(self, baleWrapperIsActive), nil, nil, self);
			else
				g_client:getServerConnection():sendEvent(ToggleBaleWrapperEvent.new(self, baleWrapperIsActive));
			end;
		end;
		
		specAutomaticUnloadForBaleWrapper.baleWrapperIsActive = baleWrapperIsActive;
	end;
end;

function AutomaticUnloadForBaleWrapper:saveToXMLFile(xmlFile, key)
	local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
	local specBaler = self.spec_baler;
	
	xmlFile:setValue(key .. "#currentDropModeState", specAutomaticUnloadForBaleWrapper.currentDropModeState);
	
	if specBaler ~= nil then	
		xmlFile:setValue(key .. "#baleWrapperIsActive", specAutomaticUnloadForBaleWrapper.baleWrapperIsActive);
	end;
end;

function AutomaticUnloadForBaleWrapper:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	if self:getIsActiveForInput(true, false) or string.find(self.configFileName, "stationaryBalerSRBW4K") then
		local specAutomaticUnloadForBaleWrapper = self.spec_automaticUnloadForBaleWrapper;
		local specBaleWrapper = self.spec_baleWrapper;
		local specBaler = self.spec_baler;
		
		if specBaler ~= nil and not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then
			if specBaleWrapper.baleToLoad == nil then
				if specBaleWrapper.baleWrapperState < BaleWrapper.STATE_MOVING_BALE_TO_WRAPPER or specBaleWrapper.baleWrapperState >= BaleWrapper.STATE_WRAPPER_WRAPPING_BALE then
					if specAutomaticUnloadForBaleWrapper.baleWrapperIsActive and self.isServer then
						local bale = NetworkUtil.getObject(specBaleWrapper.currentWrapper.currentBale);
						
						if bale ~= nil and bale.wrappingState == 0 and specBaleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then
							self:playMoveToWrapper(bale);
						end;
					end;
				end;
			end;
			
			local toggleBaleWrapperButton = specAutomaticUnloadForBaleWrapper.actionEvents[InputAction.TOGGLE_BALE_WRAPPER_BUTTON];

			if toggleBaleWrapperButton ~= nil then
				local currentText = specAutomaticUnloadForBaleWrapper.l10NTexts.START_BALE_WRAPPER;
				
				if specAutomaticUnloadForBaleWrapper.baleWrapperIsActive then
					currentText = specAutomaticUnloadForBaleWrapper.l10NTexts.STOP_BALE_WRAPPER;
				end;

				local allowToggleBaleWrapper = specBaleWrapper.currentWrapper.currentBale == nil;
				local currentFillType = g_fillTypeManager:getFillTypeByIndex(self:getFillUnitFillType(specBaler.fillUnitIndex)).name;
				
				if currentFillType ~= nil and currentFillType ~= "UNKNOWN" then
					allowToggleBaleWrapper = allowToggleBaleWrapper and currentFillType == "GRASS_WINDROW";
				end;
				
				g_inputBinding:setActionEventActive(toggleBaleWrapperButton.actionEventId, allowToggleBaleWrapper);
				g_inputBinding:setActionEventTextVisibility(toggleBaleWrapperButton.actionEventId, allowToggleBaleWrapper);
				g_inputBinding:setActionEventText(toggleBaleWrapperButton.actionEventId, currentText);
			end;
		end;
		
		if not specAutomaticUnloadForBaleWrapper.foundGoeweilDLC then
			local changeDropModeButton = specAutomaticUnloadForBaleWrapper.actionEvents[InputAction.CHANGE_DROP_MODE_BUTTON];

			if changeDropModeButton ~= nil then
				local currentText = specAutomaticUnloadForBaleWrapper.l10NTexts.DROP_MODE_MANUALLY;

				g_inputBinding:setActionEventActive(changeDropModeButton.actionEventId, true);

				if specAutomaticUnloadForBaleWrapper.currentDropModeState == AutomaticUnloadForBaleWrapper.DROP_MODE_AUTOMATIC then
					currentText = specAutomaticUnloadForBaleWrapper.l10NTexts.DROP_MODE_AUTOMATIC;
				elseif specAutomaticUnloadForBaleWrapper.currentDropModeState == AutomaticUnloadForBaleWrapper.DROP_MODE_COLLECT then
					currentText = specAutomaticUnloadForBaleWrapper.l10NTexts.DROP_MODE_COLLECT;
				end;

				g_inputBinding:setActionEventText(changeDropModeButton.actionEventId, string.gsub(specAutomaticUnloadForBaleWrapper.l10NTexts.CURRENT_DROP_MODE, "currentDropMode", currentText));
			end;

			if specBaleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED and specAutomaticUnloadForBaleWrapper.currentDropModeState > AutomaticUnloadForBaleWrapper.DROP_MODE_MANUAL then
				local allowDropBale = false;

				if specAutomaticUnloadForBaleWrapper.currentDropModeState == AutomaticUnloadForBaleWrapper.DROP_MODE_AUTOMATIC then
					allowDropBale = true;
				elseif AutomaticUnloadForBaleWrapper.FORCE_DROP_BALE then
					allowDropBale = true;

					AutomaticUnloadForBaleWrapper.FORCE_DROP_BALE = false;
				elseif specAutomaticUnloadForBaleWrapper.currentDropModeState == AutomaticUnloadForBaleWrapper.DROP_MODE_COLLECT then
					if self.spec_fillUnit:getFillUnitFillLevel(1) == self.spec_fillUnit:getFillUnitCapacity(1) then
						allowDropBale = true;

						AutomaticUnloadForBaleWrapper.FORCE_DROP_BALE = true;
					end;
				end;

				if self.isClient and allowDropBale then
					g_client:getServerConnection():sendEvent(BaleWrapperStateEvent.new(self, BaleWrapper.CHANGE_BUTTON_EMPTY));
				end;
			end;
		end;
	end;
end;

-----------------------------------------------------------------------------
--## Multiplayer Event | Change Drop Mode
-----------------------------------------------------------------------------

SetDropModeEvent = {};
SetDropModeEvent_mt = Class(SetDropModeEvent, Event);

InitEventClass(SetDropModeEvent, "SetDropModeEvent");

function SetDropModeEvent.emptyNew()
    local self = Event.new(SetDropModeEvent_mt);

    self.className = "SetDropModeEvent";

    return self;
end;

function SetDropModeEvent.new(baleWrapper, currentDropModeState)
    local self = SetDropModeEvent.emptyNew();
	
    self.baleWrapper = baleWrapper;
    self.currentDropModeState = currentDropModeState;
    
	return self;
end;

function SetDropModeEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.baleWrapper);

    streamWriteInt32(streamId, self.currentDropModeState);
end;

function SetDropModeEvent:readStream(streamId, connection)
    self.baleWrapper = NetworkUtil.readNodeObject(streamId);
    self.currentDropModeState = streamReadInt32(streamId);

    self:run(connection);
end;

function SetDropModeEvent:run(connection)	
	if not connection:getIsServer() then
		g_server:broadcastEvent(SetDropModeEvent.new(self.baleWrapper, self.currentDropModeState), nil, connection, self.baleWrapper);
	end;
	
	if self.baleWrapper ~= nil and self.baleWrapper.setDropMode ~= nil then	
		self.baleWrapper:setDropMode(self.currentDropModeState, true);
	end;
end;

-----------------------------------------------------------------------------
--## Multiplayer Event | Turn off/on bale wrapper
-----------------------------------------------------------------------------

ToggleBaleWrapperEvent = {};
ToggleBaleWrapperEvent_mt = Class(ToggleBaleWrapperEvent, Event);

InitEventClass(ToggleBaleWrapperEvent, "ToggleBaleWrapperEvent");

function ToggleBaleWrapperEvent.emptyNew()
	local self = Event.new(ToggleBaleWrapperEvent_mt);
    
	return self;
end;

function ToggleBaleWrapperEvent.new(baleWrapper, baleWrapperIsActive)
	local self = ToggleBaleWrapperEvent.emptyNew();
	
	self.baleWrapper = baleWrapper;
	self.baleWrapperIsActive = baleWrapperIsActive;
	
	return self;
end;

function ToggleBaleWrapperEvent:readStream(streamId, connection)
	self.baleWrapper = NetworkUtil.readNodeObject(streamId);
	self.baleWrapperIsActive = streamReadBool(streamId);
    
	self:run(connection);
end;

function ToggleBaleWrapperEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.baleWrapper);

	streamWriteBool(streamId, self.baleWrapperIsActive);
end;

function ToggleBaleWrapperEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(ToggleBaleWrapperEvent.new(self.baleWrapper, self.baleWrapperIsActive), nil, connection, self.baleWrapper);
	end;
	
    if self.baleWrapper ~= nil and self.baleWrapper.toggleBaleWrapper ~= nil then
        self.baleWrapper:toggleBaleWrapper(self.baleWrapperIsActive, true);
	end;
end;