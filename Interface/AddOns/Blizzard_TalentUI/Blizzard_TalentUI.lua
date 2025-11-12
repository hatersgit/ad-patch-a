local SpecMapTalentCache;
local SpecMap_TalentCacheEnsureReady;

function ResolveBaseTalentGroup(talentGroup)
	if ( type(SpecMap_ResolveTalentGroupForBaseAPI) == "function" ) then
		return SpecMap_ResolveTalentGroupForBaseAPI(talentGroup);
	end
	if ( type(talentGroup) == "number" and talentGroup >= 1 ) then
		return talentGroup;
	end
	return 1;
end

local function SpecMap_GetTalentTierFromGame(talentGroup, tabIndex, talentId)
	if ( not talentId ) then
		return nil;
	end
	local numTalents = GetNumTalents(tabIndex, false, false);
	for index = 1, numTalents do
		local link = GetTalentLink(tabIndex, index, false, false, ResolveBaseTalentGroup(talentGroup));
		local linkTalentId = nil;
		if ( type(link) == "string" ) then
			linkTalentId = tonumber(string.match(link, "Htalent:(%d+)") or string.match(link, "talent:(%d+)"));
		end
		if ( linkTalentId == talentId ) then
			local _, _, tier = GetTalentInfo(tabIndex, index, false, false, ResolveBaseTalentGroup(talentGroup));
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
				local talentLink = GetTalentLink(tabIndex, talentIndex, false, false, ResolveBaseTalentGroup(talentGroup), false);
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

UIPanelWindows["PlayerTalentFrame"] = { area = "left", pushable = 1, whileDead = 1 };

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
local specTreeTotals = {};
local pendingActiveSpecSelection = nil;
local glyphViewActive = false;

local playerSpecTabFrames = {};

local function EnsureTalentSpecCacheEntry(specKey)
	if ( not talentSpecInfoCache[specKey] ) then
		talentSpecInfoCache[specKey] = {};
	end
end

local function EnsureSpecInTalentSortOrder(specKey)
	if ( type(TALENT_SORT_ORDER) ~= "table" ) then
		TALENT_SORT_ORDER = {};
	end
	for i = 1, #TALENT_SORT_ORDER do
		if ( TALENT_SORT_ORDER[i] == specKey ) then
			return;
		end
	end
	-- Insert player specs before pet specs to keep ordering predictable
	if ( type(specKey) == "string" and string.sub(specKey, 1, 7) ~= "petspec" ) then
		local inserted = false;
		for i = 1, #TALENT_SORT_ORDER do
			local key = TALENT_SORT_ORDER[i];
			if ( type(key) == "string" and string.sub(key, 1, 7) == "petspec" ) then
				table.insert(TALENT_SORT_ORDER, i, specKey);
				inserted = true;
				break;
			end
		end
		if ( not inserted ) then
			table.insert(TALENT_SORT_ORDER, specKey);
		end
	else
		table.insert(TALENT_SORT_ORDER, specKey);
	end
end

local function EnsurePlayerSpecDefinition(specIndex)
	local specKey = "spec"..specIndex;
	if ( not specs[specKey] ) then
		-- Create a default spec definition for additional specializations
		local ordinalName = GetOrdinalSpecName(specIndex);
		specs[specKey] = {
			name = ordinalName,
			talentGroup = specIndex,
			unit = "player",
			pet = false,
			tooltip = ordinalName,
			portraitUnit = "player",
			defaultSpecTexture = "Interface\\Icons\\Ability_Marksmanship",
			hasGlyphs = true,
			glyphName = ordinalName,
		};
	else
		-- Ensure existing definition stays in sync with the spec index
		specs[specKey].talentGroup = specIndex;
		specs[specKey].unit = "player";
		specs[specKey].pet = false;
		specs[specKey].hasGlyphs = true;
		if ( not specs[specKey].name ) then
			specs[specKey].name = GetOrdinalSpecName(specIndex);
		end
		if ( not specs[specKey].tooltip ) then
			specs[specKey].tooltip = specs[specKey].name;
		end
		if ( not specs[specKey].glyphName ) then
			specs[specKey].glyphName = specs[specKey].name;
		end
	end

	EnsureTalentSpecCacheEntry(specKey);

	if ( not specTreeTotals[specKey] ) then
		specTreeTotals[specKey] = { 0, 0, 0 };
	end

	EnsureSpecInTalentSortOrder(specKey);

	return specKey;
end

local function EnsurePlayerSpecTab(specIndex)
	local specKey = "spec"..specIndex;
	if ( specTabs[specKey] ) then
		playerSpecTabFrames[specIndex] = specTabs[specKey];
		return specTabs[specKey];
	end

	if ( not PlayerTalentFrame ) then
		return nil;
	end

	local nextIndex = numSpecTabs + 1;
	while ( _G["PlayerSpecTab"..nextIndex] ) do
		nextIndex = nextIndex + 1;
	end

	local frameName = "PlayerSpecTab"..nextIndex;
	local frame = CreateFrame("CheckButton", frameName, PlayerTalentFrame, "PlayerSpecTabTemplate");
	-- Anchor temporarily; PlayerTalentFrame_UpdateSpecs will reposition it properly
	frame:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPRIGHT", -32, -65 - ((specIndex - 1) * 22));

	PlayerSpecTab_Load(frame, specKey);
	playerSpecTabFrames[specIndex] = frame;

	return frame;
end

local function HideUnusedPlayerSpecTabs(specCount)
	for index, frame in pairs(playerSpecTabFrames) do
		if ( frame and index > specCount ) then
			frame:Hide();
			frame:SetChecked(false);
		end
	end
end

local function PlayerTalentFrame_GetOrderedSpecTabs()
	local playerTabs = {};
	local petTabs = {};

	for specKey, frame in pairs(specTabs) do
		if ( frame ) then
			local spec = specs[specKey];
			if ( spec ) then
				if ( spec.pet ) then
					table.insert(petTabs, frame);
				else
					table.insert(playerTabs, frame);
				end
			end
		end
	end

	table.sort(playerTabs, function(a, b)
		local specA = specs[a.specIndex];
		local specB = specs[b.specIndex];
		local groupA = specA and specA.talentGroup or 0;
		local groupB = specB and specB.talentGroup or 0;
		return groupA < groupB;
	end);

	table.sort(petTabs, function(a, b)
		local specA = specs[a.specIndex];
		local specB = specs[b.specIndex];
		local groupA = specA and specA.talentGroup or 0;
		local groupB = specB and specB.talentGroup or 0;
		return groupA < groupB;
	end);

	local ordered = {};
	for _, frame in ipairs(playerTabs) do
		table.insert(ordered, frame);
	end
	for _, frame in ipairs(petTabs) do
		table.insert(ordered, frame);
	end
	return ordered;
