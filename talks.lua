-- Shortcodes that render talk data from talks.yml (single source of truth).
--   {{< talk <id> "<time>" >}}   -> card body for the program schedule
--   {{< abstracts >}}            -> full grid for the Titles and Abstracts page

local talks = nil

local function load_talks()
  if talks then return talks end
  local dir = quarto.project.directory or "."
  local f = assert(io.open(dir .. "/talks.yml", "r"), "talks.yml not found")
  local yaml = f:read("a")
  f:close()
  -- Parse the YAML as a pandoc metadata block so strings become markdown.
  local meta = pandoc.read("---\n" .. yaml .. "---\n", "markdown").meta
  talks = {}
  for _, t in ipairs(meta.talks) do
    local entry = {
      id = pandoc.utils.stringify(t.id),
      speaker = pandoc.utils.stringify(t.speaker),
      title = t.title,
      abstract = t.abstract,
    }
    if entry.abstract.t == "MetaInlines" then
      entry.abstract = pandoc.Blocks({ pandoc.Para(entry.abstract) })
    else
      entry.abstract = pandoc.Blocks(entry.abstract)
    end
    table.insert(talks, entry)
    talks[entry.id] = entry
  end
  return talks
end

local function talk(args, kwargs, meta)
  local id = pandoc.utils.stringify(args[1])
  local time = args[2] and pandoc.utils.stringify(args[2]) or ""
  local t = assert(load_talks()[id], "unknown talk id: " .. id)
  local head = pandoc.Inlines({ pandoc.Strong(t.title) })
  if time ~= "" then
    head:insert(pandoc.Span(pandoc.Str(time), { class = "talk-time" }))
    head:insert(pandoc.Span({}, { class = "talk-dot" }))
  end
  head:insert(pandoc.Str(t.speaker))
  return pandoc.Blocks({
    pandoc.Para(head),
    pandoc.Div(t.abstract, { class = "talk-abstract" }),
  })
end

local function abstracts(args, kwargs, meta)
  local cards = pandoc.Blocks({})
  for _, t in ipairs(load_talks()) do
    local id = pandoc.utils.stringify(t.title):lower():gsub("[^%w%s%-_.]", ""):gsub("%s+", "-")
    local body = pandoc.Blocks(t.abstract):clone()
    local label = pandoc.Inlines({ pandoc.Strong("Abstract:"), pandoc.Space() })
    if body[1] and body[1].t == "Para" then
      body[1].content = label .. body[1].content
    else
      body:insert(1, pandoc.Para(label))
    end
    cards:insert(pandoc.Div(pandoc.Blocks({
      pandoc.Header(3, t.title, { id = id }),
      pandoc.Para({ pandoc.Strong("Speaker:"), pandoc.Space(), pandoc.Str(t.speaker) }),
    }) .. body, { class = "abstract-card" }))
  end
  return pandoc.Div(cards, { class = "abstract-grid" })
end

return {
  ["talk"] = talk,
  ["abstracts"] = abstracts,
}
