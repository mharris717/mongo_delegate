class Mongo::Cursor
  def foc
    formatted_order_clause
  rescue => exp
    return nil
  end
end

class Numeric
  def sortflip
    self * -1.0
  end
end

class String
  def num_val
    return 0 if length == 0
    self[-1] + 500*self[0..-2].num_val
  end
  def sortflip
    opposite_word
  end
  def opposite_word
    res = " " * length
    for i in (0...length)
      res[i] = 255-self[i]
    end
    res
  end
end

class CompositeCursor
  class FindOps
    attr_accessor :res, :cursor
    include FromHash
    def options; cursor.options; end
    fattr(:num_using) { res.map { |x| x[0].to_af.size }.sum }
    fattr(:found_ids) { res.map { |x| x[1].to_af.map { |x| x['_id'] } }.flatten }
    fattr(:ops) do
      r = {}
      r[:limit] = (options[:limit] - num_using) if options[:limit] && !options[:sort]
      r[:skip] = [(options[:skip] - found_ids.size ),0].max if options[:skip] && !options[:sort]
      r[:sort] = options[:sort] if options[:sort]
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
  def sort_proc
    foc = cursors.first.foc
    return nil unless foc
    lambda do |doc|
      foc.map { |k,v| (v == 1) ? doc[k] : doc[k].sortflip }
    end
  end
  fattr(:rows) do
    res = cursors.map { |x| x.to_af }.flatten
    res = res.sort_by(&sort_proc) if sort_proc
    res = res[0...(options[:limit])] if options[:limit]
    res = res[(options[:skip])..-1] if options[:skip] && options[:sort]
    res
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