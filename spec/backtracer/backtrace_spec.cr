require "../spec_helper"

describe Backtracer::Backtrace do
  backtrace = Backtracer.parse(caller)

  it "#lines" do
    backtrace.lines.should be_a(Array(Backtracer::Backtrace::Line))
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
    backtrace2 = Backtracer::Backtrace.new(backtrace.lines)
    backtrace2.should eq(backtrace)
  end
end
