module RJGit
  
  import 'org.eclipse.jgit.revwalk.RevBlob'
  
  class Blob 
    
    attr_reader :id, :mode, :name, :path, :jblob
    RJGit.delegate_to(RevBlob, :@jblob)

    def initialize(jrepo, path, mode, jblob)
      @jrepo = jrepo
      @jblob = jblob
      @path = path
      @name = File.basename(path)
      @mode = mode
      @id = ObjectId.toString(jblob.get_id)
    end
    
    # The size of this blob in bytes
    #
    # Returns Integer
    def bytesize
      @bytesize ||= @jrepo.open(@jblob).get_size 
    end

    def size
      @size ||= bytesize
    end
    
    def blame(options={})
      @blame ||= RJGit::Porcelain.blame(@jrepo, @path, options)
    end

    # The binary contents of this blob.
    # Returns String
    def data
      @data ||= RJGit::Porcelain.cat_file(@jrepo, @jblob) 
    end

    # The mime type of this file (based on the filename)
    # Returns String
    def mime_type
      Blob.mime_type(self.name)
    end

    def self.mime_type(filename)
      guesses = MIME::Types.type_for(filename) rescue []
      guesses.first ? guesses.first.simplified : DEFAULT_MIME_TYPE
    end
    
    # Finds a particular Blob in repository matching file_path
    def self.find_blob(repository, file_path, revstring=Constants::HEAD)
      jrepo = RJGit.repository_type(repository)
      last_commit_hash = jrepo.resolve(revstring)
      return nil if last_commit_hash.nil?

      walk = RevWalk.new(jrepo)
      jcommit = walk.parse_commit(last_commit_hash)
      treewalk = TreeWalk.new(jrepo)
      jtree = jcommit.get_tree
      treewalk.add_tree(jtree)
      treewalk.set_recursive(true)
      treewalk.set_filter(PathFilter.create(file_path))
      if treewalk.next
        jblob = walk.lookup_blob(treewalk.objectId(0))
        if jblob
          mode = RJGit.get_file_mode(jrepo, file_path, jtree) 
          Blob.new(jrepo, file_path, mode, jblob)
        end
      else
        nil
      end
    end

  end
end
