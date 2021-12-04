AddonName = "CritterCallerLight"
OldAddonName = "CritterCaller"

local Weighting
local NormalisedWeighting

CritterCallerLight_Enabled = true

local SummoningQuestPet = false
local QuestPetSummoned = false
local HasSummoned = false
local SummonedPetIndex = 0
local DebugOn = false
local NeedToLoadMacros = true

local LastSummonTime = 0

_G["BINDING_HEADER_CRITTERCALLERLIGHT"] = "Critter Caller Light"

local PetItemSpellIds = 
{
	17567,	-- Bloodsail Admiral's Hat
	23012,	-- Orcish Orphan Whistle
	23013,	-- Human Orphan Whistle
	39478,	-- Blood Elf Orphan Whistle
	39479,	-- Draenei Orphan Whistle
	44879,	-- Sizzling Embers
	47794,	-- Golem Control Unit
	51149,	-- Don Carlos' Famous Hat
	65183,	-- Venomhide Hatchling
	65352,	-- Oracle Orphan Whistle
	65353,	-- Wolvar Orphan Whistle	
	66175	-- Macabre Marionette
}

local PetItemSpells = {}

function PetSummon_NormaliseWeightings( weights )
	local i
	local total = 0
	local name, weightName
	
	local normalised = {}
	
	total = 0
	
	for name, weight in pairs( weights ) do
		total = total + weight
	end
	
	if total <= 0 then
		total = 1
	end
	
	for name, weight in pairs( weights ) do
		normalised[ name ] = weight / total
	end 
		
	return normalised
end


function CritterCallerLight_RebuildWeightings()
	Weighting = {}
	
	-- GetNumPets returns unflitered count, GetPetInfoByIndex returns filteres count.
	-- Need to clear filters to make them match. Not very user friendly.
	--C_PetJournal.ClearSearchFilter() 
	--C_PetJournal.AddAllPetTypesFilter()
	--C_PetJournal.AddAllPetSourcesFilter()
	
	local _, numPets = C_PetJournal.GetNumPets(true)		
	for i=1,numPets,1 do
		local petID, _, _, _, _, _, _, _, _, _, companionID = C_PetJournal.GetPetInfoByIndex(i)
		if petID then
			local _, _, _, _, rarity = C_PetJournal.GetPetStats(petID)
			
			if C_PetJournal.PetIsSummonable(petID) then			
				local weight = 1.0
				--weight = weight * CritterCallerLight_PetRarityMul[rarity] / 100.0
				
				Weighting[petID] = weight
			end
		end
	end
	
	NormalisedWeighting = PetSummon_NormaliseWeightings( Weighting )
end

local AlreadyInitialised = false

local function AttemptInitialisation()
	if not AlreadyInitialised then 
		local _, numPets = C_PetJournal.GetNumPets(true)
		if numPets > 0 then
			AlreadyInitialised = true
			CritterCallerLight_RebuildWeightings()
		end
	end
end


function PetSummon_OnAddonLoaded()
	
	if CritterCallerLightOptions == nil then
		CritterCallerLightOptions = {}
		CritterCallerLightOptions["RarityMul"] = { 1, 1, 1, 1, 1, 5 }
		CritterCallerLightOptions["ResummonTime"] = 15
	end

	CritterCallerLight_RebuildWeightings()
	
	for index,spellid in ipairs(PetItemSpellIds) do
		GetItemInfo( spellid )
		local spellname = GetSpellInfo( spellid )
		if spellname then
			PetItemSpells[ spellname ] = 1
		end
	end
	
	LastSummonTime = GetTime()
		
	CheckForCompanion()
		
	hooksecurefunc( "MoveForwardStart", SummonPet )
	hooksecurefunc( "ToggleAutoRun", SummonPet )
	-- This only seems to hook movement by clicking the middle button, not by 
	-- holding left and right.
	hooksecurefunc( "MoveAndSteerStart", SummonPet )
	-- To hook movement by both buttons, hook them individually
	hooksecurefunc("CameraOrSelectOrMoveStart",CritterCallerLight_LeftButtonDown)
	hooksecurefunc("CameraOrSelectOrMoveStop",CritterCallerLight_LeftButtonUp)
	hooksecurefunc("TurnOrActionStart",CritterCallerLight_RightButtonDown)
	hooksecurefunc("TurnOrActionStop",CritterCallerLight_RightButtonUp)
	
end

local LeftDown = false
local RightDown = false

function CritterCallerLight_LeftButtonUp()
	LeftDown = false
end

function CritterCallerLight_LeftButtonDown()
	LeftDown = true
	if RightDown then
		SummonPet()
	end
end

function CritterCallerLight_RightButtonUp()
	RightDown = false
end

function CritterCallerLight_RightButtonDown()
	RightDown = true
	if LeftDown then
		SummonPet()
	end
end

function CheckForCompanion()

	local petID = C_PetJournal.GetSummonedPetGUID()
	if petID then 
		HasSummoned = true
		SummonedPetIndex = petID
	else 
		HasSummoned = false 
	end	

	if DebugOn then
		PetSummonPrintDebug()
	end
end


local PrintedIntroText = false

function PetSummon_UpdateCompanion( companionType )			
	if companionType == "CRITTER" then
		if SummoningQuestPet then
			SummoningQuestPet = false
			QuestPetSummoned = true
		else
			QuestPetSummoned = false
		end
		CheckForCompanion()
		
	end
	
	if not PrintedIntroText then
		PrintedIntroText = true		
		
		-- Leaving this block because it might be useful
	end
end

