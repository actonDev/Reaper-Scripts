package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

require 'deps.template'
require 'deps.colors'
require 'deps.class'
require 'deps.GuiBuffer'
require 'deps.drawing'

debug_mode = 0

label = "ActonDev: Fx Routing Matrix"

local gui = {}
local colors = {}

function scriptColors()
	gfx.clear = themeColor("col_main_bg2")
	colors.back = {themeColor("col_main_bg2", true)}
	colors.text = {themeColor("col_main_text2", true)}

	colors.left = {themeColor("col_mi_bg2", true)}
	-- colors.right = {themeColor("region", true)}

	local scale = 1.2
	colors.right = {colorAdjust(colors.left[1], colors.left[2], colors.left[3], 0.2)}
	colors.odd = {colorAdjust(colors.text[1], colors.text[2], colors.text[3], 0)}

	local adjust = 0.05
	colors.odd = {colorAdjust(colors.back[1], colors.back[2], colors.back[3], adjust)}
	colors.even = {colorAdjust(colors.back[1], colors.back[2], colors.back[3], -adjust)}

	colors.highlightRow = {colorAdjust(colors.back[1], colors.back[2], colors.back[3], 3*adjust)}

	colors.frameBorder = {themeColor("col_main_3dsh",true)}

	colors.labelBack = {themeColor("col_main_text2", true)}
	colors.labelBack = colors.text
	colors.labelText = {themeColor("col_main_bg2", true)}
	colors.labelText = colors.back
end

function take_title(target)

end


function FX_GetChannelCount(target, context)
	-- fdebug(context)
	if target == nil then return 0 end
	if context == "track" then
		return math.min( reaper.GetMediaTrackInfo_Value(target, "I_NCHAN"), 32 )
	else
		local item = reaper.GetMediaItemTake_Item(target)
		local takeIdx = reaper.GetMediaItemInfo_Value(item, "I_CURTAKE")
		local _,chunk = reaper.GetItemStateChunk(item, "", false)
		local takes = reaper.GetMediaItemNumTakes(item)
		local channels = 2
		if false or takes == 1 then
			-- local pattern = 
			channels = chunk:match("TAKEFX_NCH (%d+)") or 2
			-- fdebug("FOUND " .. channels)
		else
			-- have to cut out the part of the chunk regarding this take
			local pattern = ""
			for i=0,takeIdx-1 do
				pattern = "\nNAME .+" .. pattern
			end
			pattern = pattern .. "\n+NAME (.+)"
			for i=takeIdx+1,takes-1 do
				pattern = pattern .. "\n+NAME .+"
			end
			-- fdebug(pattern:gsub("\n","\\n"))
			local chunkPart = chunk:match(pattern)
			channels = chunkPart:match("TAKEFX_NCH (%d+)") or 2
			-- fdebug(">>>>>>>>>>>>>")
			-- fdebug(chunkPart)
			-- fdebug("FOUND " .. channels)
			-- fdebug("<<<<<<<<<<<<<<")
		end


		local pattern = "NAME .+"
		for i=1,takeIdx do

		end
		-- fdebug(takeIdx)
		return channels
	end
end

function FX_TargetName(target, context)
	if context == "track" then
		local _, track_name = reaper.GetSetMediaTrackInfo_String(target, "P_NAME", "", false)
		return track_name
	else
		return "Take"
	end
end

function targetLabel(target, context)
	local label = ""
	if context == "track" then
		label = "Track " .. math.floor(reaper.GetMediaTrackInfo_Value(target, "IP_TRACKNUMBER"))
		local _, track_name = reaper.GetSetMediaTrackInfo_String(target, "P_NAME", "", false)
		if track_name:len()>0 then
			label = label .. "  "..track_name..""
		end
		return label
	else
		local takeName = reaper.GetTakeName(target)
		local item = reaper.GetMediaItemTake_Item(target)
		local takeIdx = math.floor(reaper.GetMediaItemInfo_Value(item, "I_CURTAKE"))
		local takes = reaper.GetMediaItemNumTakes(item)

		label = "Take " .. takeIdx+1 .. "/" .. takes
		label = label .. "  "..takeName .. ""
	end
	return label
end
-- if targetName:len()>0 then targetName = "\""..targetName.."\"" end
-- gfx.printf("Track " .. math.floor(targetId) .. "  " .. targetName)

function FX_TargetId(target, context)
	if context == "track" then
		return reaper.GetMediaTrackInfo_Value(target, "IP_TRACKNUMBER")
	else
		return 0
	end
