class CompositeCursor
  class FindOps
    attr_accessor :res, :cursor
    include FromHash
    def options; cursor.options; end
    fattr(:num_using) { res.map { |x| x[0].to_af.size }.sum }
    fattr(:found_ids) { res.map { |x| x[1].to_af.map { |x| x['_id'] } }.flatten }
    fattr(:ops) do
      r = {}
      r[:limit] = (options[:limit] - num_using) if options[:limit]
      r[:skip] = [(options[:skip] - found_ids.size ),0].max if options[:skip]
      r
    end
    def zero_limit?
      ops[:limit] == 0
    end
  end
  
  attr_accessor :colls, :selector, :options
  include FromHash
  include Enumerable
  def to_af; rows; end
  fattr(:rows) do
    cursors.map { |x| x.to_af }.flatten
  end
  def each(&b)
    rows.each(&b)
  end
  def count
    colls.map do |coll|
      coll.scope_ne('_duplicate' => true).find(selector).count
    end.sum
  end
  def first
    rows.first
  end
  fattr(:cursors) do
    colls.inject([]) do |res,coll|
      ops = FindOps.new(:res => res, :cursor => self)
      res + if !ops.zero_limit?
        [[coll.scope_nin('_id' => ops.found_ids).find(selector,ops.ops),coll.find(selector)]]
      else
        []
      end
    end.map { |x| x[0] }
  end
  fattr(:unpruned_cursors) do
    colls.map { |c| c.find(selector) }
  end
  fattr(:unpruned_rows) do
    unpruned_cursors.map { |c| c.to_a }.flatten
  end
end