module Fluent
  require 'fluent/plugin/in_tail'
  require 'fluent/mixin/config_placeholders'

  class TailMultilineInput_EX < TailInput

    class MultilineTextParser_EX < TextParser
      def configure(conf, required=true)
        format = conf['format']
        if format == nil
          raise ConfigError, "'format' parameter is required"
        elsif format[0] != ?/ || format[format.length-1] != ?/ 
          raise ConfigError, "'format' should be RegEx. Template is not supported in multiline mode"
        end

        begin
          @regex = Regexp.new(format[1..-2],Regexp::MULTILINE)
          if @regex.named_captures.empty?
            raise "No named captures"
          end
        rescue
          raise ConfigError, "Invalid regexp in format '#{format[1..-2]}': #{$!}"
        end

        @parser = RegexpParser.new(@regex, conf)

        format_firstline = conf['format_firstline']
        if format_firstline
          # Use custom matcher for 1st line
          if format_firstline[0] == '/' && format_firstline[format_firstline.length-1] == '/'
            @regex = Regexp.new(format_firstline[1..-2])
          else
            raise ConfigError, "Invalid regexp in format_firstline '#{format_firstline[1..-2]}': #{$!}"
          end
        end

        return true
      end

      def match_firstline(text)
        @regex.match(text)
      end
    end

    Plugin.register_input('tail_multiline_ex', self)

    FORMAT_MAX_NUMS = 20

    config_param :format, :string
    config_param :format_firstline, :string, :default => nil
    config_param :rawdata_key, :string, :default => nil
    config_param :auto_flush_sec, :integer, :default => 1
    config_param :read_newfile_from_head, :bool, :default => false
    (1..FORMAT_MAX_NUMS).each do |i|
      config_param "format#{i}".to_sym, :string, :default => nil
    end

    config_param :expand_date, :bool, :default => true
    config_param :read_all, :bool, :default => true
    config_param :refresh_interval, :integer, :default => 3600

    include Fluent::Mixin::ConfigPlaceholders    

    def initialize
      super
      @locker = Monitor.new
      @logbuf = nil
      @logbuf_flusher = CallLater_EX::new
      @ready = false
    end

    def configure(conf)
      if conf['format'].nil?
        invalids = conf.keys.select{|k| k =~ /^format(\d+)$/ and not (1..FORMAT_MAX_NUMS).include?($1.to_i)}
        if invalids.size > 0
          raise ConfigError, "invalid number formats (valid format number:1-#{FORMAT_MAX_NUMS}):" + invalids.join(",")
        end
        format_index_list = conf.keys.select{|s| s =~ /^format\d+$/}.map{|v| (/^format(\d+)$/.match(v))[1].to_i}
        if (1..format_index_list.max).map{|i| conf["format#{i}"]}.include?(nil)
          raise Fluent::ConfigError, "jump of format index found"
        end
        formats = (1..FORMAT_MAX_NUMS).map {|i|
          conf["format#{i}"]
        }.delete_if {|format|
          format.nil?
        }.map {|format|
          format[1..-2]
        }.join
        conf['format'] = '/' + formats + '/'
      end
      super
      if @tag.index('*')
        @tag_prefix, @tag_suffix = @tag.split('*')
        @tag_suffix ||= ''
      else
        @tag_prefix = nil
        @tag_suffix = nil
      end
      @watchers = {}
      @refresh_trigger = TailWatcher::TimerWatcher.new(@refresh_interval, true, &method(:refresh_watchers))
      if read_newfile_from_head and @pf
        # Tread new file as rotated file
        # Use temp file inode number as previos logfile
        @paths.map {|path|
          pe = @pf[path]
          if pe.read_inode == 0
            require 'tempfile'
            tmpfile = Tempfile.new('gettempinode')
            pe.update(File.stat(tmpfile).ino, 0)
            tmpfile.unlink
          end
        }
      end
    end

    def expand_paths
      date = Time.now
      paths = []
      for path in @paths
        if @expand_date
          path = date.strftime(path)
        end
        paths += Dir.glob(path)
      end
      paths
    end

    def refresh_watchers
      paths = expand_paths
      missing = @watchers.keys - paths
      added = paths - @watchers.keys

      stop_watch(missing) unless missing.empty?
      start_watch(added) unless added.empty?
    end

    def start_watch(paths)
      paths.each do |path|
        if @pf
          pe = @pf[path]
          if @read_all && pe.read_inode == 0
            inode = File::Stat.new(path).ino
            pe.update(inode, 0)
          end
        else
          pe = nil
        end

        watcher = TailExWatcher_EX.new(path, @rotate_wait, pe, &method(:receive_lines))
        watcher.attach(@loop)
        @watchers[path] = watcher
      end
    end

    def stop_watch(paths, immediate=false)
      paths.each do |path|
        watcher = @watchers.delete(path)
        if watcher
          watcher.close(immediate ? nil : @loop)
        end
      end
    end

    def start
      paths, @paths = @paths, []
      super
      @thread.join
      @paths = paths
      refresh_watchers
      @refresh_trigger.attach(@loop)
      @ready = true
      @thread = Thread.new(&method(:run))
    end   

    def run
      # don't run unless ready to avoid coolio error
      if @ready
        super
      end
    end   

    def configure_parser(conf)
      @parser = MultilineTextParser_EX.new
      @parser.configure(conf)
    end

    def receive_lines(lines,tag)
      if @tag_prefix || @tag_suffix
        @tag = @tag_prefix + tag + @tag_suffix
      end
      @logbuf_flusher.cancel()
      es = MultiEventStream.new
      @locker.synchronize do
        lines.each {|line|
            if @parser.match_firstline(line)
              time, record = parse_logbuf(@logbuf)
              if time && record
                es.add(time, record)
              end
              @logbuf = line
            else
              @logbuf += line if(@logbuf)
            end
        }
      end
      unless es.empty?
        begin
          Engine.emit_stream(@tag, es)
        rescue
          # ignore errors. Engine shows logs and backtraces.
        end
      end
      @logbuf_flusher.call_later(@auto_flush_sec) do
        flush_logbuf()
      end
    end

    def shutdown
      @refresh_trigger.detach
      stop_watch(@watchers.keys, true)
      @loop.stop
      @thread.join
      @pf_file.close if @pf_file
      flush_logbuf()
      @logbuf_flusher.shutdown()
    end   

    def flush_logbuf
      time, record = nil,nil
      @locker.synchronize do
        time, record = parse_logbuf(@logbuf)
        @logbuf = nil
      end
      if time && record
        Engine.emit(@tag, time, record)
      end
    end

    def parse_logbuf(buf)
      return nil,nil unless buf
      buf.chomp!
      begin
        time, record = @parser.parse(buf)
      rescue
        $log.warn buf.dump, :error=>$!.to_s
        $log.debug_backtrace
      end
      return nil,nil unless time && record
      record[@rawdata_key] = buf if @rawdata_key
      return time, record
    end

    class TailExWatcher_EX < TailWatcher
      def initialize(path, rotate_wait, pe, &receive_lines)
        @parent_receive_lines = receive_lines
        super(path, rotate_wait, pe, &method(:_receive_lines))
        #super(path, rotate_wait, pe, &receive_lines)
        @close_trigger = TimerWatcher.new(rotate_wait * 2, false, &method(:_close))
      end

      def _receive_lines(lines)
        tag = @path.tr('/', '.').gsub(/\.+/, '.').gsub(/^\./, '')
        @parent_receive_lines.call(lines, tag)
      end

      def close(loop=nil)
        detach # detach first to avoid timer conflict
        if loop
          @close_trigger.attach(loop)
        else
          _close
        end
      end

      def _close
        @close_trigger.detach if @close_trigger.attached?
        self.class.superclass.instance_method(:close).bind(self).call

        @io_handler.on_notify
        @io_handler.close
        $log.info "stop following of #{@path}"
      end
    end
  end
  
  class CallLater_EX 
    def initialize
      @locker = Monitor::new
      initExecBlock()
      @thread = Thread.new(&method(:run))
    end
    
    def call_later(delay,&block)
      @locker.synchronize do
        @exec_time = Engine.now + delay
        @exec_block = block
      end
      @thread.run
    end
    
    def run
      @running = true
      while true
        sleepSec = -1
        @locker.synchronize do
          now = Engine.now
          if @exec_block && @exec_time <= now
            @exec_block.call()
            initExecBlock()
          end          
          return unless @running
          unless(@exec_time == -1)
            sleepSec = @exec_time - now 
          end
        end
        if (sleepSec == -1)
          sleep()
        else
          sleep(sleepSec)
        end
      end
    rescue => e
      puts e
    end

    def cancel()
      initExecBlock()
    end

    def shutdown()
      @locker.synchronize do
        @running = false
      end
      if(@thread)
        @thread.run
        @thread.join
        @thread = nil
      end
    end    

    private 

    def initExecBlock()
      @locker.synchronize do
        @exec_time = -1
        @exec_block = nil
      end
    end
    
  end
end