end

context = "track"
function setFxContext(what)
	context = what
	if what == "track" then
		FX_GetPinMappings = reaper.TrackFX_GetPinMappings
		FX_SetPinMappings = reaper.TrackFX_SetPinMappings
		-- TakeFX_GetFXName
		FX_GetFXName = reaper.TrackFX_GetFXName
		FX_GetIOSize = reaper.TrackFX_GetIOSize
		FX_GetEnabled = reaper.TrackFX_GetEnabled
		FX_SetEnabled = reaper.TrackFX_SetEnabled
		FX_SetOpen = reaper.TrackFX_SetOpen
		FX_GetCount = reaper.TrackFX_GetCount
		FX_Show = reaper.TrackFX_Show

		FX_Remove =
		function(target,fx)
			reaper.SNM_MoveOrRemoveTrackFX(target, fx, 0)
		end
	else
		FX_GetPinMappings = reaper.TakeFX_GetPinMappings
		FX_SetPinMappings = reaper.TakeFX_SetPinMappings
		-- TakeFX_GetFXName
		FX_GetFXName = reaper.TakeFX_GetFXName
		FX_GetIOSize = reaper.TakeFX_GetIOSize
		FX_GetEnabled = reaper.TakeFX_GetEnabled
		FX_SetEnabled = reaper.TakeFX_SetEnabled
		FX_SetOpen = reaper.TakeFX_SetOpen
		FX_GetCount = reaper.TakeFX_GetCount
		FX_Show = reaper.TakeFX_Show
		FX_Remove =
		function(target, fx)
			-- well...
		end
	end
end


function init()
	----------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------
	---INIT---------------------------------------------------------------------------------------------
	Z = 18 --used as cell w,h(and for change zoom level etc)
	R = 1  --used for rewind FXs

	scrollX = 0
	scrollStep = 80

	alphaBypass = 0.7

	scriptColors()

	gui.font = "Calibri"

	-- 200 height handels 6 channels, nice optically
	gfx.init(label, 800,300 )

	
	gfx.setfont(1,gui.font, Z)
	last_mouse_cap=0
	mouse_dx, mouse_dy =0,0

	reaperCMD("_BR_MOVE_WINDOW_TO_MOUSE_H_M_V_B")
end



----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
function pointIN(x,y,w,h)
	return mouse_ox >= x and mouse_ox <= x + w and mouse_oy >= y and mouse_oy <= y + h and
	gfx.mouse_x >= x and gfx.mouse_x <= x + w and gfx.mouse_y  >= y and gfx.mouse_y <= y + h
end

function mouseOver(x,y,x2,y2, relative)
	relative = relative or true
	-- relative means x2, y2 mean width, height
	-- if relative == false, they are coordinates
	if relative then
		return gfx.mouse_x >= x and gfx.mouse_x <= x + x2 and gfx.mouse_y  >= y and gfx.mouse_y <= y + y2
	else
		return gfx.mouse_x >= x and gfx.mouse_x <= x2 and gfx.mouse_y  >= y and gfx.mouse_y <= y2
	end
end
-----
function mouseClick()
	return gfx.mouse_cap&1==0 and last_mouse_cap&1==1
end
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
---draw current pin---------------------------------------------------------------------------------
function draw_pin(target,fx,isOut,pin,chans, x,y,w,h, alphaIn)
	local Low32,Hi32 = FX_GetPinMappings(target, fx, isOut, pin)--Get current pin
	local bit,val
	local Click = mouseClick()
	gfx.a=1
	local color1 = colors.text[1]
	local color2 = colors.text[2]
	local color3 = colors.text[3]
	gfx.set(color1,color2,color3)
	if (pin+1)%2==0 then
		-- gfx.a=1
		-- local color = colorAdjust(color1,color2,color3)
		gfx.set(table.unpack(colors.right))
	else
		gfx.set(table.unpack(colors.left))
	end
	--set pin color(odd parity) 
	--------------------------------------
	--draw(and change val if Clicked)-------
	for i = 1, chans do
		bit = 2^(i-1)       --cuurent bit
		val = (Low32&bit)>0 --current bit(aka channel value as booleen)
		if Click and pointIN(x+select(1,fxBuffer:mouseOffset()),y+select(2,fxBuffer:mouseOffset()),w,h) then
			if val then
				Low32 = Low32 - bit
			else
				Low32 = Low32 + bit
			end 
			FX_SetPinMappings(target, fx, isOut , pin, Low32, Hi32)--Set pin 
		end

		gfx.a = alphaIn
		-- border
		gfx.rect(x,y,w-2,h-2, 0)
		-- fill
		if val then gfx.rect(x+1,y+1,w-4,h-4, 1) end
		y = y + h --next y
	end 
	--------------------------------------
	return x,y
