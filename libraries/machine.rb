
require 'set'
require 'chef/provisioning'

# Module that contains a class to represent one virtual machine
class Machine
  # Represents one virtual machine that will eventually be converged.
  attr_accessor :fragments, :memory, :memory_used, :run_list, :suffix, :tags,
                :only_group_with_tags, :flavor_id, :environment, :host_aliases

  def self.flavors
    {
      '1' => ['m1.tiny', 512, 1],
      '2' => ['m1.small', 2048, 1],
      '3' => ['m1.medium', 4096, 2],
      '4' => ['m1.large', 8192, 4],
      '5' => ['m1.xlarge', 16_384, 8]
    }.merge(::Chef.node['fragments']['extra_flavors'])
  end

  # Create a new Machine object from a machine fragment resource. Suffix is
  # string that should be append to the basename to make this machines name
  # unique
  def self.from_fragment(suffix, fragment) # rubocop:disable Metrics/AbcSize
    machine = Machine.new
    machine.fragments = [fragment]
    machine.memory_used = fragment.memory_weight
    machine.run_list = fragment.run_list
    machine.suffix = suffix
    machine.tags = fragment.tags.to_set
    machine.only_group_with_tags = fragment.only_group_with_tags.to_set
    machine.flavor_id = fragment.flavor_id
    machine.environment = fragment.environment
    machine.host_aliases = fragment.host_aliases.to_set
    machine
  end

  def self._fragments_from_hash(fragments)
    fragments.map { |frh| Fragment.from_hash(frh) }
  end

  # Create a Machine object from a hash that was previously created by
  # the to_hash method
  def self.from_hash(hash) # rubocop:disable Metrics/AbcSize
    machine = Machine.new
    machine.fragments = _fragments_from_hash(hash['fragments'])
    machine.memory_used = hash['memory_weight']
    machine.run_list = hash['run_list']
    machine.suffix = hash['suffix']
    machine.tags = hash['tags'].to_set
    machine.only_group_with_tags = hash['only_group_with_tags'].to_set
    machine.flavor_id = hash['flavor_id']
    machine.environment = hash['environment']
    machine.host_aliases = hash['host_aliases'].to_set
    machine
  end

  def initialize
    @node = ::Chef.node
    @chef_provisioning = @node.run_context.chef_provisioning
    @current_chef_server = @node.run_context.cheffish.current_chef_server
  end

  # Return the flavor of the virtual machine
  def flavor
    self.class.flavors[@flavor_id]
  end

  # Returns the amount of memory the VM has assigned
  def memory
    flavor[1]
  end

  # Returns the amount of CPUs the VM has assigned
  def cpus
    flavor[2]
  end

  # The name of the virtual machine
  def name
    [::Chef.node.run_state['fragments']['cluster']['name'], @suffix].join('-')
  end

  # Percentage memory used
  def memory_used_percent
    (memory_used.to_f / memory * 100).to_i
  end

  # Appends the fragment to the end of the run list
  def append_fragment(fragment)
    @fragments << fragment
    @memory_used += fragment.memory_weight
    @tags += fragment.tags.to_set
    @host_aliases += fragment.host_aliases.to_set
    @environment = fragment.environment
    @run_list = (@run_list.to_set + fragment.run_list.to_set).to_a
  end

  # Prepends an array of fragments to the beginning of the run list
  def prepend_fragments(fragments)
    @fragments.unshift(*fragments)

    fragments.each do |fragment|
      @memory_used += fragment.memory_weight
      @tags += fragment.tags.to_set
      @run_list = (fragments.map(&:run_list).flatten.to_set +
                   @run_list.to_set.to_set).to_a
    end
  end

  # Checks if this machine already has a fragment with the same name
  def include?(fragment)
    @fragments.map(&:name).include?(fragment.name)
  end

  # Returns the roles that will be needed by this machine
  def roles
    @run_list.select do |rl|
      rl.start_with?('r_', 'p_', 'base_', 'os_', 'os-')
    end
  end

  # Returns the recipes that will be needed by this machine
  def recipes
    (@run_list.to_set - roles.to_set).to_a
  end

  # Returns the list of host aliases that need to be created for this machine
  def host_aliases
    @fragments.map(&:host_aliases).flatten.uniq + [name]
  end

  # Executes a command on the virtual machine and returns a Result object
  # that may be used to retrieve the output or return code.
  def execute(command, live_stream = false)
    machine = @chef_provisioning.connect_to_machine(name, @current_chef_server)
    machine.execute_always(command, stream: live_stream)
  end

  def to_hash
    {
      memory_used: @memory_used,
      suffix: @suffix,
      tags: @tags.to_a,
      only_group_with_tags: @only_group_with_tags.to_a,
      flavor_id: @flavor_id,
      run_list: @run_list,
      environment: @environment,
      host_aliases: @host_aliases.to_a,
      fragments: @fragments.map(&:to_hash)
    }
  end
end
