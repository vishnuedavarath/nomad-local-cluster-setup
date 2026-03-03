# Test the new nomad_nodes and nomad_node data sources

# Get all nodes
data "nomad_nodes" "all" {
  resources = true
  os        = true
}

# Get details for each node (using the first one as example)
data "nomad_node" "first" {
  count   = length(data.nomad_nodes.all.nodes) > 0 ? 1 : 0
  node_id = data.nomad_nodes.all.nodes[0].id
}

output "all_nodes" {
  description = "List of all Nomad nodes"
  value       = data.nomad_nodes.all.nodes
}

output "first_node_details" {
  description = "Details of the first node"
  value       = length(data.nomad_node.first) > 0 ? data.nomad_node.first[0] : null
}
