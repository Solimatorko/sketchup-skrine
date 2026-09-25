require 'fileutils'

module Skrine
  module SU
    # Diagnostics: a load log outside SketchUp's console and an opt-in start-up
    # self-test (touch /tmp/skrine-selftest.request, restart SketchUp).
    module Diag
      LOG = '/tmp/skrine-load.log'.freeze
      REQUEST = '/tmp/skrine-selftest.request'.freeze
      SCREENSHOT = '/tmp/skrine-selftest.png'.freeze

      def self.log(message)
        File.open(LOG, 'a') { |f| f.puts("#{Time.now.strftime('%H:%M:%S')} #{message}") }
      rescue StandardError
        nil
      end

      def self.log_exception(where, error)
        log("#{where}: #{error.class}: #{error.message}\n  #{error.backtrace.first(6).join("\n  ")}")
      end

      def self.menu_registered!
        @menu_registered = true
      end

      def self.menu_registered?
        @menu_registered == true
      end

      def self.selftest_requested?
        File.exist?(REQUEST)
      end

      # Runs a few seconds after load so the model window exists.
      def self.schedule_selftest
        return unless selftest_requested?

        log('selftest scheduled')
        UI.start_timer(4.0, false) { run_selftest }
      end

      def self.run_selftest
        File.delete(REQUEST) if File.exist?(REQUEST)
        model = Sketchup.active_model
        log("selftest start: SketchUp #{Sketchup.version}, Ruby #{RUBY_VERSION}, model #{model.title.inspect}")
        type = Core::Registry.fetch(:wardrobe)
        res = Builder.create(model, type.key, type.schema.defaults)
        log("selftest create: errors=#{res[:errors].inspect} warnings=#{res[:warnings].size} parts=#{res[:group] ? res[:group].entities.size : 0}")
        return if res[:errors].any?

        Commands.open_editor(res[:group])
        log('selftest editor open requested')
        UI.start_timer(5.0, false) do
          begin
            dlg = Dialog.instance.dialog
            log("selftest dialog visible=#{dlg.visible?}")
            model.active_view.zoom(res[:group])
            model.active_view.write_image(SCREENSHOT, 1400, 900, true)
            log("selftest screenshot #{SCREENSHOT}")
          rescue StandardError => e
            log_exception('selftest dialog check', e)
          end
        end
      rescue StandardError => e
        log_exception('selftest', e)
      end
    end
  end
end
