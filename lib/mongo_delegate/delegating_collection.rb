require 'rubygems'
require 'mongo'
require 'mongo_scope'
require 'mharris_ext'
require 'active_support'
require 'andand'

%w(ext composite_cursor).each { |x| require File.join(File.dirname(__FILE__),x) }

module Mongo
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
end