end

local function PlayerTalentFrame_UpdateSpecTabChecks()
	for key, frame in pairs(specTabs) do
		if ( frame ) then
			if ( key == selectedSpec ) then
				frame:SetChecked(1);
			else
				frame:SetChecked(nil);
			end
		end
	end
end

local function TalentFrame_GetInspectFlag()
	if ( PlayerTalentFrame and PlayerTalentFrame.inspect ) then
		return 1;
	end
	return nil;
end

local function TalentFrame_GetPetFlag()
	if ( PlayerTalentFrame and PlayerTalentFrame.pet ) then
		return 1;
	end
	return nil;
end

local function PlayerTalentFrame_SelectSpecByKey(specKey, suppressRefresh)
	if ( not PlayerTalentFrame ) then
		return;
	end

	local spec = specs[specKey];
	if ( not spec ) then
		return;
	end

	local glyphTabSelected = (PanelTemplates_GetSelectedTab(PlayerTalentFrame) == GLYPH_TALENT_TAB);

	selectedSpec = specKey;

	if ( spec.pet ) then
		PlayerTalentFrame.pet = 1;
		PlayerTalentFrame.inspect = nil;
		PlayerTalentFrame.unit = spec.unit or "pet";
		PlayerTalentFrame.talentGroup = spec.talentGroup;
	else
		PlayerTalentFrame.pet = nil;
		PlayerTalentFrame.inspect = nil;
		PlayerTalentFrame.unit = spec.unit or "player";
		PlayerTalentFrame.talentGroup = spec.talentGroup;
		selectedSpecNumber = spec.talentGroup;
	end

	PlayerTalentFrame_UpdateSpecTabChecks();

	if ( glyphTabSelected and not spec.pet ) then
		PanelTemplates_SetTab(PlayerTalentFrame, GLYPH_TALENT_TAB);
		if ( type(PlayerTalentFrame_ShowGlyphFrame) == "function" ) then
			PlayerTalentFrame_ShowGlyphFrame();
		end
	else
		if ( PanelTemplates_GetSelectedTab(PlayerTalentFrame) ~= 1 ) then
			PanelTemplates_SetTab(PlayerTalentFrame, 1);
		end
		if ( type(PlayerTalentFrame_HideGlyphFrame) == "function" ) then
			PlayerTalentFrame_HideGlyphFrame();
		end
	end

	if ( not suppressRefresh ) then
		PlayerTalentFrame_Refresh();
	end
