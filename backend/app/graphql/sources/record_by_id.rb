module Sources
  # id で1件ずつ要求されたレコードを、1回の IN クエリでまとめて取る
  class RecordById < GraphQL::Dataloader::Source
    def initialize(model)
      @model = model
    end

    def fetch(ids)
      records = @model.where(id: ids).index_by(&:id)
      ids.map { records[_1] }
    end
  end
end
