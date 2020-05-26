-- Find and automatically connect to the AE network when placed beside an ME cable.
AEUplink = peripheral.find("aemultipart")

-- If an AE system is not found, exit with an error.
if not AEUplink then
	error("Computer must be placed next to a part of the AE system.")
end

-- IMPORTANT TABLES --

-- Initialize table that'll hold the items we want to store.
monitorItems = {}

-- A table for the item that is currently being targeted. This lets 
-- allows us to control when a redstone channel is removed from the
-- side of the computer.
activeItem = {}

-- Assign some dummy values to avoid an "attempt to index ? (a nil value)" error.
table.insert(activeItem, 1, { ID="foo",
							  DMG=1
							})
----------------------


-- Load the items that we want to monitor.
function loadConfiguration()
	-- Check if a disk drive is present.
	if not fs.isDir("disk/") then
		configurationName = "resources.config"
	else
		configurationName = "disk/resources.config"
	end
	
	-- If configuration file does not exist, then create it.
	if not fs.exists(configurationName) then
		print('[INFO] Creating configuration file: ',configurationName)
		configurationIO = io.open(configurationName,"w")
		io.output(configurationIO)
		
		writeConfiguration = [[
# ID,DMG,lowThreshhold,COLOR,SIDE,PULSE
#
# ID -            The ID of the item. 
#                 This is a string.
#
# DMG -           The damage value of the item.
#                 This is an int.
#
# lowThreshhold - The minimal amount the AE network will
#                 try to keep within the system.
#                 This is an int.
#
# COLOR -         The channel color the redstone output
#                 will be outputted on. This is used by
#                 bundled cables to transmit multiple
#                 redstone signals on the same wire.
#                 This is an int.
#
# SIDE -          The side of the computer that will emit
#                 a redstone signal on COLOR. 
#                 This is a string.
#
# PULSE -         Controls whether or not the redstone
#                 signal will pulse in 5 second intervals.
#                 This is to mitigate a bug in AE where
#                 a redstone signal appears to "halt"
#                 the system.
#                 This is a boolean.
# 
# In-order for the changes in this configuration file to
# take effect, the system will need to be rebooted.


]]
		io.write(writeConfiguration)
		
		io.close()
		
		writeConfiguration = nil
		
		print('[INFO] Generated blank configuration file. Add entries to this file and reboot to continue.')
		error()
	end
	
	print('[INFO] Loading configuration from file: ', configurationName)
	
	configurationIO = io.open(configurationName,"r")
	io.input(configurationIO)
	
	-- Loop through all lines of the configuration file, and append item entries to the monitorItems table.
	for line in configurationIO:lines() do
		for id, dmg, lowThreshhold, color, side, pulse in string.gmatch(line,"([a-zA-Z0-9:_.]*),([0-9]*),([0-9]*),([0-9]*),([a-z]*),([a-z]*)") do
			-- Convert dmg, lowThreshhold, and color into integers.
			dmg = tonumber(dmg)
			lowThreshhold = tonumber(lowThreshhold)
			color = tonumber(color)
			
			-- Check to make sure the side provided is one of six sides.
			if side == "front" or side == "back" or side == "left" or side == "right" or side == "top" or side == "bottom" then else print('[ERROR] Invalid side \"'..side..'\"') error() end
			
			-- Make sure that the value of pulse is either true or false.
			if pulse == "true" or pulse == "false" then else print('[ERROR] Invalid string: \"'..pulse..'\" for PULSE parameter in configuration.') error() end
			
			-- Append id, dmg, lowThreshhold, color, side, and pulse to the monitorItems table as key-value pairs.
			table.insert(monitorItems, { ID=id,
										 DMG=dmg,
										 LOW=lowThreshhold,
										 COLOR=color,
										 SIDE=side,
										 PULSE=pulse
										})
		end
	end
	
	io.close()
	
	-- If the monitorItems table is empty after reading the configuration file, 
	-- exit with an error stating that the table is empty.
	if #monitorItems == 0 then
		error("No item(s) were read from the configuration file. This is because the file is either empty, or all entries are invalid.")
	end
	
	print('[INFO] Configuration complete with '..#monitorItems..' entries loaded.')
end
loadConfiguration()

print('Executing...')
-- Main program loop
while true do
	for i=1,#monitorItems do
		-- Attempt to set the itemInAESystem variable. If it fails the status will be false, and the actual exception thrown will be returned.
		-- If the below code does not throw an exception, the itemInAESystem variable is set normally.
		status, exception = xpcall(function()
						itemInAESystem = AEUplink.getItemDetail({id=monitorItems[i].ID,dmg=monitorItems[i].DMG}).all()
						end, function(err)
						-- Remove the program name and line number from the exception.
						return string.match(err,".*: (.*)")
						end)
		
		-- Now that we know the status and exception of the above, make all 
		-- other exceptions that aren't a "attempt to index ? (a nil value)"
		-- exit with an error. Otherwise attempt to create a stub item
		-- specifically for the item which is missing. Because this can also 
		-- throw errors, we will repeat pretty much what we did above to make 
		-- sure that the item really does exist within the game. Again, if 
		-- any errors are thrown when creating the stub item, these errors are 
		-- considered fatal, as we can't do anything past this point without 
		-- valid data.
		if not status then
			if exception == "attempt to index ? (a nil value)" then
				status, exception = xpcall(function()
								itemInAESystem = AEUplink.expandStack({id=monitorItems[i].ID,qty=0,dmg=monitorItems[i].DMG})
								end, function(err)
								return string.match(err,".*: (.*)")
								end)
				if not status then
					error(exception)
				end
			elseif exception ~= "attempt to index ? (a nil value)" then
				-- Immediately exit with an error if such error is not
				-- an exception for a nil value.
				error(exception)
			end
		end
		
		-- Compare the quantity of items from the AE system and the low lowThreshhold value the user provided.
		-- Emit redstone signal on specified channel color if the quantity of items in the AE system is below
		-- the threshold value.
		
		-- Emit redstone signal to SIDE when item quantity is below threshold. Because of a bug in the 
		-- 1.7.10 version of AE, which causes the system to essentially halt when supplying a AE cable
		-- redstone power, so we will sleep a few seconds, then turn the redstone signal off. This will
		-- effectively create a redstone pulse, which should be long enough for the system to perform
		-- the desired operation.
		if monitorItems[i].PULSE == "true" then
			if itemInAESystem.qty < monitorItems[i].LOW then
				redstone.setBundledOutput(monitorItems[i].SIDE,colors.combine(redstone.getBundledOutput(monitorItems[i].SIDE),monitorItems[i].COLOR))
				sleep(5)
				redstone.setBundledOutput(monitorItems[i].SIDE,colors.subtract(redstone.getBundledOutput(monitorItems[i].SIDE),monitorItems[i].COLOR))
			end
		
		-- If we weren't directed to pulse, then create start adding items to their respective redstone 
		-- channels. However, no more than one item can ever be assigned to one channel at a time.
		elseif monitorItems[i].PULSE == "false" then
			-- If the color from monitorItems[i].COLOR has NOT been assigned to monitorItems[i].SIDE,
			-- then assign the color to the side. This will create a queue for items that are configured
			-- for the same redstone channel.
			if not redstone.testBundledInput(monitorItems[i].SIDE,monitorItems[i].COLOR) then
				if itemInAESystem.qty < monitorItems[i].LOW then
					print("Added item: "..monitorItems[i].ID) -- Temp
					redstone.setBundledOutput(monitorItems[i].SIDE,colors.combine(redstone.getBundledOutput(monitorItems[i].SIDE),monitorItems[i].COLOR))
					
					-- Populate the activeItem table with the item currently being targeted.
					table.insert(activeItem, 1, { ID=monitorItems[i].ID,
												  DMG=monitorItems[i].DMG
												})
				end
			
			-- If the channel color has been assigned to the side, see if the item quantities are
			-- above the threshold. If they are, then remove the channel.
			elseif redstone.testBundledInput(monitorItems[i].SIDE,monitorItems[i].COLOR) and activeItem[1].ID == monitorItems[i].ID and activeItem[1].DMG == monitorItems[i].DMG then
				-- If above threshold, remove the channel from the side.
				if itemInAESystem.qty > monitorItems[i].LOW then
					print("Removing item: "..monitorItems[i].ID) -- Temp
					redstone.setBundledOutput(monitorItems[i].SIDE,colors.subtract(redstone.getBundledOutput(monitorItems[i].SIDE),monitorItems[i].COLOR))
				end
			end
		end
	end
	sleep(5)
end
