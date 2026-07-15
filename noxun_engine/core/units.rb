# frozen_string_literal: true
# Noxun Engine — units. JEDINE miesto prevodu mm(Float) <-> Length v celom plugine.
# Vsetky NOXUN data su mm Float; .mm sa pouziva LEN tu, na hranici kreslenia.
module Noxun
  module Engine
    module Units
      MM_PER_INCH = 25.4

      # mm Float -> SketchUp Length (interne v palcoch).
      def self.mm(v)
        v.to_f.mm
      end

      # SketchUp Length (alebo cislo v palcoch) -> mm Float.
      # Length dedi z Float a interne drzi palce, preto *25.4.
      def self.to_mm(len)
        len.to_f * MM_PER_INCH
      end

      # Point3d z mm suradnic.
      def self.point(x_mm, y_mm, z_mm)
        Geom::Point3d.new(mm(x_mm), mm(y_mm), mm(z_mm))
      end

      # Vector3d z mm zloziek.
      def self.vector(x_mm, y_mm, z_mm)
        Geom::Vector3d.new(mm(x_mm), mm(y_mm), mm(z_mm))
      end
    end
  end
end
