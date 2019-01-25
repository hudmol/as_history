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

    let!(:deleted_resource) do
      resource = create(:json_resource,
                        :title => 'the walking dead')

      resource.delete

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

    it 'will not restore a version of a record if the user lacks update permissions' do
      create_nobody_user

      as_test_user('nobody') do
        handler = HistoryRequestHandler.new(Thread.current[:active_test_user])
        expect{handler.restore_version!('resource', resource.id, 0)}.to raise_error(AccessDeniedException)
      end
    end

    it 'restores a version of a deleted record' do
      (obj, json) = History.restore_version!('resource', deleted_resource.id, 0)

      # ideally, the restored record would have the same id as it previously had
      # unfortunately this requires undesirable hackery
      # expect(Resource.get_or_die(deleted_resource.id).title).to eq('the walking dead')
      expect(Resource.get_or_die(obj.id).title).to eq('the walking dead')
    end

    it 'fetches previous versions' do
      handler = HistoryRequestHandler.new(Thread.current[:active_test_user], {:mode => 'json'})

      json = handler.get_history('resource', resource.id, 0)
      expect(json['title']).to eq('the original title')
    end

    it 'fetches version metadata' do
      handler = HistoryRequestHandler.new(Thread.current[:active_test_user], {:mode => 'data'})

      data = handler.get_history('resource', resource.id, 0)
      data.values[0][:uri].should eq(resource.uri)
    end

    it 'fetches a full set of data (json + version metadata + diff + version list)' do
      handler = HistoryRequestHandler.new(Thread.current[:active_test_user], {:mode => 'full'})

      full = handler.get_history('resource', resource.id, 1)

      expect(full.has_key?(:data)).to be(true)
      expect(full.has_key?(:json)).to be(true)
      expect(full.has_key?(:diff)).to be(true)
      expect(full.has_key?(:versions)).to be(true)
      expect(full.has_key?(:can_restore)).to be(true)

      expect(full[:versions].length).to eq(2)

      expect(full[:json]['title']).to eq('a new title')

      expect(full[:diff][:_changes]['title'][:_from]).to eq('the original title')
      expect(full[:diff][:_changes]['title'][:_to]).to eq('a new title')
      expect(full[:diff][:_adds]).to be_empty
      expect(full[:diff][:_removes]).to be_empty

      expect(full[:can_restore]).to eq(true)
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