end



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
	specTreeTotals = {};
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
		local baseTalentGroup = ResolveBaseTalentGroup(talentGroup);
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
				local talentLink = GetTalentLink(tabId, talentIndex, false, false, baseTalentGroup, false);
				if ( talentLink ) then
					local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
					if ( talentId ) then
						-- Get talent info
						local name, iconTexture, tier, column = GetTalentInfo(tabId, talentIndex, false, false, baseTalentGroup);
						
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
						local prereqTier, prereqColumn = GetTalentPrereqs(tabId, talentIndex, false, false, baseTalentGroup);
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
								local prereqTalentLink = GetTalentLink(tabId, prereqTalentIndex, false, false, baseTalentGroup, false);
								if ( prereqTalentLink ) then
									local prereqTalentId = SpecMap_TalentCacheExtractTalentID(prereqTalentLink);
									local _, _, _, _, _, maxRank = GetTalentInfo(tabId, prereqTalentIndex, false, false, baseTalentGroup);
									
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
										local prereqTalentLink = GetTalentLink(tabIndex, prereqTalentIndex, false, false, baseTalentGroup, false);
										if ( prereqTalentLink ) then
											local prereqTalentId = SpecMap_TalentCacheExtractTalentID(prereqTalentLink);
											local _, _, _, _, _, maxRank = GetTalentInfo(tabIndex, prereqTalentIndex, false, false, baseTalentGroup);
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
			if ( active < 1 ) then
				active = 1;
			elseif ( active > count ) then
				active = ((active - 1) % count) + 1;
			end
			return active;
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
	local specCount = numTalentGroups;
	if ( specMap and type(specMap.activeSpec) == "number" ) then
		-- specMap.activeSpec is already 1-based (converted in DecodeSpecInfo)
		activeSpecNumber = specMap.activeSpec;
	else
		activeSpecNumber = activeTalentGroup;
	end

	if ( specMap and type(specMap.specCount) == "number" ) then
		specCount = specMap.specCount;
	end

	-- Ensure we have spec definitions and tabs for each available specialization
	if ( specCount and specCount > 0 ) then
		for index = 1, specCount do
			local specData = specMap and specMap.specs and specMap.specs[index] or nil;
			local totals = { 0, 0, 0 };
			if ( specData and type(specData.talents) == "table" ) then
				for _, talentData in ipairs(specData.talents) do
					local tabId = tonumber(talentData.tabId or talentData.tab or talentData.tabIndex);
					local rank = tonumber(talentData.rank);
					if ( tabId ) then
						tabId = tabId + 1;
						if ( tabId >= 1 and tabId <= 3 and rank and rank >= 0 ) then
							totals[tabId] = (totals[tabId] or 0) + (rank + 1);
						end
					end
				end
			end
			specTreeTotals["spec" .. index] = totals;
			EnsurePlayerSpecDefinition(index);
			EnsurePlayerSpecTab(index);
		end
		for key in pairs(specTreeTotals) do
			local idx = tonumber(string.match(key or "", "^spec(%d+)$"));
			if ( idx and idx > specCount ) then
				specTreeTotals[key] = nil;
			end
		end
		HideUnusedPlayerSpecTabs(specCount);
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

	if ( type(specCount) == "number" and specCount > 0 ) then
		if ( selectedSpecNumber and selectedSpecNumber > specCount ) then
			selectedSpecNumber = specCount;
		elseif ( not selectedSpecNumber ) then
			selectedSpecNumber = (activeSpecNumber and activeSpecNumber <= specCount) and activeSpecNumber or 1;
		end

		if ( selectedSpecNumber ) then
			selectedSpec = "spec"..selectedSpecNumber;
		end
	end

	PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups);
	
	PlayerTalentFrame_UpdateSpecTabChecks();

	if ( PlayerTalentFrame:IsShown() ) then
		local targetSpecIndex = selectedSpecNumber or activeSpecNumber or 1;
		PlayerTalentFrame_SelectSpecByKey("spec"..targetSpecIndex, true);
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
		-- Ensure we're viewing a player spec when showing glyphs
		if ( PlayerTalentFrame.pet ) then
			local targetSpecNumber = selectedSpecNumber or SpecMap_GetActiveTalentGroup() or 1;
			PlayerTalentFrame_SelectSpecByKey("spec" .. targetSpecNumber, true);
		end

		if ( GLYPH_VIEW_TALENT_FRAME_WIDTH == nil or GLYPH_VIEW_TALENT_FRAME_HEIGHT == nil ) then
			local glyphWidth = GlyphFrame and GlyphFrame:GetWidth();
			local glyphHeight = GlyphFrame and GlyphFrame:GetHeight();
			local baseWidth = PlayerTalentFrame.originalWidth or PlayerTalentFrame:GetWidth();
			local baseHeight = PlayerTalentFrame.originalHeight or PlayerTalentFrame:GetHeight();

			if ( glyphWidth and glyphWidth > 0 ) then
				GLYPH_VIEW_TALENT_FRAME_WIDTH = glyphWidth;
			else
				GLYPH_VIEW_TALENT_FRAME_WIDTH = baseWidth;
			end

			if ( glyphHeight and glyphHeight > 0 ) then
				local targetHeight = baseHeight + (glyphHeight - baseHeight) * 0.5;
				if ( targetHeight < baseHeight ) then
					targetHeight = baseHeight;
				end
				GLYPH_VIEW_TALENT_FRAME_HEIGHT = math.floor(targetHeight + 0.5);
			else
				GLYPH_VIEW_TALENT_FRAME_HEIGHT = baseHeight;
			end
		end

		PlayerTalentFrame:SetWidth(GLYPH_VIEW_TALENT_FRAME_WIDTH);
		PlayerTalentFrame:SetHeight(GLYPH_VIEW_TALENT_FRAME_HEIGHT);
		PlayerTalentFrame:SetAttribute("UIPanelLayout-width", GLYPH_VIEW_TALENT_FRAME_WIDTH);
		PlayerTalentFrame:SetAttribute("UIPanelLayout-height", GLYPH_VIEW_TALENT_FRAME_HEIGHT);
		if ( GlyphFrame ) then
			GlyphFrame:SetParent(GlyphFrame.originalParent or PlayerTalentFrame);
			GlyphFrame:ClearAllPoints();
			if ( GlyphFrame.originalPoints ) then
				for _, pointData in ipairs(GlyphFrame.originalPoints) do
					GlyphFrame:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.offsetX, pointData.offsetY);
				end
			else
				GlyphFrame:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPLEFT", 11, -12);
				GlyphFrame:SetPoint("BOTTOMRIGHT", PlayerTalentFrame, "BOTTOMRIGHT", -32, 76);
			end
		end

		-- Hide the talent frame title text when viewing glyphs
		if ( PlayerTalentFrameTitleText ) then
			PlayerTalentFrameTitleText:Show();
			PlayerTalentFrameTitleText:ClearAllPoints();
			PlayerTalentFrameTitleText:SetPoint("TOP", PlayerTalentFrame, "TOP", 0, -18);
		end
		if ( GlyphFrameTitleText ) then
			GlyphFrameTitleText:Hide();
		end
		if ( PlayerTalentFrameGridContainer ) then
			PlayerTalentFrameGridContainer:Hide();
		end
		if ( PlayerTalentFrameTalents ) then
			PlayerTalentFrameTalents:Hide();
		end
		if ( PlayerTalentFrameScrollFrame ) then
			PlayerTalentFrameScrollFrame:Hide();
		end
		if ( PlayerTalentFramePointsBar ) then
			PlayerTalentFramePointsBar:Hide();
		end
		if ( PlayerTalentFramePreviewBar ) then
			PlayerTalentFramePreviewBar:Hide();
		end
		if ( PlayerTalentFrameStatusFrame ) then
			PlayerTalentFrameStatusFrame:Show();
			PlayerTalentFrameStatusFrame:ClearAllPoints();
			if ( PlayerTalentFrameStatusFrame.originalPoints ) then
				for _, pointData in ipairs(PlayerTalentFrameStatusFrame.originalPoints) do
					PlayerTalentFrameStatusFrame:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.offsetX, pointData.offsetY);
				end
			else
				PlayerTalentFrameStatusFrame:SetPoint("TOP", PlayerTalentFramePointsBar or PlayerTalentFrame, "BOTTOM", 0, -12);
			end
		end
		if ( PlayerTalentFrameActivateButton ) then
			PlayerTalentFrameActivateButton:Show();
			PlayerTalentFrameActivateButton:ClearAllPoints();
			if ( PlayerTalentFrameActivateButton.originalPoints ) then
				for _, pointData in ipairs(PlayerTalentFrameActivateButton.originalPoints) do
					PlayerTalentFrameActivateButton:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.offsetX, pointData.offsetY);
				end
			else
				PlayerTalentFrameActivateButton:SetPoint("RIGHT", PlayerTalentFrameStatusFrame or PlayerTalentFramePointsBar or PlayerTalentFrame, "LEFT", -5, 0);
			end
		end
		if ( PlayerTalentFrame.DisableDrawLayer ) then
			PlayerTalentFrame:DisableDrawLayer("BACKGROUND");
			PlayerTalentFrame:DisableDrawLayer("BORDER");
		end

		glyphViewActive = true;

		-- set the title text of the GlyphFrame
		-- Use spec name with "Glyphs" instead of "Specialization"
		local numTalentGroups;
		if ( PlayerTalentFrame.inspect ) then
			numTalentGroups = GetNumTalentGroups();
		else
			numTalentGroups = SpecMap_GetTalentGroupCount();
		end
		
		local specNumber = selectedSpecNumber or PlayerTalentFrame.talentGroup or activeSpecNumber or SpecMap_GetActiveTalentGroup() or GetActiveTalentGroup(false, false) or 1;
		if ( specNumber < 1 ) then
			specNumber = 1;
		end
		if ( numTalentGroups and numTalentGroups > 1 ) then
			local specName = GetOrdinalSpecName(specNumber);
			local glyphTitle = string.gsub(specName, "Specialization", "Glyphs");
			PlayerTalentFrameTitleText:SetText(glyphTitle);
		else
			PlayerTalentFrameTitleText:SetText(GLYPHS);
		end
		
		-- show/update the glyph frame
		if ( GlyphFrame:IsShown() ) then
			GlyphFrame_Update();
		else
			GlyphFrame:Show();
		end

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
		
		-- Update glyph title text when switching specs
		if ( GlyphFrame and GlyphFrame:IsShown() and PlayerTalentFrameTitleText ) then
			local specNumber = selectedSpecNumber or PlayerTalentFrame.talentGroup or activeSpecNumber or SpecMap_GetActiveTalentGroup() or GetActiveTalentGroup(false, false) or 1;
			if ( specNumber < 1 ) then
				specNumber = 1;
			end
			if ( numTalentGroups and numTalentGroups > 1 ) then
				local specName = GetOrdinalSpecName(specNumber);
				local glyphTitle = string.gsub(specName, "Specialization", "Glyphs");
				PlayerTalentFrameTitleText:SetText(glyphTitle);
			else
				PlayerTalentFrameTitleText:SetText(GLYPHS);
			end
		else
			PlayerTalentFrameTitleText:SetText(TALENTS);
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
	
	if ( PlayerTalentFrame.originalWidth and PlayerTalentFrame.originalHeight ) then
		PlayerTalentFrame:SetWidth(PlayerTalentFrame.originalWidth);
		PlayerTalentFrame:SetHeight(PlayerTalentFrame.originalHeight);
		PlayerTalentFrame:SetAttribute("UIPanelLayout-width", PlayerTalentFrame.originalUIPanelLayoutWidth or PlayerTalentFrame.originalWidth);
		PlayerTalentFrame:SetAttribute("UIPanelLayout-height", PlayerTalentFrame.originalUIPanelLayoutHeight or PlayerTalentFrame.originalHeight);
		if ( GlyphFrame ) then
			GlyphFrame:SetParent(GlyphFrame.originalParent or PlayerTalentFrame);
			GlyphFrame:ClearAllPoints();
			if ( GlyphFrame.originalPoints ) then
				for _, pointData in ipairs(GlyphFrame.originalPoints) do
					GlyphFrame:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.offsetX, pointData.offsetY);
				end
			else
				GlyphFrame:SetPoint("TOPLEFT", PlayerTalentFrame, "TOPLEFT", 11, -12);
				GlyphFrame:SetPoint("BOTTOMRIGHT", PlayerTalentFrame, "BOTTOMRIGHT", -32, 76);
			end
		end
		local backdropFrame = _G["PlayerTalentFrameBackdrop"];
		if ( backdropFrame and backdropFrame.originalPoints ) then
			backdropFrame:SetParent(backdropFrame.originalParent or PlayerTalentFrame);
			backdropFrame:ClearAllPoints();
			for _, pointData in ipairs(backdropFrame.originalPoints) do
				backdropFrame:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.offsetX, pointData.offsetY);
			end
			backdropFrame:Show();
		end
		if ( PlayerTalentFrame.backgroundTextures and PlayerTalentFrame.originalBackgroundPoints ) then
			for index, texture in ipairs(PlayerTalentFrame.backgroundTextures) do
				if ( texture ) then
					texture:SetParent(PlayerTalentFrame);
					texture:ClearAllPoints();
					local pointDataTable = PlayerTalentFrame.originalBackgroundPoints[index];
					if ( pointDataTable ) then
						for _, pointData in ipairs(pointDataTable) do
							texture:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.offsetX, pointData.offsetY);
						end
					end
					texture:Show();
				end
			end
		end
	end
	if ( UIPanelWindows and UIPanelWindows[PlayerTalentFrame:GetName()] ) then
		local panelInfo = UIPanelWindows[PlayerTalentFrame:GetName()];
		if ( panelInfo ) then
			panelInfo.width = PlayerTalentFrame.originalUIPanelWidth or panelInfo.width;
			panelInfo.height = PlayerTalentFrame.originalUIPanelHeight or panelInfo.height;
		end
	end
	if ( type(UpdateUIPanelPositions) == "function" ) then
		UpdateUIPanelPositions(PlayerTalentFrame);
	end

	GLYPH_VIEW_TALENT_FRAME_WIDTH = nil;
	GLYPH_VIEW_TALENT_FRAME_HEIGHT = nil;

	-- Show the talent frame title text when hiding glyphs
	if ( PlayerTalentFrameTitleText ) then
		PlayerTalentFrameTitleText:Show();
		PlayerTalentFrameTitleText:ClearAllPoints();
		PlayerTalentFrameTitleText:SetPoint("TOP", PlayerTalentFrame, "TOP", 0, -18);
		PlayerTalentFrameTitleText:SetText(TALENTS);
	end
	if ( GlyphFrameTitleText ) then
		GlyphFrameTitleText:Hide();
	end
	if ( PlayerTalentFrameGridContainer ) then
		PlayerTalentFrameGridContainer:Show();
	end
	if ( PlayerTalentFrameTalents ) then
		PlayerTalentFrameTalents:Show();
	end
	if ( PlayerTalentFrameScrollFrame ) then
		PlayerTalentFrameScrollFrame:Show();
	end
	if ( PlayerTalentFramePointsBar ) then
		PlayerTalentFramePointsBar:Show();
	end
	if ( PlayerTalentFrameStatusFrame ) then
		PlayerTalentFrameStatusFrame:Show();
	end
	if ( PlayerTalentFramePreviewBar ) then
		PlayerTalentFramePreviewBar:Show();
	end
	if ( PlayerTalentFrameActivateButton ) then
		PlayerTalentFrameActivateButton:Show();
	end
	if ( PlayerTalentFrame.EnableDrawLayer ) then
		PlayerTalentFrame:EnableDrawLayer("BACKGROUND");
		PlayerTalentFrame:EnableDrawLayer("BORDER");
	end

	glyphViewActive = false;
