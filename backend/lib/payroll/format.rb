# frozen_string_literal: true

module Payroll
  # 計算根拠（basis）の表示用フォーマット
  module Format
    module_function

    def yen(value)
      v = value.to_i
      "#{v.negative? ? '-' : ''}#{v.abs.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}円"
    end

    # 70 → "1時間10分"。計算は分単位の正確な値で行い、表示だけ時間・分にする
    def hours(minutes)
      h, m = minutes.divmod(60)
      return "#{m}分" if h.zero?

      m.zero? ? "#{h}時間" : "#{h}時間#{m}分"
    end

    def percent(rate)
      "#{(rate * 100).to_s('F').sub(/\.?0+\z/, '')}%"
    end

    def per_mille(rate)
      "#{(rate * 1000).to_s('F').sub(/\.?0+\z/, '')}/1000"
    end

    def decimal(value)
      value.to_s("F").sub(/\.?0+\z/, "")
    end
  end
end
