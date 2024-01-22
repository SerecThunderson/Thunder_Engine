-- render.lua

-- This module handles the rendering of 3D models. It includes functions for projecting 3D points to 2D,
-- determining visibility of faces, sorting faces for correct rendering order, and the main rendering logic.

-----------------------------------------------------------------------------------------------------------------
-- Combined function to render a given model to a given camera
-- @param camera: The camera object used for the projection.
-- @param model: The 3D model whose vertices are to be transformed.
function render(camera, model)
    local transformedVertices, sortedFaces = batchTransformModelVertices(model, camera)
    local camRotation = lib.smath.conjugate(camera.rotation) -- Precompute camRotation

    if not sortedFaces or #sortedFaces == 0 then
        print("Error: No sorted faces available for rendering.")
        return
    end

    local projectedVertices = {}
    for i, vertex in ipairs(transformedVertices) do
        projectedVertices[i] = projectVertex(camera, vertex, camRotation)
    end

    for _, faceInfo in ipairs(sortedFaces) do
        local face = faceInfo.face
        local isVisible, normal = isFaceVisible(camera, face, transformedVertices)

        if isVisible then
            local faceVertices = {}
            for _, vertexIndex in ipairs(face) do
                local projectedVertex = projectedVertices[vertexIndex.v]
                if projectedVertex then
                    table.insert(faceVertices, projectedVertex)
                else
                    break
                end
            end

            if #faceVertices == #face then
                local lightLevel = getLightLevel(face, transformedVertices, normal)
                fill_triangle(faceVertices[1], faceVertices[2], faceVertices[3], lightLevel)
            end
        end
    end
end

-- Transforms all vertices of a model for the current frame.
-- Applies scaling, rotation, and translation transformations to each vertex.
-- @param model: The 3D model whose vertices are to be transformed.
-- @return An array of transformed vertices.
function batchTransformModelVertices(model, camera)
    local batchTransformedVertices = {}
    local faceDepths = {} 

    for i, vertex in ipairs(model.vertices) do
        local scaledX, scaledY, scaledZ = vertex.x * model.scale.x, vertex.y * model.scale.y, vertex.z * model.scale.z
        local rotatedVertex = lib.smath.rotatePoint(model.rotation, {x = scaledX, y = scaledY, z = scaledZ})

        batchTransformedVertices[i] = {
            x = rotatedVertex.x + model.position.x,
            y = rotatedVertex.y + model.position.y,
            z = rotatedVertex.z + model.position.z
        }
    end

    for _, face in ipairs(model.faces) do
        local depth = calculateFaceDepth(face, batchTransformedVertices, camera)
        table.insert(faceDepths, {face = face, depth = depth})
    end

    table.sort(faceDepths, function(a, b) return a.depth > b.depth end)

    return batchTransformedVertices, faceDepths
end

-- Projects a vertex from 3D space onto the 2D screen.
-- @param camera: The camera object used for the projection.
-- @param vertex: The 3D vertex to be projected.
-- @return The 2D coordinates of the projected vertex, or nil if the vertex is not visible.
function projectVertex(camera, vertex, camRotation)
    local tx, ty, tz = vertex.x - camera.position.x, vertex.y - camera.position.y, vertex.z - camera.position.z
    local transformedVertex = lib.smath.rotatePoint(camRotation, {x = tx, y = ty, z = tz})
    
    if transformedVertex.z <= 0 then return nil end

    local pdz = camera.perspectiveDivide / transformedVertex.z
    local projectedX = transformedVertex.x * pdz
    local projectedY = transformedVertex.y * pdz

    projectedX = (projectedX / camera.aspectRatio + 1) * camera.halfWidth
    projectedY = (1 - projectedY) * camera.halfHeight

    if projectedX < 0 or projectedX > camera.width or projectedY < 0 or projectedY > camera.height then
        return nil
    end

    return {x = math.floor(projectedX + 0.5), y = math.floor(projectedY + 0.5)}
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

-- Function to create a new camera object.
-- @param x, y, z: Position coordinates of the camera.
-- @param qx, qy, qz, qw: Quaternion components representing the camera's rotation.
-- @return A camera object with position, rotation, field of view, and screen dimensions.
function newCam(x, y, z, qx, qy, qz, qw)
    local width = 480
    local height = 270
    local fovRadians = 70 * math.pi / 180 -- 70 degrees field of view
    local cam = {
        position = {x = x or 0, y = y or 0, z = z or 0},
        rotation = lib.smath.new(qx, qy, qz, qw),
        fovRadians = fovRadians,
        perspectiveDivide = 1 / math.tan(fovRadians / 2),
        aspectRatio = width / height,
        width = width,
        height = height,
        halfWidth = width / 2,
        halfHeight = height / 2
    }
    return cam
end

-- Fill triangle function, fills a triangle on the screen given its vertices and color.
-- It splits a general triangle into two special cases: top-flat and bottom-flat triangles, then fills them.
-- @param v1, v2, v3: The three vertices of the triangle in screen space.
-- @param color: The base color to fill the triangle with.* for use with shaded color runs
-- @DEV - consider combined use of runs + fill for optimized palette and shading
function fill_triangle(v1, v2, v3, color)

    local function fill_bottom_flat_triangle(v1, v2, v3)
        local invslope1 = (v2.x - v1.x) / (v2.y - v1.y)
        local invslope2 = (v3.x - v1.x) / (v3.y - v1.y)

        local curx1 = v1.x
        local curx2 = v1.x

        for scanlineY = v1.y, v2.y do
            rectfill(curx1 \ 1, scanlineY, curx2 \ 1, scanlineY, color\1) -- thank you Werxy
            curx1 = curx1 + invslope1
            curx2 = curx2 + invslope2
        end
    end

    local function fill_top_flat_triangle(v1, v2, v3)
        local invslope1 = (v3.x - v1.x) / (v3.y - v1.y)
        local invslope2 = (v3.x - v2.x) / (v3.y - v2.y)

        local curx1 = v3.x
        local curx2 = v3.x

        for scanlineY = v3.y, v1.y, -1 do
            rectfill(curx1 \ 1, scanlineY, curx2 \ 1, scanlineY, color \ 1) -- thank you Werxy
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

