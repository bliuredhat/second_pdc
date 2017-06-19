# requirements:
# * data: to be passed as an Array
# * type: of the resource as String
# * partial_for_resource: the partial that can render a single instance of
#                         resource
#
# output: renders all resources in an array like
#
# {
#   "data": [
#       {
#         "id":
#         "type":
#         partial-for-resource-1
#       },
#       {
#         "id":
#         "type":
#         partial-for-resource-2
#       }
#   ]
# }

json.data data do |resource|
  json.id resource.id
  json.type type
  json.partial! partial_for_resource, :resource => resource
end
