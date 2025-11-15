MAX_TALENT_GROUPS = 2;
MAX_TALENT_TABS = 3;
MAX_NUM_TALENT_TIERS = 15;
NUM_TALENT_COLUMNS = 4;
MAX_NUM_TALENTS = 40;
PLAYER_TALENTS_PER_TIER = 5;
PET_TALENTS_PER_TIER = 3;

DEFAULT_TALENT_SPEC = 1;
DEFAULT_TALENT_TAB = 1;

TALENT_BUTTON_SIZE = 32;
MAX_NUM_BRANCH_TEXTURES = 30;
MAX_NUM_ARROW_TEXTURES = 30;
INITIAL_TALENT_OFFSET_X = 35;
INITIAL_TALENT_OFFSET_Y = 20;
TREE_WIDTH = 160; -- Approximate width of one talent tree

TALENT_HYBRID_ICON = "Interface\\Icons\\Ability_DualWieldSpecialization";

-- Talent System Opcodes and Message Prefixes
SPEC_INFO_OP = 7;
MESSAGE_PREFIX_SERVER = "AC_CU_SERVER_MSG";
MESSAGE_PREFIX_GET = "AC_CU_GET";
MESSAGE_PREFIX_POST = "AC_CU_POST";

TALENT_BRANCH_TEXTURECOORDS = {
	up = {
		[1] = {0.12890625, 0.25390625, 0 , 0.484375},
		[-1] = {0.12890625, 0.25390625, 0.515625 , 1.0}
	},
	down = {
		[1] = {0, 0.125, 0, 0.484375},
		[-1] = {0, 0.125, 0.515625, 1.0}
	},
	left = {
		[1] = {0.2578125, 0.3828125, 0, 0.5},
		[-1] = {0.2578125, 0.3828125, 0.5, 1.0}
	},
	right = {
		[1] = {0.2578125, 0.3828125, 0, 0.5},
		[-1] = {0.2578125, 0.3828125, 0.5, 1.0}
	},
	topright = {
		[1] = {0.515625, 0.640625, 0, 0.5},
		[-1] = {0.515625, 0.640625, 0.5, 1.0}
	},
	topleft = {
		[1] = {0.640625, 0.515625, 0, 0.5},
		[-1] = {0.640625, 0.515625, 0.5, 1.0}
	},
	bottomright = {
		[1] = {0.38671875, 0.51171875, 0, 0.5},
		[-1] = {0.38671875, 0.51171875, 0.5, 1.0}
	},
	bottomleft = {
		[1] = {0.51171875, 0.38671875, 0, 0.5},
		[-1] = {0.51171875, 0.38671875, 0.5, 1.0}
	},
	tdown = {
		[1] = {0.64453125, 0.76953125, 0, 0.5},
		[-1] = {0.64453125, 0.76953125, 0.5, 1.0}
	},
	tup = {
		[1] = {0.7734375, 0.8984375, 0, 0.5},
		[-1] = {0.7734375, 0.8984375, 0.5, 1.0}
	},
};

TALENT_ARROW_TEXTURECOORDS = {
	top = {
		[1] = {0, 0.5, 0, 0.5},
		[-1] = {0, 0.5, 0.5, 1.0}
	},
	right = {
		[1] = {1.0, 0.5, 0, 0.5},
		[-1] = {1.0, 0.5, 0.5, 1.0}
	},
	left = {
		[1] = {0.5, 1.0, 0, 0.5},
		[-1] = {0.5, 1.0, 0.5, 1.0}
	},
};


local min = min;
local max = max;
local huge = math.huge;
local rshift = bit.rshift;

if ( type(SpecMap_IsUsingCustomTalents) ~= "function" ) then
	function SpecMap_IsUsingCustomTalents()
		if ( type(SpecMap) == "table" ) then
			if ( type(SpecMap.useCustomTalents) == "boolean" ) then
				return SpecMap.useCustomTalents;
			end
			if ( type(SpecMap.specs) == "table" ) then
				for _, specData in pairs(SpecMap.specs) do
					if ( specData ~= nil ) then
						return true;
					end
				end
			end
		end
		return false;
	end
end

if ( type(SpecMap_ResolveTalentGroupForBaseAPI) ~= "function" ) then
	function SpecMap_ResolveTalentGroupForBaseAPI(talentGroup)
		if ( SpecMap_IsUsingCustomTalents() ) then
			if ( type(talentGroup) == "number" and talentGroup >= 1 ) then
				return talentGroup;
			end
			return 1;
		end
		return 1;
	end
end

function ClearBaseTextures(object)
	if object:IsObjectType("Texture") then
		if kill then
			object:Kill()
		elseif alpha then
			object:SetAlpha(0)
		else
			object:SetTexture()
		end
	else
		if object.GetNumRegions then
			for i = 1, object:GetNumRegions() do
				local region = select(i, object:GetRegions())
				if region and region.IsObjectType and region:IsObjectType("Texture") then
					if kill then
						region:Kill()
					elseif alpha then
						region:SetAlpha(0)
					else
						region:SetTexture()
					end
				end
			end
		end
	end
end

function ReskinTab(tab)
	if (not tab) or (tab.backdrop) then
		return;
	end
	
	local tabs = {
		"LeftDisabled",
		"MiddleDisabled",
		"RightDisabled",
		"Left",
		"Middle",
		"Right"
	};
	
	for _, object in ipairs(tabs) do
		local tex = _G[tab:GetName()..object];
		if tex then
			tex:SetVertexColor(0, 0, 0, 0);
		end
	end
	
	local highlightTex = tab.GetHighlightTexture and tab:GetHighlightTexture();
	if highlightTex then
		highlightTex:SetVertexColor(0, 0, 0, 0);
	else
		ClearBaseTextures(tab);
	end
	
	tab:SetHitRectInsets(10, 10, 3, 3);
end

function TalentFrame_Load(TalentFrame)
	TalentFrame.TALENT_BRANCH_ARRAY={};
	for i=1, MAX_NUM_TALENT_TIERS do
		TalentFrame.TALENT_BRANCH_ARRAY[i] = {};
		for j=1, NUM_TALENT_COLUMNS do
			TalentFrame.TALENT_BRANCH_ARRAY[i][j] = {id=nil, up=0, left=0, right=0, down=0, leftArrow=0, rightArrow=0, topArrow=0};
		end
	end
	TalentFrame.TALENT_FRAME_MAP = {};
end

