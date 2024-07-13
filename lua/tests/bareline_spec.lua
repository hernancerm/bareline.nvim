---@diagnostic disable: undefined-global

-- PlenaryBustedDirectory ./lua/tests/ { init = "mini" }

describe("bareline", function()

  before_each(function()
    vim.o.columns = 100
  end)

  it("bare preset shows active statusline", function()
    assert.equals("bello Brian", vim.wo.statusline)
  end)
end)
