require 'rubygems'
require 'mongo'
require 'mharris_ext'
require 'activesupport'
require 'mongo_scope'
require 'rr'
require 'andand'

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
  fattr(:rows) do
    cursors.map { |x| x.to_af }.flatten
  end
  def each(&b)
    rows.each(&b)
  end
  def count
    rows.size
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

class DelegatingCollection
  include FromHash
  include CollMod
  attr_accessor :remote, :local
  def find(selector={},options={})
    CompositeCursor.new(:colls => [local,remote],:selector => selector, :options => options)  
  end
  def find_one(selector = {},options = {})
    find(selector,options.merge(:limit => 1)).first
  end
  def remove
    colls.each { |x| x.remove }
  end
  def colls
    [local,remote]
  end
  def save(d)
    local.save(d.merge('_duplicate' => true))
  end
end

Mongo::Collection.send(:include,CollMod)

Spec::Runner.configure do |config|
  config.mock_with :rr
end

def mit(name,&b)
  it(name,&b) #if name == 'respects skip and limit'
end

context DelegatingCollection do
  def setup_coll
    @conn = Mongo::Connection.new
    @d = DelegatingCollection.new(:remote => @conn.db('dc-remote').collection('abc'), :local => @conn.db('dc-local').collection('abc'))
    @d.remove
    @remotes = %w(Ellen Randy Barbara).each { |x| @d.remote.save(:name => x) }
    @locals = %w(Mike Lou Lowell).each { |x| @d.local.save(:name => x) }
    @all = @remotes + @locals
  end
  context 'find' do
    before { setup_coll }
    mit 'find returns all records' do
      @d.find.count.should == @all.size
    end
    mit 'find doesnt return dups' do
      @d.local.save(@d.remote.find_one(:name => 'Randy'))
      @d.find.count.should == @all.size
      @d.find.unpruned_rows.size.should == @all.size + 1
    end
    mit 'find calls find on remote with local ids' do
      local_ids = @d.local.find.map { |x| x['_id'] }
      mock.proxy(@d.remote).scope_nin('_id' => local_ids).times(1)
      @d.find.rows
    end
    mit 'find returns local precedence' do
      r = @d.remote.find_one(:name => 'Randy').merge(:age => 'old')
      @d.local.save(r)
      @d.find_one(:name => 'Randy')['age'].should == 'old'
    end
    mit 'respects limit' do
      @d.find({},:limit => 4).count.should == 4
      expected_names = @d.find.map { |x| x['name'] }[0...4].sort
      @d.find({},:limit => 4).map { |x| x['name'] }.sort.should == expected_names
    end
    mit 'doesnt query more colls after reaching limit' do
      mock.proxy(@d.remote).find(anything,anything).times(0)
      @d.find({},:limit => 2).rows
    end
    mit 'respects skip' do
      @d.find({},:skip => 1).count.should == 5
      @d.find({},:skip => 1).map { |x| x['name'] }.sort.should == @all.reject { |x| x == 'Mike' }.sort
    end
    mit 'respects skip whole collection' do
      @d.find({},:skip => 4).count.should == 2
    end
    mit 'wont return remote records that were skipped locally' do
      @d.local.save(@d.remote.find_one(:name => 'Randy'))
      @d.find({},:skip => 5).count.should == 1
    end
    mit 'respects skip and limit' do
      @d.find({},:skip => 1, :limit => 4).count.should == 4
    end
    mit 'count doesnt fetch records' do
      dont_allow(Mongo::Cursor).to_a
      @d.count.should == 6
    end
  end
  context 'save' do
    before { setup_coll }
    mit 'save uses local' do
      @d.save(:name => 'Pat')
      @d.count.should == @all.size + 1
      @d.remote.count.should == @remotes.size
      @d.local.count.should == @locals.size + 1
    end
  end
end

