# Dunst

Examples:

```lua
local Dunst = require("app.dunst").Dunst

-- Show a notification
local cmd1 = Dunst.notify("title", { body = "message" })

-- Complex notification
local cmd2 = Dunst.notify("title", {
    body = "message",
    icon = "/path/to/icon.png", -- or icon_name
    urgency = "low",
    timeout = 1000, -- in ms
    replaceId = 10,
    -- app_name = "...",
    -- hints = "...",
    -- action = "...",
    -- raw_icon = "...",
    -- category = "...",
    -- block = true, -- waits for user response
    -- printId = true, -- print notification id
})

-- Close notification by id
local cmd3 = Dunst.close(10)

-- Dunst capabilities
local cmd4 = Dunst.capabilities()

-- Dunst server info
local cmd5 = Dunst.serverInfo()
```
