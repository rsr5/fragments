resource_name :packer

action :pack do
  converge_by(
    "Packed #{::Chef.node.run_state['fragments']['cluster']['fragments'].size}"\
    " fragments with '#{MachinePacker.get.class.name}'") do
    MachinePacker.get.pack
  end
end

action :verify do
  converge_by("Verified #{MachinePacker.get.fragments.size} fragments") do
    MachinePacker.get.verify_dependencies
  end
end

action :berkshelf_vendor do
  require 'berkshelf'

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
