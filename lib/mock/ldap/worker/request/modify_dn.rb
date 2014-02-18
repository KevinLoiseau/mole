require 'openssl'

require 'mock/ldap/worker/error'
require 'mock/ldap/worker/tag'
require 'mock/ldap/worker/request/abst_request'

module Mock
  module Ldap
    module Worker
      module Request
        extend Mock::Ldap::Worker::Tag
        extend Mock::Ldap::Worker::Error

        class ModifyDn < AbstRequest
          def initialize(*args)
            @protocol = :ModifyDNRequest
            super
          end
        end

      end
    end
  end
end
