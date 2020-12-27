module Backtracer
  module Backtrace::Line::Parser
    extend self

    # Parses a single line of a given backtrace, where *unparsed_line* is
    # the raw line from `caller` or some backtrace.
    #
    # Returns the parsed backtrace line on success or `nil` otherwise.
    def parse?(line : String, **options) : Backtrace::Line?
      return unless Configuration::LINE_PATTERNS.any? &.match(line)

      method = $~["method"]?.presence
      file = $~["file"]?.presence
      number = $~["line"]?.try(&.to_i?)
      column = $~["col"]?.try(&.to_i?)

      return unless method

      Backtrace::Line.new method, file, number, column,
        configuration: options[:configuration]?
    end

    def parse(line : String, **options) : Backtrace::Line
      parse?(line, **options) ||
        raise ArgumentError.new("Error parsing line: #{line.inspect}")
    end
  end
end