function TalentFrame_Update(TalentFrame)
	if ( not TalentFrame ) then
		return;
	end

	if ( TalentFrame.updateFunction ) then
		TalentFrame.updateFunction();
	end

	local talentFrameName = TalentFrame:GetName();
	local selectedTab = PanelTemplates_GetSelectedTab(TalentFrame);
	local preview = GetCVarBool("previewTalents");

	-- get active talent group
	-- Use activeSpecNumber (from decoded message) as source of truth, fallback to base game API
	local isActiveTalentGroup;
	if ( TalentFrame.inspect ) then
		-- even though we have inspection data for more than one talent group, we're only showing one for now
		isActiveTalentGroup = true;
	else
		-- For player talents: prioritize activeSpecNumber (from decoded message) over GetActiveTalentGroup
		if ( not TalentFrame.pet and type(_G["activeSpecNumber"]) == "number" and _G["activeSpecNumber"] > 0 ) then
			isActiveTalentGroup = (TalentFrame.talentGroup == _G["activeSpecNumber"]);
		else
			-- Fallback to base game API
			isActiveTalentGroup = TalentFrame.talentGroup == GetActiveTalentGroup(TalentFrame.inspect, TalentFrame.pet);
		end
	end
	-- Setup Frame (background textures - use first tab's background for multi-tab view)
	local base;
	local displayTab = selectedTab;
	-- For multi-tab rendering, always use first talent tab for background
	if ( not TalentFrame.inspect and not TalentFrame.pet ) then
		-- For player talents, always use first talent tab background when showing all trees
		if ( selectedTab == 4 ) then
			displayTab = 1; -- Use first talent tab for background
		else
			displayTab = selectedTab; -- Use selected tab if it's a talent tab
		end
	end
	local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(displayTab, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
	
	if ( not TalentFrame.inspect and not TalentFrame.pet ) then
		if ( type(SpecMap_TalentCacheApplyTabPoints) == "function" ) then
			pointsSpent, previewPointsSpent = SpecMap_TalentCacheApplyTabPoints(TalentFrame.talentGroup, displayTab, pointsSpent, previewPointsSpent);
		end
	end
	if ( name ) then
		base = "Interface\\TalentFrame\\"..background.."-";
	else
		-- temporary default for classes without talents poor guys
		base = "Interface\\TalentFrame\\MageFire-";
	end
	-- For player talents with multi-tab rendering, hide the main background pieces
	-- They will be replaced by column-specific backgrounds
	local renderAllTabs = (not TalentFrame.inspect and not TalentFrame.pet and selectedTab ~= 4);
	if ( renderAllTabs ) then
		-- Hide main background pieces for player talents
		local backgroundPiece = _G[talentFrameName.."BackgroundTopLeft"];
		if ( backgroundPiece ) then
			backgroundPiece:Hide();
		end
		backgroundPiece = _G[talentFrameName.."BackgroundTopRight"];
		if ( backgroundPiece ) then
			backgroundPiece:Hide();
		end
		backgroundPiece = _G[talentFrameName.."BackgroundBottomLeft"];
		if ( backgroundPiece ) then
			backgroundPiece:Hide();
		end
		backgroundPiece = _G[talentFrameName.."BackgroundBottomRight"];
		if ( backgroundPiece ) then
			backgroundPiece:Hide();
		end
	else
		-- For pet/inspect views, show and desaturate the background if this isn't the active talent group
		local backgroundPiece = _G[talentFrameName.."BackgroundTopLeft"];
		backgroundPiece:SetTexture(base.."TopLeft");
		SetDesaturation(backgroundPiece, not isActiveTalentGroup);
		backgroundPiece:Show();
		backgroundPiece = _G[talentFrameName.."BackgroundTopRight"];
		backgroundPiece:SetTexture(base.."TopRight");
		SetDesaturation(backgroundPiece, not isActiveTalentGroup);
		backgroundPiece:Show();
		backgroundPiece = _G[talentFrameName.."BackgroundBottomLeft"];
		backgroundPiece:SetTexture(base.."BottomLeft");
		SetDesaturation(backgroundPiece, not isActiveTalentGroup);
		backgroundPiece:Show();
		backgroundPiece = _G[talentFrameName.."BackgroundBottomRight"];
		backgroundPiece:SetTexture(base.."BottomRight");
		SetDesaturation(backgroundPiece, not isActiveTalentGroup);
		backgroundPiece:Show();
	end

	-- get unspent talent points
	local unspentPoints = TalentFrame_UpdateTalentPoints(TalentFrame);
	
	-- For player talents, render all tabs side-by-side when tab 1 (Talents) is selected
	-- When glyph tab (tab 4) is selected, show glyphs instead
	-- Tab 1 now represents all talent trees shown together
	-- Note: renderAllTabs was already defined above, but we need it here too
	local renderAllTabs = (not TalentFrame.inspect and not TalentFrame.pet and selectedTab ~= 4);
	local tabsToRender = {};
	
	-- For player talents with multi-tab rendering, create grid-based frame structure
	if ( renderAllTabs ) then
		local scrollFrame = _G[talentFrameName.."ScrollFrame"];
		if ( scrollFrame ) then
			scrollFrame:Hide(); -- Hide the scroll frame
		end
		
		-- Create or get the grid container frame
		local gridContainer = _G[talentFrameName.."GridContainer"];
		-- Calculate width: 3 columns with 4px padding between them
		-- Grid dimensions: 4 columns * 56px = 224px width per column
		local cellSize = 40;
		local gridWidth = 4 * cellSize; -- 224 pixels per column
		local gridHeight = 11 * cellSize; -- 616 pixels height
		local columnPadding = 4; -- 4px gap between columns
		local totalGridWidth = (gridWidth * 3) + (columnPadding * 2); -- 672 + 8 = 680 pixels total (3 columns + 2 gaps)

		gridContainer:Show();
		gridContainer:SetWidth(totalGridWidth);
		-- Grid container height includes the header (40px) plus the grid height
		local headerHeight = 40;
		gridContainer:SetHeight(gridHeight + headerHeight);
		-- 11 x diff | 31 y diff
		-- Calculate frame dimensions first
		local baseFrameHeight = 512;
		local heightIncrease = gridHeight + 32 - 332; -- Increase needed (grid + header - original scroll height)
		-- Reduce padding to create tighter fit around columns
		-- Base frame width is 384, but we need to fit the grid which is wider
		-- Add 67px padding to the grid width for proper spacing
		local newFrameWidth = totalGridWidth + 80; -- 67px padding for grid container
		
		-- Increase the main talent frame height to accommodate the taller grid + headers
		TalentFrame:SetHeight(baseFrameHeight + heightIncrease);
		TalentFrame:SetWidth(newFrameWidth);

		-- Reposition the grid container to be centered horizontally and properly aligned with points bar
		gridContainer:ClearAllPoints();
		local pointsBar = _G[talentFrameName.."PointsBar"];
		local titleText = _G[talentFrameName.."TitleText"];
		if ( pointsBar and titleText ) then
			-- Anchor bottom to top of points bar
			gridContainer:SetPoint("BOTTOM", pointsBar, "TOP", -11, 0);
			-- Anchor top to 8px below the bottom of title text
			gridContainer:SetPoint("TOP", titleText, "BOTTOM", -11, -8);
		else
			-- Fallback: anchor to top and center if points bar or title text not found
			gridContainer:SetPoint("TOP", TalentFrame, "TOP", -10, -77);
			local horizontalOffset = (newFrameWidth - totalGridWidth) / 2;
			gridContainer:SetPoint("LEFT", TalentFrame, "LEFT", horizontalOffset, 0);
		end
		
		-- Show and configure all 3 column frames (from XML)
		-- If columns 2 and 3 weren't created due to circular anchor dependencies, create them programmatically
		-- gridWidth, gridHeight, and columnPadding are already defined above
		local col1Frame = _G[talentFrameName.."GridColumn1"];
		local col2Frame = _G[talentFrameName.."GridColumn2"];
		local col3Frame = _G[talentFrameName.."GridColumn3"];
		
		-- Ensure column 1 exists and is positioned
		if ( not col1Frame ) then
			-- Create column 1 if it doesn't exist (shouldn't happen, but safety check)
			col1Frame = CreateFrame("Frame", talentFrameName.."GridColumn1", gridContainer, "PlayerTalentFrameGridColumnTemplate");
			col1Frame:SetSize(gridWidth, gridHeight + 40); -- Add header height
			col1Frame:SetPoint("BOTTOMLEFT", gridContainer, "BOTTOMLEFT", 0, 0);
		else
			-- Resize existing column to match grid dimensions + header
			col1Frame:SetSize(gridWidth, gridHeight + 40); -- Add header height
		end
		
		-- Create column 2 if it doesn't exist (likely due to circular anchor dependency in XML)
		if ( not col2Frame ) then
			col2Frame = CreateFrame("Frame", talentFrameName.."GridColumn2", gridContainer, "PlayerTalentFrameGridColumnTemplate");
			col2Frame:SetSize(gridWidth, gridHeight + 40); -- Add header height
		else
			-- Resize existing column to match grid dimensions + header
			col2Frame:SetSize(gridWidth, gridHeight + 40); -- Add header height
		end
		
		-- Create column 3 if it doesn't exist (likely due to circular anchor dependency in XML)
		if ( not col3Frame ) then
			col3Frame = CreateFrame("Frame", talentFrameName.."GridColumn3", gridContainer, "PlayerTalentFrameGridColumnTemplate");
			col3Frame:SetSize(gridWidth, gridHeight + 40); -- Add header height
		else
			-- Resize existing column to match grid dimensions + header
			col3Frame:SetSize(gridWidth, gridHeight + 40); -- Add header height
		end
		
		-- Fix anchors to break circular dependencies and ensure proper positioning
		-- The XML has column 2 referencing column 3, which creates a circular dependency
		-- We need to position them sequentially: 1 -> 2 -> 3
		if ( col1Frame ) then
			-- Ensure column 1 is anchored to the container (should already be in XML)
			local hasPoint = col1Frame:GetPoint(1);
			if ( not hasPoint ) then
				col1Frame:SetPoint("BOTTOMLEFT", gridContainer, "BOTTOMLEFT", 0, 0);
			end
		end
		
		if ( col2Frame and col1Frame ) then
			-- Column 2: Position to the right of column 1 with 4px padding
			-- Clear XML anchors that reference column 3 (circular dependency)
			col2Frame:ClearAllPoints();
			col2Frame:SetPoint("TOPLEFT", col1Frame, "TOPRIGHT", columnPadding, 0);
			col2Frame:SetPoint("BOTTOMLEFT", col1Frame, "BOTTOMRIGHT", columnPadding, 0);
		end
		
		if ( col3Frame and col2Frame ) then
			-- Column 3: Position to the right of column 2 with 4px padding
			-- Clear XML anchor that references BOTTOMRIGHT (might not work correctly)
			col3Frame:ClearAllPoints();
			col3Frame:SetPoint("TOPLEFT", col2Frame, "TOPRIGHT", columnPadding, 0);
			col3Frame:SetPoint("BOTTOMLEFT", col2Frame, "BOTTOMRIGHT", columnPadding, 0);
		end
		
		for colIndex = 1, 3 do
			local colFrame = _G[talentFrameName.."GridColumn"..colIndex];
			if ( colFrame ) then
				-- Show the column frame
				colFrame:Show();
				
				-- Get background info for this column's talent tree
				local tabName, tabIcon, tabPointsSpent, tabBackground = GetTalentTabInfo(colIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
				local treeBase = "Interface\\TalentFrame\\MageFire-"; -- Default fallback
				if ( tabBackground ) then
					treeBase = "Interface\\TalentFrame\\"..tabBackground.."-";
				end
				
				-- Create or get header frame for this column
				local headerFrame = _G[talentFrameName.."GridColumn"..colIndex.."Header"];
				if ( not headerFrame ) then
					headerFrame = CreateFrame("Frame", talentFrameName.."GridColumn"..colIndex.."Header", colFrame);
					headerFrame:SetHeight(40);
					headerFrame:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, 0);
					headerFrame:SetPoint("TOPRIGHT", colFrame, "TOPRIGHT", 0, 0);
					
					-- Set black backdrop with alpha 0.85
					headerFrame:SetBackdrop({
						bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
						edgeFile = nil,
						tile = true,
						tileSize = 16,
						edgeSize = 0,
						insets = { left = 0, right = 0, top = 0, bottom = 0 }
					});
					headerFrame:SetBackdropColor(0, 0, 0, 0.85);
					
					-- Create icon texture
					local iconTexture = headerFrame:CreateTexture(nil, "ARTWORK");
					iconTexture:SetSize(32, 32);
					iconTexture:SetPoint("LEFT", headerFrame, "LEFT", 4, 0);
					headerFrame.iconTexture = iconTexture;
					
					-- Create font string for title with smaller font size
					local titleText = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
					titleText:SetPoint("LEFT", iconTexture, "RIGHT", 10, 0); -- 4px original + 6px = 10px
					headerFrame.titleText = titleText;
					
					-- Create font string for points spent on the right side (smaller font)
					local pointsText = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
					pointsText:SetPoint("RIGHT", headerFrame, "RIGHT", -8, 0); -- 8px inset from right edge
					pointsText:SetTextColor(1, 1, 1, 1); -- White color
					headerFrame.pointsText = pointsText;
				end
				
				-- Update header content
				if ( tabIcon ) then
					headerFrame.iconTexture:SetTexture(tabIcon);
					headerFrame.iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);
					headerFrame.iconTexture:Show();
				else
					headerFrame.iconTexture:Hide();
				end
				
				if ( tabName ) then
					headerFrame.titleText:SetText(tabName);
				else
					headerFrame.titleText:SetText("");
				end
				
				-- Get and display points spent for this tab
				local displayPointsSpent = tabPointsSpent or 0;
				if ( not TalentFrame.inspect and not TalentFrame.pet ) then
					-- For player talents, use SpecMap cache if available
					if ( type(SpecMap_TalentCacheSumTabPoints) == "function" ) then
						local cachedPoints = SpecMap_TalentCacheSumTabPoints(TalentFrame.talentGroup, colIndex);
						if ( cachedPoints ) then
							displayPointsSpent = cachedPoints;
						end
					end
				end
				headerFrame.pointsText:SetText(displayPointsSpent);
				
				headerFrame:Show();
				
				-- Hide the old 4-part background system
				local bgTopLeft = _G[talentFrameName.."GridColumn"..colIndex.."BackgroundTopLeft"];
				local bgTopRight = _G[talentFrameName.."GridColumn"..colIndex.."BackgroundTopRight"];
				local bgBottomLeft = _G[talentFrameName.."GridColumn"..colIndex.."BackgroundBottomLeft"];
				local bgBottomRight = _G[talentFrameName.."GridColumn"..colIndex.."BackgroundBottomRight"];
				
				if ( bgTopLeft ) then
					bgTopLeft:Hide();
				end
				if ( bgTopRight ) then
					bgTopRight:Hide();
				end
				if ( bgBottomLeft ) then
					bgBottomLeft:Hide();
				end
				if ( bgBottomRight ) then
					bgBottomRight:Hide();
				end
				
				-- Create or get single background texture that spans the whole column
				local colBackground = _G[talentFrameName.."GridColumn"..colIndex.."Background"];
				if ( not colBackground ) then
					colBackground = colFrame:CreateTexture(talentFrameName.."GridColumn"..colIndex.."Background", "BACKGROUND");
					colBackground:SetDrawLayer("BACKGROUND", -1);
				end
				
				-- Set texture path: "Interface\\FrameGeneral\\SpecBG\\"..background (no -Part suffix)
				local specBgPath = "Interface\\FrameGeneral\\SpecBG\\"..tabBackground;
				if ( not tabBackground ) then
					-- Default fallback
					specBgPath = "Interface\\FrameGeneral\\SpecBG\\MageFire";
				end
				
				colBackground:SetTexture(specBgPath);
				colBackground:SetTexCoord(0, 1, 0, 0.639648438);
				colBackground:ClearAllPoints();
				colBackground:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, 0);
				colBackground:SetPoint("BOTTOMRIGHT", colFrame, "BOTTOMRIGHT", 0, 0);
				
				-- Desaturate if this isn't the active talent group
				SetDesaturation(colBackground, not isActiveTalentGroup);
				colBackground:Show();
				
				-- Create 4x11 grid of frames within this column if not already created
				if ( not colFrame.gridFrames ) then
					colFrame.gridFrames = {};
					local headerHeight = 40; -- Header is 40px tall
					local tabIndex = colIndex; -- This column corresponds to tab 1, 2, or 3
					local numTalents = GetNumTalents(tabIndex, TalentFrame.inspect, TalentFrame.pet);
					
					for gridRow = 1, 11 do
						colFrame.gridFrames[gridRow] = {};
						for gridCol = 1, 4 do
							local gridFrame = CreateFrame("Frame", "$parentCell"..gridRow..":"..gridCol, colFrame);
							-- Each grid cell is 56x56 pixels (talent button size + spacing)
							gridFrame:SetSize(cellSize, cellSize);
							-- Position: column determines X offset, row determines Y offset
							-- Grid starts below the 40px header
							local xOffset = (gridCol - 1) * cellSize;
							local yOffset = -headerHeight - ((gridRow - 1) * cellSize);
							gridFrame:SetPoint("TOPLEFT", colFrame, "TOPLEFT", xOffset, yOffset);
							
							colFrame.gridFrames[gridRow][gridCol] = gridFrame;
							
							-- Find the talent that belongs in this grid cell (matching tier and column)
							local talentIndex = nil;
							local talentIconTexture = nil;
							for i = 1, numTalents do
								local name, iconTexture, tier, column = GetTalentInfo(tabIndex, i, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
								if ( name and tier == gridRow and column == gridCol ) then
									talentIndex = i;
									talentIconTexture = iconTexture;
									break;
								end
							end
							
							-- Create a talent button for this cell if a talent exists at this position
							if ( talentIndex ) then
								local buttonName = talentFrameName.."GridColumn"..colIndex.."Talent"..talentIndex;
								local talentButton = CreateFrame("Button", buttonName, gridFrame, "PlayerTalentGridButtonTemplate");
								talentButton:SetID(talentIndex);
								talentButton:ClearAllPoints();
								talentButton:SetPoint("CENTER", gridFrame, "CENTER", 0, 0);
								talentButton:SetSize(28, 28); -- Standard talent button size
								
								-- Set backdrop with black border using white8x8 texture
								talentButton:SetBackdrop({
									edgeFile = "Interface\\BUTTONS\\WHITE8X8",
									edgeSize = 1,
									tile = false,
									tileSize = 0,
									insets = { left = 0, right = 0, top = 0, bottom = 0 }
								});
								talentButton:SetBackdropBorderColor(0, 0, 0, 1); -- Black border
								
								talentButton.tabIndex = colIndex;

								-- Set the icon texture for this talent button
								local iconTexture = _G[buttonName.."IconTexture"];
								if ( iconTexture and talentIconTexture ) then
									iconTexture:SetTexture(talentIconTexture);
									iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);
								end
								
								-- Set up click and enter handlers for grid talent buttons (player talents only)
								if ( not TalentFrame.inspect and not TalentFrame.pet ) then
									talentButton:SetScript("OnClick", function(self, button)
										HandlePlayerTalentButtonClick(self, button, TalentFrame);
									end);
									
									-- Set up OnEnter handler to show tooltip with current rank
									talentButton:SetScript("OnEnter", function(self)
										GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
										
										local talentIndex = self:GetID();
										local talentGroup = SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup);
										local talentLink = GetTalentLink(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup), GetCVarBool("previewTalents"));
										
										-- For player talents, get the current rank from SpecMap cache
										if ( not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_TalentCacheExtractTalentID) == "function" ) then
											local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
											
											if ( talentId and type(SpecMap_TalentCacheGetRank) == "function" ) then
												local currentRank = SpecMap_TalentCacheGetRank(talentGroup, tabIndex, talentId) or 0;
												
												-- Get talent name for link construction
												local talentName = GetTalentInfo(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup);
												
												-- Construct a talent link with the current rank from cache
												if ( talentName and currentRank > 0 ) then
													local talentLinkWithRank = "|cff4e96f7|Htalent:"..tabIndex..":"..talentIndex..":"..currentRank.."|h["..talentName.."]|h|r";
													GameTooltip:SetHyperlink(talentLinkWithRank);
												else
													-- No rank or no name, use normal SetTalent
													GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup, false);
												end
											else
												-- Fallback to normal SetTalent
												GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup, false);
											end
										else
											-- For pet/inspect, use normal SetTalent
											GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup, false);
										end
									end);
									
									-- Set up OnLeave handler to hide tooltip
									talentButton:SetScript("OnLeave", function(self)
										GameTooltip:Hide();
									end);
								end

								-- Don't draw prerequisite lines here - wait until all cells are created
								-- Store talent button directly on the grid frame for later prerequisite line drawing
								gridFrame.talent = talentButton;
							else
								gridFrame.talent = nil; -- No talent at this position
							end
						end
					end
			end
		end
	end
	
	-- Now that all cells are created, draw prerequisite lines for all talent buttons
	if ( renderAllTabs ) then
		for colIndex = 1, 3 do
			local colFrame = _G[talentFrameName.."GridColumn"..colIndex];
			if ( colFrame and colFrame.gridFrames ) then
				local tabIndex = colIndex; -- Column index corresponds to tab index
				local numTalents = GetNumTalents(tabIndex, TalentFrame.inspect, TalentFrame.pet);
				
				-- Iterate through all grid cells and draw prerequisites for cells with talents
				for gridRow = 1, 11 do
					for gridCol = 1, 4 do
						local gridFrame = colFrame.gridFrames[gridRow][gridCol];
						if ( gridFrame and gridFrame.talent ) then
							local talentButton = gridFrame.talent;
							local talentIndex = talentButton:GetID();
							-- Draw prerequisite lines now that all cells exist
							DrawGridPrereqs(talentButton, talentIndex, tabIndex);
						end
					end
				end
			end
		end
	end
		
	-- Update all grid talent buttons with desaturation and rank text
	if ( not TalentFrame.inspect and not TalentFrame.pet ) then
		local talentFrameName = TalentFrame:GetName();
			
			-- Get unspent points (calculate once for all columns)
			local unspentPoints = TalentFrame_UpdateTalentPoints(TalentFrame);
			
			-- Get active talent group status (calculate once for all columns)
			-- Use activeSpecNumber (from decoded message) as source of truth, fallback to base game API
			local isActiveTalentGroup = false;
			if ( not TalentFrame.inspect and not TalentFrame.pet ) then
				-- For player talents: prioritize activeSpecNumber (from decoded message) over GetActiveTalentGroup
				if ( type(_G["activeSpecNumber"]) == "number" and _G["activeSpecNumber"] > 0 ) then
					isActiveTalentGroup = (TalentFrame.talentGroup == _G["activeSpecNumber"]);
				else
					-- Fallback to base game API
					isActiveTalentGroup = TalentFrame.talentGroup == GetActiveTalentGroup(TalentFrame.inspect, TalentFrame.pet);
				end
			else
				isActiveTalentGroup = TalentFrame.talentGroup == GetActiveTalentGroup(TalentFrame.inspect, TalentFrame.pet);
			end
			
			for colIndex = 1, 3 do
				local colFrame = _G[talentFrameName.."GridColumn"..colIndex];
				if ( colFrame and colFrame.gridFrames ) then
					local tabIndex = colIndex; -- Column index corresponds to tab index
					-- Get tab points spent for this tab
					local tabPointsSpent = 0;
					if ( type(SpecMap_TalentCacheSumTabPoints) == "function" ) then
						local cachePoints = SpecMap_TalentCacheSumTabPoints(TalentFrame.talentGroup, tabIndex);
						if ( cachePoints ~= nil ) then
							tabPointsSpent = cachePoints;
						end
					else
						local _, _, pointsSpent = GetTalentTabInfo(tabIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
						tabPointsSpent = pointsSpent or 0;
					end
					
					-- Loop through all grid frames in this column
					for gridRow = 1, 11 do
						for gridCol = 1, 4 do
							local gridFrame = colFrame.gridFrames[gridRow] and colFrame.gridFrames[gridRow][gridCol];
							if ( gridFrame and gridFrame.talent ) then
								local talentButton = gridFrame.talent;
								local talentIndex = talentButton:GetID();
								
								-- Get talent info (rank from GetTalentInfo is ignored, we use SpecMap cache)
								local name, iconTexture, tier, column, _, maxRank = GetTalentInfo(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
								if ( name and tier and column and maxRank ) then
									-- Get talent ID from talent link
									local talentID = nil;
									local talentLink = GetTalentLink(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup), GetCVarBool("previewTalents"));
									if ( type(talentLink) == "string" ) then
										talentID = tonumber(string.match(talentLink, "Htalent:(%d+)") or string.match(talentLink, "talent:(%d+)"));
									end
									
									-- Ensure OnEnter/OnLeave handlers are set (they might have been lost during updates)
									if ( not TalentFrame.inspect and not TalentFrame.pet ) then
										-- Re-set OnEnter handler to ensure it's always present
										talentButton:SetScript("OnEnter", function(self)
											GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
											
											local talentIndex = self:GetID();
											local talentGroup = SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup);
											local baseLink = GetTalentLink(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup, false);
											
											-- For player talents, get the current rank from SpecMap cache
											if ( not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_TalentCacheExtractTalentID) == "function" ) then
												local talentId = SpecMap_TalentCacheExtractTalentID(baseLink);
												
												if ( talentId and type(SpecMap_TalentCacheGetRank) == "function" ) then
													local currentRank = SpecMap_TalentCacheGetRank(talentGroup, tabIndex, talentId) or 0;
													
													-- Get talent name for the link
													local talentName = GetTalentInfo(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup);
													
													if ( talentName and currentRank > 0 ) then
														-- Construct hyperlink with correct rank
														-- Rank format: -1 = rank 0, 0 = rank 1, 1 = rank 2, etc.
														-- So rankNum = currentRank - 1
														local rankNum = currentRank - 1;
														local talentLink = "|cff4e96f7|Htalent:"..talentId..":"..rankNum.."|h["..talentName.."]|h|r";
														GameTooltip:SetHyperlink(talentLink);
													else
														-- Rank is 0 or no name, use normal SetTalent
														GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup, false);
													end
												else
													-- Fallback to normal SetTalent
													GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup, false);
												end
											else
												-- For pet/inspect, use normal SetTalent
												GameTooltip:SetTalent(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, talentGroup, false);
											end
										end);
										
										-- Re-set OnLeave handler
										talentButton:SetScript("OnLeave", function(self)
											GameTooltip:Hide();
										end);
									end
									
									-- Update the grid talent button (rank will be read from SpecMap cache in UpdateGridTalentButton)
									UpdateGridTalentButton(talentButton, tabIndex, talentIndex, talentID, tier, column, maxRank, TalentFrame, tabPointsSpent, unspentPoints, isActiveTalentGroup);
									talentButton:Show();
								else
									talentButton:Hide();
								end
							end
						end
					end
				end
			end
		end
	else
		-- For single tab rendering (pet/inspect/glyph), show scroll frame and hide grid
		local scrollFrame = _G[talentFrameName.."ScrollFrame"];
		if ( scrollFrame ) then
			scrollFrame:Show();
		end
		local gridContainer = _G[talentFrameName.."GridContainer"];
		if ( gridContainer ) then
			gridContainer:Hide();
			-- Hide all column frames
			for colIndex = 1, 3 do
				local colFrame = _G[talentFrameName.."GridColumn"..colIndex];
				if ( colFrame ) then
					colFrame:Hide();
				end
			end
		end
		
		-- Reset the main talent frame height to base size
		local baseFrameHeight = 512;
		TalentFrame:SetHeight(baseFrameHeight);
		-- Reset width to base size
		TalentFrame:SetWidth(384);
	end
	
	if ( renderAllTabs ) then
		-- Get all player talent tabs (always skip glyph tab 4)
		-- For player talents, we always want to render tabs 1, 2, and 3 (the actual talent tree tabs)
		local numTabs = GetNumTalentTabs(TalentFrame.inspect, TalentFrame.pet);
		-- GetNumTalentTabs returns 4 for player (3 talent tabs + 1 glyph tab)
		-- We want to render tabs 1, 2, 3 (the talent tree tabs)
		-- For player talents, always render tabs 1, 2, 3 regardless of GetTalentTabInfo return
		for tabIndex = 1, 3 do
			-- Only add tabs 1-3 (the actual talent tree tabs)
			-- Tab 4 is the glyph tab, which we skip
			if ( tabIndex <= numTabs ) then
				-- Always add tabs 1-3 for player talents, even if GetTalentTabInfo fails
				-- The function might fail for inactive tabs, but we still want to render them
				local tabName = GetTalentTabInfo(tabIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
				table.insert(tabsToRender, tabIndex);
			end
		end
		-- If no tabs to render (shouldn't happen), fall back to first talent tab
		if ( #tabsToRender == 0 ) then
			tabsToRender = {1}; -- Default to first talent tab
		end
		
		-- Resize scroll frame and scroll child to accommodate multiple tabs
		-- Only do this if we're NOT using the grid (i.e., for pet/inspect, not player talents with grid)
		local scrollFrame = _G[talentFrameName.."ScrollFrame"];
		local scrollChild = _G[talentFrameName.."ScrollChildFrame"];
		local gridContainer = _G[talentFrameName.."GridContainer"];
		local usingGrid = (gridContainer and gridContainer:IsShown());
		
		if ( scrollFrame and scrollChild and not usingGrid ) then
			local numTabsToRender = #tabsToRender;
			local newWidth = TREE_WIDTH * numTabsToRender;
			scrollFrame:SetWidth(newWidth);
			-- ScrollChild needs extra width for scrollbar, add padding
			scrollChild:SetWidth(newWidth + 20);
			
			-- Resize the main talent frame to accommodate the wider scroll frame
			-- Base frame width is 384, scroll frame is anchored with -65 offset from right
			-- For 3 tabs: scroll width is 888, so frame needs to be wider
			-- Frame width = scroll width + right offset (65) + left padding/margins
			local baseFrameWidth = 384;
			local scrollFrameRightOffset = 65; -- Offset from XML: x="-65"
			local frameWidthIncrease = newWidth - TREE_WIDTH; -- Increase over single tree width (296)
			local newFrameWidth = baseFrameWidth + frameWidthIncrease;
			TalentFrame:SetWidth(newFrameWidth + 67);
		end
	else
		-- For pet/inspect, render only selected tab
		tabsToRender = {selectedTab};
		
		-- Reset scroll frame to original size
		local scrollFrame = _G[talentFrameName.."ScrollFrame"];
		local scrollChild = _G[talentFrameName.."ScrollChildFrame"];
		if ( scrollFrame and scrollChild ) then
			scrollFrame:SetWidth(296);
			scrollChild:SetWidth(320);
			
			-- Reset the main talent frame to base size
			TalentFrame:SetWidth(384);
		end
	end

	TalentFrame_ResetBranches(TalentFrame);
	local talentFrameTalentName = talentFrameName.."Talent";
	
	-- For multi-tab rendering, we need to keep track of which buttons have been used
	-- Since we only have 40 buttons total, we need to allocate them across tabs
	-- For now, let's try: each tab uses buttons 1-40, but they're positioned at different offsets
	-- This means buttons from tab 1 will be overwritten by tab 2, which is the problem
	
	-- Reset branches and textures once at the start (not per tab)
	-- For multi-tab rendering, we'll populate branches as we go
	TalentFrame_ResetBranchTextureCount(TalentFrame);
	TalentFrame_ResetArrowTextureCount(TalentFrame);
	
	-- For multi-tab rendering, DON'T hide all buttons at once
	-- Instead, track which buttons are used per tab and only hide unused ones
	if ( not renderAllTabs ) then
		-- For single tab rendering, hide all buttons first
		for i=1, MAX_NUM_TALENTS do
			local buttonName = talentFrameTalentName..i;
			local button = _G[buttonName];
			if ( button ) then
				button:Hide();
				if ( button.prereqBranches ) then
					for _, texture in pairs(button.prereqBranches) do
						if ( texture and texture.Hide ) then
							texture:Hide();
						end
					end
				end
			end
		end
	end
	
	-- Render each tab
	-- Each tab reuses buttons 1-40 independently, positioned at different horizontal offsets
	-- Store TalentFrame reference for button positioning
	local talentFrameRef = TalentFrame;
	for tabIter = 1, #tabsToRender do
		local currentTab = tabsToRender[tabIter];
		local tabOffsetX = (tabIter - 1) * TREE_WIDTH;
		local numTalents = GetNumTalents(currentTab, TalentFrame.inspect, TalentFrame.pet);
		
		-- Ensure we don't exceed the button limit for this tab
		if ( numTalents > MAX_NUM_TALENTS ) then
			message("Too many talents in tab "..currentTab.."! Max: "..MAX_NUM_TALENTS);
			numTalents = MAX_NUM_TALENTS;
		end
		
		-- For multi-tab rendering, we need to clear branch array for this tab before building
		-- Since TALENT_BRANCH_ARRAY is shared, we clear the relevant parts for this tab
		-- But we must do this carefully - only clear after previous tab's branches are drawn
		if ( renderAllTabs and tabIter == 1 ) then
			-- For first tab, clear the branch array once
			TalentFrame_ResetBranches(TalentFrame);
		elseif ( renderAllTabs and tabIter > 1 ) then
			-- For subsequent tabs, clear only the branch data we'll be using
			-- Since each tab uses the same tier/column structure, we need to clear it
			-- But branches are drawn immediately after each tab, so this is OK
			for i=1, MAX_NUM_TALENT_TIERS do
				for j=1, NUM_TALENT_COLUMNS do
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].id = nil;
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].up = 0;
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].down = 0;
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].left = 0;
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].right = 0;
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].rightArrow = 0;
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].leftArrow = 0;
					TalentFrame.TALENT_BRANCH_ARRAY[i][j].topArrow = 0;
				end
			end
		elseif ( not renderAllTabs ) then
			-- For single tab (pet/inspect), reset normally
			TalentFrame_ResetBranches(TalentFrame);
		end
		
		-- compute tab points spent for this specific tab
		local tabPointsSpent = 0;
		if ( not TalentFrame.inspect and not TalentFrame.pet ) then
			if ( type(SpecMap_TalentCacheSumTabPoints) == "function" ) then
				tabPointsSpent = SpecMap_TalentCacheSumTabPoints(TalentFrame.talentGroup, currentTab) or 0;
			elseif ( TalentFrame.pointsSpent and TalentFrame.previewPointsSpent ) then
				tabPointsSpent = TalentFrame.pointsSpent + TalentFrame.previewPointsSpent;
			end
		elseif ( TalentFrame.pointsSpent and TalentFrame.previewPointsSpent ) then
			tabPointsSpent = TalentFrame.pointsSpent + TalentFrame.previewPointsSpent;
		end
		
		local forceDesaturated, tierUnlocked;
		-- Use buttons 1 through numTalents for this tab (reusing the same button pool for each tab)
		for i=1, numTalents do
			local buttonName = talentFrameTalentName..i;
			local button = _G[buttonName];
			if ( button ) then
				-- Set the button info
				local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq, previewRank, meetsPreviewPrereq =
					GetTalentInfo(currentTab, i, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
				local meetsSpecMapPrereq = true;
				if ( name and not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_TalentCacheCheckPrereqs) == "function" ) then
					local talentID;
					local talentLink = GetTalentLink(currentTab, i, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup), GetCVarBool("previewTalents"));
					if ( type(talentLink) == "string" ) then
						talentID = tonumber(string.match(talentLink, "Htalent:(%d+)") or string.match(talentLink, "talent:(%d+)") );
					end
					meetsSpecMapPrereq = SpecMap_TalentCacheCheckPrereqs(TalentFrame.talentGroup, currentTab, talentID, tier, column);
				end
				if ( name ) then
					local baseRank = rank or 0;
					if ( not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_GetTalentRank) == "function" ) then
						local talentID;
						local talentLink = GetTalentLink(currentTab, i, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup), GetCVarBool("previewTalents"));
						if ( type(talentLink) == "string" ) then
							talentID = tonumber(string.match(talentLink, "Htalent:(%d+)") or string.match(talentLink, "talent:(%d+)") );
						end
						local specRank = SpecMap_GetTalentRank(TalentFrame.talentGroup, currentTab, i, talentID);
						if ( type(specRank) == "number" ) then
							baseRank = specRank;
						end
					end
				rank = baseRank;
				local displayRank;
				if ( preview and type(previewRank) == "number" ) then
					displayRank = previewRank;
					if ( displayRank < rank ) then
						displayRank = rank;
					end
				else
					displayRank = rank;
				end

					_G[buttonName.."Rank"]:SetText(displayRank);
					SetTalentButtonLocation(button, tier, column, tabOffsetX);
					TalentFrame.TALENT_BRANCH_ARRAY[tier][column].id = button:GetID();
					
					-- Store button frame reference in coordinate map [tabIndex][tier][column]
					TalentFrame.TALENT_FRAME_MAP[currentTab] = TalentFrame.TALENT_FRAME_MAP[currentTab] or {};
					TalentFrame.TALENT_FRAME_MAP[currentTab][tier] = TalentFrame.TALENT_FRAME_MAP[currentTab][tier] or {};
					TalentFrame.TALENT_FRAME_MAP[currentTab][tier][column] = button;
			
				-- If player has no talent points or this is the inactive talent group then show only talents with points in them
				if ( (unspentPoints <= 0 or not isActiveTalentGroup) and displayRank == 0 ) then
					forceDesaturated = 1;
				else
					forceDesaturated = nil;
				end

				-- is this talent's tier unlocked?
				if ( ((tier - 1) * (TalentFrame.pet and PET_TALENTS_PER_TIER or PLAYER_TALENTS_PER_TIER) <= tabPointsSpent) ) then
					tierUnlocked = 1;
				else
					tierUnlocked = nil;
				end

				SetItemButtonTexture(button, iconTexture);

				if (TalentFrame.pet) then
					local prereqsSet =
					TalentFrame_SetPrereqs(TalentFrame, tier, column, forceDesaturated, tierUnlocked, preview,
					GetTalentPrereqs(currentTab, i, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup)));
					if ( prereqsSet and ( (preview and meetsPreviewPrereq) or (not preview and meetsPrereq)) ) then
						SetItemButtonDesaturated(button, nil);

						if ( displayRank < maxRank ) then
							-- Rank is green if not maxed out
							_G[buttonName.."Slot"]:SetVertexColor(0.1, 1.0, 0.1);
							_G[buttonName.."Rank"]:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
						else
							_G[buttonName.."Slot"]:SetVertexColor(1.0, 0.82, 0);
							_G[buttonName.."Rank"]:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
						end
						_G[buttonName.."RankBorder"]:Show();
						_G[buttonName.."Rank"]:Show();
					else
						SetItemButtonDesaturated(button, 1, 0.65, 0.65, 0.65);
						_G[buttonName.."Slot"]:SetVertexColor(0.5, 0.5, 0.5);
						if ( rank == 0 ) then
							_G[buttonName.."RankBorder"]:Hide();
							_G[buttonName.."Rank"]:Hide();
						else
							_G[buttonName.."RankBorder"]:SetVertexColor(0.5, 0.5, 0.5);
							_G[buttonName.."Rank"]:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b);
						end
					end
				end

				button:Show();
				-- Show prerequisite branch textures if they exist
				if ( button.prereqBranches ) then
					for _, texture in pairs(button.prereqBranches) do
						if ( texture and texture.Show ) then
							texture:Show();
						end
					end
				end
			end
		end
	end
		
		-- Draw branches for this tab (with tab offset)
		-- Note: Branches are drawn immediately after building branch array for this tab
		-- For multi-tab rendering, each tab's branches are drawn at different horizontal offsets
		local node;
		local ignoreUp;
		local tempNode;
		for i=1, MAX_NUM_TALENT_TIERS do
			for j=1, NUM_TALENT_COLUMNS do
				node = TalentFrame.TALENT_BRANCH_ARRAY[i][j];
				
				-- Setup offsets with tab offset
				xOffset = ((j - 1) * 63) + INITIAL_TALENT_OFFSET_X + 2;
				yOffset = -((i - 1) * 63) - INITIAL_TALENT_OFFSET_Y - 2;
			
				if ( node.id ) then
					-- Has talent
					if ( node.up ~= 0 ) then
						if ( not ignoreUp ) then
							TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["up"][node.up], xOffset, yOffset + TALENT_BUTTON_SIZE, TalentFrame, tabOffsetX);
						else
							ignoreUp = nil;
						end
					end
					if ( node.down ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["down"][node.down], xOffset, yOffset - TALENT_BUTTON_SIZE + 1, TalentFrame, tabOffsetX);
					end
					if ( node.left ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["left"][node.left], xOffset - TALENT_BUTTON_SIZE, yOffset, TalentFrame, tabOffsetX);
					end
					if ( node.right ~= 0 ) then
						-- See if any connecting branches are gray and if so color them gray
						tempNode = TalentFrame.TALENT_BRANCH_ARRAY[i][j+1];	
						if ( tempNode.left ~= 0 and tempNode.down < 0 ) then
							TalentFrame_SetBranchTexture(i, j-1, TALENT_BRANCH_TEXTURECOORDS["right"][tempNode.down], xOffset + TALENT_BUTTON_SIZE, yOffset, TalentFrame, tabOffsetX);
						else
							TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["right"][node.right], xOffset + TALENT_BUTTON_SIZE + 1, yOffset, TalentFrame, tabOffsetX);
						end
					end
					-- Draw arrows
					if ( node.rightArrow ~= 0 ) then
						TalentFrame_SetArrowTexture(i, j, TALENT_ARROW_TEXTURECOORDS["right"][node.rightArrow], xOffset + TALENT_BUTTON_SIZE/2 + 5, yOffset, TalentFrame, tabOffsetX);
					end
					if ( node.leftArrow ~= 0 ) then
						TalentFrame_SetArrowTexture(i, j, TALENT_ARROW_TEXTURECOORDS["left"][node.leftArrow], xOffset - TALENT_BUTTON_SIZE/2 - 5, yOffset, TalentFrame, tabOffsetX);
					end
					if ( node.topArrow ~= 0 ) then
						TalentFrame_SetArrowTexture(i, j, TALENT_ARROW_TEXTURECOORDS["top"][node.topArrow], xOffset, yOffset + TALENT_BUTTON_SIZE/2 + 5, TalentFrame, tabOffsetX);
					end
				else
					-- Doesn't have a talent
					if ( node.up ~= 0 and node.left ~= 0 and node.right ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["tup"][node.up], xOffset , yOffset, TalentFrame, tabOffsetX);
					elseif ( node.down ~= 0 and node.left ~= 0 and node.right ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["tdown"][node.down], xOffset , yOffset, TalentFrame, tabOffsetX);
					elseif ( node.left ~= 0 and node.down ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["topright"][node.left], xOffset , yOffset, TalentFrame, tabOffsetX);
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["down"][node.down], xOffset , yOffset - 32, TalentFrame, tabOffsetX);
					elseif ( node.left ~= 0 and node.up ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["bottomright"][node.left], xOffset , yOffset, TalentFrame, tabOffsetX);
					elseif ( node.left ~= 0 and node.right ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["right"][node.right], xOffset + TALENT_BUTTON_SIZE, yOffset, TalentFrame, tabOffsetX);
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["left"][node.left], xOffset + 1, yOffset, TalentFrame, tabOffsetX);
					elseif ( node.right ~= 0 and node.down ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["topleft"][node.right], xOffset , yOffset, TalentFrame, tabOffsetX);
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["down"][node.down], xOffset , yOffset - 32, TalentFrame, tabOffsetX);
					elseif ( node.right ~= 0 and node.up ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["bottomleft"][node.right], xOffset , yOffset, TalentFrame, tabOffsetX);
					elseif ( node.up ~= 0 and node.down ~= 0 ) then
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["up"][node.up], xOffset , yOffset, TalentFrame, tabOffsetX);
						TalentFrame_SetBranchTexture(i, j, TALENT_BRANCH_TEXTURECOORDS["down"][node.down], xOffset , yOffset - 32, TalentFrame, tabOffsetX);
						ignoreUp = 1;
					end
				end
			end
		end
	end

	-- Hide any unused branch textures
	for i=TalentFrame_GetBranchTextureCount(TalentFrame), MAX_NUM_BRANCH_TEXTURES do
		_G[talentFrameName.."Branch"..i]:Hide();
	end
	-- Hide and unused arrow textures
	for i=TalentFrame_GetArrowTextureCount(TalentFrame), MAX_NUM_ARROW_TEXTURES do
		_G[talentFrameName.."Arrow"..i]:Hide();
	end
	
	-- For multi-tab rendering, hide any buttons that weren't used
	-- (all buttons should have been shown during rendering, so this is just cleanup)
	if ( renderAllTabs ) then
		-- Buttons are shown during the tab loop, so we don't need to hide unused ones here
		-- They're already positioned and shown for their respective tabs
	end
