----------------------------------------------------------------------------------------------------------
-- 31682 - 'Client groups not accessible in MP' bug
--
-- Problem: When I have a player unit and I access its group, the group is here BUT IsExist() returns false 
--          Then getID, getCategory, getName and such will not work
--
-- Workaround: At initialisation, I parse the mission description data to build a list of ALL playable units in the map (MIST-style)
--             In this list, I store the corresponding group information I would like to access later, mostly groupID
--             At runtime, if the runtime group info are messed-up, I used the data in my list in place
--
-- Here is some sample code from my masterscript and I hope it will help people that were blocked like me
-- When the bug is fixed, the workaround can stay as a normal code path is still there
--
-- Limitation: I still have to find out how to use the dictionary to properly extract names for my table (search for TODO|Dictionary)
--			   I am still not sure how to handle 2 players in one plane
--             I've never tried to track Combined-Arms players as my server doesn't have slots for them
---------------------------------------------------------------------------------------------------------

			
----------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Declaring a table
---------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

local g_PlayableUnits = { }	-- All potential units player can enter, indexed by UnitID, can be big for a server map (around 220 for me)

----------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Building the table and save the information you want
-- Should be done at mission startup, once
---------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------

OpenConflict.BuildPlayableUnitList = function()

	g_PlayableUnits = {}
	
	-- Parsing code borrowed from MIST v3.3	
	-- We parse the mission declaration instead of runtime group information so the bug doesn't affect those data
	for coa_name, coa_data in pairs(env.mission.coalition) do
		if (coa_name == 'red' or coa_name == 'blue') and type(coa_data) == 'table' then
			if coa_data.country then --there is a country table
				for cntry_id, cntry_data in pairs(coa_data.country) do					
					local countryName = string.lower(cntry_data.name)
					local countryID = cntry_data.id
					if type(cntry_data) == 'table' then  --just making sure					
						for obj_type_name, obj_type_data in pairs(cntry_data) do	
							if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" or obj_type_name == "static" then --should be an unnecessary check 								
								local category = obj_type_name								
								if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then  --there's a group!								
									for group_num, group_data in pairs(obj_type_data.group) do										
										if group_data and group_data.units and type(group_data.units) == 'table' then  --making sure again- this is a valid group
											for unit_num, unit_data in pairs(group_data.units) do
												local unitSkill = unit_data.skill
												if unitSkill and ( (unitSkill == "Client" or unitSkill == "Player")) then
													local unitID = tostring(unit_data.unitId) -- unitID will be our index and a string to match the type of runtime Unit.getID(theUnit)
													local groupID = tostring(group_data.groupId)
													if g_PlayableUnits[unitID] ~= nil then
														-- Shouldn't happen if the UnitID is truly unique
														OpenConflict.LogWarningMessage('Playable Unit ID ALREADY in table: ' ..  'UnitID: ' .. unitID)
													else
														-- YAY a new one
														local newPlayableUnit = {}														
														
														-- Save the information we need
														
														newPlayableUnit.unitID = unitID		-- Should not be needed it as it is our index
														newPlayableUnit.groupID = groupID	-- Needed for direct communication
														
														-- Transform the string into the enum 
														-- I use a lot GroupCategory for other features 
														-- But maybe you don't need it
														newPlayableUnit.groupCategoryID = Group.Category.GROUND 
														if category == "helicopter" then 
															newPlayableUnit.groupCategoryID = Group.Category.HELICOPTER
														elseif category == "ship" then
															newPlayableUnit.groupCategoryID = Group.Category.SHIP
														elseif category == "plane" then 
															newPlayableUnit.groupCategoryID = Group.Category.AIRPLANE
														elseif category == "vehicle" then
															newPlayableUnit.groupCategoryID = Group.Category.GROUND
														end	
														
														-- Names for debug log
														-- TODO|Dictionary: Those strings are actual dictionary entries (Ex: DictKey_UnitName_393). Not sure how to resolve them yet!
														newPlayableUnit.unitName = unit_data.name
														newPlayableUnit.groupName = group_data.name
														
														-- Store the goods
														g_PlayableUnits[unitID] = newPlayableUnit
														OpenConflict.LogInfoMessage('Playable Unit Found: UnitID: ' .. unitID .. ' (' .. type(unitID) .. ') '.. 'UnitName: ' .. newPlayableUnit.unitName .. ' GroupID: ' .. newPlayableUnit.groupID .. ' GroupName: ' .. newPlayableUnit.groupName)
														-- OpenConflict:Info@16.70: Playable Unit Found: UnitID: 125 (string) UnitName: DictKey_UnitName_393 GroupID: 125 GroupName: DictKey_GroupName_392
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end					
			end
		end
	end	
