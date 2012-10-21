require 'test_helper'

class XmlTest < Test::Unit::TestCase
  should "should transform a simple tag with content" do
    xml = "<tag>This is the contents</tag>"
    Crack::XML.parse(xml).should == { 'tag' => 'This is the contents' }
  end

  should "should work with cdata tags" do
    xml = <<-END
      <tag>
      <![CDATA[
        text inside cdata
      ]]>
      </tag>
    END
    Crack::XML.parse(xml)["tag"].strip.should == "text inside cdata"
  end

  should "should transform a simple tag with attributes" do
    xml = "<tag attr1='1' attr2='2'></tag>"
    hash = { 'tag' => { 'attr1' => '1', 'attr2' => '2' } }
    Crack::XML.parse(xml).should == hash
  end

  should "should transform repeating siblings into an array" do
    xml =<<-XML
      <opt>
        <user login="grep" fullname="Gary R Epstein" />
        <user login="stty" fullname="Simon T Tyson" />
      </opt>
    XML

    Crack::XML.parse(xml)['opt']['user'].class.should == Array

    hash = {
      'opt' => {
        'user' => [{
          'login'    => 'grep',
          'fullname' => 'Gary R Epstein'
        },{
          'login'    => 'stty',
          'fullname' => 'Simon T Tyson'
        }]
      }
    }

    Crack::XML.parse(xml).should == hash
  end

  should "should not transform non-repeating siblings into an array" do
    xml =<<-XML
      <opt>
        <user login="grep" fullname="Gary R Epstein" />
      </opt>
    XML

    Crack::XML.parse(xml)['opt']['user'].class.should == Hash

    hash = {
      'opt' => {
        'user' => {
          'login' => 'grep',
          'fullname' => 'Gary R Epstein'
        }
      }
    }
    
    Crack::XML.parse(xml).should == hash
  end
  
  context "Parsing xml with text and attributes" do
    setup do
      xml =<<-XML
        <opt>
          <user login="grep">Gary R Epstein</user>
          <user>Simon T Tyson</user>
        </opt>
      XML
      @data = Crack::XML.parse(xml)
    end

    should "correctly parse text nodes" do
      @data.should == {
        'opt' => {
          'user' => [
            'Gary R Epstein',
            'Simon T Tyson'
          ]
        }
      }
    end
    
    should "be parse attributes for text node if present" do
      @data['opt']['user'][0].attributes.should == {'login' => 'grep'}
    end
    
    should "default attributes to empty hash if not present" do
      @data['opt']['user'][1].attributes.should == {}
    end
    
    should "add 'attributes' accessor methods to parsed instances of String" do
      @data['opt']['user'][0].respond_to?(:attributes).should be(true)
      @data['opt']['user'][0].respond_to?(:attributes=).should be(true)
    end
    
    should "not add 'attributes' accessor methods to all instances of String" do
      "some-string".respond_to?(:attributes).should be(false)
      "some-string".respond_to?(:attributes=).should be(false)
    end
  end

  xml_entities = {
    "<" => "&lt;",
    ">" => "&gt;",
    '"' => "&quot;",
    "'" => "&apos;",
    "&" => "&amp;"
  }
  should "should unescape html entities" do
    xml_entities.each do |k,v|
      xml = "<tag>Some content #{v}</tag>"
      Crack::XML.parse(xml)['tag'].should =~ Regexp.new(k)
    end
  end
  
  should "should unescape XML entities in attributes" do
    xml_entities.each do |k,v|
      xml = "<tag attr='Some content #{v}'></tag>"
      Crack::XML.parse(xml)['tag']['attr'].should =~ Regexp.new(k)
    end
  end

  should "should undasherize keys as tags" do
    xml = "<tag-1>Stuff</tag-1>"
    Crack::XML.parse(xml).keys.should include( 'tag_1' )
  end

  should "should undasherize keys as attributes" do
    xml = "<tag1 attr-1='1'></tag1>"
    Crack::XML.parse(xml)['tag1'].keys.should include( 'attr_1')
  end

  should "should undasherize keys as tags and attributes" do
    xml = "<tag-1 attr-1='1'></tag-1>"
    Crack::XML.parse(xml).keys.should include( 'tag_1' )
    Crack::XML.parse(xml)['tag_1'].keys.should include( 'attr_1')
  end

  should "should render nested content correctly" do
    xml = "<root><tag1>Tag1 Content <em><strong>This is strong</strong></em></tag1></root>"
    Crack::XML.parse(xml)['root']['tag1'].should == "Tag1 Content <em><strong>This is strong</strong></em>"
  end

  should "should render nested content with splshould text nodes correctly" do
    xml = "<root>Tag1 Content<em>Stuff</em> Hi There</root>"
    Crack::XML.parse(xml)['root'].should == "Tag1 Content<em>Stuff</em> Hi There"
  end

  should "should ignore attributes when a child is a text node" do
    xml = "<root attr1='1'>Stuff</root>"
    Crack::XML.parse(xml).should == { "root" => "Stuff" }
  end

  should "should ignore attributes when any child is a text node" do
    xml = "<root attr1='1'>Stuff <em>in italics</em></root>"
    Crack::XML.parse(xml).should == { "root" => "Stuff <em>in italics</em>" }
  end

  should "should properly handle nil values (ActiveSupport Compatible)" do
    topic_xml = <<-EOT
      <topic>
        <title></title>
        <id type="integer"></id>
        <approved type="boolean"></approved>
        <written-on type="date"></written-on>
        <viewed-at type="datetime"></viewed-at>
        <content type="yaml"></content>
        <parent-id></parent-id>
      </topic>
    EOT

    expected_topic_hash = {
      'title'      => nil,
      'id'         => nil,
      'approved'   => nil,
      'written_on' => nil,
      'viewed_at'  => nil,
      'content'    => nil,
      'parent_id'  => nil
    }
    Crack::XML.parse(topic_xml)["topic"].should == expected_topic_hash
  end

  should "should handle a single record from_xml with attributes other than type (ActiveSupport Compatible)" do
    topic_xml = <<-EOT
    <rsp stat="ok">
      <photos page="1" pages="1" perpage="100" total="16">
        <photo id="175756086" owner="55569174@N00" secret="0279bf37a1" server="76" title="Colored Pencil PhotoBooth Fun" ispublic="1" isfriend="0" isfamily="0"/>
      </photos>
    </rsp>
    EOT

    expected_topic_hash = {
      'id' => "175756086",
      'owner' => "55569174@N00",
      'secret' => "0279bf37a1",
      'server' => "76",
      'title' => "Colored Pencil PhotoBooth Fun",
      'ispublic' => "1",
      'isfriend' => "0",
      'isfamily' => "0",
    }
    Crack::XML.parse(topic_xml)["rsp"]["photos"]["photo"].each do |k,v|
      v.should == expected_topic_hash[k]
    end
  end

  should "should handle array with one entry from_xml (ActiveSupport Compatible)" do
    blog_xml = <<-XML
      <blog>
        <posts type="array">
          <post>a post</post>
        </posts>
      </blog>
    XML
    expected_blog_hash = {"blog" => {"posts" => ["a post"]}}
    Crack::XML.parse(blog_xml).should == expected_blog_hash
  end

  should "should handle array with multiple entries from xml (ActiveSupport Compatible)" do
    blog_xml = <<-XML
      <blog>
        <posts type="array">
          <post>a post</post>
          <post>another post</post>
        </posts>
      </blog>
    XML
    expected_blog_hash = {"blog" => {"posts" => ["a post", "another post"]}}
    Crack::XML.parse(blog_xml).should == expected_blog_hash
  end

  should "should let type trickle through" do
    product_xml = <<-EOT
    <product>
      <weight type="double">0.5</weight>
      <image type="ProductImage"><filename>image.gif</filename></image>

    </product>
    EOT

    # XXX: current behavior sucks, the attributes are tossed if this is a text node
    expected_product_hash = {
      'weight' => "0.5",
      'image' => {'type' => 'ProductImage', 'filename' => 'image.gif' },
    }

    Crack::XML.parse(product_xml)["product"].should == expected_product_hash
  end

  should "should handle unescaping from xml (ActiveResource Compatible)" do
    xml_string = '<person><bare-string>First &amp; Last Name</bare-string><pre-escaped-string>First &amp;amp; Last Name</pre-escaped-string></person>'
    expected_hash = {
      'bare_string'        => 'First & Last Name',
      'pre_escaped_string' => 'First &amp; Last Name'
    }

    Crack::XML.parse(xml_string)['person'].should == expected_hash
  end
  
  should "handle an empty xml string" do
    Crack::XML.parse('').should == {}
  end
  
  # As returned in the response body by the unfuddle XML API when creating objects
  should "handle an xml string containing a single space" do
    Crack::XML.parse(' ').should == {}
  end
end
