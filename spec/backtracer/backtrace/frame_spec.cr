require "../../spec_helper"

private def parse_frame(line)
  Backtracer::Backtrace::Frame::Parser.parse(line)
end

private def with_frame(method, path = nil, lineno = nil, column = nil)
  line = String.build do |io|
    if path
      io << path
      io << ':' << lineno if lineno
      io << ':' << column if column
      io << " in '" << method << '\''
    else
      io << method
    end
  end
  yield parse_frame(line)
end

private def with_foo_frame(
  method = "foo_bar?",
  path = "#{__DIR__}/foo.cr",
  lineno = 1,
  column = 7
)
  with_frame(method, path, lineno, column) do |frame|
    yield frame
  end
end

describe Backtracer::Backtrace::Frame do
  describe ".parse" do
    it "fails to parse an empty string" do
      expect_raises(ArgumentError) { parse_frame("") }
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

    context "with ~proc signature" do
      it "parses absolute path outside of src/ dir" do
        backtrace_line = "~proc2Proc(Fiber, (IO::FileDescriptor | Nil))@/usr/local/Cellar/crystal/0.27.2/src/fiber.cr:72"

        with_frame(backtrace_line) do |frame|
          frame.lineno.should eq(72)
          frame.column.should be_nil
          frame.method.should eq("~proc2Proc(Fiber, (IO::FileDescriptor | Nil))")
          frame.path.should eq("/usr/local/Cellar/crystal/0.27.2/src/fiber.cr")
          frame.relative_path.should be_nil
          frame.under_src_path?.should be_false
          frame.shard_name.should be_nil
          frame.in_app?.should be_false
        end
      end

      it "parses relative path inside of lib/ dir" do
        backtrace_line = "~procProc(HTTP::Server::Context, String)@lib/kemal/src/kemal/route.cr:11"

        with_frame(backtrace_line) do |frame|
          frame.lineno.should eq(11)
          frame.column.should be_nil
          frame.method.should eq("~procProc(HTTP::Server::Context, String)")
          frame.path.should eq("lib/kemal/src/kemal/route.cr")
          frame.relative_path.should eq("lib/kemal/src/kemal/route.cr")
          frame.under_src_path?.should be_false
          frame.shard_name.should eq("kemal")
          frame.in_app?.should be_false
        end
      end
    end

    it "parses absolute path outside of configuration.src_path" do
      path = "/some/absolute/path/to/foo.cr"

      with_foo_frame(path: path) do |frame|
        frame.lineno.should eq(1)
        frame.column.should eq(7)
        frame.method.should eq("foo_bar?")
        frame.path.should eq(path)
        frame.relative_path.should be_nil
        frame.under_src_path?.should be_false
        frame.shard_name.should be_nil
        frame.in_app?.should be_false
      end
    end

    context "with in_app? = false" do
      it "parses absolute path outside of src/ dir" do
        with_foo_frame do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq("#{__DIR__}/foo.cr")
          frame.relative_path.should eq("spec/backtracer/backtrace/foo.cr")
          frame.under_src_path?.should be_true
          frame.shard_name.should be_nil
          frame.in_app?.should be_false
        end
      end

      it "parses relative path outside of src/ dir" do
        path = "some/relative/path/to/foo.cr"

        with_foo_frame(path: path) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(path)
          frame.relative_path.should eq(path)
          frame.under_src_path?.should be_false
          frame.shard_name.should be_nil
          frame.in_app?.should be_false
        end
      end
    end

    context "with in_app? = true" do
      it "parses absolute path inside of src/ dir" do
        src_path = File.expand_path("../../../src", __DIR__)
        path = "#{src_path}/foo.cr"

        with_foo_frame(path: path) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(path)
          frame.relative_path.should eq("src/foo.cr")
          frame.under_src_path?.should be_true
          frame.shard_name.should be_nil
          frame.in_app?.should be_true
        end
      end

      it "parses relative path inside of src/ dir" do
        path = "src/foo.cr"

        with_foo_frame(path: path) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(path)
          frame.relative_path.should eq(path)
          frame.under_src_path?.should be_false
          frame.shard_name.should be_nil
          frame.in_app?.should be_true
        end
      end
    end

    context "with shard path" do
      it "parses absolute path inside of lib/ dir" do
        lib_path = File.expand_path("../../../lib/bar", __DIR__)
        path = "#{lib_path}/src/bar.cr"

        with_foo_frame(path: path) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(path)
          frame.relative_path.should eq("lib/bar/src/bar.cr")
          frame.under_src_path?.should be_true
          frame.shard_name.should eq "bar"
          frame.in_app?.should be_false
        end
      end

      it "parses relative path inside of lib/ dir" do
        path = "lib/bar/src/bar.cr"

        with_foo_frame(path: path) do |frame|
          frame.lineno.should eq(1)
          frame.column.should eq(7)
          frame.method.should eq("foo_bar?")
          frame.path.should eq(path)
          frame.relative_path.should eq(path)
          frame.under_src_path?.should be_false
          frame.shard_name.should eq "bar"
          frame.in_app?.should be_false
        end
      end

      it "uses only folders for shard names" do
        with_foo_frame(path: "lib/bar.cr") do |frame|
          frame.shard_name.should be_nil
        end
      end
    end
  end

  it "#inspect" do
    with_foo_frame do |frame|
      frame.inspect.should match(/Backtrace::Frame(.*)$/)
    end
  end

  it "#to_s" do
    with_foo_frame do |frame|
      frame.to_s.should eq "`foo_bar?` at #{__DIR__}/foo.cr:1:7"
    end
  end

  it "#==" do
    with_foo_frame do |frame|
      with_foo_frame do |frame2|
        frame.should eq(frame2)
      end
      with_foo_frame(method: "other_method") do |frame2|
        frame.should_not eq(frame2)
      end
    end
  end
end