end


function PlayerTalentFrame_OnLoad(self)
	-- Set scale to baseline (1.0) to ensure proper alignment with GlyphFrame
	self:SetScale(1.0);
	self.originalWidth = self.originalWidth or self:GetWidth();
	self.originalHeight = self.originalHeight or self:GetHeight();
	self.originalUIPanelLayoutWidth = self.originalUIPanelLayoutWidth or self:GetAttribute("UIPanelLayout-width");
	self.originalUIPanelLayoutHeight = self.originalUIPanelLayoutHeight or self:GetAttribute("UIPanelLayout-height");
	if ( UIPanelWindows and UIPanelWindows[self:GetName()] ) then
		local panelInfo = UIPanelWindows[self:GetName()];
		if ( panelInfo ) then
			self.originalUIPanelWidth = self.originalUIPanelWidth or panelInfo.width;
			self.originalUIPanelHeight = self.originalUIPanelHeight or panelInfo.height;
		end
	end
	
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
	backdropFrame.originalParent = self;
	backdropFrame.originalPoints = {};
	for i = 1, backdropFrame:GetNumPoints() do
		local point, relativeTo, relativePoint, offsetX, offsetY = backdropFrame:GetPoint(i);
		backdropFrame.originalPoints[i] = {
			point = point,
			relativeTo = relativeTo,
			relativePoint = relativePoint,
			offsetX = offsetX,
			offsetY = offsetY,
		};
	end
	
	self.backgroundTextures = {
		PlayerTalentFrameBackgroundTopLeft,
		PlayerTalentFrameBackgroundTopRight,
		PlayerTalentFrameBackgroundBottomLeft,
		PlayerTalentFrameBackgroundBottomRight,
	};
	self.originalBackgroundPoints = {};
	for index, texture in ipairs(self.backgroundTextures) do
		if ( texture ) then
			self.originalBackgroundPoints[index] = {};
			for i = 1, texture:GetNumPoints() do
				local point, relativeTo, relativePoint, offsetX, offsetY = texture:GetPoint(i);
				self.originalBackgroundPoints[index][i] = {
					point = point,
					relativeTo = relativeTo,
					relativePoint = relativePoint,
					offsetX = offsetX,
					offsetY = offsetY,
				};
			end
		end
	end
	
	-- Clear base textures from status frame, points bar, preview bar, close button, and spec tabs
	if ( PlayerTalentFrameStatusFrame ) then
		ClearBaseTextures(PlayerTalentFrameStatusFrame);
		PlayerTalentFrameStatusFrame.originalPoints = {};
		for i = 1, PlayerTalentFrameStatusFrame:GetNumPoints() do
			local point, relativeTo, relativePoint, offsetX, offsetY = PlayerTalentFrameStatusFrame:GetPoint(i);
			PlayerTalentFrameStatusFrame.originalPoints[i] = {
				point = point,
				relativeTo = relativeTo,
				relativePoint = relativePoint,
				offsetX = offsetX,
				offsetY = offsetY,
			};
		end
	end
	if ( PlayerTalentFramePointsBar ) then
		ClearBaseTextures(PlayerTalentFramePointsBar);
	end
	if ( PlayerTalentFramePreviewBar ) then
		ClearBaseTextures(PlayerTalentFramePreviewBar);
	end
	if ( PlayerTalentFrameActivateButton ) then
		PlayerTalentFrameActivateButton.originalPoints = {};
		for i = 1, PlayerTalentFrameActivateButton:GetNumPoints() do
			local point, relativeTo, relativePoint, offsetX, offsetY = PlayerTalentFrameActivateButton:GetPoint(i);
			PlayerTalentFrameActivateButton.originalPoints[i] = {
				point = point,
				relativeTo = relativeTo,
				relativePoint = relativePoint,
				offsetX = offsetX,
				offsetY = offsetY,
			};
		end
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
	
	-- Create Reset button on the far left of the points bar
	if ( not _G["PlayerTalentFramePointsBarResetButton"] ) then
		local resetButton = CreateFrame("Button", "PlayerTalentFramePointsBarResetButton", _G["PlayerTalentFramePointsBar"], "UIPanelButtonTemplate");
		resetButton:SetSize(60, 22);
		resetButton:SetPoint("LEFT", _G["PlayerTalentFramePointsBar"], "LEFT", 8, 0);
		resetButton:SetText("Reset");
		
		-- Set button scripts
		resetButton:SetScript("OnClick", function(self, button)
			if ( button == "LeftButton" ) then
				local previousSpecKey = selectedSpec;
				local previousSelectedNumber = selectedSpecNumber;
				local previousFrameGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup or nil;
				local previousTab = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
				-- Send message to server with opcode 10
				local resetOpCode = 10;
				local fullMessage = string.format("%d|", resetOpCode);
				PushMessageToServer(fullMessage);
				if ( previousSpecKey ) then
					selectedSpec = previousSpecKey;
				end
				if ( type(previousSelectedNumber) == "number" and previousSelectedNumber > 0 ) then
					selectedSpecNumber = previousSelectedNumber;
				end
				if ( PlayerTalentFrame ) then
					if ( type(previousFrameGroup) == "number" and previousFrameGroup > 0 ) then
						PlayerTalentFrame.talentGroup = previousFrameGroup;
					end
					if ( type(previousTab) == "number" ) then
						PanelTemplates_SetTab(PlayerTalentFrame, previousTab);
					end
				end
				PlayerTalentFrame_UpdateSpecTabChecks();
				if ( type(PlayerTalentFrame_Refresh) == "function" ) then
					PlayerTalentFrame_Refresh();
				end
				if ( PlayerTalentFrame and previousSpecKey and specTabs[previousSpecKey] ) then
					specTabs[previousSpecKey]:SetChecked(true);
				end
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
		local specMapReady = SpecMap_TalentCacheIsReady and SpecMap_TalentCacheIsReady() or false;
		local activeSpecNum = SpecMap_GetActiveTalentGroup();
		if ( type(activeSpecNum) ~= "number" or activeSpecNum <= 0 ) then
			activeSpecNum = GetActiveTalentGroup(self.inspect, self.pet);
			if ( not activeSpecNum or activeSpecNum <= 0 ) then
				activeSpecNum = 1;
			end
		end

		selectedSpecNumber = activeSpecNum;
		selectedSpec = "spec" .. selectedSpecNumber;
		self.talentGroup = selectedSpecNumber;
		pendingActiveSpecSelection = selectedSpecNumber;

		if ( specMapReady ) then
			PlayerTalentFrame_SelectSpecByKey("spec"..selectedSpecNumber, true);
			PlayerTalentFrame_Refresh();
			pendingActiveSpecSelection = nil;
		end
	else
		-- For pet/inspect, use the old spec tab system
		if ( not selectedSpec ) then
			-- if no spec was selected, try to select the active one
			PlayerSpecTab_OnClick(specTabs[activeSpec]);
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
			local numPetTalentGroups = GetNumTalentGroups(false, true) or 0;
			if ( numPetTalentGroups == 0 ) then
				local targetSpec = SpecMap_GetActiveTalentGroup();
				if ( type(targetSpec) ~= "number" or targetSpec <= 0 ) then
					targetSpec = GetActiveTalentGroup(false, false);
					if ( not targetSpec or targetSpec <= 0 ) then
						targetSpec = 1;
					end
				end
				selectedSpecNumber = targetSpec;
				selectedSpec = "spec" .. targetSpec;
				pendingActiveSpecSelection = nil;
				PlayerTalentFrame_SelectSpecByKey("spec" .. targetSpec, true);
				PlayerTalentFrame_Refresh();
				return;
			end
			if ( selectedSpec and specs[selectedSpec].pet ) then
				PlayerTalentFrame_Refresh();
				return;
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
	local shouldUpdateTalentFrame = false;
	if ( selectedTab == GLYPH_TALENT_TAB ) then
		PlayerTalentFrame_ShowGlyphFrame();
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
	else
		PlayerTalentFrame_HideGlyphFrame();
		-- Update the talent frame display when viewing talents
		shouldUpdateTalentFrame = true;
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
	
	if ( shouldUpdateTalentFrame and type(TalentFrame_Update) == "function" ) then
		TalentFrame_Update(PlayerTalentFrame);
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
	
end

function PlayerTalentFrame_UpdateActiveSpec(activeTalentGroup, numTalentGroups)
	-- set the active spec
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
-			PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
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
			local resolvedGroup = ResolveBaseTalentGroup(PlayerTalentFrame.talentGroup);
			local talentLink = GetTalentLink(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, resolvedGroup, GetCVarBool("previewTalents"));
			local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
			local _, _, tier, column, _, maxRank, _, meetsPrereq = GetTalentInfo(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, resolvedGroup);
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
            local resolvedGroup = ResolveBaseTalentGroup(PlayerTalentFrame.talentGroup);
            local talentLink = GetTalentLink(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, resolvedGroup, GetCVarBool("previewTalents"));
            local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
			local _, _, tier, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, resolvedGroup);
			
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
		local resolvedGroup = ResolveBaseTalentGroup(PlayerTalentFrame.talentGroup);
		GameTooltip:SetTalent(PanelTemplates_GetSelectedTab(PlayerTalentFrame), self:GetID(),
-			PlayerTalentFrame.inspect, PlayerTalentFrame.pet, PlayerTalentFrame.talentGroup, GetCVarBool("previewTalents"));
	end
