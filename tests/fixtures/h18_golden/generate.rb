# frozen_string_literal: true
# Rucny generator. Predzmenove odtlacky smie vytvorit LEN na pripnutom maine;
# po implementacii prepise iba payload_po.json (--after), nikdy stare goldeny.
require_relative 'cases'

if ARGV == ['--after']
  abort 'predzmenove goldeny chybaju' unless File.file?(File.join(__dir__, 'source_pred.json'))
  File.write(File.join(__dir__, 'payload_po.json'), NxH18.matrix_json(NxH18.cases.to_h { |c| [c['id'], NxH18.payload(c)] }))
else
  abort 'ocakavane --after alebo ziadny argument' unless ARGV.empty?
  abort 'generator PRED smie bezat len nad starym kodom' if NxH18::HS.respond_to?(:resolve_mapping_source)
  head = IO.popen(%w[git rev-parse HEAD], &:read).strip
  abort "ocakavany main #{NxH18::BEFORE}, dostal #{head}" unless head == NxH18::BEFORE
  abort 'goldeny PRED uz existuju; neregenerovat' if File.exist?(File.join(__dir__, 'source_pred.json'))
  cases = NxH18.cases
  { 'resolver' => cases.to_h { |c| [c['id'], NxH18.resolver(c)] },
    'source_pred' => cases.to_h { |c| [c['id'], NxH18.sources(c)] },
    'payload_pred' => cases.to_h { |c| [c['id'], NxH18.payload(c)] },
    'cena_zavesy' => NxH18.prices }.each do |name, value|
    File.write(File.join(__dir__, name + '.json'), name == 'cena_zavesy' ? NxH18.json(value) : NxH18.matrix_json(value))
  end
  puts "H18 PRED: #{cases.length} pripadov, #{cases.sum { |c| c['items'].length }} poloziek, HEAD #{head}"
end
