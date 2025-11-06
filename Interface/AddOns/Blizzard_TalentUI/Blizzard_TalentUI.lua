local SpecMapTalentCache;
local SpecMap_TalentCacheEnsureReady;

local function SpecMap_GetTalentTierFromGame(talentGroup, tabIndex, talentId)
	if ( not talentId ) then
		return nil;
	end
	local numTalents = GetNumTalents(tabIndex, false, false);
	for index = 1, numTalents do
		local link = GetTalentLink(tabIndex, index, false, false, talentGroup);
		local linkTalentId = nil;
		if ( type(link) == "string" ) then
			linkTalentId = tonumber(string.match(link, "Htalent:(%d+)") or string.match(link, "talent:(%d+)"));
		end
		if ( linkTalentId == talentId ) then
			local _, _, tier = GetTalentInfo(tabIndex, index, false, false, talentGroup);
			return tier;
		end
	end
	return nil;
end

local function SpecMap_TalentCacheGetDetails(talentGroup, tabIndex, talentId)
	if ( type(SpecMapTalentCache) ~= "table" ) then
		return nil;
	end
	if ( not SpecMap_TalentCacheEnsureReady() ) then
		return nil;
	end
	local specCache = SpecMapTalentCache.specs[talentGroup];
	local tabCache = specCache and specCache.tabs[tabIndex];
	local talentDetails = tabCache and tabCache.talentDetails;
	return talentDetails and talentDetails[talentId] or nil;
end

-- Function to collect and encode talents for learning
local function EncodeTalentLearnMessage(talentGroup)
	if ( not talentGroup or not SpecMap_TalentCacheEnsureReady() ) then
		return nil;
	end
	
	local specCache = SpecMapTalentCache.specs[talentGroup];
	if ( not specCache ) then
		return nil;
	end
	
	-- Collect all talents with their tab, ID, rank, and prerequisite info
	local allTalents = {};
	
	-- Iterate through all tabs
	for tabIndex = 1, MAX_TALENT_TABS do
		local tabCache = specCache.tabs[tabIndex];
		if ( tabCache and tabCache.ranksById ) then
			-- Get all talents in this tab using base game API to get full details
			local numTalents = GetNumTalents(tabIndex, false, false);
			for talentIndex = 1, numTalents do
				local talentLink = GetTalentLink(tabIndex, talentIndex, false, false, talentGroup, false);
				if ( talentLink ) then
					local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
					if ( talentId ) then
						local rank = tabCache.ranksById[talentId] or 0;
						if ( rank > 0 ) then
							-- Get prerequisite info
							local details = SpecMap_TalentCacheGetDetails(talentGroup, tabIndex, talentId);
							local prereqTalentId = details and details.prereqTalentId or nil;
							
							table.insert(allTalents, {
								tabId = tabIndex - 1, -- Convert to 0-based for message
								talentId = talentId,
								rank = rank - 1, -- Convert to 0-based for message
								prereqTalentId = prereqTalentId,
								tabIndex = tabIndex,
								tier = details and details.tier or nil
							});
						end
					end
				end
			end
		end
	end
	
	-- Sort talents: only order prerequisites when they're on the same tier (row)
	-- Build lookup maps
	local talentById = {}; -- Maps talentId -> talent object
	for _, talent in ipairs(allTalents) do
		talentById[talent.talentId] = talent;
	end
	
	-- Sort talents: prerequisites come before dependents only if they're on the same tier
	table.sort(allTalents, function(a, b)
		-- Check if b requires a (a is prerequisite of b) and they're on the same tier
		if ( b.prereqTalentId and b.prereqTalentId == a.talentId and a.tier == b.tier ) then
			return true; -- a comes before b
		end
		-- Check if a requires b (b is prerequisite of a) and they're on the same tier
		if ( a.prereqTalentId and a.prereqTalentId == b.talentId and a.tier == b.tier ) then
			return false; -- b comes before a
		end
		-- Otherwise, sort by tier first, then by tab
		if ( a.tier ~= b.tier ) then
			return (a.tier or 0) < (b.tier or 0);
		end
		return a.tabIndex < b.tabIndex;
	end);
	
	local sortedTalents = allTalents;
	
	-- Encode the message
	local messageParts = {};
	for _, talent in ipairs(sortedTalents) do
		table.insert(messageParts, string.format("%d:%d", talent.talentId, talent.rank));
	end
	
	return table.concat(messageParts, ",");
end

StaticPopupDialogs["CONFIRM_LEARN_PREVIEW_TALENTS"] = {
	text = CONFIRM_LEARN_PREVIEW_TALENTS,
	button1 = YES,
	button2 = NO,
	OnAccept = function (self)
		local talentGroup = PlayerTalentFrame.talentGroup;
		if ( not talentGroup ) then
			return;
		end
		
		-- Encode talents for learning
		local encodedMessage = EncodeTalentLearnMessage(talentGroup);
		if ( encodedMessage and encodedMessage ~= "" ) then
			-- Send message to server
			-- Format: OPCODE|encodedTalents
			-- Example: 8|LEARN|1|0:123:2,0:456:3,1:789:1
			local learnOpCode = 9; -- Learn talents opcode (adjust if needed)
			local fullMessage = string.format("%d|%s", learnOpCode, encodedMessage);
			PushMessageToServer(fullMessage);
		end
	end,
	OnCancel = function (self)
	end,
	hideOnEscape = 1,
	timeout = 0,
	exclusive = 1,
}

UIPanelWindows["PlayerTalentFrame"] = { area = "center", pushable = 0, whileDead = 1 };


-- global constants
GLYPH_TALENT_TAB = 4;

-- speed references
local next = next;
local ipairs = ipairs;

-- local data
local specs = {
	["spec1"] = {
		name = TALENT_SPEC_PRIMARY,
		talentGroup = 1,
		unit = "player",
		pet = false,
		tooltip = TALENT_SPEC_PRIMARY,
		portraitUnit = "player",
		defaultSpecTexture = "Interface\\Icons\\Ability_Marksmanship",
		hasGlyphs = true,
		glyphName = TALENT_SPEC_PRIMARY_GLYPH,
	},
	["spec2"] = {
		name = TALENT_SPEC_SECONDARY,
		talentGroup = 2,
		unit = "player",
		pet = false,
		tooltip = TALENT_SPEC_SECONDARY,
		portraitUnit = "player",
		defaultSpecTexture = "Interface\\Icons\\Ability_Marksmanship",
		hasGlyphs = true,
		glyphName = TALENT_SPEC_SECONDARY_GLYPH,
	},
	["petspec1"] = {
		name = TALENT_SPEC_PET_PRIMARY,
		talentGroup = 1,
		unit = "pet",
		tooltip = TALENT_SPEC_PET_PRIMARY,
		pet = true,
		portraitUnit = "pet",
		defaultSpecTexture = nil,
		hasGlyphs = false,
		glyphName = nil,
	},
};

local specTabs = { };	-- filled in by PlayerSpecTab_OnLoad
local numSpecTabs = 0;
selectedSpec = nil;
activeSpec = nil;

-- Numeric spec values for dropdown control (talent group indices)
selectedSpecNumber = nil;
activeSpecNumber = nil;

-- Helper function to get ordinal spec name
local function GetOrdinalSpecName(specIndex)
	local ordinalNames = {
		[1] = "Primary Specialization",
		[2] = "Secondary Specialization",
		[3] = "Tertiary Specialization",
		[4] = "Quaternary Specialization",
		[5] = "Quinary Specialization",
		[6] = "Senary Specialization",
		[7] = "Septenary Specialization",
		[8] = "Octonary Specialization",
		[9] = "Nonary Specialization",
	};
	return ordinalNames[specIndex] or ("Spec " .. specIndex);
end


-- cache talent info so we can quickly display cool stuff like the number of points spent in each tab
local talentSpecInfoCache = {
	["spec1"]		= { },
	["spec2"]		= { },
	["petspec1"]	= { },
};
-- cache talent tab widths so we can resize tabs to fit for localization
local talentTabWidthCache = { };



-- ACTIVESPEC_DISPLAYTYPE values:
-- "BLUE", "GOLD_INSIDE", "GOLD_BACKGROUND"
local ACTIVESPEC_DISPLAYTYPE = nil;

-- SELECTEDSPEC_DISPLAYTYPE values:
-- "BLUE", "GOLD_INSIDE", "PUSHED_OUT", "PUSHED_OUT_CHECKED"
local SELECTEDSPEC_DISPLAYTYPE = "GOLD_INSIDE";
local SELECTEDSPEC_OFFSETX;
if ( SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT" or SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT_CHECKED" ) then
	SELECTEDSPEC_OFFSETX = 5;
else
	SELECTEDSPEC_OFFSETX = 0;
end


local function GetSpecMapTable()
	if ( type(SpecMap) == "table" ) then
		return SpecMap;
	end
	return nil;
end

local function GetSpecMapSpecData(talentGroup)
	local specMap = GetSpecMapTable();
	if ( specMap and type(specMap.specs) == "table" and type(talentGroup) == "number" ) then
		return specMap.specs[talentGroup];
	end
	return nil;
end

SpecMapTalentCache = {
	specs = {},
	ready = false,
	freeTalents = nil,
};

-- Glyph socket cache
SpecMapGlyphCache = {
	ready = false,
	socketEnabled = {}, -- [slotIndex] = enabled
};

local function SpecMap_ResetTalentCache()
	for key in pairs(SpecMapTalentCache.specs) do
		SpecMapTalentCache.specs[key] = nil;
	end
	SpecMapTalentCache.ready = false;
	SpecMapTalentCache.freeTalents = nil;
end

function SpecMap_BuildTalentCache()
	SpecMap_ResetTalentCache();
	local specMap = GetSpecMapTable();
	if ( not specMap or type(specMap.specs) ~= "table" ) then
		return;
	end
	if ( type(specMap.freeTalents) == "number" ) then
		SpecMapTalentCache.freeTalents = specMap.freeTalents;
	end
	for specIndex, specData in ipairs(specMap.specs) do
		local cacheSpec = { tabs = {} };
		SpecMapTalentCache.specs[specIndex] = cacheSpec;
		if ( type(specData.talents) == "table" ) then
			for _, talentData in ipairs(specData.talents) do
				local tabId = tonumber(talentData.tabId or talentData.tab or talentData.tabIndex);
				local talentId = tonumber(talentData.talentId or talentData.id or talentData.talentIndex);
				local rankIndex = tonumber(talentData.rank);
				-- Initialize details for all talents, even those with rank 0 or nil (for prerequisite checking)
				if ( tabId and talentId ) then
					tabId = tabId + 1;
					local tabCache = cacheSpec.tabs[tabId];
					if ( not tabCache ) then
						tabCache = {
							ranksById = {},
							pointsSpent = 0,
							talentDetails = {},
						};
						cacheSpec.tabs[tabId] = tabCache;
					end
					-- Always initialize talent details (prerequisite info will be populated from base game API below)
					if ( not tabCache.talentDetails[talentId] ) then
						tabCache.talentDetails[talentId] = {
							tier = tonumber(talentData.tier) or tonumber(talentData.row),
							prereqTalentId = nil,
							prereqRank = nil,
						};
					end
					-- Set rank if rankIndex is provided
					if ( rankIndex ~= nil ) then
						local displayRank = rankIndex + 1;
						if ( displayRank < 0 ) then
							displayRank = 0;
						end
						tabCache.ranksById[talentId] = displayRank;
						if ( displayRank > 0 ) then
							tabCache.pointsSpent = tabCache.pointsSpent + displayRank;
						end
					end
				end
			end
		end
	end
	
	-- Populate talentDetails for ALL talents in the tree using base game API
	-- This ensures prerequisite checking works even for talents not in the decoded message
	for specIndex, cacheSpec in pairs(SpecMapTalentCache.specs) do
		local talentGroup = specIndex;
		-- Iterate through all talent tabs (1-3 for player talents)
		for tabId = 1, MAX_TALENT_TABS do
			local tabCache = cacheSpec.tabs[tabId];
			if ( not tabCache ) then
				tabCache = {
					ranksById = {},
					pointsSpent = 0,
					talentDetails = {},
				};
				cacheSpec.tabs[tabId] = tabCache;
			end
			if ( not tabCache.talentDetails ) then
				tabCache.talentDetails = {};
			end
			
			-- Get all talents in this tab using base game API
			local numTalents = GetNumTalents(tabId, false, false);
			for talentIndex = 1, numTalents do
				local talentLink = GetTalentLink(tabId, talentIndex, false, false, talentGroup, false);
				if ( talentLink ) then
					local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
					if ( talentId ) then
						-- Get talent info
						local name, iconTexture, tier, column = GetTalentInfo(tabId, talentIndex, false, false, talentGroup);
						
						-- Initialize or get existing details
						local details = tabCache.talentDetails[talentId];
						if ( not details ) then
							details = {
								tier = tier,
								prereqTalentId = nil,
								prereqRank = nil,
							};
							tabCache.talentDetails[talentId] = details;
						end
						
						-- Update tier if not set
						if ( not details.tier and tier ) then
							details.tier = tier;
						end
						
						-- Get prerequisite information
						local prereqTier, prereqColumn = GetTalentPrereqs(tabId, talentIndex, false, false, talentGroup);
						if ( prereqTier and prereqColumn ) then
							-- Find the prerequisite talent at this tier/column
							local prereqTalentIndex = nil;
							for i = 1, numTalents do
								local prereqName, prereqIcon, prereqTierCheck, prereqColumnCheck = GetTalentInfo(tabId, i, false, false, talentGroup);
								if ( prereqTierCheck == prereqTier and prereqColumnCheck == prereqColumn ) then
									prereqTalentIndex = i;
									break;
								end
							end
							
							-- Get the prerequisite talent ID and max rank
							if ( prereqTalentIndex ) then
								local prereqTalentLink = GetTalentLink(tabId, prereqTalentIndex, false, false, talentGroup, false);
								if ( prereqTalentLink ) then
									local prereqTalentId = SpecMap_TalentCacheExtractTalentID(prereqTalentLink);
									local _, _, _, _, _, maxRank = GetTalentInfo(tabId, prereqTalentIndex, false, false, talentGroup);
									
									-- Store prerequisite info (required rank is always the max rank)
									if ( prereqTalentId and maxRank ) then
										details.prereqTalentId = prereqTalentId;
										details.prereqRank = maxRank; -- Required rank is always the maximum rank
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	SpecMapTalentCache.ready = true;
end

function SpecMap_TalentCacheIsReady()
	return SpecMapTalentCache.ready;
end

SpecMap_TalentCacheEnsureReady = function()
	if ( SpecMapTalentCache.ready ) then
		return true;
	end
	SpecMap_BuildTalentCache();
	return SpecMapTalentCache.ready;
end

local function SpecMap_TalentCacheGetSpec(talentGroup)
	if ( not SpecMapTalentCache.ready ) then
		return nil;
	end
	return SpecMapTalentCache.specs[talentGroup];
end

function SpecMap_TalentCacheGetFreeTalents()
	if ( not SpecMapTalentCache.ready ) then
		return nil;
	end
	return SpecMapTalentCache.freeTalents;
end

function SpecMap_TalentCacheGetTabPoints(talentGroup, tabIndex)
	local specCache = SpecMap_TalentCacheGetSpec(talentGroup);
	if ( not specCache ) then
		return nil, nil;
	end
	local tabCache = specCache.tabs[tabIndex];
	if ( not tabCache ) then
		return 0, nil;
	end
	return tabCache.pointsSpent or 0, nil;
end

function SpecMap_TalentCacheGetRank(talentGroup, tabIndex, talentId)
	local specCache = SpecMap_TalentCacheGetSpec(talentGroup);
	if ( not specCache ) then
		return 0;
	end
	local tabCache = specCache.tabs[tabIndex];
	if ( not tabCache ) then
		return 0;
	end
	if ( talentId and tabCache.ranksById[talentId] ~= nil ) then
		return tabCache.ranksById[talentId];
	end
	return 0;
end

-- Get the base spec map rank (from decoded message, before any user changes)
function SpecMap_GetBaseTalentRank(talentGroup, tabIndex, talentId)
	local spec = GetSpecMapSpecData(talentGroup);
	if ( not spec or type(spec.talents) ~= "table" ) then
		return 0;
	end
	for _, talentInfo in ipairs(spec.talents) do
		local specTabId = talentInfo.tabId or talentInfo.tab or talentInfo.tabIndex;
		local specTalentId = talentInfo.talentId or talentInfo.id or talentInfo.talentIndex;
		if ( type(specTabId) == "number" and type(specTalentId) == "number" ) then
			-- Convert tab ID from 0-based to 1-based if needed
			local tabMatches = (specTabId == tabIndex) or (specTabId + 1 == tabIndex);
			-- Check if talent ID matches
			if ( tabMatches and specTalentId == talentId ) then
				local rank = talentInfo.rank;
				if ( type(rank) == "number" ) then
					-- Convert from 0-based to 1-based
					if ( rank >= 0 ) then
						return rank + 1;
					else
						return 0;
					end
				end
				return 0;
			end
		end
	end
	return 0;
end

-- Get rank across all tabs (for prerequisites that might be in different tabs)
local function SpecMap_TalentCacheGetRankAnyTab(talentGroup, talentId)
	local specCache = SpecMap_TalentCacheGetSpec(talentGroup);
	if ( not specCache or not talentId ) then
		return 0;
	end
	-- Search all tabs
	for tabIndex, tabCache in pairs(specCache.tabs or {}) do
		if ( tabCache and tabCache.ranksById and tabCache.ranksById[talentId] ~= nil ) then
			return tabCache.ranksById[talentId];
		end
	end
	return 0;
end

function SpecMap_TalentCacheSumTabPoints(talentGroup, tabIndex)
	local specCache = SpecMap_TalentCacheGetSpec(talentGroup);
	if ( not specCache ) then
		return nil;
	end
	local tabCache = specCache.tabs[tabIndex];
	if ( not tabCache ) then
		return 0;
	end
	return tabCache.pointsSpent or 0;
end


local function SpecMap_TalentCacheBuildTierTotals(talentGroup, tabIndex, pendingTalentId, pendingDelta)
	local totals = {};
	if ( not SpecMap_TalentCacheEnsureReady() ) then
		return totals;
	end
	local specCache = SpecMapTalentCache.specs[talentGroup];
	local tabCache = specCache and specCache.tabs[tabIndex];
	if ( not tabCache ) then
		return totals;
	end
	local talentDetails = tabCache.talentDetails or {};
	for talentId, rank in pairs(tabCache.ranksById or {}) do
		local tierInfo = talentDetails[talentId];
		local tier = tierInfo and tierInfo.tier;
		if ( not tier ) then
			tier = SpecMap_GetTalentTierFromGame(talentGroup, tabIndex, talentId) or 1;
			tabCache.talentDetails = tabCache.talentDetails or {};
			tabCache.talentDetails[talentId] = tabCache.talentDetails[talentId] or {};
			tabCache.talentDetails[talentId].tier = tier;
		end
		if ( pendingTalentId and talentId == pendingTalentId and pendingDelta ) then
			rank = math.max(0, rank + pendingDelta);
		end
		if ( rank and rank > 0 ) then
			totals[tier] = (totals[tier] or 0) + rank;
		end
	end
	return totals;
end

