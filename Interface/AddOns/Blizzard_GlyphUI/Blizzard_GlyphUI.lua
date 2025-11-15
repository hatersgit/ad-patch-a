GLYPHTYPE_MAJOR = 1;
GLYPHTYPE_MINOR = 2;

GLYPH_MINOR = { r = 0, g = 0.25, b = 1};
GLYPH_MAJOR = { r = 1, g = 0.25, b = 0};

-- Static popup for confirming glyph removal (uses activeSpecNumber instead of GetActiveTalentGroup)
StaticPopupDialogs["CONFIRM_REMOVE_GLYPH_SPECMAP"] = {
	text = CONFIRM_REMOVE_GLYPH,
	button1 = YES,
	button2 = NO,
	OnAccept = function (self)
		local talentGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup or 1;
		-- Use activeSpecNumber global variable instead of GetActiveTalentGroup()
		local isActiveSpec = false;
		if ( type(activeSpecNumber) == "number" and type(selectedSpecNumber) == "number" ) then
			isActiveSpec = (selectedSpecNumber == activeSpecNumber);
		elseif ( type(activeSpecNumber) == "number" ) then
			isActiveSpec = (talentGroup == activeSpecNumber);
		else
			-- Fallback to base game API if activeSpecNumber is not available
			isActiveSpec = (talentGroup == GetActiveTalentGroup());
		end
		if ( isActiveSpec ) then
			RemoveGlyphFromSocket(self.data);
		end
	end,
	OnCancel = function (self)
	end,
	hideOnEscape = 1,
	timeout = 0,
	exclusive = 1,
}

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

local function GlyphFrame_GetTextureForIcon(icon)
	if ( type(icon) == "number" ) then
		return GLYPH_ICON_TEXTURES[icon];
	elseif ( type(icon) == "string" and icon ~= "" ) then
		return icon;
	end
	return nil;
end

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

local glyphPositions = {
	[1] = {"CENTER", -1, 126},
	[2] = {"CENTER", -1, -119},
	[3] = {"TOPLEFT", 8, -62},
	[4] = {"BOTTOMRIGHT", -10, 70},
	[5] = {"TOPRIGHT", -8, -62},
	[6] = {"BOTTOMLEFT", 7, 70},
};

local GLYPH_SOCKET_UNLOCK_LEVELS = {
	[1] = 15,
	[2] = 15,
	[3] = 50,
	[4] = 30,
	[5] = 70,
	[6] = 80,
};

local function GlyphFrame_PositionSockets(frame)
	if ( not frame or not frame.background ) then
		return;
	end

	for index, position in ipairs(glyphPositions) do
		local glyphButton = _G[frame:GetName().."Glyph"..index];
		if ( glyphButton ) then
			glyphButton:ClearAllPoints();
			local point, offsetX, offsetY = position[1], position[2], position[3];
			glyphButton:SetPoint(point, frame.background, point, offsetX or 0, offsetY or 0);
		end
	end
end

local function GlyphFrame_GetSocketUnlockLevel(slotIndex, glyphType)
	if ( type(SpecMap_GetGlyphSocketUnlockLevel) == "function" ) then
		local level = SpecMap_GetGlyphSocketUnlockLevel(slotIndex);
		if ( level ) then
			return level;
		end
	end
	return GLYPH_SOCKET_UNLOCK_LEVELS[slotIndex] or ((glyphType == GLYPHTYPE_MINOR) and 15 or 25);
