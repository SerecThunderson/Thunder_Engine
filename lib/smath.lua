-- smath.lua 

-- a collection of math tools, mostly to do with quaternions.
-- quaternion functions need a "q" added for easier distinction
-- needs auditing.

-- Function to get the conjugate of a quaternion.
function conjugate(q) return new(-q.x, -q.y, -q.z, q.w) end

-- Function to determine the sign of a number: -1 for negative, 1 for positive, 0 for zero.
function sign(x) return x < 0 and -1 or (x > 0 and 1 or 0) end

-- Calculates the Dot Product of two vectors.
function dotProduct(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

-- Converts degrees to radians.
function degreesToRadians(angle_deg) return angle_deg * math.pi / 180 end

-- Creates a new quaternion from components, defaults to a unit quaternion if no parameters given.
function new(x, y, z, w) return {x = x or 0, y = y or 0, z = z or 0, w = w or 1} end

-- Normalizes a quaternion to ensure its length is 1 (unit quaternion).
function normalize(q)
    local length = math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
    return {x = q.x / length, y = q.y / length, z = q.z / length, w = q.w / length}
end

-- Computes the Cross Product of two vectors.
function crossProduct(a, b) return {
    x = a.y * b.z - a.z * b.y,
    y = a.z * b.x - a.x * b.z,
    z = a.x * b.y - a.y * b.x}
end

-- Normalizes a vector to make its length 1.
function normalizeVector(vec)
    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    if length == 0 then return {x = 0, y = 0, z = 0} end -- Prevent division by zero
    return {x = vec.x / length, y = vec.y / length, z = vec.z / length}
end

-- Rotates a model using a quaternion rotation.
function rotateModel(model, axis, angle_deg)
    local rotationQuaternion = fromAxisAngle(axis, angle_deg)
    model.rotation = multiply(model.rotation, rotationQuaternion)
    model.rotation = normalize(model.rotation)
end

-- Calculates the normal vector of a face defined by three vertices.
function calculateNormal(v1, v2, v3)
    local u = {x = v2.x - v1.x, y = v2.y - v1.y, z = v2.z - v1.z}
    local v = {x = v3.x - v1.x, y = v3.y - v1.y, z = v3.z - v1.z}
    return crossProduct(u, v)
end

-- Multiplies two quaternions together.
function multiply(q1, q2) return new(
    q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
    q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
    q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
    q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z)
end

-- Creates a rotation quaternion from an axis and an angle in degrees.
function fromAxisAngle(axis, angle_deg)
    local angle_rad = math.rad(angle_deg)
    local half_angle = angle_rad / 2
    local sin_half_angle = math.sin(half_angle)
    return new(axis.x * sin_half_angle, axis.y * sin_half_angle, axis.z * sin_half_angle, math.cos(half_angle))
end

-- Inverts a quaternion.
function inverse(q)
    local lengthSquared = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w
    return {
        x = -q.x / lengthSquared,
        y = -q.y / lengthSquared,
        z = -q.z / lengthSquared,
        w = q.w / lengthSquared
    }
end

-- Rotates a point in 3D space using a quaternion.
function rotatePoint(q, point)
    local w, x, y, z = q.w, q.x, q.y, q.z
    local px, py, pz = point.x, point.y, point.z

    local qx = w * px + y * pz - z * py
    local qy = w * py + z * px - x * pz
    local qz = w * pz + x * py - y * px
    local qw = -x * px - y * py - z * pz

    return {
        x = qx * w + qw * -x + qy * -z - qz * -y,
        y = qy * w + qw * -y + qz * -x - qx * -z,
        z = qz * w + qw * -z + qx * -y - qy * -x
    }
end

-- Converts a quaternion to Euler angles (yaw, pitch, roll).
function toEuler(q)
    local norm_q = normalize(q)

    local siny = 2 * (norm_q.w * norm_q.y - norm_q.z * norm_q.x)
    local yaw = math.abs(siny) >= 1 and math.pi / 2 * sign(siny) or math.asin(siny)

    local sinp_cos = 2 * (norm_q.w * norm_q.x + norm_q.y * norm_q.z)
    local cosp_cos = 1 - 2 * (norm_q.x * norm_q.x + norm_q.y * norm_q.y)
    local pitch = atan2(cosp_cos, sinp_cos)

    local sinr_cos = 2 * (norm_q.w * norm_q.z + norm_q.x * norm_q.y)
    local cosr_cos = 1 - 2 * (norm_q.y * norm_q.y + norm_q.z * norm_q.z)
    local roll = atan2(cosr_cos, sinr_cos)
    
    return {yaw * 180 / math.pi, pitch * 180 / math.pi, roll * 180 / math.pi}
end 