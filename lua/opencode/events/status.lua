local M = {}

---@type "idle" | "busy" | "error" | nil
local status = nil
---@type string?
M.url = nil

---The length of the pinned session title shown in the statusline.
local PIN_TITLE_MAX_WIDTH = 30

---@return string
function M.statusline()
  local url = (M.url and (" " .. M.url:gsub("^%w+://", "")) or "")

  -- When a session is pinned, show it — prompts route to exactly that session.
  local pinned = require("opencode.server").pinned
  local pin = ""
  if pinned then
    local title = (pinned.title and pinned.title ~= "" and pinned.title) or pinned.id
    if vim.fn.strwidth(title) > PIN_TITLE_MAX_WIDTH then
      title = vim.fn.strcharpart(title, 0, PIN_TITLE_MAX_WIDTH - 3) .. "..."
    end
    pin = " 󰌾 " .. title
  end

  return M.icon() .. url .. pin
end

---Force a statusline refresh; used when the pinned session changes.
function M.refresh()
  vim.schedule(function()
    vim.cmd("redrawstatus")
  end)
end

---@return "󰚩" | "󱜙" | "󱚡" | "󱚧"
function M.icon()
  if status == "idle" then
    return "󰚩"
  elseif status == "busy" then
    return "󱜙"
  elseif status == "error" then
    return "󱚡"
  else
    return "󱚧"
  end
end

---@param event opencode.server.Event
---@param url string
function M.update(event, url)
  M.url = url

  if event.type == "server.connected" then
    status = "idle"
  elseif event.type == "session.status" then
    local kind = event.data and event.data.status and event.data.status.type
    if kind == "idle" then
      status = "idle"
    elseif kind == "busy" or kind == "retry" then
      status = "busy"
    end
  elseif event.type == "session.execution.failed" then
    status = "error"
  elseif event.type == "global.disposed" or event.type == "server.instance.disposed" then
    M.reset()
  end
end

function M.reset()
  status = nil
  M.url = nil
end

return M
