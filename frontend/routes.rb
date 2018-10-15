ArchivesSpace::Application.routes.draw do
  [AppConfig[:frontend_proxy_prefix], AppConfig[:frontend_prefix]].uniq.each do |prefix|
    scope prefix do
      match('/history' => 'history#index', :via => [:get])
      match('/history/:model/:id' => 'history#record', :via => [:get])
      match('/history/:model/:id/:version' => 'history#version', :via => [:get])
      match('/history/:model/:id/:version/:diff' => 'history#version', :via => [:get])
    end
  end
end
