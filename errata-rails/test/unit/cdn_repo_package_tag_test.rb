require 'test_helper'

class CdnRepoPackageTagTest < ActiveSupport::TestCase
  test "tag template expansion" do
    tag = CdnRepoPackageTag.new(:cdn_repo_package_id => 1)
    build = BrewBuild.new(:package_id => tag.cdn_repo_package.package_id, :version => '1.2.3', :release => '4.5')

    tag.tag_template = 'test-{{version}}-test'
    assert tag.valid?
    assert_equal 'test-1.2.3-test', tag.tag_for_build(build)

    tag.tag_template = 'test-{{release}}-test'
    assert tag.valid?
    assert_equal 'test-4.5-test', tag.tag_for_build(build)

    tag.tag_template = 'test-{{ReLeaSE}}-test'
    assert tag.valid?
    assert_equal 'test-4.5-test', tag.tag_for_build(build)

    tag.tag_template = 'test-{{version}}-{{ version}}-{{  RELEASE  }}'
    assert tag.valid?
    assert_equal 'test-1.2.3-1.2.3-4.5', tag.tag_for_build(build)

    tag.tag_template = 'test-{{FOOBAR}}-test'
    refute tag.valid?
    assert_equal 'test-{{FOOBAR}}-test', tag.tag_for_build(build)
  end

  test "templates using number dot groups" do
    tag = CdnRepoPackageTag.new(:cdn_repo_package_id => 1)
    build = BrewBuild.new(:package_id => tag.cdn_repo_package.package_id, :version => 'v21.5.4.3.2-5', :release => 'rel_1.2.3')

    tag.tag_template = 'test-{{version(2)}}-test'
    assert tag.valid?
    assert_equal 'test-21.5-test', tag.tag_for_build(build)

    tag.tag_template = '{{version(3)}}-{{release(1)}}'
    assert tag.valid?
    assert_equal '21.5.4-1', tag.tag_for_build(build)

    tag.tag_template = '{{version(3)}}-{{release}}'
    assert tag.valid?
    assert_equal '21.5.4-rel_1.2.3', tag.tag_for_build(build)

    tag.tag_template = '{{version(10)}}-{{release(5)}}'
    assert tag.valid?
    assert_equal '21.5.4.3.2-1.2.3', tag.tag_for_build(build)

    tag.tag_template = '{{version(x)}}'
    refute tag.valid?

    tag.tag_template = '{{release()}}'
    refute tag.valid?
  end

  test "tag validation" do
    tag = CdnRepoPackageTag.new(:cdn_repo_package_id => 1)
    build = BrewBuild.new(:package_id => tag.cdn_repo_package.package_id, :version => '1.2.3', :release => '4.5')

    # Unsupported attribute
    tag.tag_template = 'test-{{bogus}}-test'
    refute tag.valid?

    # Invalid character
    tag.tag_template = 'test!'
    refute tag.valid?

    # Too short
    tag.tag_template = 't'
    refute tag.valid?

    # Too long
    tag.tag_template = 't' * 81
    refute tag.valid?

    # These are OK
    tag.tag_template = 't' * 50
    assert tag.valid?

    tag.tag_template = 'test_123_HELLO-{{release}}_1'
    assert tag.valid?

  end

end
