assert 'it connects and retrieves credentials' do
  session = nil
  reqs = []
  reqs << HTTP::Session::Response.new(200, 'OK', headers: {
    'content-type' => 'application/json'
  }, body:
    '{"credentials":{"accessKeyId":"AKIAIOSFODNN7EXAMPLE","secretAccessKey":'+
    '"wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY","sessionToken":"AQoEXAMPLEH4'+
    'aoAH0gNCAPyJxz4BlCFFxWNE1OPTgk5TthT+FvwqnKwRcOIfrRh3c/LTo6UDdyJwOOvEVPv'+
    'LXCrrrUtdnniCEXAMPLE/IvU1dYUg2RVAJBanLiHb4IgRmpRV3zrkuWJOgQs8IZZaIv2BXI'+
    'a2R4OlgkBN9bkUDNCJiBeb/AXlzBBko7b15fjrBs2+cTQtpZ3CYWFXG8C5zqx37wnOE49mR'+
    'l/+OtkIKGO7fAE","expiration":"2023-07-15T00:25:36Z"}}'
  )
  outstream = HTTP::Session::OutputStream.new
  HTTP::Session.on_new = Proc.new do |sess|
    session = sess
    session.stream = HTTP::Session::Stream.new { reqs.shift }
    session.connection = outstream
  end

  # finally, actually test stuff
  c = AWS::IoT::CredentialProvider.new domain_name: '127.0.0.1',
                                       role_alias: 'role',
                                       thing_name: '12341234',
                                       client_certificate: "cert",
                                       client_private_key: "privkey",
                                       ca_chain: "chain"
  c.refresh!

  # check what was sent
  r = HTTP::Session::Request::Parser.new(outstream).request
  assert_equal 'chain',   session.ssl_options[:ca_chain]
  assert_equal 'cert',    session.ssl_options[:client_cert]
  assert_equal 'privkey', session.ssl_options[:client_key]
  assert_equal :get, r.verb
  assert_equal 'http://127.0.0.1/role-aliases/role/credentials', r.uri.to_s
  assert_equal '127.0.0.1', r['host']
  assert_equal  '12341234', r['x-amzn-iot-thingname']
  assert_equal '', r.body.read

  # check what happened to the result
  assert_equal 'AKIAIOSFODNN7EXAMPLE', c.credentials[:access_key_id]
  assert_equal 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY', c.credentials[:secret_access_key]
  assert_equal 'AQoEXAMPLEH4aoAH0gNCAPyJxz4BlCFFxWNE1OPTgk5TthT+FvwqnKwRcOIf'+
               'rRh3c/LTo6UDdyJwOOvEVPvLXCrrrUtdnniCEXAMPLE/IvU1dYUg2RVAJBan'+
               'LiHb4IgRmpRV3zrkuWJOgQs8IZZaIv2BXIa2R4OlgkBN9bkUDNCJiBeb/AXl'+
               'zBBko7b15fjrBs2+cTQtpZ3CYWFXG8C5zqx37wnOE49mRl/+OtkIKGO7fAE',
               c.credentials[:session_token]
  assert_equal Time.utc(2023, 7, 15, 0, 25, 36, 0),
               c.credentials[:expires_at]
  assert_true c.expired?
end

assert 'it raises any returned error message' do
  session = nil
  reqs = []
  reqs << HTTP::Session::Response.new(200, 'OK', headers: {
    'content-type' => 'application/json'
  }, body:
    '{"message":"Invalid thing name passed"}'
  )
  outstream = HTTP::Session::OutputStream.new
  HTTP::Session.on_new = Proc.new do |sess|
    session = sess
    session.stream = HTTP::Session::Stream.new { reqs.shift }
    session.connection = outstream
  end

  # finally, actually test stuff
  assert_raise_with_message(AWS::IoT::CredentialProvider::Error, "Invalid thing name passed") do
    c = AWS::IoT::CredentialProvider.new domain_name: '127.0.0.1',
                                         role_alias: 'role',
                                         thing_name: '12341234',
                                         client_certificate: "cert",
                                         client_private_key: "privkey",
                                         ca_chain: "chain"
    c.refresh!
  end
end

assert 'it is expired if credentials are nil' do
  c = AWS::IoT::CredentialProvider.new domain_name: '127.0.0.1',
                                       role_alias: 'role',
                                       thing_name: '12341234',
                                       client_certificate: "cert",
                                       client_private_key: "privkey",
                                       ca_chain: "chain"
  assert_true c.expired?
  c.credentials = {} # no expiry info
  assert_true c.expired?
end
