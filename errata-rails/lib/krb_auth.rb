module KrbAuth
  require 'rubygems'
  require 'krb5_auth'
  include Krb5Auth

  def self.get_user(trace = lambda { |msg| $stderr.puts(msg)} )
    user = nil
    begin
      krb = Krb5.new
      princ = krb.get_default_principal
      login_name = princ.downcase
      user = User.find_by_login_name(login_name)
    rescue Krb5::Exception => e
      trace.call("Error getting kerberos credentials: #{e.to_s}")
      return nil
    end

    unless user
      trace.call("#{login_name} not found in errata system. You do not appear to be a valid errata system user.")
    end
    return user
  end
end
