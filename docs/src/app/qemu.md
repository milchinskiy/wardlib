# app.qemu

`app.qemu` is a set of command-construction wrappers around QEMU tools:

- `qemu-system-<arch>` (system emulation)
- `qemu-img` (disk image utility)
- `qemu-nbd` (Network Block Device server / /dev/nbd binding / list mode)
- `qemu-storage-daemon` (QSD)

> This module constructs `ward.process.cmd(...)` invocations; it does not parse output.
> Consumers can use `wardlib.tools.out` (or their own parsing) on the
> `:output()` result.

## Import

```lua
local qemu = require("wardlib.app.qemu")
local Qemu = qemu.Qemu
```

## Philosophy

QEMU has a *very* large CLI surface. `app.qemu` covers the common patterns with structured
option tables and helper builders (for QEMU's `k=v,k2=v2` comma-list syntax),
while still leaving an escape hatch:

- `opts.extra: string[]` is appended verbatim at the end for advanced flags.

## Helpers (comma-list builders)

Many QEMU flags accept comma-separated specs. These helpers accept either:

- a raw `string` (passed as-is), or
- a `table` that is encoded into a stable `head,k=v,...` string (keys sorted).

Boolean values in tables are encoded as `on`/`off`.

### `qemu.hostfwd(spec) -> string`

Builds a `hostfwd=` value for user-mode networking (`-netdev user,...`).

```lua
qemu.hostfwd({ hostport = 2222, guestport = 22 })
-- => "tcp::2222-:22"

qemu.hostfwd({
  proto = "udp",
  hostaddr = "127.0.0.1",
  hostport = 5353,
  guestaddr = "10.0.2.15",
  guestport = 5353,
})
-- => "udp:127.0.0.1:5353-10.0.2.15:5353"
```

Fields:

- `proto` (default `"tcp"`)
- `hostaddr` (optional; empty means all interfaces)
- `hostport` (required)
- `guestaddr` (optional; empty means default guest)
- `guestport` (required)


### `qemu.drive(spec) -> string`

Builds a `-drive <spec>` string.

- Required key when using a table: `file`
- Alias: `if_` becomes `if` (because `if` is a Lua keyword)

```lua
local drive = qemu.drive({
  file = "disk.qcow2",
  format = "qcow2",
  if_ = "virtio",
  cache = "writeback",
})
-- => "file=disk.qcow2,cache=writeback,format=qcow2,if=virtio"
```

### `qemu.netdev(spec) -> string`

Builds a `-netdev <spec>` string.

- Required key when using a table: `type`

```lua
local net0 = qemu.netdev({
  type = "user",
  id = "net0",
  hostfwd = qemu.hostfwd({ hostport = 2222, guestport = 22 }),
})
```

### `qemu.device(spec) -> string`

Builds a `-device <spec>` string.

- Required key when using a table: `driver`

```lua
local nic = qemu.device({ driver = "virtio-net-pci", netdev = "net0" })
```

### `qemu.chardev(spec)`, `qemu.fsdev(spec)`, `qemu.object(spec)`, `qemu.kv(spec)`

These mirror the same encoding approach:

- `chardev`: required key `backend`
- `fsdev`: required key `driver`
- `object`: required key `type`
- `kv`: generic `k=v,k2=v2` encoder

## System emulation

### `Qemu.system(arch, opts) -> ward.Cmd`

Runs `qemu-system-<arch>` with a structured `opts` table.

- `arch` examples: `"x86_64"`, `"aarch64"`, `"riscv64"`, ...
- `opts.bin` can override the binary (name or absolute path)

Common options:

- `memory`: `-m <val>` (string or number)
- `smp`: `-smp <val>` (string or number)
- `machine`: `-machine <val>`
- `accel`: `-accel <val>` (string or string[])
- `cpu`: `-cpu <val>`
- `nographic`: `-nographic`
- `display`: `-display <val>`
- `serial`, `monitor`, `qmp`: repeatable
- `drive`, `device`, `netdev`, `chardev`, `fsdev`, `object`, `global`: repeatable
(strings or tables)
- `extra`: appended verbatim


#### Additional supported system options

In addition to the common options above, the wrapper also supports:

- `name`: `-name <val>`
- `uuid`: `-uuid <val>`
- `bios`: `-bios <file>`
- `kernel`: `-kernel <file>`
- `initrd`: `-initrd <file>`
- `append`: `-append <cmdline>`
- `boot`: `-boot <spec>`
- `cdrom`: `-cdrom <file>`
- `snapshot`: `-snapshot`
- `daemonize`: `-daemonize`
- `pidfile`: `-pidfile <path>`
- `gdb`: `-gdb <dev>`
- `start_paused`: `-S`
- `rtc`: `-rtc <spec>`
- `clock`: `-clock <spec>`
- `global`: `-global <spec>` (repeatable)
- `images`: positional images appended last (`string|string[]`)

Repeatable spec lists (each element may be a raw string or a table encoded into a stable comma-list):

- `object`: `-object <spec>`
- `chardev`: `-chardev <spec>`
- `fsdev`: `-fsdev <spec>`
- `netdev`: `-netdev <spec>`
- `device`: `-device <spec>`
- `drive`: `-drive <spec>`

##### Example: kernel boot

```lua
Qemu.system_x86_64({
  nographic = true,
  machine = "q35",
  accel = { "kvm", "tcg" },
  memory = "1G",
  kernel = "bzImage",
  initrd = "initramfs.cpio.gz",
  append = "console=ttyS0 root=/dev/ram0",
}):run()
```

##### Example: QMP via -chardev

```lua
Qemu.system_x86_64({
  nographic = true,
  chardev = { { backend = "socket", id = "qmp0", path = "/tmp/qmp.sock", server = true, wait = false } },
  qmp = { "chardev:qmp0,server=on,wait=off" },
}):run()
```

Convenience helpers:

- `Qemu.system_x86_64(opts)`
- `Qemu.system_i386(opts)`
- `Qemu.system_aarch64(opts)`
- `Qemu.system_arm(opts)`
- `Qemu.system_riscv64(opts)`
- `Qemu.system_ppc64(opts)`

#### Example: boot a qcow2 image with user-mode networking

```lua
local qemu = require("wardlib.app.qemu")
local Qemu = qemu.Qemu

Qemu.system_x86_64({
  memory = "2G",
  smp = 4,
  nographic = true,

  netdev = {
    { type = "user", id = "net0", hostfwd = qemu.hostfwd({ hostport = 2222, guestport = 22 }) },
  },
  device = {
    { driver = "virtio-net-pci", netdev = "net0" },
  },
  drive = {
    { file = "disk.qcow2", format = "qcow2", if_ = "virtio" },
  },
}):run()
```

## Disk images (`qemu-img`)

### `Qemu.img_create(path, size, opts)`

Builds:

- `qemu-img create [-f <fmt>] [-o <k=v,...>] <path> <size>`

```lua
Qemu.img_create("disk.qcow2", "20G", {
  format = "qcow2",
  options = { cluster_size = "2M", preallocation = "metadata" },
}):run()
```

### `Qemu.img_info(path, opts)`

Builds:

- `qemu-img info [-f <fmt>] [--output=<fmt>] <path>`

### `Qemu.img_convert(src, dst, opts)`

Builds:

- `qemu-img convert ... <src> <dst>`

Supported options include: `input_format (-f)`, `output_format (-O)`, `output_options (-o)`,
`backing_file (-B)`, `compress (-c)`, `progress (-p)`, `quiet (-q)`,
`target_image_opts`, `image_opts`, and `extra`.


#### `QemuImgConvertOpts` fields

- `input_format`: `-f <fmt>`
- `output_format`: `-O <fmt>`
- `output_options`: `-o <opts>` (string|string[]|table; encoded as comma-list)
- `backing_file`: `-B <file>`
- `snapshot`: `-s <name>`
- `compress`: `-c`
- `progress`: `-p`
- `quiet`: `-q`
- `unsafe`: `-U`
- `image_opts`: `--image-opts`
- `target_image_opts`: `--target-image-opts`
- `extra`: appended verbatim

### `Qemu.img_resize(path, size, opts)`

Builds:

- `qemu-img resize [-f <fmt>] <path> <size>`

### Snapshots

- `Qemu.img_snapshot_list(path)`
- `Qemu.img_snapshot_create(path, name)`
- `Qemu.img_snapshot_apply(path, name)`
- `Qemu.img_snapshot_delete(path, name)`

## NBD (`qemu-nbd`)

The wrapper supports both:

- local `/dev/nbdX` binding (Linux) via `-c/--connect` and `-d/--disconnect`, and
- server/list mode with `--port`, `--bind`, `--socket`, `--export-name`,
TLS objects, etc.

### `Qemu.nbd_connect(dev, image, opts)`

```lua
-- qemu-nbd -c /dev/nbd0 -f qcow2 disk.qcow2
Qemu.nbd_connect("/dev/nbd0", "disk.qcow2", { format = "qcow2" }):run()
```

### `Qemu.nbd_disconnect(dev, opts)`

```lua
-- qemu-nbd -d /dev/nbd0
Qemu.nbd_disconnect("/dev/nbd0"):run()
```

### `Qemu.nbd_serve(image, opts)`

Runs `qemu-nbd` in server mode (TCP or Unix socket), with options like:

- `port`, `bind`, `socket`
- `read_only`, `shared`, `persistent`, `fork`, `pid_file`
- `export_name`, `description`
- `object`, `tls_creds`, `tls_authz`, `tls_hostname`
- `image_opts` + `filename` as a block-driver options string

### `Qemu.nbd_list(opts)`

Connects as a client and lists exports (`-L`).


### NBD options (`QemuNbdOpts`)

The wrapper maps a large portion of `qemu-nbd` flags into `opts` (plus `opts.extra`). Highlights:

- Listening / endpoints: `port (-p)`, `bind (-b)`, `socket (-k)`
- Image selection: `format (-f)`, `offset (-o)`, `image_opts (--image-opts)`
- Access & behavior: `read_only (-r)`, `shared (-e)`, `persistent (-t)`, `fork (--fork)`, `pid_file (--pid-file)`
- Snapshots: `snapshot (-s)`, `load_snapshot (-l)`
- IO tuning: `cache`, `nocache (-n)`, `aio`, `discard`, `detect_zeroes`, `allocation_depth (-A)`, `bitmap (-B)`
- TLS: `object (--object ...)`, `tls_creds`, `tls_hostname`, `tls_authz`
- Metadata/debug: `export_name (-x)`, `description (-D)`, `handshake_limit`, `verbose (-v)`, `trace (-T ...)`

#### Example: serve via TCP

```lua
Qemu.nbd_serve("disk.qcow2", {
  format = "qcow2",
  bind = "127.0.0.1",
  port = 10809,
  export_name = "disk0",
  persistent = true,
}):run()
```

#### Example: list exports

```lua
Qemu.nbd_list({ bind = "127.0.0.1", port = 10809 }):run()
```

## QEMU Storage Daemon (`qemu-storage-daemon`)

### `Qemu.storage_daemon(opts)`

Constructs a `qemu-storage-daemon` invocation.

Common options:

- `chardev`, `monitor`
- `object`
- `blockdev`
- `nbd_server`
- `export`
- `pidfile`, `daemonize`
- `extra`

### Storage daemon options (`QemuStorageDaemonOpts`)

- `chardev`: `--chardev <spec>` (repeatable; string or table via `qemu.chardev`)
- `monitor`: `--monitor <spec>` (repeatable)
- `object`: `--object <spec>` (repeatable; string or table via `qemu.object`)
- `blockdev`: `--blockdev <spec>` (repeatable; each item encoded as a comma-list)
- `nbd_server`: `--nbd-server <spec>` (repeatable; comma-list)
- `export`: `--export <spec>` (repeatable; comma-list)
- `pidfile`: `--pidfile=<path>`
- `daemonize`: `--daemonize`
- `extra`: appended verbatim

### Example: NBD export via QSD

```lua
Qemu.storage_daemon({
  blockdev = {
    { driver = "file", filename = "disk.qcow2", node_name = "file0" },
    { driver = "qcow2", file = "file0", node_name = "img0" },
  },
  nbd_server = {
    { addr = { type = "inet", host = "127.0.0.1", port = "10809" } },
  },
  export = {
    { type = "nbd", id = "exp0", node_name = "img0", name = "disk0", writable = true },
  },
}):run()
```