function SpecMap_TalentCacheIsTalentAvailable(talentGroup, tabIndex, talentId, tier)
	if ( not SpecMap_TalentCacheEnsureReady() ) then
		return true;
	end
	if ( not talentId ) then
		return true;
	end
	local specCache = SpecMapTalentCache.specs[talentGroup];
	local tabCache = specCache and specCache.tabs[tabIndex];
	if ( not tabCache ) then
		return true;
	end
	local talentDetails = tabCache.talentDetails or {};
	local details = talentDetails[talentId];
	
	-- If details don't exist, try to load them from SpecMap source data
	if ( not details ) then
		local specMap = GetSpecMapTable();
		if ( specMap and type(specMap.specs) == "table" and specMap.specs[talentGroup] ) then
			local specData = specMap.specs[talentGroup];
			if ( type(specData.talents) == "table" ) then
				for _, talentData in ipairs(specData.talents) do
					local dataTabId = tonumber(talentData.tabId or talentData.tab or talentData.tabIndex);
					local dataTalentId = tonumber(talentData.talentId or talentData.id or talentData.talentIndex);
					if ( dataTabId and dataTalentId and dataTabId + 1 == tabIndex and dataTalentId == talentId ) then
						-- Found the talent in SpecMap, create details
						-- Prerequisite info will be populated from base game API in SpecMap_BuildTalentCache
						tabCache.talentDetails = tabCache.talentDetails or {};
						details = {
							tier = tonumber(talentData.tier) or tonumber(talentData.row),
							prereqTalentId = nil,
							prereqRank = nil,
						};
						tabCache.talentDetails[talentId] = details;
						break;
					end
				end
			end
		end
		-- If still no details, create empty details structure
		if ( not details ) then
			tabCache.talentDetails = tabCache.talentDetails or {};
			details = {};
			tabCache.talentDetails[talentId] = details;
		end
	end

	local pointsPerTier = PLAYER_TALENTS_PER_TIER or 5;
	if ( tier and tier > 1 ) then
		local tierTotals = SpecMap_TalentCacheBuildTierTotals(talentGroup, tabIndex);
		local cumulative = 0;
		for i = 1, tier - 1 do
			cumulative = cumulative + (tierTotals[i] or 0);
		end
		local requiredPoints = (tier - 1) * pointsPerTier;
		if ( cumulative < requiredPoints ) then
			return false;
		end
	end
	
	-- Check prerequisite requirement
	-- Only check if we have both a prerequisite talent ID and a required rank
	local prereqTalentId = details.prereqTalentId;
	local requiredRank = details.prereqRank;
	if ( prereqTalentId and prereqTalentId > 0 and requiredRank ~= nil and requiredRank > 0 ) then
		-- Get actual current rank from cache (reflects user changes)
		-- Try current tab first, then search all tabs
		local prereqRank = SpecMap_TalentCacheGetRank(talentGroup, tabIndex, prereqTalentId) or 0;
		if ( prereqRank < requiredRank ) then
			return false;
		end
	elseif ( prereqTalentId and prereqTalentId > 0 ) then
		-- We have a prerequisite talent but no required rank specified
		-- This is a warning case, but we'll allow it
	else
		-- No prerequisites
	end
	return true;
end

function SpecMap_TalentCacheCheckPrereqs(talentGroup, tabIndex, talentId, tier)
	if ( not talentId ) then
		return true;
	end
	if ( not SpecMap_TalentCacheEnsureReady() ) then
		return true;
	end
	if (SpecMapTalentCache) then
		local specCache = SpecMapTalentCache.specs[talentGroup];
		local tabCache = specCache and specCache.tabs[tabIndex];
		if ( not tabCache ) then
			return true;
		end
		-- Ensure details are initialized (SpecMap_TalentCacheIsTalentAvailable will handle this)
		-- but we can also try to get them first
		local details = SpecMap_TalentCacheGetDetails(talentGroup, tabIndex, talentId);
		if ( not details ) then
			-- Try to load from SpecMap
			local specMap = GetSpecMapTable();
			if ( specMap and type(specMap.specs) == "table" and specMap.specs[talentGroup] ) then
				local specData = specMap.specs[talentGroup];
				if ( type(specData.talents) == "table" ) then
					for _, talentData in ipairs(specData.talents) do
						local dataTabId = tonumber(talentData.tabId or talentData.tab or talentData.tabIndex);
						local dataTalentId = tonumber(talentData.talentId or talentData.id or talentData.talentIndex);
						if ( dataTabId and dataTalentId and dataTabId + 1 == tabIndex and dataTalentId == talentId ) then
							tabCache.talentDetails = tabCache.talentDetails or {};
							details = {
								tier = tonumber(talentData.tier) or tonumber(talentData.row),
								prereqTalentId = nil,
								prereqRank = nil,
							};
							tabCache.talentDetails[talentId] = details;
							-- Populate prerequisite info from base game API
							local talentIndex = nil;
							local numTalents = GetNumTalents(tabIndex, false, false);
							for i = 1, numTalents do
								local talentLink = GetTalentLink(tabIndex, i, false, false, talentGroup, false);
								if ( talentLink ) then
									local linkTalentId = SpecMap_TalentCacheExtractTalentID(talentLink);
									if ( linkTalentId == talentId ) then
										talentIndex = i;
										break;
									end
								end
							end
							if ( talentIndex ) then
								local prereqTier, prereqColumn = GetTalentPrereqs(tabIndex, talentIndex, false, false, talentGroup);
								if ( prereqTier and prereqColumn ) then
									local prereqTalentIndex = nil;
									for i = 1, numTalents do
										local name, iconTexture, tier, col = GetTalentInfo(tabIndex, i, false, false, talentGroup);
										if ( tier == prereqTier and col == prereqColumn ) then
											prereqTalentIndex = i;
											break;
										end
									end
									if ( prereqTalentIndex ) then
										local prereqTalentLink = GetTalentLink(tabIndex, prereqTalentIndex, false, false, talentGroup, false);
										if ( prereqTalentLink ) then
											local prereqTalentId = SpecMap_TalentCacheExtractTalentID(prereqTalentLink);
											local _, _, _, _, _, maxRank = GetTalentInfo(tabIndex, prereqTalentIndex, false, false, talentGroup);
											if ( prereqTalentId and maxRank ) then
												details.prereqTalentId = prereqTalentId;
												details.prereqRank = maxRank; -- Required rank is always the maximum rank
											end
										end
									end
								end
							end
							break;
						end
					end
				end
			end
		end
		if ( details and details.tier and details.tier ~= tier ) then
			tier = details.tier;
		end
		if ( not SpecMap_TalentCacheIsTalentAvailable(talentGroup, tabIndex, talentId, tier) ) then
			return false;
		end
	end
	return true;
end

function SpecMap_TalentCacheCanDerank(talentGroup, tabIndex, talentId, currentTier)
	if ( not SpecMap_TalentCacheEnsureReady() ) then
		return false;
	end
	local specCache = SpecMapTalentCache.specs[talentGroup];
	if ( not specCache ) then
		return true;
	end
	local tabCache = specCache.tabs[tabIndex];
	if ( not tabCache ) then
		return true;
	end
	local ranksById = tabCache.ranksById or {};
	if ( (ranksById[talentId] or 0) <= 0 ) then
		return false;
	end
	local currentTierInfo = tabCache.talentDetails and tabCache.talentDetails[talentId];
	local newRankValue = (ranksById[talentId] or 0) - 1;
	local pendingDelta = newRankValue >= 0 and (newRankValue - (ranksById[talentId] or 0)) or - (ranksById[talentId] or 0);
	local tierTotals = SpecMap_TalentCacheBuildTierTotals(talentGroup, tabIndex, talentId, pendingDelta);
	local pointsPerTier = PLAYER_TALENTS_PER_TIER or 5;
	local tiers = {};
	for tier in pairs(tierTotals) do
		table.insert(tiers, tier);
	end
	table.sort(tiers);
	local cumulative = 0;
	for _, tier in ipairs(tiers) do
		local tierPoints = tierTotals[tier];
		if ( tierPoints and tierPoints > 0 ) then
			if ( tier > 1 ) then
				local requiredPoints = (tier - 1) * pointsPerTier;
				if ( cumulative < requiredPoints ) then
					return false;
				end
			end
			cumulative = cumulative + tierPoints;
		end
	end
	return true;
end

function SpecMap_TalentCacheCountHigherTierRanks(talentGroup, tabIndex, tierThreshold)
	local specCache = SpecMap_TalentCacheGetSpec(talentGroup);
	if ( not specCache ) then
		return 0;
	end
	local tabCache = specCache.tabs[tabIndex];
	if ( not tabCache ) then
		return 0;
	end
	local total = 0;
	for talentId, rank in pairs(tabCache.ranksById or {}) do
		local talentInfo = tabCache.talentDetails and tabCache.talentDetails[talentId];
		if ( talentInfo and talentInfo.tier and talentInfo.tier > tierThreshold ) then
			total = total + rank;
		end
	end
	return total;
end

local function SpecMap_TalentCacheApplyTabPoints(talentGroup, tabIndex, pointsSpent, previewPointsSpent)
	local cachePoints, cachePreview = SpecMap_TalentCacheGetTabPoints(talentGroup, tabIndex);
	if ( cachePoints ~= nil ) then
		pointsSpent = cachePoints;
	end
	if ( cachePreview ~= nil ) then
		previewPointsSpent = cachePreview;
	end
	return pointsSpent, previewPointsSpent;
end

function SpecMap_TalentCacheAdjustRank(talentGroup, tabIndex, talentId, delta, maxRank, tier)
	if ( not talentGroup or not tabIndex or not talentId or delta == 0 ) then
		return false;
	end
	if ( not SpecMap_TalentCacheEnsureReady() ) then
		return false;
	end
	local specCache = SpecMapTalentCache.specs[talentGroup];
	if ( not specCache ) then
		specCache = { tabs = {} };
		SpecMapTalentCache.specs[talentGroup] = specCache;
	end
	local tabCache = specCache.tabs[tabIndex];
	if ( not tabCache ) then
		tabCache = { ranksById = {}, pointsSpent = 0, talentDetails = {} };
		specCache.tabs[tabIndex] = tabCache;
	end
	local currentRank = tabCache.ranksById[talentId] or 0;
	local newRank = currentRank + delta;
	if ( maxRank ) then
		if ( delta > 0 and newRank > maxRank ) then
			newRank = maxRank;
		elseif ( delta < 0 and newRank > maxRank ) then
			newRank = maxRank;
		end
	end
	if ( newRank < 0 ) then
		newRank = 0;
	end
	if ( newRank == currentRank ) then
		return false;
	end
	if ( newRank == 0 ) then
		tabCache.ranksById[talentId] = nil;
	else
		tabCache.ranksById[talentId] = newRank;
	end
	local deltaApplied = newRank - currentRank;
	tabCache.pointsSpent = math.max(0, (tabCache.pointsSpent or 0) + deltaApplied);
	if ( SpecMapTalentCache.freeTalents ~= nil ) then
		SpecMapTalentCache.freeTalents = math.max(0, SpecMapTalentCache.freeTalents - deltaApplied);
	end
	-- Always ensure talent details are initialized
	tabCache.talentDetails = tabCache.talentDetails or {};
	local details = tabCache.talentDetails[talentId];
	if ( not details ) then
		-- Try to load details from SpecMap
		local specMap = GetSpecMapTable();
		if ( specMap and type(specMap.specs) == "table" and specMap.specs[talentGroup] ) then
			local specData = specMap.specs[talentGroup];
			if ( type(specData.talents) == "table" ) then
				for _, talentData in ipairs(specData.talents) do
					local dataTabId = tonumber(talentData.tabId or talentData.tab or talentData.tabIndex);
					local dataTalentId = tonumber(talentData.talentId or talentData.id or talentData.talentIndex);
					if ( dataTabId and dataTalentId and dataTabId + 1 == tabIndex and dataTalentId == talentId ) then
						-- Prerequisite info will be populated from base game API in SpecMap_BuildTalentCache
						details = {
							tier = tonumber(talentData.tier) or tonumber(talentData.row),
							prereqTalentId = nil,
							prereqRank = nil,
						};
						tabCache.talentDetails[talentId] = details;
						break;
					end
				end
			end
		end
		-- If still no details, create empty structure
		if ( not details ) then
			details = {};
			tabCache.talentDetails[talentId] = details;
		end
	end
	-- Update tier if provided
	if ( tier ) then
		details.tier = tier;
	end
	return true;
end

function SpecMap_TalentCacheExtractTalentID(link)
	if ( type(link) ~= "string" ) then
		return nil;
	end
	local talentId = link:match("Htalent:(%d+)") or link:match("talent:(%d+)");
	if ( talentId ) then
		return tonumber(talentId);
	end
	return nil;
end

function SpecMap_GetTalentGroupCount()
	local specMap = GetSpecMapTable();
	if ( specMap ) then
		local count = specMap.specCount;
		if ( type(count) == "number" and count > 0 ) then
			return count;
		end
	end
	return 1;
end

function SpecMap_GetActiveTalentGroup()
	local count = SpecMap_GetTalentGroupCount();
	local specMap = GetSpecMapTable();
	if ( specMap ) then
		local active = specMap.activeSpec;
		if ( type(active) == "number" ) then
			return (active % count) + 1;
		end
	end
	return 1;
end

function SpecMap_GetFreeTalentPoints()
	local cached = SpecMap_TalentCacheGetFreeTalents();
	if ( cached ~= nil ) then
		return cached;
	end
	local specMap = GetSpecMapTable();
	if ( specMap ) then
		local freeTalents = specMap.freeTalents;
		if ( type(freeTalents) == "number" ) then
			return freeTalents;
		end
	end
	return 0;
end

function SpecMap_HasCacheChanges(talentGroup)
	if ( not talentGroup ) then
		return false;
	end
	if ( not SpecMap_TalentCacheEnsureReady() ) then
		return false;
	end
	local specMap = GetSpecMapTable();
	if ( not specMap or type(specMap.specs) ~= "table" ) then
		return false;
	end
	local specData = specMap.specs[talentGroup];
	if ( not specData or type(specData.talents) ~= "table" ) then
		return false;
	end
	local specCache = SpecMapTalentCache.specs[talentGroup];
	if ( not specCache ) then
		return true;
	end
	-- Check talent ranks
	for _, talentInfo in ipairs(specData.talents) do
		local tabId = tonumber(talentInfo.tabId or talentInfo.tab or talentInfo.tabIndex);
		local talentId = tonumber(talentInfo.talentId or talentInfo.id or talentInfo.talentIndex);
		local rankIndex = tonumber(talentInfo.rank);
		if ( tabId and talentId and rankIndex ~= nil ) then
			tabId = tabId + 1;
			local displayRank = rankIndex + 1;
			if ( displayRank < 0 ) then
				displayRank = 0;
			end
			local tabCache = specCache.tabs[tabId];
			local cachedRank = tabCache and (tabCache.ranksById[talentId] or 0) or 0;
			if ( cachedRank ~= displayRank ) then
				return true;
			end
		end
	end
	-- Check cached talents that might not be in SpecMap (user added them)
	for tabIndex, tabCache in pairs(specCache.tabs or {}) do
		if ( tabCache.ranksById ) then
			for talentId, cachedRank in pairs(tabCache.ranksById) do
				if ( cachedRank > 0 ) then
					-- Check if this talent exists in SpecMap with the same rank
					local found = false;
					for _, talentInfo in ipairs(specData.talents) do
						local dataTabId = tonumber(talentInfo.tabId or talentInfo.tab or talentInfo.tabIndex);
						local dataTalentId = tonumber(talentInfo.talentId or talentInfo.id or talentInfo.talentIndex);
						local rankIndex = tonumber(talentInfo.rank);
						if ( dataTabId and dataTalentId and dataTabId + 1 == tabIndex and dataTalentId == talentId ) then
							local displayRank = rankIndex + 1;
							if ( displayRank < 0 ) then
								displayRank = 0;
							end
							if ( cachedRank == displayRank ) then
								found = true;
							end
							break;
						end
					end
					if ( not found ) then
						return true;
					end
				end
			end
		end
	end
	return false;
end

-- Glyph DBC index to spell ID lookup table
-- This can be populated manually or from server data if needed
-- Format: [glyphDBCIndex] = spellID
SpecMapGlyphIndexToSpellID = SpecMapGlyphIndexToSpellID or {};

-- Convert glyph DBC index to spell ID
-- In WoW 3.3.5a, glyphs are stored in GlyphProperties DBC and we need to get the spell ID
-- The GlyphProperties DBC has a field that maps glyph ID to spell ID
local function GetGlyphSpellFromIndex(glyphIndex)
	if ( not glyphIndex or glyphIndex <= 0 ) then
		return nil;
	end
	
	-- First, check if we have a lookup table entry
	if ( SpecMapGlyphIndexToSpellID[glyphIndex] ) then
		return SpecMapGlyphIndexToSpellID[glyphIndex];
	end
	
	-- Try GetGlyphInfo first (if available in this version)
	if ( type(GetGlyphInfo) == "function" ) then
		local spellID = GetGlyphInfo(glyphIndex);
		if ( spellID and spellID > 0 ) then
			-- Cache it for future use
			SpecMapGlyphIndexToSpellID[glyphIndex] = spellID;
			return spellID;
		end
	end
	
	-- As a fallback, try using GetSpellInfo with the glyph index
	-- Sometimes the glyph index might actually be the spell ID
	local name, _, icon = GetSpellInfo(glyphIndex);
	if ( name ) then
		-- If GetSpellInfo returns a result, the glyph index might actually be the spell ID
		SpecMapGlyphIndexToSpellID[glyphIndex] = glyphIndex;
		return glyphIndex;
	end
	
	-- If all else fails, return nil
	-- The caller should handle this case appropriately
	return nil;
end

function SpecMap_GetGlyphSpell(talentGroup, slotIndex)
	local spec = GetSpecMapSpecData(talentGroup);
	if ( spec and type(spec.glyphs) == "table" and type(slotIndex) == "number" ) then
		local glyphEntry = spec.glyphs[slotIndex];
		if ( glyphEntry ) then
			-- Check if glyphEntry is a table with glyphId and spellId
			if ( type(glyphEntry) == "table" and glyphEntry.spellId ) then
				-- Use the spell ID directly from the decoded data
				return glyphEntry.spellId;
			elseif ( type(glyphEntry) == "number" and glyphEntry > 0 ) then
				-- Backward compatibility: convert glyph DBC index to spell ID
				local spellID = GetGlyphSpellFromIndex(glyphEntry);
				return spellID;
			elseif ( type(glyphEntry) == "table" and glyphEntry.glyphId ) then
				-- Has glyph ID but no spell ID, need to convert
				local spellID = GetGlyphSpellFromIndex(glyphEntry.glyphId);
				return spellID;
			end
		end
	end
	return nil;
end

-- Get glyph icon ID from SpecMap
function SpecMap_GetGlyphIconId(talentGroup, slotIndex)
	local spec = GetSpecMapSpecData(talentGroup);
	if ( spec and type(spec.glyphs) == "table" and type(slotIndex) == "number" ) then
		local glyphEntry = spec.glyphs[slotIndex];
		if ( glyphEntry and type(glyphEntry) == "table" and glyphEntry.iconId ) then
			return glyphEntry.iconId;
		end
	end
	return nil;
end

-- Convert icon ID to icon texture path
-- In WoW, icon IDs map to icon textures in Interface\Icons
-- Note: This function may need to be implemented based on your server's icon system
-- For now, we'll rely on GetSpellInfo which should return the correct icon path
function SpecMap_GetIconPathFromId(iconId)
	if ( not iconId or iconId <= 0 ) then
		return nil;
	end
	
	-- In WoW 3.3.5a, icon IDs can be used to construct texture paths
	-- However, the exact mapping depends on the icon DBC file
	-- For now, we'll return nil and let GetSpellInfo handle icon retrieval
	-- The icon ID is stored in the glyph data for reference/verification
	
	-- If you need to implement icon ID to path conversion, you would need:
	-- 1. Access to the icon DBC file mapping
	-- 2. Or a lookup table mapping icon IDs to texture paths
	-- 3. Or use a server-side API that provides the icon path
	
	return nil;
