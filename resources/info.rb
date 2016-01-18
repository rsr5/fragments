resource_name :machine_state

property :state, String, name_property: true

action :update do
  state = info_hash(new_resource.state)
  state['id'] = 'state'

  chef_data_bag_item 'state' do
    data_bag 'fragments'
    raw_data state
  end

  state['machines'].each do |name, _|
    converge_by("'#{name}' updated to '#{new_resource.state}'") {}
  end
end