end

function PlayerTalentFrameTalent_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	
	local tabIndex = PanelTemplates_GetSelectedTab(PlayerTalentFrame);
	local talentIndex = self:GetID();
	local talentGroup = PlayerTalentFrame.talentGroup;
	local baseTalentGroup = ResolveBaseTalentGroup(talentGroup);
	
	-- For player talents, get the current rank from SpecMap cache and show tooltip with that rank
	if ( not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
		-- Get base talent link (rank 0, which is rank -1 in the link format)
		local baseLink = GetTalentLink(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, baseTalentGroup, false);
		local talentId = SpecMap_TalentCacheExtractTalentID(baseLink);
		
		if ( talentId and type(SpecMap_TalentCacheGetRank) == "function" ) then
			local currentRank = SpecMap_TalentCacheGetRank(talentGroup, tabIndex, talentId) or 0;
			
			-- Get talent name for the link
			local talentName = GetTalentInfo(tabIndex, talentIndex, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, baseTalentGroup);
			
			if ( talentName and currentRank > 0 ) then
				-- Construct hyperlink with correct rank
				-- Rank format: -1 = rank 0, 0 = rank 1, 1 = rank 2, etc.
				-- So rankNum = currentRank - 1
				local rankNum = currentRank - 1;
				local talentLink = "|cff4e96f7|Htalent:"..talentId..":"..rankNum.."|h["..talentName.."]|h|r";
				GameTooltip:SetHyperlink(talentLink);
			else
				-- Rank is 0 or no name, use normal SetTalent
				GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame_GetInspectFlag(), TalentFrame_GetPetFlag(), baseTalentGroup, false);
			end
		else
			-- Fallback to normal SetTalent
			GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame_GetInspectFlag(), TalentFrame_GetPetFlag(), baseTalentGroup, false);
		end
	else
		-- For pet/inspect, use normal SetTalent
		GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame_GetInspectFlag(), TalentFrame_GetPetFlag(), baseTalentGroup, GetCVarBool("previewTalents"));
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
			end
			local anchor = PlayerTalentFrameTitleText or PlayerTalentFrame;
			PlayerTalentFrameActivateButton:ClearAllPoints();
			PlayerTalentFrameActivateButton:SetPoint("TOP", anchor, "BOTTOM", 0, -8);
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
					local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(i, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, ResolveBaseTalentGroup(PlayerTalentFrame.talentGroup));
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
					local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(i, PlayerTalentFrame.inspect, PlayerTalentFrame.pet, ResolveBaseTalentGroup(PlayerTalentFrame.talentGroup));
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
	PlayerTalentFrameActiveSpecTabHighlight:Hide();

	local orderedTabs = PlayerTalentFrame_GetOrderedSpecTabs();
	local firstShownTab, lastShownTab;

	for index, frame in ipairs(orderedTabs) do
		local specKey = frame.specIndex;
		local spec = specs[specKey];
		if ( PlayerSpecTab_Update(frame, activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups) ) then
			firstShownTab = firstShownTab or frame;
			frame:ClearAllPoints();

			if ( not lastShownTab ) then
				frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPRIGHT", -32, -33);
			else
				frame:SetPoint("TOPLEFT", lastShownTab, "BOTTOMLEFT", 0, -6);
			end
			lastShownTab = frame;
		else
			-- if the selected tab is not shown then clear out the selected spec
			if ( specKey == selectedSpec ) then
				selectedSpec = nil;
			end
		end
	end

	if ( not selectedSpec ) then
		local handled = false;
		local specMapReady = SpecMap_TalentCacheIsReady and SpecMap_TalentCacheIsReady() or false;

		if ( specMapReady and pendingActiveSpecSelection ) then
			local pendingKey = "spec" .. pendingActiveSpecSelection;
			local pendingFrame = specTabs[pendingKey];
			if ( pendingFrame and pendingFrame:IsShown() and specs[pendingKey] ) then
				PlayerTalentFrame_SelectSpecByKey(pendingKey, true);
				pendingActiveSpecSelection = nil;
				handled = true;
			else
				pendingActiveSpecSelection = nil;
			end
		end

		if ( not handled and specMapReady ) then
			local activeSpecCandidate = SpecMap_GetActiveTalentGroup();
			if ( type(activeSpecCandidate) == "number" and activeSpecCandidate > 0 ) then
				local activeKey = "spec" .. activeSpecCandidate;
				local activeFrame = specTabs[activeKey];
				if ( activeFrame and activeFrame:IsShown() and specs[activeKey] ) then
					PlayerTalentFrame_SelectSpecByKey(activeKey, true);
					handled = true;
				end
			end
		end

		if ( not handled and firstShownTab ) then
			PlayerTalentFrame_SelectSpecByKey(firstShownTab.specIndex, true);
		end
	end

	PlayerTalentFrame_UpdateSpecTabChecks();

	return true;
