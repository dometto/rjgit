require 'spec_helper'

UPLOAD_PACK_ADVERTISEMENT = "009df5771ead0e6d9a8d937bf5cabfa3678ee8944a92 HEAD\u0000 include-tag multi_ack_detailed multi_ack ofs-delta side-band side-band-64k thin-pack no-progress shallow \n0044f5771ead0e6d9a8d937bf5cabfa3678ee8944a92 refs/heads/alternative\n003ff5771ead0e6d9a8d937bf5cabfa3678ee8944a92 refs/heads/master\n0000"

CORRECT_UPLOAD_REQUEST = "0067want f5771ead0e6d9a8d937bf5cabfa3678ee8944a92 multi_ack_detailed side-band-64k thin-pack ofs-delta\n00000009done\n" # Correct request for an object

CORRECT_UPLOAD_REQUEST_RESPONSE = "Counting objects: 26, done" # Server's expected response to CORRECT_UPLOAD_REQUEST

UPLOAD_REQUEST_INVALID_LENGTH = "0065want f5771ead0e6d9a8d937bf5cabfa3678ee8944a92 multi_ack_detailed side-band-64k thin-pack ofs-delta\n" # Request has invalid packet length header

UPLOAD_REQUEST_UNKNOWN_OBJECT = "0067want aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa multi_ack_detailed side-band-64k thin-pack ofs-delta\n00000009done\n" # Unknown object requested

UPLOAD_REQUEST_INVALID_OBJECT = "0067want aaa aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa multi_ack_detailed side-band-64k thin-pack ofs-delta\n00000009done\n" # Malformed object id requested

RECEIVE_PACK_ADVERTISEMENT = "0078f5771ead0e6d9a8d937bf5cabfa3678ee8944a92 refs/heads/alternative\u0000 side-band-64k delete-refs report-status ofs-delta \n003ff5771ead0e6d9a8d937bf5cabfa3678ee8944a92 refs/heads/master\n0000"

CORRECT_RECEIVE_REQUEST = "00820000000000000000000000000000000000000000 0ed348defdb66282b02803a8836c5d5fc5b97d0d refs/heads/test\x00 report-status side-band-64k0000PACK\x00\x00\x00\x02\x00\x00\x00\x00\x02\x9D\b\x82;\xD8\xA8\xEA\xB5\x10\xADj\xC7\\\x82<\xFD>\xD3\x1E" # Client pushes a valid object-id

CORRECT_RECEIVE_REQUEST_RESPONSE = "0028\u0002Updating references: 100% (1/1)   \r0025\u0002Updating references: 100% (1/1)\n002e\u0001000eunpack ok\n0017ok refs/heads/test\n00000000" # Server's expected response to CORRECT_RECEIVE_REQUEST

RECEIVE_REQUEST_INVALID_LENGTH = "00010000000000000000000000000000000000000000 0ed348defdb66282b02803a8836c5d5fc5b97d0d refs/heads/test\x00 report-status side-band-64k0000PACK\x00\x00\x00\x02\x00\x00\x00\x00\x02\x9D\b\x82;\xD8\xA8\xEA\xB5\x10\xADj\xC7\\\x82<\xFD>\xD3\x1E" # Request has invalid packet length header

RECEIVE_REQUEST_INVALID_OBJECT = "0082wa 0000000000000000000000000000000000000 0ed348defdb66282b02803a8836c5d5fc5b97d0d refs/heads/test\x00 report-status side-band-64k0000PACK\x00\x00\x00\x02\x00\x00\x00\x00\x02\x9D\b\x82;\xD8\xA8\xEA\xB5\x10\xADj\xC7\\\x82<\xFD>\xD3\x1E" # Client pushes a malformed object-id

