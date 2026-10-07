---Pick which OpenCode session this Neovim instance drives.
local M = {}

---Humanize a millisecond timestamp as a relative age.
---@param ms integer?
---@return string
local function ago(ms)
  if not ms then
    return ""
  end
  local secs = math.max(0, math.floor((vim.uv.now() - ms) / 1000))
  if secs < 60 then
    return secs .. "s ago"
  elseif secs < 3600 then
    return math.floor(secs / 60) .. "m ago"
  elseif secs < 86400 then
    return math.floor(secs / 3600) .. "h ago"
  end
  return math.floor(secs / 86400) .. "d ago"
end

---@class opencode.session.Opts : snacks.picker.ui_select.Opts
---@field prompt? string Prompt to display.

---List the live root sessions for Neovim's directory and pick one.
---Archived sessions are excluded. Rejects on cancellation or when no live session exists.
---
---@param server opencode.server.Server
---@param opts? opencode.session.Opts
---@return Promise<opencode.server.Session>
function M.pick(server, opts)
  local Promise = require("opencode.promise")
  return server:get_sessions():next(function(sessions)
    local items = {}
    for _, session in ipairs(sessions) do
      if not (session.time and session.time.archived) then
        table.insert(items, {
          __session = session,
          name = session.title or session.id,
          text = session.time and ago(session.time.updated) or "",
        })
      end
    end

    if #items == 0 then
      return Promise.reject("No OpenCode session found for `" .. vim.fn.getcwd() .. "`. Start one in the TUI.")
    end

    ---@type snacks.picker.ui_select.Opts
    local select_opts = {
      prompt = opts and opts.prompt or "OpenCode session: ",
      ---@param item { name: string, text: string }
      format_item = function(item)
        return ("%s  %s"):format(item.name, item.text)
      end,
    }
    if opts then
      select_opts = vim.tbl_deep_extend("force", select_opts, opts)
    end

    return require("opencode.promise.ui").select(items, select_opts):next(function(choice)
      return choice.__session
    end)
  end)
end

return M
