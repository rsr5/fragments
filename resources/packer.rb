resource_name :packer

# May be used with the deploy action to converge a set of virtual machines
property :machines, Array, default: []

action :pack do
  chef_data_bag 'fragments'

  converge_by(
    "Packed #{::Chef.node.run_state['fragments']['cluster']['fragments'].size}"\
    " fragments with '#{MachinePacker.get.class.name}'") do
    MachinePacker.get.pack
  end

  converge_by("Verified #{MachinePacker.get.fragments.size} fragments") do
    MachinePacker.get.verify_dependencies
  end

  packer = MachinePacker.get
  packer_spec = packer.machines.map(&:to_hash)
  converge_by "Storing #{packer.machines.size} machine definitions" do
    packer_spec = {
      machines: packer.machines.map(&:to_hash),
      fragments: packer.fragments.map(&:to_hash)
    }

    chef_data_bag_item 'spec' do
      data_bag 'fragments'
      raw_data packer_spec
    end

    ::File.open(chef_root('dependencies.dot'), 'w') do |f|
      f.write(packer.dependency_graph_dot)
    end
  end

  machine_state 'Not Created'
end

action :from_spec_file do
  converge_by 'Loaded spec from data bag' do
    MachinePacker.from_spec
    Driver.get.pre_verify(MachinePacker.get)
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

    ::File.delete(chef_root('../Berksfile-Remote-Machines.lock'))
  end
end

action :provision do
  require 'chef/provisioning'

  # Setup all of the virtual machines but do not converge yet in order that
  # the Chef search index is ready.  Each hostnames is gatherede in the
  # hostnames variable above and then used to converge the nodes in a second
  # machine_batch below
  machine_batch 'setup' do
    MachinePacker.get.machines.each do |current_machine|
      machine current_machine.name  do
        # Add the machine options specific to the driver
        add_machine_options Driver.get.machine_options(current_machine)

        # The Chef environment of the machine
        chef_environment current_machine.environment

        # Used below to identify the nodes that are being converged
        tag node.run_state['fragments']['cluster']['name']

        # Add the roles
        current_machine.roles.each do |role|
          role role
        end

        # Add the recipes
        current_machine.recipes.each do |recipe|
          recipe recipe
        end

        # Add all of the attributes for each of the fragments
        current_machine.fragments.each do |fragment|
          fragment.attributes.each do |k, v|
            attribute k, v
          end
        end

        # Set the fqdn for the machine
        attribute 'fqdn', [current_machine.name, Driver.get.domain].join('.')
        attribute 'hostname', current_machine.name
        attribute 'host_aliases', lazy {
          current_machine
            .host_aliases
            .select { |a| a != current_machine.name }
            .map { |a| [a, Driver.get.domain].join('.') }
        }

        # Do not converge the virtual machine yet
        converge false
      end
    end
    action :setup
  end

  ruby_block 'set extra driver attributes on the node object' do
    block do
      MachinePacker.get.machines.each do |current_machine|
        attrs = Driver.get.extra_attributes(current_machine)
        next if attrs.empty?
        node = search(:node, "name:#{current_machine.name}")[0]
        attrs.each do |key, value|
          node.normal[key] = value
        end
        node.save
      end
    end
  end

  # Transfer all of the relevant files to the virtual machine and create the
  # directory for the Chef log.
  MachinePacker.get.machines.each do |current_machine|
    current_machine.fragments.each do |fragment|
      fragment.machine_files.each do |local_path, remote_path|
        machine_file remote_path do
          machine current_machine.name
          local_path local_path
        end
      end
    end
    machine_execute "#{current_machine.name} create Chef log directory" do
      machine current_machine.name
      command 'sudo mkdir -p /var/log/chef/'
    end
  end

  machine_state 'Created'
end

action :converge do
  machines = MachinePacker.get.machines
  unless new_resource.machines.empty?
    machines = machines.select do |current_machine|
      new_resource.machines.include?(current_machine.name)
    end
  end

  machine_batch 'converge' do
    machines machines.map(&:name)
    action :converge_only
  end

  # Execute all of the post converge commands
  machines.each do |current_machine|
    current_machine.fragments.each do |fragment|
      fragment.machine_commands.each do |description, command|
        machine_execute description do
          machine current_machine.name
          command command
        end
      end
    end
  end

  machine_state 'Converged'
end

action :destroy do
  ::Chef::Recipe.send(:extend, Fragments::Drivers)

  # Initialize the driver
  Driver.get

  # Nodes to destroy
  nodes = search(:node,
                 "tags:#{node.run_state['fragments']['cluster']['name']}")

  # Destroy all of the virtual machines that are tagged with the basename
  # for this configuration
  machine_batch do
    machines nodes.map(&:name)
    action :destroy
  end
end