end

function DrawGridPrereqs(button, talentIndex, tabIndex)
	local TalentFrame = PlayerTalentFrame;
	local prereqTier, prereqColumn = GetTalentPrereqs(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
	local name, iconTexture, tier, column = GetTalentInfo(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, TalentFrame.talentGroup);
	local colFrame = _G["PlayerTalentFrameGridColumn"..tabIndex]

	-- Initialize prereqTextures table to store texture references
	button.prereqTextures = button.prereqTextures or {};

	if ( prereqColumn and prereqTier ) then
		-- Ensure the prerequisite cell exists
		if ( not colFrame.gridFrames or not colFrame.gridFrames[prereqTier] or not colFrame.gridFrames[prereqTier][prereqColumn] ) then
			return; -- Prerequisite cell doesn't exist yet, skip drawing
		end
		
		local reqCell = colFrame.gridFrames[prereqTier][prereqColumn];
		-- Ensure the prerequisite cell has a talent button
		if ( not reqCell.talent ) then
			return; -- Prerequisite talent button doesn't exist, skip drawing
		end
		
		local arrow = button:CreateTexture("$parentArrow", "OVERLAY", 10);
		arrow:SetPoint("CENTER", button, "TOP", 0, 0);
		arrow:SetSize(16, 16);
		arrow:SetTexture("Interface\\TalentFrame\\UI-TalentArrows");
		arrow:SetTexCoord(0, 0.5, 0, 0.5);
		button.prereqTextures.arrow = arrow;

		if ( prereqColumn ~= column ) then
			if ( prereqTier ~= tier ) then
				-- requires corner
				-- Ensure corner cell exists
				if ( not colFrame.gridFrames or not colFrame.gridFrames[prereqTier] or not colFrame.gridFrames[prereqTier][column] ) then
					return; -- Corner cell doesn't exist, skip drawing
				end
				local cornerCell = colFrame.gridFrames[prereqTier][column];
				local corner = button:CreateTexture("$parentCorner", 'BACKGROUND', -1);
				corner:ClearAllPoints()
				corner:SetPoint("CENTER", cornerCell, "CENTER")
				corner:SetTexture("Interface\\FrameGeneral\\branch-corn")
				corner:SetSize(16, 16)
				button.prereqTextures.corner = corner;

				arrow:SetPoint("CENTER", button, "TOP", 0, 0)
				arrow:SetTexCoord(0, 0.5, 0, 0.5)
				if (prereqColumn < column) then
					corner:SetTexCoord(0, 1, 0, 1)
					
					local branchH = button:CreateTexture("$parentBranchH", 'BACKGROUND', -1);
					branchH:ClearAllPoints()
					branchH:SetPoint("LEFT", reqCell.talent, "RIGHT", 0, 0)
					branchH:SetPoint("RIGHT", corner, "LEFT", 0, 0)
					branchH:SetTexture("Interface\\FrameGeneral\\branch-hori")
					branchH:SetHorizTile(true)
					branchH:SetTexCoord(0, 1, 0, 1)
					branchH:SetSize(16, 16)
					button.prereqTextures.branchH = branchH;

					local branchV = button:CreateTexture("$parentBranchV", 'BACKGROUND', -1);
					branchV:ClearAllPoints()
					branchV:SetPoint("TOP", corner, "BOTTOM", 0, 0)
					branchV:SetPoint("BOTTOM", button, "TOP", 0, 0)
					branchV:SetTexture("Interface\\FrameGeneral\\branch-vert")
					branchV:SetVertTile(true)
					branchV:SetSize(16, 16)
					branchV:SetTexCoord(0, 1, 0, 1)
					button.prereqTextures.branchV = branchV;
				else
					corner:SetTexCoord(1, 0, 0, 1)
					corner:SetSize(16, 16)
					
					local branchH = button:CreateTexture("$parentBranchH", 'BACKGROUND', -1);
					branchH:ClearAllPoints()
					branchH:SetPoint("RIGHT", reqCell.talent, "LEFT", 0, 0)
					branchH:SetPoint("LEFT", corner, "RIGHT", 0, 0)
					branchH:SetTexture("Interface\\FrameGeneral\\branch-hori")
					branchH:SetTexCoord(0, 1, 0, 1)
					branchH:SetHorizTile(true)
					branchH:SetSize(16, 16)
					button.prereqTextures.branchH = branchH;

					local branchV = button:CreateTexture("$parentBranchV", 'BACKGROUND', -1);
					branchV:ClearAllPoints()
					branchV:SetPoint("TOP", corner, "BOTTOM", 0, 0)
					branchV:SetPoint("BOTTOM", arrow, "CENTER", 0, 0)
					branchV:SetTexture("Interface\\FrameGeneral\\branch-vert")
					branchV:SetVertTile(true)
					branchV:SetSize(16, 16)
					branchV:SetTexCoord(0, 1, 0, 1)
					button.prereqTextures.branchV = branchV;
				end
			elseif prereqColumn < column then
				arrow:SetPoint("CENTER", button, "LEFT", 0, 0)
				arrow:SetTexCoord(0.5, 1, 0, 0.5)

				local branch = button:CreateTexture("$parentBranch", 'BACKGROUND', -1);
				branch:ClearAllPoints()
				branch:SetPoint("LEFT", reqCell.talent, "RIGHT", 0, 0)
				branch:SetPoint("RIGHT", arrow, "CENTER", 0, 0)
				branch:SetTexture("Interface\\FrameGeneral\\branch-hori")
				branch:SetTexCoord(0, 1, 0, 1)
				branch:SetSize(16, 16)
				button.prereqTextures.branch = branch;
			else
				arrow:SetPoint("CENTER", button, "RIGHT", 0, 0)
				arrow:SetTexCoord(1, 0.5, 0, 0.5)

				local branch = button:CreateTexture("$parentBranch", 'BACKGROUND', -1);
				branch:ClearAllPoints()
				branch:SetPoint("RIGHT", reqCell.talent, "LEFT", 0, 0)
				branch:SetPoint("LEFT", arrow, "CENTER", 0, 0)
				branch:SetTexture("Interface\\FrameGeneral\\branch-hori")
				branch:SetTexCoord(0, 1, 0, 1)
				branch:SetSize(16, 16)
				button.prereqTextures.branch = branch;
			end
		else
			arrow:SetPoint("CENTER", button, "TOP", 0, 0)
			arrow:SetTexCoord(0, 0.5, 0, 0.5)

			local branch = button:CreateTexture("$parentBranch", 'BACKGROUND', -1);
			branch:ClearAllPoints()
			branch:SetPoint("TOP", reqCell.talent, "BOTTOM", 0, 0)
			branch:SetPoint("BOTTOM", arrow, "CENTER", 0, 0)
			branch:SetTexture("Interface\\FrameGeneral\\branch-vert")
			branch:SetVertTile(true)
			branch:SetSize(16, 16)
			button.prereqTextures.branch = branch;
		end
	end
end

function TalentFrame_SetArrowTexture(tier, column, texCoords, xOffset, yOffset, TalentFrame, tabOffsetX)
	tabOffsetX = tabOffsetX or 0;
	local talentFrameName = TalentFrame:GetName();
	local arrowTexture = TalentFrame_GetArrowTexture(TalentFrame);
	arrowTexture:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4]);
	arrowTexture:SetPoint("TOPLEFT", talentFrameName.."ArrowFrame", "TOPLEFT", xOffset + tabOffsetX, yOffset);
