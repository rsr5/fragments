resource_name :fragment_cluster

# A base name that will be used when generating the names for virtual machines
property :name, String, required: true

# The packer that should be used pack the fragments
property :packer, String, default: 'modular'

# The name of the driver to use
property :driver, String, required: true

# Chef supermarket URL
property :supermarket_url, String, default: 'https://supermarket.chef.io'

action :create do
  converge_by "Creating cluster called '#{new_resource.name}'" do
    node.run_state['fragments'] = {
      'cluster' => {
        'name' => new_resource.name,
        'packer' => new_resource.packer,
        'driver' => new_resource.driver,
        'supermarket_url' => new_resource.supermarket_url
      }
    }
  end
end
