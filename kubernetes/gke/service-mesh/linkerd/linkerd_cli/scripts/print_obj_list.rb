#!/usr/bin/env ruby

######
# print_obj_list.rb
# 
# Description: prints list given flatten list of K8S rsrc objs
# Format of Input: 
#   kind: ServiceAccount
#   metadata.name: prometheus
#   ---
#   kind: ClusterRole
#   metadata.name: linkerd-linkerd-viz-tap
#   --- 
##############################

FILE = ARGV[0]

# create HoL indexed by kind
objkey, objects = "", {}
File.open(FILE).each_line do |line|
  next if line.chomp == "---"
  type, name = line.gsub(/[[:space:]]/, '').split(':')
  if type == "kind"
    objkey = name
  elsif type == "metadata.name"
    (objects[objkey] ||=[]) << name
    objkey = ""
  end
end

objects.each do |kind,items|
  puts kind
  items.each { |item| puts "  - #{item}" }
end