end

function PlayerSpecTab_Update(self, ...)
	local activeTalentGroup, numTalentGroups, activePetTalentGroup, numPetTalentGroups = ...;

	local specKey = self.specIndex;
	local spec = specs[specKey];

	if ( not spec ) then
		self:Hide();
		return false;
	end

	local canShow;
	if ( spec.pet ) then
		canShow = (numPetTalentGroups or 0) > 0 and spec.talentGroup <= numPetTalentGroups;
	else
		canShow = (numTalentGroups or 0) > 0 and spec.talentGroup <= numTalentGroups;
	end

	if ( not canShow ) then
		if ( specKey == selectedSpec and spec ) then
			if ( spec.pet ) then
				local activePlayerSpec = SpecMap_GetActiveTalentGroup();
				if ( type(activePlayerSpec) ~= "number" or activePlayerSpec <= 0 ) then
					activePlayerSpec = GetActiveTalentGroup(false, false);
					if ( not activePlayerSpec or activePlayerSpec <= 0 ) then
						activePlayerSpec = 1;
					end
				end
				pendingActiveSpecSelection = activePlayerSpec;
			else
				pendingActiveSpecSelection = spec.talentGroup;
			end
		end
		self:Hide();
		return false;
	end

	self:Show();

	local isSelectedSpec = (specKey == selectedSpec);
	local isActiveSpec;
	if ( spec.pet ) then
		isActiveSpec = spec.talentGroup == activePetTalentGroup;
	else
		isActiveSpec = spec.talentGroup == activeTalentGroup;
	end
	local showActiveBorder = isActiveSpec and not spec.pet;
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

	-- set the selection visuals
	local checkedTexture = self:GetCheckedTexture();
	if ( checkedTexture ) then
		if ( isSelectedSpec ) then
			checkedTexture:Show();
		else
			checkedTexture:Hide();
		end
	end

	-- show/hide active overlay
	if ( self.activeOverlay ) then
		if ( normalTexture ) then
			self.activeOverlay:ClearAllPoints();
			self.activeOverlay:SetAllPoints(normalTexture);
		end
		if ( showActiveBorder ) then
			self.activeOverlay:Show();
		else
			self.activeOverlay:Hide();
		end
	end

	if ( self.backdropFrame ) then
		self.backdropFrame:SetBackdropBorderColor(0, 0, 0, 1);
		self.backdropFrame:SetBackdropColor(0, 0, 0, 1);
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
	elseif ( PlayerTalentFrameActiveSpecTabHighlight:GetParent() == self ) then
		PlayerTalentFrameActiveSpecTabHighlight:Hide();
		PlayerTalentFrameActiveSpecTabHighlight:SetParent(nil);
	else
		PlayerTalentFrameActiveSpecTabHighlight:Hide();
	end

