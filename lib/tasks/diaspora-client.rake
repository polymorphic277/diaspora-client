namespace :diaspora do

  desc 'Generates a set of 2048 keys'
  task :generate_keys do
    priv_key = OpenSSL::PKey::RSA.generate(2048)
    app_name = Rails.application.class.parent_name
    priv_path = File.join(Rails.root, "config", "#{app_name}.private.pem")
    pub_path = File.join(Rails.root, "config", "#{app_name}.public.pem")

    puts "writing private key to: " + priv_path
    priv_f = File.new(priv_path, "w")
    priv_f.write(priv_key.export)
    priv_f.close

    puts "writing public key to: " + pub_path
    pub_f = File.new(pub_path, "w")
    pub_f.write(priv_key.public_key.export)
    pub_f.close
  end

  desc 'Packages a JWT-signed manifest from client configuration'
  task :package_manifest => :environment do
    manifest_path = File.join(Rails.root, "public", "manifest.json")

    puts "writing manifest to: " + manifest_path
    man_f = File.new(manifest_path, "w")
    man_f.write(DiasporaClient.package_manifest)
    man_f.close
  end

end
