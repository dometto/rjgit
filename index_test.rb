require 'lib/rjgit'

import org.eclipse.jgit.lib.Constants
import org.eclipse.jgit.lib.FileMode
import org.eclipse.jgit.lib.CommitBuilder
import org.eclipse.jgit.lib.TreeFormatter

include RJGit

class Index
  attr_accessor :to_add, :to_delete
  
  def initialize(repo)
    @repo = repo
    @object_inserter = @repo.newObjectInserter
    @to_add = {}
    @to_delete = []
  end
  
  def add(path, data)
    path = "/#{path}" unless path[0] == '/'
    to_add[path] = data  
  end
  
  def delete(path)
    path = "/#{path}" unless path[0] == '/'
    to_delete << path
  end
  
  def is_subpath?(path, subpath)
    !! (path =~ /\A#{subpath}/)
  end
  
  # False if a subtree of path requries modification
  def is_ready_path?(path)
    return false if to_add.keys.find {|x| is_subpath?(x, path)}
    true
  end
  
  # Check if there are any files that need to be added in path. Return a hash with the names of these files as key, and their data as value.
  def new_files_for_path(path)
    puts "DEBUG NEW FILES: path = #{path}\n"
    new_files = {}
    to_add.each do |key, val|
      puts "DEBUG NEW FILES: key, val = #{key} #{val}\n"
      name = key.split('/').last
      puts "DEBUG NEW FILES: name = #{name}\n"
      new_files[name] = val if key == File.join(path, name)
    end
    new_files
  end
  
  # Check if there are any trees in to_add that are direct children of path, but that have not yet been handled by build_tree (i.e., are not in handled_paths). Return an array of the names of these children.
  def new_trees_for_path(cur_path, handled_paths)
    new_trees = []
    puts "DEBUG NEW TREES: path = #{cur_path} handled_paths = #{handled_paths}\n"
    divider_length = cur_path == '/' ? 0 : 1
    to_add.keys.each do |x|
      puts "DEBUG NEW TREES: x = #{x}\n"
      if is_subpath?(x, cur_path) then
        x = x[cur_path.length+divider_length, x.length]
        length = x.index('/')
        length = length.nil? ? x.length : length
        name = x[0, length]
        puts "DEBUG NEW TREES: name = #{name}\n"
        new_trees << name unless handled_paths.include?(name)
      end
    end
    new_trees
  end
  
  def commit(author, message)
    head = @repo.resolve(Constants::HEAD+"^{commit}")
    new_tree = build_tree
    
    cb = CommitBuilder.new
    pi = author.person_ident
    cb.setCommitter(pi)
    cb.setAuthor(pi)
    cb.setMessage(message)
    cb.setTreeId(new_tree)
    cb.addParentId(head)
    
    newhead = @object_inserter.insert(cb)
    
    @object_inserter.flush
    newhead
  end
  
  # Sweet recursion
  def build_tree(start_tree = @repo.resolve(Constants::HEAD+"^{tree}"), base_path = '/')
    formatter = TreeFormatter.new
    new_trees = {}
    handled_paths = []
    
    new_files_for_path(base_path).each do |name, data|
      blobid = @object_inserter.insert(Constants::OBJ_BLOB, data.to_java_bytes)
      formatter.append(name.to_java_string, FileMode::REGULAR_FILE, blobid)
      to_add.delete(File.join(base_path, name))
    end
    
    if !start_tree.nil? then
      treewalk = TreeWalk.new(@repo)
      treewalk.add_tree(start_tree)    
      while treewalk.next
        name = treewalk.get_name_string
        path = File.join(base_path, name)
        if !is_ready_path?(path) && treewalk.isSubtree
            new_trees[name] = treewalk.get_object_id(0) 
        else
          mode = treewalk.isSubtree ? FileMode::TREE : FileMode::REGULAR_FILE
          formatter.append(name.to_java_string, mode, treewalk.get_object_id(0)) unless to_delete.include?(path)
        end
        handled_paths << name
      end
    end
    
    new_trees_for_path(base_path, handled_paths).each do |name|
      new_tree = build_tree(nil, File.join(base_path, name))
      formatter.append(name.to_java_string, FileMode::TREE, new_tree)
    end
    
    new_trees.each do |name, new_objectid|
      new_tree = build_tree(new_objectid, File.join(base_path, name))
      formatter.append(name.to_java_string, FileMode::TREE, new_tree)
    end
    
    @object_inserter.insert(formatter)
  end
  
end

repo = Repo.new("/tmp/testrepo")

idx = Index.new(repo.jrepo)
idx.add 'test1/this.txt', "What about this one...?"
idx.add 'testnieuw/this.txt', "What about this one...?"
idx.delete 'test1/tester'
idx.add 'test1/test2/test3/test', "Whatever"
newhead = idx.commit(Actor.new("Dawa Ometto", "d.ometto@gmail.com"), "Testing")

ru = repo.updateRef(Constants::HEAD) # Point HEAD to the newest commit
ru.setNewObjectId(newhead)
res = ru.forceUpdate

puts res.to_string