--[[
	if ( not spec.pet ) then
		SetDesaturation(normalTexture, not isActiveSpec);
	end
--]]

	-- update the spec info cache
	EnsureTalentSpecCacheEntry(specKey);
	TalentFrame_UpdateSpecInfoCache(talentSpecInfoCache[specKey], false, spec.pet, spec.talentGroup);

	-- update spec tab icon
	self.usingPortraitTexture = false;
	
	if ( hasMultipleTalentGroups ) then
		local specInfoCache = talentSpecInfoCache[specKey];
		local primaryTabIndex = specInfoCache.primaryTabIndex;
		if ( primaryTabIndex > 0 and specInfoCache[primaryTabIndex] ) then
			local iconPath = specInfoCache[primaryTabIndex].icon;
			-- the spec had a primary tab, set the icon to that tab's icon
			if ( iconPath and iconPath ~= "" ) then
				normalTexture:SetTexture(iconPath);
				normalTexture:Show();
			else
				-- Icon path is missing, fall through to default/hybrid logic
				if ( specInfoCache.numTabs > 1 and specInfoCache.totalPointsSpent > 0 ) then
					normalTexture:SetTexture(TALENT_HYBRID_ICON);
				elseif ( spec.defaultSpecTexture ) then
					normalTexture:SetTexture(spec.defaultSpecTexture);
				elseif ( spec.portraitUnit ) then
					SetPortraitTexture(normalTexture, spec.portraitUnit);
					self.usingPortraitTexture = true;
				end
			end
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

	self:Show();
	if ( normalTexture ) then
		normalTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);
	end
	return true;
end

function PlayerSpecTab_Load(self, specIndex)
	self.specIndex = specIndex;
	specTabs[specIndex] = self;
	numSpecTabs = numSpecTabs + 1;

	if ( not talentSpecInfoCache[specIndex] ) then
		talentSpecInfoCache[specIndex] = {};
	end

	local numericIndex = string.match(specIndex or "", "^spec(%d+)$");
	if ( numericIndex ) then
		local playerIndex = tonumber(numericIndex);
		playerSpecTabFrames[playerIndex] = self;
	end

	local legacyBackground = _G[self:GetName().."Background"];
	if ( legacyBackground ) then
		legacyBackground:Hide();
		legacyBackground:SetTexture(nil);
	end

	if ( not self.backdropFrame ) then
		local backdrop = CreateFrame("Frame", nil, self, nil);
		backdrop:SetFrameLevel(self:GetFrameLevel() - 1);
		backdrop:SetPoint("TOPLEFT", self, "TOPLEFT", -1, 1);
		backdrop:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 1, -1);
		backdrop:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
		});
		backdrop:SetBackdropColor(0, 0, 0, 1);
		backdrop:SetBackdropBorderColor(0, 0, 0, 1);
		self.backdropFrame = backdrop;
	end

	local spec = specs[self.specIndex];
	if ( spec and spec.portraitUnit ) then
		SetPortraitTexture(self:GetNormalTexture(), spec.portraitUnit);
		self.usingPortraitTexture = true;
	else
		self.usingPortraitTexture = false;
	end

	if ( not self.activeOverlay ) then
		local overlay = self:CreateTexture(nil, "OVERLAY");
		local normalTex = self:GetNormalTexture();
		if ( normalTex ) then
			overlay:SetAllPoints(normalTex);
		else
			overlay:SetAllPoints(self);
		end
		overlay:SetTexture("Interface\\Buttons\\WHITE8X8");
		overlay:SetVertexColor(1, 0.82, 0, 0.3);
		overlay:SetBlendMode("MOD");
		overlay:Hide();
		self.activeOverlay = overlay;
	end

	local checkedTexture = self:GetCheckedTexture();
	if ( SELECTEDSPEC_DISPLAYTYPE == "BLUE" ) then
		checkedTexture:SetTexture("Interface\\Buttons\\UI-Button-Outline");
		checkedTexture:SetWidth(64);
		checkedTexture:SetHeight(64);
		checkedTexture:ClearAllPoints();
		checkedTexture:SetPoint("CENTER", self, "CENTER", 0, 0);
	elseif ( SELECTEDSPEC_DISPLAYTYPE == "GOLD_INSIDE" ) then
		checkedTexture:SetTexture("Interface\\Buttons\\WHITE8X8");
		checkedTexture:SetVertexColor(1, 1, 1, 0.35);
		checkedTexture:ClearAllPoints();
		checkedTexture:SetAllPoints(self);
	end

	local normalTexture = self:GetNormalTexture();
	if ( normalTexture ) then
		normalTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);
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
	if ( not self or not self.specIndex ) then
		return;
	end

	self:SetChecked(true);
	PlayerTalentFrame_SelectSpecByKey(self.specIndex);
end

