require_relative 'lib/history_resolver.rb'
require_relative 'lib/history_request_handler.rb'

[
 Repository,
 Accession,
 Resource,
 ArchivalObject,
 DigitalObject,
 DigitalObjectComponent,
 Assessment,
 Classification,
 ContainerProfile,

 AgentPerson,
 AgentCorporateEntity,
 AgentFamily,
 AgentSoftware,
 Location,
 Subject,
 TopContainer,
].each do |model|

  History.register_model(model)

end

# Load custom schema
JSONModel::JSONModel(:history)

URIResolver.register_resolver(HistoryResolver)


# A marker mixin used to figure out whether we care about any of this
module SystemStatusDisabled; end

# wiring for asam
begin
  StatCounter
  SystemStatus.group('History', ['History Updates', 'Last History Update'])
  SystemStatus.update('History Updates', :no, 'History enabled. Waiting for updates ...')
  SystemStatus.update('Last History Update', :no, 'History enabled. Waiting for updates ...')
rescue => e
  Log.info "Install asam to enable history monitoring"

  # asam isn't active so fake SystemStatus and StatCounter
  class SystemStatus
    include SystemStatusDisabled

    def self.method_missing(meth, *args)
      # don't complain, nobody cares
    end
  end

  class StatCounter
    include SystemStatusDisabled

    def initialize(*args)
      # don't complain, nobody cares
    end

    def method_missing(meth, *args)
      # don't complain, nobody cares
    end

    def self.method_missing(meth, *args)
      # don't complain, nobody cares
    end
  end
end

# a new impl of dump_sanitized that preserves uniqueness
# unfortunately procs that can't be called (because they need a param,
# eg. inherit_if) can't be uniquified, so we just sub out the changy bits
require 'digest/sha1'
class AppConfig
  def self.digest
    protected_terms = /(key|password|secret)/
    Digest::SHA1.hexdigest(Hash[@@parameters.map {|k, v|
           if k == :db_url
             [k, AppConfig[:db_url_redacted]]
           elsif k.to_s =~ protected_terms or v.to_s =~ protected_terms
             [k, Digest::SHA1.hexdigest(v.to_s)]
           elsif v.is_a? (Proc)
             [k, v.parameters.empty? ? v.call : v.to_s]
           else
             [k, v]
           end
         }.sort].to_s.gsub(/\#<Proc:[^>]+>/, 'Proc'))
  end
end

# determine system version
History.ensure_system_version