end

function calcWindowWidth(track)

end

---draw_FX_labels-----------------------------------------
function draw_FX_labels(target, fx, x, y, w, h)
	local _, fx_name = FX_GetFXName(target, fx, "");
	fx_name = " ".. string.gsub(fx_name, "[VSTiJS]+: ", "")
	local _, in_Pins,out_Pins = FX_GetIOSize(target,fx)
	if out_Pins==-1 and in_Pins~=-1 then out_Pins=in_Pins end --in some JS outs ret "-1" 

	w,h = w*(in_Pins+out_Pins+1.2)-2,h-1 --correct values for label position
	local s_w, s_h = gfx.measurestr(fx_name)
	local maxChars = math.floor(w/gfx.measurestr("E"))
	if fx_name:len() > maxChars then
		fx_name = fx_name:sub(1, maxChars-1)..".."
	end
	local fxEnabled = FX_GetEnabled(target,fx)
	-----------------------
	gfx.x, gfx.y = x, y+(h-gfx.texth)/2
	gfx.set(colors.labelBack[1], colors.labelBack[2], colors.labelBack[3])
	gfx.rect(x,y,w,h,fxEnabled)
	if fxEnabled then
		gfx.set(colors.labelText[1], colors.labelText[2], colors.labelText[3])
	end
	gfx.printf(fx_name)
	
	-- Fx label click
	if mouseClick() and pointIN(x+select(1,fxBuffer:mouseOffset()),y+select(2,fxBuffer:mouseOffset()),w,h) then
		if Shift then
			-- Toggle Bypass
			FX_SetEnabled(target, fx, not fxEnabled)
		elseif Alt then
			-- Remove Fx
			FX_Remove(target, fx)
		else
			-- normal click, open Fx window
			-- close floating fx for selected track
			-- gfx.mouse_y = gfx.mouse_y-200
			-- reaperCMD("_S&M_WNCLS5")
			FX_Show(target, 0, 0)
			FX_Show(target,fx,1)
			
			-- FX_SetOpen(target, fx, 1 )--not bool for change state
			-- sleep(1)
			reaperCMD("_BR_MOVE_WINDOW_TO_MOUSE_H_M_V_T")
		end
	end
	return x, y
end
--------------------------------------------------------



---draw current FX--------------------------------------
function draw_FX_pins(target, fx, chans, x,y,w,h, alphaAll)
	local _, in_Pins,out_Pins = FX_GetIOSize(target,fx) 
	--for some JS-plug-ins---------------------------------
	if out_Pins==-1 and in_Pins~=-1 then out_Pins=in_Pins end --in some JS outs ret "-1" 

	local enabled, alphaFX
	if FX_GetEnabled(target,fx) then
		alphaFX = 1
	else
		alphaFX = alphaBypass
	end

	local alpha = math.min(alphaAll, alphaFX)

	---------------------------------
	--------------------------------
	--Draw FX pins,chans etc-- 
	---------------
	--input pins---
	local tempY, maxY = 0,0
	y=y+1.5*w
	local isOut=0
	-- local xStart = x
	for i=1,in_Pins do
		-- highlight_column(x,w-2,y,chans*w)
		_,tempY = draw_pin(target,fx,isOut, i-1,chans, x,y,w,h, alpha)
		
		x = x + w --next x
	end
	---------------
	x = x + 1.2*w --Gap between FX in-out pins
	---------------
	--output pins--
	local isOut=1 
	for i=1,out_Pins do
		-- highlight_column(x,w-2,y,chans*w)
		_,tempY = draw_pin(target,fx,isOut, i-1,chans, x,y,w,h, alpha)
		maxY = math.max(maxY, tempY)
		
		x = x + w --next x
	end   
	return x,maxY --return x value for next FX position
end

function highlight_column(xStart,w,yStart,h)
	if mouseOver(xStart+select(1,fxBuffer:mouseOffset()), yStart+select(2,fxBuffer:mouseOffset()), w, h) then
		gfx.set(table.unpack(colors.highlightRow))
		gfx.rect(xStart, yStart, w,h, 1)
	end
end

