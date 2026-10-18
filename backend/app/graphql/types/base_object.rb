module Types
  class BaseObject < GraphQL::Schema::Object
    field_class Types::BaseField

    private

    def dataloader_record(model, id)
      dataloader.with(Sources::RecordById, model).load(id)
    end
  end
end