end

function TalentFrame_SetBranchTexture(tier, column, texCoords, xOffset, yOffset, TalentFrame, tabOffsetX)
	tabOffsetX = tabOffsetX or 0;
	local talentFrameName = TalentFrame:GetName();
	local branchTexture = TalentFrame_GetBranchTexture(TalentFrame);
	branchTexture:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4]);
	branchTexture:SetPoint("TOPLEFT", talentFrameName.."ScrollChildFrame", "TOPLEFT", xOffset + tabOffsetX, yOffset);
end

function TalentFrame_GetArrowTexture(TalentFrame)
	local talentFrameName = TalentFrame:GetName();
	local arrowTexture = _G[talentFrameName.."Arrow"..TalentFrame.arrowIndex];
	TalentFrame.arrowIndex = TalentFrame.arrowIndex + 1;
	if ( not arrowTexture ) then
		message("Not enough arrow textures");
	else
		arrowTexture:Show();
		return arrowTexture;
	end
end

function TalentFrame_GetBranchTexture(TalentFrame)
	local talentFrameName = TalentFrame:GetName();
	local branchTexture = _G[talentFrameName.."Branch"..TalentFrame.textureIndex];
	TalentFrame.textureIndex = TalentFrame.textureIndex + 1;
	if ( not branchTexture ) then
		--branchTexture = CreateTexture("TalentFrameBranch"..TalentFrame.textureIndex);
		message("Not enough branch textures");
	else
		branchTexture:Show();
		return branchTexture;
	end
