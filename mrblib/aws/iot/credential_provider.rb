module AWS
  module IoT
    class CredentialProvider
      class Error < RuntimeError; end
      class MalformedResponse < Error; end

      attr_accessor :credentials

      def initialize(thing_name:,
                     domain_name:,
                     role_alias:,
                     client_certificate:,
                     client_private_key:,
                     ca_chain:)
        @thing_name = thing_name
        @domain_name = domain_name
        @role_alias = role_alias
        @client_certificate = client_certificate
        @client_private_key = client_private_key
        @ca_chain = ca_chain
      end

      def uri
        @uri ||= HTTP::Session::URI.new("https://#{@domain_name}/role-aliases/#{@role_alias}/credentials")
      end

      private def parse_response(response)
        raise MalformedResponse, "HTTP status #{response.status_code}" unless response.status_code = 200
        raise MalformedResponse, "Wrong content type" unless response['Content-type'] == 'application/json'
        parsed = JSON.parse(response.body.read)
        raise Error, parsed['message'] if parsed['message']
        raise MalformedResponse, "Unexpected JSON structure: #{parsed.inspect}" unless parsed['credentials']
        result = {
          access_key_id: parsed['credentials']['accessKeyId'],
          secret_access_key: parsed['credentials']['secretAccessKey'],
          session_token: parsed['credentials']['sessionToken'],
          expiration: parsed['credentials']['expiration']
        }
        raise MalformedResponse, "Missing access key ID" unless result[:access_key_id]
        raise MalformedResponse, "Missing secret access key" unless result[:secret_access_key]
        raise MalformedResponse, "Missing session token" unless result[:session_token]
        raise MalformedResponse, "Missing expiration" unless result[:expiration]
        # 2023-07-15T00:25:36Z
        date, time = *result[:expiration].split('T')
        year, month, day = *date.split('-')
        hour, min, sec = *time.split(':')
        result[:expires_at] = Time.utc(year.to_i, month.to_i, day.to_i,
                                       hour.to_i, min.to_i, sec.to_i, 0)
        result
      end

      # Immediately request new credentials. Ignore whether the current
      # credentials are valid or not.
      #
      # Returns itself on success, or raises an error on failure.
      #
      # Example:
      #
      #    creds.refresh! do |http|
      #      # called when no bytes are available. It's a good time to do
      #      # other things. When this block ends, the refresh will proceed.
      #    end
      #
      def refresh!(timeout_seconds: 60, &block)
        session = HTTP::Session.new uri
        session.when_blocking(&block) if block_given?
        session.read_timeout = timeout_seconds
        session.ssl_options[:ca_chain] = @ca_chain
        session.ssl_options[:client_cert] = @client_certificate
        session.ssl_options[:client_key] = @client_private_key
        response = session.get uri.path do |req|
          req['x-amzn-iot-thingname'] = @thing_name
        end
        @credentials = parse_response response
        session.close
        self
      end

      # Returns true if the credentials are expired.
      def expired?
        return true unless @credentials && @credentials[:expires_at]
        @credentials[:expires_at] < Time.now
      end
    end
  end
end
