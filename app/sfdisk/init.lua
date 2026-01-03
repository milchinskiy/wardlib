---@diagnostic disable: undefined-doc-name

-- Disk partitioning wrapper module
--
-- Thin wrappers around util-linux tools:
--   * sfdisk: script-oriented, declarative partitioning
--
-- These helpers construct CLI invocations and return `ward.process.cmd(...)`
-- objects.
--
-- NOTE on feeding stdin:
-- Ward supports pipelines via Lua 5.4 bitwise OR (`|`). The `Sfdisk.apply(...)`
-- helper below builds `printf "%s" <script> | sfdisk ...` for you.

local _proc = require("ward.process")
local _env = require("ward.env")
local _fs = require("ward.fs")

---@class SfdiskOpts
---@field force boolean? Add `--force`
---@field no_reread boolean? Add `--no-reread`
---@field no_act boolean? Add `--no-act`
---@field quiet boolean? Add `--quiet`
---@field lock boolean|"yes"|"no"|"nonblock"|nil Add `--lock[=mode]`
---@field wipe "auto"|"never"|"always"|string|nil Add `--wipe <mode>`
---@field label string? Add `--label <type>` (e.g. "gpt", "dos")
---@field sector_size integer? Add `--sector-size <n>`
---@field extra string[]? Extra args appended before positional args

---@class SfdiskPartition
---@field start string|integer|nil
---@field size string|integer|nil
---@field type string|nil
---@field uuid string|nil
---@field name string|nil
---@field attrs string|nil
---@field bootable boolean|nil If true, emits `bootable`
---@field extra table<string, string|number|boolean>|nil Extra key/values appended at end (sorted by key)

---@class SfdiskTable
---@field label string|nil e.g. "gpt", "dos"
---@field label_id string|nil maps to `label-id:`
---@field unit string|nil maps to `unit:` (e.g. "sectors")
---@field first_lba integer|nil maps to `first-lba:`
---@field last_lba integer|nil maps to `last-lba:`
---@field extra_header table<string, string|number|boolean>|nil Extra header lines (sorted by key)
---@field partitions SfdiskPartition[]

---@class Sfdisk
---@field bin string Executable name or path to `sfdisk`
---@field cmd fun(argv: string[]|nil, opts: SfdiskOpts|nil): ward.Cmd
---@field dump fun(device: string, opts: SfdiskOpts|nil): ward.Cmd
---@field json fun(device: string, opts: SfdiskOpts|nil): ward.Cmd
---@field list fun(device: string, opts: SfdiskOpts|nil): ward.Cmd
---@field write fun(device: string, opts: SfdiskOpts|nil): ward.Cmd
---@field script fun(spec: SfdiskTable): string Build sfdisk script text
---@field apply fun(device: string, spec_or_script: SfdiskTable|string, opts: SfdiskOpts|nil): ward.Cmd Build `printf | sfdisk` pipeline
local Sfdisk = {
  bin = "sfdisk",
}

