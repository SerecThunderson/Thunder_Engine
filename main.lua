-- thunderEngine.lua

-- A demonstration in picotron showing use of modules/library system to load
-- and render 3d .obj files in real time with transformation and camera control

-- Not efficient as can be
-- Even when efficiency is hit, there is a hard limit due to lack of efficient "trifill"

-- TODO: explore fundamentals to reduce load
-- Coroutines, meshing, zsort wrapper, oct trees/scenes/unloading
-- Implement fill pattern shading

-- save each other module as separate files in the lib folder
-- render.lua, smath.lua, obj.lua, control.lua, model.lua->saveAs model.obj

---------------------------------------------------------------------Main chunk
--declare library table and basic variables
lib = {}
local cam, model

--Initialize variables, imports, and call first functions
function _init()

	--Import required libraries from the lib folder
	--Generate lib folder by esc to console then cd ram, cd cart, cdz nutz, mkdir lib  
	import_library("lib/smath.lua", "smath")
	import_library("lib/control.lua", "control")
	import_library("lib/obj.lua", "obj")
	import_library("lib/render.lua", "render")

	--initiate a camera by calling "newCam" function of render module
	--the arguments are X, Y, Z, qX, qY, qZ, qW
	--quaternions are weird 
	cam = lib.render.newCam(0, 0, -.9, 0, 0, 0, 1)
   
	--load the model -- a better method of model-handling should be derived
	--think "scene handler" "model handler" "oct trees"
	--note folder load location
	model = lib.obj.load("gfx/model.obj")
   
	--set a simple green palette run
	pal({[0]=1,19,3,17,28},1)
end



-- Modified _draw function to use batch processing
function _draw() cls(16)

    -- call "control" function of control module with cam for argument
    lib.control.control(cam)
    
    -- Update model rotation and pulsate scale
    -- Divide amount by "skip" to implement automatic rate change
    local skip = (stat(7)/60)
    updateModelRotation(model, skip) 
    updatePulsate(model, skip)

    -- call "renderModel" of render module with cam and model for args
    -- eventually need scene handler
    lib.render.renderModel(cam, model)
    
    print_camera_info()
end

-- info block print
function print_camera_info()
    print(string.format("Cam Pos: x=%.3f y=%.3f z=%.3f", cam.position.x, cam.position.y, cam.position.z), 10, 10, 3)
    print("cpu: "..string.format("%.3f",stat(1)), bitc)
    print(stat(7).."fps")
    if model then print("Model Loaded", 10, 250) end
end


--import modules/libraries 
function import_library(module_name, lib_namespace)
	
	--fetches the desired module file from cart folder
	-- use directory tags for accessing subfolders
	local module_code = fetch(module_name)
    	
	--set global module environment for fetched data/code
	local module_env = setmetatable({}, {__index = _G})
	
	--set module environment to namespace -- call lib.module.moduleFunction to execute
	--imported modules can call other imported modules
	lib[lib_namespace] = module_env

	--prepares the loaded module data as callable functions/instructions
	local module, err = load(module_code, module_name, "t", module_env)
	if not module then print("Error importing module: " .. err) return end
   
	--"initiate" the module
	module()
end

------------------------------------------------------------demo animation chunk
local pulsate_time = 0
local pulsate_frequency = 0.022-- Pulsation per second
local pulsate_amplitude = .3 -- Amount of size variation
lightDirection = {x = -0.3, y = 1, z = -0.6} -- Light it up

function updatePulsate(model, skip)
    -- Increment time
    pulsate_time = pulsate_time + (pulsate_frequency / skip)

    -- Calculate scale factor
    local scale_factor = 1 + pulsate_amplitude * math.sin(pulsate_time)

    -- Apply the scale to the model
    model.scale.x = scale_factor
    model.scale.y = scale_factor
    model.scale.z = scale_factor
end

--rotate the model
function updateModelRotation(model, skip)
	 --rotates along a quaternion axis allegedly
    local rot1 = lib.smath.new(-.002/skip, .006/skip, 0, 1)
    local rot2 = lib.smath.new(0, -.01, .008/skip, 1)
    
    --rotates along a euler axis ALLEGEDLY
    local rot3 = lib.smath.fromAxisAngle({x = 0, y = 0, z = 1}, .2/skip)

	--apply rotations in order to the model and normalize
    model.rotation = lib.smath.multiply(rot1, model.rotation)
    model.rotation = lib.smath.multiply(model.rotation, rot2)
    model.rotation = lib.smath.multiply(model.rotation, rot3)
    model.rotation = lib.smath.normalize(model.rotation)
end