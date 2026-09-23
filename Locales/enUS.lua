local _, ns = ...

-- Identity locale: L["text"] returns "text". Other locales write into this same table.
ns.L = setmetatable({}, {
  __index = function(_, key) return key end,
})