function PlayerSpecTab_OnEnter(self)
	local specKey = self.specIndex;
	local spec = specs[specKey];
	if ( not spec ) then
		return;
	end

	local activePlayerGroup;
	if ( type(activeSpecNumber) == "number" and activeSpecNumber > 0 ) then
		activePlayerGroup = activeSpecNumber;
	else
		local specMapActive = SpecMap_GetActiveTalentGroup();
		if ( type(specMapActive) == "number" and specMapActive > 0 ) then
			activePlayerGroup = specMapActive;
		else
			local baseActive = GetActiveTalentGroup(false, false);
			if ( type(baseActive) == "number" and baseActive > 0 ) then
				activePlayerGroup = baseActive;
			end
		end
	end

	local activePetGroup = GetActiveTalentGroup(false, true);

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

	if ( spec.pet ) then
		local playerNumTalentGroups;
		if ( PlayerTalentFrame and PlayerTalentFrame.inspect ) then
			playerNumTalentGroups = GetNumTalentGroups(false, false);
		else
			playerNumTalentGroups = SpecMap_GetTalentGroupCount();
		end

		if ( GetNumTalentGroups(false, true) <= 1 and playerNumTalentGroups <= 1 ) then
			GameTooltip:AddLine(UnitName(spec.unit), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		else
			GameTooltip:AddLine(spec.tooltip or TALENT_SPEC_PET_PRIMARY);
			if ( type(activePetGroup) == "number" and spec.talentGroup == activePetGroup ) then
				GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
			end
		end
	else
		local specNumber = spec.talentGroup or tonumber(string.match(specKey or "", "^spec(%d+)$")) or 1;
		GameTooltip:AddLine(GetOrdinalSpecName(specNumber), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		if ( type(activePlayerGroup) == "number" and spec.talentGroup == activePlayerGroup ) then
			GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
		end
	end

	local totals = specTreeTotals[specKey];
	local cache = talentSpecInfoCache[specKey];
	if ( cache ) then
		local pointsColor;
		for index, info in ipairs(cache) do
			if ( info.name ) then
				local pointsSpent = totals and totals[index] or info.pointsSpent;
				if ( cache.primaryTabIndex == index ) then
					pointsColor = GREEN_FONT_COLOR;
				else
					pointsColor = HIGHLIGHT_FONT_COLOR;
				end
				GameTooltip:AddDoubleLine(
					info.name,
					pointsSpent or 0,
					HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b,
					pointsColor.r, pointsColor.g, pointsColor.b,
					1
				);
			end
		end
	end

	GameTooltip:Show();
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

if ( not SpecMapBaseTalentWrappersInitialized ) then
	SpecMapBaseTalentWrappersInitialized = true;

	local Original_GetTalentLink = GetTalentLink;
	function GetTalentLink(tabIndex, talentIndex, inspect, pet, talentGroup, showPartiallySpent)
		return Original_GetTalentLink(tabIndex, talentIndex, inspect, pet, ResolveBaseTalentGroup(talentGroup), showPartiallySpent);
	end

	local Original_GetTalentInfo = GetTalentInfo;
	function GetTalentInfo(tabIndex, talentIndex, inspect, pet, talentGroup)
		return Original_GetTalentInfo(tabIndex, talentIndex, inspect, pet, ResolveBaseTalentGroup(talentGroup));
	end

	local Original_GetTalentPrereqs = GetTalentPrereqs;
	function GetTalentPrereqs(tabIndex, talentIndex, inspect, pet, talentGroup)
		return Original_GetTalentPrereqs(tabIndex, talentIndex, inspect, pet, ResolveBaseTalentGroup(talentGroup));
	end

	local Original_GetUnspentTalentPoints = GetUnspentTalentPoints;
	function GetUnspentTalentPoints(inspect, pet, talentGroup)
		return Original_GetUnspentTalentPoints(inspect, pet, ResolveBaseTalentGroup(talentGroup));
	end

	local Original_AddPreviewTalentPoints = AddPreviewTalentPoints;
	function AddPreviewTalentPoints(tabIndex, talentIndex, delta, pet, talentGroup)
		return Original_AddPreviewTalentPoints(tabIndex, talentIndex, delta, pet, ResolveBaseTalentGroup(talentGroup));
	end

	local Original_LearnTalent = LearnTalent;
	function LearnTalent(tabIndex, talentIndex, pet, talentGroup)
		return Original_LearnTalent(tabIndex, talentIndex, pet, ResolveBaseTalentGroup(talentGroup));
	end

	local Original_ResetGroupPreviewTalentPoints = ResetGroupPreviewTalentPoints;
	function ResetGroupPreviewTalentPoints(pet, talentGroup)
		return Original_ResetGroupPreviewTalentPoints(pet, ResolveBaseTalentGroup(talentGroup));
	end

	local Original_GetGroupPreviewTalentPointsSpent = GetGroupPreviewTalentPointsSpent;
	function GetGroupPreviewTalentPointsSpent(pet, talentGroup)
		return Original_GetGroupPreviewTalentPointsSpent(pet, ResolveBaseTalentGroup(talentGroup));
	end
end

SpecMapTalentCache = {
	specs = {},
	ready = false,
	freeTalents = nil,
};

if ( PlayerTalentFrameTalents ) then
	PlayerTalentFrameTalents:Show();
end
if ( PlayerTalentFrameScrollFrame ) then
	PlayerTalentFrameScrollFrame:Show();
end

local GLYPH_VIEW_TALENT_FRAME_WIDTH = nil;
local GLYPH_VIEW_TALENT_FRAME_HEIGHT = nil;

local resolvedSpecNumber = selectedSpecNumber;
if ( type(resolvedSpecNumber) ~= "number" or resolvedSpecNumber <= 0 ) then
	resolvedSpecNumber = SpecMap_GetActiveTalentGroup();
	if ( type(resolvedSpecNumber) ~= "number" or resolvedSpecNumber <= 0 ) then
		resolvedSpecNumber = GetActiveTalentGroup(false, false) or 1;
	end
	selectedSpecNumber = resolvedSpecNumber;
end

if ( not selectedSpec or not specs[selectedSpec] or specs[selectedSpec].pet ) then
	local specKey = "spec" .. resolvedSpecNumber;
	if ( specs[specKey] ) then
		PlayerTalentFrame_SelectSpecByKey(specKey, true);
	end
end

if ( type(resolvedSpecNumber) ~= "number" or resolvedSpecNumber <= 0 ) then
	resolvedSpecNumber = 1;
end

if ( type(activeSpecNumber) ~= "number" or activeSpecNumber <= 0 ) then
	local activeFromSpecMap = SpecMap_GetActiveTalentGroup();
	if ( type(activeFromSpecMap) ~= "number" or activeFromSpecMap <= 0 ) then
		activeFromSpecMap = GetActiveTalentGroup(false, false) or 1;
	end
	activeSpecNumber = activeFromSpecMap;
end