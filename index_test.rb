require 'lib/rjgit'


module RJGit
  class Index
    import org.eclipse.jgit.lib.FileMode
    import org.eclipse.jgit.lib.CommitBuilder
    import org.eclipse.jgit.lib.TreeFormatter
    import org.eclipse.jgit.lib.Constants
    
    attr_accessor :treemap
  
    def initialize(repo)
      @repo = repo
      @object_inserter = @repo.newObjectInserter
      @treemap = {}
    end
  
    def add(path, data)
      path = path[1..-1] if path[0] == '/'
      path = path.split('/')
      filename = path.pop

      current = self.treemap

      path.each do |dir|
        current[dir] ||= {}
        node = current[dir]
        current = node
      end

      current[filename] = data
    end
  
    def delete(path)
      path = path[1..-1] if path[0] == '/'
      path = path.split('/')
      last = path.pop
    
      current = self.treemap
    
      path.each do |dir|
        current[dir] ||= {}
        node = current[dir]
        current = node
      end
    
      current[last] = :delete
    end
  
    def commit(message, parent = nil, author = nil, last_tree = nil, ref = "refs/heads/#{Constants::MASTER}")
      last_tree = last_tree ? last_tree : @repo.resolve(ref+"^{tree}")
      new_tree = build_tree(last_tree)
      return false if new_tree.name == last_tree.name
      
      parent = parent ? parent : @repo.resolve(ref+"^{commit}")
    
      cb = CommitBuilder.new
      pi = author.person_ident
      cb.setCommitter(pi)
      cb.setAuthor(pi)
      cb.setMessage(message)
      cb.setTreeId(new_tree)
      cb.addParentId(parent)
    
      newhead = @object_inserter.insert(cb)
      
      # Point ref to the newest commit
      ru = @repo.updateRef(ref)
      ru.setNewObjectId(newhead)
      res = ru.forceUpdate
      
      @object_inserter.flush
      res.to_string
    end
  
    # Sweet recursion
    def build_tree(start_tree = @repo.resolve("refs/heads/#{Constants::MASTER}^{tree}"), treemap = nil)
      existing_trees = {}
      formatter = TreeFormatter.new
      treemap ||= self.treemap
    
      if start_tree then
        treewalk = TreeWalk.new(@repo)
        treewalk.add_tree(start_tree)
        while treewalk.next
          name = treewalk.get_name_string
          if treemap.keys.include?(name) then
            existing_trees[name] = treewalk.get_object_id(0) if treewalk.isSubtree
            treemap[name] = :deleted if treemap[name] == :delete
          else
            mode = treewalk.isSubtree ? FileMode::TREE : FileMode::REGULAR_FILE
            formatter.append(name.to_java_string, mode, treewalk.get_object_id(0))
          end
        end
      end
    
      treemap.each do |name, data|
        case data
          when String
            blobid = @object_inserter.insert(Constants::OBJ_BLOB, data.to_java_bytes)
            formatter.append(name.to_java_string, FileMode::REGULAR_FILE, blobid)
          when Hash
            next_tree = build_tree(existing_trees[name], data)
            formatter.append(name.to_java_string, FileMode::TREE, next_tree)
          end
      end
    
      @object_inserter.insert(formatter)
    end
  
  end
end

repo = RJGit::Repo.new("/tmp/testrepo")

idx = RJGit::Index.new(repo.jrepo)
idx.add 'test1/this.txt', "What about this one...?"
idx.add 'testnieuw/this.txt', "What about this one...?"
idx.delete 'test1/tester'
idx.add 'test1/test2/test3/test', "Whatever"
res = idx.commit("Testing", nil, RJGit::Actor.new("Dawa Ometto", "d.ometto@gmail.com"))

puts res
puts idx.treemap.inspect # Allows you to see which files where deleted; these will have the value :deleted, while files marked for deletion that were no encountered will have the value :delete