# frozen_string_literal: true
# CENY-M2 — GENERATOR ODTLACKU „golden pred M2" (zlaty test B, sklo bez formatu).
#
# PRECO: M2 (C12) meni cenu materialu bez platneho formatu, ktoreho typ nie je
# v registri typov (sklo) — z fiktivnej platne 2800 × 2070 na skutocne m²
# dielcov. Test `tests/pure/test_ceny_m2_golden.rb` porovna cerstvy vypocet
# s tymto odtlackom a dovoli rozdiel LEN na vymenovanych cestach (riadky SK4
# a NOP, medzisucet Materialu, totals, zaokruhlenie, nahlad ponuky, bunky XLSX
# a blok `stale`) s PRESNYMI cislami z package.
#
# Odtlacok vznikol RAZ nad mainom po CENY-M1b (41d97e73, v0.16.2) PRED prvou
# zmenou kodu M2 — samostatny commit „golden pred M2". Znova sa NEgeneruje
# (test ho nevola — inak by charakterizacia „dokazovala" samu seba).
#   C:/Ruby32-x64/bin/ruby.exe tests/fixtures/ceny_m2_golden/generate_pre.rb
require_relative '../../helper'
require_relative 'fixture'

snap = NxCenyM2Golden.roundtrip(NxCenyM2Golden.snapshot)
File.write(File.join(NxCenyM2Golden::DIR, 'pre_glass.json'), JSON.pretty_generate(snap) + "\n")
puts "OK: pre_glass.json v #{NxCenyM2Golden::DIR}"