end

-- Determine if a glyph socket should be enabled based on player level
-- Base WoW 3.3.5 unlock pattern:
-- Level 15: 1 Major (slot 1), 1 Minor (slot 2)
-- Level 30: 2 Major (slot 4)
-- Level 50: 2 Minor (slot 3)
-- Level 70: 3 Minor (slot 5)
-- Level 80: 3 Major (slot 6)
function SpecMap_GetGlyphSocketUnlockLevel(slotIndex)
	if ( not slotIndex or slotIndex < 1 or slotIndex > NUM_GLYPH_SLOTS ) then
		return 80; -- Default to max level if unknown
	end
	
	-- Base WoW 3.3.5 unlock levels for each slot
	local unlockLevels = {
		[1] = 15, -- Major glyph slot 1
		[2] = 15, -- Minor glyph slot 1
		[3] = 50, -- Minor glyph slot 2
		[4] = 30, -- Major glyph slot 2
		[5] = 70, -- Minor glyph slot 3
		[6] = 80, -- Major glyph slot 3
	};
	
	return unlockLevels[slotIndex] or 80;
end

-- Get glyph type (1=Major, 2=Minor) for a slot
-- Indices 1, 4, 6 = Major, Indices 2, 3, 5 = Minor
local function SpecMap_GetGlyphSocketType(slotIndex)
	if ( not slotIndex or slotIndex < 1 ) then
		return 1; -- Default to Major
	end
	
	-- Indices 1, 4, 6 are Major glyphs
	if ( slotIndex == 1 or slotIndex == 4 or slotIndex == 6 ) then
		return 1; -- Major
	else
		-- Indices 2, 3, 5 are Minor glyphs
		return 2; -- Minor
	end
end

function SpecMap_BuildGlyphCache()
	SpecMapGlyphCache.ready = false;
	SpecMapGlyphCache.socketEnabled = {};
	
	-- Get player level
	local playerLevel = UnitLevel("player");
	
	-- Check each socket slot
	for slotIndex = 1, NUM_GLYPH_SLOTS do
		local unlockLevel = SpecMap_GetGlyphSocketUnlockLevel(slotIndex);
		SpecMapGlyphCache.socketEnabled[slotIndex] = playerLevel >= unlockLevel;
	end
	
	SpecMapGlyphCache.ready = true;
end

function SpecMap_IsGlyphSocketEnabled(slotIndex)
	if ( not SpecMapGlyphCache.ready ) then
		SpecMap_BuildGlyphCache();
	end
	return SpecMapGlyphCache.socketEnabled[slotIndex] == true;
end

function SpecMap_GetGlyphSocketTypeCached(slotIndex)
	return SpecMap_GetGlyphSocketType(slotIndex);
end

function SpecMap_GetTalentRank(talentGroup, tabIndex, talentIndex, talentID)
	local cachedRank = SpecMap_TalentCacheGetRank(talentGroup, tabIndex, talentID);
	if ( cachedRank ~= nil ) then
		return cachedRank;
	end
	local spec = GetSpecMapSpecData(talentGroup);
	if ( not spec or type(spec.talents) ~= "table" ) then
		return nil;
	end
	for _, talentInfo in ipairs(spec.talents) do
		local specTabId = talentInfo.tabId or talentInfo.tab or talentInfo.tabIndex;
		local specTalentId = talentInfo.talentId or talentInfo.id or talentInfo.talentIndex;
		if ( type(specTabId) == "number" and type(specTalentId) == "number" ) then
			local matchesById = talentID and specTalentId == talentID;
			local matchesTab = (specTabId == tabIndex) or (specTabId + 1 == tabIndex);
			local matchesTalent = (specTalentId == talentIndex) or (specTalentId + 1 == talentIndex);
			if ( matchesById or (matchesTab and matchesTalent) ) then
				local rank = talentInfo.rank;
				if ( type(rank) == "number" ) then
					if ( rank >= 0 ) then
						return rank + 1;
					else
						return 0;
					end
				end
				return nil;
			end
		end
	end
	return nil;
end

local function PlayerTalentFrame_HandleSpecMapUpdate()
	if ( not PlayerTalentFrame ) then
		return;
	end

	SpecMap_BuildTalentCache();

	local activeTalentGroup = SpecMap_GetActiveTalentGroup();
	local numTalentGroups = SpecMap_GetTalentGroupCount();
	
	-- Set active spec number from decoded SpecMap message
	local specMap = GetSpecMapTable();
	if ( specMap and type(specMap.activeSpec) == "number" ) then
		-- specMap.activeSpec is already 1-based (converted in DecodeSpecInfo)
		activeSpecNumber = specMap.activeSpec;
	else
		activeSpecNumber = activeTalentGroup;
	end
	
	-- Also update base game active spec if possible (this ensures GetActiveTalentGroup returns correct value)
	-- Note: This might not work in all cases, but we'll also check activeSpecNumber as fallback
	
	-- Update selectedSpecNumber and talentGroup when specmap is received
	-- If selectedSpecNumber is nil or not set, use activeSpecNumber
	-- Otherwise, keep the user's selection but ensure talentGroup matches
	if ( type(activeSpecNumber) == "number" and activeSpecNumber > 0 ) then
		if ( selectedSpecNumber == nil ) then
			-- Initialize to active spec if not set
			selectedSpecNumber = activeSpecNumber;
			if ( PlayerTalentFrame ) then
				PlayerTalentFrame.talentGroup = activeSpecNumber;
			end
		elseif ( PlayerTalentFrame and not PlayerTalentFrame:IsShown() ) then
			-- If frame hasn't been shown yet, update to active spec
			selectedSpecNumber = activeSpecNumber;
			if ( PlayerTalentFrame ) then
				PlayerTalentFrame.talentGroup = activeSpecNumber;
			end
		else
			-- Frame is shown and user has a selection - ensure talentGroup matches selectedSpecNumber
			-- This ensures the talent tree shows the correct spec
			if ( PlayerTalentFrame and type(selectedSpecNumber) == "number" ) then
				PlayerTalentFrame.talentGroup = selectedSpecNumber;
			end
		end
	else
		-- Fallback: ensure talentGroup is set even if activeSpecNumber is not available
		if ( PlayerTalentFrame and type(selectedSpecNumber) == "number" ) then
			PlayerTalentFrame.talentGroup = selectedSpecNumber;
		elseif ( PlayerTalentFrame ) then
			PlayerTalentFrame.talentGroup = 1;
		end
	end

	PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups);
	
	-- Rebuild menu items when spec map updates (spec count may have changed)
	local dropdownButton = _G["PlayerTalentFrameSpecDropdown"];
	if ( dropdownButton and type(PlayerTalentFrameSpecDropdown_BuildMenu) == "function" ) then
		PlayerTalentFrameSpecDropdown_BuildMenu(dropdownButton);
	end
	
	-- Update spec dropdown (this will update the text color based on active spec)
	-- Do this AFTER activeSpecNumber is set so the dropdown can check the correct value
	if ( type(PlayerTalentFrameSpecDropdown_Update) == "function" ) then
		PlayerTalentFrameSpecDropdown_Update();
	end

	if ( PlayerTalentFrame:IsShown() ) then
		-- Also update dropdown after refresh to ensure it reflects the active spec
		if ( type(PlayerTalentFrameSpecDropdown_Update) == "function" ) then
			PlayerTalentFrameSpecDropdown_Update();
		end
		if ( type(PlayerTalentFrameSpecDropdown_SelectSpec) == "function" ) then
			PlayerTalentFrameSpecDropdown_SelectSpec(activeSpecNumber);
		end
		PlayerTalentFrame_Refresh();
	end

	if ( GlyphFrame and GlyphFrame_Update ) then
		GlyphFrame_Update();
	end
end


-- PlayerTalentFrame

function PlayerTalentFrame_Toggle(pet, suggestedTalentGroup)
	local hidden;
	local talentTabSelected = PanelTemplates_GetSelectedTab(PlayerTalentFrame) ~= GLYPH_TALENT_TAB;
	if ( not PlayerTalentFrame:IsShown() ) then
		ShowUIPanel(PlayerTalentFrame);
		hidden = false;
	else
		local spec = selectedSpec and specs[selectedSpec];
		if ( spec and talentTabSelected ) then
			-- if a talent tab is selected then toggle the frame off
			HideUIPanel(PlayerTalentFrame);
			hidden = true;
		else
			hidden = false;
		end
	end
	if ( not hidden ) then
		-- open the spec with the requested talent group (or the current talent group if the selected
		-- spec has one)
		if ( selectedSpec ) then
			local spec = specs[selectedSpec];
			if ( spec.pet == pet ) then
				suggestedTalentGroup = spec.talentGroup;
			end
		end
		for _, index in ipairs(TALENT_SORT_ORDER) do
			local spec = specs[index];
			if ( spec.pet == pet and spec.talentGroup == suggestedTalentGroup ) then
				PlayerSpecTab_OnClick(specTabs[index]);
				if ( not talentTabSelected ) then
					PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab"..PlayerTalentTab_GetBestDefaultTab(index)]);
				end
				break;
			end
		end
	end
end

function PlayerTalentFrame_Open(pet, talentGroup)
	ShowUIPanel(PlayerTalentFrame);
	-- open the spec with the requested talent group
	for index, spec in next, specs do
		if ( spec.pet == pet and spec.talentGroup == talentGroup ) then
			PlayerSpecTab_OnClick(specTabs[index]);
			break;
		end
	end
end

function PlayerTalentFrame_ToggleGlyphFrame(suggestedTalentGroup)
	GlyphFrame_LoadUI();
	if ( GlyphFrame ) then
		local hidden;
		if ( not PlayerTalentFrame:IsShown() ) then
			ShowUIPanel(PlayerTalentFrame);
			hidden = false;
		else
			local spec = selectedSpec and specs[selectedSpec];
			if ( spec and spec.hasGlyphs and
				 PanelTemplates_GetSelectedTab(PlayerTalentFrame) == GLYPH_TALENT_TAB ) then
				-- if the glyph tab is selected then toggle the frame off
				HideUIPanel(PlayerTalentFrame);
				hidden = true;
			else
				hidden = false;
			end
		end
		if ( not hidden ) then
			-- open the spec with the requested talent group (or the current talent group if the selected
			-- spec has one)
			if ( selectedSpec ) then
				local spec = specs[selectedSpec];
				if ( spec.hasGlyphs ) then
					suggestedTalentGroup = spec.talentGroup;
				end
			end
			for _, index in ipairs(TALENT_SORT_ORDER) do
				local spec = specs[index];
				if ( spec.hasGlyphs and spec.talentGroup == suggestedTalentGroup ) then
					PlayerSpecTab_OnClick(specTabs[index]);
					PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab"..GLYPH_TALENT_TAB]);
					break;
				end
			end
		end
	end
end

function PlayerTalentFrame_OpenGlyphFrame(talentGroup)
	GlyphFrame_LoadUI();
	if ( GlyphFrame ) then
		ShowUIPanel(PlayerTalentFrame);
		-- open the spec with the requested talent group
		for index, spec in next, specs do
			if ( spec.hasGlyphs and spec.talentGroup == talentGroup ) then
				PlayerSpecTab_OnClick(specTabs[index]);
				PlayerTalentTab_OnClick(_G["PlayerTalentFrameTab"..GLYPH_TALENT_TAB]);
				break;
			end
		end
	end
end

function PlayerTalentFrame_ShowGlyphFrame()
	GlyphFrame_LoadUI();
	if ( GlyphFrame ) then
		-- Hide the talent frame title text when viewing glyphs
		if ( PlayerTalentFrameTitleText ) then
			PlayerTalentFrameTitleText:Hide();
		end
		-- set the title text of the GlyphFrame
		-- Use spec name with "Glyphs" instead of "Specialization"
		local numTalentGroups;
		if ( PlayerTalentFrame.inspect ) then
			numTalentGroups = GetNumTalentGroups();
		else
			numTalentGroups = SpecMap_GetTalentGroupCount();
		end
		
		if ( numTalentGroups > 1 ) then
			-- Get the current spec number (use selectedSpecNumber if available, otherwise talentGroup)
			local currentSpecNumber = selectedSpecNumber or PlayerTalentFrame.talentGroup or 1;
			-- Get the spec name
			local specName = GetOrdinalSpecName(currentSpecNumber);
			-- Replace "Specialization" with "Glyphs"
			local glyphTitle = string.gsub(specName, "Specialization", "Glyphs");
			GlyphFrameTitleText:SetText(glyphTitle);
		else
			GlyphFrameTitleText:SetText(GLYPHS);
		end
		-- Set glyph frame height to match updated XML size (544 pixels)
		GlyphFrame:SetHeight(544);
		
		-- show/update the glyph frame
		if ( GlyphFrame:IsShown() ) then
			GlyphFrame_Update();
		else
			GlyphFrame:Show();
		end
		
		-- Increase scale by 50% when viewing glyphs (0.80 * 1.5 = 1.20)
		-- Set scale after frame is shown/updated to ensure it's not overridden
		PlayerTalentFrame:SetScale(1.20);

		-- don't forget to hide the scroll button overlay or it may show up on top of the GlyphFrame!
		UIFrameFlashStop(PlayerTalentFrameScrollButtonOverlay);
		
		-- Update controls to show status frame/activate button for glyphs
		local activeTalentGroup;
		if ( PlayerTalentFrame.inspect ) then
			activeTalentGroup = GetActiveTalentGroup(false, false);
		else
			activeTalentGroup = SpecMap_GetActiveTalentGroup();
		end
		if ( type(PlayerTalentFrame_UpdateControls) == "function" ) then
			PlayerTalentFrame_UpdateControls(activeTalentGroup, numTalentGroups);
		end
		
		-- Ensure scale is maintained after controls update (in case they reset it)
		PlayerTalentFrame:SetScale(1.20);
		
		-- Update glyph title text when switching specs
		if ( GlyphFrame and GlyphFrame:IsShown() and GlyphFrameTitleText ) then
			if ( numTalentGroups > 1 ) then
				local currentSpecNumber = selectedSpecNumber or PlayerTalentFrame.talentGroup or 1;
				local specName = GetOrdinalSpecName(currentSpecNumber);
				local glyphTitle = string.gsub(specName, "Specialization", "Glyphs");
				GlyphFrameTitleText:SetText(glyphTitle);
			else
				GlyphFrameTitleText:SetText(GLYPHS);
			end
		end
	end
end

function PlayerTalentFrame_HideGlyphFrame()
	if ( not GlyphFrame or not GlyphFrame:IsShown() ) then
		return;
	end

	GlyphFrame_LoadUI();
	if ( GlyphFrame ) then
		GlyphFrame:Hide();
	end
	
	-- Revert scale back to 0.75 when hiding glyphs
	PlayerTalentFrame:SetScale(0.80);
	if ( GlyphFrame ) then
		GlyphFrame:SetScale(0.80);
	end
	
	-- Show the talent frame title text when hiding glyphs
	if ( PlayerTalentFrameTitleText ) then
		PlayerTalentFrameTitleText:Show();
	end
end


