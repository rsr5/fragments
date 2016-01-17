
module Fragments
  # Extra DSL methods needed for the machine fragment code
  module DSL
    # Create a hash of all the machines information
    def info_hash(state) # rubocop:disable Metrics/MethodLength
      machines = Hash[Fragments::Packers::MachinePacker
                      .get
                      .machines
                      .map do |current_machine|
        [current_machine.name,
         { state: state }.merge(
           Fragments::Drivers::Driver.get.machine_info(current_machine)
         )]
      end]
      {
        'machines' => machines,
        'basename' => basename,
        'packer' => packer,
        'driver' => driver
      }
    end

    # Create a file resource for the current state of all the virtual machines
    def machine_info_resource(state)
      # Write the info hash to a file
      file chef_root('machine_info.json') do
        content lazy { info_hash(state).to_json }
      end
    end

    # Shortens accessing node attributes forh this cookbook
    def nodeattr
      node['fragments']
    end

    def basename
      node.run_state['fragments']['cluster']['name']
    end

    # Returns the driver that is being used.
    def driver
      node.run_state['fragments']['cluster']['driver']
    end

    # Returns the name of the current packing algorithm
    def packer_name
      node.run_state['fragments']['cluster']['packer']
    end

    # Reserved for later use.  Returns the environment that should be used
    # for the nodes.
    def chef_environment
      '_default'
    end
  end
end