end

----------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Helper to access table and get the information I use if my other code 
---------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
OpenConflict.RetrieveGroupInfoForUnit = function(unitID,groupObject)
	local groupID		= InvalidID
	local groupName		= InvalidName
	local groupCategory = Group.Category.AIRPLANE
	
	if not unitID then 
		OpenConflict.LogWarningMessage('RetrieveGroupInfoForUnit: Unable to find info for NIL unitID')
	elseif groupObject and groupObject:isExist() then
		-- > This is the NORMAL path < -- 
		groupID				= Group.getID(groupObject)
		groupName			= Group.getName(groupObject)
		groupCategory		= Group.getCategory(groupObject)
	elseif g_PlayableUnits[unitID] ~= nil then
		-- > This is the WORKAROUND path < --
		groupID				= g_PlayableUnits[unitID].groupID
		groupName			= g_PlayableUnits[unitID].groupName
		groupCategory		= g_PlayableUnits[unitID].groupCategoryID
	else
		OpenConflict.LogWarningMessage('RetrieveGroupInfoForUnit: Unable to find info for unitID: ' .. unitID .. ' (' .. type(unitID) .. ') ')
	end
	
	-- groupID for direct communication
	-- trigger.action.outTextForGroup
	-- trigger.action.outSoundForGroup
	-- missionCommands.addCommandForGroup
		
	-- groupCategory to know what kind of vehicle the player is in (unitCategory could be used instead)
	
	-- groupName for debug log
	
	return groupID, groupName, groupCategory
end		

----------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- An example on how I use the table
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
OpenConflict.UpdatePlayerTrackingForCoalition(coalitionID)

	local allPlayerUnits = coalition.getPlayers(coalitionID)
	OpenConflict.LogDebugMessage('UpdatePlayerTrackingForCoalition: ' .. #allPlayerUnits .. ' players')
	
	for k,playerUnit in pairs(allPlayerUnits) do		
		if playerUnit and playerUnit:isExist() then	
			local playerUnitID = Unit.getID(playerUnit)
			local playerGroupObject = Unit.getGroup(playerUnit) -- A group will be returned but the bug make it so playerGroupObject:isExist() will return false
			if playerGroupObject then			
				local playerGroupID, playerGroupName, playerGroupCategory = OpenConflict.RetrieveGroupInfoForUnit(playerUnitID,playerGroupObject)
				
				-- Then, I use:
				
				-- playerUnitID and playerGroupID to track players
				
				-- playerGroupID for direct communication using 
				-- 		trigger.action.outTextForGroup
				-- 		trigger.action.outSoundForGroup
				-- 		missionCommands.addCommandForGroup
				
				-- playerGroupName for debug log
				
				-- groupCategory to know what kind of vehicle the player is in
				-- I have other features using groupCategory but maybe you don't care this data
				-- Unit.getCategory(playerUnit) could be used instead in some cases
			end
		end
	end
end	
	
	
----------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Everyone have their own special Log / Files Functions. Here are mines:
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------

OpenConflict.LogDebugMessage = function(message)
	local finalMessage = string.format("OpenConflict:Dbug@%0.2f: %s",timer.getTime(),message)
	if g_LogFile then
		g_LogFile:write(finalMessage .. '\n')
	end
	
	-- In dev mode, gimme all those debug message in the log
	-- In normal mode, we keep the debug message for the file (if it exists).
	if not g_LogFile or g_DevelopmentMode then
		env.info(finalMessage)
	end
end

---------------------------------------------------------------------------------------------------------

OpenConflict.LogInfoMessage = function(message)
	local finalMessage = string.format("OpenConflict:Info@%0.2f: %s",timer.getTime(),message)
	if g_LogFile then
		g_LogFile:write(finalMessage .. '\n')
	end
	env.info(finalMessage)
end

---------------------------------------------------------------------------------------------------------

OpenConflict.LogWarningMessage = function(message)
	local finalMessage = string.format("OpenConflict:Wrng@%0.2f: %s",timer.getTime(),message)
	if g_LogFile then
		g_LogFile:write(finalMessage .. '\n')
	end
	env.info(finalMessage)
end
	
---------------------------------------------------------------------------------------------------------

OpenConflict.LogErrorMessage = function(message)
	local finalMessage = string.format("OpenConflict:Error@%0.2f: %s",timer.getTime(),message)
	if g_LogFile then
		g_LogFile:write(finalMessage .. '\n')
	end
	env.info(finalMessage)
end	