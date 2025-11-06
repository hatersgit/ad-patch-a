GLYPHTYPE_MAJOR = 1;
GLYPHTYPE_MINOR = 2;

GLYPH_MINOR = { r = 0, g = 0.25, b = 1};
GLYPH_MAJOR = { r = 1, g = 0.25, b = 0};

GLYPH_SLOTS = {};
-- Empty Texture
GLYPH_SLOTS[0] = { left = 0.78125, right = 0.91015625, top = 0.69921875, bottom = 0.828125 };
-- Major Glyphs
GLYPH_SLOTS[3] = { left = 0.392578125, right = 0.521484375, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[1] = { left = 0, right = 0.12890625, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[5] = { left = 0.26171875, right = 0.390625, top = 0.87109375, bottom = 1 };
-- Minor Glyphs
GLYPH_SLOTS[2] = { left = 0.130859375, right = 0.259765625, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[6] = { left = 0.654296875, right = 0.783203125, top = 0.87109375, bottom = 1 };
GLYPH_SLOTS[4] = { left = 0.5234375, right = 0.65234375, top = 0.87109375, bottom = 1 };

NUM_GLYPH_SLOTS = 6;

-- Mapping of glyph icon IDs to texture paths
local GLYPH_ICON_TEXTURES = {
	[3098] = "Interface\\Spellbook\\UI-Glyph-Rune-11",
	[2681] = "Interface\\Icons\\Creature_sporemushroom",
	[3115] = "Interface\\Spellbook\\UI-Glyph-Rune-14",
	[3114] = "Interface\\Spellbook\\UI-Glyph-Rune-13",
	[3113] = "Interface\\Spellbook\\UI-Glyph-Rune-12",
	[3312] = "Interface\\Spellbook\\UI-Glyph-Rune-10",
	[3124] = "Interface\\Spellbook\\UI-Glyph-Rune-4",
	[3129] = "Interface\\Spellbook\\UI-Glyph-Rune1",
	[3112] = "Interface\\Spellbook\\UI-Glyph-Rune-10",
	[3128] = "Interface\\Spellbook\\UI-Glyph-Rune-8",
	[3123] = "Interface\\Spellbook\\UI-Glyph-Rune-3",
	[3121] = "Interface\\Spellbook\\UI-Glyph-Rune-20",
	[3127] = "Interface\\Spellbook\\UI-Glyph-Rune-7",
	[3125] = "Interface\\Spellbook\\UI-Glyph-Rune-5",
	[3119] = "Interface\\Spellbook\\UI-Glyph-Rune-18",
	[3120] = "Interface\\Spellbook\\UI-Glyph-Rune-10",
	[3117] = "Interface\\Spellbook\\UI-Glyph-Rune-16",
	[3122] = "Interface\\Spellbook\\UI-Glyph-Rune-2",
	[3118] = "Interface\\Spellbook\\UI-Glyph-Rune-17",
	[3116] = "Interface\\Spellbook\\UI-Glyph-Rune-15",
	[3126] = "Interface\\Spellbook\\UI-Glyph-Rune-6",
	[3110] = "Interface\\Spellbook\\UI-Glyph-Rune-1",
};

-- Default glyph icon ID (3312)
local DEFAULT_GLYPH_ICON_ID = 3312;
local DEFAULT_GLYPH_TEXTURE = GLYPH_ICON_TEXTURES[DEFAULT_GLYPH_ICON_ID];

local slotAnimations = {};
local TOPLEFT, TOP, TOPRIGHT, BOTTOMRIGHT, BOTTOM, BOTTOMLEFT = 3, 1, 5, 4, 2, 6;
slotAnimations[TOPLEFT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -85, ["yStart"] = 17, ["yStop"] = 60};
slotAnimations[TOP] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -13, ["yStart"] = 17, ["yStop"] = 100};
slotAnimations[TOPRIGHT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = 59, ["yStart"] = 17, ["yStop"] = 60};
slotAnimations[BOTTOM] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -13, ["yStart"] = 17, ["yStop"] = -64};
slotAnimations[BOTTOMLEFT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = -87, ["yStart"] = 18, ["yStop"] = -27};
slotAnimations[BOTTOMRIGHT] = {["point"] = "CENTER", ["xStart"] = -13, ["xStop"] = 61, ["yStart"] = 18, ["yStop"] = -27};

local HIGHLIGHT_BASEALPHA = .4;

local function GlyphFrame_ShouldUseSpecMap()
	return type(SpecMap_GetGlyphSpell) == "function" and type(SpecMap_GetActiveTalentGroup) == "function" and PlayerTalentFrame and not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet;
end

local function GlyphFrame_GetSpecMapGlyphInfo(talentGroup, slotIndex)
	if ( not GlyphFrame_ShouldUseSpecMap() ) then
		return nil, nil, false;
	end
	local glyphSpell = SpecMap_GetGlyphSpell(talentGroup, slotIndex);
	local iconId = nil;
	if ( type(SpecMap_GetGlyphIconId) == "function" ) then
		iconId = SpecMap_GetGlyphIconId(talentGroup, slotIndex);
	end
	
	if ( glyphSpell ) then
		local icon = iconId;
		return glyphSpell, icon, true;
	end
	return nil, nil, true;
end

-- Get glyph socket info from SpecMap cache when using SpecMap
local function GlyphFrame_GetSpecMapSocketInfo(slotIndex)
	if ( not GlyphFrame_ShouldUseSpecMap() ) then
		return nil, nil;
	end
	
	-- Check if viewing active spec - sockets are shown for both active and inactive specs
	-- but will be desaturated for inactive specs
	local isActiveSpec = false;
	if ( PlayerTalentFrame and not PlayerTalentFrame.pet and not PlayerTalentFrame.inspect ) then
		-- Check if selected spec matches active spec
		if ( type(selectedSpecNumber) == "number" and type(activeSpecNumber) == "number" ) then
			isActiveSpec = (selectedSpecNumber == activeSpecNumber);
		else
			-- Fallback to base game API
			local activeGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
			isActiveSpec = (PlayerTalentFrame.talentGroup == activeGroup);
		end
	end
	
	-- Always return socket info (show sockets even for inactive specs, they'll be desaturated)
	if ( type(SpecMap_IsGlyphSocketEnabled) == "function" and type(SpecMap_GetGlyphSocketTypeCached) == "function" ) then
		local enabled = SpecMap_IsGlyphSocketEnabled(slotIndex);
		local glyphType = SpecMap_GetGlyphSocketTypeCached(slotIndex);
		return enabled, glyphType;
	end
	return nil, nil;
end


function GlyphFrame_Toggle ()
	TalentFrame_LoadUI();
	if ( PlayerTalentFrame_ToggleGlyphFrame ) then
		local activeGroup = GetActiveTalentGroup();
		if ( GlyphFrame_ShouldUseSpecMap() ) then
			activeGroup = SpecMap_GetActiveTalentGroup();
		end
		PlayerTalentFrame_ToggleGlyphFrame(activeGroup);
	end
end

function GlyphFrame_Open ()
	TalentFrame_LoadUI();
	if ( PlayerTalentFrame_OpenGlyphFrame ) then
		local activeGroup = GetActiveTalentGroup();
		if ( GlyphFrame_ShouldUseSpecMap() ) then
			activeGroup = SpecMap_GetActiveTalentGroup();
		end
		PlayerTalentFrame_OpenGlyphFrame(activeGroup);
	end
end


function GlyphFrameGlyph_OnLoad (self)
	local name = self:GetName();
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	self.glyph = _G[name .. "Glyph"];
	self.setting = _G[name .. "Setting"];
	self.highlight = _G[name .. "Highlight"];
	self.background = _G[name .. "Background"];
	self.ring = _G[name .. "Ring"];
	self.shine = _G[name .. "Shine"];
	self.elapsed = 0;
	self.tintElapsed = 0;
	self.glyphType = nil;
end

function GlyphFrameGlyph_UpdateSlot (self)
	local id = self:GetID();
	local talentGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup;
	local enabled, glyphType, glyphSpell, iconFilename = GetGlyphSocketInfo(id, talentGroup);
	
	-- Override socket enablement and type from SpecMap cache if using SpecMap
	local specSocketEnabled, specGlyphType = GlyphFrame_GetSpecMapSocketInfo(id);
	if ( specSocketEnabled ~= nil ) then
		enabled = specSocketEnabled;
	end
	if ( specGlyphType ~= nil ) then
		glyphType = specGlyphType;
	else
		-- If not using SpecMap, use the mapping: 1, 4, 6 = Major, 2, 3, 5 = Minor
		if ( id and id >= 1 and id <= NUM_GLYPH_SLOTS ) then
			if ( id == 1 or id == 4 or id == 6 ) then
				glyphType = 1; -- Major (indices: 1, 4, 6)
			else
				glyphType = 2; -- Minor (indices: 2, 3, 5)
			end
		end
	end
	
	-- Get glyph spell and icon from SpecMap if using SpecMap
	-- The base UI uses GetGlyphSocketInfo which returns iconFilename directly from the glyph's spell
	-- When using SpecMap, we get the icon via GetSpellInfo (same way GetGlyphSocketInfo does internally)
	local specGlyphSpell, specGlyphIcon, specAuthoritative = GlyphFrame_GetSpecMapGlyphInfo(talentGroup, id);
	if ( specAuthoritative ) then
		if ( specGlyphSpell ) then
			-- We have a glyph spell from SpecMap - override both spell and icon
			glyphSpell = specGlyphSpell;
			
			-- Get icon ID from SpecMap and map it to texture path
			local iconId = nil;
			if ( type(SpecMap_GetGlyphIconId) == "function" ) then
				iconId = SpecMap_GetGlyphIconId(talentGroup, id);
			end
			
			if ( iconId and GLYPH_ICON_TEXTURES[iconId] ) then
				-- Use texture from mapping table
				iconFilename = GLYPH_ICON_TEXTURES[iconId];
			elseif ( iconId ) then
				-- Icon ID exists but not in mapping, use default
				iconFilename = DEFAULT_GLYPH_TEXTURE;
			else
				-- No icon ID from SpecMap - fall back to icon from spell info
				local _, _, spellIcon = GetSpellInfo(glyphSpell);
				if ( spellIcon ) then
					iconFilename = spellIcon;
				else
					-- Final fallback: use default texture
					iconFilename = DEFAULT_GLYPH_TEXTURE;
				end
			end
		else
			-- Empty socket - no glyph spell, clear both spell and icon (same as base UI)
			glyphSpell = nil;
			iconFilename = nil;
		end
	else
		-- Not using SpecMap - use iconFilename from GetGlyphSocketInfo, but only if glyph spell exists
		if ( not glyphSpell ) then
			iconFilename = nil;
		end
		-- Note: iconFilename from GetGlyphSocketInfo should already be correct if glyphSpell exists
	end

	-- Always hide and clear glyph texture initially - only show if glyph is actually slotted
	-- Do this before SetGlyphType to prevent any default texture from showing
	self.glyph:Hide();
	self.glyph:SetTexture(nil);

	local isMinor = glyphType == 2;
	if ( isMinor ) then
		GlyphFrameGlyph_SetGlyphType(self, GLYPHTYPE_MINOR);
	else
		GlyphFrameGlyph_SetGlyphType(self, GLYPHTYPE_MAJOR);
	end

	self.elapsed = 0;
	self.tintElapsed = 0;
	
	-- Hide highlight texture - simple saturation is enough
	if ( self.highlight ) then
		self.highlight:Hide();
	end

	-- Check if viewing active spec - disable animations if viewing inactive spec
	local isActiveSpec = false;
	if ( PlayerTalentFrame and not PlayerTalentFrame.pet and not PlayerTalentFrame.inspect ) then
		-- Check if selected spec matches active spec
		if ( type(selectedSpecNumber) == "number" and type(activeSpecNumber) == "number" ) then
			isActiveSpec = (selectedSpecNumber == activeSpecNumber);
		else
			-- Fallback to base game API
			local activeGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
			isActiveSpec = (PlayerTalentFrame.talentGroup == activeGroup);
		end
	end

	local slotAnimation = slotAnimations[id];
	
	if ( not enabled ) then
		slotAnimation.glyph = nil;
		if ( slotAnimation.sparkle ) then
			slotAnimation.sparkle:StopAnimating();
			slotAnimation.sparkle:Hide();
		end
		self.shine:Hide();
		self.background:Hide();
		self.ring:Hide();
		self.setting:SetTexture("Interface\\Spellbook\\UI-GlyphFrame-Locked");
		self.setting:SetTexCoord(.1, .9, .1, .9);
	elseif ( not glyphSpell ) then
		-- Empty socket - no glyph slotted
		-- Disable animations if viewing inactive spec
		if ( not isActiveSpec ) then
			slotAnimation.glyph = nil;
			if ( slotAnimation.sparkle ) then
				slotAnimation.sparkle:StopAnimating();
				slotAnimation.sparkle:Hide();
			end
		else
			slotAnimation.glyph = nil; -- Empty socket doesn't animate
			if ( slotAnimation.sparkle ) then
				slotAnimation.sparkle:StopAnimating();
				slotAnimation.sparkle:Hide();
			end
		end
		self.spell = nil;
		self.shine:Show();
		self.background:Show();
		self.background:SetTexCoord(GLYPH_SLOTS[0].left, GLYPH_SLOTS[0].right, GLYPH_SLOTS[0].top, GLYPH_SLOTS[0].bottom);
		if ( not GlyphMatchesSocket(id) ) then
			self.background:SetAlpha(1);
		end
		-- Desaturate borders when viewing inactive spec
		if ( not isActiveSpec ) then
			SetDesaturation(self.ring, true);
			SetDesaturation(self.background, true);
			SetDesaturation(self.setting, true);
		else
			SetDesaturation(self.ring, false);
			SetDesaturation(self.background, false);
			SetDesaturation(self.setting, false);
		end
		-- Ensure glyph texture is hidden and cleared for empty slots
		self.glyph:Hide();
		self.glyph:SetTexture(nil);
		self.ring:Show();
	else
		-- Glyph is slotted - show the glyph rune texture
		-- Only enable animations if viewing active spec
		if ( isActiveSpec ) then
			slotAnimation.glyph = true;
		else
			slotAnimation.glyph = nil;
			if ( slotAnimation.sparkle ) then
				slotAnimation.sparkle:StopAnimating();
				slotAnimation.sparkle:Hide();
			end
		end
		self.spell = glyphSpell;
		self.shine:Show();
		self.background:Show();
		self.background:SetAlpha(1);
		self.background:SetTexCoord(GLYPH_SLOTS[id].left, GLYPH_SLOTS[id].right, GLYPH_SLOTS[id].top, GLYPH_SLOTS[id].bottom);
		-- Only show glyph texture when glyph is actually slotted AND we have an icon
		-- Double-check that glyphSpell exists (safety check)
		if ( glyphSpell and iconFilename ) then
			self.glyph:Show();
			self.glyph:SetTexture(iconFilename);
		else
			-- No glyph or no icon available - don't show the glyph texture
			self.glyph:Hide();
			self.glyph:SetTexture(nil);
		end
		-- Desaturate borders and glyph rune when viewing inactive spec
		if ( not isActiveSpec ) then
			SetDesaturation(self.ring, true);
			SetDesaturation(self.background, true);
			SetDesaturation(self.setting, true);
			SetDesaturation(self.glyph, true);
		else
			SetDesaturation(self.ring, false);
			SetDesaturation(self.background, false);
			SetDesaturation(self.setting, false);
			SetDesaturation(self.glyph, false);
		end
		self.ring:Show();
	end
end

function GlyphFrameGlyph_SetGlyphType (glyph, glyphType)
	glyph.glyphType = glyphType;
	
	glyph.setting:SetTexture("Interface\\Spellbook\\UI-GlyphFrame");
	if ( glyphType == GLYPHTYPE_MAJOR ) then
		glyph.glyph:SetVertexColor(GLYPH_MAJOR.r, GLYPH_MAJOR.g, GLYPH_MAJOR.b);
		glyph.setting:SetWidth(108);
		glyph.setting:SetHeight(108);
		glyph.setting:SetTexCoord(0.740234375, 0.953125, 0.484375, 0.697265625);
		glyph.highlight:SetWidth(108);
		glyph.highlight:SetHeight(108);
		glyph.highlight:SetTexCoord(0.740234375, 0.953125, 0.484375, 0.697265625);
		glyph.ring:SetWidth(82);
		glyph.ring:SetHeight(82);
		glyph.ring:SetPoint("CENTER", glyph, "CENTER", 0, -1);
		glyph.ring:SetTexCoord(0.767578125, 0.92578125, 0.32421875, 0.482421875);
		glyph.shine:SetTexCoord(0.9609375, 1, 0.9609375, 1);
		glyph.background:SetWidth(70);
		glyph.background:SetHeight(70);
	else
		glyph.glyph:SetVertexColor(GLYPH_MINOR.r, GLYPH_MINOR.g, GLYPH_MINOR.b);
		glyph.setting:SetWidth(86);
		glyph.setting:SetHeight(86);
		glyph.setting:SetTexCoord(0.765625, 0.927734375, 0.15625, 0.31640625);
		glyph.highlight:SetWidth(86);
		glyph.highlight:SetHeight(86);
		glyph.highlight:SetTexCoord(0.765625, 0.927734375, 0.15625, 0.31640625);
		glyph.ring:SetWidth(62);
		glyph.ring:SetHeight(62);
		glyph.ring:SetPoint("CENTER", glyph, "CENTER", 0, 1);
		glyph.ring:SetTexCoord(0.787109375, 0.908203125, 0.033203125, 0.154296875);
		glyph.shine:SetTexCoord(0.9609375, 1, 0.921875, 0.9609375);
		glyph.background:SetWidth(64);
		glyph.background:SetHeight(64);
	end
end

function GlyphFrameGlyph_OnUpdate (self, elapsed)
	local GLYPHFRAMEGLYPH_FINISHED = 6;
	local GLYPHFRAMEGLYPH_START = 2;
	local GLYPHFRAMEGLYPH_HOLD = 4;

	local hasGlyph = self.glyph:IsShown();
	
	if ( hasGlyph or self.elapsed > 0 ) then
		self.elapsed = self.elapsed + elapsed;
		
		elapsed = self.elapsed;
		if ( elapsed >= GLYPHFRAMEGLYPH_FINISHED ) then
			self.setting:SetAlpha(.6);
			self.elapsed = 0;
		elseif ( elapsed <= GLYPHFRAMEGLYPH_START ) then
			self.setting:SetAlpha(.6 + (.4 * elapsed/GLYPHFRAMEGLYPH_START));
		elseif ( elapsed >= GLYPHFRAMEGLYPH_HOLD ) then
			self.setting:SetAlpha(1 - (.4 * (elapsed - GLYPHFRAMEGLYPH_HOLD) / (GLYPHFRAMEGLYPH_FINISHED - GLYPHFRAMEGLYPH_HOLD) ) );
		end
	elseif ( self.background:IsShown() ) then
		self.setting:SetAlpha(.6);
	else
		self.setting:SetAlpha(.6);
	end
	
	local TINT_START, TINT_HOLD, TINT_FINISHED = .6, .8, 1.6;
	
	local id = self:GetID();
	if ( not hasGlyph and self.background:IsShown() and GlyphMatchesSocket(id) ) then
		self.tintElapsed = self.tintElapsed + elapsed;
		
		self.background:SetTexCoord(GLYPH_SLOTS[id].left, GLYPH_SLOTS[id].right, GLYPH_SLOTS[id].top, GLYPH_SLOTS[id].bottom);
		
		-- Hide highlight texture - simple saturation is enough
		if ( self.highlight ) then
			self.highlight:Hide();
		end
		
		local alpha;
		elapsed = self.tintElapsed;
		if ( elapsed >= TINT_FINISHED ) then
			alpha = 1;
			
			self.tintElapsed = 0;
		elseif ( elapsed <= TINT_START ) then
			alpha = 1 - (.6 * elapsed/TINT_START);
		elseif ( elapsed >= TINT_HOLD ) then
			alpha = .4 + (.6 * (elapsed - TINT_HOLD) / (TINT_FINISHED - TINT_HOLD));
		end
		
		if ( alpha ) then
			self.background:SetAlpha(alpha);
		end
	elseif ( not hasGlyph ) then
		self.background:SetTexCoord(GLYPH_SLOTS[0].left, GLYPH_SLOTS[0].right, GLYPH_SLOTS[0].top, GLYPH_SLOTS[0].bottom);
		self.background:SetAlpha(1);
	end
	
	if ( self.hasCursor and SpellIsTargeting() ) then
		if ( GlyphMatchesSocket(self:GetID()) and self.background:IsShown() ) then
			SetCursor("CAST_CURSOR");
		else
			SetCursor("CAST_ERROR_CURSOR");
		end
	end
end

function GlyphFrameGlyph_OnClick (self, button)
	local id = self:GetID();
	local talentGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup;
	
	-- Determine if viewing active spec
	local isActiveSpec = false;
	if ( GlyphFrame_ShouldUseSpecMap() ) then
		-- For player talents with SpecMap, use global activeSpecNumber if available
		if ( type(selectedSpecNumber) == "number" and type(activeSpecNumber) == "number" ) then
			isActiveSpec = (selectedSpecNumber == activeSpecNumber);
		else
			local activeGroup = SpecMap_GetActiveTalentGroup();
			isActiveSpec = (talentGroup == activeGroup);
		end
	else
		local activeGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
		isActiveSpec = (talentGroup == activeGroup);
	end

	if ( IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() ) then
		local link = GetGlyphLink(id, talentGroup);
		if ( not link ) then
			local glyphSpell, _, specAuthoritative = GlyphFrame_GetSpecMapGlyphInfo(talentGroup, id);
			if ( specAuthoritative and glyphSpell ) then
				link = GetSpellLink(glyphSpell);
			end
		end
		if ( link ) then
			ChatEdit_InsertLink(link);
		end
	elseif ( button == "RightButton" ) then
		if ( IsShiftKeyDown() and isActiveSpec ) then
			local glyphName;
			local _, _, glyphSpell = GetGlyphSocketInfo(id, talentGroup);
			local specGlyphSpell, _, specAuthoritative = GlyphFrame_GetSpecMapGlyphInfo(talentGroup, id);
			if ( specAuthoritative and specGlyphSpell ) then
				glyphSpell = specGlyphSpell;
			end
			if ( glyphSpell ) then
				glyphName = GetSpellInfo(glyphSpell);
				local dialog = StaticPopup_Show("CONFIRM_REMOVE_GLYPH", glyphName);
				dialog.data = id;
			end
		end
	elseif ( isActiveSpec ) then
		if ( self.glyph:IsShown() and GlyphMatchesSocket(id) ) then
			local dialog = StaticPopup_Show("CONFIRM_GLYPH_PLACEMENT", id);
			dialog.data = id;
		else
			PlaceGlyphInSocket(id);
		end
	end
end

function GlyphFrameGlyph_OnEnter (self)
	self.hasCursor = true;
	-- Hide highlight texture - simple saturation is enough
	if ( self.highlight ) then
		self.highlight:Hide();
	end
	local talentGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup;
	local id = self:GetID();
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	
	-- Check if we should use SpecMap
	local useSpecMap = GlyphFrame_ShouldUseSpecMap();
	if ( useSpecMap ) then
		local glyphSpell, _, specAuthoritative = GlyphFrame_GetSpecMapGlyphInfo(talentGroup, id);
		-- If we have a glyph spell from SpecMap, show it
		if ( specAuthoritative and glyphSpell and glyphSpell > 0 ) then
			GameTooltip:SetHyperlink(GetSpellLink(glyphSpell));
			GameTooltip:Show();
		else
			-- For empty/locked sockets with SpecMap, we need to show tooltip manually
			-- Get socket info from SpecMap cache
			local enabled, glyphType = GlyphFrame_GetSpecMapSocketInfo(id);
			if ( enabled ~= nil and glyphType ~= nil ) then
				local socketName = (glyphType == 2) and "Minor Glyph" or "Major Glyph";
				GameTooltip:SetText(socketName);
				if ( not enabled ) then
					local unlockLevel = nil;
					if ( type(SpecMap_GetGlyphSocketUnlockLevel) == "function" ) then
						unlockLevel = SpecMap_GetGlyphSocketUnlockLevel(id);
					else
						-- Fallback levels (base WoW 3.3.5 pattern)
						-- Slot 1 (Major): 15, Slot 2 (Minor): 15, Slot 3 (Minor): 50, 
						-- Slot 4 (Major): 30, Slot 5 (Minor): 70, Slot 6 (Major): 80
						local fallbackLevels = {
							[1] = 15, -- Major slot 1
							[2] = 15, -- Minor slot 1
							[3] = 50, -- Minor slot 2
							[4] = 30, -- Major slot 2
							[5] = 70, -- Minor slot 3
							[6] = 80, -- Major slot 3
						};
						unlockLevel = fallbackLevels[id] or ((glyphType == 2) and 15 or 25);
					end
					if ( unlockLevel ) then
						GameTooltip:AddLine("Unlocks at level " .. unlockLevel, 1, 1, 1);
					end
				elseif ( not glyphSpell ) then
					GameTooltip:AddLine("Empty " .. socketName .. " Socket", 0.5, 0.5, 0.5);
				end
				GameTooltip:Show();
			else
				-- Fallback to base game API
				GameTooltip:SetGlyph(id, talentGroup);
				GameTooltip:Show();
			end
		end
	else
		-- Not using SpecMap, use base game API
		GameTooltip:SetGlyph(id, talentGroup);
		GameTooltip:Show();
	end
end

function GlyphFrameGlyph_OnLeave (self)
	self.hasCursor = nil;
	self.highlight:Hide();
	GameTooltip:Hide();
end

local GLYPH_SPARKLE_SIZES = 3;
local GLYPH_DURATION_MODIFIERS = { 1.25, 1.5, 1.8 };

function GlyphFrame_OnUpdate (self, elapsed)
	-- Disabled sparkle animations to improve FPS
	-- for i = 1, #slotAnimations do
	-- 	local animation = slotAnimations[i];
	-- 	if ( animation.glyph and not (animation.sparkle and animation.sparkle.animGroup:IsPlaying()) ) then
	-- 		local sparkleSize = math.random(GLYPH_SPARKLE_SIZES);
	-- 		GlyphFrame_StartSlotAnimation(i, sparkleSize * GLYPH_DURATION_MODIFIERS[sparkleSize], sparkleSize);
	-- 	end
	-- end
end

function GlyphFrame_PulseGlow ()
	-- Disabled glow pulse animation to improve FPS
	-- GlyphFrame.glow:Show();
	-- GlyphFrame.glow.pulse:Play();
end

function GlyphFrame_OnShow (self)
	PlayerTalentFrameControlBar:Hide();
	PlayerTalentFrameControlBarResetButton:Hide();
	PlayerTalentFrameControlBarLearnButton:Hide();
	GlyphFrame_Update();
end

function GlyphFrame_OnLoad (self)
	local name = self:GetName();
	self.background = _G[name .. "Background"];
	self.sparkleFrame = SparkleFrame:New(self);
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("GLYPH_ADDED");
	self:RegisterEvent("GLYPH_REMOVED");
	self:RegisterEvent("GLYPH_UPDATED");
	self:RegisterEvent("USE_GLYPH");
	self:RegisterEvent("PLAYER_LEVEL_UP");
end

function GlyphFrame_OnEnter (self)
	if ( SpellIsTargeting() ) then
		SetCursor("CAST_ERROR_CURSOR");
	end
end

function GlyphFrame_OnLeave (self)

end

function GlyphFrame_OnEvent (self, event, ...)
	if ( event == "ADDON_LOADED" ) then
		local name = ...;
		if ( name == "Blizzard_GlyphUI" and IsAddOnLoaded("Blizzard_TalentUI") or name == "Blizzard_TalentUI" ) then
			self:ClearAllPoints();
			self:SetParent(PlayerTalentFrame);
			self:SetAllPoints();
			-- make sure this shows up above the talent UI
			local frameLevel = self:GetParent():GetFrameLevel() + 4;
			self:SetFrameLevel(frameLevel);
			PlayerTalentFrameCloseButton:SetFrameLevel(frameLevel + 1);
		end
	elseif ( event == "USE_GLYPH" or event == "PLAYER_LEVEL_UP" ) then
		-- Rebuild glyph cache on level up (sockets unlock at different levels)
		if ( event == "PLAYER_LEVEL_UP" and type(SpecMap_BuildGlyphCache) == "function" ) then
			SpecMap_BuildGlyphCache();
		end
		GlyphFrame_Update();
	elseif ( event == "GLYPH_ADDED" or event == "GLYPH_REMOVED" or event == "GLYPH_UPDATED" ) then
		local index = ...;
		local glyph = _G["GlyphFrameGlyph" .. index];
		if ( glyph and self:IsVisible() ) then
			-- update the glyph
			GlyphFrameGlyph_UpdateSlot(glyph);
			-- play effects based on the event and glyph type
			GlyphFrame_PulseGlow();
			local glyphType = glyph.glyphType;
			if ( event == "GLYPH_ADDED" or event == "GLYPH_UPDATED" ) then
				if ( glyphType == GLYPHTYPE_MINOR ) then
					PlaySound("Glyph_MinorCreate");
				elseif ( glyphType == GLYPHTYPE_MAJOR ) then
					PlaySound("Glyph_MajorCreate");
				end
			elseif ( event == "GLYPH_REMOVED" ) then
				GlyphFrame_StopSlotAnimation(index);
				if ( glyphType == GLYPHTYPE_MINOR ) then
					PlaySound("Glyph_MinorDestroy");
				elseif ( glyphType == GLYPHTYPE_MAJOR ) then
					PlaySound("Glyph_MajorDestroy");
				end
			end
		end

		--Refresh tooltip!
		if ( GameTooltip:IsOwned(glyph) ) then
			GlyphFrameGlyph_OnEnter(glyph);
		end
	end
end

function GlyphFrame_Update ()
	-- Build glyph cache if using SpecMap
	if ( GlyphFrame_ShouldUseSpecMap() and type(SpecMap_BuildGlyphCache) == "function" ) then
		SpecMap_BuildGlyphCache();
	end
	
	-- Determine if viewing active spec (use base game API as source of truth)
	local activeGroup = GetActiveTalentGroup(PlayerTalentFrame and PlayerTalentFrame.inspect, PlayerTalentFrame and PlayerTalentFrame.pet);
	local isActiveTalentGroup = false;
	if ( PlayerTalentFrame and not PlayerTalentFrame.pet and not PlayerTalentFrame.inspect ) then
		-- Check if selected spec matches active spec
		if ( type(selectedSpecNumber) == "number" and type(activeSpecNumber) == "number" ) then
			isActiveTalentGroup = (selectedSpecNumber == activeSpecNumber);
		else
			-- Fallback to base game API
			isActiveTalentGroup = (PlayerTalentFrame.talentGroup == activeGroup);
		end
	end
	
	-- Desaturate background when viewing inactive spec
	SetDesaturation(GlyphFrame.background, not isActiveTalentGroup);

	for i = 1, NUM_GLYPH_SLOTS do
		GlyphFrameGlyph_UpdateSlot(_G["GlyphFrameGlyph"..i]);
	end
	
	-- Stop any running sparkle animations to improve FPS
	for i = 1, NUM_GLYPH_SLOTS do
		local animation = slotAnimations[i];
		if ( animation and animation.sparkle ) then
			animation.sparkle.animGroup:Stop();
			animation.sparkle:Hide();
		end
	end
	
	-- Hide glow to improve FPS
	if ( GlyphFrame and GlyphFrame.glow ) then
		GlyphFrame.glow:Hide();
	end
	
	-- Update controls to show status frame/activate button for glyphs
	if ( PlayerTalentFrame and not PlayerTalentFrame.inspect and not PlayerTalentFrame.pet ) then
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
end

function GlyphFrame_StartSlotAnimation (slotID, duration, size)
	local animation = slotAnimations[slotID];

	-- init texture to animate
	local sparkleName = "GlyphFrameSparkle"..slotID;
	local sparkle = _G[sparkleName];
	if ( not sparkle ) then
		sparkle = GlyphFrame:CreateTexture(sparkleName, "OVERLAY", "GlyphSparkleTexture");
		sparkle.slotID = slotID;
	end
	local template;
	if ( size == 1 ) then
		template = "SparkleTextureSmall";
	elseif ( size == 2 ) then
		template = "SparkleTextureKindaSmall";
	else
		template = "SparkleTextureNormal";
	end
	local sparkleDim = SparkleDimensions[template];
	sparkle:SetHeight(sparkleDim.height);
	sparkle:SetWidth(sparkleDim.width);
	sparkle:SetPoint("CENTER", GlyphFrame, animation.point, animation.xStart, animation.yStart);
	sparkle:Show();

	-- init animation
	local offsetX, offsetY = animation.xStop - animation.xStart, animation.yStop - animation.yStart;
	local animGroupAnim = sparkle.animGroup.translate;
	animGroupAnim:SetOffset(offsetX, offsetY);
	animGroupAnim:SetDuration(duration);
	animGroupAnim:Play();

	animation.sparkle = sparkle;
end

function GlyphFrame_StopSlotAnimation (slotID)
	local animation = slotAnimations[slotID];
	if ( animation.sparkle ) then
		animation.sparkle.animGroup:Stop();
		animation.sparkle:Hide();
		animation.sparkle = nil;
	end
end
