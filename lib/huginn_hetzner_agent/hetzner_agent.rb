module Agents
  class HetznerAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description <<-MD
      The Hetzner Agent interacts with Hetzner API .

      The `type` can be like get_servers_info.

      The `debug` can add verbosity.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

    MD

    event_description <<-MD
      Events look like this:

          {
            "server":{
              "server_ip":"123.123.123.123",
              "server_ipv6_net":"2a01:f48:111:4221::",
              "server_number":321,
              "server_name":"server1",
              "product":"DS 3000",
              "dc":"NBG1-DC1",
              "traffic":"5 TB",
              "status":"ready",
              "cancelled":false,
              "paid_until":"2010-09-02",
              "ip":[
                "123.123.123.123"
              ],
              "subnet":[
                {
                  "ip":"2a01:4f8:111:4221::",
                  "mask":"64"
                }
              ]
            }
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'emit_events' => 'true',
        'changes_only' => 'true',
        'user' => '',
        'password' => '',
        'expected_receive_period_in_days' => '2',
        'type' => 'get_servers_info'
      }
    end

    form_configurable :changes_only, type: :boolean
    form_configurable :emit_events, type: :boolean
    form_configurable :debug, type: :boolean
    form_configurable :user, type: :string
    form_configurable :password, type: :string
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :type, type: :array, values: ['get_servers_info']
    def validate_options
      errors.add(:base, "type has invalid value: should be 'get_servers_info'") if interpolated['type'].present? && !%w(get_servers_info).include?(interpolated['type'])

      unless options['user'].present? || !['get_servers_info'].include?(options['type'])
        errors.add(:base, "user is a required field")
      end

      unless options['password'].present? || !['get_servers_info'].include?(options['type'])
        errors.add(:base, "password is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      trigger_action
    end

    private

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def get_servers_info

      uri = URI.parse("https://robot-ws.your-server.de/server")
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(interpolated['user'], interpolated['password'])
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)
      payload = JSON.parse(response.body)

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload.each do | server |
              create_event payload: server
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null")
            last_status = JSON.parse(last_status)
            payload.each do | server |
              found = false
              last_status.each do | serverbis|
                if server == serverbis
                    found = true
                end
              end
              if found == false
                  create_event payload: server
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end

    def trigger_action

      case interpolated['type']
      when "get_servers_info"
        get_servers_info()
      else
        log "Error: type has an invalid value (#{type})"
      end

    end
  end
end