function draw_rows(chans, x, y, w, h)
	gfx.x, gfx.y = x, y
	local tempY=y+0.5*w
	-- gfx.a=0.15
	-- gfx.set(table.unpack(colors.odd))
	for i=1,chans,2 do
		gfx.set(table.unpack(colors.odd))
		-- if gfx.mouse_y  >= tempY and gfx.mouse_y <= tempY + h then
		if mouseOver(0,tempY,gfx.w,h-1) then
			-- highlight row
			gfx.set(table.unpack(colors.highlightRow))
		end
		gfx.rect(0,tempY-1,gfx.w,h-1, 1)
		tempY = tempY + 2*h
	end
	tempY=y+1.5*w
	
	for i=2,chans,2 do
		gfx.set(table.unpack(colors.even))
		-- if gfx.mouse_y  >= tempY and gfx.mouse_y <= tempY + h then
		if mouseOver(0,tempY,gfx.w,h-1) then
			-- highlight row
			gfx.set(table.unpack(colors.highlightRow))
		end
		gfx.rect(0,tempY-1,gfx.w,h-1, 1)
		tempY = tempY + 2*h
	end
end

--draw in-out +/- buttons-----------------------
function draw_target_chan_add_sub(target,chans, x,y,w,h)
	-- y=y+0.5*h
	gfx.set(table.unpack(colors.text))
	-- "-" --
	-- Remove channels
	gfx.rect(x,y,w-2,h-2, 0)
	local s_w, s_h = gfx.measurestr("-")
	gfx.x, gfx.y = x + (w-1.2*s_w)/2 , y + (h-1.2*s_h)/2 
	gfx.printf("-")
	-- y = y + h
	if mouseClick() and pointIN(x,y,w,h) then
		if context == "track" then
			reaper.SetMediaTrackInfo_Value(target, "I_NCHAN", math.max(chans-2,2)) 
		else
			-- item
		end
	end 

	-- "+" --
	-- Add channels
	y = y+h
	gfx.rect(x,y,w-2,h-2, 0);
	s_w, s_h = gfx.measurestr("+")
	gfx.x, gfx.y = x + (w-1.2*s_w)/2 , y + (h-1.2*s_h)/2 
	gfx.printf("+")
	
	if mouseClick() and pointIN(x,y,w,h) then
		if context == "track" then
			reaper.SetMediaTrackInfo_Value(target, "I_NCHAN", math.min(chans+2,32))
		else
			-- item
		end
	end 

	return x+w
end
------------------------------------------------
---draw track in/out----------------------------
function draw_track_in_out(type,track,chans, x,y,w,h)
	gfx.x, gfx.y = x, y-w
	gfx.set(table.unpack(colors.text))
	gfx.printf(type)
	y=y+0.5*w
	for i=1,chans do 
		if i%2==0 then
			gfx.set(colors.right[1], colors.right[2], colors.right[3])
		else 
			gfx.set(colors.left[1], colors.left[2], colors.left[3])
		end
		gfx.rect(x,y,w-2,h-2, 1)
		gfx.set(table.unpack(colors.back))
		if i < 10 then gfx.x =x+4 else gfx.x =x end
		-- drawString(i, "center", x,y,w,h)
		gfx.y =y-1
		gfx.printf(i)
		y = y + h
	end
	return x,y
end

function draw_FX_enabledToggle(track, enabled, x, y, w, h)
	local statusText
	gfx.rect(x,y,w-2,h-2, 0)
	if(enabled == 1) then
		statusText = " ON"
		gfx.rect(x+2,y+2,w-6,h-6, 1)
	else
		statusText = "OFF"
	end

	gfx.x = x + 1.2*w
	gfx.y=y
	gfx.printf(statusText)
	if mouseClick() and pointIN(x,y,w,h) then
		-- gfx.w = 300
		if enabled == 0 then enabled = 1 else enabled = 0 end
		reaper.SetMediaTrackInfo_Value(track, "I_FXEN", enabled)
	end
end

function draw_FX_list(target, x,y,w,h)
	local text = " FX "
	local s_w, s_h = gfx.measurestr(text)
	x = x
	y=y+2
	gfx.x = x
	gfx.y = y
	
	-- gfx.y = y-2*w
	gfx.set(table.unpack(colors.text))
	gfx.rect(x,y,s_w,s_h, 1)
	gfx.set(table.unpack(colors.back))
	gfx.printf(text)
	if mouseClick() and pointIN(x,y,s_w,s_h) then
		-- close floating fx for current track
		reaperCMD("_S&M_WNCLS5")
		-- show chain
		FX_Show(target, 0, 1)
		reaperCMD("_BR_MOVE_WINDOW_TO_MOUSE_H_M_V_T")
	end
