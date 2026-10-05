# frozen_string_literal: true
require_relative 'cases'
if ARGV == ['--payload']
  File.write(File.join(NxH18b::DIR, 'payload_po.json'), JSON.pretty_generate(NxH18b.payloads) + "\n")
else
  %w[zapis_pred nakup_pred guarded_pred].each do |name|
    path = File.join(NxH18b::DIR, name + '.json')
    raise "PRED uz existuje: #{path}" if File.exist?(path)
    value = { 'zapis_pred' => -> { NxH18b.packed }, 'nakup_pred' => -> { NxH18b.purchases }, 'guarded_pred' => -> { NxH18b.hashes } }.fetch(name).call
    File.write(path, JSON.generate(value) + "\n")
  end
end
