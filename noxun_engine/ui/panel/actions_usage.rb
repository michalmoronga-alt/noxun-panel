# frozen_string_literal: true
# Noxun Engine - Panel: D-25 merac pouzivania panela (callback usage_flush).
# Cast modulu Panel (reopen) - zdiela ivary cez class << self.
#
# Merac je NEVIDITELNY: handler ma vlastny begin/rescue LEN s logom a NIKDY
# nevola set_status — cb() wrapper by pri vynimke napisal chybu do stavoveho
# riadku panela, ale chyba meraca nesmie pouzivatela rusit pri praci.
# Payload z usage.js: {"counts": {"kluc_prvku": n, ...}} — ziadne hodnoty poli.
module Noxun
  module Engine
    module Panel
      class << self
        def handle_usage_flush(payload)
          data = JSON.parse(payload.to_s)
          counts = data.is_a?(Hash) ? data['counts'] : nil
          UsageStats.record(counts)
        rescue StandardError => e
          # Aj pad LOGERA musi ostat ticho — inak by vynimka usla do cb wrappera
          # a ten by zavolal set_status (Codex audit D-25). Dvojite zlyhanie uz
          # nemame kam hlasit; vedomy tichy rescue LEN tu.
          begin
            Engine.log_error(e, 'handle_usage_flush')
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