end

function TalentFrame_ResetArrowTextureCount(TalentFrame)
	TalentFrame.arrowIndex = 1;
end

function TalentFrame_ResetBranchTextureCount(TalentFrame)
	TalentFrame.textureIndex = 1;
end

function TalentFrame_GetArrowTextureCount(TalentFrame)
	return TalentFrame.arrowIndex;
end

function TalentFrame_GetBranchTextureCount(TalentFrame)
	return TalentFrame.textureIndex;
end

function TalentFrame_SetPrereqs(TalentFrame, buttonTier, buttonColumn, forceDesaturated, tierUnlocked, preview, ...)
	local requirementsMet = tierUnlocked and not forceDesaturated;
	for i=1, select("#", ...), 4 do
		local tier, column, isLearnable, isPreviewLearnable = select(i, ...);
		if ( forceDesaturated or
			 (preview and not isPreviewLearnable) or
			 (not preview and not isLearnable) ) then
			requirementsMet = nil;
		end
		TalentFrame_DrawLines(buttonTier, buttonColumn, tier, column, requirementsMet, TalentFrame);
	end
	return requirementsMet;
end


function TalentFrame_DrawLines(buttonTier, buttonColumn, tier, column, requirementsMet, TalentFrame)
	if ( requirementsMet ) then
		requirementsMet = 1;
	else
		requirementsMet = -1;
	end
	
	-- Check to see if are in the same column
	if ( buttonColumn == column ) then
		-- Check for blocking talents
		if ( (buttonTier - tier) > 1 ) then
			-- If more than one tier difference
			for i=tier + 1, buttonTier - 1 do
				if ( TalentFrame.TALENT_BRANCH_ARRAY[i][buttonColumn].id ) then
					-- If there's an id, there's a blocker
					message("Error this layout is blocked vertically "..TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][i].id);
					return;
				end
			end
		end
		
		-- Draw the lines
		for i=tier, buttonTier - 1 do
			TalentFrame.TALENT_BRANCH_ARRAY[i][buttonColumn].down = requirementsMet;
			if ( (i + 1) <= (buttonTier - 1) ) then
				TalentFrame.TALENT_BRANCH_ARRAY[i + 1][buttonColumn].up = requirementsMet;
			end
		end
		
		-- Set the arrow
		TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][buttonColumn].topArrow = requirementsMet;
		return;
	end
	-- Check to see if they're in the same tier
	if ( buttonTier == tier ) then
		local left = min(buttonColumn, column);
		local right = max(buttonColumn, column);
		
		-- See if the distance is greater than one space
		if ( (right - left) > 1 ) then
			-- Check for blocking talents
			for i=left + 1, right - 1 do
				if ( TalentFrame.TALENT_BRANCH_ARRAY[tier][i].id ) then
					-- If there's an id, there's a blocker
					message("there's a blocker "..tier.." "..i);
					return;
				end
			end
		end
		-- If we get here then we're in the clear
		for i=left, right - 1 do
			TalentFrame.TALENT_BRANCH_ARRAY[tier][i].right = requirementsMet;
			TalentFrame.TALENT_BRANCH_ARRAY[tier][i+1].left = requirementsMet;
		end
		-- Determine where the arrow goes
		if ( buttonColumn < column ) then
			TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][buttonColumn].rightArrow = requirementsMet;
		else
			TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][buttonColumn].leftArrow = requirementsMet;
		end
		return;
	end
	-- Now we know the prereq is diagonal from us
	local left = min(buttonColumn, column);
	local right = max(buttonColumn, column);
	-- Don't check the location of the current button
	if ( left == column ) then
		left = left + 1;
	else
		right = right - 1;
	end
	-- Check for blocking talents
	local blocked = nil;
	for i=left, right do
		if ( TalentFrame.TALENT_BRANCH_ARRAY[tier][i].id ) then
			-- If there's an id, there's a blocker
			blocked = 1;
		end
	end
	left = min(buttonColumn, column);
	right = max(buttonColumn, column);
	if ( not blocked ) then
		TalentFrame.TALENT_BRANCH_ARRAY[tier][buttonColumn].down = requirementsMet;
		TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][buttonColumn].up = requirementsMet;
		
		for i=tier, buttonTier - 1 do
			TalentFrame.TALENT_BRANCH_ARRAY[i][buttonColumn].down = requirementsMet;
			TalentFrame.TALENT_BRANCH_ARRAY[i + 1][buttonColumn].up = requirementsMet;
		end

		for i=left, right - 1 do
			TalentFrame.TALENT_BRANCH_ARRAY[tier][i].right = requirementsMet;
			TalentFrame.TALENT_BRANCH_ARRAY[tier][i+1].left = requirementsMet;
		end
		-- Place the arrow
		TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][buttonColumn].topArrow = requirementsMet;
		return;
	end
	-- If we're here then we were blocked trying to go vertically first so we have to go over first, then up
	if ( left == buttonColumn ) then
		left = left + 1;
	else
		right = right - 1;
	end
	-- Check for blocking talents
	for i=left, right do
		if ( TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][i].id ) then
			-- If there's an id, then throw an error
			message("Error, this layout is undrawable "..TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][i].id);
			return;
		end
	end
	-- If we're here we can draw the line
	left = min(buttonColumn, column);
	right = max(buttonColumn, column);
	--TALENT_BRANCH_ARRAY[tier][column].down = requirementsMet;
	--TALENT_BRANCH_ARRAY[buttonTier][column].up = requirementsMet;

	for i=tier, buttonTier-1 do
		TalentFrame.TALENT_BRANCH_ARRAY[i][column].up = requirementsMet;
		TalentFrame.TALENT_BRANCH_ARRAY[i+1][column].down = requirementsMet;
	end

	-- Determine where the arrow goes
	if ( buttonColumn < column ) then
		TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][buttonColumn].rightArrow =  requirementsMet;
	else
		TalentFrame.TALENT_BRANCH_ARRAY[buttonTier][buttonColumn].leftArrow =  requirementsMet;
	end
