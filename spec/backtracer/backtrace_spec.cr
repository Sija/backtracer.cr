require "../spec_helper"

describe Backtracer::Backtrace do
  backtrace = Backtracer.parse(caller)

  it "#frames" do
    backtrace.frames.should be_a(Array(Backtracer::Backtrace::Frame))
  end

  it "#inspect" do
    backtrace.inspect.should match(/#<Backtrace: .*>$/)
  end

  {% unless flag?(:release) || !flag?(:debug) %}
    it "#to_s" do
      backtrace.to_s.should match(/backtrace_spec.cr:4/)
    end
  {% end %}

  it "#==" do
    backtrace2 = Backtracer::Backtrace.new(backtrace.frames)
    backtrace2.should eq(backtrace)
  end
end
