-- render.lua

-- This module handles the rendering of 3D models. It includes functions for projecting 3D points to 2D,
-- determining visibility of faces, sorting faces for correct rendering order, and the main rendering logic.

-----------------------------------------------------------------------------------------------------------------
local fovRadians = 90 * math.pi / 180
local perspectiveDivide = 1 / math.tan(fovRadians / 2)
local aspectRatio = 480 / 270

-- main function to render a given model to a given camera
-- need to optimize each step and cull redundancy
-- @param camera: The camera object used for the projection.
-- @param model: The 3D model whose vertices are to be transformed.
function renderModel(camera, model)
    local transformedVertices, sortedFaces = batchTransformModelVertices(model, camera)
    batchRenderFaces(camera, model, transformedVertices, sortedFaces, perspectiveDivide, aspectRatio)
end

-- Function to create a new camera object.
-- @param x, y, z: Position coordinates of the camera.
-- @param qx, qy, qz, qw: Quaternion components representing the camera's rotation.
-- @return A camera object with position, rotation, field of view, and screen dimensions.
function newCam(x, y, z, qx, qy, qz, qw)
    local cam = {
        position = {x = x or 0, y = y or 0, z = z or 0},
        rotation = lib.smath.new(qx, qy, qz, qw),
        fov = 70,
        width = 480,
        height = 270
    }
    return cam
end

-- Determines if a face of the model is visible to the camera.
-- @param camera: The camera object.
-- @param face: The face of the model to check visibility for.
-- @param transformedVertices: An array of vertices that have been transformed for the current frame.
-- @return True if the face is visible to the camera, false otherwise.
function isFaceVisible(camera, face, transformedVertices)
    local v1, v2, v3 = transformedVertices[face[1].v], transformedVertices[face[2].v], transformedVertices[face[3].v]
    local normal = lib.smath.calculateNormal(v1, v2, v3)
    local viewVector = {x = camera.position.x - v1.x, y = camera.position.y - v1.y, z = camera.position.z - v1.z}
    local isVisible = lib.smath.dotProduct(normal, viewVector) > 0
    return isVisible, normal
end

-- Transforms all vertices of a model for the current frame.
-- Applies scaling and rotation transformations to each vertex.
-- @param model: The 3D model whose vertices are to be transformed.
-- @return An array of transformed vertices.
function batchTransformModelVertices(model, camera)
    local batchTransformedVertices = {}
    local faceDepths = {} -- Store average depth of each face

    for _, vertex in ipairs(model.vertices) do
        local scaledVertex = {
            x = vertex.x * model.scale.x,
            y = vertex.y * model.scale.y,
            z = vertex.z * model.scale.z
        }
        table.insert(batchTransformedVertices, lib.smath.rotatePoint(model.rotation, scaledVertex))
    end

    -- Calculate and store face depths
    for _, face in ipairs(model.faces) do
        local depth = calculateFaceDepth(face, batchTransformedVertices, camera)
        table.insert(faceDepths, {face = face, depth = depth})
    end

    -- Sort faces by depth
    table.sort(faceDepths, function(a, b) return a.depth > b.depth end)

    return batchTransformedVertices, faceDepths
end

function calculateFaceDepth(face, vertices, camera)
    -- Calculate centroid of the face
    local centroid = {x = 0, y = 0, z = 0}
    for _, vertexIndex in ipairs(face) do
        centroid.x = centroid.x + vertices[vertexIndex.v].x
        centroid.y = centroid.y + vertices[vertexIndex.v].y
        centroid.z = centroid.z + vertices[vertexIndex.v].z
    end
    centroid.x = centroid.x / #face
    centroid.y = centroid.y / #face
    centroid.z = centroid.z / #face

    -- Calculate depth as distance from camera to centroid
    local depth = math.sqrt(
        (centroid.x - camera.position.x)^2 +
        (centroid.y - camera.position.y)^2 +
        (centroid.z - camera.position.z)^2
    )

    return depth
end


-- Calculate light level for a given face using normal and light direction.
-- @param face: The face for which light level is calculated.
-- @param transformedVertices: An array of vertices that have been transformed for the current frame.
-- @return The light level (brightness) for the face.
function getLightLevel(face, transformedVertices, normal)
    normal = lib.smath.normalizeVector(normal)
    local dotProd = lib.smath.dotProduct(normal, lightDirection)

    dotProd = math.max(0, dotProd)
    local lightLevel = math.floor(dotProd * 5)
    if lightLevel > 4 then lightLevel = 4 end

    return lightLevel
end

-- Projects a vertex from 3D space onto the 2D screen.
-- @param camera: The camera object used for the projection.
-- @param vertex: The 3D vertex to be projected.
-- @param perspectiveDivide: The perspective divide factor, calculated from camera's field of view.
-- @param aspectRatio: The aspect ratio of the screen.
-- @return The 2D coordinates of the projected vertex, or nil if the vertex is not visible.
function projectVertex(camera, vertex, perspectiveDivide, aspectRatio)
    -- Translate vertex relative to camera position
    local camPos = camera.position
    local tx, ty, tz = vertex.x - camPos.x, vertex.y - camPos.y, vertex.z - camPos.z

    -- Rotate vertex according to camera's rotation
    local camRotation = lib.smath.conjugate(camera.rotation)
    local transformedVertex = lib.smath.rotatePoint(camRotation, {x = tx, y = ty, z = tz})

    -- Return nil if vertex is behind the camera
    if transformedVertex.z <= 0 then return nil end

    -- Perspective projection
    local pdz = perspectiveDivide / transformedVertex.z
    local projectedX = transformedVertex.x * pdz
    local projectedY = transformedVertex.y * pdz

    -- Convert to screen coordinates
    projectedX = (projectedX / aspectRatio + 1) * camera.width / 2
    projectedY = (1 - projectedY) * camera.height / 2

    -- Return nil if vertex is outside screen bounds
    if projectedX < 0 or projectedX > camera.width or projectedY < 0 or projectedY > camera.height then
        return nil
    end

    return {x = math.floor(projectedX + 0.5), y = math.floor(projectedY + 0.5)}