describe RJGitUploadPack do
  before(:all) do
    @temp_repo_path = create_temp_repo(TEST_REPO_PATH)
    @repo = Repo.new(@temp_repo_path)
  end
  
  before(:each) do
    @pack = RJGitUploadPack.new(@repo)
  end  
  
  it "should have a reference to the repository's JGit-repository" do
    @pack.jrepo.should eql @repo.jrepo
  end
  
  it "should create a JGit pack object on creation" do
    @pack.jpack.should be_a org.eclipse.jgit.transport.UploadPack
  end
  
  it "should advertise all references" do
    @pack.advertise_refs.should eql UPLOAD_PACK_ADVERTISEMENT
  end
  
  it "should return the server-side response to a client's wants" do
    res, msg = @pack.process(CORRECT_UPLOAD_REQUEST)
    res.read.include?(CORRECT_UPLOAD_REQUEST_RESPONSE).should eql true
    msg.should eql nil
  end
  
  it "should advertise its references when processing requests in bidirectional mode" do
    res, msg = @pack.process(CORRECT_UPLOAD_REQUEST)
    res.read.include?(UPLOAD_PACK_ADVERTISEMENT.split("\n").first).should eql false
    @pack.bidirectional = true
    res, msg = @pack.process(CORRECT_UPLOAD_REQUEST)
    res.read.include?(UPLOAD_PACK_ADVERTISEMENT.split("\n").first).should eql true
  end
  
  it "should return a bidirectional pipe when in bidirectional mode"
  
  it "should return nil and a Java IO error exception object when the client's request has the wrong length" do
    res, msg = @pack.process(UPLOAD_REQUEST_INVALID_LENGTH)
    res.should eql nil
    msg.should be_a java.io.IOException
  end
  
  it "should return nil and a JGit internal server error exception object when the client requests an unknown object" do
    res, msg = @pack.process(UPLOAD_REQUEST_UNKNOWN_OBJECT)
    res.should eql nil
    msg.should be_a org.eclipse.jgit.transport.UploadPackInternalServerErrorException
  end
  
  it "should return nil and a JGit invalid object exception object when the client requests an invalid object id" do
    res, msg = @pack.process(UPLOAD_REQUEST_INVALID_OBJECT)
    res.should eql nil
    msg.should be_a org.eclipse.jgit.errors.InvalidObjectIdException
  end
  
  after(:all) do
    remove_temp_repo(@temp_repo_path)
    @repo = nil
  end
end

describe RJGitReceivePack do
  before(:all) do
    @temp_repo_path = create_temp_repo(TEST_REPO_PATH)
    @repo = Repo.new(@temp_repo_path)
  end
  
  before(:each) do
    @pack = RJGitReceivePack.new(@repo)
  end
  
  it "should have a reference to the repository's JGit-repository" do
    @pack.jrepo.should eql @repo.jrepo
  end
  
  it "should create a JGit pack object on creation" do
    @pack.jpack.should be_a org.eclipse.jgit.transport.ReceivePack
  end
  
  it "should advertise all references" do
    @pack.advertise_refs.should eql RECEIVE_PACK_ADVERTISEMENT
  end
  
  it "should respond correctly to a client's push request" do
    res, msg = @pack.process(CORRECT_RECEIVE_REQUEST)
    res.read.should eql CORRECT_RECEIVE_REQUEST_RESPONSE
    msg.should eql nil
  end
  
  it "should advertise its references when processing requests in bidirectional mode" do
    res, msg = @pack.process(CORRECT_RECEIVE_REQUEST)
    res.read.include?(RECEIVE_PACK_ADVERTISEMENT.split("\n").first).should eql false
    @pack.bidirectional = true
    res, msg = @pack.process(CORRECT_RECEIVE_REQUEST)
    res.read.include?(RECEIVE_PACK_ADVERTISEMENT.split("\n").first).should eql true
  end
  
  it "should return a bidirectional pipe when in bidirectional mode"
  
  it "should return nil and a Java IO error exception object when the client's request has the wrong length" do
    res, msg = @pack.process(RECEIVE_REQUEST_INVALID_LENGTH)
    res.should eql nil
    msg.should be_a java.io.IOException
  end
  
  it "should return nil and a JGit invalid object exception object if the client requests an invalid object id" do
    res, msg = @pack.process(RECEIVE_REQUEST_INVALID_OBJECT)
    res.should eql nil
    msg.should be_a org.eclipse.jgit.errors.InvalidObjectIdException
  end
  
  after(:all) do
    remove_temp_repo(@temp_repo_path)
    @repo = nil
  end
end