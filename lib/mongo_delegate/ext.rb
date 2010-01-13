module Enumerable
  def uniq_by(&b)
    group_by(&b).values.map { |x| x.first }
  end
end

module CollMod
  def count
    find.count
  end
end

class Mongo::Cursor
  fattr(:to_af) { to_a }
  include Enumerable
end

Mongo::Collection.send(:include,CollMod)