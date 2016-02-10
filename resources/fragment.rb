resource_name :fragment
if node['fragments']['resource_name']
  resource_name node['fragments']['resource_name'].to_sym
end

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

# A list of tags that the packer should use to only group like tagged fragments
# together with no other fragments allowed on the host.
property :only_group_with_tags, Array, default: []

# The flavor that should be used to create the virtual machine.  Flavors
# define the amount of resources that a virtual machine should have assigned.
property :flavor_id, String, default: '2'

# The environment that the virtual machine should have assigned
property :environment,
         String,
         default: lazy { node['fragments']['default_environment'] }

attr_reader :machine_files, :machine_commands

def initialize(*args)
  super
  @machine_files = {}
  @machine_commands = {}
end

# Transfer a file to a virtual machine.
def machine_file(local_path, remote_path)
  @machine_files[local_path] = remote_path
end

# Add a command that should be run on the virtual machine when the converge
# stage is finished.
def machine_command(description, command)
  @machine_commands[description] = command
end

# Tests if a fragment of that name is already in the collection
def existing_fragment(fragment)
  node.run_state['fragments']['cluster']['fragments']
    .find { |f| f.name == fragment.name }
end

action :create do
  fail 'Define a fragment_cluster resource before defining fragments' \
    unless node.run_state['fragments']['cluster']['name']

  converge_by "Merged fragment '#{new_resource.name}'" do
    node.run_state['fragments']['cluster']['fragments'] = [] \
      unless node.run_state['fragments']['cluster']['fragments']

    fail "Fragment with name '#{new_resource.name}' already included at #{existing_fragment(new_resource).source_line}" \
      if existing_fragment(new_resource)

    node.run_state['fragments']['cluster']['fragments'] << new_resource
  end
end
