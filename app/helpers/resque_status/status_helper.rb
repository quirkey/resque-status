module ResqueStatus
  module StatusHelper
    def status_poll(start)
      if @polling
        text = "<a href='#{statuses_path}?start=#{start}'>Last Updated: #{Time.now.strftime("%H:%M:%S")}</a>"
      else
        text = "<a href='#{statuses_path}?start=#{start}' rel='poll'>Live Poll</a>"
      end
      "<p class='poll'>#{text}</p>"
    end
  end
end