end



-- Helper functions

function TalentFrame_UpdateTalentPoints(TalentFrame)
	local talentPoints;
	if ( not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_GetFreeTalentPoints) == "function" ) then
		talentPoints = SpecMap_GetFreeTalentPoints();
	else
		talentPoints = GetUnspentTalentPoints(TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
	end
	local unspentPoints = talentPoints - GetGroupPreviewTalentPointsSpent(TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
	local talentFrameName = TalentFrame:GetName();
	_G[talentFrameName.."TalentPointsText"]:SetFormattedText(UNSPENT_TALENT_POINTS, HIGHLIGHT_FONT_COLOR_CODE..unspentPoints..FONT_COLOR_CODE_CLOSE);
	TalentFrame_ResetBranches(TalentFrame);
	_G[talentFrameName.."ScrollFrameScrollBarScrollDownButton"]:SetScript("OnClick", _G[talentFrameName.."DownArrow_OnClick"]);
	return unspentPoints;
end

function SetTalentButtonLocation(button, tier, column, tabOffsetX)
	tabOffsetX = tabOffsetX or 0;
	local parent = button:GetParent();
	if ( not parent ) then
		return;
	end
	column = ((column - 1) * 63) + INITIAL_TALENT_OFFSET_X + tabOffsetX;
	tier = -((tier - 1) * 63) - INITIAL_TALENT_OFFSET_Y;
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", column, tier);
end

function UpdateGridTalentButton(talentButton, tabIndex, talentIndex, talentID, tier, column, maxRank, TalentFrame, tabPointsSpent, unspentPoints, isActiveTalentGroup)
	if ( not talentButton ) then
		return;
	end
	
	local buttonName = talentButton:GetName();
	if ( not buttonName ) then
		return;
	end
	
	-- Get rank from cache for the current talent group (selected spec)
	local rank = 0;
	if ( not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_TalentCacheGetRank) == "function" ) then
		-- Ensure we're reading from the correct talent group
		local cachedRank = SpecMap_TalentCacheGetRank(TalentFrame.talentGroup, tabIndex, talentID);
		if ( cachedRank ~= nil ) then
			rank = cachedRank;
		else
			rank = 0; -- Explicitly set to 0 if not in cache
		end
	elseif ( not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_GetTalentRank) == "function" ) then
		local cachedRank = SpecMap_GetTalentRank(TalentFrame.talentGroup, tabIndex, talentIndex, talentID);
		if ( cachedRank ~= nil ) then
			rank = cachedRank;
		else
			rank = 0; -- Explicitly set to 0 if not in cache
		end
	end
	
	-- Calculate desaturation conditions
	local forceDesaturated = nil;
	-- For non-active specs: only show talents with points as saturated (desaturated if no points)
	-- For active specs: show talents based on prerequisites and tier unlock
	if ( not isActiveTalentGroup ) then
		-- Viewing a non-active spec: only desaturate if talent has no points
		if ( rank == 0 ) then
			forceDesaturated = true;
		end
	else
		-- Active spec: use normal logic
		if ( (unspentPoints <= 0) and rank == 0 ) then
			forceDesaturated = true;
		end
	end
	
	-- Check if tier is unlocked
	local tierUnlocked = false;
	if ( ((tier - 1) * PLAYER_TALENTS_PER_TIER <= tabPointsSpent) ) then
		tierUnlocked = true;
	end
	
	-- Check prerequisites
	local meetsSpecMapPrereq = true;
	if ( not TalentFrame.inspect and not TalentFrame.pet and type(SpecMap_TalentCacheCheckPrereqs) == "function" ) then
		meetsSpecMapPrereq = SpecMap_TalentCacheCheckPrereqs(TalentFrame.talentGroup, tabIndex, talentID, tier, column);
	end
	
	-- Apply desaturation to icon texture
	local iconTexture = _G[buttonName.."IconTexture"];
	if ( iconTexture ) then
		-- For non-active specs: only saturate talents with points (ignore prerequisites/tier)
		-- For active specs: use normal saturation logic
		if ( not isActiveTalentGroup ) then
			-- Non-active spec: saturate only if talent has points
			if ( rank > 0 ) then
				SetDesaturation(iconTexture, false);
			else
				SetDesaturation(iconTexture, true);
			end
		else
			-- Active spec: use normal logic
			if ( meetsSpecMapPrereq and tierUnlocked and not forceDesaturated ) then
				SetDesaturation(iconTexture, false);
			else
				SetDesaturation(iconTexture, true);
			end
		end
	end
	
	-- Apply desaturation to prerequisite textures (arrows and branches)
	local shouldDesaturate;
	if ( not isActiveTalentGroup ) then
		-- Non-active spec: desaturate prerequisite textures if talent has no points
		shouldDesaturate = (rank == 0);
	else
		-- Active spec: use normal logic
		shouldDesaturate = not (meetsSpecMapPrereq and tierUnlocked and not forceDesaturated);
	end
	if ( talentButton.prereqTextures ) then
		if ( talentButton.prereqTextures.arrow ) then
			SetDesaturation(talentButton.prereqTextures.arrow, shouldDesaturate);
		end
		if ( talentButton.prereqTextures.corner ) then
			SetDesaturation(talentButton.prereqTextures.corner, shouldDesaturate);
		end
		if ( talentButton.prereqTextures.branch ) then
			SetDesaturation(talentButton.prereqTextures.branch, shouldDesaturate);
		end
		if ( talentButton.prereqTextures.branchH ) then
			SetDesaturation(talentButton.prereqTextures.branchH, shouldDesaturate);
		end
		if ( talentButton.prereqTextures.branchV ) then
			SetDesaturation(talentButton.prereqTextures.branchV, shouldDesaturate);
		end
	end
	
	-- Update rank text
	local rankText = _G[buttonName.."Rank"];
	local rankBackdrop = _G[buttonName.."RankBackdrop"];
	if ( rankText ) then
		-- Determine if talent can be ranked up
		local canRankUp;
		if ( not isActiveTalentGroup ) then
			-- Non-active spec: cannot rank up (only show rank if points invested)
			canRankUp = false;
		else
			-- Active spec: use normal logic
			canRankUp = meetsSpecMapPrereq and tierUnlocked and not forceDesaturated;
		end
		
		-- For non-active specs: only show rank if points are invested (rank > 0)
		-- For active specs: show rank if points invested OR if can be ranked up
		if ( not isActiveTalentGroup ) then
			-- Non-active spec: only show rank if points invested
			if ( rank > 0 ) then
				rankText:Show();
				if ( rankBackdrop ) then
					rankBackdrop:Show();
				end
				rankText:SetText(rank);
				rankText:SetShadowOffset(1, -1);
				rankText:SetShadowColor(0, 0, 0, 1);
				-- Set color to white for all ranks in non-active specs
				rankText:SetTextColor(1, 1, 1, 1);
			else
				-- Hide rank text if no points invested
				rankText:Hide();
				if ( rankBackdrop ) then
					rankBackdrop:Hide();
				end
			end
		else
			-- Active spec: show rank if points invested OR if can be ranked up
			if ( rank == 0 and not canRankUp ) then
				-- Hide rank text if no points invested and talent cannot be ranked up
				rankText:Hide();
				if ( rankBackdrop ) then
					rankBackdrop:Hide();
				end
			else
				-- Show rank text if points invested OR if talent can be ranked up
				rankText:Show();
				if ( rankBackdrop ) then
					rankBackdrop:Show();
				end
				rankText:SetText(rank);
				
				-- Set outline/shadow for better visibility
				rankText:SetShadowOffset(1, -1);
				rankText:SetShadowColor(0, 0, 0, 1);
				
				-- Set color based on rank vs maxRank
				if ( rank >= maxRank ) then
					-- Yellow color (same as tab names/maxed talents)
					rankText:SetTextColor(1.0, 0.82, 0);
				else
					-- Green color for talents not maxed (or available to rank up)
					rankText:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
				end
			end
		end
	end
