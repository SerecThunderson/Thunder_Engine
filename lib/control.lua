-- control.lua

-- a quick and dirty control script for the system
-- strange rotation - not sure where the quirk is, or if it's a feature

--local variables for mouse and speed stats
local prev_mx, prev_my = 0, 0
local base_speed = 0.2
local base_rotation_speed = 0.01

--main control function
function control(cam)

	--introduce scaled speed stat according to current fps for consistent speed
	local scale = (stat(7)/60)
	local speed = (base_speed / scale)
	local rotation_speed = (base_rotation_speed / scale)
	
	--apply the desired rotation according to button press -- quirky or my understanding of space is being tested I can't tell
    if btn(0) then local yawRotation = lib.smath.new(0, -rotation_speed, 0, 1) cam.rotation = lib.smath.multiply(cam.rotation, yawRotation) end
    if btn(1) then local yawRotation = lib.smath.new(0, rotation_speed, 0, 1) cam.rotation = lib.smath.multiply(cam.rotation, yawRotation) end
    if btn(2) then local pitchRotation = lib.smath.new(-rotation_speed, 0, 0, 1) cam.rotation = lib.smath.multiply(cam.rotation, pitchRotation) end
    if btn(3) then local pitchRotation = lib.smath.new(rotation_speed, 0, 0, 1) cam.rotation = lib.smath.multiply(cam.rotation, pitchRotation) end

    -- Calculate the forward direction vector
    local forward = {x = 0, y = 0, z = -1, w = 0}  -- Forward direction in camera space
    local rotatedForward = lib.smath.rotatePoint(cam.rotation, forward)
    
    -- Normalize the forward direction vector
    local length = math.sqrt(rotatedForward.x^2 + rotatedForward.y^2 + rotatedForward.z^2)
    rotatedForward.x = rotatedForward.x / length
    rotatedForward.y = rotatedForward.y / length
    rotatedForward.z = rotatedForward.z / length
    
	-- do math to allow mouse drag to rotate camera
    if btn(4) then
    cam.position.x = cam.position.x + rotatedForward.x * speed
    cam.position.y = cam.position.y + rotatedForward.y * speed
    cam.position.z = cam.position.z + rotatedForward.z * speed
    elseif btn(5) then
    cam.position.x = cam.position.x + rotatedForward.x * -speed
    cam.position.y = cam.position.y + rotatedForward.y * -speed
    cam.position.z = cam.position.z + rotatedForward.z * -speed
    end
    
	--get current mouse stats
    local mx, my, mb = mouse()
    if mb==1 then
        -- Calculate mouse movement delta
        local delta_x = mx - prev_mx
        local delta_y = my - prev_my

        -- Adjust camera rotation based on mouse movement
        -- Adjust these values as necessary for sensitivity
        local yawChange = -delta_x * 0.005
        local pitchChange = -delta_y * 0.005

        local yawRotation = lib.smath.new(0, yawChange, 0, 1)
        local pitchRotation = lib.smath.new(pitchChange, 0, 0, 1)

        cam.rotation = lib.smath.multiply(cam.rotation, yawRotation)
        cam.rotation = lib.smath.multiply(cam.rotation, pitchRotation)
    end

	--leave previous mouse stat for reference calculation
    prev_mx, prev_my = mx, my
end

