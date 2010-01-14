require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

context Mongo::DelegatingCollection do
  def setup_coll
    @conn = Mongo::Connection.new
    @db = Mongo::DelegatingDatabase.new(:remote => @conn.db('dc-remote'), :local => @conn.db('dc-local'))
    @d = @db.collection('abc')
    @d.remove
    @remotes = %w(Ellen Randy Barbara).each { |x| @d.remote.save(:name => x) }
    @locals = %w(Mike Lou Lowell).each { |x| @d.local.save(:name => x) }
    @all = @remotes + @locals
  end
  context 'find' do
    before { setup_coll }
    it 'find returns all records' do
      @d.find.count.should == @all.size
    end
    it 'find doesnt return dups' do
      @d.save(@d.remote.find_one(:name => 'Randy'))
      @d.find.count.should == @all.size
      @d.find.unpruned_rows.size.should == @all.size + 1
    end
    it 'find calls find on remote with local ids' do
      local_ids = @d.local.find.map { |x| x['_id'] }
      mock.proxy(@d.remote).scope_nin('_id' => local_ids).times(1)
      @d.find.rows
    end
    it 'find returns local precedence' do
      r = @d.remote.find_one(:name => 'Randy').merge(:age => 'old')
      @d.local.save(r)
      @d.find_one(:name => 'Randy')['age'].should == 'old'
    end
    it 'respects limit' do
      @d.find({},:limit => 4).to_af.size.should == 4
      expected_names = @d.find.map { |x| x['name'] }[0...4].sort
      @d.find({},:limit => 4).map { |x| x['name'] }.sort.should == expected_names
    end
    it 'doesnt query more colls after reaching limit' do
      mock.proxy(@d.remote).find(anything,anything).times(0)
      @d.find({},:limit => 2).rows
    end
    it 'respects skip' do
      @d.find({},:skip => 1).to_af.size.should == 5
      @d.find({},:skip => 1).map { |x| x['name'] }.sort.should == @all.reject { |x| x == 'Mike' }.sort
    end
    it 'respects skip whole collection' do
      @d.find({},:skip => 4).to_af.size.should == 2
    end
    it 'wont return remote records that were skipped locally' do
      @d.local.save(@d.remote.find_one(:name => 'Randy'))
      @d.find({},:skip => 5).to_af.size.should == 1
    end
    it 'respects skip and limit' do
      @d.find({},:skip => 1, :limit => 4).to_af.size.should == 4
    end
    it 'count doesnt fetch records' do
      mock.instance_of(Mongo::Cursor).to_a.times(0)
      @d.count.should == 6
    end
    # it 'count honors remote deletes' do
    #   @d.remote.find.each { |x| @d.save(x) }
    #   @d.remote.remove
    #   @d.count.should == 6
    # end
  end
  context 'save' do
    before { setup_coll }
    it 'save uses local' do
      @d.save(:name => 'Pat')
      @d.count.should == @all.size + 1
      @d.remote.count.should == @remotes.size
      @d.local.count.should == @locals.size + 1
    end
    it 'updating a non-dup shouldnt mark it as a dup' do
      r = @d.local.find_one(:name => 'Mike').merge(:foo => :bar)
      @d.save(r)
      @d.count.should == 6
      @d.local.find_one(:name => 'Mike')['_duplicate'].should be_nil
    end
    it 'saving a dup for first time should mark it as a dup' do
      r = @d.remote.find_one(:name => 'Randy')
      @d.save(r)
      @d.count.should == 6
      @d.local.find_one(:name => 'Randy')['_duplicate'].should == true
    end
  end
end