end


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
	
	-- Get glyph spell from SpecMap if using SpecMap (for tooltip purposes)
	local specGlyphSpell, specGlyphIcon, specAuthoritative = GlyphFrame_GetSpecMapGlyphInfo(talentGroup, id);
	if ( specAuthoritative and specGlyphSpell ) then
		glyphSpell = specGlyphSpell;
	elseif ( specAuthoritative and not specGlyphSpell ) then
		glyphSpell = nil;
	end

	local slotTexCoords = GLYPH_SLOTS[id] or GLYPH_SLOTS[0];
	if ( slotTexCoords ) then
		self.background:SetTexCoord(slotTexCoords.left, slotTexCoords.right, slotTexCoords.top, slotTexCoords.bottom);
	end

	local glyphIconTexture = nil;
	if ( specAuthoritative and specGlyphIcon ) then
		glyphIconTexture = GlyphFrame_GetTextureForIcon(specGlyphIcon);
	end
	if ( not glyphIconTexture ) then
		glyphIconTexture = GlyphFrame_GetTextureForIcon(iconFilename);
	end

	local hasGlyph = (glyphSpell and glyphSpell > 0);

	-- Always hide glyph texture (inner rune) - we only show borders
	self.glyph:Hide();
	self.glyph:SetTexture(nil);
	
	-- Always hide background - we only show borders
	self.background:Hide();

	local isMinor = glyphType == 2;
	if ( isMinor ) then
		GlyphFrameGlyph_SetGlyphType(self, GLYPHTYPE_MINOR);
	else
		GlyphFrameGlyph_SetGlyphType(self, GLYPHTYPE_MAJOR);
	end

	self.elapsed = 0;
	self.tintElapsed = 0;
	
	-- Hide highlight and setting textures by default (will be shown later if needed)
	if ( self.highlight ) then
		self.highlight:Hide();
	end

	-- Check if viewing active spec for desaturation
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

	if ( not enabled ) then
		-- Socket is locked - show locked texture
		self.shine:Hide();
		self.background:Hide();
		self.glyph:Hide();
		self.ring:Hide();
		self.setting:SetTexture("Interface\\Spellbook\\UI-GlyphFrame-Locked");
		self.setting:SetTexCoord(.1, .9, .1, .9);
		-- Tooltip logic is kept in OnEnter handler
	else
		-- Socket is unlocked
		self.spell = glyphSpell; -- Store for tooltip
		
		if ( hasGlyph ) then
			-- Glyph is slotted - show both ring and setting
			self.shine:Show();
			self.ring:Show();
			self.setting:SetTexture("Interface\\Spellbook\\UI-GlyphFrame");
			self.background:Show();
			self.background:SetAlpha(1);
			self.background:SetTexCoord(GLYPH_SLOTS[id].left, GLYPH_SLOTS[id].right, GLYPH_SLOTS[id].top, GLYPH_SLOTS[id].bottom);
			
			local glyphTexture = glyphIconTexture;
			if ( glyphTexture ) then
				self.glyph:SetTexture(glyphTexture);
				self.glyph:Show();
			else
				self.glyph:Hide();
			end

			-- Ensure highlight is hidden
			if ( self.highlight ) then
				self.highlight:Hide();
			end
		else
			-- No glyph slotted - show only ring texture
			self.shine:Show();
			self.ring:Show();
			self.background:Show();
			self.background:SetTexCoord(GLYPH_SLOTS[0].left, GLYPH_SLOTS[0].right, GLYPH_SLOTS[0].top, GLYPH_SLOTS[0].bottom);
			self.background:SetAlpha(1);
			self.glyph:Hide();
		end
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
	-- Simplified: no animations, just handle cursor
	if ( self.hasCursor and SpellIsTargeting() ) then
		if ( GlyphMatchesSocket(self:GetID()) ) then
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
				local dialog = StaticPopup_Show("CONFIRM_REMOVE_GLYPH_SPECMAP", glyphName);
				if ( dialog ) then
					dialog.data = id;
				end
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
	local talentGroup = PlayerTalentFrame and PlayerTalentFrame.talentGroup;
	local id = self:GetID();

	local enabled, glyphType = GetGlyphSocketInfo(id, talentGroup);
	local specSocketEnabled = select(1, GlyphFrame_GetSpecMapSocketInfo(id));
	if ( specSocketEnabled ~= nil ) then
		enabled = specSocketEnabled;
	end

	if ( self.highlight ) then
		if ( enabled ) then
			local isActiveSpec = false;
			if ( PlayerTalentFrame and not PlayerTalentFrame.pet and not PlayerTalentFrame.inspect ) then
				if ( type(selectedSpecNumber) == "number" and type(activeSpecNumber) == "number" ) then
					isActiveSpec = (selectedSpecNumber == activeSpecNumber);
				else
					local activeGroup = GetActiveTalentGroup(PlayerTalentFrame.inspect, PlayerTalentFrame.pet);
					isActiveSpec = (PlayerTalentFrame.talentGroup == activeGroup);
				end
			end
			if ( isActiveSpec ) then
				self.highlight:SetVertexColor(1, 1, 1);
				self.highlight:SetAlpha(HIGHLIGHT_BASEALPHA);
			else
				self.highlight:SetVertexColor(0.6, 0.6, 0.6);
				self.highlight:SetAlpha(HIGHLIGHT_BASEALPHA * 0.75);
			end
			self.highlight:Show();
		else
			self.highlight:Hide();
		end
	end
	
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
 
	local enabled, glyphType, glyphSpell = GetGlyphSocketInfo(id, talentGroup);
	local specSocketEnabled, specGlyphType = GlyphFrame_GetSpecMapSocketInfo(id);
	if ( specSocketEnabled ~= nil ) then
		enabled = specSocketEnabled;
	end
	if ( specGlyphType ~= nil ) then
		glyphType = specGlyphType;
	end
	if ( not glyphType and id and id >= 1 and id <= NUM_GLYPH_SLOTS ) then
		if ( id == 1 or id == 4 or id == 6 ) then
			glyphType = GLYPHTYPE_MAJOR;
		else
			glyphType = GLYPHTYPE_MINOR;
		end
	end

	local specGlyphSpell, _, specAuthoritative = GlyphFrame_GetSpecMapGlyphInfo(talentGroup, id);
	if ( specAuthoritative ) then
		glyphSpell = specGlyphSpell or 0;
	end

	local glyphTypeText = (glyphType == GLYPHTYPE_MINOR) and "Minor Glyph" or "Major Glyph";
	local hasGlyph = (glyphSpell and glyphSpell > 0);

	GameTooltip:ClearLines();

	if ( not enabled ) then
		GameTooltip:AddLine("Locked", 1, 0, 0);
		GameTooltip:AddLine(glyphTypeText, 0.6, 0.8, 1);
		local unlockLevel = GlyphFrame_GetSocketUnlockLevel(id, glyphType);
		if ( unlockLevel ) then
			GameTooltip:AddLine(string.format("Unlocked at level %d.", unlockLevel), 1, 0.82, 0);
		end
		GameTooltip:Show();
		return;
	end

	if ( hasGlyph ) then
		local link = GetSpellLink(glyphSpell);
		if ( link ) then
			GameTooltip:SetHyperlink(link);
		else
			GameTooltip:SetGlyph(id, talentGroup);
		end
		local descText, descR, descG, descB;
		local numLines = GameTooltip:NumLines();
		if ( numLines >= 2 ) then
			local descLine = _G["GameTooltipTextLeft2"];
			if ( descLine ) then
				descText = descLine:GetText();
				descR, descG, descB = descLine:GetTextColor();
				if ( descText and descText ~= "" ) then
					for lineIndex = 2, numLines - 1 do
						local currentLine = _G["GameTooltipTextLeft" .. lineIndex];
						local nextLine = _G["GameTooltipTextLeft" .. (lineIndex + 1)];
						if ( currentLine and nextLine ) then
							local nextText = nextLine:GetText();
							currentLine:SetText(nextText);
							local nr, ng, nb = nextLine:GetTextColor();
							currentLine:SetTextColor(nr, ng, nb);
						end
					end
					local lastLine = _G["GameTooltipTextLeft" .. numLines];
					if ( lastLine ) then
						lastLine:SetText("");
					end
				end
			end
		end
		GameTooltip:AddLine(glyphTypeText, 0.6, 0.8, 1);
		if ( descText and descText ~= "" ) then
			GameTooltip:AddLine(descText, descR or 1, descG or 1, descB or 1);
		end
		GameTooltip:AddLine("<Shift Right Click to Remove>", 0.6, 0.6, 0.6);
		GameTooltip:Show();
	else
		GameTooltip:AddLine("Empty", 0.6, 0.6, 0.6);
		GameTooltip:AddLine(glyphTypeText, 0.6, 0.8, 1);
		GameTooltip:AddLine("Use a Glyph from your inventory to inscribe your spellbook.", 1, 0.82, 0);
		GameTooltip:Show();
	end
end

function GlyphFrameGlyph_OnLeave (self)
	self.hasCursor = nil;
	self.highlight:Hide();
	GameTooltip:Hide();
end

function GlyphFrame_OnUpdate (self, elapsed)
end

function GlyphFrame_PulseGlow ()
	-- Disabled glow pulse animation to improve FPS
	GlyphFrame.glow:Show();
	GlyphFrame.glow.pulse:Play();
end

function GlyphFrame_OnShow (self)
	PlayerTalentFrameControlBar:Hide();
	PlayerTalentFrameControlBarResetButton:Hide();
	PlayerTalentFrameControlBarLearnButton:Hide();
	GlyphFrame_PositionSockets(self);
	
	GlyphFrame_Update();
end

function GlyphFrame_OnLoad (self)
	local name = self:GetName();
	self.background = _G[name .. "Background"];
	-- Set scale to baseline (1.0) to match PlayerTalentFrame and ensure proper alignment
	self:SetScale(1.0);
	GlyphFrame_PositionSockets(self);
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
			GlyphFrame_PositionSockets(self);
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
