module Backtracer
  # An object representation of a stack frame.
  struct Backtrace::Frame
    # The method of this frame (such as `User.find`).
    getter method : String

    # The file name of this frame (such as `app/models/user.cr`).
    getter path : String?

    # The line number of this frame.
    getter lineno : Int32?

    # The column number of this frame.
    getter column : Int32?

    protected getter(configuration) { Backtracer.configuration }

    def initialize(@method, @path = nil, @lineno = nil, @column = nil, *,
                   @configuration = nil)
    end

    def_equals_and_hash @method, @path, @lineno, @column

    # Reconstructs the frame in a readable fashion.
    def to_s(io : IO) : Nil
      io << '`' << @method << '`'
      if @path
        io << " at " << @path
        io << ':' << @lineno if @lineno
        io << ':' << @column if @column
      end
    end

    def inspect(io : IO) : Nil
      io << "Backtrace::Frame("
      to_s(io)
      io << ')'
    end

    # Returns `true` if `path` of this frame is within
    # the `configuration.src_path`, `false` otherwise.
    #
    # See `Configuration#src_path`
    def under_src_path? : Bool
      return false unless src_path = configuration.src_path
      !!path.try(&.starts_with?(src_path))
    end

    # Returns:
    #
    # - `path` as is, unless it's absolute - i.e. starts with `/`
    # - `path` relative to `configuration.src_path` when `under_src_path?` is `true`
    # - `nil` otherwise
    #
    # NOTE: returned path is not required to be `under_src_path?` - see point no. 1
    #
    # See `Configuration#src_path`
    def relative_path : String?
      return unless path = @path
      return path unless path.starts_with?('/')
      return unless under_src_path?
      if prefix = configuration.src_path
        path[prefix.chomp(File::SEPARATOR).size + 1..]
      end
    end

    # Returns:
    #
    # - `path` as is, if it's absolute - i.e. starts with `/`
    # - `path` appended to `configuration.src_path`
    # - `nil` otherwise
    #
    # See `Configuration#src_path`
    def absolute_path : String?
      return unless path = @path
      return path if path.starts_with?('/')
      if prefix = configuration.src_path
        File.join(prefix, path)
      end
    end

    # Returns name of the shard from which this frame originated.
    #
    # See `Configuration#modules_path_pattern`
    def shard_name : String?
      relative_path
        .try(&.match(configuration.modules_path_pattern))
        .try(&.["name"])
    end

    # Returns `true` if this frame originated from the app source code,
    # `false` otherwise.
    #
    # See `Configuration#in_app_pattern`
    def in_app? : Bool
      !!(path.try(&.matches?(configuration.in_app_pattern)))
    end

    # Returns a tuple consisting of 3 elements - an array of context lines
    # before the `lineno`, line at `lineno`, and an array of context lines
    # after the `lineno`. In case of failure it returns `nil`.
    #
    # Amount of returned context lines is taken from the *context_lines*
    # argument if given, or `configuration.context_lines` otherwise.
    #
    # See `Configuration#context_lines`
    def context(context_lines : Int32? = nil) : {Array(String), String, Array(String)}?
      context_lines ||= configuration.context_lines

      return unless context_lines && (context_lines > 0)
      return unless (lineno = @lineno) && (lineno > 0)
      return unless (path = @path) && File.readable?(path)

      lines = File.read_lines(path)
      lineidx = lineno - 1

      if context_line = lines[lineidx]?
        pre_context = lines[Math.max(0, lineidx - context_lines), context_lines]
        post_context = lines[Math.min(lines.size, lineidx + 1), context_lines]
        {pre_context, context_line, post_context}
      end
    end

    # Returns hash with context lines, where line numbers are keys and
    # the lines itself are values. In case of failure it returns `nil`.
    #
    # Amount of returned context lines is taken from the *context_lines*
    # argument if given, or `configuration.context_lines` otherwise.
    #
    # See `Configuration#context`, `Configuration#context_lines`
    def context_hash(context_lines : Int32? = nil) : Hash(Int32, String)?
      return unless context = self.context(context_lines)
      return unless lineno = @lineno

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
