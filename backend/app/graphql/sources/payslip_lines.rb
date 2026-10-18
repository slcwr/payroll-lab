module Sources
  # 複数の明細の行を1回のクエリでまとめて取る
  class PayslipLines < GraphQL::Dataloader::Source
    def fetch(payslip_ids)
      lines = PayslipLine.where(payslip_id: payslip_ids).order(:payslip_id, :position).group_by(&:payslip_id)
      payslip_ids.map { lines.fetch(_1, []) }
    end
  end
end
