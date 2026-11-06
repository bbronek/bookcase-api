Rails.application.config.filter_parameters += [
  :passw, :email, :full_name, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
