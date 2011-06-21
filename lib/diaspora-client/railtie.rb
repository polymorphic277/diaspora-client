require 'diaspora-client'
require 'rails'
module DiasporaClient
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join( File.join( File.dirname(__FILE__) , "..","..", "lib","tasks","diaspora-client.rake" ) )
    end
  end
end
