ExUnit.start(exclude: [:skip])

# Start the distributed system if not already started
unless Node.alive?() do
  node_name = String.to_atom("test_node@127.0.0.1")
  :net_kernel.start([node_name, :shortnames])
  Node.set_cookie(:test_cookie)
end