end

function HandlePlayerTalentButtonClick(self, button, TalentFrame)
	if ( not self or not TalentFrame or TalentFrame.inspect or TalentFrame.pet ) then
		return;
	end
	
	if ( IsModifiedClick("CHATLINK") ) then
		local tabIndex = self.tabIndex;
		local talentIndex = self:GetID();
		local link = GetTalentLink(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup), true);
		if ( link ) then
			ChatEdit_InsertLink(link);
		end
		return;
	end
	
	-- Check if we have an active spec selected (use numeric spec values from dropdown)
	if ( type(_G["selectedSpecNumber"]) ~= "number" or type(_G["activeSpecNumber"]) ~= "number" or _G["selectedSpecNumber"] ~= _G["activeSpecNumber"] ) then
		return;
	end
	
	local tabIndex = self.tabIndex;
	local talentIndex = self:GetID();
	local talentLink = GetTalentLink(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup), true);
	local talentId = SpecMap_TalentCacheExtractTalentID(talentLink);
	
	if ( not talentId ) then
		return;
	end
	
	if ( button == "LeftButton" ) then
		local _, _, tier, column, _, maxRank = GetTalentInfo(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
		local isAvailable = SpecMap_TalentCacheIsTalentAvailable(TalentFrame.talentGroup, tabIndex, talentId, tier);
		local freeTalents = SpecMap_TalentCacheGetFreeTalents();
		if ( isAvailable and (freeTalents == nil or freeTalents > 0) and SpecMap_TalentCacheAdjustRank(TalentFrame.talentGroup, tabIndex, talentId, 1, maxRank, tier) ) then
			TalentFrame_Update(TalentFrame);
			-- Refresh tooltip if it's showing for this button
			if ( GameTooltip:IsOwned(self) ) then
				-- Get the OnEnter handler and call it to refresh the tooltip
				local onEnterScript = self:GetScript("OnEnter");
				if ( onEnterScript ) then
					onEnterScript(self);
				end
			end
		end
	elseif ( button == "RightButton" ) then
		local _, _, tier, _, _, maxRank = GetTalentInfo(tabIndex, talentIndex, TalentFrame.inspect, TalentFrame.pet, SpecMap_ResolveTalentGroupForBaseAPI(TalentFrame.talentGroup));
		
		-- Get current rank from cache (includes user changes)
		local currentRank = SpecMap_TalentCacheGetRank(TalentFrame.talentGroup, tabIndex, talentId);
		-- Get base spec map rank (from decoded message, before any user changes)
		local baseSpecMapRank = SpecMap_GetBaseTalentRank(TalentFrame.talentGroup, tabIndex, talentId);
		
		-- Check if deranking would go below the spec map rank
		local newRank = currentRank - 1;
		if ( newRank < baseSpecMapRank ) then
			-- Cannot derank below spec map rank
			return;
		end
		
		-- Proceed with derank if allowed
		if ( SpecMap_TalentCacheCanDerank(TalentFrame.talentGroup, tabIndex, talentId, tier) and SpecMap_TalentCacheAdjustRank(TalentFrame.talentGroup, tabIndex, talentId, -1, maxRank, tier) ) then
			-- Refresh the talent frame to show updated ranks
			if ( type(PlayerTalentFrame_Refresh) == "function" ) then
				PlayerTalentFrame_Refresh();
			end
			-- Refresh tooltip if it's showing for this button
			if ( GameTooltip:IsOwned(self) ) then
				-- Get the OnEnter handler and call it to refresh the tooltip
				local onEnterScript = self:GetScript("OnEnter");
				if ( onEnterScript ) then
					onEnterScript(self);
				end
			end
		end
	end
end

function TalentFrame_ResetBranches(TalentFrame)
	local selectedTab = PanelTemplates_GetSelectedTab(TalentFrame);
	for i=1, MAX_NUM_TALENT_TIERS do
		for j=1, NUM_TALENT_COLUMNS do
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].id = nil;
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].up = 0;
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].down = 0;
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].left = 0;
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].right = 0;
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].rightArrow = 0;
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].leftArrow = 0;
			TalentFrame.TALENT_BRANCH_ARRAY[i][j].topArrow = 0;
		end
	end
	-- Clear frame map for current tab
	if ( selectedTab and TalentFrame.TALENT_FRAME_MAP and TalentFrame.TALENT_FRAME_MAP[selectedTab] ) then
		TalentFrame.TALENT_FRAME_MAP[selectedTab] = nil;
	end
