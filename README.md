# fragments

Chef Provisioning is great for provisioning virtual machines when a clear
definition of a cluster or platform is available.  If such a definition will
never be available at the time a Provisioning cookbook is written then it
can be a bit constrictive.  In organisations where there are hundreds of
services and just as many combinations they may be combined a different
approach may be necessary.

The `fragments` cookbook is an attempt at moving from thinking about virtual
machines as being the unit that should be defined to thinking more about
sections of a large platform and how they are defined and relate depend on
each other.  From now on these sections will be referred to as *fragments*.

A *fragment* is defined using an LWRP called `fragment`.  For instance, a
simple web application may have the following fragments.

```ruby
fragment 'database' do
  memory_weight 100
  run_list %w(mysqld::default)
end

fragment 'webapp' do
  memory_weight 250
  run_list %w(webapp::default)
  required_fragment %w(database)
end

fragment 'nginx' do
  memory_weight 50
  run_list %w(nginx::default)
  required_fragment %w(webapp)
end
```

So rather than define a virtual machine with a run list that contains the
above recipes, *fragments* are defined.  The cookbook then includes facilities
to *pack* these *fragments* into as many virtual machines as are required to
host them.
