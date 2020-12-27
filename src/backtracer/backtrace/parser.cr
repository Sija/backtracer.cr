module Backtracer
  module Backtrace::Parser
    extend self

    def parse(backtrace : Array(String), **options) : Backtrace
      configuration = options[:configuration]? || Backtracer.configuration

      filters = configuration.line_filters
      if extra_filters = options[:filters]?
        filters += extra_filters
      end

      lines = backtrace.compact_map do |line|
        line = filters.reduce(line) do |nested_line, filter|
          filter.call(nested_line) || break
        end
        Line::Parser.parse(line, configuration: configuration) if line
      end

      Backtrace.new(lines)
    end

    def parse(backtrace : String, **options) : Backtrace
      parse(backtrace.lines, **options)
    end
  end
end
