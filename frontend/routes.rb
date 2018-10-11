ArchivesSpace::Application.routes.draw do
  [AppConfig[:frontend_proxy_prefix], AppConfig[:frontend_prefix]].uniq.each do |prefix|
    scope prefix do
      match('/plugins/history' => 'history#index', :via => [:get])
      match('/plugins/history/:model/:id' => 'history#record', :via => [:get])
      match('/plugins/history/:model/:id/:version' => 'history#version', :via => [:get])
    end
  end
end
