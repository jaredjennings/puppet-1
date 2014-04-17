require 'puppet/util/checksums'

# This setting type handles a list of digest algorithms. Any
# algorithms that don't work are expunged from the list. (On FIPS
# 140-2 compliant hosts, this happens to MD5.)
#
# Values should match the regex "algorithm(\s?,\s?algorithm)*",
# i.e. any number of algorithms separated by commas and optional
# whitespace. Valid algorithms are named below.
class Puppet::Settings::DigestAlgorithmsSetting < Puppet::Settings::BaseSetting
  include Puppet::Util::Checksums

  # These must be a subset of
  # Puppet::Util::Checksums.known_checksum_types.
  VALID_DIGEST_ALGORITHMS = [:md5, :sha1, :sha256]

  def type
    :digest_algorithms
  end

  def munge value
    algo_symbols = value.split(',').collect(&:strip).collect(&:intern)
    invalids = algo_symbols - VALID_DIGEST_ALGORITHMS
    raise(Puppet::Settings::ValidationError, 
          "Unknown digest algorithm(s): #{invalids.join(' ')}") if invalids.any?
    algo_symbols.select! do |algo|
      begin
        method(algo).call "test digest string"
        true
      rescue
        warn "Digest algorithm #{algo.to_s} fails; not using it"
        false
      end
    end
    raise(Puppet::Settings::ValidationError,
          "No workable digest algorithms") if algo_symbols.none?
    algo_symbols
  end
end