---Validate binary name/path.
---@param bin string
---@param label string
local function validate_bin(bin, label)
  assert(type(bin) == "string" and #bin > 0, label .. " binary is not set")
  if bin:find("/", 1, true) then
    assert(_fs.is_exists(bin), string.format("%s binary does not exist: %s", label, bin))
    assert(_fs.is_executable(bin), string.format("%s binary is not executable: %s", label, bin))
  else
    assert(_env.is_in_path(bin), string.format("%s binary is not in PATH: %s", label, bin))
  end
end

---Validate a block device argument.
---@param device string
local function validate_device(device)
  assert(type(device) == "string" and #device > 0, "device must be a non-empty string")
  assert(device:sub(1, 1) ~= "-", "device must not start with '-': " .. tostring(device))
  assert(not device:find("%s"), "device must not contain whitespace: " .. tostring(device))
end

---@param args string[]
---@param extra string[]|nil
local function append_extra(args, extra)
  if extra == nil then
    return
  end
  assert(type(extra) == "table", "extra must be an array")
  for _, v in ipairs(extra) do
    table.insert(args, tostring(v))
  end
end

---Generic constructor: `sfdisk [opts...] <argv...>`
---@param argv string[]|nil
---@param opts SfdiskOpts|nil
---@return ward.Cmd
function Sfdisk.cmd(argv, opts)
  validate_bin(Sfdisk.bin, "sfdisk")
  opts = opts or {}

  local args = { Sfdisk.bin }
  if opts.force then
    table.insert(args, "--force")
  end
  if opts.no_reread then
    table.insert(args, "--no-reread")
  end
  if opts.no_act then
    table.insert(args, "--no-act")
  end
  if opts.quiet then
    table.insert(args, "--quiet")
  end
  if opts.lock ~= nil then
    if opts.lock == true or opts.lock == "yes" then
      table.insert(args, "--lock")
    elseif opts.lock == false or opts.lock == "no" then
      table.insert(args, "--lock=no")
    elseif opts.lock == "nonblock" then
      table.insert(args, "--lock=nonblock")
    else
      error("lock must be boolean or one of: 'yes','no','nonblock'")
    end
  end
  if opts.wipe ~= nil then
    assert(type(opts.wipe) == "string" and #opts.wipe > 0, "wipe must be a non-empty string")
    table.insert(args, "--wipe")
    table.insert(args, opts.wipe)
  end
  if opts.label ~= nil then
    assert(type(opts.label) == "string" and #opts.label > 0, "label must be a non-empty string")
    table.insert(args, "--label")
    table.insert(args, opts.label)
  end
  if opts.sector_size ~= nil then
    assert(
      type(opts.sector_size) == "number" and opts.sector_size > 0 and math.floor(opts.sector_size) == opts.sector_size,
      "sector_size must be a positive integer"
    )
    table.insert(args, "--sector-size")
    table.insert(args, tostring(opts.sector_size))
  end
  append_extra(args, opts.extra)
  if argv ~= nil then
    assert(type(argv) == "table", "argv must be an array")
    for _, v in ipairs(argv) do
      table.insert(args, tostring(v))
    end
  end
  return _proc.cmd(table.unpack(args))
end

---Dump partition table: `sfdisk --dump <device>`
---@param device string
---@param opts SfdiskOpts|nil
---@return ward.Cmd
function Sfdisk.dump(device, opts)
  validate_device(device)
  return Sfdisk.cmd({ "--dump", device }, opts)
end

---Dump partition table as JSON: `sfdisk --json <device>`
---@param device string
---@param opts SfdiskOpts|nil
---@return ward.Cmd
function Sfdisk.json(device, opts)
  validate_device(device)
  return Sfdisk.cmd({ "--json", device }, opts)
end

---List partitions: `sfdisk --list <device>`
---@param device string
---@param opts SfdiskOpts|nil
---@return ward.Cmd
function Sfdisk.list(device, opts)
  validate_device(device)
  return Sfdisk.cmd({ "--list", device }, opts)
end

---Apply partition table script to device: `sfdisk [opts...] <device>`
---
---Provide the sfdisk script via stdin when executing the returned command.
---@param device string
---@param opts SfdiskOpts|nil
---@return ward.Cmd
function Sfdisk.write(device, opts)
  validate_device(device)
  return Sfdisk.cmd({ device }, opts)
end

local function _kv(v)
  if v == nil then
    return nil
  end
  if type(v) == "number" then
    return tostring(v)
  end
  if type(v) == "string" then
    return v
  end
  if type(v) == "boolean" then
    return v and true or nil
  end
  return tostring(v)
end

local function _sorted_keys(tbl)
  local keys = {}
  for k, _ in pairs(tbl) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

---Encode a single partition line.
---@param part SfdiskPartition
---@return string
local function encode_partition(part)
  assert(type(part) == "table", "partition must be a table")

  local fields = {}

  local function add_kv(key, val)
    local vv = _kv(val)
    if vv == nil then
      return
    end
    if vv == true then
      table.insert(fields, key)
    else
      table.insert(fields, string.format("%s=%s", key, vv))
    end
  end

  -- Stable, explicit ordering for common keys.
  add_kv("start", part.start)
  add_kv("size", part.size)
  add_kv("type", part.type)
  add_kv("uuid", part.uuid)
  add_kv("name", part.name)
  add_kv("attrs", part.attrs)
  if part.bootable then
    add_kv("bootable", true)
  end

  if part.extra ~= nil then
    assert(type(part.extra) == "table", "partition.extra must be a table")
    for _, k in ipairs(_sorted_keys(part.extra)) do
      add_kv(k, part.extra[k])
    end
  end

  return table.concat(fields, ", ")
end

---Encode an sfdisk table script.
---@param spec SfdiskTable
---@return string
function Sfdisk.script(spec)
  assert(type(spec) == "table", "spec must be a table")
  assert(type(spec.partitions) == "table", "spec.partitions must be an array")

  local out = {}

  local function add_header(key, val)
    local vv = _kv(val)
    if vv == nil then
      return
    end
    if vv == true then
      vv = "yes"
    end
    table.insert(out, string.format("%s: %s", key, vv))
  end

  add_header("label", spec.label)
  add_header("label-id", spec.label_id)
  add_header("unit", spec.unit)
  add_header("first-lba", spec.first_lba)
  add_header("last-lba", spec.last_lba)

  if spec.extra_header ~= nil then
    assert(type(spec.extra_header) == "table", "spec.extra_header must be a table")
    for _, k in ipairs(_sorted_keys(spec.extra_header)) do
      add_header(k, spec.extra_header[k])
    end
  end

  if #out > 0 then
    table.insert(out, "") -- blank line between header and partitions
  end

  for _, p in ipairs(spec.partitions) do
    table.insert(out, encode_partition(p))
  end

  return table.concat(out, "\n") .. "\n"
end

---Build a single-call pipeline: `printf "%s" <script> | sfdisk ... <device>`
---
---`spec_or_script` may be:
---  * a string containing a valid sfdisk script, or
---  * a structured table accepted by `Sfdisk.script(spec)`.
---@param device string
---@param spec_or_script SfdiskTable|string
---@param opts SfdiskOpts|nil
---@return ward.Cmd
function Sfdisk.apply(device, spec_or_script, opts)
  validate_device(device)

  local script
  if type(spec_or_script) == "string" then
    script = spec_or_script
    if not script:match("\n$") then
      script = script .. "\n"
    end
  else
    script = Sfdisk.script(spec_or_script)
  end

  -- `printf "%s"` avoids interpreting `%` sequences inside user scripts.
  local feeder = _proc.cmd("printf", "%s", script)
  return feeder | Sfdisk.write(device, opts)
end

return {
  Sfdisk = Sfdisk,
}

