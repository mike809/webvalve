require 'webmock'
require 'singleton'
require 'set'

module WebValve
  # @api private
  class Manager
    include Singleton

    def register(fake_service, **args)
      raise "#{fake_service.inspect} already registered" if fake_service_configs.any? { |c| c.service == fake_service }
      fake_service_configs << FakeServiceConfig.new(service: fake_service, **args)
    end

    def whitelist_url(url)
      raise "#{url} already registered" if whitelisted_urls.include?(url)
      whitelisted_urls << url
    end

    def setup
      fake_service_configs.each do |config|
        if config.should_intercept?
          webmock_service config
        else
          whitelist_service config
        end
      end

      WebMock.enable!
      WebMock.disable_net_connect! webmock_disable_options
    end

    # @api private
    def reset
      whitelisted_urls.clear
      fake_service_configs.clear
    end

    # @api private
    def fake_service_configs
      @fake_service_configs ||= []
    end

    # @api private
    def whitelisted_urls
      @whitelisted_urls ||= Set.new
    end

    private

    def webmock_disable_options
      { allow_localhost: true }.tap do |opts|
        opts[:allow] = whitelisted_url_regexps unless WebValve.env.test?
      end
    end

    def whitelisted_url_regexps
      whitelisted_urls.map { |url| url_to_regexp url }
    end

    def webmock_service(config)
      WebMock.stub_request(
        :any,
        url_to_regexp(config.service_url)
      ).to_rack(FakeServiceWrapper.new(config.service))
    end

    def whitelist_service(config)
      whitelisted_urls << config.service_url
    end

    def url_to_regexp(url)
      %r(\A#{Regexp.escape url})
    end
  end
end
