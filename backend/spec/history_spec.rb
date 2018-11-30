require 'spec_helper'
require 'factory_bot'


describe 'History' do

  describe "Resource records" do
    let!(:resource) do
      resource = create(:json_resource,
                        :title => 'the original title')

      resource.title = 'a new title'
      resource.save

      resource
    end

    it 'adds a history list to archival record types' do
      # history will contain a URI for the history record.  Resolve it.
      json = Resource.to_jsonmodel(resource.id)

      expect(json['history'].length).to eq(1)

      resolved = URIResolver.resolve_references(json, ['history'])
      expect(resolved['history'].length).to eq(2)
    end

    it 'calculates differences between versions' do
      diff = History.diff('resource', resource.id, 0, 1)

      expect(diff[:_changes]['title'][:_from]).to eq('the original title')
      expect(diff[:_changes]['title'][:_to]).to eq('a new title')
    end

    it 'restores a version of a record when requested' do
      History.restore_version!('resource', resource.id, 0)
      expect(Resource.get_or_die(resource.id).title).to eq('the original title')
    end

    it 'fetches previous versions' do
      formatter = HistoryFormatter.new
      full = formatter.get_version('resource', resource.id, 0, 'json', true, 0)
      expect(full['title']).to eq('the original title')
    end

    it 'fetches version metadata' do
      formatter = HistoryFormatter.new
      data = formatter.get_version('resource', resource.id, 0, 'data', true, 0)
      data.values[0][:uri].should eq(resource.uri)
    end

    it 'fetches previous full set (json + version metadata + diff)' do
      formatter = HistoryFormatter.new
      full = formatter.get_version('resource', resource.id, 0, 'full', true, 0)

      expect(full[:json]['title']).to eq('the original title')
      expect(full[:data].length).to eq(1)

      expect(full[:diff][:_changes]).to be_empty
      expect(full[:diff][:_adds]).to be_empty
      expect(full[:diff][:_removes]).to be_empty
    end

  end

  describe "Archival objects" do
    let!(:resource) do
      create(:json_resource,
             :title => 'the original title')
    end

    let!(:archival_object) do
      ao = create(:json_archival_object,
                  :title => 'the original AO title',
                  :resource => {:ref => resource.uri})

      ao.title = 'a new AO title'
      ao.save

      ao
    end

    it "can restore an AO version too" do
      History.restore_version!('archival_object', archival_object.id, 0)
      expect(ArchivalObject.get_or_die(archival_object.id).title).to eq('the original AO title')
    end

  end


end
