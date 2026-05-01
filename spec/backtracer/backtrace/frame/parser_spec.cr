require "../../../spec_helper"

private BACKTRACE_LINE_EXAMPLES = {
  "[0x489d6c] *Crystal::main<Int32, Pointer(Pointer(UInt8))>:Int32 +156": {
    method: "Crystal::main<Int32, Pointer(Pointer(UInt8))>:Int32",
  },
  "/usr/lib/libc.so.6 in '??'": {
    path:   Path.posix("/usr/lib/libc.so.6"),
    method: "??",
  },
  "/usr/lib/crystal/crystal/main.cr:115:7 in 'main'": {
    path:   Path.posix("/usr/lib/crystal/crystal/main.cr"),
    method: "main",
    lineno: 115,
    column: 7,
  },
  "/usr/local/Cellar/crystal-lang/0.24.1/src/fiber.cr:114:3 in '*Fiber#run:(IO::FileDescriptor | Nil)'": {
    path:   Path.posix("/usr/local/Cellar/crystal-lang/0.24.1/src/fiber.cr"),
    method: "Fiber#run:(IO::FileDescriptor | Nil)",
    lineno: 114,
    column: 3,
  },
  "../../../../../crystal/src/crystal/main.cr:105:5 in 'main'": {
    path:          Path.posix("../../../../../crystal/src/crystal/main.cr"),
    relative_path: Path.posix("../../../../../crystal/src/crystal/main.cr"),
    method:        "main",
    lineno:        105,
    column:        5,
  },
  "Crystal::CodeGenVisitor#visit<Crystal::Assign>:(Bool | Nil)": {
    method: "Crystal::CodeGenVisitor#visit<Crystal::Assign>:(Bool | Nil)",
  },
  %q(WINDOWS\SYSTEM32\ntdll.dll +314513 in 'RtlUserThreadStart'): {
    path:          Path.windows(%q(WINDOWS\SYSTEM32\ntdll.dll)),
    relative_path: Path.windows(%q(WINDOWS\SYSTEM32\ntdll.dll)),
    method:        "RtlUserThreadStart",
  },
  %q(D:\a\crystal\crystal\src\compiler\crystal.cr:11 in '__crystal_main'): {
    path:   Path.windows(%q(D:\a\crystal\crystal\src\compiler\crystal.cr)),
    method: "__crystal_main",
    lineno: 11,
  },
}