function PetSummon_OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if string.upper(loadedAddon) == string.upper(AddonName) then
			PetSummon_OnAddonLoaded()
		elseif string.upper(loadedAddon) == string.upper(OldAddonName) then
			print("WARNING: Cannot have both Critter Caller and Critter Caller Light installed at the same time");
		end
	elseif event == "COMPANION_UPDATE" then		
		PetSummon_UpdateCompanion( ... )
	elseif event == "COMPANION_LEARNED" then		
		CritterCallerLight_RebuildWeightings()
	elseif event == "PLAYER_ENTERING_WORLD" then
		HasSummoned = false
		QuestPetSummoned = false
		PetSummon_UpdateCompanion( "CRITTER" )
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local target, spell = ...
		if target == "player" then
			if PetItemSpells[ spell ] then
				SummoningQuestPet = true
				SummonedPetIndex = spell
			end
		end
	end
	
	local _, numPets = C_PetJournal.GetNumPets(true)
end


function PetSummon_OnLoad() 
	SlashCmdList["CRITTERCALLER"] = CritterCallerSlashCmdFunction
	SLASH_CRITTERCALLER1 = "/crittercaller"
	SLASH_CRITTERCALLER2 = "/ccall"
	
end 

local function isCompanionBanned(companionID)
	-- Ethereal Soul-Trader can't be summoned in arenas and battle grounds
	if companionID == 27914 then
		if IsActiveBattlefieldArena() then
			return true
		end
		
		for bfid=1,GetMaxBattlefieldID(),1 do
			if GetBattlefieldStatus(bfid) == "active" then
				return true
			end
		end
	end
	
	-- Winter Veil only (December 16th - January 2nd)
	if companionID == 15698 or companionID == 73741 or companionID == 15705 then		
		local day = tonumber(date("%d"))
		local month = tonumber(date("%m"))
		if (month == 12 and day >= 16) or (month == 1 and day <= 2) then
			return false
		else
			return true
		end
	end
	
	return false
end

function CritterCallerLight_SummonPetAlways()
	local _, count = C_PetJournal.GetNumPets(true)
	local roll = random()		
	
	AttemptInitialisation()

	weights = NormalisedWeighting
	
	if not weights then
		return
	end
	local totalweight = 0
	for i=1,count,1 do	
		local petID, _, _, _, _, _, _, speciesName, _, _, companionID  = C_PetJournal.GetPetInfoByIndex(i)	
		local issummoned = false
		if C_PetJournal.GetSummonedPetGUID() == petID then
			issummoned = true
		end
		if weights[ petID ] ~= nil then
			totalweight = totalweight + weights[ petID ]			
			
			if totalweight >= roll then		
				if not issummoned and C_PetJournal.PetIsSummonable(petID) and not isCompanionBanned(companionID) then
					--local startTime, duration, isEnabled = GetCompanionCooldown("CRITTER", i)
					-- Avoid the ability not ready yet message; in this 
					-- case a pet won't be summoned until the next movement.
					--if isEnabled == 0 or startTime == 0 then
						C_PetJournal.SummonPetByGUID( petID )
					--end
				end				
				break
			end
		end
	end

	local hour,minute = GetGameTime()

	LastSummonTime = GetTime()
end

function IsTimeForNextSummon()

	if not CritterCallerLightOptions["ResummonTime"] then
		return false
	end
	
	if CritterCallerLightOptions["ResummonTime"] <= 0 then
		return false
	end
	
	local TargetTime = LastSummonTime + CritterCallerLightOptions["ResummonTime"] * 60
	local CurrentTime = GetTime()
	return CurrentTime > TargetTime
end

function ShouldSummon()

	if HasSummoned and not IsTimeForNextSummon() then
		return false
	end
	
	if not CritterCallerLight_Enabled then
		return false
	end
		
	if IsMounted() then
		return false
	end 
		
	if UnitAffectingCombat("player") then
		return false
	end
	
	if QuestPetSummoned then
		return false
	end
	
	if UnitIsDeadOrGhost("player") then
		return false
	end
	
	if IsStealthed() then
		return false
	end
	
	return true
end

function SummonPet()
	if ShouldSummon() then		
		CritterCallerLight_SummonPetAlways()
	end
end

function PetSummonPrintDebug()
	if HasSummoned or QuestPetSummoned then
		print("Summoned: "..SummonedPetIndex );
	else
		print("No pet");
	end
end

function CritterCallerLight_DismissPet()
	local petID = C_PetJournal.GetSummonedPetGUID()
	if petID then
		C_PetJournal.SummonPetByGUID(petID)
	end
end

function CritterCallerSlashCmdFunction( cmd )
	if cmd == "summon" then
		CritterCallerLight_SummonPetAlways()
	elseif cmd == "dismiss" then
		CritterCallerLight_DismissPet()
	elseif cmd == "enable" then
		CritterCallerLight_Enabled = true
		CheckForCompanion()
	elseif cmd == "disable" then
		CritterCallerLight_Enabled = false
	elseif cmd == "debug" then
		PetSummonPrintDebug()
	elseif cmd == "debugon" then
		DebugOn = true		
	elseif cmd == "debugoff" then
		DebugOn = false
	else
		print( "Critter Caller Light summons a random companion pet whenever you move and you don't already have a pet.  The following commands are available:" )
		print( "/ccall summon  Summons a random pet." )
		print( "/ccall dismiss  Dismisses your current pet." )
		print( "/ccall disable  Prevents the summoning of pets." )
		print( "/ccall enable  Enables pet summoning." )
		print( "See readme.txt for more documentation." )
	end
end
