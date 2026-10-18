Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:3001").split(","))
    resource "/graphql", headers: :any, methods: %i[post options]
  end
end