function PlayerTalentFrame_OnLoad(self)
	-- Check UIParent's effective scale and adjust PlayerTalentFrame scale accordingly
	self:SetScale(0.80);
	
	-- Create backdrop frame with black background (0.55 alpha) at specified points
	local backdropFrame = CreateFrame("Frame", "PlayerTalentFrameBackdrop", self);
	backdropFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 11, -12);
	backdropFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -32, 76);
	backdropFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		tile = true,
		tileSize = 8,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	});
	backdropFrame:SetBackdropColor(0, 0, 0, 0.75);
	backdropFrame:SetFrameLevel(self:GetFrameLevel() - 1); -- Ensure it's behind other elements
	
	-- Clear base textures from status frame, points bar, preview bar, close button, and spec tabs
	if ( PlayerTalentFrameStatusFrame ) then
		ClearBaseTextures(PlayerTalentFrameStatusFrame);
	end
	if ( PlayerTalentFramePointsBar ) then
		ClearBaseTextures(PlayerTalentFramePointsBar);
	end
	if ( PlayerTalentFramePreviewBar ) then
		ClearBaseTextures(PlayerTalentFramePreviewBar);
	end
	if ( PlayerTalentFrameCloseButton ) then
		ClearBaseTextures(PlayerTalentFrameCloseButton);
		PlayerTalentFrameCloseButton:SetNormalTexture("");
		PlayerTalentFrameCloseButton:SetPushedTexture("");

		local closeTex = PlayerTalentFrameCloseButton:CreateTexture("$parentCloseTex", "OVERLAY");
		closeTex:SetTexture("Interface\\FrameGeneral\\Close");
		closeTex:SetSize(16, 16);
		closeTex:SetPoint("CENTER");
		closeTex:SetAlpha(.60)
		PlayerTalentFrameCloseButton:SetHitRectInsets(7, 6, 7, 6);
		PlayerTalentFrameCloseButton:HookScript("OnEnter", function(self)
			local closeTex = _G[self:GetName().."CloseTex"];
			if ( closeTex ) then
				closeTex:SetAlpha(1)
			end
		end);
		PlayerTalentFrameCloseButton:HookScript("OnLeave", function(self)
			local closeTex = _G[self:GetName().."CloseTex"];
			if ( closeTex ) then
				closeTex:SetAlpha(.60)
			end
		end);
	end

	-- Reskin tabs
	for i = 1, 4 do
		local tab = _G["PlayerTalentFrameTab"..i];
		if ( tab ) then
			ReskinTab(tab);
			-- Set backdrop frame level to -1 relative to tab
			local backdrop = _G[tab:GetName().."Backdrop"];
			if ( backdrop ) then
				backdrop:SetFrameLevel(tab:GetFrameLevel() - 1);
			end
		end
	end
	-- Clear textures from scrollframe (used in pet frame)
	if ( PlayerTalentFrameScrollFrame ) then
		ClearBaseTextures(PlayerTalentFrameScrollFrame);
	end
	
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("PREVIEW_TALENT_POINTS_CHANGED");
	self:RegisterEvent("PREVIEW_PET_TALENT_POINTS_CHANGED");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("UNIT_PET");
	self:RegisterEvent("PLAYER_LEVEL_UP");
	self:RegisterEvent("PLAYER_TALENT_UPDATE");
	self:RegisterEvent("PET_TALENT_UPDATE");
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
	self.unit = "player";
	self.inspect = false;
	self.pet = false;
	self.talentGroup = 1;
	self.updateFunction = PlayerTalentFrame_Update;
	
	-- Initialize selectedSpecNumber to match active spec (if available) or default to 1
	-- Prioritize activeSpecNumber (from decoded message) over GetActiveTalentGroup
	if ( selectedSpecNumber == nil ) then
		if ( type(activeSpecNumber) == "number" and activeSpecNumber > 0 ) then
			-- Use activeSpecNumber from decoded message if available
			selectedSpecNumber = activeSpecNumber;
			self.talentGroup = activeSpecNumber;
		else
			-- Fallback to base game API
			local activeTalentGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
			if ( activeTalentGroup and activeTalentGroup > 0 ) then
				selectedSpecNumber = activeTalentGroup;
				self.talentGroup = activeTalentGroup;
			else
				-- Default to 1
				selectedSpecNumber = 1;
				self.talentGroup = 1;
			end
		end
	end
	
	-- Create spec dropdown button
	if ( not _G["PlayerTalentFrameSpecDropdown"] ) then
		local dropdownButton = CreateFrame("Button", "PlayerTalentFrameSpecDropdown", self);
		dropdownButton:SetSize(150, 24);
		dropdownButton:SetPoint("TOPLEFT", self, "TOPLEFT", 29, -24);
		
		-- Create backdrop (no border)
		dropdownButton:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			tile = true,
			tileSize = 8,
			insets = { left = 0, right = 0, top = 0, bottom = 0 }
		});
		dropdownButton:SetBackdropColor(0, 0, 0, 0.75);
		
		-- Create text for selected spec (no "Spec:" label)
		local text = dropdownButton:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		text:SetPoint("LEFT", dropdownButton, "LEFT", 10, 0);
		text:SetPoint("RIGHT", dropdownButton, "RIGHT", -25, 0);
		text:SetJustifyH("LEFT");
		text:SetText("Select Spec");
		dropdownButton.text = text;
		
		-- Create dropdown arrow
		local arrow = dropdownButton:CreateTexture(nil, "OVERLAY");
		arrow:SetTexture("Interface\\FrameGeneral\\arrowup");
		arrow:SetTexCoord(0, 1, 1, 0);
		arrow:SetSize(18, 18);
		arrow:SetPoint("RIGHT", dropdownButton, "RIGHT", -5, 0);
		arrow:SetVertexColor(1, .8, 0)
		dropdownButton.arrow = arrow;
		
		-- Create dropdown menu frame
		local menuFrame = CreateFrame("Frame", "PlayerTalentFrameSpecDropdownMenu", UIParent);
		-- Set strata and frame level once when creating - keep static
		menuFrame:SetFrameStrata("FULLSCREEN_DIALOG");
		menuFrame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			tile = true,
			tileSize = 8,
			insets = { left = 0, right = 0, top = 0, bottom = 0 }
		});
		menuFrame:SetBackdropColor(0, 0, 0, 0.90);
		menuFrame:Hide();
		menuFrame:SetMovable(false);
		menuFrame:EnableMouse(true);
		menuFrame:SetScript("OnMouseDown", function(self, button)
			if ( button == "RightButton" ) then
				menuFrame:Hide();
			end
		end);
		dropdownButton.menuFrame = menuFrame;
		
		-- Set click handler
		dropdownButton:SetScript("OnClick", function(self, button)
			if ( button == "LeftButton" ) then
				if ( self.menuFrame and self.menuFrame:IsShown() ) then
					self.menuFrame:Hide();
				else
					PlayerTalentFrameSpecDropdown_ShowMenu(self);
				end
			end
		end);
		
		-- Close menu when PlayerTalentFrame is hidden
		self:HookScript("OnHide", function()
			if ( dropdownButton.menuFrame ) then
				dropdownButton.menuFrame:Hide();
			end
		end);
		
		-- Hide by default, will be shown when needed
		dropdownButton:Hide();
		self.specDropdown = dropdownButton;
	end
	
	-- Create Reset button on the far left of the points bar
	if ( not _G["PlayerTalentFramePointsBarResetButton"] ) then
		local resetButton = CreateFrame("Button", "PlayerTalentFramePointsBarResetButton", _G["PlayerTalentFramePointsBar"], "UIPanelButtonTemplate");
		resetButton:SetSize(60, 22);
		resetButton:SetPoint("LEFT", _G["PlayerTalentFramePointsBar"], "LEFT", 8, 0);
		resetButton:SetText("Reset");
		
		-- Set button scripts
		resetButton:SetScript("OnClick", function(self, button)
			if ( button == "LeftButton" ) then
				-- Send message to server with opcode 10
				local resetOpCode = 10;
				local fullMessage = string.format("%d|", resetOpCode);
				PushMessageToServer(fullMessage);
			end
		end);
		
		resetButton:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText("Reset Talents");
			GameTooltip:Show();
		end);
		
		resetButton:SetScript("OnLeave", function(self)
			GameTooltip:Hide();
		end);
		
		-- Enable mouse
		resetButton:EnableMouse(true);
		resetButton:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		
		-- Hide the button initially - will be shown only when viewing active spec
		resetButton:Hide();
	end

	TalentFrame_Load(self);

	-- setup talent buttons
	local button;
	for i = 1, MAX_NUM_TALENTS do
		button = _G["PlayerTalentFrameTalent"..i];
		if ( button ) then
			button:SetScript("OnClick", PlayerTalentFrameTalent_OnClick);
			button:SetScript("OnEvent", PlayerTalentFrameTalent_OnEvent);
			button:SetScript("OnEnter", PlayerTalentFrameTalent_OnEnter);
		end
	end

	-- setup tabs
	PanelTemplates_SetNumTabs(self, 2);	-- add one for the GLYPH_TALENT_TAB

	-- initialize active spec as a fail safe
	local activeTalentGroup;
	local numTalentGroups;
	if ( self.inspect ) then
		activeTalentGroup = GetActiveTalentGroup();
		numTalentGroups = GetNumTalentGroups();
	else
		activeTalentGroup = SpecMap_GetActiveTalentGroup();
		numTalentGroups = SpecMap_GetTalentGroupCount();
	end
	PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups);

	-- setup active spec highlight
	if ( ACTIVESPEC_DISPLAYTYPE == "BLUE" ) then
		PlayerTalentFrameActiveSpecTabHighlight:SetDrawLayer("OVERLAY");
		PlayerTalentFrameActiveSpecTabHighlight:SetBlendMode("ADD");
		PlayerTalentFrameActiveSpecTabHighlight:SetTexture("Interface\\Buttons\\UI-Button-Outline");
	elseif ( ACTIVESPEC_DISPLAYTYPE == "GOLD_INSIDE" ) then
		PlayerTalentFrameActiveSpecTabHighlight:SetDrawLayer("OVERLAY");
		PlayerTalentFrameActiveSpecTabHighlight:SetBlendMode("ADD");
		PlayerTalentFrameActiveSpecTabHighlight:SetTexture("Interface\\Buttons\\CheckButtonHilight");
	elseif ( ACTIVESPEC_DISPLAYTYPE == "GOLD_BACKGROUND" ) then
		PlayerTalentFrameActiveSpecTabHighlight:SetDrawLayer("BACKGROUND");
		PlayerTalentFrameActiveSpecTabHighlight:SetWidth(74);
		PlayerTalentFrameActiveSpecTabHighlight:SetHeight(86);
		PlayerTalentFrameActiveSpecTabHighlight:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab-Glow");
	end
end

function PlayerTalentFrame_OnShow(self)
	-- Stop buttons from flashing after skill up
	SetButtonPulse(TalentMicroButton, 0, 1);

	PlaySound("TalentScreenOpen");
	UpdateMicroButtons();

	-- For player talents (not inspect, not pet), ensure we show the active spec
	if ( not self.inspect and not self.pet ) then
		-- Get the active spec number (from decoded message or base API)
		local activeSpecNum = _G["activeSpecNumber"];
		if ( type(activeSpecNum) ~= "number" or activeSpecNum <= 0 ) then
			-- Fallback to base game API
			activeSpecNum = GetActiveTalentGroup(self.inspect, self.pet);
			if ( not activeSpecNum or activeSpecNum <= 0 ) then
				activeSpecNum = 1;
			end
		end
		
		-- Always set selectedSpecNumber and talentGroup to active spec when showing the frame
		-- This ensures the talent tree shows the active spec's trees
		-- Set these BEFORE any refresh/update calls
		selectedSpecNumber = activeSpecNum;
		self.talentGroup = activeSpecNum;
		
		-- For player talents with dropdown, bypass the old spec tab system
		-- Just refresh directly with the correct talentGroup set
		PlayerTalentFrame_Refresh();
		
		-- Ensure talentGroup is still set correctly after refresh (in case something reset it)
		-- This is a safeguard to prevent the talent tree from resetting to spec 1
		if ( type(selectedSpecNumber) == "number" ) then
			self.talentGroup = selectedSpecNumber;
		end
		
		-- Force update the talent frame with the correct talentGroup
		if ( type(TalentFrame_Update) == "function" ) then
			TalentFrame_Update(self);
		end
		
		-- Update dropdown to show the active spec
		if ( type(PlayerTalentFrameSpecDropdown_Update) == "function" ) then
			PlayerTalentFrameSpecDropdown_Update();
		end
	else
		-- For pet/inspect, use the old spec tab system
		if ( not selectedSpec ) then
			-- if no spec was selected, try to select the active one
			PlayerSpecTab_OnClick(activeSpec and specTabs[activeSpec] or specTabs[DEFAULT_TALENT_SPEC]);
		else
			PlayerTalentFrame_Refresh();
		end
	end

	-- Set flag
	if ( not GetCVarBool("talentFrameShown") ) then
		SetCVar("talentFrameShown", 1);
	end
end

function  PlayerTalentFrame_OnHide()
	PlaySound("TalentScreenClose");
	UpdateMicroButtons();
end

function PlayerTalentFrame_OnEvent(self, event, ...)
	if ( event == "PLAYER_TALENT_UPDATE" or event == "PET_TALENT_UPDATE" ) then
		PlayerTalentFrame_Refresh();
	elseif ( event == "PREVIEW_TALENT_POINTS_CHANGED" ) then
		--local talentIndex, tabIndex, groupIndex, points = ...;
		if ( selectedSpec and not specs[selectedSpec].pet ) then
			PlayerTalentFrame_Refresh();
		end
	elseif ( event == "PREVIEW_PET_TALENT_POINTS_CHANGED" ) then
		--local talentIndex, tabIndex, groupIndex, points = ...;
		if ( selectedSpec and specs[selectedSpec].pet ) then
			PlayerTalentFrame_Refresh();
		end
	elseif ( event == "UNIT_PORTRAIT_UPDATE" ) then
		local unit = ...;
		-- Portrait is hidden, no longer updating
		-- if ( unit == PlayerTalentFramePortrait.unit ) then
		-- 	SetPortraitTexture(PlayerTalentFramePortrait, unit);
		-- end
		-- update spec tabs' portraits
		for _, frame in next, specTabs do
			if ( frame.usingPortraitTexture ) then
				local spec = specs[frame.specIndex];
				if ( unit == spec.unit and spec.portraitUnit ) then
					SetPortraitTexture(frame:GetNormalTexture(), unit);
				end
			end
		end
	elseif ( event == "UNIT_PET" ) then
		local summoner = ...;
		if ( summoner == "player" ) then
			if ( selectedSpec and specs[selectedSpec].pet ) then
				-- if the selected spec is a pet spec...
				local numTalentGroups = GetNumTalentGroups(false, true);
				if ( numTalentGroups == 0 ) then
					--...and a pet spec is not available, select the default spec
					PlayerSpecTab_OnClick(activeSpec and specTabs[activeSpec] or specTabs[DEFAULT_TALENT_SPEC]);
					return;
				end
			end
			PlayerTalentFrame_Refresh();
		end
	elseif ( event == "PLAYER_LEVEL_UP" ) then
		if ( selectedSpec and not specs[selectedSpec].pet ) then
			local level = ...;
			PlayerTalentFrame_Update(level);
		end
	elseif ( event == "ACTIVE_TALENT_GROUP_CHANGED" ) then
		MainMenuBar_ToPlayerArt(MainMenuBarArtFrame);
	end
end

function PlayerTalentFrame_Refresh()
	-- Ensure talentGroup is set correctly before refreshing
	if ( PlayerTalentFrame and not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- For player talents, ensure talentGroup matches selectedSpecNumber
		if ( type(selectedSpecNumber) == "number" ) then
			PlayerTalentFrame.talentGroup = selectedSpecNumber;
		elseif ( PlayerTalentFrame.talentGroup == nil ) then
			-- Fallback to active spec or default
			local activeSpec = _G["activeSpecNumber"];
			if ( type(activeSpec) == "number" and activeSpec > 0 ) then
				PlayerTalentFrame.talentGroup = activeSpec;
			else
				PlayerTalentFrame.talentGroup = 1;
			end
		end
	end
	
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	if ( selectedTab == GLYPH_TALENT_TAB ) then
		PlayerTalentFrame_ShowGlyphFrame();
		-- Ensure scale is maintained after ShowGlyphFrame (in case it gets reset)
		if ( GlyphFrame and GlyphFrame:IsShown() ) then
			PlayerTalentFrame:SetScale(1.20);
		end
		-- Update controls for glyph view (ShowGlyphFrame already calls this, but ensure it's called)
		local activeTalentGroup;
		local numTalentGroups;
		if ( PlayerTalentFrame.inspect ) then
			activeTalentGroup = GetActiveTalentGroup(false, false);
			numTalentGroups = GetNumTalentGroups();
		else
			activeTalentGroup = SpecMap_GetActiveTalentGroup();
			numTalentGroups = SpecMap_GetTalentGroupCount();
		end
		if ( type(PlayerTalentFrame_UpdateControls) == "function" ) then
			PlayerTalentFrame_UpdateControls(activeTalentGroup, numTalentGroups);
		end
		-- Ensure scale is maintained after controls update when viewing glyphs
		if ( GlyphFrame and GlyphFrame:IsShown() ) then
			PlayerTalentFrame:SetScale(1.20);
		end
	else
		PlayerTalentFrame_HideGlyphFrame();
		-- Update the talent frame display when viewing talents
		if ( type(TalentFrame_Update) == "function" ) then
			TalentFrame_Update(PlayerTalentFrame);
		end
		-- Also update controls
		local activeTalentGroup;
		local numTalentGroups;
		if ( PlayerTalentFrame.inspect ) then
			activeTalentGroup = GetActiveTalentGroup(false, false);
			numTalentGroups = GetNumTalentGroups();
		else
			activeTalentGroup = SpecMap_GetActiveTalentGroup();
			numTalentGroups = SpecMap_GetTalentGroupCount();
		end
		if ( type(PlayerTalentFrame_UpdateControls) == "function" ) then
			PlayerTalentFrame_UpdateControls(activeTalentGroup, numTalentGroups);
		end
	end
	
	-- Update spec dropdown position and visibility
	if ( type(PlayerTalentFrameSpecDropdown_Update) == "function" ) then
		PlayerTalentFrameSpecDropdown_Update();
	end
	
	TalentFrame_Update(PlayerTalentFrame);
	
	-- Final scale check: ensure scale is correct based on glyph frame visibility
	-- This must be after TalentFrame_Update as it may reset the scale
	if ( GlyphFrame and GlyphFrame:IsShown() ) then
		-- Glyph frame is shown: scale should be 1.20 (50% increase from 0.80)
		PlayerTalentFrame:SetScale(1.20);
		GlyphFrame:SetScale(1);
	else
		-- Talent view: scale should be 0.80
		PlayerTalentFrame:SetScale(0.80);
		if ( GlyphFrame ) then
			GlyphFrame:SetScale(0.80);
		end
	end
end

function PlayerTalentFrame_Update(playerLevel)
	local activeTalentGroup;
	local numTalentGroups;
	if ( PlayerTalentFrame.inspect ) then
		activeTalentGroup, numTalentGroups = GetActiveTalentGroup(false, false), GetNumTalentGroups(false, false);
	else
		activeTalentGroup = SpecMap_GetActiveTalentGroup();
		numTalentGroups = SpecMap_GetTalentGroupCount();
	end
	local activePetTalentGroup, numPetTalentGroups = GetActiveTalentGroup(false, true), GetNumTalentGroups(false, true);
	
	-- Update activeSpecNumber and ensure selectedSpecNumber matches active spec if not set
	-- Only update if activeSpecNumber hasn't been set from decoded message
	-- This prevents overriding the value from the decoded message
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- Only update activeSpecNumber if it hasn't been set yet (from decoded message)
		if ( activeSpecNumber == nil ) then
			-- Use base game API as source of truth for active spec
			local baseActiveTalentGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
			if ( baseActiveTalentGroup and baseActiveTalentGroup > 0 ) then
				activeSpecNumber = baseActiveTalentGroup;
			end
		end
		
		-- Ensure selectedSpecNumber and talentGroup are set correctly
		-- Only initialize if not already set - don't override user's selection
		if ( selectedSpecNumber == nil ) then
			if ( type(activeSpecNumber) == "number" and activeSpecNumber > 0 ) then
				-- Initialize to active spec if not already set
				selectedSpecNumber = activeSpecNumber;
				-- Also set the frame's talentGroup to match
				PlayerTalentFrame.talentGroup = activeSpecNumber;
			else
				-- Fallback: if activeSpecNumber not set, try base game API
				local baseActiveTalentGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
				if ( baseActiveTalentGroup and baseActiveTalentGroup > 0 ) then
					selectedSpecNumber = baseActiveTalentGroup;
					PlayerTalentFrame.talentGroup = baseActiveTalentGroup;
				else
					selectedSpecNumber = 1;
					PlayerTalentFrame.talentGroup = 1;
				end
			end
		else
			-- selectedSpecNumber is set - ensure talentGroup matches it
			if ( type(selectedSpecNumber) == "number" ) then
				PlayerTalentFrame.talentGroup = selectedSpecNumber;
			end
		end
	end

	-- update specs
	if ( not PlayerTalentFrame_UpdateSpecs(activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups) ) then
		-- the current spec is not selectable any more, discontinue updates
		return;
	end

	-- update tabs
	if ( not PlayerTalentFrame_UpdateTabs(playerLevel) ) then
		-- the current spec is not selectable any more, discontinue updates
		return;
	end

	-- Portrait is hidden, no longer setting
	-- SetPortraitTexture(PlayerTalentFramePortrait, PlayerTalentFrame.unit);

	-- update active talent group stuff
	PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups);

	-- update talent controls
	PlayerTalentFrame_UpdateControls(activeTalentGroup, numTalentGroups);
	
	-- Update spec dropdown to reflect any changes to active spec
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		if ( type(PlayerTalentFrameSpecDropdown_Update) == "function" ) then
			PlayerTalentFrameSpecDropdown_Update();
		end
	end
end

function PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups)
	-- set the active spec
	activeSpec = DEFAULT_TALENT_SPEC;
	for index, spec in next, specs do
		if ( not spec.pet and spec.talentGroup == activeTalentGroup ) then
			activeSpec = index;
			break;
		end
	end
	-- make UI adjustments
	local spec = selectedSpec and specs[selectedSpec];

	local hasMultipleTalentGroups = numTalentGroups > 1;
	-- Show/hide title text based on whether we're viewing glyphs or talents
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	if ( selectedTab == GLYPH_TALENT_TAB ) then
		-- Hide title text when viewing glyphs
		if ( PlayerTalentFrameTitleText ) then
			PlayerTalentFrameTitleText:Hide();
		end
	else
		-- Show title text when viewing talents
		if ( PlayerTalentFrameTitleText ) then
			PlayerTalentFrameTitleText:Show();
			-- Check if viewing pet talents
			if ( PlayerTalentFrame.pet ) then
				PlayerTalentFrameTitleText:SetText("Pet Specialization");
			elseif ( hasMultipleTalentGroups ) then
				-- Use ordinal spec name for the title
				-- Use selectedSpecNumber if available, otherwise fall back to activeTalentGroup or talentGroup
				local currentSpecNumber = selectedSpecNumber;
				if ( not currentSpecNumber ) then
					currentSpecNumber = PlayerTalentFrame.talentGroup or activeTalentGroup or 1;
				end
				PlayerTalentFrameTitleText:SetText(GetOrdinalSpecName(currentSpecNumber));
			else
				PlayerTalentFrameTitleText:SetText(TALENTS);
			end
		end
	end

	if ( selectedSpec == activeSpec and hasMultipleTalentGroups ) then
		--PlayerTalentFrameActiveTalentGroupFrame:Show();
	else
		PlayerTalentFrameActiveTalentGroupFrame:Hide();
	end