end

-- Renders a batch of faces, sorted by their depth relative to the camera.
-- This function first projects vertices, then renders visible and valid faces.
-- @param camera: The camera object.
-- @param model: The 3D model to render.
-- @param transformedVertices: An array of vertices that have been transformed for the current frame.
-- @param sortedFaces: The faces of the model sorted by depth.
-- @param perspectiveDivide: The perspective divide factor, calculated from camera's field of view.
-- @param aspectRatio: The aspect ratio of the screen.
function batchRenderFaces(camera, model, transformedVertices, sortedFaces, perspectiveDivide, aspectRatio)
    if not sortedFaces or #sortedFaces == 0 then
        print("Error: No sorted faces available for rendering.")
        return
    end

    local projectedVertices = {}
    for i, vertex in ipairs(transformedVertices) do
        projectedVertices[i] = projectVertex(camera, vertex, perspectiveDivide, aspectRatio)
    end

    for _, faceInfo in ipairs(sortedFaces) do
        local face = faceInfo.face
        local faceVertices, faceIsValid = {}, true

        for _, vertexIndex in ipairs(face) do
            local projectedVertex = projectedVertices[vertexIndex.v]
            if projectedVertex then
                table.insert(faceVertices, projectedVertex)
            else
                faceIsValid = false
                break
            end
        end

        if faceIsValid then
            -- Calculate face normal and check visibility
            local v1, v2, v3 = transformedVertices[face[1].v], transformedVertices[face[2].v], transformedVertices[face[3].v]
            local normal = lib.smath.calculateNormal(v1, v2, v3)
            local isVisible = lib.smath.dotProduct(normal, {x = camera.position.x - v1.x, y = camera.position.y - v1.y, z = camera.position.z - v1.z}) > 0

            if isVisible then
                local lightLevel = getLightLevel(face, transformedVertices, normal)
                fill_triangle(faceVertices[1], faceVertices[2], faceVertices[3], lightLevel)
            end
        end
    end
end

-- Fill triangle function, fills a triangle on the screen given its vertices and color.
-- It splits a general triangle into two special cases: top-flat and bottom-flat triangles, then fills them.
-- @param v1, v2, v3: The three vertices of the triangle in screen space.
-- @param color: The color to fill the triangle with.
function fill_triangle(v1, v2, v3, color)

	-- local helper function to fill a triangle with a flat bottom
	local function fill_bottom_flat_triangle(v1, v2, v3, color)
	    local invslope1 = (v2.x - v1.x) / (v2.y - v1.y)
	    local invslope2 = (v3.x - v1.x) / (v3.y - v1.y)
	
	    local curx1 = v1.x
	    local curx2 = v1.x
	
	    for scanlineY = v1.y, v2.y do
	        rectfill(math.floor(curx1), scanlineY, math.floor(curx2), scanlineY, color)
	        curx1 = curx1 + invslope1
	        curx2 = curx2 + invslope2
	    end
	end
	
	-- local helper function to fill a triangle with a flat top
	local function fill_top_flat_triangle(v1, v2, v3, color)
	    local invslope1 = (v3.x - v1.x) / (v3.y - v1.y)
	    local invslope2 = (v3.x - v2.x) / (v3.y - v2.y)
	
	    local curx1 = v3.x
	    local curx2 = v3.x
	
	    for scanlineY = v3.y, v1.y, -1 do
	        rectfill(math.floor(curx1), scanlineY, math.floor(curx2), scanlineY, color)
	        curx1 = curx1 - invslope1
	        curx2 = curx2 - invslope2
	    end
	end

	-- local helper function to sort vertices by y-coordinate
	local function sort_vertices(v1, v2, v3)
	    if v2.y < v1.y then v1, v2 = v2, v1 end
	    if v3.y < v1.y then v1, v3 = v3, v1 end
	    if v3.y < v2.y then v2, v3 = v3, v2 end
	    return v1, v2, v3
	end

    -- Sort vertices by y-coordinate
    v1, v2, v3 = sort_vertices(v1, v2, v3)

    -- Split triangle into two parts: top-flat and bottom-flat
    if v2.y == v3.y then
        fill_bottom_flat_triangle(v1, v2, v3, color)
    elseif v1.y == v2.y then
        fill_top_flat_triangle(v1, v2, v3, color)
    else
        -- For general case, split into two flat triangles
        local v4 = { x = v1.x + (v2.y - v1.y) / (v3.y - v1.y) * (v3.x - v1.x), y = v2.y }
        fill_bottom_flat_triangle(v1, v2, v4, color)
        fill_top_flat_triangle(v2, v4, v3, color)
    end
end
---------------------------------------------------------------------------------------------------------------------
--PRECALCULATE EVERYTHING
-- NORMALS TRANSFORMATIONS PROJECTION
