
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
    machines.sort_by { |m| -m.memory_used }
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
      machine.tags.disjoint?(fragment.avoid_tags.to_set)
    end
  end
end

Filter.register(AvoidTags)

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

# A packer that is configurable by way of sorters and filters
class ModularPacker < MachinePacker
  def initialize
    # Used to number the virtual machines as they are created
    @counter = 0
    super
  end

  def _place_fragment(fragment)
    local_machines = machines
    Filter.filters.each do |filter|
      local_machines = filter.filter(fragment, local_machines)
    end

    if local_machines.size == 0
      @machines << Machine.from_fragment(@counter, fragment)
      @counter += 1
    else
      local_machines[0].append_fragment(fragment)
    end
  end

  # Packs all of the fragments that have a cardinality less than the
  # final number of nodes
  def pack_not_every_node(fragments)
    # Place fragments that have tags before those that do not
    fragments.sort_by(&:tags).reverse_each do |fragment|
      fragment.cardinality.times do |_|
        _place_fragment(fragment)
        add_fragments([fragment])
      end
    end
  end
end

MachinePacker.register('modular', ModularPacker)
