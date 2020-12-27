module Backtracer
  # Handles backtrace parsing line by line
  struct Backtrace::Line
    # The method of the line (such as `User.find`).
    getter method : String

    # The file portion of the line (such as `app/models/user.cr`).
    getter file : String?

    # The line number portion of the line.
    getter number : Int32?

    # The column number portion of the line.
    getter column : Int32?

    protected getter(configuration) { Backtracer.configuration }

    def initialize(@method, @file = nil, @number = nil, @column = nil, *,
                   @configuration = nil)
    end

    def_equals_and_hash @method, @file, @number, @column

    # Reconstructs the line in a readable fashion
    def to_s(io : IO) : Nil
      io << '`' << @method << '`'
      if @file
        io << " at " << @file
        io << ':' << @number if @number
        io << ':' << @column if @column
      end
    end

    def inspect(io : IO) : Nil
      io << "Backtrace::Line("
      to_s(io)
      io << ')'
    end

    def under_src_path? : Bool
      return false unless src_path = configuration.src_path
      !!file.try(&.starts_with?(src_path))
    end

    def relative_path : String?
      return unless path = file
      return path unless path.starts_with?('/')
      return unless under_src_path?
      if prefix = configuration.src_path
        path[prefix.chomp(File::SEPARATOR).size + 1..]
      end
    end

    def absolute_path : String?
      return unless path = file
      return path if path.starts_with?('/')
      if prefix = configuration.src_path
        File.join(prefix, path)
      end
    end

    def shard_name : String?
      relative_path
        .try(&.match(configuration.modules_path_pattern))
        .try(&.["name"])
    end

    def in_app? : Bool
      !!(file.try(&.matches?(configuration.in_app_pattern)))
    end

    def context(context_lines : Int32? = nil) : {Array(String), String, Array(String)}?
      context_lines ||= configuration.context_lines

      return unless context_lines && (context_lines > 0)
      return unless (lineno = @number) && (lineno > 0)
      return unless (filename = @file) && File.readable?(filename)

      lines = File.read_lines(filename)
      lineidx = lineno - 1

      if context_line = lines[lineidx]?
        pre_context = lines[Math.max(0, lineidx - context_lines), context_lines]
        post_context = lines[Math.min(lines.size, lineidx + 1), context_lines]
        {pre_context, context_line, post_context}
      end
    end

    def context_hash(context_lines : Int32? = nil) : Hash(Int32, String)?
      return unless context = self.context(context_lines)
      return unless lineno = self.number

      pre_context, context_line, post_context = context

      ({} of Int32 => String).tap do |hash|
        pre_context.each_with_index do |code, index|
          line = (lineno - pre_context.size) + index
          hash[line] = code
        end

        hash[lineno] = context_line

        post_context.each_with_index do |code, index|
          line = lineno + (index + 1)
          hash[line] = code
        end
      end
    end
  end
end
