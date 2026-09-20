local _, ns = ...

-- enUS is the identity locale: L["Some text"] returns "Some text".
-- Other locales assign translations into this same table.
ns.L = setmetatable({}, {
  __index = function(_, key) return key end,
})
