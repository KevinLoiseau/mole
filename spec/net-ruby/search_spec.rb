require (File.dirname(__FILE__) + '/../spec_helper')
require 'net/ldap'

describe "Net::LDAP#search" do

  before :all do
    @server = Mole::Server.new(level: 'error')
    @t = @server.listen(async=true)

  end

  before do
    @server.clear

    @ldap = Net::LDAP.new
    @ldap.port = 3890
    @ldap.base = 'dc=example,dc=com'

    @ldap.open do |ldap|
      ldap.add(dn: 'dc=example,dc=com',
               attributes: {dc: "example", objectClass: "organizationalUnit"})
      ldap.add(dn: 'ou=Group,dc=example,dc=com',
               attributes: {ou: "Group", objectClass: "organizationalUnit"})
      ldap.add(dn: 'gid=userf,ou=Group,dc=example,dc=com',
               attributes: {gid: "users", objectClass: "posixGroup", gidNumber: '10001'})
      ldap.add(dn: 'ou=People,dc=example,dc=com',
               attributes: {ou: "People", objectClass: "organizationalUnit"})
      ldap.add(dn: 'uid=sato,ou=People,dc=example,dc=com',
               attributes: {uid: "sato", objectClass: ['posixAccount', 'inetOrgPerson'], uidNumber: '10001', gidNumber: '10001'})
      ldap.add(dn: 'uid=suzuki,ou=People,dc=example,dc=com',
               attributes: {uid: "suzuki", objectClass: ['posixAccount', 'inetOrgPerson'], uidNumber: '10002', gidNumber: '10002'})
    end
  end

  after :all do
    @server.close
    @t.join
  end

  it "should search all entries under specified subtree." do
    @ldap.open do |ldap|
      ldap.search.length.should == 6
      ldap.search(base: "ou=People,dc=example,dc=com").length.should == 3
      ldap.search(base: "uid=sato,ou=People,dc=example,dc=com").length.should == 1
      ldap.search(base: "dc=sample,dc=com").should be_nil
    end
  end

  it "should hit at most one entry when scope is base object." do
    scope = Net::LDAP::SearchScope_BaseObject
    @ldap.open do |ldap|
      ldap.search(scope: scope).length.should == 1
      ldap.search(base: "ou=People,dc=example,dc=com", scope: scope).length.should == 1
      ldap.search(base: "uid=sato,ou=People,dc=example,dc=com", scope: scope).length.should == 1
      ldap.search(base: "dc=sample,dc=com", scope: scope).should be_nil
    end
  end

  it "should hit only specified entry and single level children." do
    scope = Net::LDAP::SearchScope_SingleLevel
    @ldap.open do |ldap|
      ldap.search(scope: scope).length.should == 3
      ldap.search(base: "ou=People,dc=example,dc=com").length.should == 3
      ldap.search(base: "uid=sato,ou=People,dc=example,dc=com", scope: scope).length.should == 1
      ldap.search(base: "dc=sample,dc=com").should be_nil
    end
  end

  it 'should get specified attributes.' do
    scope = Net::LDAP::SearchScope_BaseObject
    attributes = ['uidNumber', 'foo']
    @ldap.open do |ldap|
      entry = ldap.search(base: "uid=sato,ou=People,dc=example,dc=com", scope: scope, attributes: attributes)[0]
      entry[:uidNumber].should == ['10001']
      entry[:foo].should be_empty
      entry[:uid].should be_empty
    end
  end

  it "should hit only filter passes." do
    filter1 = Net::LDAP::Filter.equals('gidNumber', '10001')
    filter2 = Net::LDAP::Filter.present('uidNumber')
    @ldap.open do |ldap|
      ldap.search(filter: filter1).length.should == 2
      ldap.search(filter: filter2).length.should == 2
      ldap.search(filter: Net::LDAP::Filter.join(filter1, filter2)).length.should == 1
      ldap.search(filter: Net::LDAP::Filter.intersect(filter1, filter2)).length.should == 3
    end
  end

  it "should fetch all attributes if attributes is empty." do
    scope = Net::LDAP::SearchScope_BaseObject
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      entry = ldap.search(base: dn, scope: scope, attributes: [])[0]
      entry[:objectClass].should_not be_empty
      entry[:uid].should_not be_empty
      entry[:uidNumber].should_not be_empty
      entry[:gidNumber].should_not be_empty
    end
  end

  it "should fetch all attributes if specified attributes include '*'." do
    scope = Net::LDAP::SearchScope_BaseObject
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      entry = ldap.search(base: dn, scope: scope, attributes: ['*'])[0]
      entry[:objectClass].should_not be_empty
      entry[:uid].should_not be_empty
      entry[:uidNumber].should_not be_empty
      entry[:gidNumber].should_not be_empty

      entry = ldap.search(base: dn, scope: scope, attributes: ['*', 'uid'])[0]
      entry[:objectClass].should_not be_empty
      entry[:uid].should_not be_empty
      entry[:uidNumber].should_not be_empty
      entry[:gidNumber].should_not be_empty

      entry = ldap.search(base: dn, scope: scope, attributes: ['*', 'foo'])[0]
      entry[:objectClass].should_not be_empty
      entry[:uid].should_not be_empty
      entry[:uidNumber].should_not be_empty
      entry[:gidNumber].should_not be_empty
    end
  end

  it "should fetch all attributes if specified attribute is only '1.1' ." do
    scope = Net::LDAP::SearchScope_BaseObject
    @ldap.open do |ldap|
      dn = 'uid=sato,ou=People,dc=example,dc=com'
      entry = ldap.search(base: dn, scope: scope, attributes: ['1.1'])[0]
      entry[:objectClass].should be_empty
      entry[:uid].should be_empty
      entry[:uidNumber].should be_empty
      entry[:gidNumber].should be_empty

      entry = ldap.search(base: dn, scope: scope, attributes: ['1.1', 'uid'])[0]
      entry[:objectClass].should be_empty
      entry[:uid].should_not be_empty
      entry[:uidNumber].should be_empty
      entry[:gidNumber].should be_empty

      entry = ldap.search(base: dn, scope: scope, attributes: ['1.1', 'foo'])[0]
      entry[:objectClass].should be_empty
      entry[:uid].should be_empty
      entry[:uidNumber].should be_empty
      entry[:gidNumber].should be_empty
    end
  end
end
