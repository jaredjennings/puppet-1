require 'rspec/mocks'
module PuppetSpec::MD5Fail
  def stub_md5_to_fail; PuppetSpec::MD5Fail.stub_md5_to_fail end
  class << self
    def stub_md5_to_fail
      [:hexdigest, :digest, :file].each do |meth|
        Digest::MD5.stub(meth) do |arg|
          # Proper behavior here depends on
          # https://bugs.ruby-lang.org/issues/9659. Before this bug is
          # fixed, the actual behavior under FIPS 140-2 compliance is
          # that the Ruby interpreter crashes. This exception-raising
          # behavior is what the patches proposed by Jared Jennings on
          # 28 March 2014 do. Later patches or the final fix may result
          # in different real-world behavior, and this should be changed
          # to match.
          raise RuntimeError, "Digest initialization failed."
        end
      end
    end
  end
end
