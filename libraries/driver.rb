module Fragments
  # Modules that contains all of the Chef Provisioning drivers
  module Drivers
    # Contains the driver setup code for Chef Provisioning
    class Driver
      # Hash containing all of the driver classes that have been loaded
      @drivers = {}

      # The driver that is being used for the current Chef run
      @driver = nil

      def name
        'base driver class'
      end

      # Registers a driver class.
      def self.register(name, driver)
        @drivers[name] = driver
      end

      # Gets the instance of the current driver
      def self.get
        unless @driver
          driver = ::Chef.node.run_state['fragments']['cluster']['driver']
          fail "Unknown driver - #{driver}" unless @drivers.key?(driver)
          @driver = @drivers[driver].new
        end
        @driver
      end

      def initialize
        @node = ::Chef.node
        @chef_provisioning = @node.run_context.chef_provisioning
        @current_chef_server = @node.run_context.cheffish.current_chef_server
        configure
      end

      def machine_options(machine)
        extra_machine_options(machine).merge(
          convergence_options: {
            chef_version: '12.4.1',
            chef_config: "log_location '/var/log/chef_client.log'\n"
          }
        )
      end

      # Returns the domain name that should be used for FQDNs
      def domain
        ::Chef.node.run_state['fragments']['cluster']['domain_name']
      end

      # Returns the command used to SSH to a virtual machine
      def ssh_command(machine)
        "ssh #{ipaddr(machine)} #{ssh_options(machine)}"
      end

      def fqdn(machine)
        [machine.name, domain].join('.')
      end

      # Returns a hash containing relevant information for a virtual machine
      def machine_info(machine)
        {
          name: machine.name,
          driver: name,
          fqdn: fqdn(machine),
          ipaddr: ipaddr(machine),
          ssh_command: ssh_command(machine),
          host_aliases: machine.host_aliases
        }
      end

      # Override the below methods when writing a driver class

      # Extra options that should be used when creating virtual machines
      def extra_machine_options(_machine)
        {}
      end

      def configure
        fail 'Do not use the Driver class directly, it is intended that it '\
             'should inherited from.'
      end

      # Returns the ip address associated with a virtual machine
      def ipaddr(_machine)
        fail 'Do not use the Driver class directly, it is intended that it '\
             'should be inherited from.'
      end

      # Returns the options that should be run in order to ssh to a virtual
      # machine
      def ssh_options(_machine)
        fail 'Do not use the Driver class directly, it is intended that it '\
             'should be inherited from.'
      end

      # If the driver needs to verify anything before creating virtual machines
      # then override this method.  For instance, checking for hostname
      # collisions.
      def pre_verify(_packer)
      end
    end
  end
end
