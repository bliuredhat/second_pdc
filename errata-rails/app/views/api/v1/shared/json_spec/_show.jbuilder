# requirements:
# * resource: Object;  expects attribute id to be present
# * type: String indicating the type of object
# * partial_for_resource: the partial to render a single resource
#     The partial to render a single reso
#
# renders resources object as
# {
#   "data": {
#     "id" : <id>
#     "type" : resource_type
#     resource
#   },
# }

json.data do
  json.id   resource.id
  json.type type
  json.partial! partial_for_resource, :resource => resource
end
