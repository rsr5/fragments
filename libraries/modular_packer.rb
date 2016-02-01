require_relative 'machine'
require_relative 'fragment'

include Fragments::Packers

# Represents an action that may be performed on a list of virtual machines in
# order to sort and filter them.
class Filter
  # All the filter instances will be sorted by their precedence before being
  # applied
  @precedence = 0
  attr_reader :precedence

  # The current selection of filters
  @filters = []

  # Returns the list of filter classes sorted by precedence
  def self.filters
    @filters.sort_by { |f| -f.precedence }
  end

  def self.register(filter)
    @filters << filter
  end

  def self.filter(_memory, _machines)
    fail 'It is intended that this class should be inherited from.'
  end
end

# Sorts the current set of virtual machines by their current memory used
# in reverse order
class MemoryUsed < Filter
  def self.precedence
    10
  end

  def self.filter(_memory, machines)
    machines.sort_by(&:memory_used)
  end
end

Filter.register(MemoryUsed)

# Filter the current set of virtual machines based on whether there is
# enough memory free for the fragment
class MemorySuitable < Filter
  def self.precedence
    5
  end

  def self.filter(fragment, machines)
    machines.select do |machine|
      (machine.memory_used + fragment.memory_weight) <= machine.memory
    end
  end
end

Filter.register(MemorySuitable)

# Filter out machines that have any of the tags the fragment needs to avoid
class AvoidTags < Filter
  def self.precedence
    10
  end

  def self.filter(fragment, machines)
    machines.select do |machine|
      avoid_machine_tags = machine.tags.disjoint?(fragment.avoid_tags.to_set)
      avoid_fragment_tags = machine
                            .fragments
                            .map(&:avoid_tags)
                            .flatten
                            .to_set
                            .disjoint?(fragment.tags.to_set)
      avoid_machine_tags && avoid_fragment_tags
    end
  end
end

Filter.register(AvoidTags)

# Filter out machines that have tags other than those in only_group_with_tags
class OnlyGroupWithTags < Filter
  def self.precedence
    10
  end

  def self.filter(fragment, machines)
    machines.select do |machine|
      empty = machine.only_group_with_tags.empty? && fragment.only_group_with_tags.empty?
      equal = machine.only_group_with_tags == fragment.only_group_with_tags.to_set
      empty || equal
    end
  end
end

Filter.register(OnlyGroupWithTags)

# Sort the list of virtual machines with the machines that are tagged with
# requested tags first.  If there are no machines with the tags required then
# a machine without the tags may be chosen.
class GroupWithTags < Filter
  def self.precedence
    10
  end

  def self.filter(fragment, machines)
    machines.sort_by do |machine|
      # Cannot sort by boolean in ruby, so cast to 1 or 0
      !machine.tags.disjoint?(fragment.group_with_tags.to_set) ? 0 : 1
    end
  end
end

Filter.register(GroupWithTags)

# Filters out all of the machines that do not have the correct flavor for
# the fragment
class AssignToFlavor < Filter
  def self.precedence
    10
  end

  def self.filter(fragment, machines)
    machines.select do |machine|
      machine.flavor_id == fragment.flavor_id
    end
  end
end

Filter.register(AssignToFlavor)

# Filters machines that already contain the fragment when placing fragments
# with a cardinality greater than 1
class AvoidSameFragment < Filter
  def self.precedence
    10
  end

  def self.filter(fragment, machines)
    machines.select do |machine|
      !machine.fragments.map(&:name).include?(fragment.name)
    end
  end
end

Filter.register(AvoidSameFragment)

# Filters the list of virtual machine to those that have the correct
# environment for the fragment
class ChooseEnvironment < Filter
  def self.precedence
    10
  end

  def self.filter(fragment, machines)
    machines.select do |machine|
      machine.environment == fragment.environment
    end
  end
end

Filter.register(ChooseEnvironment)

# A packer that is configurable by way of sorters and filters
class ModularPacker < MachinePacker
  include DebugModularPackerMixin

  def initialize
    # Used to number the virtual machines as they are created
    @counter = 0
    super
  end

  # Packs all of the fragments that have a cardinality less than the
  # final number of nodes
  def pack_not_every_node(fragments)
    # Place fragments that have tags before those that do not
    fragments.each do |fragment|
      fragment.cardinality.times do |count|
        beginning_to_pack_fragment(fragment, count)
        place_fragment(fragment)
        add_fragments([fragment])
      end
    end
  end

  private

  # Find a list of virtual machines (if any) that would be suitable for the
  # fragment
  def filter_machines(fragment)
    local_machines = machines
    Filter.filters.each do |filter|
      next if local_machines.length == 0
      local_machines = applied_filter(
        fragment, filter, filter.filter(fragment, local_machines)
      )
    end
    local_machines
  end

  # Either create a new virtual machine or place the fragment in an existing
  # one
  def place_fragment(fragment)
    local_machines = filter_machines(fragment)

    if local_machines.size == 0
      @machines << created_machine(Machine.from_fragment(@counter, fragment))
      @counter += 1
    else
      machine = local_machines[0]
      machine.append_fragment(fragment)
      placed_fragment(machine)
    end
  end
end

MachinePacker.register('modular', ModularPacker)