describe Backtracer::Backtrace::Frame::Parser do
  describe ".parse" do
    it "fails to parse an empty string" do
      expect_raises(ArgumentError) { with_frame("", &.itself) }
    end

    context "when --no-debug flag is set" do
      it "parses frame with any value as method" do
        backtrace_line = "__crystal_main"

        with_frame(backtrace_line) do |frame|
          frame.lineno.should be_nil
          frame.column.should be_nil
          frame.method.should eq(backtrace_line)
          frame.path.should be_nil
          frame.relative_path.should be_nil
          frame.under_src_path?.should be_false
          frame.shard_name.should be_nil
          frame.in_app?.should be_false
        end
      end
    end

    it "parses valid backtrace line format examples" do
      BACKTRACE_LINE_EXAMPLES.each do |backtrace_line, expected|
        with_frame(backtrace_line) do |frame|
          frame.lineno.should eq(expected[:lineno]?)
          frame.column.should eq(expected[:column]?)
          frame.method.should eq(expected[:method]?)
          frame.path.should eq(expected[:path]?)
          frame.relative_path.should eq(expected[:relative_path]?)
          frame.shard_name.should eq(expected[:shard_name]?)
          frame.in_app?.should eq(expected[:in_app]? || false)
        end
      end
    end

    context "with ~proc signature" do
      it "parses absolute path outside of src/ dir" do
        path = Path[Dir.current, "..", "some", "path", "to", "foo.cr"].expand
        backtrace_line = "~proc2Proc(Fiber, (IO::FileDescriptor | Nil))@#{path}:72"

        with_frame(backtrace_line) do |frame|
          frame.lineno.should eq(72)
          frame.column.should be_nil
          frame.method.should eq("~proc2Proc(Fiber, (IO::FileDescriptor | Nil))")
          frame.path.should eq(path)
          frame.absolute_path.should eq(frame.path)
          frame.relative_path.should be_nil
          frame.under_src_path?.should be_false
          frame.shard_name.should be_nil
          frame.in_app?.should be_false
        end
      end

      it "parses relative path inside of lib/ dir" do
        with_configuration do |configuration|
          path = Path["lib", "kemal", "src", "kemal", "route.cr"]
          backtrace_line = "~procProc(HTTP::Server::Context, String)@#{path}:11"

          with_frame(backtrace_line) do |frame|
            frame.lineno.should eq(11)
            frame.column.should be_nil
            frame.method.should eq("~procProc(HTTP::Server::Context, String)")
            frame.path.should eq(path)
            frame.absolute_path.should eq(Path[configuration.src_path.not_nil!, path])
            frame.relative_path.should eq(frame.path)
            frame.under_src_path?.should be_false
            frame.shard_name.should eq("kemal")
            frame.in_app?.should be_false
          end
        end
      end
    end

    it "parses absolute path outside of configuration.src_path" do
      path = Path[Dir.current, "..", "some", "path", "to", "foo.cr"].expand

      with_foo_frame(path: path) do |frame|
        frame.lineno.should eq(1)
        frame.column.should eq(7)
        frame.method.should eq("foo_bar?")
        frame.path.should eq(path)
        frame.absolute_path.should eq(frame.path)
        frame.relative_path.should be_nil
        frame.under_src_path?.should be_false
        frame.shard_name.should be_nil
        frame.in_app?.should be_false
      end
    end

    context "with in_app? = false" do
      it "parses absolute path outside of src/ dir" do
        with_foo_frame(path: Path[__DIR__, "foo.cr"]) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(Path[__DIR__, "foo.cr"])
          frame.absolute_path.should eq(frame.path)
          frame.relative_path.should eq(Path[__DIR__].relative_to(Dir.current).join("foo.cr"))
          frame.under_src_path?.should be_true
          frame.shard_name.should be_nil
          frame.in_app?.should be_false
        end
      end

      it "parses relative path outside of src/ dir" do
        with_configuration do |configuration|
          path = Path["some", "relative", "path", "to", "foo.cr"]

          with_foo_frame(path: path) do |frame|
            frame.lineno.should eq(1)
            frame.column.should eq(7)
            frame.method.should eq("foo_bar?")
            frame.path.should eq(path)
            frame.absolute_path.should eq(Path[configuration.src_path.not_nil!, path])
            frame.relative_path.should eq(frame.path)
            frame.under_src_path?.should be_false
            frame.shard_name.should be_nil
            frame.in_app?.should be_false
          end
        end
      end
    end

    context "with in_app? = true" do
      it "parses absolute path inside of src/ dir" do
        src_path = File.expand_path("../../../../src", __DIR__)
        path = Path[src_path, "foo.cr"]

        with_foo_frame(path: path) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(path)
          frame.absolute_path.should eq(frame.path)
          frame.relative_path.should eq(Path[path].relative_to(Dir.current))
          frame.under_src_path?.should be_true
          frame.shard_name.should be_nil
          frame.in_app?.should be_true
        end
      end

      it "parses relative path inside of src/ dir" do
        with_configuration do |configuration|
          path = Path["src", "foo.cr"]

          with_foo_frame(path: path) do |frame|
            frame.lineno.should eq(1)
            frame.column.should eq(7)
            frame.method.should eq("foo_bar?")
            frame.path.should eq(path)
            frame.absolute_path.should eq(Path[configuration.src_path.not_nil!, path])
            frame.relative_path.should eq(path)
            frame.under_src_path?.should be_false
            frame.shard_name.should be_nil
            frame.in_app?.should be_true
          end
        end
      end
    end

    context "with shard path" do
      it "parses absolute path inside of lib/ dir" do
        lib_path = File.expand_path("../../../../lib/bar", __DIR__)
        path = Path[lib_path, "src", "bar.cr"]

        with_foo_frame(path: path) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(path)
          frame.absolute_path.should eq(frame.path)
          frame.relative_path.should eq(Path[path].relative_to(Dir.current))
          frame.under_src_path?.should be_true
          frame.shard_name.should eq "bar"
          frame.in_app?.should be_false
        end
      end

      it "parses relative path inside of lib/ dir" do
        with_configuration do |configuration|
          path = Path["lib", "bar", "src", "bar.cr"]

          with_foo_frame(path: path) do |frame|
            frame.lineno.should eq(1)
            frame.column.should eq(7)
            frame.method.should eq("foo_bar?")
            frame.path.should eq(path)
            frame.absolute_path.should eq(Path[configuration.src_path.not_nil!, path])
            frame.relative_path.should eq(path)
            frame.under_src_path?.should be_false
            frame.shard_name.should eq "bar"
            frame.in_app?.should be_false
          end
        end
      end

      it "uses only folders for shard names" do
        with_foo_frame(path: Path["lib", "bar.cr"]) do |frame|
          frame.shard_name.should be_nil
        end
      end
    end
  end
end
