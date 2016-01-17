require 'berkshelf'

resource_name :berkshelf

action :create do
  converge_by 'Reticulating Splines' do
    berksfile = ::Berkshelf::Berksfile.new(
      chef_root('../Berksfile-Remote-Machines')
    )
    ::Berkshelf::ProvisioningFormatter.provider(self)
    ::Berkshelf.set_format('provisioning')

    berksfile.source node.run_state['fragments']['cluster']['supermarket_url']

    Fragments::Packers::Berkshelf.new(
      MachinePacker.get
    ).cookbooks.each do |name, options|
      # Make sure all the keys are symbols
      berks_options = Hash[options.clone.map { |k, v| [k.to_sym, v] }]
      if berks_options.key? 'version'
        berksfile.cookbook(name, berks_options['version'], berks_options)
      else
        berksfile.cookbook(name, berks_options)
      end
    end

    berksfile.install
    berksfile.upload(server_url: ::Chef::Config.chef_server_url)
  end
end
