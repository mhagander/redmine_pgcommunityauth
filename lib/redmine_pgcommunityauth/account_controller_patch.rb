require 'base64'
require "rbnacl"

module RedminePgcommunityauth
  module AccountControllerPatch
    unloadable

    class AuthTokenExpiredError < RuntimeError; end
    class InvalidAuthTokenError < RuntimeError; end

    def login
      url = pgcommunityauth_login_url

      back_url = params[:back_url]
      if back_url.present?
        url += "?d=" + encrypt_login_data(back_url)
      end

      redirect_to url
    end

    def logout
      logout_user
      redirect_to pgcommunityauth_logout_url
    end

    # GET /pgcommunityauth
    def pgcommunityauth
      if params[:s] == 'logout'
        flash[:notice] = "Successfully logged out from PG community sites."
        return
      end

      nonce   = Base64.urlsafe_decode64(params[:n] || "")
      data = Base64.urlsafe_decode64(params[:d] || "")
      tag = Base64.urlsafe_decode64(params[:t] || "")

      qs = do_decrypt(pgcommunityauth_cipher_key, nonce, data, tag).rstrip
      auth = Rack::Utils.parse_query(qs)

      # check auth hash for mandatory keys
      raise InvalidAuthTokenError.new unless %w(t u f l e).all?{ |x| auth.keys.include?(x) }

      # check auth token timestamp: issued 10 seconds ago or less
      raise AuthTokenExpiredError.new unless Time.now.to_i <= auth['t'].to_i + 10

      user = User.find_by_login(auth['u']) || User.new
      user.login = auth['u']
      user.firstname = auth['f']
      user.lastname = auth['l']
      user.mail = auth['e']
      user.save!

      login_data = auth['d']
      if login_data.present?
        decoded_qs = decrypt_login_data(login_data)
        decoded_data = Rack::Utils.parse_query(decoded_qs)
        params[:back_url] = decoded_data['r']
      else
        params[:back_url] = pgcommunityauth_settings['default_url']
      end

      successful_authentication(user)
    rescue RbNaCl::LengthError
      flash[:error] = "Invalid PG communityauth message nonce received."
    rescue RbNaCl::CryptoError
      flash[:error] = "Invalid PG communityauth message received."
    rescue InvalidAuthTokenError
      flash[:error] = "Invalid PG communityauth token received."
    rescue AuthTokenExpiredError
      flash[:error] = "PG community auth token expired."
    end

    private

    def pgcommunityauth_settings
      Setting['plugin_redmine_pgcommunityauth']
    end

    def pgcommunityauth_base_url
      "#{pgcommunityauth_settings['base_url']}account/auth/#{pgcommunityauth_settings['authsite_id']}"
    end

    def pgcommunityauth_login_url
      "#{pgcommunityauth_base_url}/"
    end

    def pgcommunityauth_logout_url
      "#{pgcommunityauth_base_url}/logout/"
    end

    def pgcommunityauth_cipher_key
      Base64.decode64(pgcommunityauth_settings['cipher_key'])
    end

    def get_cipher(key)
      RbNaCl::AEAD::XChaCha20Poly1305IETF.new(key)
    end

    def do_encrypt(key, iv, data)
      cipher = get_cipher(key)
      cipher.encrypt(iv, data, '')
    end

    def do_decrypt(key, nonce, data, tag)
      cipher = get_cipher(key)
      cipher.decrypt(nonce, data + tag, '')
    end

    def login_data_cipher_key
      # TODO: haven't found a away to use the Rails' secret key base or token
      pgcommunityauth_cipher_key
    end

    def encrypt_login_data(back_url)
      iv = RbNaCl::Random.random_bytes(24)

      data = "r=#{CGI.escape(back_url)}"
      cipher = do_encrypt(login_data_cipher_key, iv, data)

      "#{Base64.urlsafe_encode64(iv)}$#{Base64.urlsafe_encode64(cipher)}"
    end

    def decrypt_login_data(data)
      parts  = data.split('$')
      iv     = Base64.urlsafe_decode64(parts[0])
      cipher = Base64.urlsafe_decode64(parts[1])

      do_decrypt(login_data_cipher_key, iv, cipher, '').rstrip
    end
  end
end

# use prepend to override existing methods:
AccountController.send(:prepend, RedminePgcommunityauth::AccountControllerPatch)
