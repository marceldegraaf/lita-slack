require 'lita'
require 'faraday'
require 'json'

module Lita
  module Adapters
    class Slack < Adapter
      # Required Lita config keys (via lita_config.rb)
      require_configs :incoming_token, :team_domain

      def initialize(robot)
        log.debug 'Slack::initialize started'

        super

        # Set config default values
        config.incoming_url ||= "https://#{config.team_domain}.slack.com/services/hooks/incoming-webhook"
        config.username ||= nil
        config.add_mention ||= false

        log.debug 'Slack::initialize ending'
      end

      # Adapter main run loop
      def run
        log.debug 'Slack::run started'

        sleep
      rescue Interrupt
        shut_down
      end

      def send_messages(target, strings)
        log.debug 'Slack::send_messages started'

        status = http_post prepare_payload(target, strings)

        log.error "Slack::send_messages failed to send (#{status})" if status != 200
        log.debug 'Slack::send_messages ending'
      end

      # Slack currently provides no method to set the topic
      def set_topic(target, topic)
        log.info 'Slack::set_topic no implementation'
      end

      def shut_down
      end

      def prepare_payload(target, strings)
        unless defined?(target.room)
          channel_id = nil
          log.warn "Slack::prepare_payload proceeding without channel designation"
        else
          channel_id = target.room
        end

        username = target.user.name || config.username
        icon_url = target.user.metadata[:icon_url] || nil

        payload = { channel: channel_id, username: username, icon_url: icon_url }
        payload[:text] = strings.join("\n")

        if config.add_mention and defined?(target.user.id)
          payload[:text] = payload[:text].prepend("<@#{target.user.id}> ")
        end

        # Clean up the payload, removing "nil" values
        payload.reject!{ |k,v| v.nil? }

        return payload
      end

      def http_post(payload)
        res = Faraday.post do |req|
          log.debug "Slack::http_post sending payload to #{config.incoming_url}; length: #{payload.to_json.size}"
          req.url config.incoming_url, :token => config.incoming_token
          req.headers['Content-Type'] = 'application/json'
          req.body = payload.to_json
        end

        log.info "Slack::http_post sent payload with response status #{res.status}"
        log.debug "Slack::http_post response body: #{res.body}"

        return res.status
      end

      #
      # Accessor shortcuts
      #
      def config
        Lita.config.adapter
      end

      def log
        Lita.logger
      end
    end

    # Register Slack adapter to Lita
    Lita.register_adapter(:slack, Slack)
  end
end