end

function draw_FX_add(target, x,y, w, h)
	local text = " Add FX "
	local s_w, s_h = gfx.measurestr(text)
	x = x
	y=y+2
	gfx.x = x
	gfx.y = y
	
	-- gfx.y = y-2*w
	gfx.set(table.unpack(colors.text))
	gfx.rect(x,y,s_w,s_h, 1)
	gfx.set(table.unpack(colors.back))
	gfx.printf(text)
	if mouseClick() and pointIN(x,y,s_w,s_h) then
		-- open FX browser
		if context == "track" then
			reaperCMD(40271)
		else
			FX_Show(target,0,1)
		end
		-- reaper.TakeFX_AddByName(target, "eq", 1)
		reaperCMD("_BR_MOVE_WINDOW_TO_MOUSE_H_M_V_T")
	end
end
------------------------------------------------

function drawFrame(x,y,w,h)
	gfx.mode = 0
	gfx.set(table.unpack(colors.text))
	gfx.a = 0.05
	gfx.rect(x,y,w,h, 1)
	gfx.mode=0
	gfx.a=1
	gfx.set(table.unpack(colors.frameBorder))
	drawRectBorder(x,y,w,h,1)
end



fxBuffer = GuiBuffer(1)

function drawScrollbar(x,y,w,h)
	if( select(1,fxBuffer:outSize()) < select(1,fxBuffer:inSize()) ) then

		gfx.set(table.unpack(colors.text))
		gfx.a=0.5
		-- gfx.rect(x,y,w,h)
		drawRectBorder(x,y,w,h,1)
		-- gfx.set(table.unpack(colors.odd))
		local scrollRatio = math.min(1,select(1,fxBuffer:outSize())/select(1,fxBuffer:inSize()))
		-- fdebug("Scroll ration ".. scrollRatio)
		gfx.rect(x+scrollX*scrollRatio,y,w*scrollRatio,h)
		gfx.a=1
	end
end

