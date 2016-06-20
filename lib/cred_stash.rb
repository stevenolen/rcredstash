require 'aws-sdk'

module CredStash
  class << self
    def get(name)
      item = Repository.new.get(name)
      data = Base64.decode64(item.key)
      contents = Base64.decode64(item.contents)

      key = CipherKey.decrypt(data)

      unless OpenSSL::HMAC.hexdigest("sha256", key.hmac_key, contents) == material["hmac"]
        raise "invalid"
      end

      Cipher.new(key.data_key).decrypte(contents)
    end

    def put(name, value)
      key = CipherKey.generate

      contents = Cipher.new(key.data_key).encrypt(value)

      hmac = OpenSSL::HMAC.hexdigest("sha256", key.hmac_key, contents)

      version = get_highest_version(name) + 1

      item = Repository::Item.new(
        name: name,
        version: "%019d" % version,
        key: Base64.encode64(key.wrapped_key),
        contents: Base64.encode64(contents),
        hmac: hmac
      )
      Repository.new.put(item)
    end

    def list
      Repository.new.list.inject({}) {|h, item| h[item.name] = item.version; h }
    end

    def delete(name)
      # TODO needs delete target version option
      repository = Repository.new
      item = repository.select(name).first
      repository.delete(item)
    end

    private

    def get_highest_version(name)
      item = Repository.new.select(name, pluck: 'version', limit: 1).first
      if item
        item.version.to_i
      else
        0
      end
    end
  end
end

require 'cred_stash/cipher_key'
require 'cred_stash/cipher'
require 'cred_stash/error'
require 'cred_stash/repository'