end

local sortedTabPointsSpentBuf = { };
function TalentFrame_UpdateSpecInfoCache(cache, inspect, pet, talentGroup)
	-- initialize some cache info
	cache.primaryTabIndex = 0;
	cache.totalPointsSpent = 0;

	local preview = GetCVarBool("previewTalents");

	local highPointsSpent = 0;
	local highPointsSpentIndex;
	local lowPointsSpent = huge;
	local lowPointsSpentIndex;

	local numTabs = GetNumTalentTabs(inspect, pet);
	cache.numTabs = numTabs;
	for i = 1, MAX_TALENT_TABS do
		cache[i] = cache[i] or { };
		if ( i <= numTabs ) then
			local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(i, inspect, pet, talentGroup);
			
			-- For player talents, use SpecMap cache if available to get accurate point counts
			-- This ensures the spec tab icon reflects the actual points spent
			if ( not inspect and not pet and type(SpecMap_TalentCacheSumTabPoints) == "function" ) then
				local cachePoints = SpecMap_TalentCacheSumTabPoints(talentGroup, i);
				if ( cachePoints ~= nil ) then
					pointsSpent = cachePoints;
					previewPointsSpent = 0; -- Preview points are handled separately in SpecMap cache
				else
					-- Fallback to applying cache points if sum function doesn't work
					if ( type(SpecMap_TalentCacheApplyTabPoints) == "function" ) then
						pointsSpent, previewPointsSpent = SpecMap_TalentCacheApplyTabPoints(talentGroup, i, pointsSpent, previewPointsSpent);
					end
				end
			end

			local displayPointsSpent = pointsSpent + previewPointsSpent;

			-- cache the info we care about
			cache[i].name = name;
			cache[i].pointsSpent = displayPointsSpent;
			cache[i].icon = icon;

			-- update total points
			cache.totalPointsSpent = cache.totalPointsSpent + displayPointsSpent;

			-- update the high and low points spent info
			-- Use >= instead of > to ensure we always have a primary tab when points are spent
			-- This ensures the spec tab icon updates based on the tab with the most points
			if ( displayPointsSpent >= highPointsSpent ) then
				highPointsSpent = displayPointsSpent;
				highPointsSpentIndex = i;
			end
			if ( displayPointsSpent < lowPointsSpent ) then
				lowPointsSpent = displayPointsSpent;
				lowPointsSpentIndex = i;
			end

			-- initialize the points spent buffer element
			sortedTabPointsSpentBuf[i] = 0;
			-- insert the points spent into our buffer in ascending order
			local insertIndex = i;
			for j = 1, i, 1 do
				local currPointsSpent = sortedTabPointsSpentBuf[j];
				if ( currPointsSpent > displayPointsSpent ) then
					insertIndex = j;
					break;
				end
			end
			for j = i, insertIndex + 1, -1 do
				sortedTabPointsSpentBuf[j] = sortedTabPointsSpentBuf[j - 1];
			end
			sortedTabPointsSpentBuf[insertIndex] = displayPointsSpent;
		else
			cache[i].name = nil;
		end
	end

	-- Always set primaryTabIndex to the tab with the most points if any points are spent
	-- This ensures the spec tab icon reflects the talent tree with the most investment
	-- If there's a tie, use the last tab encountered with the highest points
	if ( highPointsSpentIndex and highPointsSpent > 0 ) then
		cache.primaryTabIndex = highPointsSpentIndex;
	else
		-- No points spent or no valid tab found, ensure primaryTabIndex is 0
		cache.primaryTabIndex = 0;
	end
	
	-- Debug: Ensure we have valid icon data for the primary tab
	if ( cache.primaryTabIndex > 0 and cache[cache.primaryTabIndex] ) then
		-- Verify the icon exists, if not try to get it from GetTalentTabInfo
		if ( not cache[cache.primaryTabIndex].icon or cache[cache.primaryTabIndex].icon == "" ) then
			local name, icon = GetTalentTabInfo(cache.primaryTabIndex, inspect, pet, talentGroup);
			if ( icon and icon ~= "" ) then
				cache[cache.primaryTabIndex].icon = icon;
			end
		end
	end
end

-- Decode Spec Info Message
-- Decodes messages sent from the server in the format:
-- OP|freeTalents~specCount~activeSpec~resetCost~spec0^spec1^...
-- Where resetCost is the total copper cost of the next talent reset
-- Where each spec is: talentCount:talentId,tabId,rank;talentId,tabId,rank;...|glyph0,glyph1,glyph2,...
function DecodeSpecInfo(message)
    if not message or message == "" then
        return nil
    end
    
    local result = {
        op = nil,
        freeTalents = nil,
        specCount = nil,
        activeSpec = nil,
        resetCost = nil,
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
    -- New format includes resetCost as 4th part
    if #playerDataParts < 3 then
        return nil -- Invalid format
    end
    
    -- Extract player-level data
    result.freeTalents = tonumber(playerDataParts[1])
    result.specCount = tonumber(playerDataParts[2])
    result.activeSpec = tonumber(playerDataParts[3]) + 1 -- 0-indexed to 1-indexed
    
    -- Extract reset cost (4th part, if exists)
    if #playerDataParts >= 4 then
        result.resetCost = tonumber(playerDataParts[4])
    end

    -- The 5th part (if exists) contains all spec data
    -- Format: spec0^spec1^spec2^...
    local specData = playerDataParts[5]
    
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

-- Initialize SpecMap if not already initialized
if ( type(SpecMap) ~= "table" ) then
    SpecMap = {}
end

-- Helper functions to query server (defined here so they're available when file loads)
function PushQueryServer(Msg)
    SendAddonMessage(MESSAGE_PREFIX_GET, Msg, "WHISPER", UnitName("player"))
end

function RequestServerAction(Msg)
    SendAddonMessage(MESSAGE_PREFIX_POST, Msg, "WHISPER", UnitName("player"))
end

-- Listen for Spec Info message
local specInfoListenerFrame = CreateFrame("Frame")
specInfoListenerFrame:RegisterEvent("CHAT_MSG_ADDON")
specInfoListenerFrame:SetScript("OnEvent", function(self, event, ...)
    
    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, msgType, sender = ...
        if prefix ~= MESSAGE_PREFIX_SERVER or msgType ~= "WHISPER" then
            return
        end

        local decoded = DecodeSpecInfo(msg)
        if ( decoded ) then
            -- Update SpecMap with all decoded data (including resetCost, activeSpec, specs, etc.)
            SpecMap = decoded
            -- Update activeSpecNumber immediately when spec info changes
            if ( decoded.activeSpec and type(decoded.activeSpec) == "number" ) then
                -- decoded.activeSpec is already 1-based (converted in DecodeSpecInfo)
                _G["activeSpecNumber"] = decoded.activeSpec
            end
            -- resetCost is automatically updated via SpecMap = decoded assignment above
            -- Call update handler if it exists (defined in Blizzard_TalentUI.lua)
            if ( type(PlayerTalentFrame_HandleSpecMapUpdate) == "function" ) then
                PlayerTalentFrame_HandleSpecMapUpdate()
            end
        end
    end
end)

-- If player is already logged in when this file loads, query immediately
-- Otherwise, wait for PLAYER_LOGIN event
if ( UnitName("player") and UnitName("player") ~= "" ) then
    PushQueryServer("7")
end