---Main draw_loop function---------------------------
lastTarget = nil
function draw_loop(target)
	x=0
	y=0

	
	fxBuffer:clear()
	fxBuffer:setScroll(scrollX)
	local w,h = Z,Z --its only one chan(rectangle) w and h (but it used in all calculation)
	local x,y = w, 0.5*w  --its first pin of first FX    x and y (but it used in all calculation) 
	local tempY -- for storing where drawing ended in y, used in +,- buttons so they snap at the last channel
	local M_Wheel
	----
	gfx.set(colors.text[1], colors.text[2], colors.text[3])

	if lastTarget ~= target then scrollX = 0 end
	-- global lastTarget
	lastTarget = target
	-- local context = "track"

	if target then
		-- local trackId = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
		local targetId = FX_TargetId(target, context)
		-- local _, targetName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
		local targetName = FX_TargetName(target, context)
		
		local fx_count = FX_GetCount(target)
		local chans = FX_GetChannelCount(target, context)

		--------------------------------------------------------
		--------------------------------------------------------
		---Zoom------
		if false and Ctrl and not Shift then
			M_Wheel = gfx.mouse_wheel;gfx.mouse_wheel = 0
			if M_Wheel>0 then
				Z = math.min(Z+1, 30)
			elseif M_Wheel<0 then
				Z = math.max(Z-1, 8)
			end
			gfx.setfont(1,gui.font, Z)
		end

		if not Shift and not Ctrl then
			-- scroll horizontally
			M_Wheel = gfx.mouse_wheel;gfx.mouse_wheel = 0
			if M_Wheel<0 then
				scrollX = scrollX + scrollStep
			elseif M_Wheel>0 then
				scrollX = math.max(scrollX-scrollStep, 0)
			end
		end
		--------------------------------------
		--draw track info(name,fx count etc)--
		gfx.x, gfx.y = w, h

		local alpha = 1

		-- takes do not have fx bypass (just per fx enable/disable)
		local fxEnabled = 1
		if context == "track" then
			fxEnabled = reaper.GetMediaTrackInfo_Value(target, "I_FXEN")
			if fxEnabled == 0 then
				alpha = 0.7
			end
		end

		if context == "track" then
			draw_FX_enabledToggle(target,fxEnabled, 0.5*w,y,w,h)
		end

		gfx.x, gfx.y = 4*w, y
		
		gfx.printf(targetLabel(target, context))
		gfx.x = gfx.x+w
		-- |  FXs: "..fx_count .. "   |    "
		draw_FX_list(target, gfx.x, y-2, w, h)
		gfx.set(table.unpack(colors.text))
		gfx.x = gfx.x+w/2
		gfx.printf(fx_count)
		-- gfx.x = gfx.x+w/2
		if context == "track" then
			draw_FX_add(target, gfx.w-100, y-2, w, h)
		end
		y = gfx.y+3*h

		-- gfx.printf("Add")
		--------------------------------------
		--draw track in,chan_add_sub----------
		
		draw_rows(chans,x,y,w,h)
		gfx.x, gfx.y = x, h
		
		x, tempY = draw_track_in_out("IN", target,chans, x+w,y,w,h)
		if context == "track" then
			draw_target_chan_add_sub(target,chans, x-1.5*w,tempY-h,w,h)
		end
		x=x+1.5*w
		
		-- drawing on FX buffer (to make it scrollable)
		gfx.dest = 1
		local fx_x,fx_y = 0,0
		-- local tempY = 0
		for i=1, fx_count do --R = 1-st drawing FX(used for rewind FXs)
			fx_x = draw_FX_labels(target, i-1, fx_x, fx_y, w, h, alpha)
			fx_x, tempY = draw_FX_pins(target, i-1,chans, fx_x, 0, w, h,alpha) -- offset for next FX
			fx_x = fx_x + w
		end
		-- drawing back on on-screen buffer
		gfx.dest = -1;

		-- setting actual drawn size (to calculate maxScroll)
		-- 		adding some padding to make it work with scrollStep size
		fxBuffer:setInSize(math.floor(fx_x-w), tempY)
		draw_track_in_out("OUT",target,chans, gfx.w-2*w,y,w,h)		
	else
		-- track nill
		gfx.x, gfx.y = 4*w, h; gfx.printf("No tracks or takes selected!") 
	end
	-- gfx.update()

	gfx.x=0;gfx.y=0
	gfx.mode = 0

	fx_start_x, fx_start_y = 4*w, 2.5*w

	fxBuffer:setOutStart(fx_start_x, fx_start_y)

	fx_end_x, fx_end_y = gfx.w -3*w, gfx.h
	fxBuffer:setOutEnd(fx_end_x, fx_end_y)
	scrollX = math.min(scrollX, fxBuffer:maxScrollX(scrollStep))
	-- fxBuffer.setOutSize(fx_start_x)
	gfx.x = fx_start_x
	gfx.y = fx_start_y
	drawFrame(fx_start_x-5, fx_start_y-8, select(1,fxBuffer:outSize())+10, select(2,fxBuffer:inSize())+10)
	gfx.blit(fxBuffer:getId(),1,0,scrollX,0, select(1,fxBuffer:outSize()), select(2,fxBuffer:outSize()))
	drawScrollbar(fx_start_x, fx_start_y + select(2,fxBuffer:inSize())+10, select(1,fxBuffer:outSize()), 13)
	-- gfx.update()
end

---------------------------------------
function mainloop()
	
	if gfx.mouse_cap&1==1 and last_mouse_cap&1==0 then 
		mouse_ox, mouse_oy = gfx.mouse_x, gfx.mouse_y 
	end
	Ctrl  = gfx.mouse_cap & 4 == 4
	Shift = gfx.mouse_cap & 8 == 8
	Alt = gfx.mouse_cap & 16 == 16

	----------------------
	--MAIN DRAW function--
	checkThemeChange()

	target = nil
	if reaper.GetCursorContext2(true) == 1 and reaper.CountSelectedMediaItems(0)>0 then
		local item = reaper.GetSelectedMediaItem(0,0)
		local take = reaper.GetActiveTake(item)
		if take ~=nil then
			target = take
			setFxContext("item")
		end
	end
	if target == nil then
		setFxContext("track")
		target = reaper.GetSelectedTrack(0,0)
	end

	draw_loop(target)
	----------------------
	----------------------
	last_mouse_cap = gfx.mouse_cap
	last_x,last_y = gfx.mouse_x,gfx.mouse_y

	gfx.update()

	local c = gfx.getchar()
	if c~=-1 and c ~=27 then
		reaper.defer(mainloop)
	end
end
---------------------------------------
-------------


init()
mainloop()

