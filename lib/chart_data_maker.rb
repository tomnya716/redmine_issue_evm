# Chart data maker
# This module is a function of create data to display chart.
# Requires CalculateEvm class.
#
module ChartDataMaker
  # Create data for display chart for chartjs.
  #
  # 1. basis EVM data for chart
  # 2. You chseck forecast option is on, add follows data
  # * BAC top line
  # * EAC top line
  # * forecast AC (forecast finish date)
  # * forecast EV (forecast finish date)
  #
  # @param [object] evm calculation EVN object
  # @return [hash] chart data
  def evm_chart_data(evm)
    # start date and end date of chart
    chart_duration = chart_duration(evm)
    # always within dyue date
    planned_value = evm.pv_actual.cumulative_pv.select { |k, _v| k <= evm.pv_actual.due_date }
    baseline_value = evm.pv_baseline.cumulative_pv.select { |k, _v| k <= evm.pv_baseline.due_date } if evm.pv_baseline.present?
    # less than basis date or finished date
    chart_adjust_date = [evm.finished_date, evm.basis_date].compact.min
    earned_value = evm.ev.cumulative_ev.select { |k, _v| k <= chart_adjust_date }
    actual_value = evm.ac.cumulative_ac.select { |k, _v| k <= chart_adjust_date }
    # init forecast chart data
    bac_top_line = {}
    eac_top_line = {}
    actual_cost_forecast = {}
    earned_value_forecast = {}
    # forecast
    if evm.forecast
      # for chart
      # top line of BAC
      bac_top_line[chart_duration[:start_date]] = evm.bac
      bac_top_line[chart_duration[:end_date]] = evm.bac
      # top line of EAC
      eac_top_line[chart_duration[:start_date]] = evm.eac
      eac_top_line[chart_duration[:end_date]] = evm.eac
      # forecast line of AC
      actual_cost_forecast[evm.basis_date] = evm.today_ac
      actual_cost_forecast[evm.forecast_finish_date] = evm.eac
      # forecast line of EV
      earned_value_forecast[evm.basis_date] = evm.today_ev
      earned_value_forecast[evm.forecast_finish_date] = evm.bac
    end

    labels = []
    plotdata_planned_value = []
    plotdata_actual_cost = []
    plotdata_earned_value = []
    plotdata_baseline_value = []
    plotdata_planned_value_daily = []
    plotdata_bac_top_line = []
    plotdata_eac_top_line = []
    plotdata_actual_cost_forecast = []
    plotdata_earned_value_forecast = []

    (chart_duration[:start_date]..chart_duration[:end_date]).each do |chart_date|
      labels << chart_date.to_time(:local).to_i * 1000
      plotdata_planned_value << evm_round(planned_value[chart_date])
      plotdata_actual_cost << evm_round(actual_value[chart_date])
      plotdata_earned_value << evm_round(earned_value[chart_date])
      plotdata_baseline_value << evm_round(baseline_value[chart_date]) if evm.pv_baseline.present?
      plotdata_planned_value_daily << evm_round(evm.pv.daily_pv[chart_date])
      plotdata_bac_top_line << evm_round(bac_top_line[chart_date])
      plotdata_eac_top_line << evm_round(eac_top_line[chart_date])
      plotdata_actual_cost_forecast << evm_round(actual_cost_forecast[chart_date])
      plotdata_earned_value_forecast << evm_round(earned_value_forecast[chart_date])
    end

    chart_data = {}
    chart_data[:labels] = labels
    chart_data[:pv] = plotdata_planned_value.to_json
    chart_data[:ac] = plotdata_actual_cost.to_json
    chart_data[:ev] = plotdata_earned_value.to_json
    chart_data[:pv_daily] = plotdata_planned_value_daily.to_json
    chart_data[:baseline] = plotdata_baseline_value.to_json
    chart_data[:bac] = plotdata_bac_top_line.to_json
    chart_data[:eac] = plotdata_eac_top_line.to_json
    chart_data[:ac_forecast] = plotdata_actual_cost_forecast.to_json
    chart_data[:ev_forecast] = plotdata_earned_value_forecast.to_json
    chart_data
  end

  # Create data for display performance chart.
  #
  # @return [hash] data for performance chart
  def performance_chart_data(evm)
    chart_data = {}
    # less than basis date or finished date
    chart_adjust_date = [evm.finished_date, evm.basis_date].compact.min
    adjusted_ev = evm.ev.cumulative_ev.select { |k, _v| k <= chart_adjust_date }
    new_ev = complement_evm_value adjusted_ev
    adjusted_ac = evm.ac.cumulative_ac.select { |k, _v| k <= chart_adjust_date }
    new_ac = complement_evm_value adjusted_ac
    new_pv = complement_evm_value evm.pv.cumulative_pv
    performance_min_date = [new_ev.keys.min,
                            new_ac.keys.min,
                            new_pv.keys.min].max
    performance_max_date = [new_ev.keys.max,
                            new_ac.keys.max,
                            new_pv.keys.max].min
    labels = []
    spi = []
    cpi = []
    cr = []
    (performance_min_date..performance_max_date).each do |date|
      labels << date.to_time(:local).to_i * 1000
      spi << evm_round((new_ev[date] / new_pv[date]))
      cpi << evm_round((new_ev[date] / new_ac[date]))
      cr << evm_round(((new_ev[date] / new_pv[date]) * (new_ev[date] / new_ac[date])))
    end
    chart_data[:labels] = labels
    chart_data[:spi] = spi.to_json
    chart_data[:cpi] = cpi.to_json
    chart_data[:cr] = cr.to_json
    chart_data
  end

  # EVM value of Each date. for performance chart.
  #
  # @param [hash] evm_hash EVM hash
  # @return [hash] EVM value of All date
  def complement_evm_value(evm_hash)
    before_date = evm_hash.keys.min
    before_value = evm_hash[before_date]
    temp = {}
    evm_hash.each do |date, value|
      dif_days = (date - before_date - 1).to_i
      dif_value = (value - before_value) / dif_days
      if dif_days.positive?
        sum_value = 0.0
        (1..dif_days).each do |add_days|
          tmpdate = before_date + add_days
          sum_value += dif_value
          temp[tmpdate] = before_value + sum_value
        end
      end
      before_date = date
      before_value = value
      temp[date] = value
    end
    temp
  end

  # round function for evm value
  #
  # @param [number] evm_value EVM hash value
  # @return [number] EVM value or nil
  def evm_round(evm_value)
    evm_value.round(2) if evm_value.present?
  end

  # Get duretion of chart
  #
  # @param [evm] evm evm object
  # @return [hash] duration chart area
  def chart_duration(evm)
    # duration
    duration = {}
    # start date
    min_date = [evm.pv.start_date, evm.pv_actual.start_date, evm.ev.min_date, evm.ac.min_date]
    min_date << evm.pv_baseline.start_date if evm.pv_baseline.present?
    duration[:start_date] = min_date.min
    # end date
    max_date = [evm.pv.due_date, evm.pv_actual.due_date]
    max_date << evm.forecast_finish_date if evm.forecast
    max_date << evm.pv_baseline.due_date if evm.pv_baseline.present?
    if evm.finished_date.present?
      max_date << evm.ev.max_date
      max_date << evm.ac.max_date
    else
      max_date << evm.ev.cumulative_ev.keys.max
      max_date << evm.ac.cumulative_ac.keys.max
    end
    duration[:end_date] = max_date.max
    duration
  end
end