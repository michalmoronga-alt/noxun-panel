# frozen_string_literal: true
# Novy display oracle predrecenzie: vyhradne stara pripnuta retaz a vstupy.
# Post payload sa generuje osobitne --after; povodne R0 goldeny sa nedotknu.
require_relative 'blocked_cases'
out = File.join(__dir__, 'blocked_pred.json')
abort 'blocked oracle uz existuje; neregenerovat' if File.exist?(out)
File.write(out, NxH18.matrix_json((NxH18.cases + NxH18Blocked.cases).to_h { |c| [c['id'], NxH18Blocked.truth(c)] }))
