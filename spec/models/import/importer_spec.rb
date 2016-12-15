require 'spec_helper'
include Import

describe Import::Importer do

  describe "should return the right error messages" do
    before :all do
      @user = create(:user, { id: 456 })
      @archivist = create(:user, { id: 123 })
      @archivist.roles << Role.new(name: "archivist")
    end

    it "when urls are empty" do
      settings = {}
      urls = []

      importer = Importer.new(settings)
      expect(importer.check_errors(urls, @user)).to eq "Did you want to enter a URL?"
    end

    it "there is an external author name but importing_for_others is NOT turned on" do
      settings = { external_author_name: "Foo", importing_for_others: "0" }
      urls = %w(url1 url2)

      importer = Importer.new(settings)
      expect(importer.check_errors(urls, @user)).to start_with "You have entered an external author name"
    end

    it "there is an external author email but importing_for_others is NOT turned on" do
      settings = { external_author_email: "Foo", importing_for_others: "0" }
      urls = %w(url1 url2)

      importer = Importer.new(settings)
      expect(importer.check_errors(urls, @user)).to start_with "You have entered an external author name"
    end

    it "the current user is NOT an archivist but importing_for_others is turned on" do
      settings = { importing_for_others: "1" }
      urls = %w(url1 url2)

      importer = Importer.new(settings)
      expect(importer.check_errors(urls, @user)).to start_with "You may not import stories by other users"
    end

    it "the current user is NOT an archivist and is importing over the maximum number of works" do
      max = ArchiveConfig.IMPORT_MAX_WORKS
      settings = { importing_for_others: 0, import_multiple: "works" }
      urls = Array.new(max + 1) { |i| "url#{i}" }

      importer = Importer.new(settings)
      expect(importer.check_errors(urls, @user)).to start_with "You cannot import more than #{max}"
    end

    it "the current user is an archivist and is importing over the maximum number of works" do
      max = ArchiveConfig.IMPORT_MAX_WORKS_BY_ARCHIVIST
      settings = { importing_for_others: 0, import_multiple: "works" }
      urls = Array.new(max + 1) { |i| "url#{i}" }

      importer = Importer.new(settings)
      expect(importer.check_errors(urls, @archivist)).to start_with "You cannot import more than #{max}"
    end

  end
end
