module RequestRecorder
  class Frontend
    class << self
      def render(log)
        convert_console_to_html_colors(log).gsub("\n", "<br/>")
      end

      private

      def convert_console_to_html_colors(string)
        string = string.dup
        {
          "0" => "inherit",
          "0;1" => "inherit",
          "4;35;1" => "red",
          "4;36;1" => "blue",
        }.each do |console, html|
          string.gsub!("\e[#{console}m","</span><span style='color:#{html}'>")
        end

        "<span>#{string}</span>"
      end
    end
  end
end
