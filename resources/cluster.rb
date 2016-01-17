resource_name :fragment_cluster

# A base name that will be used when generating the names for virtual machines
property :name, String, required: true

# The packer that should be used pack the fragments
property :packer, String, default: 'modular'

action :create do
  converge_by "Creating cluster called '#{new_resource.name}'" do
    node.run_state['fragments'] = {
      'cluster' => {
        'name' => new_resource.name,
        'packer' => new_resource.packer
      }
    }
  end
end
