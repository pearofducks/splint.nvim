describe('linter.vale', function()
  it("doesn't error on empty output", function()
    local parser = require('splint.linters.vale').parser
    parser('')
    parser('  ')
  end)
end)

