-- obj.lua
-- module for loading and parsing .obj files

-- Splits a string into lines
-- @param str: String to split into lines.
-- @return Table of lines.
function split_lines(str)
    local lines = {}
    local line = ""
    for i = 1, #str do
        local char = sub(str, i, i)
        if char == "\n" then
            add(lines, line)
            line = ""
        else
            line = line..char
        end
    end
    if #line > 0 then add(lines, line) end
    return lines
end

-- Splits a string by spaces
-- @param str: String to split by spaces.
-- @return Table of space-separated parts.
function split_space(str)
    local parts = {}
    local part = ""
    for i = 1, #str do
        local char = sub(str, i, i)
        if char == " " then
            if #part > 0 then add(parts, part) end
            part = ""
        else
            part = part..char
        end
    end
    if #part > 0 then add(parts, part) end
    return parts
end

-- Extracts a vertex, texture coordinate, or normal from a line
-- @param line: Line containing vector data.
-- @return Table with x, y, z components of the vector.
function extract_vector(line)
    local parts = split_space(line)
    return {
        x = tonum(parts[2]),
        y = tonum(parts[3]),
        z = tonum(parts[4])
    }
end

-- Splits a string by slashes
-- @param str: String to split by slashes.
-- @return Table of slash-separated parts.
function split_slash(str)
    local parts = {}
    local part = ""
    for i = 1, #str do
        local char = sub(str, i, i)
        if char == "/" then
            if #part > 0 then add(parts, part) end
            part = ""
        else
            part = part..char
        end
    end
    if #part > 0 then add(parts, part) end
    return parts
end

-- Revised extract_vector function
function extract_vector(line)
    local parts = split_space(line)
    return {
        x = tonum(parts[2]),
        y = tonum(parts[3]),
        z = tonum(parts[4])
    }
end

-- Function to triangulate a face
-- @param face: Table of vertices representing a face.
-- @return Table of triangles representing the face.
function triangulate_face(face)
    local triangles = {}
    local vertex0 = face[1]

    for i = 3, #face do
        table.insert(triangles, {vertex0, face[i - 1], face[i]})
    end

    return triangles
end

-- Revised extract_face function
-- @param line: Line containing face data.
-- @return Table of faces with vertices and texture/normal indices.
function extract_face(line)
    local parts = split_space(line)
    local face = {}
    for i = 2, #parts do
        local vparts = split_slash(parts[i])
        local vertex = {
            v = tonum(vparts[1]),
            vt = vparts[2] and tonum(vparts[2]) or nil,
            vn = vparts[3] and tonum(vparts[3]) or nil
        }
        table.insert(face, vertex)
    end

    if #face > 3 then
        return triangulate_face(face)
    else
        return {face}
    end
end

-- Function to load and parse obj file for a given Path
-- @param filePath: Path to the OBJ file.
-- @return Table containing model data.
-- @DEV - reassess how objects are loaded/parsed/stored -- ground level structure
function load(filePath)
    local file_content = fetch(filePath)
    if not file_content then
        print("Failed to load file: " .. filePath)
        return nil
    end

    local vertices = {}
    local texcoords = {}
    local normals = {}
    local faces = {}
    local content_lines = split_lines(file_content)

	--for each line in the content loaded above, parse and add to relevant tables
	--triangulation step at the end for naughty files
    for _, line in ipairs(content_lines) do
        if sub(line, 1, 2) == "v " then
            add(vertices, extract_vector(line))
        elseif sub(line, 1, 3) == "vt " then
            add(texcoords, extract_vector(line))
        elseif sub(line, 1, 3) == "vn " then
            add(normals, extract_vector(line))
        elseif sub(line, 1, 2) == "f " then
            local triangles = extract_face(line)
            for _, triangle in ipairs(triangles) do
                add(faces, triangle)
            end
        end
    end
    
    return {
        vertices = vertices,
        texcoords = texcoords,
        normals = normals,
        faces = faces,
        scale = { x = 1, y = 1, z = 1 },
        rotation = lib.smath.new(0, 0, 0, 1),
        position = { x = 0, y = 0, z = 0 }
    }
end
