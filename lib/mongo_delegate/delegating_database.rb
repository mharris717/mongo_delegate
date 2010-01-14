module Mongo
  class DelegatingDatabase
    attr_accessor :local, :remote
    include FromHash
    def collection(name)
      DelegatingCollection.new(:local => local.collection(name), :remote => remote.collection(name))
    end
  end
end