end


-- PlayerTalentFrameTalents

function PlayerTalentFrameTalent_OnClick(self, button)
	if ( IsModifiedClick("CHATLINK") ) then
		local link = GetTalentLink(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(),
			PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
		-- Debug: Print raw talent hyperlink
		if ( link ) then
			print("DEBUG: Raw talent hyperlink (PlayerTalentFrameTalent_OnClick):", link);
			ChatEdit_InsertLink(link);
		else
			print("DEBUG: GetTalentLink returned nil");
		end
	elseif ( selectedSpec and specs[selectedSpec].pet ) then
		-- only allow functionality if an active spec is selected
		if ( button == "LeftButton" ) then
			if ( GetCVarBool("previewTalents") ) then
				AddPreviewTalentPoints(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), 1, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			else
				LearnTalent(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			end
		elseif ( button == "RightButton" ) then
			if ( GetCVarBool("previewTalents") ) then
				AddPreviewTalentPoints(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), -1, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			else
				LearnTalent(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(), PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			end
		end
		elseif (selectedSpec and activeSpec == selectedSpec) then
		if ( button == "LeftButton" ) then
			local tabIndex = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
			local talentIndex = self:GetID();
			local talentLink = GetTalentLink(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
			local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
			local _, _, tier, column, _, maxRank, _, meetsPrereq = GetTalentInfo(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			local isAvailable = SpecMap_TalentCacheIsTalentAvailable(PlayerTalentFrame.talentGroup, tabIndex, talentId, tier);
			local freeTalents = SpecMap_TalentCacheGetFreeTalents();
			if ( isAvailable and (freeTalents == nil or freeTalents > 0) and SpecMap_TalentCacheAdjustRank(PlayerTalentFrame.talentGroup, tabIndex, talentId, 1, maxRank, tier) ) then
				PlayerTalentFrame_Refresh();
				-- Refresh tooltip if it's showing for this button
				if ( GameTooltip:IsOwned(self) ) then
					PlayerTalentFrameTalent_OnEnter(self);
				end
			end
        elseif ( button == "RightButton" ) then
            local tabIndex = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
            local talentIndex = self:GetID();
            local talentLink = GetTalentLink(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
            local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
			local _, _, tier, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
			
			-- Get current rank from cache (includes user changes)
			local currentRank = SpecMap_TalentCacheGetRank(PlayerTalentFrame.talentGroup, tabIndex, talentId);
			-- Get base spec map rank (from decoded message, before any user changes)
			local baseSpecMapRank = SpecMap_GetBaseTalentRank(PlayerTalentFrame.talentGroup, tabIndex, talentId);
			
			-- Check if deranking would go below the spec map rank
			local newRank = currentRank - 1;
			if ( newRank < baseSpecMapRank ) then
				-- Cannot derank below spec map rank
				return;
			end
			
			-- Proceed with derank if allowed
			if ( SpecMap_TalentCacheCanDerank(PlayerTalentFrame.talentGroup, tabIndex, talentId, tier) and SpecMap_TalentCacheAdjustRank(PlayerTalentFrame.talentGroup, tabIndex, talentId, -1, maxRank, tier) ) then
                PlayerTalentFrame_Refresh();
				-- Refresh tooltip if it's showing for this button
				if ( GameTooltip:IsOwned(self) ) then
					PlayerTalentFrameTalent_OnEnter(self);
				end
            end
		end
	end
end

function PlayerTalentFrameTalent_OnEvent(self, event, ...)
	if ( GameTooltip:IsOwned(self) ) then
		GameTooltip:SetTalent(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(),
			PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
	end
end

function PlayerTalentFrameTalent_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	
	local tabIndex = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	local talentIndex = self:GetID();
	local talentGroup = PlayerTalentFrame.talentGroup;
	
	-- For player talents, get the current rank from SpecMap cache and show tooltip with that rank
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- Get base talent link (rank 0, which is rank -1 in the link format)
		local baseLink = GetTalentLink(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, talentGroup, false);
		local talentId = SpecMap_TalentCacheExtractTalentID(baseLink);
		
		if ( talentId and type(SpecMap_TalentCacheGetRank) == "function" ) then
			local currentRank = SpecMap_TalentCacheGetRank(talentGroup, tabIndex, talentId) or 0;
			
			-- Get talent name for the link
			local talentName = GetTalentInfo(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, talentGroup);
			
			if ( talentName and currentRank > 0 ) then
				-- Construct hyperlink with correct rank
				-- Rank format: -1 = rank 0, 0 = rank 1, 1 = rank 2, etc.
				-- So rankNum = currentRank - 1
				local rankNum = currentRank - 1;
				local talentLink = "|cff4e96f7|Htalent:"..talentId..":"..rankNum.."|h["..talentName.."]|h|r";
				GameTooltip:SetHyperlink(talentLink);
			else
				-- Rank is 0 or no name, use normal SetTalent
				GameTooltip:SetTalent(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, talentGroup, false);
			end
		else
			-- Fallback to normal SetTalent
			GameTooltip:SetTalent(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, talentGroup, false);
		end
	else
		-- For pet/inspect, use normal SetTalent
		GameTooltip:SetTalent(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, talentGroup, GetCVarBool("previewTalents"));
	end
end

function PlayerTalentFrameTalent_OnLeave(self)
	GameTooltip:Hide();
end


-- Controls

function PlayerTalentFrame_UpdateControls(activeTalentGroup, numTalentGroups)
	local spec = selectedSpec and specs[selectedSpec];

	-- Determine if this is the active spec
	local isActiveSpec;
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- Player talents: use numeric spec values from dropdown
		if ( type(selectedSpecNumber) == "number" and type(activeSpecNumber) == "number" ) then
			isActiveSpec = selectedSpecNumber == activeSpecNumber;
		else
			isActiveSpec = false;
		end
	else
		-- Pet/inspect: use original string-based logic
		isActiveSpec = selectedSpec == activeSpec;
	end
	
	-- Determine if we should show the status frame or activate button
	-- Show status frame/activate button for both talents and glyphs
	local showStatusFrame = false;
	local showActivateButton = false;
	
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- Player talents/glyphs: show status frame if viewing active spec, activate button if viewing inactive spec
		if ( isActiveSpec ) then
			-- Always show status frame when viewing active spec (talents or glyphs)
			showStatusFrame = true;
			showActivateButton = false;
		elseif ( numTalentGroups > 1 ) then
			-- Show activate button when viewing inactive spec and multiple talent groups exist (talents or glyphs)
			showStatusFrame = false;
			showActivateButton = true;
		end
	else
		-- Pet/inspect: show status frame if not a pet spec and multiple talent groups
		if ( spec and not spec.pet and numTalentGroups > 1 ) then
			if ( isActiveSpec ) then
				showStatusFrame = true;
				showActivateButton = false;
			else
				showStatusFrame = false;
				showActivateButton = true;
			end
		end
	end
	
	-- Update status frame and activate button visibility (show for both talents and glyphs)
	-- Position both relative to title text (even if title text is hidden for glyphs)
	local titleText = PlayerTalentFrameTitleText;
	
	if ( showActivateButton ) then
		PlayerTalentFrameStatusFrame:Hide();
		PlayerTalentFrameActivateButton:Show();
		-- Ensure activate button is above glyph frame if glyphs are showing
		local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
		if ( selectedTab == GLYPH_TALENT_TAB ) then
			if ( GlyphFrame and GlyphFrame:IsShown() ) then
				local glyphFrameLevel = GlyphFrame:GetFrameLevel();
				PlayerTalentFrameActivateButton:SetFrameLevel(glyphFrameLevel + 1);
				PlayerTalentFrameActivateButton:SetPoint("TOP", GlyphFrameTitleText, "BOTTOM", 0, -8);
			end
		else
			-- Position activate button in same position as status frame (relative to title text)
			if ( titleText ) then
				PlayerTalentFrameActivateButton:ClearAllPoints();
				PlayerTalentFrameActivateButton:SetPoint("TOP", titleText, "BOTTOM", 0, -8);
			else
				-- Fallback: position relative to frame top
				PlayerTalentFrameActivateButton:ClearAllPoints();
				PlayerTalentFrameActivateButton:SetPoint("TOP", PlayerTalentFrame, "TOP", 10, -45);
			end
		end
	else
		PlayerTalentFrameActivateButton:Hide();
		if ( showStatusFrame ) then
			-- Position status frame below the title text (even if title text is hidden)
			if ( titleText ) then
				PlayerTalentFrameStatusFrame:ClearAllPoints();
				PlayerTalentFrameStatusFrame:SetPoint("TOP", titleText, "BOTTOM", 0, -8);
			else
				-- Fallback: position relative to frame top
				PlayerTalentFrameStatusFrame:ClearAllPoints();
				PlayerTalentFrameStatusFrame:SetPoint("TOP", PlayerTalentFrame, "TOP", 10, -45);
			end
			-- Ensure status frame is above glyph frame if glyphs are showing
			local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
			if ( selectedTab == GLYPH_TALENT_TAB ) then
				if ( GlyphFrame and GlyphFrame:IsShown() ) then
					local glyphFrameLevel = GlyphFrame:GetFrameLevel();
					PlayerTalentFrameStatusFrame:SetFrameLevel(glyphFrameLevel + 1);
					PlayerTalentFrameActivateButton:SetPoint("TOP", GlyphFrameTitleText, "BOTTOM", 0, -8);
				else
					-- If glyph frame exists but isn't shown yet, use a high frame level
					PlayerTalentFrameStatusFrame:SetFrameLevel(PlayerTalentFrame:GetFrameLevel() + 5);
				end
			end
			PlayerTalentFrameStatusFrame:Show();
			-- Update status text
			if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
				-- Player talents: use dropdown spec numbers
				if ( isActiveSpec ) then
					PlayerTalentFrameStatusText:SetText(TALENT_ACTIVE_SPEC_STATUS);
				else
					-- Show inactive status - construct message based on selected vs active spec
					local selectedSpecText = "Spec " .. (selectedSpecNumber or "?");
					local activeSpecText = "Spec " .. (activeSpecNumber or "?");
					PlayerTalentFrameStatusText:SetText("Viewing " .. selectedSpecText .. " (Active: " .. activeSpecText .. ")");
				end
			else
				-- Pet/inspect: use default status text
				PlayerTalentFrameStatusText:SetText(TALENT_ACTIVE_SPEC_STATUS);
			end
		else
			PlayerTalentFrameStatusFrame:Hide();
		end
	end

	local preview = GetCVarBool("previewTalents");

	-- enable the control bar if this is the active spec, preview is enabled, and preview points were spent
	local talentPoints;
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- Player talents: use SpecMap
		talentPoints = SpecMap_GetFreeTalentPoints();
	elseif ( spec ) then
		-- Pet/inspect: use spec data
		talentPoints = GetUnspentTalentPoints(PlayerTalentFrame.inspect, spec.pet, spec.talentGroup);
	else
		-- Fallback: use base game API
		talentPoints = GetUnspentTalentPoints(PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
	end

	local hasCacheChanges = false;
	if ( isActiveSpec and not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- For player talents, use PlayerTalentFrame.talentGroup or selectedSpecNumber instead of spec.talentGroup
		local talentGroupToCheck = PlayerTalentFrame.talentGroup;
		if ( not talentGroupToCheck and type(selectedSpecNumber) == "number" ) then
			talentGroupToCheck = selectedSpecNumber;
		end
		if ( talentGroupToCheck ) then
			hasCacheChanges = SpecMap_HasCacheChanges(talentGroupToCheck);
		end
	end

	if ( isActiveSpec and hasCacheChanges and (not GlyphFrame or not GlyphFrame:IsShown()) ) then
		PlayerTalentFrameControlBar:Show();
		PlayerTalentFrameControlBarResetButton:Show();
		PlayerTalentFrameControlBarLearnButton:Show();
		PlayerTalentFrameControlBar:SetPoint("CENTER", PlayerTalentFramePointsBar, "CENTER", 0, 0);
	else
		PlayerTalentFrameControlBar:Hide();
		PlayerTalentFrameControlBarResetButton:Hide();
		PlayerTalentFrameControlBarLearnButton:Hide();
		if ( spec and spec.pet and talentPoints > 0 and preview ) then
			PlayerTalentFramePreviewBar:Show();
			-- enable accept/cancel buttons if preview talent points were spent
			if ( GetGroupPreviewTalentPointsSpent(spec.pet, spec.talentGroup) > 0 ) then
				PlayerTalentFrameLearnButton:Enable();
				PlayerTalentFrameResetButton:Enable();
			else
				PlayerTalentFrameLearnButton:Disable();
				PlayerTalentFrameResetButton:Disable();
			end
			-- squish all frames to make room for this bar
			PlayerTalentFramePointsBar:SetPoint("BOTTOM", PlayerTalentFramePreviewBar, "TOP", 0, -4);
		else
			PlayerTalentFramePreviewBar:Hide();
			-- unsquish frames since the bar is now hidden
			PlayerTalentFramePointsBar:SetPoint("BOTTOM", PlayerTalentFrame, "BOTTOM", 0, 81);
		end
	end
	
	-- Show/hide the points bar reset button based on active spec and glyph frame visibility
	local pointsBarResetButton = _G["PlayerTalentFramePointsBarResetButton"];
	if ( pointsBarResetButton ) then
		if ( isActiveSpec and (not GlyphFrame or not GlyphFrame:IsShown()) ) then
			pointsBarResetButton:Show();
		else
			pointsBarResetButton:Hide();
		end
	end
end

function PlayerTalentFrameActivateButton_OnLoad(self)
	self:SetWidth(self:GetTextWidth() + 40);
end

function PlayerTalentFrameActivateButton_OnClick(self)
	-- Get the spec number to activate (0-based)
	local specNumber = nil;
	if ( type(selectedSpecNumber) == "number" ) then
		-- Convert to 0-based (spec 1 becomes 0, spec 2 becomes 1, etc.)
		specNumber = selectedSpecNumber - 1;
	elseif ( selectedSpec ) then
		-- Fallback to old method if selectedSpecNumber not set
		local talentGroup = specs[selectedSpec].talentGroup;
		if ( talentGroup ) then
			specNumber = talentGroup - 1; -- Convert to 0-based
		end
	end
	
	if ( specNumber ~= nil ) then
		-- Send message to server with opcode 8
		-- Example: 8|0
		local activateOpCode = 8;
		local fullMessage = string.format("%d|%d", activateOpCode, specNumber);
		PushMessageToServer(fullMessage);
	end
end

function PlayerTalentFrameActivateButton_OnShow(self)
	self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED");
	PlayerTalentFrameActivateButton_Update();
end

function PlayerTalentFrameActivateButton_OnHide(self)
	self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED");
end

function PlayerTalentFrameActivateButton_OnEvent(self, event, ...)
	PlayerTalentFrameActivateButton_Update();
end

function PlayerTalentFrameActivateButton_Update()
	local spec = selectedSpec and specs[selectedSpec];
	if ( spec and PlayerTalentFrameActivateButton:IsShown() ) then
		-- if the activation spell is being cast currently, disable the activate button
		if ( IsCurrentSpell(TALENT_ACTIVATION_SPELLS[spec.talentGroup]) ) then
			PlayerTalentFrameActivateButton:Disable();
		else
			PlayerTalentFrameActivateButton:Enable();
		end
	end
end

-- PlayerTalentFrameResetButton_OnEnter and PlayerTalentFrameResetButton_OnLeave removed
-- Button now uses default UIPanelButtonTemplate behavior

function PlayerTalentFrameResetButton_OnClick(self)
	if ( PlayerTalentFrame.pet ) then
		ResetGroupPreviewTalentPoints(PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
	else
		-- Reset the cache to match SpecMap data
		SpecMap_BuildTalentCache();
		-- Refresh the UI to show the reset state
		PlayerTalentFrame_Refresh();
	end
end

function PlayerTalentFrameLearnButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	GameTooltip:SetText(TALENT_TOOLTIP_LEARNTALENTGROUP);
end

function PlayerTalentFrameLearnButton_OnClick(self)
	StaticPopup_Show("CONFIRM_LEARN_PREVIEW_TALENTS");
end


-- PlayerTalentFrameDownArrow

function PlayerTalentFrameDownArrow_OnClick(self, button)
	local parent = self:GetParent();
	parent:SetValue(parent:GetValue() + (parent:GetHeight() / 2));
	PlaySound("UChatScrollButton");
	UIFrameFlashStop(PlayerTalentFrameScrollButtonOverlay);
end


-- PlayerTalentFrameTab

function PlayerTalentFrame_UpdateTabs(playerLevel)
	local totalTabWidth = 0;

	local firstShownTab;

	-- setup talent tabs
	local maxPointsSpent = 0;
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	-- Ensure a tab is selected (default to tab 1 if none selected)
	if ( not selectedTab or selectedTab <= 0 ) then
		selectedTab = 1;
		PanelTemplates_SetTab(PlayerTalentFrame, selectedTab);
	end
	local numTabs = GetNumTalentTabs(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
	local renderAllTabs = (not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet);
	local tab;
	
	-- For player talents, replace tabs 1-3 with a single "Talents" tab (tab 1)
	-- Tab 1 shows all 3 talent trees side-by-side, tab 4 is glyphs
	-- For pet/inspect, show tabs as normal
	if ( renderAllTabs ) then
		-- Hide tabs 2 and 3 (unused)
		for i = 2, MAX_TALENT_TABS do
			talentTabWidthCache[i] = 0;
			tab = _G["PlayerTalentFrameTab"..i];
			if ( tab ) then
				tab:Hide();
				tab.textWidth = 0;
			end
		end
		-- Configure tab 1 as the "Talents" tab
		tab = _G["PlayerTalentFrameTab"..1];
		if ( tab ) then
			-- Calculate total points spent across all talent tabs for display
			local totalPointsSpent = 0;
			local totalPreviewPointsSpent = 0;
			for i = 1, numTabs do
				if ( i ~= GLYPH_TALENT_TAB ) then
					local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(i, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
					local cachePoints = SpecMap_TalentCacheSumTabPoints(PlayerTalentFrame.talentGroup, i);
					if ( cachePoints ~= nil ) then
						pointsSpent = cachePoints;
					end
					totalPointsSpent = totalPointsSpent + pointsSpent;
					totalPreviewPointsSpent = totalPreviewPointsSpent + previewPointsSpent;
				end
			end
			local displayPointsSpent = totalPointsSpent + totalPreviewPointsSpent;
			
			-- Set tab 1 text to "Talents"
			tab:SetText("Talents");
			PanelTemplates_TabResize(tab, 0);
			tab.textWidth = tab:GetTextWidth();
			talentTabWidthCache[1] = PanelTemplates_GetTabWidth(tab);
			totalTabWidth = totalTabWidth + talentTabWidthCache[1];
			tab:Show();
			firstShownTab = firstShownTab or tab;
			
			-- Set points spent display (hidden when using grid layout)
			-- Points spent is now shown in each column header instead
			-- PlayerTalentFrameSpentPointsText:SetFormattedText(MASTERY_POINTS_SPENT, "Talents", HIGHLIGHT_FONT_COLOR_CODE..displayPointsSpent..FONT_COLOR_CODE_CLOSE);
			PlayerTalentFrameSpentPointsText:Hide(); -- Hide the old points spent text
			PlayerTalentFrame.pointsSpent = totalPointsSpent;
			PlayerTalentFrame.previewPointsSpent = totalPreviewPointsSpent;
		end
	else
		-- For pet/inspect, show tabs as normal
		for i = 1, MAX_TALENT_TABS do
			-- clear cached widths
			talentTabWidthCache[i] = 0;
			tab = _G["PlayerTalentFrameTab"..i];
			if ( tab ) then
				if ( i <= numTabs ) then
					local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(i, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup);
					if ( i == selectedTab ) then
						-- If tab is the selected tab set the points spent info (hidden when using grid layout)
						-- Points spent is now shown in each column header instead
						local displayPointsSpent = pointsSpent + previewPointsSpent;
						-- PlayerTalentFrameSpentPointsText:SetFormattedText(MASTERY_POINTS_SPENT, name, HIGHLIGHT_FONT_COLOR_CODE..displayPointsSpent..FONT_COLOR_CODE_CLOSE);
						PlayerTalentFrameSpentPointsText:Hide(); -- Hide the old points spent text
						PlayerTalentFrame.pointsSpent = pointsSpent;
						PlayerTalentFrame.previewPointsSpent = previewPointsSpent;
					end
					tab:SetText(name);
					PanelTemplates_TabResize(tab, 0);
					-- record the text width to see if we need to display a tooltip
					tab.textWidth = tab:GetTextWidth();
					-- record the tab widths for resizing later
					talentTabWidthCache[i] = PanelTemplates_GetTabWidth(tab);
					totalTabWidth = totalTabWidth + talentTabWidthCache[i];
					tab:Show();
					firstShownTab = firstShownTab or tab;
				else
					tab:Hide();
					tab.textWidth = 0;
				end
			end
		end
	end

	local spec = specs[selectedSpec];

	-- setup glyph tabs, right now there is only one
	playerLevel = playerLevel or UnitLevel("player");
	local meetsGlyphLevel = playerLevel >= SHOW_INSCRIPTION_LEVEL;
	tab = _G["PlayerTalentFrameTab"..GLYPH_TALENT_TAB];
	
	-- For player talents, always show the glyph tab (if level requirement met) so users can switch between talents and glyphs
	-- For pet/inspect, only show if glyphs are available
	if ( renderAllTabs ) then
		-- Player talents: always show glyph tab if level requirement met (regardless of spec.hasGlyphs)
		-- This allows users to switch between viewing all talent trees and viewing glyphs
		-- The glyph tab acts as a toggle: when NOT selected, show all 3 talent trees; when selected, show glyphs
		if ( meetsGlyphLevel ) then
			tab:Show();
			firstShownTab = firstShownTab or tab;
			PanelTemplates_TabResize(tab, 0);
			talentTabWidthCache[GLYPH_TALENT_TAB] = PanelTemplates_GetTabWidth(tab);
			totalTabWidth = totalTabWidth + talentTabWidthCache[GLYPH_TALENT_TAB];
		else
			tab:Hide();
			talentTabWidthCache[GLYPH_TALENT_TAB] = 0;
		end
	else
		-- Pet/inspect: only show if glyphs are available
		if ( meetsGlyphLevel and spec.hasGlyphs ) then
			tab:Show();
			firstShownTab = firstShownTab or tab;
			PanelTemplates_TabResize(tab, 0);
			talentTabWidthCache[GLYPH_TALENT_TAB] = PanelTemplates_GetTabWidth(tab);
			totalTabWidth = totalTabWidth + talentTabWidthCache[GLYPH_TALENT_TAB];
		else
			tab:Hide();
			talentTabWidthCache[GLYPH_TALENT_TAB] = 0;
		end
	end
	local numGlyphTabs = (tab and tab:IsShown()) and 1 or 0;

	-- select the first shown tab if the selected tab does not exist for the selected spec
	tab = _G["PlayerTalentFrameTab"..selectedTab];
	if ( tab and not tab:IsShown() ) then
		-- For player talents, if tab 1 (Talents) or tab 4 (Glyphs) is selected, it should be visible
		-- If a hidden tab (2 or 3) is selected, switch to tab 1
		if ( renderAllTabs and selectedTab >= 2 and selectedTab <= MAX_TALENT_TABS ) then
			-- Tabs 2-3 are hidden, switch to tab 1 (Talents)
			local talentsTab = _G["PlayerTalentFrameTab"..1];
			if ( talentsTab ) then
				PlayerTalentFrameTab_OnClick(talentsTab);
				return false;
			end
		elseif ( firstShownTab ) then
			-- No visible tab matches selectedTab, switch to first shown tab
			PlayerTalentFrameTab_OnClick(firstShownTab);
			return false;
		else
			-- No tabs available - this shouldn't happen but handle gracefully
			return false;
		end
	end

	-- readjust tab sizes to fit
	local maxTotalTabWidth = PlayerTalentFrame:GetWidth();
	while ( totalTabWidth >= maxTotalTabWidth ) do
		-- progressively shave 10 pixels off of the largest tab until they all fit within the max width
		local largestTab = 1;
		for i = 2, #talentTabWidthCache do
			if ( talentTabWidthCache[largestTab] < talentTabWidthCache[i] ) then
				largestTab = i;
			end
		end
		-- shave the width
		talentTabWidthCache[largestTab] = talentTabWidthCache[largestTab] - 10;
		-- apply the shaved width
		tab = _G["PlayerTalentFrameTab"..largestTab];
		PanelTemplates_TabResize(tab, 0, talentTabWidthCache[largestTab]);
		-- now update the total width
		totalTabWidth = totalTabWidth - 10;
	end

	-- update the tabs
	-- For player talents, we have tab 1 (Talents) and tab 4 (Glyphs)
	-- For pet/inspect, count all tabs as normal
	local numTabsToShow;
	if ( renderAllTabs ) then
		-- Tab 1 (Talents) is shown, plus glyph tab if available
		numTabsToShow = 1 + numGlyphTabs;
	else
		-- Glyph tab is selected - still show both tabs
		numTabsToShow = 1 + numGlyphTabs;
	end
	
	-- For player talents, we have tab 1 (Talents) and tab 4 (Glyphs)
	-- Tabs 2 and 3 are hidden, so we need to tell PanelTemplates that tabs 1 and 4 exist
	if ( renderAllTabs ) then
		-- Tell PanelTemplates there are 4 tabs total (1, 2, 3, 4), but we'll manage visibility manually
		PanelTemplates_SetNumTabs(PlayerTalentFrame, 4);
		-- Hide tabs 2 and 3 explicitly (tab 1 is already shown above)
		for i = 2, MAX_TALENT_TABS do
			local tab = _G["PlayerTalentFrameTab"..i];
			if ( tab ) then
				tab:Hide();
			end
		end
		-- Ensure tab 1 is shown (Talents tab)
		local talentsTab = _G["PlayerTalentFrameTab"..1];
		if ( talentsTab ) then
			talentsTab:Show();
		end
		-- Show glyph tab (tab 4) if available
		if ( numGlyphTabs > 0 ) then
			local glyphTab = _G["PlayerTalentFrameTab"..GLYPH_TALENT_TAB];
			if ( glyphTab ) then
				glyphTab:Show();
			end
		end
		PanelTemplates_UpdateTabs(PlayerTalentFrame);
	else
		-- Not rendering all tabs (glyph tab selected) - use normal PanelTemplates logic
		if ( numTabsToShow == 0 ) then
			numTabsToShow = 1;
		end
		PanelTemplates_SetNumTabs(PlayerTalentFrame, numTabsToShow);
		PanelTemplates_UpdateTabs(PlayerTalentFrame);
	end
	

	return true;
end

function PlayerTalentFrameTab_OnLoad(self)
	self:SetFrameLevel(self:GetFrameLevel() + 2);
end

function PlayerTalentFrameTab_OnClick(self)
	local id = self:GetID();
	PanelTemplates_SetTab(PlayerTalentFrame, id);
	PlayerTalentFrame_Refresh();
	PlaySound("igCharacterInfoTab");
end

function PlayerTalentFrameTab_OnEnter(self)
	if ( self.textWidth and self.textWidth > self:GetFontString():GetWidth() ) then	--We're ellipsizing.
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM");
		GameTooltip:SetText(self:GetText());
	end
end


-- PlayerTalentTab

function PlayerTalentTab_OnLoad(self)
	PlayerTalentFrameTab_OnLoad(self);

	self:RegisterEvent("PLAYER_LEVEL_UP");
end

function PlayerTalentTab_OnClick(self)
	PlayerTalentFrameTab_OnClick(self);
	for i=1, MAX_TALENT_TABS do
		SetButtonPulse(_G["PlayerTalentFrameTab"..i], 0, 0);
	end
end

function PlayerTalentTab_OnEvent(self, event, ...)
	if ( UnitLevel("player") == (SHOW_TALENT_LEVEL - 1) and PanelTemplates_GetSelectedTab(PlayerTalentFrame) ~= self:GetID() ) then
		SetButtonPulse(self, 60, 0.75);
	end
end

function PlayerTalentTab_GetBestDefaultTab(specIndex)
	if ( not specIndex ) then
		return DEFAULT_TALENT_TAB;
	end

	local spec = specs[specIndex];
	if ( not spec ) then
		return DEFAULT_TALENT_TAB;
	end

	local specInfoCache = talentSpecInfoCache[specIndex];
	TalentFrame_UpdateSpecInfoCache(specInfoCache, false, spec.pet, spec.talentGroup);
	if ( specInfoCache.primaryTabIndex > 0 ) then
		return talentSpecInfoCache[specIndex].primaryTabIndex;
	else
		return DEFAULT_TALENT_TAB;
	end
end


-- PlayerGlyphTab

function PlayerGlyphTab_OnLoad(self)
	PlayerTalentFrameTab_OnLoad(self);

	self:RegisterEvent("PLAYER_LEVEL_UP");
	GLYPH_TALENT_TAB = self:GetID();
	-- we can record the text width for the glyph tab now since it never changes
	self.textWidth = self:GetTextWidth();
end

function PlayerGlyphTab_OnClick(self)
	PlayerTalentFrameTab_OnClick(self);
	SetButtonPulse(_G["PlayerTalentFrameTab"..GLYPH_TALENT_TAB], 0, 0);
end

function PlayerGlyphTab_OnEvent(self, event, ...)
	if ( UnitLevel("player") == (SHOW_INSCRIPTION_LEVEL - 1) and PanelTemplates_GetSelectedTab(PlayerTalentFrame) ~= self:GetID() ) then
		SetButtonPulse(self, 60, 0.75);
	end
end


-- Specs

-- PlayerTalentFrame_UpdateSpecs is a helper function for PlayerTalentFrame_Update.
-- Returns true on a successful update, false otherwise. An update may fail if the currently
-- selected tab is no longer selectable. In this case, the first selectable tab will be selected.
function PlayerTalentFrame_UpdateSpecs(activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups)
	-- Hide PlayerSpecTabs for player talents (we use dropdown instead)
	-- BUT show pet spec tabs if the player has a pet
	-- AND show SpecTab1 when viewing pet talents (so it can switch back to player view)
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- Hide non-pet spec tabs (player uses dropdown for those)
		-- SpecTab1 will be hidden here but will show when viewing pet talents
		for i = 1, 3 do
			local frame = _G["PlayerSpecTab"..i];
			if ( frame ) then
				local specIndex = frame.specIndex;
				local spec = specs[specIndex];
				-- Hide if it's a player spec tab (not a pet spec) and not spec1
				-- SpecTab1 needs to be available when viewing pet talents
				if ( spec and not spec.pet and specIndex ~= "spec1" ) then
					frame:Hide();
				end
			end
		end
		-- Hide the active spec highlight (only shown for player specs, not pet specs)
		PlayerTalentFrameActiveSpecTabHighlight:Hide();
		-- Continue with update logic for pet tabs if player has a pet
		-- If no pet talent groups, return early (no pet tabs to show)
		if ( numPetTalentGroups == 0 ) then
			return true;
		end
		-- Otherwise, continue to show pet spec tabs below
	end
	
	-- set the active spec highlight to be hidden initially, if a spec is the active one then it will
	-- be shown in PlayerSpecTab_Update
	PlayerTalentFrameActiveSpecTabHighlight:Hide();

	-- update each of the spec tabs
	local firstShownTab, lastShownTab;
	local numShown = 0;
	local offsetX = 0;
	for i = 1, numSpecTabs do
		local frame = _G["PlayerSpecTab"..i];
		local specIndex = frame.specIndex;
		local spec = specs[specIndex];
		if ( PlayerSpecTab_Update(frame, activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups) ) then
			firstShownTab = firstShownTab or frame;
			numShown = numShown + 1;
			frame:ClearAllPoints();
			-- set an offsetX fudge if we're the selected tab, otherwise use the previous offsetX
			offsetX = specIndex == selectedSpec and SELECTEDSPEC_OFFSETX or offsetX;
			if ( numShown == 1 ) then
				--...start the first tab off at a base location
				frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPRIGHT", -32 + offsetX, -65);
				-- we'll need to negate the offsetX after the first tab so all subsequent tabs offset
				-- to their default positions
				offsetX = -offsetX;
			else
				--...offset subsequent tabs from the previous one
				if ( spec.pet ~= specs[lastShownTab.specIndex].pet ) then
					frame:SetPoint("TOPLEFT", lastShownTab, "BOTTOMLEFT", 0 + offsetX, -39);
				else
					frame:SetPoint("TOPLEFT", lastShownTab, "BOTTOMLEFT", 0 + offsetX, -22);
				end
			end
			lastShownTab = frame;
		else
			-- if the selected tab is not shown then clear out the selected spec
			if ( specIndex == selectedSpec ) then
				selectedSpec = nil;
			end
		end
	end

	if ( not selectedSpec ) then
		-- For player talents, if we're using the dropdown system, don't auto-select a spec tab
		-- This prevents switching back to pet view when clicking SpecTab1 to switch to player view
		if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
			-- Player talents use dropdown - don't auto-select a spec tab
			-- Just return true to continue with the update
			return true;
		end
		-- For pet/inspect, auto-select the first shown tab
		if ( firstShownTab ) then
			PlayerSpecTab_OnClick(firstShownTab);
		end
		return false;
	end

	if ( numShown == 1 and lastShownTab ) then
		-- If we're only showing one tab, hide it since it doesn't need to be there
		-- EXCEPT if it's a pet tab when viewing player talents (player might want to switch between player and pet)
		-- OR if it's SpecTab1 when viewing pet talents (needed to switch back to player view)
		local specIndex = lastShownTab.specIndex;
		local spec = specs[specIndex];
		if ( specIndex == "spec1" and PlayerTalentFrame.pet ) then
			-- Keep SpecTab1 visible when viewing pet talents so player can switch back
			-- Don't hide it
		elseif ( spec and spec.pet and not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
			-- Keep pet tab visible when viewing player talents (player might want to switch between player and pet)
			-- Don't hide it
		else
			-- Hide the single tab
			lastShownTab:Hide();
		end
	end

	return true;
end

function PlayerSpecTab_Update(self, ...)
	local activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups = ...;

	local specIndex = self.specIndex;
	local spec = specs[specIndex];

	-- Hide SpecTab2 (spec2) - it's no longer needed
	if ( specIndex == "spec2" ) then
		self:Hide();
		return false;
	end

	-- Hide PlayerSpecTabs for player talents (we use dropdown instead)
	-- BUT allow pet spec tabs to show when viewing player talents
	-- AND allow SpecTab1 to show when viewing pet talents (so it can switch back to player view)
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- When viewing player talents: hide spec1 (we use dropdown), but allow pet tabs
		if ( specIndex == "spec1" ) then
			self:Hide();
			return false;
		end
		-- Pet spec tabs are allowed to show when viewing player talents (if player has a pet)
		-- No need to hide them here - they'll be shown if numPetTalentGroups > 0
	end
	-- When viewing pet talents: SpecTab1 will be shown (handled by normal logic below)
	-- Pet spec tabs are allowed to show when viewing player talents (if player has a pet)
	-- SpecTab1 is allowed to show when viewing pet talents (to switch back to player view)

	-- determine whether or not we need to hide the tab
	local canShow;
	if ( spec.pet ) then
		canShow = spec.talentGroup <= numPetTalentGroups;
	else
		canShow = spec.talentGroup <= numTalentGroups;
	end
	if ( not canShow ) then
		self:Hide();
		return false;
	end

	local isSelectedSpec = specIndex == selectedSpec;
	local isActiveSpec = not spec.pet and spec.talentGroup == activeTalentGroup;
	local normalTexture = self:GetNormalTexture();

	-- set the background based on whether or not we're selected
	if ( isSelectedSpec and (SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT" or SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT_CHECKED") ) then
		local name = self:GetName();
		local backgroundTexture = _G[name.."Background"];
		backgroundTexture:SetTexture("Interface\\TalentFrame\\UI-TalentFrame-SpecTab");
		backgroundTexture:SetPoint("TOPLEFT", self, "TOPLEFT", -13, 11);
		if ( SELECTEDSPEC_DISPLAYTYPE == "PUSHED_OUT_CHECKED" ) then
			self:GetCheckedTexture():Show();
		else
			self:GetCheckedTexture():Hide();
		end
	else
		local name = self:GetName();
		local backgroundTexture = _G[name.."Background"];
		backgroundTexture:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab");
		backgroundTexture:SetPoint("TOPLEFT", self, "TOPLEFT", -3, 11);
	end

	-- update the active spec info
	local hasMultipleTalentGroups = numTalentGroups > 1;
	if ( isActiveSpec and hasMultipleTalentGroups ) then
		PlayerTalentFrameActiveSpecTabHighlight:ClearAllPoints();
		if ( ACTIVESPEC_DISPLAYTYPE == "BLUE" ) then
			PlayerTalentFrameActiveSpecTabHighlight:SetParent(self);
			PlayerTalentFrameActiveSpecTabHighlight:SetPoint("TOPLEFT", self, "TOPLEFT", -13, 14);
			PlayerTalentFrameActiveSpecTabHighlight:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 15, -14);
			PlayerTalentFrameActiveSpecTabHighlight:Show();
		elseif ( ACTIVESPEC_DISPLAYTYPE == "GOLD_INSIDE" ) then
			PlayerTalentFrameActiveSpecTabHighlight:SetParent(self);
			PlayerTalentFrameActiveSpecTabHighlight:SetAllPoints(self);
			PlayerTalentFrameActiveSpecTabHighlight:Show();
		elseif ( ACTIVESPEC_DISPLAYTYPE == "GOLD_BACKGROUND" ) then
			PlayerTalentFrameActiveSpecTabHighlight:SetParent(self);
			PlayerTalentFrameActiveSpecTabHighlight:SetPoint("TOPLEFT", self, "TOPLEFT", -3, 20);
			PlayerTalentFrameActiveSpecTabHighlight:Show();
		else
			PlayerTalentFrameActiveSpecTabHighlight:Hide();
		end
	end

--[[
	if ( not spec.pet ) then
		SetDesaturation(normalTexture, not isActiveSpec);
	end
--]]

	-- update the spec info cache
	TalentFrame_UpdateSpecInfoCache(talentSpecInfoCache[specIndex], false, spec.pet, spec.talentGroup);

	-- update spec tab icon
	self.usingPortraitTexture = false;
	
	-- Special handling for SpecTab1 (spec1): always use player portrait
	if ( specIndex == "spec1" ) then
		-- Always use player portrait for SpecTab1
		SetPortraitTexture(normalTexture, "player");
		self.usingPortraitTexture = true;
	elseif ( hasMultipleTalentGroups ) then
		local specInfoCache = talentSpecInfoCache[specIndex];
		local primaryTabIndex = specInfoCache.primaryTabIndex;
		if ( primaryTabIndex > 0 ) then
			-- the spec had a primary tab, set the icon to that tab's icon
			normalTexture:SetTexture(specInfoCache[primaryTabIndex].icon);
		else
			if ( specInfoCache.numTabs > 1 and specInfoCache.totalPointsSpent > 0 ) then
				-- the spec is only considered a hybrid if the spec had more than one tab and at least
				-- one point was spent in one of the tabs
				normalTexture:SetTexture(TALENT_HYBRID_ICON);
			else
				if ( spec.defaultSpecTexture ) then
					-- the spec is probably untalented...set to the default spec texture if we have one
					normalTexture:SetTexture(spec.defaultSpecTexture);
				elseif ( spec.portraitUnit ) then
					-- last check...if there is no default spec texture, try the portrait unit
					SetPortraitTexture(normalTexture, spec.portraitUnit);
					self.usingPortraitTexture = true;
				end
			end
		end
	else
		if ( spec.portraitUnit ) then
			-- set to the portrait texture if we only have one talent group
			SetPortraitTexture(normalTexture, spec.portraitUnit);
			self.usingPortraitTexture = true;
		end
	end
--[[
	-- update overlay icon
	local name = self:GetName();
	local overlayIcon = _G[name.."OverlayIcon"];
	if ( overlayIcon ) then
		if ( hasMultipleTalentGroups ) then
			overlayIcon:Show();
		else
			overlayIcon:Hide();
		end
	end
--]]
	self:Show();
	return true;
end

function PlayerSpecTab_Load(self, specIndex)
	self.specIndex = specIndex;
	specTabs[specIndex] = self;
	numSpecTabs = numSpecTabs + 1;

	-- set the spec's portrait
	local spec = specs[self.specIndex];
	if ( spec.portraitUnit ) then
		SetPortraitTexture(self:GetNormalTexture(), spec.portraitUnit);
		self.usingPortraitTexture = true;
	else
		self.usingPortraitTexture = false;
	end

	-- set the checked texture
	if ( SELECTEDSPEC_DISPLAYTYPE == "BLUE" ) then
		local checkedTexture = self:GetCheckedTexture();
		checkedTexture:SetTexture("Interface\\Buttons\\UI-Button-Outline");
		checkedTexture:SetWidth(64);
		checkedTexture:SetHeight(64);
		checkedTexture:ClearAllPoints();
		checkedTexture:SetPoint("CENTER", self, "CENTER", 0, 0);
	elseif ( SELECTEDSPEC_DISPLAYTYPE == "GOLD_INSIDE" ) then
		local checkedTexture = self:GetCheckedTexture();
		checkedTexture:SetTexture("Interface\\Buttons\\CheckButtonHilight");
	end

	local activeTalentGroup;
	local numTalentGroups;
	if ( PlayerTalentFrame and PlayerTalentFrame.inspect ) then
		activeTalentGroup, numTalentGroups = GetActiveTalentGroup(false, false), GetNumTalentGroups(false, false);
	else
		activeTalentGroup = SpecMap_GetActiveTalentGroup();
		numTalentGroups = SpecMap_GetTalentGroupCount();
	end
	local activePetTalentGroup, numPetTalentGroups = GetActiveTalentGroup(false, true), GetNumTalentGroups(false, true);
	PlayerSpecTab_Update(self, activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups);
end

function PlayerSpecTab_OnClick(self)
	-- set all specs as unchecked initially
	for _, frame in next, specTabs do
		frame:SetChecked(nil);
	end

	-- check ourselves (before we wreck ourselves)
	self:SetChecked(1);

	-- update the selected to this spec
	local specIndex = self.specIndex;
	
	-- Special handling for SpecTab1 (spec1): always switch to player talent view
	if ( specIndex == "spec1" ) then
		selectedSpec = nil; -- Clear selected spec since we're using dropdown for player talents
		
		-- CRITICAL: Set all state BEFORE any update functions are called
		-- This ensures renderAllTabs will be calculated correctly
		
		-- Switch to player talent view
		PlayerTalentFrame.pet = false;
		PlayerTalentFrame.inspect = false;
		PlayerTalentFrame.unit = "player";
		
		-- Set talent group to active spec (from dropdown system) BEFORE setting tab
		local activeSpecNum = _G["activeSpecNumber"];
		if ( type(activeSpecNum) == "number" and activeSpecNum > 0 ) then
			PlayerTalentFrame.talentGroup = activeSpecNum;
			selectedSpecNumber = activeSpecNum;
		else
			-- Fallback to base game API
			local activeTalentGroup = GetActiveTalentGroup(false, false);
			if ( activeTalentGroup and activeTalentGroup > 0 ) then
				PlayerTalentFrame.talentGroup = activeTalentGroup;
				selectedSpecNumber = activeTalentGroup;
			else
				PlayerTalentFrame.talentGroup = 1;
				selectedSpecNumber = 1;
			end
		end
		
		-- Ensure we're on the talents tab (not glyphs tab) - this must be set before updates
		-- Set tab to 1 (talents) explicitly, which will make renderAllTabs = true
		PanelTemplates_SetTab(PlayerTalentFrame, 1);
		
		-- Hide glyph frame if it's showing (we're switching to player talents)
		if ( type(PlayerTalentFrame_HideGlyphFrame) == "function" ) then
			PlayerTalentFrame_HideGlyphFrame();
		end
		
		-- Explicitly hide scroll frame and show grid container for player talents
		local scrollFrame = _G["PlayerTalentFrameScrollFrame"];
		local gridContainer = _G["PlayerTalentFrameGridContainer"];
		if ( scrollFrame ) then
			scrollFrame:Hide();
		end
		if ( gridContainer ) then
			gridContainer:Show();
		end
		
		-- Show and update the spec dropdown
		if ( type(PlayerTalentFrameSpecDropdown_Update) == "function" ) then
			local dropdownButton = _G["PlayerTalentFrameSpecDropdown"];
			if ( dropdownButton ) then
				dropdownButton:Show();
			end
			PlayerTalentFrameSpecDropdown_Update();
		end
	else
		-- For pet spec tabs, use normal behavior
		selectedSpec = specIndex;
		local spec = specs[specIndex];
		PlayerTalentFrame.pet = spec.pet;
		PlayerTalentFrame.unit = spec.unit;
		PlayerTalentFrame.talentGroup = spec.talentGroup;
		
		-- select a tab if one is not already selected
		if ( not PanelTemplates_GetSelectedTab(PlayerTalentFrame) ) then
			PanelTemplates_SetTab(PlayerTalentFrame, PlayerTalentTab_GetBestDefaultTab(specIndex));
		end
	end

	-- Force a full refresh to update the view
	-- For spec1, we need to ensure the view actually switches from pet to player
	if ( specIndex == "spec1" ) then
		-- Verify state is correct before updating
		-- Ensure all state variables are set correctly
		PlayerTalentFrame.pet = false;
		PlayerTalentFrame.inspect = false;
		PlayerTalentFrame.unit = "player";
		
		-- Verify tab is set to 1 (talents, not glyphs)
		local currentTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
		if ( currentTab ~= 1 ) then
			PanelTemplates_SetTab(PlayerTalentFrame, 1);
		end
		
		-- Ensure glyph frame is hidden
		if ( type(PlayerTalentFrame_HideGlyphFrame) == "function" ) then
			PlayerTalentFrame_HideGlyphFrame();
		end
		
		-- Explicitly hide scroll frame and show grid container (again, to be safe)
		local scrollFrame = _G["PlayerTalentFrameScrollFrame"];
		local gridContainer = _G["PlayerTalentFrameGridContainer"];
		if ( scrollFrame ) then
			scrollFrame:Hide();
		end
		if ( gridContainer ) then
			gridContainer:Show();
			-- Also show all grid columns
			local col1 = _G["PlayerTalentFrameGridColumn1"];
			local col2 = _G["PlayerTalentFrameGridColumn2"];
			local col3 = _G["PlayerTalentFrameGridColumn3"];
			if ( col1 ) then col1:Show(); end
			if ( col2 ) then col2:Show(); end
			if ( col3 ) then col3:Show(); end
		end
		
		-- IMPORTANT: Call PlayerTalentFrame_Refresh first to update the frame state
		-- Then call TalentFrame_Update to render the grid
		-- The refresh will update controls and dropdown, but we need to ensure the grid renders
		
		-- Verify state one more time before refreshing
		local verifyTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
		if ( verifyTab ~= 1 ) then
			-- Force tab to 1 if it's not already set
			PanelTemplates_SetTab(PlayerTalentFrame, 1);
		end
		
		-- Ensure pet is false (this is critical for renderAllTabs calculation)
		PlayerTalentFrame.pet = false;
		PlayerTalentFrame.inspect = false;
		
		-- Call refresh first - this will update the frame but TalentFrame_Update at the end might override
		-- So we need to call it again after
		PlayerTalentFrame_Refresh();
		
		-- Now explicitly call TalentFrame_Update to ensure the grid is rendered
		-- IMPORTANT: Temporarily disable updateFunction to prevent it from resetting state
		-- The updateFunction (PlayerTalentFrame_Update) might reset things during the update
		local originalUpdateFunction = PlayerTalentFrame.updateFunction;
		PlayerTalentFrame.updateFunction = nil;
		
		-- Re-assert state before calling TalentFrame_Update
		PlayerTalentFrame.pet = false;
		PlayerTalentFrame.inspect = false;
		local verifyTabAgain = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
		if ( verifyTabAgain ~= 1 ) then
			PanelTemplates_SetTab(PlayerTalentFrame, 1);
		end
		
		-- Now call TalentFrame_Update - this should calculate renderAllTabs = true
		-- because: not inspect (true) and not pet (true) and selectedTab ~= 4 (true)
		if ( type(TalentFrame_Update) == "function" ) then
			TalentFrame_Update(PlayerTalentFrame);
		end
		
		-- Restore updateFunction
		PlayerTalentFrame.updateFunction = originalUpdateFunction;
	else
		-- For pet spec tabs, just refresh normally
		PlayerTalentFrame_Refresh();
	end
end

function PlayerSpecTab_OnEnter(self)
	local specIndex = self.specIndex;
	local spec = specs[specIndex];
	if ( spec.tooltip ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		-- Special handling for SpecTab1 (spec1): always show "Player Talents"
		if ( specIndex == "spec1" ) then
			GameTooltip:AddLine("Player Talents", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
			-- Don't show points spent for SpecTab1
		else
			-- name
			local playerNumTalentGroups;
			if ( PlayerTalentFrame and PlayerTalentFrame.inspect ) then
				playerNumTalentGroups = GetNumTalentGroups(false, false);
			else
				playerNumTalentGroups = SpecMap_GetTalentGroupCount();
			end
			if ( GetNumTalentGroups(false, true) <= 1 and playerNumTalentGroups <= 1 ) then
				-- set the tooltip to be the unit's name
				GameTooltip:AddLine(UnitName(spec.unit), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
			else
				-- set the tooltip to be the spec name
				GameTooltip:AddLine(spec.tooltip);
				if ( self.specIndex == activeSpec ) then
					-- add text to indicate that this spec is active
					GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
				end
			end
			-- points spent (only show for non-spec1 tabs)
			local pointsColor;
			for index, info in ipairs(talentSpecInfoCache[specIndex]) do
				if ( info.name ) then
					-- assign a special color to a tab that surpasses the max points spent threshold
					if ( talentSpecInfoCache[specIndex].primaryTabIndex == index ) then
						pointsColor = GREEN_FONT_COLOR;
					else
						pointsColor = HIGHLIGHT_FONT_COLOR;
					end
					GameTooltip:AddDoubleLine(
						info.name,
						info.pointsSpent,
						HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b,
						pointsColor.r, pointsColor.g, pointsColor.b,
						1
					);
				end
			end
		end
		GameTooltip:Show();
	end
end

-- Decode Spec Info Message
-- Decodes messages sent from the server in the format:
-- OP|freeTalents~specCount~activeSpec~spec0^spec1^...
-- Where each spec is: talentCount:talentId,tabId,rank;talentId,tabId,rank;...|glyph0,glyph1,glyph2,...

-- Constants
local SPEC_INFO_OP = 7

-- Main decode function
local function DecodeSpecInfo(message)
    if not message or message == "" then
        return nil
    end
    
    local result = {
        op = nil,
        freeTalents = nil,
        specCount = nil,
        activeSpec = nil,
        specs = {}
    }
    
    -- Split by OP delimiter to get OP code and data
    local opDelimiter = string.find(message, "|")
    if not opDelimiter then
        return nil -- Invalid format
    end
    
    -- Extract OP code (everything before first |)
    local opCode = tonumber(string.sub(message, 1, opDelimiter - 1))
    result.op = opCode
    
    -- Verify OP code matches expected value
    if opCode ~= SPEC_INFO_OP then
        return nil -- Wrong OP code
    end
    
    -- Extract data portion (everything after first |)
    local data = string.sub(message, opDelimiter + 1)
    
    -- Split player-level data by ~ delimiter
    local playerDataParts = {}
    for part in string.gmatch(data, "([^~]+)") do
        table.insert(playerDataParts, part)
    end
    
    -- Need at least 3 parts: freeTalents, specCount, activeSpec
    if #playerDataParts < 3 then
        return nil -- Invalid format
    end
    
    -- Extract player-level data
    result.freeTalents = tonumber(playerDataParts[1])
    result.specCount = tonumber(playerDataParts[2])
    result.activeSpec = tonumber(playerDataParts[3]) + 1 -- 0-indexed to 1-indexed

    -- The 4th part (if exists) contains all spec data
    -- Format: spec0^spec1^spec2^...
    local specData = playerDataParts[4]
    
    -- If there's no spec data, return early
    if not specData or specData == "" then
        return result
    end
    
    -- Split specs by ^ delimiter
    local specParts = {}
    for part in string.gmatch(specData, "([^^]+)") do
        table.insert(specParts, part)
    end
    
    -- Decode each spec
    for specIndex, specString in ipairs(specParts) do
        local spec = {
            index = specIndex - 1, -- 0-indexed
            talentCount = 0,
            talents = {},
            glyphs = {}
        }
        
        -- Split spec by | to separate talents from glyphs
        local pipePos = string.find(specString, "|")
        local talentData, glyphData
        
        if pipePos then
            -- Has both talents and glyphs
            talentData = string.sub(specString, 1, pipePos - 1)
            glyphData = string.sub(specString, pipePos + 1)
        else
            -- No pipe means no glyphs, only talents (shouldn't happen based on C++ code, but handle it)
            talentData = specString
            glyphData = ""
        end
        
        
        -- Parse talent data
        -- Format: talentCount:talentId,tabId,rank,prereqId,prereqRank;talentId,tabId,rank,prereqId,prereqRank;...
        local colonPos = string.find(talentData, ":")
        if colonPos then
            local countStr = string.sub(talentData, 1, colonPos - 1)
            spec.talentCount = tonumber(countStr) or 0
            
            local talentListStr = string.sub(talentData, colonPos + 1)
            if talentListStr and talentListStr ~= "" then
                -- Split talents by ;
                for talentStr in string.gmatch(talentListStr, "([^;]+)") do
                    -- Split talent by ,
                    local talentParts = {}
                    for part in string.gmatch(talentStr, "([^,]+)") do
                        table.insert(talentParts, part)
                    end
                    
                    local talentInfo = {
                        talentId = tonumber(talentParts[1]),
                        tabId = tonumber(talentParts[2]),
                        rank = tonumber(talentParts[3]),
                    }
                    -- Prerequisite information will be populated from base game API in SpecMap_BuildTalentCache
                    if talentInfo.talentId and talentInfo.tabId and talentInfo.rank ~= nil then
                        table.insert(spec.talents, talentInfo)
                    end
                end
            end
        end
        
        -- Parse glyph data
        -- Format: glyphId$spellId$iconId,glyphId$spellId$iconId,...
        if glyphData and glyphData ~= "" then
            -- Trim whitespace from glyphData
            glyphData = string.gsub(glyphData, "^%s+", "")
            glyphData = string.gsub(glyphData, "%s+$", "")
            
            -- Split glyphs by ,
            for glyphStr in string.gmatch(glyphData, "([^,]+)") do
                -- Trim whitespace from each glyph string
                glyphStr = string.gsub(glyphStr, "^%s+", "")
                glyphStr = string.gsub(glyphStr, "%s+$", "")
                
                if glyphStr and glyphStr ~= "" then
                    -- Split glyph entry by $ to get glyph ID, spell ID, and icon ID
                    -- Use plain string matching (not pattern) for the dollar sign
                    local parts = {}
                    local startPos = 1
                    while true do
                        local dollarPos = string.find(glyphStr, "$", startPos, true)
                        if not dollarPos then
                            -- Last part
                            table.insert(parts, string.sub(glyphStr, startPos))
                            break
                        else
                            table.insert(parts, string.sub(glyphStr, startPos, dollarPos - 1))
                            startPos = dollarPos + 1
                        end
                    end
                    
                    if #parts >= 2 then
                        -- Has at least glyph ID and spell ID
                        local glyphId = tonumber(parts[1])
                        local spellId = tonumber(parts[2])
                        local iconId = (#parts >= 3) and tonumber(parts[3]) or nil
                        
                        if glyphId and spellId then
                            table.insert(spec.glyphs, {
                                glyphId = glyphId,
                                spellId = spellId,
                                iconId = iconId
                            })
                            -- Populate the glyph lookup table for faster access
                            if ( type(SpecMapGlyphIndexToSpellID) == "table" ) then
                                SpecMapGlyphIndexToSpellID[glyphId] = spellId;
                            end
                        end
                    else
                        -- Fallback: try to parse as single number (backward compatibility)
                        local glyphEntry = tonumber(glyphStr)
                        if glyphEntry then
                            table.insert(spec.glyphs, {
                                glyphId = glyphEntry,
                                spellId = nil, -- Will need to be converted later
                                iconId = nil
                            })
                        end
                    end
                end
            end
        end
        
        table.insert(result.specs, spec)
    end
    
    return result
end


-- Export for use in addon
-- Usage example in a WoW addon:
--[[
    local decoded = DecodeSpecInfo(message)
    if decoded then
        print("Free Talents: " .. decoded.freeTalents)
        print("Active Spec: " .. decoded.activeSpec)
        for i, spec in ipairs(decoded.specs) do
            print("Spec " .. i .. " has " .. #spec.talents .. " talents")
            for j, talent in ipairs(spec.talents) do
                -- talent.talentId, talent.tabId, talent.rank
            end
            for j, glyph in ipairs(spec.glyphs) do
                -- glyph is the glyph entry ID
            end
        end
    end
]]

MESSAGE_PREFIX = "HATEROP"

SpecMap = {}

--- Listen for Spec Info message
local fs = CreateFrame("Frame")
fs:RegisterEvent("CHAT_MSG_ADDON")
fs:SetScript("OnEvent", function(self, event, ...)
    local prefix, msg, msgType, sender = ...
	if event ~= "CHAT_MSG_ADDON" or prefix ~= MESSAGE_PREFIX or msgType ~= "WHISPER" then
        return
    end

	if msg == "7|GET" then
		return
	end

	local decoded = DecodeSpecInfo(msg)
	if ( decoded ) then
		SpecMap = decoded
		PlayerTalentFrame_HandleSpecMapUpdate()
	end
end)

function PushMessageToServer(Msg)
	SendAddonMessage(MESSAGE_PREFIX, Msg, "WHISPER", UnitName("player"))
end

PushMessageToServer("7|GET")

-- Spec Dropdown Functions
-- Build or update menu items (called when spec map updates)
function PlayerTalentFrameSpecDropdown_BuildMenu(dropdownButton)
	if ( not dropdownButton or not dropdownButton.menuFrame ) then
		return;
	end
	
	local menuFrame = dropdownButton.menuFrame;
	local specMap = GetSpecMapTable();
	
	if ( not specMap or type(specMap.specs) ~= "table" ) then
		return;
	end
	
	-- Determine dropdown width based on whether viewing glyphs
	local dropdownWidth = 150; -- Default width for talents
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	if ( selectedTab == GLYPH_TALENT_TAB ) then
		dropdownWidth = 75; -- Half width for glyphs
	end
	
	-- Check if we need to rebuild (spec count changed or items don't exist)
	local currentSpecCount = specMap.specCount or 0;
	local existingItemCount = menuFrame.menuItems and #menuFrame.menuItems or 0;
	local needsRebuild = (not menuFrame.menuItems or existingItemCount == 0 or existingItemCount ~= currentSpecCount);
	
	-- Clear existing menu items if we need to rebuild
	if ( needsRebuild and menuFrame.menuItems ) then
		for _, item in ipairs(menuFrame.menuItems) do
			if ( item ) then
				item:Hide();
				-- Properly clean up old items
				item:SetParent(nil);
				item:ClearAllPoints();
			end
		end
		-- Clear the table
		menuFrame.menuItems = {};
	end
	
	-- Initialize menuItems table if it doesn't exist
	if ( not menuFrame.menuItems ) then
		menuFrame.menuItems = {};
	end
	
	-- Only create items if we need to rebuild
	-- If items already exist and count matches, we'll update colors and width later
	if ( not needsRebuild ) then
		-- Update existing items' width based on current view
		local padding = 4;
		local itemWidth = dropdownWidth - (padding * 2);
		for _, item in ipairs(menuFrame.menuItems) do
			if ( item ) then
				item:SetWidth(itemWidth);
			end
		end
		-- Items already exist and count matches, just update colors and return
		PlayerTalentFrameSpecDropdown_UpdateMenuColors();
		return;
	end
	
	local itemHeight = 20;
	local padding = 4;
	local previousItem = nil;
	
	-- Create menu items for each spec
	for specIndex = 1, (specMap.specCount or 0) do
		local specData = specMap.specs[specIndex];
		if ( specData ) then
			local item = CreateFrame("Button", "$parentItem" .. specIndex, menuFrame);
			item:SetSize(dropdownWidth - (padding * 2), itemHeight);
			-- Chain items together - first item anchors to menu frame, others anchor to previous item
			if ( previousItem ) then
				item:SetPoint("TOPLEFT", previousItem, "BOTTOMLEFT", 0, 0);
			else
				item:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", padding, -padding);
			end
			
			-- Ensure the button can receive mouse events by registering for clicks first
			item:RegisterForClicks("LeftButtonUp", "RightButtonUp");
			
			-- Enable mouse events for hover effects
			item:EnableMouse(true);
			
			-- Menu items are children of menuFrame, so they inherit the parent's strata
			-- Just ensure they're at a higher frame level within that strata
			-- Don't set strata explicitly - children inherit from parent automatically
			-- Verify parent is set correctly first (must be set before frame level)
			if ( item:GetParent() ~= menuFrame ) then
				item:SetParent(menuFrame);
			end
			-- Set frame level relative to menu frame (menu frame level is set to 1000 at creation)
			-- Use a higher offset to ensure items are above backdrop
			item:SetFrameLevel(menuFrame:GetFrameLevel() + 10); -- Much higher than menu frame background/backdrop
			
			-- Create text (reduced font size)
			local text = item:CreateFontString("$parentText", "ARTWORK", "GameFontDisableSmall");
			text:SetAllPoints();
			text:SetJustifyH("LEFT");
			text:SetText(GetOrdinalSpecName(specIndex));
			item.text = text;
			
			-- Store spec index on the item for later reference
			item.specIndex = specIndex;
			
			-- Set click handler - use OnClick which is the standard handler for buttons
			item:SetScript("OnClick", function(self, button)
				if ( button == "LeftButton" ) then
					-- Close the dropdown first
					if ( menuFrame.closeFrame ) then
						menuFrame.closeFrame:Hide();
					end
					menuFrame:Hide();
					-- Then select the spec
					PlayerTalentFrameSpecDropdown_SelectSpec(self.specIndex);
				end
			end);
			
			-- Hover effects - change font color to white on hover
			item:SetScript("OnEnter", function(self)
				-- Ensure text exists before setting color
				local textObj = self.text;
				if ( textObj ) then
					textObj:SetTextColor(1, 1, 1, 1); -- White on hover
				end
			end);
			item:SetScript("OnLeave", function(self)
				-- Ensure text exists before setting color
				local textObj = self.text;
				if ( textObj ) then
					-- Get current selected spec and active spec
					local currentSelectedSpec = selectedSpecNumber or PlayerTalentFrame.talentGroup or 1;
					local currentActiveSpec = _G["activeSpecNumber"];
					local isSelected = (type(currentSelectedSpec) == "number" and self.specIndex == currentSelectedSpec);
					local isActive = (type(currentActiveSpec) == "number" and self.specIndex == currentActiveSpec);
					
					-- Set color: white for selected spec, green for active spec, yellow otherwise
					if ( isSelected ) then
						textObj:SetTextColor(1, 1, 1, 1); -- White for selected spec
					elseif ( isActive ) then
						textObj:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1); -- Green for active spec
					else
						textObj:SetTextColor(1.0, 0.82, 0, 1.0); -- Yellow for inactive specs
					end
				end
			end);
			
			table.insert(menuFrame.menuItems, item);
			previousItem = item; -- Store for next iteration
		end
	end
	
	-- Set menu frame height
	if ( #menuFrame.menuItems > 0 ) then
		menuFrame:SetHeight((#menuFrame.menuItems * itemHeight) + (padding * 2));
		-- Force all items to be properly set up
		for _, item in ipairs(menuFrame.menuItems) do
			if ( item ) then
				-- Ensure parent is correct
				if ( item:GetParent() ~= menuFrame ) then
					item:SetParent(menuFrame);
				end
				-- Ensure frame level is correct
				item:SetFrameLevel(menuFrame:GetFrameLevel() + 10);
			end
		end
	else
		menuFrame:Hide();
	end
end

-- Update menu item colors based on selected spec and active spec
function PlayerTalentFrameSpecDropdown_UpdateMenuColors()
	local dropdownButton = _G["PlayerTalentFrameSpecDropdown"];
	if ( not dropdownButton or not dropdownButton.menuFrame ) then
		return;
	end
	
	local menuFrame = dropdownButton.menuFrame;
	if ( not menuFrame.menuItems ) then
		return;
	end
	
	-- Get current selected spec (what user is viewing) and active spec (from decoded message)
	local currentSelectedSpec = selectedSpecNumber or (PlayerTalentFrame and PlayerTalentFrame.talentGroup) or 1;
	local currentActiveSpec = _G["activeSpecNumber"];
	
	for _, item in ipairs(menuFrame.menuItems) do
		if ( item and item.text ) then
			local isSelected = (type(currentSelectedSpec) == "number" and item.specIndex == currentSelectedSpec);
			local isActiveSpec = (type(currentActiveSpec) == "number" and item.specIndex == currentActiveSpec);
			
			-- Set color: white for selected spec, green for active spec, yellow otherwise
			if ( isSelected ) then
				item.text:SetTextColor(1, 1, 1, 1); -- White for selected spec
			elseif ( isActiveSpec ) then
				item.text:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1); -- Green for active spec
			else
				item.text:SetTextColor(1.0, 0.82, 0, 1.0); -- Yellow for inactive specs
			end
		end
	end
end

-- Show or hide the menu (items are pre-built)
function PlayerTalentFrameSpecDropdown_ShowMenu(dropdownButton)
	if ( not dropdownButton or not dropdownButton.menuFrame ) then
		return;
	end
	
	local menuFrame = dropdownButton.menuFrame;
	
	-- Build menu items if they don't exist yet
	if ( not menuFrame.menuItems or #menuFrame.menuItems == 0 ) then
		PlayerTalentFrameSpecDropdown_BuildMenu(dropdownButton);
	end
	
	if ( not menuFrame.menuItems or #menuFrame.menuItems == 0 ) then
		menuFrame:Hide();
		return;
	end
	
	-- Update menu item colors before showing
	PlayerTalentFrameSpecDropdown_UpdateMenuColors();
	
	-- Determine dropdown width based on whether viewing glyphs
	local dropdownWidth = 150; -- Default width for talents
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	if ( selectedTab == GLYPH_TALENT_TAB ) then
		dropdownWidth = 75; -- Half width for glyphs
	end
	
	-- Position menu frame below dropdown button
	menuFrame:ClearAllPoints();
	menuFrame:SetPoint("TOPLEFT", dropdownButton, "BOTTOMLEFT", 0, -2);
	menuFrame:SetWidth(dropdownWidth);
	
	-- Update menu item widths to match dropdown width
	local padding = 4;
	local itemWidth = dropdownWidth - (padding * 2);
	
	-- Show all menu items and ensure they have correct frame levels and parent
	-- Items are children of menuFrame, so they inherit strata automatically
	for _, item in ipairs(menuFrame.menuItems) do
		if ( item ) then
			-- Update item width to match dropdown width
			item:SetWidth(itemWidth);
			-- Ensure parent is set correctly (should be menuFrame) - must be set before frame level
			if ( item:GetParent() ~= menuFrame ) then
				item:SetParent(menuFrame);
			end
			-- Update frame level to be well above menu frame backdrop (items are children, so they inherit strata)
			-- Use a higher offset to ensure items are above backdrop which may render at parent level
			item:SetFrameLevel(menuFrame:GetFrameLevel() + 10);
			item:Show();
		end
	end
	
	-- Create or get close frame for clicking outside (only create once)
	if ( not menuFrame.closeFrame ) then
		local closeFrame = CreateFrame("Frame", "$parentCloseFrame", UIParent);
		closeFrame:SetFrameStrata("FULLSCREEN_DIALOG");
		closeFrame:SetAllPoints();
		closeFrame:EnableMouse(true);
		closeFrame:EnableMouseWheel(false);
		-- Use OnMouseDown to check coordinates, but don't close until OnMouseUp
		-- This allows menu item OnClick to fire first
		closeFrame:SetScript("OnMouseDown", function(self, button)
			-- Store the button for later use
			self.downButton = button;
		end);
		closeFrame:SetScript("OnMouseUp", function(self, button)
			if ( (button == "LeftButton" or button == "RightButton") and self.downButton == button ) then
				-- Check what actually received the click
				local focus = GetMouseFocus();
				-- Check if focus is menuFrame or one of its children by checking parent chain
				local isMenuChild = false;
				if ( focus ) then
					if ( focus == menuFrame ) then
						isMenuChild = true;
					else
						-- Check parent chain manually (isAncestorOf not available in 3.3.5a)
						local parent = focus:GetParent();
						while ( parent ) do
							if ( parent == menuFrame ) then
								isMenuChild = true;
								break;
							end
							parent = parent:GetParent();
						end
					end
				end
				if ( not isMenuChild ) then
					-- Click was outside, close the menu
					menuFrame:Hide();
					self:Hide();
				end
			end
			self.downButton = nil;
		end);
		closeFrame:Hide();
		menuFrame.closeFrame = closeFrame;
	end
	
	-- Show close frame and menu frame
	if ( menuFrame.closeFrame ) then
		menuFrame.closeFrame:Show();
	end
	menuFrame:Show();
	
	-- Hide close frame when menu is hidden
	menuFrame:SetScript("OnHide", function(self)
		if ( self.closeFrame ) then
			self.closeFrame:Hide();
		end
	end);
end

function PlayerTalentFrameSpecDropdown_SelectSpec(specIndex)
	if ( not PlayerTalentFrame or PlayerTalentFrame.inspect or PlayerTalentFrame.pet ) then
		return;
	end
	
	-- Set the talent group to view this spec
	PlayerTalentFrame.talentGroup = specIndex;
	
	-- Set the selected spec number (this is what the dropdown controls)
	selectedSpecNumber = specIndex;
	
	-- Note: This does NOT change the active spec (activeSpecNumber remains unchanged)
	
	-- Refresh the talent frame to update the display with the new spec's data
	if ( type(PlayerTalentFrame_Refresh) == "function" ) then
		PlayerTalentFrame_Refresh();
	elseif ( type(TalentFrame_Update) == "function" ) then
		TalentFrame_Update(PlayerTalentFrame);
	end
	-- The active spec is only changed by the server message
	
	-- Update the dropdown text
	local dropdownButton = _G["PlayerTalentFrameSpecDropdown"];
	if ( dropdownButton and dropdownButton.text ) then
		dropdownButton.text:SetText(GetOrdinalSpecName(specIndex));
	end
	
	-- Update the title text to show the selected spec name
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	if ( selectedTab == GLYPH_TALENT_TAB ) then
		-- Update glyph title text with spec name (replace "Specialization" with "Glyphs")
		if ( GlyphFrameTitleText ) then
			local numTalentGroups = SpecMap_GetTalentGroupCount();
			if ( numTalentGroups > 1 ) then
				local specName = GetOrdinalSpecName(specIndex);
				local glyphTitle = string.gsub(specName, "Specialization", "Glyphs");
				GlyphFrameTitleText:SetText(glyphTitle);
			else
				GlyphFrameTitleText:SetText(GLYPHS);
			end
		end
	else
		-- Update talent frame title text
		if ( PlayerTalentFrameTitleText and PlayerTalentFrameTitleText:IsShown() ) then
			-- Check if viewing pet talents
			if ( PlayerTalentFrame.pet ) then
				PlayerTalentFrameTitleText:SetText("Pet Specialization");
			else
				local numTalentGroups = SpecMap_GetTalentGroupCount();
				if ( numTalentGroups > 1 ) then
					PlayerTalentFrameTitleText:SetText(GetOrdinalSpecName(specIndex));
				end
			end
		end
	end
	
	-- Refresh the talent frame to show the selected spec
	if ( type(PlayerTalentFrame_Refresh) == "function" ) then
		PlayerTalentFrame_Refresh();
	end
	
	-- Update menu colors to reflect the new selection
	if ( type(PlayerTalentFrameSpecDropdown_UpdateMenuColors) == "function" ) then
		PlayerTalentFrameSpecDropdown_UpdateMenuColors();
	end
end

function PlayerTalentFrameSpecDropdown_Update()
	local dropdownButton = _G["PlayerTalentFrameSpecDropdown"];
	if ( not dropdownButton ) then
		return;
	end
	
	-- Don't update if the menu is currently open (to prevent interference)
	local menuFrame = dropdownButton.menuFrame;
	if ( menuFrame and menuFrame:IsShown() ) then
		return;
	end
	
	if ( not PlayerTalentFrame or PlayerTalentFrame.inspect or PlayerTalentFrame.pet ) then
		dropdownButton:Hide();
		return;
	end
	
	-- Show dropdown for both talents and glyphs
	local selectedTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	-- Note: Position is set later based on status frame/activate button
	
	-- Adjust dropdown width when viewing glyphs (reduce by half)
	if ( selectedTab == GLYPH_TALENT_TAB ) then
		dropdownButton:SetWidth(75); -- Half of 150
	else
		dropdownButton:SetWidth(150); -- Full width for talents
	end
	
	local specMap = GetSpecMapTable();
	if ( specMap and type(specMap.specs) == "table" and (specMap.specCount or 0) > 0 ) then
		dropdownButton:Show();
		
		-- Initialize selectedSpecNumber if not set (prioritize activeSpecNumber from decoded message)
		-- Only initialize if it's nil - don't override user's selection
		-- Note: OnShow sets selectedSpecNumber to active spec, so this should rarely be nil
		if ( selectedSpecNumber == nil ) then
			if ( type(activeSpecNumber) == "number" and activeSpecNumber > 0 ) then
				-- Use activeSpecNumber from decoded message if available
				selectedSpecNumber = activeSpecNumber;
				-- Also update talentGroup to match
				if ( PlayerTalentFrame ) then
					PlayerTalentFrame.talentGroup = activeSpecNumber;
				end
			else
				-- Fallback to base game API
				local activeTalentGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
				if ( activeTalentGroup and activeTalentGroup > 0 ) then
					selectedSpecNumber = activeTalentGroup;
					if ( PlayerTalentFrame ) then
						PlayerTalentFrame.talentGroup = activeTalentGroup;
					end
				else
					-- Fallback to current talentGroup or default to 1
					selectedSpecNumber = PlayerTalentFrame.talentGroup or 1;
					if ( PlayerTalentFrame ) then
						PlayerTalentFrame.talentGroup = selectedSpecNumber;
					end
				end
			end
		end
		
		-- Update text to show current spec (use selectedSpecNumber, not activeSpecNumber)
		if ( dropdownButton.text ) then
			-- Always use selectedSpecNumber to show what the user is viewing, not what's active
			local currentSpec = selectedSpecNumber or PlayerTalentFrame.talentGroup or 1;
			dropdownButton.text:SetText(GetOrdinalSpecName(currentSpec));
			
			-- Set text color based on whether this spec is active
			-- Use global activeSpecNumber directly (from decoded message) - this is the most reliable source
			local isActiveSpec = false;
			
			-- Check activeSpecNumber first (from decoded message) - ensure we access the global variable
			-- Use explicit global access to avoid any scope issues
			local activeSpec = _G["activeSpecNumber"];
			if ( type(activeSpec) == "number" and activeSpec > 0 and type(currentSpec) == "number" ) then
				-- If activeSpecNumber is set from decoded message, use it exclusively
				isActiveSpec = (currentSpec == activeSpec);
			else
				-- Only check base game API as fallback if activeSpecNumber is not set
				local baseActiveTalentGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
				if ( baseActiveTalentGroup and baseActiveTalentGroup > 0 and type(currentSpec) == "number" ) then
					isActiveSpec = (currentSpec == baseActiveTalentGroup);
				end
			end
			
			-- Set the text color based on whether the current spec is active
			if ( isActiveSpec ) then
				dropdownButton.text:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, 1); -- Green for active spec
			else
				dropdownButton.text:SetTextColor(1.0, 0.82, 0, 1.0); -- Yellow for inactive specs
			end
		end
		
		-- Position dropdown based on whether viewing glyphs or talents
		if ( selectedTab == GLYPH_TALENT_TAB ) then
			-- When viewing glyphs: position at top left of frame, 2px above background texture, aligned with left edge
			dropdownButton:ClearAllPoints();
			dropdownButton:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPLEFT", 19, -24); -- 2px above background texture, left aligned
			
			-- Ensure dropdown button is above glyph frame
			if ( GlyphFrame and GlyphFrame:IsShown() ) then
				local glyphFrameLevel = GlyphFrame:GetFrameLevel();
				dropdownButton:SetFrameLevel(glyphFrameLevel + 1);
				-- Menu frame is already set to FULLSCREEN_DIALOG with high frame level in ShowMenu
			else
				-- If glyph frame exists but isn't shown yet, use a high frame level
				dropdownButton:SetFrameLevel(PlayerTalentFrame:GetFrameLevel() + 5);
			end
		else
			-- Fallback: position at frame top right
			dropdownButton:ClearAllPoints();
			dropdownButton:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPLEFT", 29, -24);
		end
	else
		dropdownButton:Hide();
	end
end