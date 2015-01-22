# Match IDs with dots in them
id_pattern = /[^\/]+/
ResqueWeb::Plugins::ResqueStatus::Engine.routes.draw do
  resources :statuses,  :only => [:show,:index] do
    member do
      post :kill
    end
    collection do
      resources :clear, :only => [:destroy]
    end
  end
  root 'statuses#index'


end
