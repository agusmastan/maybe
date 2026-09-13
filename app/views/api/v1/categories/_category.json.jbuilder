# frozen_string_literal: true

json.id category.id
json.name category.name
json.classification category.classification
json.color category.color
json.icon category.lucide_icon

# Parent category reference (nil if this is a root category)
if category.subcategory?
  json.parent_id category.parent_id
else
  json.parent_id nil
end

# Subcategories (only populated for root categories)
if category.subcategories.any?
  json.subcategories category.subcategories.sort_by(&:name) do |sub|
    json.id sub.id
    json.name sub.name
    json.classification sub.classification
    json.color sub.color
    json.icon sub.lucide_icon
    json.parent_id sub.parent_id
  end
else
  json.subcategories []
end
