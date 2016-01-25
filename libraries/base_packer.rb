require 'pp'

require_relative 'machine'
require_relative 'fragment'

module Fragments
  module Packers
    # Base for packing algorithms
    class MachinePacker
      # Hash containing all of the packer classes that are available
      @packers = {}

      # The packer is currently slected
      @packer = nil

      # Represents a collection of virtual machines.  Takes care of selecting
      # the packing algorithm to use.
      attr_accessor :machines, :fragments

      def initialize
        @machines = []
        @fragments = []
      end

      # Registers a driver class.
      def self.register(name, packer)
        @packers[name] = packer
      end

      # Gets the instance of the current driver
      def self.get
        packer = ::Chef.node.run_state['fragments']['cluster']['packer']
        unless @packer
          fail "Unknown packer - #{packer}" unless @packers.key?(packer)
          @packer = @packers[packer].new
        end
        @packer
      end

      # Creates a Packer object that has previously been packed from a JSON
      # spec file
      def self.from_spec
        packer = MachinePacker.new
        packer_spec = ::Chef::DataBagItem.load('fragments', 'spec').to_hash

        packer.machines = packer_spec['machines'].map do |m|
          Machine.from_hash(m)
        end
        packer.fragments = packer_spec['fragments'].map do |f|
          Fragment.from_hash(f)
        end
        @packer = packer if @packer.nil?
      end

      def add_fragments(extra_fragments)
        @fragments += extra_fragments
      end

      # Builds a dependency graph for the current list of fragments
      def dependency_graph
        Hash[fragments.map { |f| [f.name, f.required_fragments] }]
      end

      # Fails the Chef run with a error because there were missing dependencies
      def _fail_because_missing(missing_frags)
        fail <<-MSG
    You have not specified a valid environment.  The following machine fragments
    require additional dependencies:

    #{PP.pp(missing_frags, '')}
        MSG
      end

      # Verifies that all the required services are available, fails Chef
      # if any required fragments are not available
      def verify_dependencies
        missing_frags = {}
        dependency_graph.each do |fragment, dependencies|
          missing = dependencies.to_set - dependency_graph.keys.to_set
          next unless missing.size > 0
          missing_frags[fragment] = missing.to_a
        end

        _fail_because_missing(missing_frags) if missing_frags.size > 0
      end

      # Packs the fragments that need to be on all nodes, it is assumed that
      # fragments that are intended for all nodes should be at the beginning
      # of the run list.
      def pack_every_node(fragments)
        add_fragments(fragments)

        @machines.each do |machine|
          machine.prepend_fragments(fragments.map do |fragment_resource|
            Fragment.from_resource(fragment_resource)
          end)
        end
      end

      # Packs all of the fragments that have a cardinality less than the
      # final nubmer of nodes
      def pack_not_every_node(_fragments)
        fail 'Override this method in less general packer classes.'
      end

      # Packs the machine fragments into a set of virtual machines.  First
      # the fragments that have a finite cardinality are packed into virtual
      # machines based on how much memory they use.  Then the fragments
      # intended for every node are prepended to the run lists of each
      # virtual machine.
      def pack
        packing_started

        # Seperate the fragments that should be on every node.
        fragment_resources = ::Chef
                             .node
                             .run_state['fragments']['cluster']['fragments']
        fragments = fragment_resources.map { |fr| Fragment.from_resource(fr) }
        groups = { 'every_node' => [],
                   'not_every_node' => []
        }.merge(fragments.group_by do |fragment|
          fragment.every_node == true ? 'every_node' : 'not_every_node'
        end)

        # Pack the fragments in the appropriate way
        pack_not_every_node(groups['not_every_node'])
        pack_every_node(groups['every_node'])

        packing_finished
      end

      # Debugging probe that is called when the packing process begins
      def packing_started
      end

      # Debugging probe that is called when the packing provess is finished
      def packing_finished
      end

      # Debugging probe that may be used by packers.  Called when a filter
      # has been applied to a list of virtual machines.  It is required that
      # the list of machines returned by the filter is also returned here.
      def applied_filter(_fragment, _filter, machines)
        machines
      end

      # Debugging probe that may be used by packers.  Called when a packer
      # calculates that a new virtual machine is required.  It is required that
      # the machine object is returned here.
      def created_machine(machine)
        machine
      end

      # Debugging probe that may be used by packers.  Called just before
      # a fragment is going to be packed
      def beginning_to_pack_fragment(_fragment)
      end

      # Debugging probe that may be used by packers.  Called once a packer
      # has found a suitable machine to place the fragment in.
      def placed_fragment(_machine, _index)
      end

      # Represents the dependency graph as DOT notation used by Graphviz
      def dependency_graph_dot
        # Importing this here as Chef may not have installed the Gem
        require 'graphviz'
        ::GraphViz.new(:G, type: :digraph) do |g|
          dependency_graph.each do |fragment, dependencies|
            g.add_nodes(fragment)

            dependencies.each do |dep|
              g.add_nodes(dep)
              g.add_edges(fragment, dep)
            end
          end
        end.output(dot: String)
      end

      def recipes
        @machines.map(&:recipes).flatten
      end

      def roles
        @machines.map(&:roles).flatten
      end

      # Returns a list of the hostnames that will be required by this set of
      # virtual machines
      def hostnames
        @machines.each_with_index.map do |_, number|
          "#{::Chef.node.run_state['fragments']['cluster']['name']}-#{number}"
        end
      end
    end
  end
end
