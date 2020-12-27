module Backtracer
  class Backtrace
    getter lines : Array(Line)

    def initialize(@lines = [] of Line)
    end

    def_equals_and_hash @lines

    def to_s(io : IO) : Nil
      @lines.join(io, '\n')
    end

    def inspect(io : IO) : Nil
      io << "#<Backtrace: "
      @lines.join(io, ", ", &.inspect(io))
      io << '>'
    end
  end
end

require "./backtrace/*"
