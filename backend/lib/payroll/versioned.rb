# frozen_string_literal: true

module Payroll
  # 適用開始日つきの値の履歴。
  # 「ある日時点で有効な値」を引けるようにし、法改正をデータの追加だけで表現する。
  class Versioned
    Entry = Data.define(:effective_from, :value)

    def initialize(entries)
      @entries = entries.map { |e| Entry.new(effective_from: to_date(e.fetch(:effective_from)), value: e.fetch(:value)) }
                        .sort_by(&:effective_from)
      dup = @entries.map(&:effective_from).tally.select { |_, n| n > 1 }.keys
      raise Error, "適用開始日が重複しています: #{dup.join(', ')}" if dup.any?
    end

    # 指定日に有効な値。まだ一度も適用されていなければ nil。
    def at(date)
      entry_at(date)&.value
    end

    def entry_at(date)
      date = to_date(date)
      @entries.reverse_each.find { |e| e.effective_from <= date }
    end

    private

    def to_date(v)
      v.is_a?(Date) ? v : Date.parse(v.to_s)
    end
  end
end
