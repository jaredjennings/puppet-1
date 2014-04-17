shared_context "digest_algorithms" do |value|
  before :each do
    Puppet[:digest_algorithms_algorithms] = value
  end
end
