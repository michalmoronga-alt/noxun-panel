# frozen_string_literal: true
# Noxun Engine — loader. LEN registracia SketchupExtension (ziadna logika).
# Jedine miesto s VERSION (drz v synchro s main.rb).
require 'sketchup.rb'
require 'extensions.rb'

module Noxun
  module Engine
    VERSION = '0.1.0'

    class << self
      # Drzime kvoli UI::Notification (potrebuje registrovany extension objekt).
      attr_accessor :extension
    end

    unless defined?(@loaded)
      ex = SketchupExtension.new('Noxun Engine', 'noxun_engine/main')
      ex.description = 'Nabytkarsky system Noxun — parametricky generator korpusov (V0.1 prototyp).'
      ex.version     = VERSION
      ex.creator     = 'Noxun Forge'
      ex.copyright   = 'Noxun Forge © 2026'
      self.extension = ex
      Sketchup.register_extension(ex, true)
      @loaded = true
    end
  end
end
