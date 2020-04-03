class HistoryController < ApplicationController

  set_access_control  :public => [:index, :record, :version, :restore]

  @@enum_handlers = []
  @@top_fields = []
  @@skip_fields =
    [
     'lock_version',
     'created_by',
     'last_modified_by',
     'create_time',
     'system_mtime',
     'user_mtime',
     'jsonmodel_type',
     'uri',
     'history',
     'agent_type',
     'tree',
    ]


  def index
    @title = "History | Recent updates"
    args = {:mode => 'full'}
    url = '/history'

    if params[:model]
      url += '/' + params[:model]
      @title += " to #{params[:model]} records"
    end

    if params[:user]
      args[:user] = params[:user]
      @title += " by #{params[:user]}"
    end

    if params[:time]
      args[:at] = params[:time]
      @title += " at #{params[:time]}"
    end

    @version = JSONModel::HTTP.get_json(url, args)

    flash.now[:info] = I18n.t('plugins.history.no_version_error_message') unless @version

    render :version
  end


  def restore
    resp = JSONModel::HTTP.post_form("/history/#{params[:model]}/#{params[:id]}/#{params[:version]}/restore")
    if resp.code === "200"
      flash[:success] = I18n.t('plugins.history.restore.success_message')
      id = JSONModel.parse_reference(ASUtils.json_parse(resp.body)['uri'])[:id]
      redirect_to(:controller => :history, :action => :record, :model => params[:model], :id => id)
    else
      flash[:error] = I18n.t('plugins.history.restore.error_message', :errors => resp.body)
      redirect_to(:controller => :history, :action => :record, :model => params[:model], :id => params[:id])
    end
  end


  def record
    @title = "History | Revisions for: #{params[:model]} / #{params[:id]}"
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}", :mode => 'full')

    flash.now[:info] = I18n.t('plugins.history.no_version_error_message') unless @version

    render :version
  end


  def version
    @title = "History | Version: #{params[:model]} / #{params[:id]} .v#{params[:version]}"
    @version = JSONModel::HTTP.get_json("/history/#{params[:model]}/#{params[:id]}/#{params[:version]}", :mode => 'full', :diff => params[:diff])

    flash.now[:info] = I18n.t('plugins.history.no_version_error_message') unless @version
  end


  helper_method :skip_fields
  def skip_fields
    @@skip_fields
  end


  def self.add_skip_field(field)
    @@skip_fields << field
  end


  helper_method :top_fields
  def top_fields
    @@top_fields
  end


  def self.add_top_fields(fields)
    @@top_fields += fields
  end


  helper_method :classes_for_diff_mode
  def classes_for_diff_mode(mode)
    @@diff_mode_class_map ||= {
      :clean => 'history-clean-field',
      :diff => 'history-diff-field',
      :add => 'history-change history-add',
      :remove => 'history-change history-remove',
    }

    @@diff_mode_class_map.fetch(mode, 'history-clean-field')
  end


  helper_method :is_a_diff
  def is_a_diff(json)
    json.is_a?(Hash) && json.has_key?('_diff')
  end


  helper_method :get_diff
  def get_diff(json)
    return false unless is_a_diff(json)
    json['_diff']
  end


  helper_method :clean_for_render
  def clean_for_render(json, top)
    json.reject{|k,v| skip_fields.include?(k)}
        .reject{|k,v| v.is_a?(Array) && v.empty?}
        .reject{|k,v| (['repository', 'parent'].include?(k) && !top)}
        .sort_by{|k,v| (@@top_fields.index(k) || 9999) }
  end


  helper_method :history_uri
  def history_uri(model, id, version, opts = {})
    uri_bits = ['history']
    if opts[:restore]
      uri_bits.push('restore')
      version = opts[:restore]
      opts.delete(:restore)
    end
    uri = '/' + (uri_bits + [model, id, version]).join('/')
    uri += '?' + opts.map{|k,v| "#{k}=#{v}"}.join('&') unless opts.empty?

    uri
  end


  helper_method :version_display
  def version_display(model, id, version)
    "#{model} / #{id} .v<strong>#{version}</strong>".html_safe
  end


  helper_method :model_pl
  def model_pl
    model = @version['data'].values.first['model']
    if model.start_with? 'agent_'
      'agents'
    elsif model == 'archival_object'
      'resources'
    else
      model.pluralize
    end
  end


  helper_method :json
  def json
    @version['json']
  end


  helper_method :data
  def data
    return {} unless @version
    @version['data'].values.first
  end


  helper_method :previous_version
  def previous_version
    return false unless @version

    this_v = data.fetch('lock_version', false)
    return false unless this_v

    prev_v = 0
    @version['versions'].values.map{|v| v['lock_version']}.each do |v|
      prev_v = v if v > prev_v && v < this_v
    end

    prev_v
  end


  helper_method :diff_version
  def diff_version
    params[:diff] || previous_version
  end


  helper_method :supported_models
  def supported_models
    @supported_models ||= MemoryLeak::Resources.get(:history_models).map {|m| {:model => m.underscore, :label => m.gsub(/(.)([A-Z])/, '\1 \2')} }
  end


  helper_method :enum_translator
  def enum_translator(type, field, value)
    return value if type.nil? # this can happen with deleted versions
    return value unless value.is_a?(String)
    return value if value.index(' ')

    enum_name = false

    @@enum_handlers.each do |handler|
      if (enum_name = handler.call(type, field))
        break
      end
    end

    enum_name ||= [type, field].join('_')

    I18n.t("enumerations.#{enum_name}.#{value}", :default => I18n.t("enumerations.#{field}.#{value}", :default => value))
  end


  def self.add_enum_handler(&block)
    # the block should take a type and a field and return an enum name
    @@enum_handlers << block
  end


  helper_method :version_set_label
  def version_set_label(params, data)
    label = params['id'] ? "#{params['model']} / #{params['id']} -- #{data['short_label']}"
                         : t('plugins.history.recent_updates')
    label += " to #{params['model']} records" if params['model'] && !params[:id]
    label += " by #{params['user']}" if params['user']
    label += " at #{params['time']}" if params['time']

    label
  end

end
