module Ahoy
  class Tracker
    attr_reader :request, :controller

    def initialize(options = {})
      @store = Ahoy::Store.new(options.merge(ahoy: self))
      @controller = options[:controller]
      @request = options[:request] || @controller.try(:request)
    end

    def track(name, properties = {}, options = {})
      unless exclude?
        options = options.dup

        options[:time] ||= trusted_time(options)
        options[:id] = ensure_uuid(options[:id] || generate_id)

        @store.track_event(name, properties, options)
      end
      true
    rescue => e
      report_exception(e)
    end

    def track_visit(options = {})
      unless exclude? or existing_visit_id
        if options[:defer]
          set_cookie("ahoy_track", true)
        else
          options = options.dup

          options[:started_at] ||= Time.zone.now

          @store.track_visit(options)
        end
      end
      true
    rescue => e
      report_exception(e)
    end

    def authenticate(user)
      unless exclude?
        @store.authenticate(user)
      end
      true
    rescue => e
      report_exception(e)
    end

    def current_visit
      @current_visit ||= @store.current_visit
    end

    def visit_id
      @visit_id ||= ensure_uuid(existing_visit_id || visit_token)
    end

    def visitor_id
      @visitor_id ||= ensure_uuid(existing_visitor_id || visitor_token)
    end

    def set_visit_cookie
      set_cookie("ahoy_visit", visit_id, Ahoy.visit_duration)
    end

    def set_visitor_cookie
      if !existing_visitor_id
        set_cookie("ahoy_visitor", visitor_id, Ahoy.visitor_duration)
      end
    end

    def user
      @user ||= @store.user
    end

    def extractor
      @extractor ||= Ahoy::Extractor.new(request)
    end

    # for ActiveRecordLegacyStore only - do not use
    def visit_token
      @visit_token ||= existing_visit_id || generate_id
    end

    # for ActiveRecordLegacyStore only - do not use
    def visitor_token
      @visitor_token ||= existing_visitor_id || generate_id
    end

    protected

    def set_cookie(name, value, duration = nil)
      cookie = {
        value: value,
        path: "/"
      }
      cookie[:expires] = duration.from_now if duration
      domain = Ahoy.cookie_domain || Ahoy.domain
      cookie[:domain] = domain if domain
      controller.response.set_cookie(name, cookie)
    end

    def trusted_time(options)
      if options[:time] and options[:trusted] == false and (1.minute.ago..Time.now).cover?(options[:time])
        options[:time]
      else
        Time.zone.now
      end
    end

    def exclude?
      @store.exclude?
    end

    def report_exception(e)
      @store.report_exception(e)
      if Rails.env.development?
        raise e
      end
    end

    def generate_id
      @store.generate_id
    end

    def existing_visit_id
      @existing_visit_id ||= request.headers["Ahoy-Visit"] || request.cookies["ahoy_visit"]
    end

    def existing_visitor_id
      @existing_visitor_id ||= request.headers["Ahoy-Visitor"] || request.cookies["ahoy_visitor"]
    end

    def ensure_uuid(id)
      Ahoy.ensure_uuid(id)
    end

  end
end
