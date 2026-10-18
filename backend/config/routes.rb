Rails.application.routes.draw do
  post "/graphql", to: "graphql#execute"
  get "/up", to: "rails/health#show", as: :rails_health_check
end
