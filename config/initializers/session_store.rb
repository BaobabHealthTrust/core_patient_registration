# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_core_patient_registration_session',
  :secret      => '72d34d4cdd1828a038c558b3d5c745e88a91542d25583d385dc2a469ebe3c3367b3151e94fce124ac79328212652ae3ac2cc72f8fa26823a943049491fdde811'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
