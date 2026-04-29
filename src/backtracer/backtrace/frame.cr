module Backtracer
  # An object representation of a stack frame.
  struct Backtrace::Frame
    @context_cache = {} of Int32 => Context

    # The method of this frame (such as `User.find`).
    getter method : String

    # The file name of this frame (such as `app/models/user.cr`).
    getter path : Path?

    # The line number of this frame.
    getter lineno : Int32?

    # The column number of this frame.
    getter column : Int32?

    protected getter(configuration : Configuration) do
      Backtracer.configuration
    end

    def initialize(@method, path : String | Path? = nil, @lineno = nil, @column = nil, *,
                   @configuration = nil)
      @path = path.is_a?(String) ? Path[path] : path
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
      return false unless path = @path
      return false unless src_path = configuration.src_path

      path.to_s.starts_with?(src_path.to_s)
    end

    # Returns:
    #
    # - `path`, unless it's absolute
    # - `path` relative to `configuration.src_path`, when `path` is contained within
    # - `nil` otherwise
    #
    # See `Configuration#src_path`
    def relative_path : Path?
      return unless path = @path
      return path unless path.absolute?
      return unless under_src_path?

      if src_path = configuration.src_path
        path.relative_to?(src_path)
      end
    end

    # Returns:
    #
    # - `path` as is, if it's absolute
    # - `path` appended to `configuration.src_path`
    # - `nil` otherwise
    #
    # See `Configuration#src_path`
    def absolute_path : Path?
      return unless path = @path
      return path if path.absolute?

      if src_path = configuration.src_path
        Path[src_path, path]
      end
    end

    # Returns name of the shard from which this frame originated.
    #
    # See `Configuration#modules_path_pattern`
    def shard_name : String?
      relative_path
        .try(&.to_posix.to_s.match(configuration.modules_path_pattern))
        .try(&.["name"])
    end

    # Returns `true` if this frame originated from the app source code,
    # `false` otherwise.
    #
    # See `Configuration#app_dirs_pattern`
    def in_app? : Bool
      !!(relative_path
        .try(&.to_posix.to_s.matches?(configuration.app_dirs_pattern)))
    end

    # Returns `Context` record consisting of 3 elements - an array of context lines
    # before the `lineno`, line at `lineno`, and an array of context lines
    # after the `lineno`. In case of failure it returns `nil`.
    #
    # Amount of returned context lines is taken from the *context_lines*
    # argument if given, or `configuration.context_lines` otherwise.
    #
    # NOTE: amount of returned context lines might be lower than given
    # in cases where `lineno` is near the start or the end of the file.
    #
    # See `Configuration#context_lines`
    def context(context_lines : Int32? = nil) : Context?
      context_lines ||= configuration.context_lines
      return unless context_lines && (context_lines > 0)

      cached = @context_cache[context_lines]?
      return cached if cached

      return unless (lineno = @lineno) && (lineno > 0)
      return unless (path = @path) && File::Info.readable?(path)

      context_line = nil
      pre_context, post_context = %w[], %w[]

      i = 0
      File.each_line(path) do |line|
        case i += 1
        when lineno - context_lines...lineno
          pre_context << line
        when lineno
          context_line = line
        when lineno + 1..lineno + context_lines
          post_context << line
        end
      end

      if context_line
        @context_cache[context_lines] =
          Context.new(
            lineno: lineno,
            pre: pre_context,
            line: context_line,
            post: post_context,
          )
      end
    end
  end
end
