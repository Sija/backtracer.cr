require "../spec_helper"

private def with_configuration
  yield Backtracer::Configuration.new
end

describe Backtracer::Configuration do
  it "should set #src_path to current dir from default" do
    with_configuration do |configuration|
      configuration.src_path.should eq(Dir.current)
    end
  end
end
