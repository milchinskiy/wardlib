-- wardlib.util.validate
-- Minimal validation helpers shared across wardlib modules.

local M = {}

-- Validate that a binary is available (either absolute path or present in PATH).
-- @param bin string
-- @param label string
function M.bin(bin, label)
	local env = require("ward.env")
	local fs = require("ward.fs")

	assert(type(bin) == "string" and #bin > 0, (label or "binary") .. " is not set")
	if bin:find("/", 1, true) then
		assert(fs.is_exists(bin), string.format("%s does not exist: %s", (label or "binary"), bin))
		assert(fs.is_executable(bin), string.format("%s is not executable: %s", (label or "binary"), bin))
	else
		assert(env.is_in_path(bin), string.format("%s is not in PATH: %s", (label or "binary"), bin))
	end
end

-- @param v any
-- @param label string
function M.non_empty_string(v, label)
	assert(type(v) == "string" and #v > 0, label .. " must be a non-empty string")
end

-- @param v any
-- @param label string
function M.not_flag(v, label)
	M.non_empty_string(v, label)
	assert(v:sub(1, 1) ~= "-", label .. " must not start with '-': " .. tostring(v))
end

-- @param v any
-- @param label string
-- @param min number|nil
function M.number_min(v, label, min)
	assert(type(v) == "number", label .. " must be a number")
	if min ~= nil then
		assert(v >= min, label .. " must be >= " .. tostring(min))
	end
end

-- @param v any
-- @param label string
function M.number_non_negative(v, label)
	assert(type(v) == "number" and v >= 0, label .. " must be a non-negative number")
end

-- @param v any
-- @param label string
function M.integer(v, label)
	assert(type(v) == "number" and math.floor(v) == v, label .. " must be an integer")
end

-- @param v any
-- @param label string
-- @param min integer|nil
function M.integer_min(v, label, min)
	M.integer(v, label)
	if min ~= nil then
		assert(v >= min, label .. " must be >= " .. tostring(min))
	end
end

-- @param v any
-- @param label string
function M.integer_non_negative(v, label)
	M.integer_min(v, label, 0)
end

return M
