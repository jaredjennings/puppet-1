# On some systems, MD5 fails even when not stubbed to do so. So let's
# make SHA1 fail instead: it works on every system the tests could be
# run on, in 2014.
shared_context "when SHA1 fails", :sha1fail => true do
  before :each do
    [:hexdigest, :digest, :file].each do |meth|
      Digest::SHA1.stubs(meth).raises(RuntimeError, "Digest initialization failed.")
    end
  end
end
