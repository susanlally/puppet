module Puppet::Pops
module Lookup
# @api private
module DataProvider
  def self.key_type
    @key_type
  end

  def self.value_type
    @value_type
  end

  def self.register_types(loader)
    (@key_type, @value_type) = Pcore::register_aliases({
      # The Pcore type for all keys and subkeys in a data hash.
      'Puppet::LookupKey' => 'Variant[String,Numeric]',

      # The Pcore type for all values and sub-values in a data hash. The
      # type is self-recursive to enforce the same constraint on values contained
      # in arrays and hashes
      'Puppet::LookupValue' => <<-PUPPET
        Variant[
          Scalar,
          Undef,
          Sensitive,
          Type,
          Hash[Puppet::LookupKey, Puppet::LookupValue],
          Array[Puppet::LookupValue]
        ]
        PUPPET
    }, Pcore::RUNTIME_NAME_AUTHORITY, loader)
  end

  # Performs a lookup with an endless recursion check.
  #
  # @param key [LookupKey] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String=>Object},nil] Merge strategy or hash with strategy and options
  #
  def key_lookup(key, lookup_invocation, merge)
    lookup_invocation.check(key.to_s) { unchecked_key_lookup(key, lookup_invocation, merge) }
  end

  def lookup(key, lookup_invocation, merge)
    lookup_invocation.check(key.to_s) { unchecked_key_lookup(key, lookup_invocation, merge) }
  end

  # Performs a lookup with the assumption that a recursive check has been made.
  #
  # @param key [LookupKey] The key to lookup
  # @param lookup_invocation [Invocation] The current lookup invocation
  # @param merge [MergeStrategy,String,Hash{String => Object},nil] Merge strategy, merge strategy name, strategy and options hash, or nil (implies "first found")
  # @return [Object] the found object
  # @throw :no_such_key when the object is not found
  def unchecked_key_lookup(key, lookup_invocation, merge)
    raise NotImplementedError, "Subclass of #{DataProvider.name} must implement 'unchecked_lookup' method"
  end

  # @return [String,nil] the name of the module that this provider belongs to nor `nil` if it doesn't belong to a module
  def module_name
    nil
  end

  # @return [String] the name of the this data provider
  def name
    raise NotImplementedError, "Subclass of #{DataProvider.name} must implement 'name' method"
  end

  # @returns `true` if the value provided by this instance can always be trusted, `false` otherwise
  def value_is_validated?
    false
  end

  # Asserts that _data_hash_ is a hash. Will yield to obtain origin of value in case an error is produced
  #
  # @param data_hash [Hash{String=>Object}] The data hash
  # @return [Hash{String=>Object}] The data hash
  def validate_data_hash(data_hash, &block)
    Types::TypeAsserter.assert_instance_of(nil, Types::PHashType::DEFAULT, data_hash, &block)
  end

  # Asserts that _data_value_ is of valid type. Will yield to obtain origin of value in case an error is produced
  #
  # @param data_provider [DataProvider] The data provider that produced the hash
  # @return [Object] The data value
  def validate_data_value(value, &block)
    # The DataProvider.value_type is self recursive so further recursive check of collections is needed here
    unless value_is_validated? || DataProvider.value_type.instance?(value)
      actual_type = Types::TypeCalculator.singleton.infer(value)
      raise Types::TypeAssertionError.new("#{yield} has wrong type, expects Puppet::LookupValue, got #{actual_type}", DataProvider.value_type, actual_type)
    end
    value
  end
end
end
end
