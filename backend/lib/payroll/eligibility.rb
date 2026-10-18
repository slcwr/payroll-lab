# frozen_string_literal: true

module Payroll
  # 年齢到達・資格の取得／喪失に関する判定。
  #
  # 社会保険では「年齢に達した日」は誕生日の前日とされる（年齢計算ニ関スル法律）。
  # そのため 4月1日生まれの人は 3月31日に到達し、3月が「到達月」になる。
  module Eligibility
    module_function

    # n歳に達する日（誕生日の前日）
    def age_reached_on(birth_date, age)
      birth_date.next_year(age) - 1
    end

    # 指定月（月初日）が n歳の到達月か
    def reaches_age_in_month?(birth_date, age, month_start)
      d = age_reached_on(birth_date, age)
      d.year == month_start.year && d.month == month_start.month
    end

    # 指定月の末日時点で n歳に達しているか（到達月を含む）
    def reached_age_by_month?(birth_date, age, month_start)
      age_reached_on(birth_date, age) <= Date.new(month_start.year, month_start.month, -1)
    end

    # 介護保険第2号被保険者（40歳到達月〜65歳到達月の前月）
    def nursing_care_insured?(birth_date, month_start)
      reached_age_by_month?(birth_date, 40, month_start) && !reached_age_by_month?(birth_date, 65, month_start)
    end

    # 厚生年金は70歳到達月の前月まで
    def welfare_pension_insured?(birth_date, month_start)
      !reached_age_by_month?(birth_date, 70, month_start)
    end

    # 健康保険（協会けんぽ）は75歳で後期高齢者医療へ移る。
    # 後期高齢者医療は75歳の誕生日当日に資格を得るため、健康保険はその誕生日に資格を喪失し、
    # 誕生日の属する月からは健康保険料が発生しない（ここは「前日」ではなく誕生日で判定する）。
    def health_insured?(birth_date, month_start)
      d = birth_date.next_year(75)
      Date.new(d.year, d.month, 1) > month_start
    end

    # 社会保険の保険料が発生する月か。
    # 資格取得日の属する月から、資格喪失日（退職日の翌日）の属する月の前月までが対象。
    def social_insurance_month?(hired_on:, retired_on:, month_start:)
      return false if hired_on > Date.new(month_start.year, month_start.month, -1)
      return true if retired_on.nil?

      lost_on = retired_on + 1
      Date.new(lost_on.year, lost_on.month, 1) > month_start
    end

    # 当月の在籍日数（暦日）
    def enrolled_days(hired_on:, retired_on:, period:)
      from = [hired_on, period.start_date].max
      to = [retired_on || period.end_date, period.end_date].min
      to < from ? 0 : (to - from).to_i + 1
    end
  end
end
