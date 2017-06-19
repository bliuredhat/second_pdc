module SharedControllerNav
  TIME_SINCE = ['today', 'yesterday', 'last_week', 'last_month'].freeze
  
  protected
  def time_since
    @timeframe = params[:timeframe]
    unless TIME_SINCE.include?(@timeframe)
      @timeframe = 'today'
    end
    
    now = Time.now.at_beginning_of_day
    class << now
      def today
        return self.at_beginning_of_day
      end
      def last_week
        return self.ago(3600*7*24)
      end
      def last_month
        return self.ago(3600*30*24) # close enough..
      end
    end
    
    @since = now.send(@timeframe)
    class << @timeframe
      def capitalize
        return "#{self.split('_').collect { |s| s.capitalize}.join(' ')}"
      end      
    end
    
  end

end

