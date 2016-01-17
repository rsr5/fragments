
require_relative 'machine'
require_relative 'fragment'

include DataSift::Packers

# A very simple packer that just uses the memory weight of a fragment
# to place it.
class SimplePacker < MachinePacker
  def initialize
    # Used to number the virtual machines as they are created
    @counter = 0
    super
  end

  # Private method that places a fragment in one of the current machines
  # based on the amount of memory that the fragment requires.  The method
  # returns true if the fragment was placed, otherwise false.
  def _place_fragment(fragment)
    placed_fragment = false
    @machines.each do |machine|
      memory_used = machine.memory_used + fragment.memory_weight
      next if machine.include?(fragment) || memory_used > machine.memory
      placed_fragment = true
      machine.append_fragment(fragment)
      add_fragments([fragment])
      break
    end
    placed_fragment
  end

  # Packs all of the fragments that have a cardinality less than the
  # final nubmer of nodes
  def pack_not_every_node(fragments)
    fragments.each do |fragment|
      fragment.cardinality.times do
        next if _place_fragment(fragment)
        @machines << Machine.from_fragment(@counter, fragment)
        add_fragments([fragment])
        @counter += 1
      end
    end
  end
end

MachinePacker.register('simple', SimplePacker)
