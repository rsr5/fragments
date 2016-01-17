
Chef::Recipe.send(:include, Fragments::DSL)
Chef::Provider.send(:include, Fragments::DSL)
Chef::Resource.send(:include, Fragments::DSL)

Chef::Recipe.send(:include, Fragments::Packers)
Chef::Provider.send(:include, Fragments::Packers)
Chef::Resource.send(:include, Fragments::Packers)
