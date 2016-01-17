resource_name :datasift_machine_fragment_v1

# The name of the fragment, will be used when other fragments depend on this
# one.
property :name, String, name_property: true

# The list of roles and recipes that the fragment requires
property :run_list, Array, default: []

# Any Node propertys that are reuired by the fragment
property :attributes, Hash, default: {}

# The amount of memory in MB that the fragment requires when assigned to a
# node.  Does not need to be completely accurate but should reflect a general
# guideline for the packing algorithm
property :memory_weight, Integer, default: 0

# A list of other fragment resources that are reuired for this fragment to
# function in an environment.
property :required_fragments, Array, default: []

# The fragment should appear on every node.  Overrides the value in
# cardinality.
property :every_node, [TrueClass, FalseClass], default: false

# The number of these fragments that should be created in the environment.
# Each fragment will be assigned a node.
property :cardinality, Integer, default: 1

# Overrides the details for a cookbook to be retrieved by Berkshelf, by default
# the name is used to identify the cookbook.  Other options such as 'path'
# or 'git' maybe specified here.
# For example:
#
# berkshelf {'hosts' => [{version: '> 1.0.0', path: "/path/to/cookbook"'}}
property :berkshelf, Hash, default: {}

# Extra hostnames that should be available in DNS for this fragment
property :host_aliases, Array, default: []

# A list of tags that the virtual machine will be tagged with if the fragment
# is placed on it.
property :tags, Array, default: []

# A list of tags that the virtual machine should not have assigned for it
# to be suitable for the fragment
property :avoid_tags, Array, default: []

# A list of tags that the packer should attempt to host the fragment along
# side.
property :group_with_tags, Array, default: []

# The flavor that should be used to create the virtual machine.  Flavors
# define the amount of resources that a virtual machine should have assigned.
property :flavor_id, String, default: '2'

attr_reader :machine_files

def initialize(*args)
  super
  @machine_files = {}
end

# Transfer a file to a virtual machine.
def machine_file(local_path, remote_path)
  @machine_files[local_path] = remote_path
end

action :create do
  converge_by "Merged fragment '#{new_resource.name}'" do
    node.run_state['fragments']['cluster']['fragments'] = [] \
      unless node.run_state['fragments']['cluster']['fragments']
    node.run_state['fragments']['cluster']['fragments'] << new_resource
  end
end
