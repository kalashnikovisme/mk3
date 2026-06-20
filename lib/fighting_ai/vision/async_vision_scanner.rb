module FightingAI
  module Vision
    # Runs vision scans in a background worker thread so the main loop is not
    # blocked by template matching. The worker processes one scan at a time,
    # guaranteeing sequential order. New submissions are latest-wins: if a scan
    # is already pending (not yet started), the newer path replaces it so the
    # worker always picks up the most recent frame rather than building a backlog.
    #
    # Main loop:            submit(path)   → non-blocking
    # Main loop:            latest_result  → last completed scan (may be nil)
    # Background worker:    detect_path → store result → wait for next
    class AsyncVisionScanner
      WORKER_JOIN_TIMEOUT = 1

      def initialize(detector)
        @detector    = detector
        @latest      = nil
        @result_lock = Mutex.new
        @pending     = nil
        @work_lock   = Mutex.new
        @work_ready  = ConditionVariable.new
        @running     = true
        @worker      = Thread.new { work_loop }
        @worker.report_on_exception = true
        at_exit { stop }
      end

      def submit(path)
        @work_lock.synchronize do
          @pending = path
          @work_ready.signal
        end
      end

      def latest_result
        @result_lock.synchronize { @latest }
      end

      def stop
        @work_lock.synchronize do
          @running = false
          @work_ready.signal
        end
        @worker.join(WORKER_JOIN_TIMEOUT)
      end

      private

      def work_loop
        loop do
          path = next_pending_path
          break unless path

          begin
            result = @detector.detect_path(path)
            @result_lock.synchronize { @latest = result }
          rescue => e
            warn "[AsyncVisionScanner] scan error: #{e.message}"
          end
        end
      end

      def next_pending_path
        @work_lock.synchronize do
          @work_ready.wait(@work_lock) while @running && @pending.nil?
          return nil unless @running

          path     = @pending
          @pending = nil
          path
        end
      end
    end
  end
end
